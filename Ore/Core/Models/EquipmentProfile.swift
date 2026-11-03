import Foundation
import SwiftData

@Model
final class EquipmentProfile: SyncRecord {
    var id: UUID
    var name: String
    var availableEquipment: [EquipmentType]
    var availablePlates: [Double]
    var barTypes: [BarConfig]
    var createdAt: Date
    var updatedAt: Date
    // Cloud sync bookkeeping (docs/sync-architecture.md); all optional/defaulted so the store migrates lightly.
    var deletedAt: Date?
    var syncedAt: Date?
    var syncDigest: String?
    var schemaVersion: Int = 1

    @Relationship var user: User?

    init(
        name: String,
        availableEquipment: [EquipmentType] = EquipmentType.allCases,
        availablePlates: [Double] = [1.25, 2.5, 5, 10, 15, 20, 25],
        barTypes: [BarConfig] = [BarConfig.defaultOlympic]
    ) {
        self.id = UUID()
        self.name = name
        self.availableEquipment = availableEquipment
        self.availablePlates = availablePlates
        self.barTypes = barTypes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct BarConfig: Codable, Identifiable {
    var id: UUID
    var name: String
    var weightKg: Double

    init(name: String, weightKg: Double) {
        self.id = UUID()
        self.name = name
        self.weightKg = weightKg
    }

    static let defaultOlympic = BarConfig(name: "Olympic Barbell", weightKg: 20)
    static let ezCurl = BarConfig(name: "EZ Curl Bar", weightKg: 10)
    static let trapBar = BarConfig(name: "Trap Bar", weightKg: 25)
}
