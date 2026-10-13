import Foundation
import SwiftData

@Model
final class WorkoutTemplate: SyncRecord {
    var id: UUID
    var name: String
    var templateExercises: [TemplateExercise]
    var splitDays: [String]
    var notes: String = ""
    var createdAt: Date
    var updatedAt: Date
    // Cloud sync bookkeeping (docs/sync-architecture.md); all optional/defaulted so the store migrates lightly.
    var deletedAt: Date?
    var syncedAt: Date?
    var syncDigest: String?
    var schemaVersion: Int = 1

    @Relationship(deleteRule: .nullify, inverse: \Workout.template) var workouts: [Workout]

    init(
        name: String,
        templateExercises: [TemplateExercise] = [],
        splitDays: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.templateExercises = templateExercises
        self.splitDays = splitDays
        self.createdAt = Date()
        self.updatedAt = Date()
        self.workouts = []
    }
}

struct TemplateExercise: Codable, Identifiable {
    var id: UUID
    var exerciseId: UUID
    var exerciseName: String
    var order: Int
    var targetSets: Int
    var targetReps: Int?
    var targetRIR: Int?
    var restSeconds: Int?
    var notes: String?

    init(
        exerciseId: UUID,
        exerciseName: String,
        order: Int,
        targetSets: Int = 3,
        targetReps: Int? = nil,
        targetRIR: Int? = nil,
        restSeconds: Int? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRIR = targetRIR
        self.restSeconds = restSeconds
        self.notes = notes
    }
}
