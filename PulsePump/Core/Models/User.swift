import Foundation
import SwiftData

@Model
final class User: SyncRecord {
    var id: UUID
    var name: String
    var username: String
    var weight: Double
    var height: Double
    var age: Int
    var gender: Gender
    var unitPreference: UnitPreference
    var experienceLevel: ExperienceLevel
    var avatarData: Data?
    var createdAt: Date
    var updatedAt: Date
    // Cloud sync bookkeeping (docs/sync-architecture.md); all optional/defaulted so the store migrates lightly.
    var deletedAt: Date?
    var syncedAt: Date?
    var syncDigest: String?
    var schemaVersion: Int = 1

    @Relationship(deleteRule: .nullify) var selectedSplit: Split?
    @Relationship(deleteRule: .cascade, inverse: \Workout.user) var workouts: [Workout]
    @Relationship(deleteRule: .cascade, inverse: \EquipmentProfile.user) var equipmentProfiles: [EquipmentProfile]

    init(
        name: String,
        username: String = "",
        weight: Double = 0,
        height: Double = 0,
        age: Int = 0,
        gender: Gender = .preferNotToSay,
        unitPreference: UnitPreference = .kg,
        experienceLevel: ExperienceLevel = .beginner
    ) {
        self.id = UUID()
        self.name = name
        self.username = username
        self.weight = weight
        self.height = height
        self.age = age
        self.gender = gender
        self.unitPreference = unitPreference
        self.experienceLevel = experienceLevel
        self.createdAt = Date()
        self.updatedAt = Date()
        self.workouts = []
        self.equipmentProfiles = []
    }
}
