import Testing
import Foundation
@testable import PulsePump

/// Likes, comments, blocking, reporting, search, handles, stats sync and the no-fixtures guarantee.
@MainActor
struct InteractionTests {
    private func harnessWithPost(likes: Int = 2, comments: Int = 1) async -> SocialHarness {
        let h = SocialHarness()
        h.friend("a")
        h.post("p", by: "a", likes: likes, comments: comments)
        await h.vm.loadFeed()
        return h
    }

    // MARK: Likes (optimistic, rolled back on failure)

    @Test func likeIsOptimisticAndWritesTheLikeDocument() async {
        let h = await harnessWithPost()
        await h.vm.toggleLike(postId: "p")
        let item = h.vm.feedItems[0]
        #expect(item.likedByMe && item.likeCount == 3)
        #expect(h.remote.likes["p"] == ["me"])
        #expect(h.remote.log.contains("setLike:p:true"))
    }

    @Test func unlikeRemovesTheDocumentAndTheCount() async {
        let h = await harnessWithPost()
        await h.vm.toggleLike(postId: "p")
        await h.vm.toggleLike(postId: "p")
        let item = h.vm.feedItems[0]
        #expect(!item.likedByMe && item.likeCount == 2)
        #expect(h.remote.likes["p"]?.isEmpty == true)
    }

    @Test func aFailedLikeRollsBackTheHeartAndTheCount() async {
        let h = await harnessWithPost()
        h.remote.fail("setLike")
        await h.vm.toggleLike(postId: "p")
        let item = h.vm.feedItems[0]
        #expect(!item.likedByMe && item.likeCount == 2)
        #expect(h.vm.lastError != nil)
    }

    @Test func aFailedUnlikeRestoresTheLike() async {
        let h = await harnessWithPost()
        await h.vm.toggleLike(postId: "p")
        h.remote.fail("setLike")
        await h.vm.toggleLike(postId: "p")
        let item = h.vm.feedItems[0]
        #expect(item.likedByMe && item.likeCount == 3)
    }

    @Test func likingAnUnknownPostDoesNothing() async {
        let h = await harnessWithPost()
        await h.vm.toggleLike(postId: "nope")
        #expect(h.remote.log.allSatisfy { !$0.hasPrefix("setLike") })
    }

    // MARK: Comments

    @Test func commentCountGoesUpAtOnceAndTheCommentIsStored() async {
        let h = await harnessWithPost()
        #expect(await h.vm.postComment(postId: "p", text: "  nice session  "))
        #expect(h.vm.feedItems[0].commentCount == 2)                       // the card refreshes without a reload
        #expect(h.remote.comments["p"]?.first?.text == "nice session")
        #expect(h.vm.comments["p"]?.count == 1)
    }

    @Test func aFailedCommentRollsTheCountBackAndKeepsTheText() async {
        let h = await harnessWithPost()
        h.remote.fail("addComment")
        #expect(await h.vm.postComment(postId: "p", text: "hello") == false)
        #expect(h.vm.feedItems[0].commentCount == 1)
        #expect(h.vm.comments["p"]?.isEmpty != false)
        #expect(h.vm.lastError != nil)
    }

    @Test func emptyAndOversizedCommentsAreRejectedBeforeTheNetwork() async {
        let h = await harnessWithPost()
        #expect(await h.vm.postComment(postId: "p", text: "   ") == false)
        #expect(await h.vm.postComment(postId: "p", text: String(repeating: "x", count: 501)) == false)
        #expect(h.remote.log.allSatisfy { !$0.hasPrefix("addComment") })
        #expect(h.vm.feedItems[0].commentCount == 1)
    }

    @Test func deletingACommentRollsBackWhenItFails() async {
        let h = await harnessWithPost()
        _ = await h.vm.postComment(postId: "p", text: "first")
        let id = h.vm.comments["p"]![0].id
        h.remote.fail("deleteComment")
        #expect(await h.vm.deleteComment(postId: "p", commentId: id) == false)
        #expect(h.vm.comments["p"]?.count == 1 && h.vm.feedItems[0].commentCount == 2)
        h.remote.healAll()
        #expect(await h.vm.deleteComment(postId: "p", commentId: id))
        #expect(h.vm.comments["p"]?.isEmpty == true && h.vm.feedItems[0].commentCount == 1)
    }

    // MARK: Blocking

