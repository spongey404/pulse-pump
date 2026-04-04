import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var templateExercises: [TemplateExercise]
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Workout.template) var workouts: [Workout]

    init(
        name: String,
        templateExercises: [TemplateExercise] = []
    ) {
        self.id = UUID()
        self.name = name
        self.templateExercises = templateExercises
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
    var targetReps: Int
    var targetRIR: Int?

    init(
        exerciseId: UUID,
        exerciseName: String,
        order: Int,
        targetSets: Int = 3,
        targetReps: Int = 10,
        targetRIR: Int? = nil
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRIR = targetRIR
    }
}
