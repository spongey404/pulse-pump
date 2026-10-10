import Testing
import Foundation
@testable import PulsePump

/// Posts, audiences, the real feed queries, likes and comments (counters come from Cloud Functions).
@Suite("Feed and posts against the emulator", .emulator, .serialized)
@MainActor
struct SocialFeedEmulatorTests {
    private func publish(_ account: TestAccount, audience: PostAudience = .friends, name: String = "Push Day",
                         bodyMapAudience: PostAudience = .friends, muscles: [String: Int]? = nil) async throws -> String {
        let payload = IntegrationData.post(by: account, audience: audience, bodyMapAudience: bodyMapAudience, name: name, muscleSets: muscles)
        try await account.social.createPost(payload)
        try? await Task.sleep(for: .milliseconds(30))   // distinct server-side createdAt values for ordering
        return payload.postId
    }

    private func postCount(_ id: String, _ field: String, as viewer: TestAccount) async -> Int? {
        (try? await viewer.document("posts/\(id)"))?[field] as? Int
    }

    // MARK: Create and read

    @Test func aPostRoundTripsItsStatsAndExercises() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await publish(ada, audience: .everyone, name: "Heavy Bench")
            let mine = try await ada.social.fetchPosts(PostQuery(authorUids: [ada.uid], audiences: [], before: nil, limit: 10))
            let post = try #require(mine.first)
            #expect(mine.count == 1 && post.id == id && post.templateName == "Heavy Bench")
            #expect(post.userId == ada.uid && post.handle == ada.handle)
            #expect(post.exercises.count == 1 && post.exercises[0].sets.count == 3)
            #expect(post.durationSeconds == 3_300 && post.prCount == 1)
            #expect(post.likeCount == 0 && post.commentCount == 0)
        }
    }

    @Test func anEveryonePostIsVisibleToAStranger() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let sid = try await world.account("sid", profile: true)
            let id = try await publish(ada, audience: .everyone)
            let seen = try await sid.social.fetchPosts(FeedQueryPlanner.profileQuery(author: ada.uid, relationship: .stranger))
            #expect(seen.map(\.id) == [id])
        }
    }

    @Test func aFriendsPostIsVisibleToAFriendButNotToAStranger() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let fay = try await world.account("fay", profile: true)
            let sid = try await world.account("sid", profile: true)
            try await ada.befriend(fay)
            let id = try await publish(ada, audience: .friends)

            let asFriend = try await fay.social.fetchPosts(FeedQueryPlanner.profileQuery(author: ada.uid, relationship: .friends))
            #expect(asFriend.map(\.id) == [id])
            // The stranger's honest query (everyone only) simply finds nothing...
            let asStranger = try await sid.social.fetchPosts(FeedQueryPlanner.profileQuery(author: ada.uid, relationship: .stranger))
            #expect(asStranger.isEmpty)
            // ...and asking for the friends audience is refused outright.
            await #expect(throws: SocialError.permissionDenied) {
                _ = try await sid.social.fetchPosts(PostQuery(authorUids: [ada.uid], audiences: [.friends], before: nil, limit: 10))
            }
        }
    }

    @Test func anOnlyMePostNeverReachesAFriendButTheAuthorSeesIt() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let fay = try await world.account("fay", profile: true)
            try await ada.befriend(fay)
            let id = try await publish(ada, audience: .onlyMe)
            #expect(try await fay.social.fetchPosts(FeedQueryPlanner.profileQuery(author: ada.uid, relationship: .friends)).isEmpty)
            #expect(try await ada.social.fetchPosts(FeedQueryPlanner.profileQuery(author: ada.uid, relationship: .me)).map(\.id) == [id])
            await #expect(throws: SocialError.permissionDenied) {
                _ = try await fay.social.fetchPosts(PostQuery(authorUids: [ada.uid], audiences: [.onlyMe], before: nil, limit: 10))
            }
        }
    }

    // MARK: The multi-author feed query

    @Test func theMultiAuthorFeedQueryIsAcceptedByTheRules() async throws {
        try await Emulator.isolated { world in
            let me = try await world.account("meg", profile: true)
            let fay = try await world.account("fay", profile: true)
            let gus = try await world.account("gus", profile: true)
            let sid = try await world.account("sid", profile: true)   // not a friend
            try await me.befriend(fay); try await me.befriend(gus)

            let fayFriends = try await publish(fay, audience: .friends)
            let fayOnlyMe = try await publish(fay, audience: .onlyMe)
            let gusEveryone = try await publish(gus, audience: .everyone)
            let sidEveryone = try await publish(sid, audience: .everyone)
            let mineOnlyMe = try await publish(me, audience: .onlyMe)

            let queries = FeedQueryPlanner.feedQueries(me: me.uid, friends: [fay.uid, gus.uid], blocked: [], before: nil)
            #expect(queries.first?.authorUids.count == 2, "one `in` query covers both friends")
            var pages: [[WorkoutFeedItem]] = []
            for query in queries { pages.append(try await me.social.fetchPosts(query)) }   // must not throw: no per-author fallback needed
            let feed = FeedQueryPlanner.merge(pages)

            #expect(feed.map(\.id) == [mineOnlyMe, gusEveryone, fayFriends], "newest first, friends' non-private posts + mine")
            #expect(!feed.map(\.id).contains(fayOnlyMe) && !feed.map(\.id).contains(sidEveryone))
        }
    }

    @Test func theViewModelBuildsTheFeedFromTheRealQueriesWithoutTheSingleAuthorFallback() async throws {
        try await Emulator.isolated { world in
            let me = try await world.account("meg", profile: true)
            let fay = try await world.account("fay", profile: true)
            let gus = try await world.account("gus", profile: true)
            try await me.befriend(fay); try await me.befriend(gus)
            let a = try await publish(fay, audience: .friends)
            let b = try await publish(gus, audience: .everyone)

            let defaults = UserDefaults(suiteName: "feed-it-\(UUID().uuidString)")!
            let user = FirebaseCurrentUser(auth: me.client.auth)
            let privacy = PrivacyService(remote: me.social, me: user, defaults: defaults, displayName: { "Meg" })
            let vm = SocialViewModel(remote: me.social, me: user, privacy: privacy, defaults: defaults,
                                     displayName: { "Meg" }, onFeedLoaded: { _, _ in })
            await vm.loadFeed(forceRefresh: true)
            #expect(vm.feedError == nil)
            #expect(Set(vm.feedItems.map(\.id)) == [a, b])
        }
    }

    @Test func anAuthorWhoBlockedMeMakesTheWholeMultiAuthorChunkFail() async throws {
        try await Emulator.isolated { world in
            let me = try await world.account("meg", profile: true)
            let fay = try await world.account("fay", profile: true)
            let gus = try await world.account("gus", profile: true)
            try await me.befriend(fay); try await me.befriend(gus)
            _ = try await publish(fay); _ = try await publish(gus)
            try await fay.social.block(BlockedUser(uid: me.uid, username: me.handle, displayName: "Meg", createdAt: Date()))

            // This is why the planner excludes blocked users and the view model retries author by author.
            let chunk = PostQuery(authorUids: [fay.uid, gus.uid].sorted(), audiences: FeedQueryPlanner.friendAudiences, before: nil, limit: 20)
            await #expect(throws: SocialError.permissionDenied) { _ = try await me.social.fetchPosts(chunk) }
            let perAuthor = FeedQueryPlanner.perAuthor(chunk)
            var readable: [String] = []
            for query in perAuthor { if let page = try? await me.social.fetchPosts(query) { readable += page.map(\.userId) } }
            #expect(readable == [gus.uid])
        }
    }

    @Test func feedPagingWithABeforeCursorReturnsOlderPostsOnly() async throws {
        try await Emulator.isolated { world in
            let me = try await world.account("meg", profile: true)
            let fay = try await world.account("fay", profile: true)
            try await me.befriend(fay)
            var ids: [String] = []
            for _ in 0..<5 { ids.append(try await publish(fay)) }

            let first = try await me.social.fetchPosts(PostQuery(authorUids: [fay.uid], audiences: FeedQueryPlanner.friendAudiences, before: nil, limit: 3))
            #expect(first.map(\.id) == Array(ids.reversed().prefix(3)))
            let cursor = try #require(first.last?.createdAt)
            let next = try await me.social.fetchPosts(PostQuery(authorUids: [fay.uid], audiences: FeedQueryPlanner.friendAudiences, before: cursor, limit: 3))
            #expect(next.map(\.id) == Array(ids.reversed().suffix(2)))
        }
    }

    // MARK: Likes and comments

    @Test func likesAreCountedByTheFunctionAndUnlikeUndoesIt() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let fay = try await world.account("fay", profile: true)
            let gus = try await world.account("gus", profile: true)
            try await ada.befriend(fay); try await ada.befriend(gus)
            let id = try await publish(ada)

            try await fay.social.setLike(postId: id, liked: true)
            try await gus.social.setLike(postId: id, liked: true)
            #expect(await Emulator.eventually { await postCount(id, "likeCount", as: ada) == 2 })
            #expect(try await fay.social.likedPostIds(among: [id]) == [id])

            try await fay.social.setLike(postId: id, liked: false)
            #expect(await Emulator.eventually { await postCount(id, "likeCount", as: ada) == 1 })
            #expect(try await fay.social.likedPostIds(among: [id]).isEmpty)
        }
    }

    @Test func commentsAreCountedListedInOrderAndDeletable() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let fay = try await world.account("fay", profile: true)
            try await ada.befriend(fay)
            let id = try await publish(ada)

            let first = try await fay.social.addComment(postId: id, text: "  Strong session  ", authorName: "Fay", authorUsername: fay.handle)
            try? await Task.sleep(for: .milliseconds(30))
            _ = try await ada.social.addComment(postId: id, text: "Thanks!", authorName: "Ada", authorUsername: ada.handle)
            #expect(await Emulator.eventually { await postCount(id, "commentCount", as: ada) == 2 })

            let listed = try await ada.social.fetchComments(postId: id, limit: 10)
            #expect(listed.map(\.text) == ["Strong session", "Thanks!"])

            try await fay.social.deleteComment(postId: id, commentId: first.id)
            #expect(await Emulator.eventually { await postCount(id, "commentCount", as: ada) == 1 })
            #expect(try await ada.social.fetchComments(postId: id, limit: 10).map(\.text) == ["Thanks!"])
        }
    }

    @Test func aStrangerCannotLikeOrCommentOnAFriendsOnlyPost() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let sid = try await world.account("sid", profile: true)
            let id = try await publish(ada, audience: .friends)
            await #expect(throws: SocialError.permissionDenied) { try await sid.social.setLike(postId: id, liked: true) }
            await #expect(throws: SocialError.permissionDenied) {
                _ = try await sid.social.addComment(postId: id, text: "hi", authorName: "Sid", authorUsername: sid.handle)
            }
        }
    }

    @Test func republishingTheSameWorkoutIsIdempotentAndKeepsTheLikeCount() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let fay = try await world.account("fay", profile: true)
            try await ada.befriend(fay)
            let payload = IntegrationData.post(by: ada, audience: .friends, caption: "first")
            try await ada.social.createPost(payload)
            try await fay.social.setLike(postId: payload.postId, liked: true)
            #expect(await Emulator.eventually { await postCount(payload.postId, "likeCount", as: ada) == 1 })

            var edited = payload; edited.caption = "second"
            try await ada.social.createPost(edited)   // merge write: the function-owned counter must survive
            let doc = try #require(try await ada.document("posts/\(payload.postId)"))
            #expect(doc["caption"] as? String == "second" && doc["likeCount"] as? Int == 1)
        }
    }

    // MARK: Body map and deletion

    @Test func theBodyMapExtrasFollowTheirOwnAudience() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let fay = try await world.account("fay", profile: true)
            let sid = try await world.account("sid", profile: true)
            try await ada.befriend(fay)
            let id = try await publish(ada, audience: .everyone, bodyMapAudience: .friends, muscles: ["chest": 6, "triceps": 3])

            #expect(try await ada.social.fetchBodyMap(postId: id) == ["chest": 6, "triceps": 3])
            #expect(try await fay.social.fetchBodyMap(postId: id) == ["chest": 6, "triceps": 3])
            #expect(try await sid.social.fetchBodyMap(postId: id) == nil, "a stranger can read the post but not its body map")
        }
    }

    @Test func deletingAPostRemovesItAndItsBodyMap() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await publish(ada, audience: .everyone, muscles: ["chest": 4])
            try await ada.social.deletePost(id: id)
            #expect(await Emulator.adminDocumentExists("posts/\(id)") == false)
            #expect(await Emulator.adminDocumentExists("posts/\(id)/extras/bodymap") == false)
            #expect(try await ada.social.fetchPosts(PostQuery(authorUids: [ada.uid], audiences: [], before: nil, limit: 10)).isEmpty)
        }
    }
}