    @Test func blockingStoresTheNameRemovesTheFollowAndHidesThem() async {
        let h = SocialHarness()
        h.friend("b", name: "Bee", handle: "bee"); h.post("pb", by: "b")
        await h.vm.loadFeed()
        #expect(h.vm.feedItems.count == 1)
        #expect(await h.vm.block(uid: "b", name: "Bee", handle: "bee"))
        #expect(h.remote.blocked["b"]?.displayName == "Bee" && h.remote.blocked["b"]?.username == "bee")
        #expect(h.remote.log.contains("unfollow:b"))
        #expect(h.vm.feedItems.isEmpty && h.vm.friends.isEmpty)
        #expect(h.vm.blockedUsers.map(\.uid) == ["b"])
        #expect(h.vm.relationship(with: "b") == .blocked)
    }

    @Test func aBlockedUserCannotBeFollowedOrFound() async {
        let h = SocialHarness()
        h.remote.addProfile("b", name: "Bee", handle: "bee")
        _ = await h.vm.block(uid: "b", name: "Bee", handle: "bee")
        #expect(await h.vm.follow("b") == false)
        #expect(!h.remote.log.contains("follow:b"))
        await h.vm.searchUsers(query: "bee")
        #expect(h.vm.searchResults.isEmpty)
    }

    @Test func aFailedBlockChangesNothing() async {
        let h = SocialHarness()
        h.friend("b")
        await h.vm.loadGraph()
        h.remote.fail("block")
        #expect(await h.vm.block(uid: "b", name: "B", handle: "b") == false)
        #expect(h.vm.relationship(with: "b") == .friends && h.vm.blockedUsers.isEmpty)
    }

    @Test func unblockingBringsThemBack() async {
        let h = SocialHarness()
        h.friend("b")
        await h.vm.loadGraph()
        _ = await h.vm.block(uid: "b", name: "B", handle: "b")
        #expect(await h.vm.unblock(uid: "b"))
        #expect(h.remote.blocked.isEmpty && h.vm.blockedUsers.isEmpty)
        #expect(h.vm.relationship(with: "b") != .blocked)
    }

    @Test func blocksSurviveAReloadFromTheServer() async {
        let h = SocialHarness()
        h.friend("b")
        _ = await h.vm.block(uid: "b", name: "B", handle: "b")
        let fresh = h.relaunch()
        await fresh.loadGraph()
        #expect(fresh.blockedUsers.map(\.uid) == ["b"] && fresh.relationship(with: "b") == .blocked)
    }

    // MARK: Reporting

    @Test func reportingAPostSendsTheReportAndHidesIt() async {
        let h = await harnessWithPost()
        #expect(await h.vm.reportPost("p"))
        #expect(h.remote.reports.map(\.id) == ["p"] && h.remote.reports[0].target == .post)
        #expect(h.vm.feedItems.isEmpty)
        // Still hidden after a relaunch and a refresh.
        let again = h.relaunch()
        await again.loadFeed()
        #expect(again.feedItems.isEmpty)
    }

    @Test func aFailedReportKeepsThePostAndSaysSo() async {
        let h = await harnessWithPost()
        h.remote.fail("report")
        #expect(await h.vm.reportPost("p") == false)
        #expect(h.vm.feedItems.count == 1 && h.vm.lastError != nil)
    }

    @Test func userCommentAndChallengeReportsUseTheRightTargetTypes() async {
        let h = SocialHarness()
        _ = await h.vm.reportUser("u1")
        _ = await h.vm.reportComment(postId: "p", commentId: "c1")
        _ = await h.vm.reportChallenge("ch1")
        #expect(h.remote.reports.map(\.target) == [.user, .comment, .challenge])
        #expect(h.remote.reports.map(\.id) == ["u1", "p/c1", "ch1"])
    }

    // MARK: Search

    @Test func searchFindsAnExactHandleAndNothingElse() async {
        let h = SocialHarness()
        h.remote.addProfile("u1", name: "Sam", handle: "sam_lifts")
        await h.vm.searchUsers(query: "  @Sam_Lifts ")
        #expect(h.vm.searchResults.map(\.uid) == ["u1"] && h.vm.searchResults[0].profile?.displayName == "Sam")
        await h.vm.searchUsers(query: "sam")                              // a prefix is not a handle
        #expect(h.vm.searchResults.isEmpty)
    }

    @Test func invalidHandlesNeverHitTheNetwork() async {
        let h = SocialHarness()
        h.remote.fail("lookupUser")
        await h.vm.searchUsers(query: "ab")
        await h.vm.searchUsers(query: "has space")
        #expect(h.vm.searchResults.isEmpty && !h.vm.isSearching)
    }

