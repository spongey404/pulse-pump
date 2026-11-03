import XCTest

/// The More hub, Settings, account lifecycle (sign-out / restore / delete), widgets and the tutorial.
final class MoreSettingsUITests: UITestCase {

    func testMoreHubOpensEveryScreenAndComesBack() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .busy, weeks: 4, plus: true))
        TabBar(t: self).more()
        let screens: [(row: String, title: String)] = [
            ("History", "HISTORY"), ("Analytics", "ANALYTICS"), ("Equipment profiles", "EQUIPMENT"), ("Weekly Recap", "WEEKLY RECAP"),
            ("Settings", "SETTINGS"), ("Cloud Sync", "CLOUD SYNC"), ("Data import", "DATA IMPORT"),
            ("Privacy & legal", "PRIVACY & LEGAL"),
        ]
        for screen in screens {
            let row = el(AX.row(screen.row))
            scrollTo(row)
            row.tap()
            require(el(AX.nav.title(screen.title)), "\(screen.title) screen")
            tapID(AX.nav.back)
            require(el(AX.more.screen), "More hub after leaving \(screen.title)")
        }
        // A member's card opens the membership page, which has its own back button.
        let card = el(AX.supernova.memberCard)
        for _ in 0..<3 { app.swipeDown(velocity: .fast) }   // the list was left scrolled by the rows above
        scrollTo(card)
        card.tap()
        require(el(AX.supernova.memberBack), "the membership page", timeout: 10)
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        tapID(AX.supernova.memberBack)
        require(el(AX.more.screen), "More hub after leaving the membership page", timeout: 10)
    }

    func testChangingTheWeightUnitInSettingsSwitchesTheAppToPounds() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .busy, weeks: 4))
        let settings = SettingsPage(t: self)
        settings.open()
        XCTAssertTrue(el(AX.row("Weight unit KG")).isSelected, "kilograms by default")
        tapID(AX.row("Weight unit LB"))
        expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: el(AX.row("Weight unit LB")))
        waitForExpectations(timeout: 10)

        // The logger header column follows the unit (stored data stays kg).
        TabBar(t: self).home()
        HomePage(t: self).startPredictedWorkout()
        require(labelContaining("LBS").exists ? labelContaining("LBS") : labelContaining("LB"), "weight column labelled in pounds")
    }

    func testSettingsPrivacyRowsAreShownAndProfileVisibilityCanChange() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .newUser, weeks: 2))
        let settings = SettingsPage(t: self)
        settings.open()
        let others = ["Profile visibility Friends only", "Profile visibility Only me", "Profile visibility Everyone"]
        let current = others.first { el(AX.row($0)).exists && el(AX.row($0)).isSelected }
        let target = others.first { $0 != current } ?? others[1]
        scrollTo(el(AX.row(target)))
        tapID(AX.row(target))
        expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: el(AX.row(target)))
        waitForExpectations(timeout: 10)
        require(el(AX.row("Auto-share to feed")), "auto-share row")
    }

    func testSigningOutAndBackInRestoresTheWorkoutsFromTheCloud() {
        let email = LaunchConfig.uniqueEmail("m")
        launch(LaunchConfig(email: email, scenario: .busy, weeks: 3))
        let before = HomePage(t: self).sets

        // Wait until the seeded data has been pushed to Firestore (Settings › Cloud Sync › Last Synced).
        let settings = SettingsPage(t: self)
        TabBar(t: self).more()
        tapID(AX.row("Cloud Sync"))
        let last = el(AX.row("Last Synced"))
        require(last, "Last synced row")
        let syncNow = el(AX.row("Sync Now"))
        require(syncNow, "SYNC NOW button")
        syncNow.tap()
        waitForLabelNotContaining(last, "NEVER", timeout: 60)

        relaunch(with: LaunchConfig(email: nil))                 // keeps login + data, drops auto sign-in
        require(el(AX.tab.home), "Home after relaunch")
        settings.signOutFromMoreHub()
        require(el(AX.auth.useEmail), "sign-in screen")
        SignInPage(t: self).signIn(email: email, password: LaunchConfig.defaultPassword)
        require(el(AX.tab.home), "Home after signing back in", timeout: 90)
        XCTAssertEqual(HomePage(t: self).sets, before, "the same weekly sets come back from the cloud")
    }

    func testDeleteAccountNeedsTheTypedPhraseAndThenRemovesTheAccount() {
        let email = LaunchConfig.uniqueEmail("d")
        launch(LaunchConfig(email: email, scenario: .newUser, weeks: 2))
        // Without the auto sign-in arguments, so the app stays on the sign-in screen once the account is gone.
        relaunch(with: LaunchConfig(email: nil))
        require(el(AX.tab.home), "Home after relaunch")
        TabBar(t: self).more()
        tapID(AX.row("Privacy & legal"))
        let row = el(AX.row("Delete Account"))
        scrollTo(row)
        row.tap()

        let confirm = el(AX.modal.confirm)
        require(confirm, "DELETE FOREVER button")
        XCTAssertFalse(confirm.isEnabled, "deleting is disabled until DELETE is typed")
        type("DELETE", into: AX.settings.deleteConfirmField)
        type(LaunchConfig.defaultPassword, into: AX.settings.deletePasswordField)
        dismissKeyboard()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        declineSavePasswordPrompt()

        require(el(AX.auth.useEmail), "sign-in screen after the account is deleted", timeout: 60)
        Self.signedInEmail = nil
        // The account is gone: the same email is free again, so signing up with it starts a brand-new account (the
        // questions), not the old data.
        SignInPage(t: self).signUp(email: email, password: LaunchConfig.defaultPassword)
        OnboardingPage(t: self).waitFor("NAME")
        XCTAssertFalse(el(AX.tab.home).exists)
    }

    func testWidgetGalleryOpensFromTheWidgetsScreen() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .busy, weeks: 4, plus: true))
        SettingsPage(t: self).open()
        let widgets = el(AX.row("Widgets"))
        scrollTo(widgets)
        widgets.tap()
        require(el(AX.nav.title("WIDGETS")), "Widgets library")
        tapID(AX.row("Widget gallery"))
        require(el(AX.nav.title("WIDGET GALLERY")), "Widget gallery")
    }

    func testTutorialCoachMarksAppearOnFirstRunAndCanBeSkipped() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("t"), tutorial: true))
        // The walkthrough is interactive (the user taps the highlighted control), so the first card has no NEXT button.
        require(el(AX.tutorial.card), "first coach mark card", timeout: 30)
        tapID(AX.tutorial.skip)
        waitUntilGone(el(AX.tutorial.card), "coach mark card after SKIP")
        require(el(AX.tab.home), "the app underneath is usable")
    }
}

