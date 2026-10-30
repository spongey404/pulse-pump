import Testing
import Foundation
import SwiftData
@testable import Ore

/// From finishing a workout to the one post that may leave the phone (composer -> SocialViewModel -> FakeSocialRemote).
@MainActor
struct SocialPostingJourneyTests {
    private static let bench = "Barbell Bench Press"

    /// Bench: warm-up 40x10, then 3 x 80x5 and a drop set 60x10; OHP: warm-up only (never posted). 62 minutes.
    private func finishedPush(_ sim: UserSim) -> WorkoutCompletionData {
        sim.startSession(template: "Push Day")
        sim.warmup(Self.bench, 40, 10)
        sim.logSets(Self.bench, 80, 5, count: 3)
        sim.log(Self.bench, 60, 10, type: .dropset)
        sim.warmup("Overhead Press", 20, 10)
        return sim.finish(minutes: 62)
    }

    @Test func finishingAWorkoutPostsNothingByItself() async throws {
        let sim = try UserSim()
        let h = SocialHarness()
        _ = finishedPush(sim)
        #expect(h.remote.createdPosts.isEmpty)                      // the composer owns the decision to post
    }

    @Test func thePostHasWorkingSetsOnlyAndStatsThatMatchTheJourney() throws {
        let sim = try UserSim()
        let data = finishedPush(sim)
        let post = try #require(sim.postPayload(of: data, caption: "  Heavy day  "))
        // Hand-derived from what was typed: 3 x 80x5 + 60x10 = 4 working sets, 1200 + 600 = 1800 kg.
        #expect(post.exercises.count == 1)                          // the warm-up-only OHP is not posted
        #expect(post.exercises[0].name == Self.bench)
        #expect(post.exercises[0].sets.map(\.weight) == [80, 80, 80, 60])
        #expect(post.exercises[0].sets.map(\.reps) == [5, 5, 5, 10])
        #expect(post.exercises[0].sets.map(\.setType) == ["standard", "standard", "standard", "dropset"])
        #expect(post.stats.sets == 4 && post.stats.volumeKg == 1800 && post.stats.durationSec == 62 * 60 && post.stats.prCount == 0)
        #expect(post.caption == "Heavy day" && post.workoutName == "Push Day")
        #expect(post.postId == sim.historyRows()[0].id.uuidString.lowercased())
    }

    @Test func theMuscleTagsGoToTheBodyMapExtrasNotTheExerciseList() throws {
        let sim = try UserSim()
        let post = try #require(sim.postPayload(of: finishedPush(sim)))
        #expect(post.exercises.allSatisfy { $0.primaryMuscles.isEmpty && $0.secondaryMuscles.isEmpty })
        // 4 working bench sets: chest primary x4, triceps and front delts secondary x2 each.
        #expect(post.muscleSets == ["Chest": 4, "Triceps": 2, "Front Delts": 2])
    }

    @Test func theComposerPostsExactlyOnceEvenWhenTappedTwice() async throws {
        let sim = try UserSim()
        let data = finishedPush(sim)
        let h = SocialHarness()
        let first = await h.vm.publishWorkoutPost(data: data, caption: "hi", taggedUids: [], includeBodyMap: true)
        let second = await h.vm.publishWorkoutPost(data: data, caption: "hi", taggedUids: [], includeBodyMap: true)
        #expect(first != nil && second == nil)
        #expect(h.remote.createdPosts.count == 1)
        #expect(h.remote.createdPosts[0].postId == sim.historyRows()[0].id.uuidString.lowercased())
        #expect(h.remote.createdPosts[0].stats.volumeKg == 1800)
    }

    @Test(arguments: [(PrivacyLevel.everyone, PostAudience.everyone), (.friendsOnly, .friends)])
    func theAudienceFollowsTheWorkoutPostsPrivacyRow(level: PrivacyLevel, audience: PostAudience) async throws {
        let sim = try UserSim()
        let data = finishedPush(sim)
        let h = SocialHarness()
        await h.privacy.set(.workoutPosts, to: level)
        _ = await h.vm.publishWorkoutPost(data: data, caption: "", taggedUids: [], includeBodyMap: true)
        #expect(h.remote.createdPosts.first?.audience == audience)
    }

    @Test func onlyMeNeverPostsAnythingFromAFinishedWorkout() async throws {
        let sim = try UserSim()
        let data = finishedPush(sim)
        let h = SocialHarness()
        await h.privacy.set(.workoutPosts, to: .onlyMe)
        let result = await h.vm.publishWorkoutPost(data: data, caption: "", taggedUids: [], includeBodyMap: true)
        #expect(result == nil && h.remote.createdPosts.isEmpty)
        #expect(sim.postPayload(of: data, privacy: { var p = PrivacySettings(); p.workoutPosts = .onlyMe; return p }()) == nil)
    }

