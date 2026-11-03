import Testing
import Foundation
@testable import Ore

struct FirestoreModelTests {

    // MARK: - FirestoreUserProfile

    @Test @MainActor func userProfileCodableRoundtrip() throws {
        let profile = FirestoreUserProfile(uid: "abc123", username: "john", displayName: "John Doe",
                                           totalWorkouts: 42, currentStreak: 5, friendCount: 3, fanCount: 7,
                                           profileVisibility: .friends, globalLeaderboardVisible: false)
        let decoded = try JSONDecoder().decode(FirestoreUserProfile.self, from: try JSONEncoder().encode(profile))
        #expect(decoded == profile)
        #expect(decoded.id == "abc123")
    }

    @Test @MainActor func restrictedProfileHasNoPersonalData() {
        let p = FirestoreUserProfile.restricted(uid: "u1", handle: "h")
        #expect(p.isRestricted && p.totalWorkouts == 0 && p.currentStreak == 0)
        #expect(p.shownName == "Private profile")
    }

    // MARK: - WorkoutFeedItem

    @Test @MainActor func feedItemCodableRoundtrip() throws {
        let item = WorkoutFeedItem(userId: "user1", username: "jane", handle: "jane_k", templateName: "PPL Day 1",
                                   exerciseCount: 6, durationSeconds: 3600, caloriesBurned: 350,
                                   musclesWorked: ["chest"], date: Date(timeIntervalSince1970: 1_700_000_000),
                                   likeCount: 4, commentCount: 2, likedByMe: true, muscleSets: ["Chest": 9])
        let decoded = try JSONDecoder().decode(WorkoutFeedItem.self, from: try JSONEncoder().encode(item))
        #expect(decoded == item)
        #expect(decoded.includesBodyMap)
    }

    @Test @MainActor func feedItemWithoutMuscleSetsHasNoBodyMap() {
        let item = WorkoutFeedItem(userId: "u", username: "n", exerciseCount: 1, durationSeconds: 60, date: Date())
        #expect(!item.includesBodyMap)
    }

    @Test @MainActor func feedItemIdentifiable() {
        let item = WorkoutFeedItem(id: "custom-id", userId: "u1", username: "test", exerciseCount: 1, durationSeconds: 60, date: Date())
        #expect(item.id == "custom-id")
    }

    @Test @MainActor func feedItemDerivesTotalsFromWorkingSetsOnly() {
        func s(_ w: Double, _ r: Int, _ t: String) -> FeedSetLog { FeedSetLog(weight: w, reps: r, duration: 0, distance: 0, setType: t, side: nil) }
        let ex = FeedExercise(id: "1", name: "Bench", sets: [s(40, 10, "warmup"), s(100, 5, "standard"), s(100, 3, "dropset")])
        let item = WorkoutFeedItem(userId: "u", username: "n", exerciseCount: 1, durationSeconds: 60, date: Date(), exercises: [ex])
        #expect(item.workingSetCount == 2)
        #expect(item.volumeKg == 800)
    }

    @Test @MainActor func exerciseForPostDropsMuscleTags() {
        let ex = FeedExercise(id: "1", name: "Bench", sets: [], primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"])
        #expect(ex.forPost.primaryMuscles.isEmpty && ex.forPost.secondaryMuscles.isEmpty)
        #expect(ex.forPost.name == "Bench")
    }

    // MARK: - FeedComment

    @Test @MainActor func feedCommentCodableRoundtrip() throws {
        let comment = FeedComment(userId: "u1", username: "alice", handle: "alice_a", text: "Great workout!")
        let decoded = try JSONDecoder().decode(FeedComment.self, from: try JSONEncoder().encode(comment))
        #expect(decoded.userId == "u1" && decoded.username == "alice" && decoded.text == "Great workout!")
    }

    // MARK: - Export DTOs

    @Test @MainActor func exportDTOsCodableRoundtrip() throws {
        let exportData = WorkoutExportData(
            exportDate: Date(timeIntervalSince1970: 1700000000),
            version: "1.0",
            workouts: [
                ExportedWorkout(
                    date: Date(timeIntervalSince1970: 1700000000),
                    duration: 3600,
                    calories: 250,
                    notes: "Good session",
                    exercises: [
                        ExportedExercise(
                            name: "Bench Press",
                            order: 0,
                            notes: "",
                            sets: [
                                ExportedSet(order: 0, weight: 100, reps: 8, rir: 2, setType: "working"),
                                ExportedSet(order: 1, weight: 100, reps: 6, rir: 1, setType: "working")
                            ]
                        )
                    ]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WorkoutExportData.self, from: data)

        #expect(decoded.version == "1.0")
        #expect(decoded.workouts.count == 1)
        #expect(decoded.workouts[0].exercises.count == 1)
        #expect(decoded.workouts[0].exercises[0].name == "Bench Press")
        #expect(decoded.workouts[0].exercises[0].sets.count == 2)
        #expect(decoded.workouts[0].exercises[0].sets[0].weight == 100)
        #expect(decoded.workouts[0].exercises[0].sets[0].rir == 2)
        #expect(decoded.workouts[0].exercises[0].sets[1].rir == 1)
    }

    @Test @MainActor func exportedSetOptionalRIR() throws {
        let set = ExportedSet(order: 0, weight: 50, reps: 12, rir: nil, setType: "warmup")
        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(ExportedSet.self, from: data)
        #expect(decoded.rir == nil)
        #expect(decoded.setType == "warmup")
    }
}
