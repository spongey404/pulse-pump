import Testing
import Foundation
@testable import Ore

/// Every document the client writes must satisfy `firebase/firestore.rules` and must never carry a
/// function-owned counter. The allowed key sets below are copied from the rules' `hasOnly` lists.
@MainActor
struct WireFormatTests {
    private typealias T = SocialTestData
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let counters: Set<String> = ["likeCount", "commentCount", "friendCount", "fanCount", "memberCount"]

    private func keys(_ doc: [String: Any]) -> Set<String> { Set(doc.keys) }

    private func payload(sets: [String: Int]? = ["Chest": 3]) -> PostPayload {
        PostPayload(postId: "w1", authorUid: "me", authorName: "Me", authorUsername: "me_m", date: now, workoutName: "Push",
                    audience: .friends, bodyMapAudience: .friends,
                    stats: .init(sets: 3, volumeKg: 1500, durationSec: 3000, prCount: 1),
                    exercises: [T.exercise("Bench", sets: [T.set(100, 5)])], caption: "hi", taggedUids: ["f1"], muscleSets: sets)
    }

    // MARK: Posts

    @Test func postDocumentMatchesTheRulesAndHasNoCounters() {
        let allowed: Set<String> = ["authorUid", "authorName", "authorUsername", "date", "workoutName", "audience", "bodyMapAudience", "stats",
                                    "exercises", "likeCount", "commentCount", "createdAt", "caption", "workoutId", "taggedUids", "schemaVersion", "updatedAt"]
        let doc = SocialWire.postDocument(payload(), now: now)
        #expect(keys(doc).isSubset(of: allowed))
        #expect(keys(doc).isDisjoint(with: Self.counters))
        #expect(["authorName", "authorUsername", "date", "workoutName", "audience", "bodyMapAudience", "stats", "exercises", "createdAt", "schemaVersion"]
            .allSatisfy { doc[$0] != nil })
        #expect(doc["audience"] as? String == "friends")
        let stats = doc["stats"] as? [String: Any] ?? [:]
        #expect(keys(stats) == ["sets", "volumeKg", "durationSec", "prCount"])
    }

    @Test func postDocumentOmitsEmptyOptionalFields() {
        var p = payload(); p.caption = ""; p.taggedUids = []
        let doc = SocialWire.postDocument(p, now: now)
        #expect(doc["caption"] == nil && doc["taggedUids"] == nil)
    }

    @Test func postExercisesAreCappedAtSixty() {
        var p = payload()
        p.exercises = (0..<75).map { T.exercise("E\($0)", sets: [T.set(10, 5)]) }
        #expect((SocialWire.postDocument(p, now: now)["exercises"] as? [Any])?.count == 60)
    }

    @Test func bodyMapDocumentIsAnIsolatedMuscleMap() {
        let doc = SocialWire.bodyMapDocument(["Chest": 9], now: now)
        #expect(keys(doc) == ["muscleSets", "schemaVersion", "updatedAt"])
        // The post itself never mentions muscles.
        let post = SocialWire.postDocument(payload(), now: now)
        #expect(post["muscleSets"] == nil)
    }

    @Test func postParsingReadsCountersFromTheDocumentOnly() throws {
        var doc = SocialWire.postDocument(payload(), now: now)
        doc["likeCount"] = 5; doc["commentCount"] = 2          // written by the functions
        let item = try #require(SocialWire.post(from: doc, id: "w1"))
        #expect(item.likeCount == 5 && item.commentCount == 2)
        #expect(item.username == "Me" && item.handle == "me_m" && item.audience == "friends")
        #expect(item.exercises.first?.sets.first?.weight == 100)
        #expect(item.includesBodyMap == false)                  // comes from extras, not the post
    }

    // MARK: Social graph and reactions

    @Test func followBlockLikeCommentReportShapes() {
        #expect(keys(SocialWire.followDocument(follower: "a", followee: "b", now: now)) == ["followerUid", "followeeUid", "createdAt"])
        #expect(SocialWire.followId(follower: "a", followee: "b") == "a_b")
        #expect(keys(SocialWire.likeDocument(uid: "a", now: now)) == ["uid", "createdAt"])
        #expect(keys(SocialWire.commentDocument(authorUid: "a", authorName: "A", authorUsername: "a_a", text: "t", now: now))
            .isSubset(of: ["authorUid", "authorName", "authorUsername", "text", "createdAt", "schemaVersion"]))
        let blocked = SocialWire.blockedDocument(BlockedUser(uid: "b", username: "bee", displayName: "Bee", createdAt: now))
        #expect(blocked.count <= 3 && blocked["createdAt"] != nil)        // the rules cap blocked docs at 3 keys
        let report = SocialWire.reportDocument(reporter: "a", target: .post, targetId: "p1", reason: "spam", details: nil, now: now)
        #expect(keys(report).isSubset(of: ["reporterUid", "targetType", "targetId", "reason", "createdAt", "details"]))
        #expect(report["targetType"] as? String == "post")
    }

    // MARK: Challenges and invites

    @Test func challengeCreateIsNonGlobalActiveAndWithoutMemberCount() {
        let draft = ChallengeDraft(name: " Bench 100 ", metric: .heaviestLift, exerciseName: "Bench Press",
                                   startAt: now, endAt: now.addingTimeInterval(86_400 * 28))
        let doc = SocialWire.challengeDocument(draft, creator: "me", now: now)
        let allowed: Set<String> = ["creatorUid", "name", "metric", "exerciseName", "startAt", "endAt", "isGlobal", "visibility", "status",
                                    "memberCount", "winCondition", "unit", "customLabel", "schemaVersion", "createdAt", "updatedAt"]
        #expect(keys(doc).isSubset(of: allowed))
        #expect(doc["isGlobal"] as? Bool == false)
        #expect(doc["status"] as? String == "active")
        #expect(doc["memberCount"] == nil)
        #expect(doc["name"] as? String == "Bench 100")
        #expect(["totalVolume", "heaviestLift", "mostReps", "longestHold", "sessionsLogged", "custom"].contains(doc["metric"] as? String ?? ""))
        #expect(["friends", "invite", "public"].contains(doc["visibility"] as? String ?? ""))
    }

    @Test func memberAndInviteShapesAndIdFormat() {
        #expect(keys(SocialWire.memberDocument(uid: "me", username: "me_m", now: now)) == ["uid", "username", "joinedAt", "schemaVersion"])
        let invite = ChallengeInvite(challengeId: "ch1", challengeName: "Bench", fromUid: "me", fromUsername: "me_m", toUid: "bob", createdAt: now)
        #expect(invite.id == "ch1_bob")
        #expect(ChallengeInvite.docId(challengeId: "c", toUid: "u") == "c_u")
        let doc = SocialWire.inviteDocument(invite)
        #expect(keys(doc).isSubset(of: ["challengeId", "fromUid", "toUid", "status", "createdAt", "challengeName", "fromUsername", "schemaVersion"]))
        #expect(doc["status"] as? String == "pending")
    }

    @Test func entriesAreParsedWithTheFunctionsFields() {
        let e = SocialWire.entry(from: ["uid": "u", "username": "u_u", "score": 120.5, "rank": 2, "previousRank": 3, "scoreAt": now, "hidden": false], id: "u")
        #expect(e.score == 120.5 && e.rank == 2 && e.previousRank == 3 && e.scoreAt == now && !e.hidden)
    }

    // MARK: Profiles and privacy

    @Test func profileCreateAndUpdateNeverWriteCounters() {
        let allowed: Set<String> = ["displayName", "username", "streak", "totalWorkouts", "friendCount", "fanCount", "profileVisibility",
                                    "globalLeaderboardVisible", "updatedAt", "createdAt", "avatarColor", "schemaVersion"]
        let create = SocialWire.newProfileDocument(name: "Me", handle: "me_m", privacy: .default, now: now)
        #expect(keys(create).isSubset(of: allowed) && keys(create).isDisjoint(with: ["friendCount", "fanCount"]))
        #expect(create["profileVisibility"] as? String == "everyone" && create["globalLeaderboardVisible"] as? Bool == true)

        let update = SocialWire.profileUpdateDocument(ProfileUpdate(displayName: "N", streak: 4, totalWorkouts: 10,
                                                                    profileVisibility: .friends, globalLeaderboardVisible: false), now: now)
        #expect(keys(update).isSubset(of: allowed) && keys(update).isDisjoint(with: ["friendCount", "fanCount"]))
        #expect(update["profileVisibility"] as? String == "friends")
        #expect(SocialWire.profileUpdateDocument(ProfileUpdate(streak: -3), now: now)["streak"] as? Int == 0)
    }

    @Test func privacyWriteTouchesOnlyThePrivacyMap() {
        let doc = SocialWire.privacyDocument(PrivacySettings())
        #expect(keys(doc) == ["privacy", "schemaVersion"])           // no name, unit, settings ... those belong to the sync layer
        let map = doc["privacy"] as? [String: String]
        #expect(map == ["workoutPosts": "friends", "bodyMap": "friends", "globalLeaderboards": "visible", "profile": "everyone"])
    }

    // MARK: Fake backend keeps counters out of client hands

    @Test func likesAndCommentsNeverChangeTheCountersOnThePost() async {
        let h = SocialHarness()
        h.friend("a"); h.post("p", by: "a", likes: 3, comments: 1)
        await h.vm.loadFeed()
        await h.vm.toggleLike(postId: "p")
        _ = await h.vm.postComment(postId: "p", text: "nice")
        let stored = h.remote.posts.first { $0.id == "p" }
        #expect(stored?.likeCount == 3 && stored?.commentCount == 1)       // only the functions move these
        #expect(h.vm.feedItems.first?.likeCount == 4 && h.vm.feedItems.first?.commentCount == 2)   // shown optimistically
    }

    @Test func joiningAChallengeNeverTouchesMemberCount() async {
        let h = SocialHarness()
        let c = T.challenge("g1", creator: "pulse", global: true, start: h.clock.date.addingTimeInterval(-86_400), end: h.clock.date.addingTimeInterval(86_400), members: 5)
        h.remote.challenges["g1"] = c
        #expect(await h.vm.join(c))
        #expect(h.remote.challenges["g1"]?.memberCount == 5)
    }
}
