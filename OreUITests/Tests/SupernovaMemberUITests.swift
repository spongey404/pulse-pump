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
        let pink = el(AX.supernova.accentSwatch("pink"))
        require(pink, "the Pink swatch")
        pink.tap()
        XCTAssertTrue(pink.isSelected, "Pink is selected")
        XCTAssertFalse(el(AX.supernova.accentSwatch("sky")).isSelected)
    }
}
