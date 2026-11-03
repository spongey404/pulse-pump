import Testing
import Foundation
@testable import Ore

/// Feed query construction: chunking, pinned authorUid + audience, blocked users excluded, pagination.
@MainActor
struct FeedQueryTests {
    // MARK: Planner

    @Test func chunksFriendsAndPinsAudiences() {
        let friends = Set((1...25).map { "f\($0)" })
        let queries = FeedQueryPlanner.feedQueries(me: "me", friends: friends, blocked: [], before: nil)
        let others = queries.dropLast()
        #expect(others.map(\.authorUids.count) == [10, 10, 5])
        #expect(others.allSatisfy { $0.audiences == [.everyone, .friends] })
        #expect(Set(others.flatMap(\.authorUids)) == friends)
        // Firestore allows 30 disjunctions per query: authors x audiences.
        #expect(queries.allSatisfy { $0.authorUids.count * max(1, $0.audiences.count) <= 30 })
    }

    @Test func myOwnPostsAreAPinnedQueryOfTheirOwn() throws {
        let queries = FeedQueryPlanner.feedQueries(me: "me", friends: ["a"], blocked: [], before: nil)
        let own = try #require(queries.last)
        #expect(own.authorUids == ["me"])
        #expect(own.audiences.isEmpty)          // the owner may read every audience
        #expect(!queries.dropLast().contains { $0.authorUids.contains("me") })
    }

    @Test func blockedUsersAndMeNeverAppearInFriendChunks() {
        let queries = FeedQueryPlanner.feedQueries(me: "me", friends: ["a", "b", "me", "blocked"], blocked: ["blocked"], before: nil)
        let authors = Set(queries.dropLast().flatMap(\.authorUids))
        #expect(authors == ["a", "b"])
    }

    @Test func noFriendsStillQueriesMyOwnPosts() {
        let queries = FeedQueryPlanner.feedQueries(me: "me", friends: [], blocked: [], before: nil)
        #expect(queries.count == 1 && queries[0].authorUids == ["me"])
    }

    @Test func paginationCursorAndLimitAreCarriedOnEveryQuery() {
        let cursor = Date(timeIntervalSince1970: 1_700_000_000)
        let queries = FeedQueryPlanner.feedQueries(me: "me", friends: ["a", "b"], blocked: [], before: cursor, limit: 7)
        #expect(queries.allSatisfy { $0.before == cursor && $0.limit == 7 })
    }

    @Test func perAuthorSplitKeepsEverythingPinned() {
        let q = PostQuery(authorUids: ["a", "b", "c"], audiences: [.everyone, .friends], before: nil, limit: 20)
        let singles = FeedQueryPlanner.perAuthor(q)
        #expect(singles.map(\.authorUids) == [["a"], ["b"], ["c"]])
        #expect(singles.allSatisfy { $0.audiences == q.audiences && $0.limit == 20 })
    }

    @Test func audiencesFollowTheRelationship() {
        #expect(FeedQueryPlanner.audiences(for: .me).isEmpty)
        #expect(FeedQueryPlanner.audiences(for: .friends) == [.everyone, .friends])
        #expect(FeedQueryPlanner.audiences(for: .fan) == [.everyone])
        #expect(FeedQueryPlanner.audiences(for: .following) == [.everyone])
        #expect(FeedQueryPlanner.audiences(for: .stranger) == [.everyone])
    }

    @Test func mergeSortsDedupesAndDropsBlockedAndHidden() {
        func item(_ id: String, _ uid: String, _ age: Double) -> WorkoutFeedItem {
            let d = Date(timeIntervalSince1970: 1_700_000_000 - age)
            return WorkoutFeedItem(id: id, userId: uid, username: uid, exerciseCount: 0, durationSeconds: 0, date: d, createdAt: d)
        }
        let merged = FeedQueryPlanner.merge([[item("1", "a", 30), item("2", "b", 10)], [item("2", "b", 10), item("3", "x", 5), item("4", "a", 20)]],
                                            blocked: ["x"], hidden: ["4"], limit: 10)
        #expect(merged.map(\.id) == ["2", "1"])
        #expect(FeedQueryPlanner.merge([[item("1", "a", 1), item("2", "a", 2)]], limit: 1).map(\.id) == ["1"])
    }

    // MARK: View model against the rule-emulating fake

    @Test func feedShowsFriendsAndMyPostsOnly() async {
        let h = SocialHarness()
        h.friend("a")
        h.remote.addProfile("stranger", name: "Stranger", handle: "stranger")
        h.post("p-friend", by: "a", audience: .friends, ageMinutes: 5)
        h.post("p-public", by: "a", audience: .everyone, ageMinutes: 10)
        h.post("p-mine", by: "me", audience: .onlyMe, ageMinutes: 1)
        h.post("p-stranger", by: "stranger", audience: .everyone, ageMinutes: 2)
        await h.vm.loadFeed()
        #expect(h.vm.feedItems.map(\.id) == ["p-mine", "p-friend", "p-public"])
        #expect(h.vm.feedError == nil)
    }

    @Test func everyQueryIsPinnedToAuthorAndAudience() async {
        let h = SocialHarness()
        for i in 1...12 { h.friend("f\(i)") }
        h.post("p", by: "f1")
        await h.vm.loadFeed()
        #expect(!h.remote.postQueries.isEmpty)
        for q in h.remote.postQueries {
            #expect(!q.authorUids.isEmpty)
            if q.authorUids != ["me"] {
                #expect(!q.audiences.isEmpty && !q.audiences.contains(.onlyMe))   // never asks for someone else's private posts
            }
        }
    }

