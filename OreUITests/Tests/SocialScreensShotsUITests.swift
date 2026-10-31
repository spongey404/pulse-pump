import XCTest

/// Screenshots of the Social feed, a session, the comments sheet and Activity (`SOCIAL_SHOTS=<dir>`), for checking against the design.
/// `SOCIAL_SHOTS_TAG` (default "light") is appended to each file name; `SOCIAL_SHOTS_MEMBER=1` runs as a Supernova member
/// (`-devDataPlus 1`), so the signed-in user's own posts carry the Stardust muscles and the SUPERNOVA* tag.
/// The seeded posts (firebase/seed) carry real sets, so the stats and session rows have data.
final class SocialScreensShotsUITests: UITestCase {
    func testSocialScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["SOCIAL_SHOTS"] else { throw XCTSkip("set SOCIAL_SHOTS to save screenshots") }
        let env = ProcessInfo.processInfo.environment
        let tag = env["SOCIAL_SHOTS_TAG"] ?? "light"
        let member = env["SOCIAL_SHOTS_MEMBER"] == "1"
        func shot(_ name: String) { try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name)-\(tag).png")) }
        func settle(_ s: TimeInterval = 1.0) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }
        func config() -> LaunchConfig {
            var c = LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false)
            if member { c.extraArguments = ["-devDataPlus", "1"] }
            return c
        }

        launch(config())
        require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
        SocialPage(t: self).open()
        require(SocialPage(t: self).anyPost, "a friend's post in the feed", timeout: 45)
        settle(2.0)
        shot("feed")
        app.swipeUp(velocity: .slow); settle(0.8)
        shot("feed-2")
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); settle(0.5)

        // The first card with a PR (seeded "Push Day" by frankie when a member: own post).
        let hero = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Full session'")).firstMatch
        if hero.exists {
            hero.tap(); settle(1.5); shot("session")
            let comments = app.buttons["Comments"].firstMatch
            if comments.exists { comments.tap(); settle(1.5); shot("comments") }
        }

        launch(config())
        require(el(AX.tab.home), "Home again", timeout: 90)
        SocialPage(t: self).open()
        tapID(AX.social.bell)
        settle(1.5)
        shot("activity")
    }
}
