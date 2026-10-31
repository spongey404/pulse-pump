import XCTest

/// Screenshots of your profile, Add friends and a friend's profile in light and dark (`SOCIAL_SHOTS=<dir>`), for checking against
/// the design. Signs in as the seeded friend1 (@frankie): friends Sam and Tess, requests from Ollie and Priya, follows Jay.
final class SocialPeopleShotsUITests: UITestCase {
    func testPeopleScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["SOCIAL_SHOTS"] else { throw XCTSkip("set SOCIAL_SHOTS to save screenshots") }
        func settle(_ s: TimeInterval = 1.2) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }

        for dark in [false, true] {
            let suffix = dark ? "-dark" : "-light"
            XCUIDevice.shared.appearance = dark ? .dark : .light
            func shot(_ name: String) { try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name)\(suffix).png")) }

            if dark { app.terminate() }
            launch(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
            require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
            SocialPage(t: self).open()
            tapID(AX.social.profile)
            require(el(AX.nav.title("YOU")), "own profile page")
            settle(2.5)
            shot("5b")

            let find = app.buttons["Find friends"]
            require(find, "find friends button")
            find.tap()
            settle(2.5)
            shot("5c")
            tapBack()
            settle()

            let tess = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tess Three'")).firstMatch
            require(tess, "Tess in the FOLLOWING list")
            tess.tap()
            settle(3)
            shot("5a")
        }
    }
}