/// Screenshots of the More list and the pages it pushes (`MORE_SHOTS=<dir>`), for checking against the design.
final class MoreScreensShotsUITests: UITestCase {
    func testMoreAndSettingsScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["MORE_SHOTS"] else { throw XCTSkip("set MORE_SHOTS to save screenshots") }
        func shot(_ name: String) { try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png")) }
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("ms"), scenario: .busy, weeks: 6, plus: true))
        TabBar(t: self).more()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        shot("more-top")
        app.swipeUp(velocity: .fast)
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        shot("more-bottom")
        for (row, name) in [("Settings", "settings"), ("History", "history"), ("Analytics", "analytics"), ("Cloud Sync", "cloudsync"),
                            ("Equipment profiles", "equipment"), ("Weekly Recap", "recap"), ("Data import", "import"), ("Privacy & legal", "privacy")] {
            for _ in 0..<3 { app.swipeDown(velocity: .fast) }
            scrollTo(el(AX.row(row)))
            tapID(AX.row(row))
            RunLoop.current.run(until: Date().addingTimeInterval(0.9))
            shot(name)
            if name == "settings" {
                app.swipeUp(velocity: .slow); RunLoop.current.run(until: Date().addingTimeInterval(0.4)); shot("settings-2")
                app.swipeUp(velocity: .slow); RunLoop.current.run(until: Date().addingTimeInterval(0.4)); shot("settings-3")
                app.swipeUp(velocity: .fast); RunLoop.current.run(until: Date().addingTimeInterval(0.4)); shot("settings-4")
                for sub in ["Edit profile", "Gender", "Calorie formula", "Training split", "Summary display"] {
                    app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
                    scrollTo(el(AX.row(sub)))
                    tapID(AX.row(sub))
                    RunLoop.current.run(until: Date().addingTimeInterval(0.9))
                    shot("settings-" + AX.slug(sub))
                    tapBack()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                }
            }
            tapBack()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        }
        // The sign-out sheet.
        app.swipeUp(velocity: .fast)
        scrollTo(el(AX.row("Sign out")))
        tapID(AX.row("Sign out"))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        shot("signout")
    }
}