    @Test func blockedAuthorsAreNeverQueriedOrShown() async {
        let h = SocialHarness()
        h.friend("a"); h.friend("b")
        h.post("pa", by: "a"); h.post("pb", by: "b")
        await h.vm.loadGraph()
        #expect(await h.vm.block(uid: "b", name: "B", handle: "b"))
        h.remote.makeFriends("me", "b")                      // even if a stale follow edge remains
        let before = h.remote.postQueries.count
        await h.vm.loadFeed(forceRefresh: true)
        #expect(h.vm.feedItems.map(\.id) == ["pa"])
        #expect(!h.remote.postQueries.dropFirst(before).flatMap(\.authorUids).contains("b"))
    }

    @Test func paginationWalksBackwardsWithoutDuplicates() async {
        let h = SocialHarness()
        h.friend("a")
        for i in 0..<45 { h.post("p\(i)", by: "a", ageMinutes: Double(i + 1)) }
        await h.vm.loadFeed()
        #expect(h.vm.feedItems.count == 20 && h.vm.hasMoreFeed)
        await h.vm.loadMoreFeed()
        #expect(h.vm.feedItems.count == 40 && h.vm.hasMoreFeed)
        await h.vm.loadMoreFeed()
        #expect(h.vm.feedItems.count == 45 && !h.vm.hasMoreFeed)
        #expect(Set(h.vm.feedItems.map(\.id)).count == 45)
        let dates = h.vm.feedItems.map(\.createdAt)
        #expect(dates == dates.sorted(by: >))
        // The second page's queries carry the cursor of the last item of the first.
        #expect(h.remote.postQueries.contains { $0.before != nil })
    }

    @Test func rejectedMultiAuthorQueriesFallBackToPerAuthor() async {
        let h = SocialHarness()
        h.friend("a"); h.friend("b")
        h.post("pa", by: "a", ageMinutes: 2); h.post("pb", by: "b", ageMinutes: 1)
        h.remote.rejectsMultiAuthorQueries = true
        await h.vm.loadFeed()
        #expect(Set(h.vm.feedItems.map(\.id)) == ["pa", "pb"])
        #expect(h.remote.postQueries.contains { $0.authorUids.count == 1 && $0.authorUids != ["me"] })
        // Remembered for the session: the next refresh does not retry the multi-author form.
        let before = h.remote.postQueries.count
        await h.vm.loadFeed(forceRefresh: true)
        #expect(h.remote.postQueries.dropFirst(before).allSatisfy { $0.authorUids.count == 1 })
    }

    @Test func oneUnreadableAuthorDoesNotBlankTheFeed() async {
        let h = SocialHarness()
        h.friend("a"); h.friend("b")
        h.post("pa", by: "a")
        h.remote.blockedMe.insert("b")      // b blocked me: any query naming b is refused by the rules
        await h.vm.loadFeed()
        #expect(h.vm.feedItems.map(\.id) == ["pa"])
    }

    @Test func feedIsCachedForFiveMinutesAndRefreshForcesTheNetwork() async {
        let h = SocialHarness()
        h.friend("a"); h.post("p", by: "a")
        await h.vm.loadFeed()
        let first = h.remote.postQueries.count
        await h.vm.loadFeed()
        #expect(h.remote.postQueries.count == first)                 // within the TTL
        h.clock.advance(SocialViewModel.cacheTTL + 1)
        await h.vm.loadFeed()
        #expect(h.remote.postQueries.count > first)                  // expired
        let second = h.remote.postQueries.count
        await h.vm.loadFeed(forceRefresh: true)
        #expect(h.remote.postQueries.count > second)                 // pull to refresh
    }

    @Test func aFailedLoadIsAnErrorNotDemoData() async {
        let h = SocialHarness()
        h.friend("a"); h.post("p", by: "a")
        h.remote.fail("fetchPosts")
        await h.vm.loadFeed()
        #expect(h.vm.feedItems.isEmpty)
        #expect(h.vm.feedError != nil)
    }

    @Test func aNewUserSeesAnEmptyFeedNotFixtures() async {
        let h = SocialHarness()
        await h.vm.loadFeed()
        await h.vm.loadChallenges()
        #expect(h.vm.feedItems.isEmpty && h.vm.friends.isEmpty && h.vm.myChallenges.isEmpty && h.vm.globalChallenge == nil)
    }

    @Test func hydrationAddsMyLikeAndAuthorizedBodyMaps() async {
        let h = SocialHarness()
        h.friend("a")
        h.post("p1", by: "a", audience: .friends, bodyMapAudience: .friends, bodyMap: ["Chest": 9])
        h.post("p2", by: "a", audience: .friends, bodyMapAudience: .onlyMe, bodyMap: ["Back": 4])
        h.remote.likes["p1"] = ["me"]
        await h.vm.loadFeed()
        let p1 = h.vm.feedItems.first { $0.id == "p1" }
        let p2 = h.vm.feedItems.first { $0.id == "p2" }
        #expect(p1?.likedByMe == true && p1?.muscleSets == ["Chest": 9])
        #expect(p2?.likedByMe == false && p2?.includesBodyMap == false)   // the author hid the body map
    }

    @Test func signedOutUsersGetNoFeedAndNoQueries() async {
        let h = SocialHarness(signedIn: false)
        await h.vm.loadFeed()
        #expect(h.vm.feedItems.isEmpty && h.remote.postQueries.isEmpty)
    }
}
