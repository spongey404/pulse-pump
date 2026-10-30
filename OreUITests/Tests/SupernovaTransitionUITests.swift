import XCTest

/// The More tab's "GO SUPERNOVA*" banner grows into the paywall and TRAIN FREE brings it back (design "Supernova
/// Transition Final"). The frames themselves are checked by `SupernovaTransitionTests`; this drives the real animation.
final class SupernovaTransitionUITests: UITestCase {
    func testBannerOpensThePaywallAndTrainFreeReturnsToTheBannerTwice() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("tr"), scenario: .newUser))
        TabBar(t: self).more()
        let banner = el(AX.supernova.banner)
        require(banner, "the GO SUPERNOVA banner (free plan)")

        for round in 1...2 {
            banner.tap()
            let start = el(AX.supernova.start)
            require(start, "the paywall, round \(round)", timeout: 10)
            // Taps count only once it is fully open (about 0.8 s; the content keeps arriving until about 1.6 s).
            RunLoop.current.run(until: Date().addingTimeInterval(1.8))
            XCTAssertTrue(app.staticTexts["Logging, PRs and body map stay free."].exists)
            XCTAssertFalse(app.buttons["NOT NOW →"].exists, "TRAIN FREE is the only way out")

            tapID(AX.supernova.free)
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: start)
            waitForExpectations(timeout: 10)
            require(banner, "the banner is back after TRAIN FREE, round \(round)", timeout: 10)
            // The banner's text returns staggered; once settled it can be tapped again.
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        }
    }
}
