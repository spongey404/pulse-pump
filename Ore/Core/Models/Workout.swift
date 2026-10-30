import Foundation
import SwiftData

@Model
final class Workout: SyncRecord {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var notes: String
    var calorieBurnEstimate: Double
    var isDraft: Bool
    var isDeload: Bool
    var createdAt: Date
    var updatedAt: Date
    // Cloud sync bookkeeping (docs/sync-architecture.md); all optional/defaulted so the store migrates lightly.
    var deletedAt: Date?
    var syncedAt: Date?
    var syncDigest: String?
    var schemaVersion: Int = 1

    @Relationship var user: User?
    @Relationship var template: WorkoutTemplate?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.workout) var exerciseLogs: [ExerciseLog]

    init(
        date: Date = Date(),
        duration: TimeInterval = 0,
        notes: String = "",
        calorieBurnEstimate: Double = 0,
        isDraft: Bool = true,
        isDeload: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.notes = notes
        self.calorieBurnEstimate = calorieBurnEstimate
        self.isDraft = isDraft
        self.isDeload = isDeload
        self.createdAt = Date()
        self.updatedAt = Date()
        self.exerciseLogs = []
    }
}