    @Test func searchNeverReturnsMeAndShowsPrivateProfilesAsHandleOnly() async {
        let h = SocialHarness()
        h.remote.addProfile("me", name: "Me", handle: "my_handle")
        h.remote.addProfile("p", name: "Priv", handle: "priv_user", visibility: .onlyMe)
        await h.vm.searchUsers(query: "my_handle")
        #expect(h.vm.searchResults.isEmpty)
        await h.vm.searchUsers(query: "priv_user")
        #expect(h.vm.searchResults.count == 1 && h.vm.searchResults[0].profile == nil && h.vm.searchResults[0].handle == "priv_user")
    }

    // MARK: Handles

    @Test func handleRulesMatchTheSecurityRules() {
        #expect(HandleRules.normalize(" @Mixed.Case_1 ") == "mixed.case_1")
        #expect(HandleRules.isValid("abc") && HandleRules.isValid("a.b_c9") && HandleRules.isValid(String(repeating: "a", count: 20)))
        #expect(!HandleRules.isValid("ab") && !HandleRules.isValid(String(repeating: "a", count: 21)) && !HandleRules.isValid("no spaces") && !HandleRules.isValid("UPPER") && !HandleRules.isValid("emoji😀x"))
    }

    @Test func generatedHandlesAreAlwaysValidAndDistinct() {
        for hint in ["Vasanth S", "Zoë Müller", "A", "", "!!!", "x.y_z", String(repeating: "long", count: 20)] {
            let candidates = HandleRules.candidates(hint: hint, uid: "uid-123")
            #expect(candidates.allSatisfy(HandleRules.isValid), "invalid handle for \(hint)")
            #expect(Set(candidates).count == candidates.count)
        }
    }

    // MARK: Stats sync and identity

    @Test func ownStatsAreWrittenOnlyWhenTheyChange() async {
        let h = SocialHarness()
        await h.vm.loadMyProfile()
        await h.vm.syncOwnStats(streak: 4, totalWorkouts: 12)
        #expect(h.remote.profiles["me"]?.currentStreak == 4 && h.remote.profiles["me"]?.totalWorkouts == 12)
        let writes = h.remote.profileUpdates.count
        await h.vm.syncOwnStats(streak: 4, totalWorkouts: 12)
        #expect(h.remote.profileUpdates.count == writes)                    // unchanged: no write
        await h.vm.syncOwnStats(streak: 5, totalWorkouts: 12)
        #expect(h.remote.profileUpdates.last?.streak == 5 && h.remote.profileUpdates.last?.totalWorkouts == nil)
    }

    @Test func signingOutClearsTheSession() async {
        let h = await harnessWithPost()
        #expect(!h.vm.feedItems.isEmpty)
        h.user.uid = nil
        await h.vm.loadFeed()
        #expect(h.vm.feedItems.isEmpty && h.vm.friends.isEmpty && h.vm.myProfile == nil)
    }

    // MARK: No demo fixtures in production paths

    @Test func fixturesAreOffByDefault() {
        let empty = UserDefaults(suiteName: "flags-\(UUID().uuidString)")!
        #expect(DevFlags.socialFixtures(defaults: empty) == false)
        #expect(DevFlags.usesFirebaseEmulator(defaults: empty) == false)
    }

    @Test func fixturesNeverTurnOnWhileTheEmulatorIsInUse() {
        let d = UserDefaults(suiteName: "flags-\(UUID().uuidString)")!
        d.set(true, forKey: "devDataSocialFixtures")
        #expect(DevFlags.socialFixtures(defaults: d) == true)               // DEBUG fallback when no emulator
        d.set(true, forKey: "useFirebaseEmulator")
        #expect(DevFlags.socialFixtures(defaults: d) == false)              // -useFirebaseEmulator 1 wins
    }

    @Test func theViewModelHasNoBuiltInDemoData() async {
        let h = SocialHarness()
        await h.vm.loadMyProfile()
        await h.vm.loadGraph()
        await h.vm.loadFeed()
        await h.vm.loadChallenges()
        #expect(h.vm.friends.isEmpty && h.vm.fans.isEmpty && h.vm.feedItems.isEmpty)
        #expect(h.vm.myChallenges.isEmpty && h.vm.globalChallenges.isEmpty && h.vm.pendingChallengeInvites.isEmpty)
        #expect(h.vm.friendCount == 0 && h.vm.fanCount == 0)
    }
}
