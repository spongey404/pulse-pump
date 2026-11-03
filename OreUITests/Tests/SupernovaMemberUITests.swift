import XCTest

/// The member experience: the membership card replaces the profile row on More, opens the membership page, and ‹ brings
/// it back (design "Supernova Member Flow"). The frames are checked by `SupernovaMemberTests`; this drives the real thing.
final class SupernovaMemberUITests: UITestCase {
    func testMembershipCardOpensThePageTabsWorkAndBackReturnsToTheCard() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("mem"), scenario: .newUser, plus: true))
        TabBar(t: self).more()
        let card = el(AX.supernova.memberCard)
        require(card, "the membership card (member)")
        XCTAssertFalse(el(AX.supernova.banner).exists, "no free banner for a member")

        for round in 1...2 {
            card.tap()
            require(el(AX.supernova.memberBack), "the membership page, round \(round)", timeout: 10)
            RunLoop.current.run(until: Date().addingTimeInterval(1.8))   // the flight is done by about 0.8 s, the content by 1.6 s
            require(el(AX.supernova.memberEmptyHeadline), "a brand-new member sees the prompt, never a 0")
            for tab in ["PERKS", "APPEARANCE", "ACCOUNT", "OVERVIEW"] {
                tapID(AX.supernova.memberTab(tab))
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            }
            tapID(AX.supernova.memberTab("ACCOUNT"))
            require(el(AX.supernova.manageSubscription), "Manage subscription on the account tab")
            tapID(AX.supernova.memberBack)
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: el(AX.supernova.memberBack))
            waitForExpectations(timeout: 10)
            require(card, "the card is back after ‹, round \(round)", timeout: 10)
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        }
    }

    func testStardustButtonsSwitchIsOnTheAppearanceTab() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("gb"), scenario: .newUser, plus: true))
        TabBar(t: self).more()
        el(AX.supernova.memberCard).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        tapID(AX.supernova.memberTab("APPEARANCE"))
        let toggle = el(AX.supernova.stardustEnabled)
        require(toggle, "the Stardust buttons switch")
        XCTAssertEqual(toggle.value as? String, "On", "on by default for a member")
        toggle.tap()
        XCTAssertEqual(el(AX.supernova.stardustEnabled).value as? String, "Off")
        XCTAssertTrue(app.staticTexts["Adds Stardust to every accent button. Uses a little more battery."].exists, "the battery hint")
    }

    func testStardustScrollsAwayWithThePage() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("scr"), scenario: .newUser, plus: true))
        TabBar(t: self).more()
        el(AX.supernova.memberCard).tap()
        require(el(AX.supernova.memberBack), "the membership page", timeout: 10)
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "member-top"; shot.lifetime = .keepAlways; add(shot)
        if let dir = ProcessInfo.processInfo.environment["MEMBER_SHOTS"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir + "/member-top.png"))
        }
        for _ in 0..<3 { app.swipeUp(velocity: .fast) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        if let dir = ProcessInfo.processInfo.environment["MEMBER_SHOTS"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir + "/member-scrolled.png"))
        }
    }

    func testPickingAnAccentRecoloursTheSelection() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("acc"), scenario: .newUser, plus: true))
        TabBar(t: self).more()
        el(AX.supernova.memberCard).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        tapID(AX.supernova.memberTab("APPEARANCE"))
        let pink = el(AX.supernova.accentSwatch("FD4A9F"))
        require(pink, "the Pink preset")
        pink.tap()
        XCTAssertTrue(pink.isSelected, "Pink is selected")
        XCTAssertFalse(el(AX.supernova.accentSwatch("3DB8FF")).isSelected, "Sky no longer is")
        XCTAssertEqual(el(AX.supernova.accentHex).value as? String, "#FD4A9F", "the hex field mirrors the preset")

        // ADJUST opens the three strips; a + step moves the hue and the hex follows (it is no longer a preset).
        tapID(AX.supernova.accentAdjust)
        require(el(AX.supernova.accentStrip("hue")), "the hue strip")
        tapID(AX.supernova.accentStep("hue", 1))
        XCTAssertNotEqual(el(AX.supernova.accentHex).value as? String, "#FD4A9F", "the hex follows the slider")
        XCTAssertFalse(pink.isSelected, "a moved colour matches no preset")
    }

    func testTypingAHexRecoloursAndLeavingAddsItToTheRecentRow() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("hex"), scenario: .newUser, plus: true))
        TabBar(t: self).more()
        el(AX.supernova.memberCard).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        tapID(AX.supernova.memberTab("APPEARANCE"))
        let field = el(AX.supernova.accentHex)
        require(field, "the hex field")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "123456\n")   // clear, then type
        XCTAssertEqual(el(AX.supernova.accentHex).value as? String, "#123456")
        tapID(AX.supernova.memberBack)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: el(AX.supernova.memberBack))
        waitForExpectations(timeout: 10)
        el(AX.supernova.memberCard).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        tapID(AX.supernova.memberTab("APPEARANCE"))
        require(el(AX.supernova.accentSwatch("123456")), "the colour joined the recent row")
    }

    /// Saves screenshots of the Account tab (sliders open) in both appearances when `MEMBER_SHOTS` is set.
    func testAccountTabScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["MEMBER_SHOTS"] else { throw XCTSkip("set MEMBER_SHOTS to save screenshots") }
        for mode in ["Dark", "Light"] {
            var config = LaunchConfig(email: LaunchConfig.uniqueEmail("shot\(mode)"), scenario: .newUser, plus: true)
            config.extraArguments = ["-appTheme", mode.lowercased(), "-debugAccentAdjust", "1"]
            if ProcessInfo.processInfo.environment["MEMBER_NO_STARS"] == "1" { config.extraArguments += ["-debugSignupNoStars", "1"] }
            launch(config)
            TabBar(t: self).more()
            el(AX.supernova.memberCard).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.8))
            for (i, tab) in ["OVERVIEW", "PERKS", "APPEARANCE", "ACCOUNT"].enumerated() {
                tapID(AX.supernova.memberTab(tab))
                RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(mode)-\(i)-\(tab).png"))
            }
            app.terminate()
        }
    }

    /// Saves the card at rest and the transition held at the end of its close (`MEMBER_SHOTS=<dir>`), to compare the "*" flyer with the real one.
    func testCloseEndsOnTheCardsAsterisk() throws {
        guard let dir = ProcessInfo.processInfo.environment["MEMBER_SHOTS"] else { throw XCTSkip("set MEMBER_SHOTS to save screenshots") }
        let first = LaunchConfig(email: LaunchConfig.uniqueEmail("cl"), scenario: .newUser, plus: true)
        launch(first)
        app.terminate()
        for (name, extra) in [("rest", []), ("close-540", ["-debugTransition", "member-close:540"]), ("close-559", ["-debugTransition", "member-close:559"])] as [(String, [String])] {
            var config = first.relaunch
            config.extraArguments = ["-debugStartTab", "4", "-debugSignupNoStars", "1", "-devDataPlus", "1"] + extra
            launch(config)
            RunLoop.current.run(until: Date().addingTimeInterval(name == "rest" ? 2 : 6))
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
            app.terminate()
        }
    }

    /// The card scrolled partly under the More header: opening and closing must start and end on what is visible (frames saved with `MEMBER_SHOTS`).
    func testClosingFromAPartlyScrolledCardEndsOnTheVisiblePart() throws {
        guard let dir = ProcessInfo.processInfo.environment["MEMBER_SHOTS"] else { throw XCTSkip("set MEMBER_SHOTS to save screenshots") }
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("scl"), scenario: .newUser, plus: true))
        TabBar(t: self).more()
        let card = el(AX.supernova.memberCard)
        require(card, "the membership card")
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)))   // a small scroll
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/scrolled-rest.png"))
        card.tap()
        require(el(AX.supernova.memberBack), "the membership page", timeout: 10)
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        tapID(AX.supernova.memberBack)
        require(card, "the card is back after the close, still tappable", timeout: 10)
        for i in 0..<6 { try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/scrolled-close-\(i).png")) }
    }
}
