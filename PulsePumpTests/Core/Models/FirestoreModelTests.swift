import Testing
import Foundation
@testable import PulsePump

struct FirestoreModelTests {

    // MARK: - FirestoreUserProfile

    @Test @MainActor func userProfileCodableRoundtrip() throws {
        let profile = FirestoreUserProfile(
            uid: "abc123",
            username: "john",
            displayName: "John Doe",
            totalWorkouts: 42,
            currentStreak: 5,
            longestStreak: 10
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(FirestoreUserProfile.self, from: data)

        #expect(decoded.uid == "abc123")
        #expect(decoded.username == "john")
        #expect(decoded.displayName == "John Doe")
        #expect(decoded.totalWorkouts == 42)
        #expect(decoded.currentStreak == 5)
        #expect(decoded.longestStreak == 10)
        #expect(decoded.id == "abc123")
    }

    // MARK: - WorkoutFeedItem

    @Test @MainActor func feedItemCodableRoundtrip() throws {
        let item = WorkoutFeedItem(
            userId: "user1",
            username: "jane",
            templateName: "PPL Day 1",
            exerciseCount: 6,
            durationSeconds: 3600,
            caloriesBurned: 350,
            musclesWorked: ["chest", "triceps", "shoulders"],
            date: Date(timeIntervalSince1970: 1700000000)
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(WorkoutFeedItem.self, from: data)

        #expect(decoded.userId == "user1")
        #expect(decoded.username == "jane")
        #expect(decoded.templateName == "PPL Day 1")
        #expect(decoded.exerciseCount == 6)
        #expect(decoded.durationSeconds == 3600)
        #expect(decoded.caloriesBurned == 350)
        #expect(decoded.musclesWorked.count == 3)
        #expect(decoded.likes.isEmpty)
        #expect(decoded.commentCount == 0)
    }

    @Test @MainActor func feedItemIdentifiable() {
        let item = WorkoutFeedItem(
            id: "custom-id",
            userId: "u1",
            username: "test",
            exerciseCount: 1,
            durationSeconds: 60,
            caloriesBurned: 10,
            musclesWorked: [],
            date: Date()
        )
        #expect(item.id == "custom-id")
    }

    // MARK: - FeedComment

    @Test @MainActor func feedCommentCodableRoundtrip() throws {
        let comment = FeedComment(userId: "u1", username: "alice", text: "Great workout!")

        let data = try JSONEncoder().encode(comment)
        let decoded = try JSONDecoder().decode(FeedComment.self, from: data)

        #expect(decoded.userId == "u1")
        #expect(decoded.username == "alice")
        #expect(decoded.text == "Great workout!")
    }

    // MARK: - FriendshipDoc

    @Test @MainActor func friendshipDocCodableRoundtrip() throws {
        let doc = FriendshipDoc(userId1: "aaa", userId2: "bbb", requestedBy: "aaa")

        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(FriendshipDoc.self, from: data)

        #expect(decoded.userId1 == "aaa")
        #expect(decoded.userId2 == "bbb")
        #expect(decoded.requestedBy == "aaa")
        #expect(decoded.status == .pending)
    }

    @Test @MainActor func friendshipDocDefaultsPending() {
        let doc = FriendshipDoc(userId1: "a", userId2: "b", requestedBy: "a")
        #expect(doc.status == .pending)
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
