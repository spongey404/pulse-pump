import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var primaryMuscleGroups: [MuscleGroup]
    var secondaryMuscleGroups: [MuscleGroup]
    var equipmentType: EquipmentType
    var movementPattern: MovementPattern
    var exerciseType: ExerciseType
    var isCustom: Bool
    var isApproved: Bool
    var isUnilateral: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.exercise) var logs: [ExerciseLog]

    init(
        name: String,
        primaryMuscleGroups: [MuscleGroup],
        secondaryMuscleGroups: [MuscleGroup] = [],
        equipmentType: EquipmentType,
        movementPattern: MovementPattern,
        exerciseType: ExerciseType = .weighted,
        isCustom: Bool = false,
        isApproved: Bool = true,
        isUnilateral: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipmentType = equipmentType
        self.movementPattern = movementPattern
        self.exerciseType = exerciseType
        self.isCustom = isCustom
        self.isApproved = isApproved
        self.isUnilateral = isUnilateral
        self.createdAt = Date()
        self.updatedAt = Date()
        self.logs = []
    }
}
