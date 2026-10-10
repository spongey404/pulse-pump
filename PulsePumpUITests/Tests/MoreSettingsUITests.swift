import XCTest

/// The More hub, Settings, account lifecycle (sign-out / restore / delete), widgets and the tutorial.
final class MoreSettingsUITests: UITestCase {

    func testMoreHubOpensEveryScreenAndComesBack() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .busy, weeks: 4, plus: true))
        TabBar(t: self).more()
        let screens: [(row: String, title: String)] = [
            ("History", "HISTORY"), ("Equipment Profiles", "EQUIPMENT"), ("Weekly Recap", "WEEKLY RECAP"),
            ("Widgets", "WIDGETS"), ("Settings", "SETTINGS"), ("Data Import", "IMPORT / EXPORT"),
            ("Privacy & Legal", "PRIVACY & LEGAL"),
        ]
        for screen in screens {
            let row = el(AX.row(screen.row))
            scrollTo(row)
            row.tap()
            require(el(AX.nav.title(screen.title)), "\(screen.title) screen")
            tapID(AX.nav.back)
            require(el(AX.more.screen), "More hub after leaving \(screen.title)")
        }
        // Pulse+ opens full screen with its own close button.
        let plus = el(AX.row("Pulse+"))
        scrollTo(plus)
        plus.tap()
        require(labelContaining("Weekly Recaps"), "Pulse+ feature list")
        tap(app.buttons["Close"].firstMatch, "Pulse+ close button")
        require(el(AX.more.screen), "More hub after closing Pulse+")
    }

    func testChangingTheWeightUnitInSettingsSwitchesTheAppToPounds() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .busy, weeks: 4))
        let settings = SettingsPage(t: self)
        settings.open()
        waitForLabel(el(AX.menu("Weight Unit")), matching: "CONTAINS[c]", "kg")
        settings.choose("Pounds (lbs)", inMenu: "Weight Unit")
        waitForLabel(el(AX.menu("Weight Unit")), matching: "CONTAINS[c]", "lbs")

        // The logger header column follows the unit (stored data stays kg).
        TabBar(t: self).home()
        HomePage(t: self).startPredictedWorkout()
        require(labelContaining("LBS").exists ? labelContaining("LBS") : labelContaining("LB"), "weight column labelled in pounds")
    }

    func testSettingsPrivacyRowsAreShownAndProfileVisibilityCanChange() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .newUser, weeks: 2))
        let settings = SettingsPage(t: self)
        settings.open()
        let visibility = el(AX.menu("Profile Visibility"))
        scrollTo(visibility)
        let before = visibility.label
        visibility.tap()
        // Pick any option that is not the current one.
        let options = app.buttons.matching(NSPredicate(format: "label != %@ AND label != ''", before))
        XCTAssertGreaterThan(options.count, 0)
        let other = ["Friends", "Only Me", "Everyone"].first { !before.localizedCaseInsensitiveContains($0) } ?? "Friends"
        tap(app.buttons[other].firstMatch, "visibility option \(other)")
        XCTAssertTrue(labelChanges(visibility, from: before, within: 10), "visibility row should show the new choice")
        require(el(AX.row("Auto-Share to Feed")), "auto-share privacy row")
    }

    func testSigningOutAndBackInRestoresTheWorkoutsFromTheCloud() {
        let email = LaunchConfig.uniqueEmail("m")
        launch(LaunchConfig(email: email, scenario: .busy, weeks: 3))
        let before = HomePage(t: self).sets

        // Wait until the seeded data has been pushed to Firestore (Settings › Cloud Sync › Last Synced).
        let settings = SettingsPage(t: self)
        settings.open()
        let last = el(AX.row("Last Synced"))
        scrollTo(last)
        let syncNow = el(AX.row("Sync Now"))
        scrollTo(syncNow)
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
        let settings = SettingsPage(t: self)
        settings.open()
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

        require(el(AX.auth.useEmail), "sign-in screen after the account is deleted", timeout: 60)
        Self.signedInEmail = nil
        // The credentials no longer work (relaunch without auto sign-in so the sheet is driven by hand).
        relaunch(with: LaunchConfig(email: nil))
        SignInPage(t: self).signIn(email: email, password: LaunchConfig.defaultPassword)
        require(el(AX.auth.emailError), "sign-in error for a deleted account", timeout: 30)
    }

    func testWidgetGalleryOpensFromTheWidgetsScreen() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("m"), scenario: .busy, weeks: 4, plus: true))
        TabBar(t: self).more()
        let widgets = el(AX.row("Widgets"))
        scrollTo(widgets)
        widgets.tap()
        require(el(AX.nav.title("WIDGETS")), "Widgets library")
        tapID(AX.row("Widget gallery"))
        require(el(AX.nav.title("WIDGET GALLERY")), "Widget gallery")
    }

    func testTutorialCoachMarksAppearOnFirstRunAndCanBeSkipped() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("t"), tutorial: true))
        require(el(AX.tutorial.card), "first coach mark card", timeout: 30)
        tapID(AX.tutorial.next)
        let second = el(AX.tutorial.card)
        XCTAssertTrue(second.exists)
        tapID(AX.tutorial.skip)
        waitUntilGone(el(AX.tutorial.card), "coach mark card after SKIP")
        require(el(AX.tab.home), "the app underneath is usable")
    }
}
