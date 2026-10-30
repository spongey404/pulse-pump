import Testing
import Foundation
@testable import Ore

/// The post payload built at the end of a workout, and how it is published.
@MainActor
struct PostPayloadTests {
    private typealias T = SocialTestData
    private let author = FeedPostBuilder.Author(uid: "me", name: "Me Myself", handle: "me_m")

    private func bench() -> FeedExercise {
        T.exercise("Bench Press", sets: [T.set(40, 10, "warmup"), T.set(100, 5), T.set(100, 5), T.set(90, 8, "dropset")],
                   primary: ["Chest"], secondary: ["Triceps", "Front Delts"], improvement: 5)
    }

    // MARK: Builder

    @Test func onlyWorkingSetsArePosted() throws {
        let warmupOnly = T.exercise("Stretch", sets: [T.set(0, 10, "warmup")])
        let payload = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench(), warmupOnly]), author: author,
                                                               caption: "", taggedUids: [], includeBodyMap: true, privacy: .default))
        #expect(payload.exercises.count == 1)                       // the warm-up-only exercise is gone
        #expect(payload.exercises[0].sets.count == 3)               // the warm-up set is gone
        #expect(payload.exercises[0].sets.allSatisfy { $0.isWorking })
        #expect(payload.stats.sets == 3)
        #expect(payload.stats.volumeKg == 1720.0)   // 500 + 500 + 720
    }

    @Test func statsCarryDurationAndPRs() throws {
        let payload = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()], prCount: 2, duration: 3725), author: author,
                                                               caption: "", taggedUids: [], includeBodyMap: true, privacy: .default))
        #expect(payload.stats.durationSec == 3725 && payload.stats.prCount == 2)
        #expect(payload.workoutName == "Push Day")
    }

    @Test func audienceComesFromThePrivacySettings() throws {
        var privacy = PrivacySettings()
        for (level, expected) in [(PrivacyLevel.everyone, PostAudience.everyone), (.friendsOnly, .friends)] {
            privacy.workoutPosts = level
            privacy.bodyMap = level == .everyone ? .friendsOnly : .everyone
            let p = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "",
                                                             taggedUids: [], includeBodyMap: true, privacy: privacy))
            #expect(p.audience == expected)
            #expect(p.bodyMapAudience == privacy.bodyMap.audience)
        }
    }

    @Test func defaultPrivacyPostsToFriendsWithAFriendsBodyMap() throws {
        let p = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "",
                                                         taggedUids: [], includeBodyMap: true, privacy: .default))
        #expect(p.audience == .friends && p.bodyMapAudience == .friends)
    }

    @Test func onlyMeWorkoutPostsPostNothing() {
        var privacy = PrivacySettings(); privacy.workoutPosts = .onlyMe
        #expect(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "", taggedUids: [],
                                            includeBodyMap: true, privacy: privacy) == nil)
    }

    @Test func bodyMapExtrasAreOmittedWhenOnlyMeOrDeclined() throws {
        var privacy = PrivacySettings(); privacy.bodyMap = .onlyMe
        let hidden = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "",
                                                              taggedUids: [], includeBodyMap: true, privacy: privacy))
        #expect(hidden.muscleSets == nil && hidden.bodyMapAudience == .onlyMe)

        let declined = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "",
                                                                taggedUids: [], includeBodyMap: false, privacy: .default))
        #expect(declined.muscleSets == nil)                          // "Post without body map"

        let shared = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "",
                                                              taggedUids: [], includeBodyMap: true, privacy: .default))
        #expect(shared.muscleSets != nil)
    }

    @Test func muscleSetsWeightPrimaryFullAndSecondaryHalfOverWorkingSetsOnly() throws {
        let p = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "",
                                                         taggedUids: [], includeBodyMap: true, privacy: .default))
        // 3 working sets (the warm-up doesn't count): Chest 3, Triceps 1.5 -> 2, Front Delts 1.5 -> 2.
        #expect(p.muscleSets == ["Chest": 3, "Triceps": 2, "Front Delts": 2])
    }

    @Test func muscleTagsNeverLeakIntoThePostedExercises() throws {
        let p = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()]), author: author, caption: "",
                                                         taggedUids: [], includeBodyMap: true, privacy: .default))
        #expect(p.exercises.allSatisfy { $0.primaryMuscles.isEmpty && $0.secondaryMuscles.isEmpty })
        let doc = SocialWire.postDocument(p, now: Date())
        let exercises = doc["exercises"] as? [[String: Any]] ?? []
        #expect(exercises.allSatisfy { $0["primaryMuscles"] == nil && $0["secondaryMuscles"] == nil })
    }

    @Test func postIdIsTheLowercasedWorkoutIdAndCaptionIsTrimmed() throws {
        let id = UUID()
        let p = try #require(FeedPostBuilder.makePayload(data: T.completion(exercises: [bench()], id: id), author: author, caption: "  big day \n",
                                                         taggedUids: ["f1"], includeBodyMap: true, privacy: .default))
        #expect(p.postId == id.uuidString.lowercased())
        #expect(p.caption == "big day" && p.taggedUids == ["f1"])
        #expect(p.authorUid == "me" && p.authorUsername == "me_m")
    }

    // MARK: Publishing

    @Test func publishCreatesTheDocumentOnceEvenIfCalledTwice() async throws {
        let h = SocialHarness()
        let data = T.completion(exercises: [bench()])
        let first = await h.vm.publishWorkoutPost(data: data, caption: "hi", taggedUids: [], includeBodyMap: true)
        let second = await h.vm.publishWorkoutPost(data: data, caption: "hi", taggedUids: [], includeBodyMap: true)
        #expect(first != nil && second == nil)
        #expect(h.remote.createdPosts.count == 1)
        #expect(h.remote.createdPosts[0].authorUsername == h.vm.myHandle && !h.vm.myHandle.isEmpty)
    }

    @Test func onlyMeNeverCallsCreatePost() async {
        let h = SocialHarness()
        await h.privacy.set(.workoutPosts, to: .onlyMe)
        let result = await h.vm.publishWorkoutPost(data: T.completion(exercises: [bench()]), caption: "", taggedUids: [], includeBodyMap: true)
        #expect(result == nil && h.remote.createdPosts.isEmpty)
    }

    @Test func signedOutNeverPosts() async {
        let h = SocialHarness(signedIn: false)
        #expect(await h.vm.publishWorkoutPost(data: T.completion(exercises: [bench()]), caption: "", taggedUids: [], includeBodyMap: true) == nil)
        #expect(h.remote.createdPosts.isEmpty)
    }

    @Test func aFailedPostIsKeptForRetryAndPostsOnce() async {
        let h = SocialHarness()
        h.remote.fail("createPost")
        let data = T.completion(exercises: [bench()])
        #expect(await h.vm.publishWorkoutPost(data: data, caption: "", taggedUids: [], includeBodyMap: true) == nil)
        #expect(h.vm.pendingPost != nil && h.vm.lastError != nil)
        h.remote.heal("createPost")
        await h.vm.retryPendingPost()
        #expect(h.vm.pendingPost == nil)
        #expect(h.remote.createdPosts.count == 1)
        await h.vm.retryPendingPost()                                // nothing left to retry
        #expect(h.remote.createdPosts.count == 1)
    }
}
