import XCTest

/// Screenshots of the Social feed, a session, the comments sheet and Activity (`SOCIAL_SHOTS=<dir>`), for checking against the design.
/// `SOCIAL_SHOTS_TAG` (default "light") is appended to each file name.
final class SocialScreensShotsUITests: UITestCase {
    func testSocialScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["SOCIAL_SHOTS"] else { throw XCTSkip("set SOCIAL_SHOTS to save screenshots") }
        let tag = ProcessInfo.processInfo.environment["SOCIAL_SHOTS_TAG"] ?? "light"
        func shot(_ name: String) { try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name)-\(tag).png")) }
        func settle(_ s: TimeInterval = 1.0) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }

        launch(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
        require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
        SocialPage(t: self).open()
        require(SocialPage(t: self).anyPost, "a friend's post in the feed", timeout: 45)
        settle(1.5)
        shot("feed")

        let hero = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Full session'")).firstMatch
        if hero.exists {
            hero.tap(); settle(1.2); shot("session")
            let comments = app.buttons["Comments"].firstMatch
            if comments.exists { comments.tap(); settle(1.2); shot("comments") }
        }

        launch(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
        require(el(AX.tab.home), "Home again", timeout: 90)
        SocialPage(t: self).open()
        tapID(AX.social.bell)
        settle(1.2)
        shot("activity")
    }
}
