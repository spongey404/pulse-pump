import Testing
import Foundation
@testable import PulsePump

/// Friends = mutual follow, one-way follower = fan. ACCEPT = follow back, IGNORE = dismiss.
@MainActor
struct FriendGraphTests {
    // MARK: Derivation matrix

    @Test(arguments: [
        (false, false, Relationship.stranger),
        (true, false, Relationship.following),
        (false, true, Relationship.fan),
        (true, true, Relationship.friends),
    ])
    func relationshipMatrix(iFollow: Bool, theyFollow: Bool, expected: Relationship) {
        let g = FriendGraph(following: iFollow ? ["x"] : [], followers: theyFollow ? ["x"] : [])
        #expect(g.relationship(with: "x", me: "me") == expected)
        #expect(g.friends.contains("x") == (expected == .friends))
        #expect(g.fans.contains("x") == (expected == .fan))
        #expect(g.pendingOutgoing.contains("x") == (expected == .following))
    }

    @Test func listsAreDerivedFromBothDirections() {
        let g = FriendGraph(following: ["a", "b", "c"], followers: ["b", "c", "d", "e"])
        #expect(g.friends == ["b", "c"])
        #expect(g.fans == ["d", "e"])
        #expect(g.pendingOutgoing == ["a"])
    }

    @Test func edgesBuildTheGraph() {
        let now = Date()
        let g = FriendGraph(following: [FollowEdge(followerUid: "me", followeeUid: "a", createdAt: now)],
                            followers: [FollowEdge(followerUid: "a", followeeUid: "me", createdAt: now),
                                        FollowEdge(followerUid: "b", followeeUid: "me", createdAt: now)])
        #expect(g.friends == ["a"] && g.fans == ["b"])
    }

    @Test func meAndBlockedAreSpecialRelationships() {
        var g = FriendGraph(following: ["x"], followers: ["x"])
        #expect(g.relationship(with: "me", me: "me") == .me)
        g.block("x")
        #expect(g.relationship(with: "x", me: "me") == .blocked)
    }

    // MARK: Accept / ignore

    @Test func acceptFollowsBackAndMakesFriends() {
        var g = FriendGraph(followers: ["fan"])
        #expect(g.fanRequests == ["fan"])
        let followed = g.follow("fan")
        #expect(followed)
        #expect(g.friends == ["fan"])
        #expect(g.fans.isEmpty && g.fanRequests.isEmpty)
    }

    @Test func ignoreDismissesButTheyStayAFan() {
        var g = FriendGraph(followers: ["fan"])
        g.ignoreFan("fan")
        #expect(g.fanRequests.isEmpty)
        #expect(g.fans == ["fan"])          // still counts as a fan
        #expect(g.friends.isEmpty)
        #expect(g.following.isEmpty)        // nothing was written
    }

    @Test func ignoreOnlyAppliesToFans() {
        var g = FriendGraph(following: ["f"], followers: ["f"])
        g.ignoreFan("f")
        #expect(g.dismissedFans.isEmpty)
        #expect(g.friends == ["f"])
    }

    @Test func followingBackAfterIgnoreStillWorks() {
        var g = FriendGraph(followers: ["fan"])
        g.ignoreFan("fan")
        g.follow("fan")
        #expect(g.friends == ["fan"])
        #expect(g.dismissedFans.isEmpty)
    }

    @Test func unfollowingAFriendLeavesAFan() {
        var g = FriendGraph(following: ["f"], followers: ["f"])
        g.unfollow("f")
        #expect(g.fans == ["f"] && g.friends.isEmpty)
        #expect(g.fanRequests == ["f"])
    }

    // MARK: Blocking

