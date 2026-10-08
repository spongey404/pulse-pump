import Foundation
import SwiftData

@Model
final class SetLog {
    var id: UUID
    var order: Int
    var weight: Double
    var reps: Int
    var rir: Int?
    var duration: TimeInterval?
    var distance: Double?
    var setType: SetType
    var side: Side
    var timestamp: Date
    var createdAt: Date

    @Relationship var exerciseLog: ExerciseLog?

    init(
        order: Int = 0,
        weight: Double = 0,
        reps: Int = 0,
        rir: Int? = nil,
        duration: TimeInterval? = nil,
        distance: Double? = nil,
        setType: SetType = .standard,
        side: Side = .both
    ) {
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.duration = duration
        self.distance = distance
        self.setType = setType
        self.side = side
        self.timestamp = Date()
        self.createdAt = Date()
    }
}
