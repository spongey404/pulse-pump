import XCTest

/// Saves screenshots of the challenge screens (3a, 4a, 6a, 6b) against the seeded emulator when `CHALLENGE_SHOTS=<dir>` is set
/// (`TEST_RUNNER_CHALLENGE_SHOTS`). Skipped otherwise. Run through `bin/test-ui.sh --only ChallengeShotsUITests`.
final class ChallengeShotsUITests: UITestCase {
    func testChallengeScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["CHALLENGE_SHOTS"] else { throw XCTSkip("set CHALLENGE_SHOTS to save screenshots") }
        func shot(_ name: String) {
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
            try? app.debugDescription.write(toFile: "\(dir)/\(name).txt", atomically: true, encoding: .utf8)
        }
        launch(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
        require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
        SocialPage(t: self).open()
        tapID(AX.social.tabChallenges)
        require(el(AX.social.challengeName), "global challenge card", timeout: 45)
        let join = el(AX.social.challengeJoin)
        if join.waitForExistence(timeout: 3) { join.tap() }
        require(el(AX.social.challengeView), "BOARD after joining", timeout: 30)
        shot("3a-challenges")

        tapID(AX.social.challengeView)
        require(el(AX.nav.back), "leaderboard", timeout: 20)
        shot("4a-global-board")
        tapBack()

        tap(labelContaining("Bench Club"), "Bench Club card")
        require(el(AX.nav.back), "friend board", timeout: 20)
        shot("4a-friend-board")
        tap(labelContaining("+ INVITE"), "invite")
        require(labelContaining("INVITE FRIENDS"), "invite screen", timeout: 20)
        shot("6b-invite")
        tapID(AX.social.pill("INVITE"))
        shot("6b-invited")
    }

    func testCreateScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["CHALLENGE_SHOTS"] else { throw XCTSkip("set CHALLENGE_SHOTS to save screenshots") }
        launch(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
        require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
        SocialPage(t: self).open()
        tapID(AX.social.tabChallenges)
        require(el(AX.social.challengeName), "global challenge card", timeout: 45)
        scrollTo(el(AX.row("Create challenge")))
        tapID(AX.row("Create challenge"))
        require(labelContaining("NEW CHALLENGE"), "step 1", timeout: 20)
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/6a-create.png"))
    }
}
