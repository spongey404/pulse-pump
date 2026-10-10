import XCTest

/// Social tab against the seeded emulator (firebase/seed): signed in as friend1 (@frankie), whose friends are
/// sam_lifts and tess.t. Tests that change the graph put it back, so they can run in any order.
final class SocialUITests: UITestCase {

    private func signInAsFrankie() {
        launch(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
        require(el(AX.tab.home), "Home for the seeded user (profile restored from the cloud)", timeout: 90)
        SocialPage(t: self).open()
    }

    func testFeedShowsPostsFromFriends() {
        signInAsFrankie()
        require(SocialPage(t: self).anyPost, "a friend's post in the feed", timeout: 45)
    }

    func testUnfollowingAFriendAndFollowingBackRestoresTheFriendship() {
        signInAsFrankie()
        let author = el(AX.social.postCard("sam_lifts"))
        require(author, "sam_lifts post author", timeout: 45)
        author.tap()

        let friends = el(AX.social.pill("FRIENDS"))
        require(friends, "FRIENDS pill on a friend's profile")
        friends.tap()
        tap(app.buttons["Unfollow"].firstMatch, "Unfollow confirmation")
        require(el(AX.social.pill("FOLLOW BACK")), "FOLLOW BACK once the follow is removed (they still follow you)", timeout: 30)

        tapID(AX.social.pill("FOLLOW BACK"))
        require(el(AX.social.pill("FRIENDS")), "friendship restored", timeout: 30)
    }

    func testJoiningTheGlobalChallengeShowsItsLeaderboardEntry() {
        signInAsFrankie()
        tapID(AX.social.tabChallenges)
        require(el(AX.social.challengeName), "global challenge card", timeout: 45)
        let join = el(AX.social.challengeJoin)
        if join.waitForExistence(timeout: 3) { join.tap() }          // already a member on re-runs
        require(el(AX.social.challengeView), "VIEW LEADERBOARD after joining", timeout: 30)
    }

    func testSocialHeaderOpensYourProfileAndActivity() {
        signInAsFrankie()
        tapID(AX.social.profile)
        require(labelContaining("@frankie"), "own handle on the profile page")
        tapID(AX.nav.back)
    }
}