    @Test func aHiddenBodyMapStillPostsTheWorkoutButWithoutTheMuscleExtras() throws {
        let sim = try UserSim()
        let data = finishedPush(sim)
        var privacy = PrivacySettings()
        privacy.bodyMap = .onlyMe
        let post = try #require(sim.postPayload(of: data, privacy: privacy))
        #expect(post.muscleSets == nil && post.bodyMapAudience == .onlyMe)
        #expect(post.exercises.count == 1)
        let declined = try #require(sim.postPayload(of: data, includeBodyMap: false))
        #expect(declined.muscleSets == nil)
    }

    @Test func aWeekOfTrainingMakesOnePostPerSessionWithDistinctIds() async throws {
        let sim = try UserSim()
        let h = SocialHarness()
        for (day, template, lift) in [(0, "Push Day", Self.bench), (2, "Pull Day", "Barbell Row"), (4, "Leg Day", "Barbell Squat")] {
            sim.skipToDay(day)
            let data = sim.session(template: template) { s in s.logSets(lift, 70, 5, count: 3) }
            _ = await h.vm.publishWorkoutPost(data: data, caption: "", taggedUids: [], includeBodyMap: true)
        }
        #expect(h.remote.createdPosts.count == 3)
        let ids = h.remote.createdPosts.map(\.postId)
        #expect(Set(ids).count == 3)
        #expect(Set(ids) == Set(sim.historyRows().map { $0.id.uuidString.lowercased() }))
        #expect(h.remote.createdPosts.map(\.workoutName) == ["Push Day", "Pull Day", "Leg Day"])
    }

    @Test func theFeedPostCarriesTheSamePRsAndImprovementsAsTheCompletionScreen() async throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 80, 5, count: 3) }
        sim.skipToDay(2)
        let data = sim.session(template: "Push Day") { s in s.logSets(Self.bench, 85, 5, count: 3) }
        let post = try #require(sim.postPayload(of: data))
        #expect(data.prCount == 1 && post.stats.prCount == 1)
        #expect(post.exercises[0].weightDelta == 5 && post.exercises[0].repsDelta == 0)
        // Improvement is the e1RM gain in percent: 85 vs 80 at 5 reps.
        #expect(abs(post.exercises[0].improvementScore - 6.25) < 1e-9)
    }

    @Test func aPoundsUsersPostIsStillInKilograms() throws {
        let sim = try UserSim(unit: .lbs)
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 100, 10, count: 2)                  // 100 lb x 10 x 2
        let data = sim.finish()
        let post = try #require(sim.postPayload(of: data))
        let kg = (100 * 0.45359237 * 10_000).rounded() / 10_000
        #expect(post.exercises[0].sets.allSatisfy { abs($0.weight - kg) < 1e-9 })
        #expect(abs(post.stats.volumeKg - 2 * 10 * kg) < 1e-6)
    }

    @Test func aFailedPostIsRetriedOnceAndNeverDuplicated() async throws {
        let sim = try UserSim()
        let data = finishedPush(sim)
        let h = SocialHarness()
        h.remote.fail("createPost")
        #expect(await h.vm.publishWorkoutPost(data: data, caption: "", taggedUids: [], includeBodyMap: true) == nil)
        h.remote.heal("createPost")
        await h.vm.retryPendingPost()
        await h.vm.retryPendingPost()
        #expect(h.remote.createdPosts.count == 1)
    }

    @Test func aDeletedWorkoutKeepsItsAlreadyPublishedPostIdStable() async throws {
        let sim = try UserSim()
        let data = finishedPush(sim)
        let h = SocialHarness()
        _ = await h.vm.publishWorkoutPost(data: data, caption: "", taggedUids: [], includeBodyMap: true)
        let id = h.remote.createdPosts[0].postId
        sim.deleteWorkout(sim.historyRows()[0])
        #expect(sim.historyRows().isEmpty)
        #expect(h.remote.createdPosts.count == 1 && h.remote.createdPosts[0].postId == id)     // deleting local history never edits the feed
    }

    @Test func theChallengeInputsOfASessionAreItsWorkingVolumeSetsAndTheSessionCount() throws {
        let sim = try UserSim()
        for d in 0..<3 {
            sim.skipToDay(d)
            sim.session(template: "Push Day") { s in
                s.warmup(Self.bench, 40, 10)
                s.logSets(Self.bench, 80, 5, count: 3)
            }
        }
        let rows = sim.historyRows()
        #expect(rows.count == 3)                                                       // sessionsLogged
        #expect(rows.reduce(0) { $0 + $1.workingVolume } == 3600)                        // totalVolume: 3 x 1200
        #expect(rows.flatMap(\.workingSets).map(\.reps).reduce(0, +) == 45)              // mostReps (warm-ups excluded)
        #expect(rows.flatMap(\.workingSets).map(\.weight).max() == 80)                   // heaviestLift
    }
}
