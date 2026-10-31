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
            for tab in ["PERKS", "ACCOUNT", "OVERVIEW"] {
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

    func testGlitterScrollsAwayWithThePage() {
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
        tapID(AX.supernova.memberTab("ACCOUNT"))
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
        tapID(AX.supernova.memberTab("ACCOUNT"))
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
        tapID(AX.supernova.memberTab("ACCOUNT"))
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
            for (i, tab) in ["OVERVIEW", "PERKS", "ACCOUNT"].enumerated() {
                tapID(AX.supernova.memberTab(tab))
                RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(mode)-\(i)-\(tab).png"))
            }
            app.terminate()
        }
    }
}