    @Test func blockedUsersVanishFromEveryListAndCannotBeFollowed() {
        var g = FriendGraph(following: ["f", "o"], followers: ["f", "fan"])
        g.block("f"); g.block("fan")
        #expect(g.friends.isEmpty && g.fans.isEmpty && g.fanRequests.isEmpty)
        #expect(g.pendingOutgoing == ["o"])
        let followedBlocked = g.follow("fan")
        #expect(!followedBlocked)
        #expect(!g.following.contains("fan"))
        g.unblock("fan")
        #expect(g.fans == ["fan"])
    }

    // MARK: View model (loads the graph from the remote)

    @Test func viewModelListsFriendsFansAndWaiting() async {
        let h = SocialHarness()
        h.friend("a")
        h.remote.addProfile("b", name: "Bea", handle: "bea"); h.remote.setFollow("b", follows: "me")
        h.remote.addProfile("c", name: "Cy", handle: "cy"); h.remote.setFollow("me", follows: "c")
        await h.vm.loadGraph()
        #expect(h.vm.friends.map(\.uid) == ["a"])
        #expect(h.vm.fans.map(\.uid) == ["b"])
        #expect(h.vm.followingOnly.map(\.uid) == ["c"])
        #expect(h.vm.friendCount == 1 && h.vm.fanCount == 1)
        #expect(h.vm.inboxCount == 1)
    }

    @Test func acceptWritesAFollowAndMakesFriends() async {
        let h = SocialHarness()
        h.remote.addProfile("b", name: "Bea", handle: "bea"); h.remote.setFollow("b", follows: "me")
        await h.vm.loadGraph()
        #expect(await h.vm.accept("b"))
        #expect(h.remote.log.contains("follow:b"))
        #expect(h.vm.friends.map(\.uid) == ["b"])
        #expect(h.vm.fanRequests.isEmpty)
    }

    @Test func ignoreWritesNothingAndSurvivesARelaunch() async {
        let h = SocialHarness()
        h.remote.addProfile("b", name: "Bea", handle: "bea"); h.remote.setFollow("b", follows: "me")
        await h.vm.loadGraph()
        h.vm.ignore("b")
        #expect(h.remote.log.isEmpty)                       // no follow, no unfollow, no delete
        #expect(h.vm.fanRequests.isEmpty && h.vm.fans.map(\.uid) == ["b"])

        let again = h.relaunch()
        await again.loadGraph()
        #expect(again.fanRequests.isEmpty && again.fans.map(\.uid) == ["b"])
    }

    @Test func failedFollowRollsBack() async {
        let h = SocialHarness()
        h.remote.addProfile("z", name: "Zed", handle: "zed")
        await h.vm.loadGraph()
        h.remote.fail("follow")
        #expect(await h.vm.follow("z") == false)
        #expect(h.vm.relationship(with: "z") == .stranger)
        #expect(h.vm.lastError != nil)
    }

    @Test func cannotFollowYourself() async {
        let h = SocialHarness()
        #expect(await h.vm.follow("me") == false)
        #expect(h.remote.log.isEmpty)
    }

    @Test func deletedAccountsDropOutOfTheLists() async {
        let h = SocialHarness()
        h.friend("alive")
        h.remote.makeFriends("me", "ghost")        // follow edges exist, but the profile is gone
        await h.vm.loadGraph()
        #expect(h.vm.friends.map(\.uid) == ["alive"])
        #expect(h.vm.friendCount == 1)
        #expect(h.vm.goneUids == ["ghost"])
    }

    @Test func privateFriendProfileShowsAsPlaceholder() async {
        let h = SocialHarness()
        h.friend("priv"); h.remote.privateUids.insert("priv")
        await h.vm.loadGraph()
        #expect(h.vm.friends.count == 1 && h.vm.friends[0].isRestricted)
    }

    @Test func switchingAccountsClearsEverything() async {
        let h = SocialHarness()
        h.friend("a")
        await h.vm.loadGraph()
        #expect(h.vm.friends.count == 1)
        h.user.uid = "other"
        h.remote.meUid = "other"
        await h.vm.loadGraph()
        #expect(h.vm.friends.isEmpty)
    }
}
