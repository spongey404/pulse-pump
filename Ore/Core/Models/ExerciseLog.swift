import Foundation
import SwiftData

@Model
final class ExerciseLog {
    var id: UUID
    var order: Int
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship var exercise: Exercise?
    @Relationship var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog) var sets: [SetLog]

    init(
        order: Int = 0,
        notes: String = ""
    ) {
        self.id = UUID()
        self.order = order
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sets = []
    }
}
