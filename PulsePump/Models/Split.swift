import Foundation
import SwiftData

@Model
final class Split {
    var id: UUID
    var type: SplitType
    var name: String
    var days: [SplitDay]
    var createdAt: Date
    var updatedAt: Date

    init(
        type: SplitType,
        name: String = "",
        days: [SplitDay] = []
    ) {
        self.id = UUID()
        self.type = type
        self.name = name.isEmpty ? type.displayName : name
        self.days = days
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct SplitDay: Codable, Identifiable {
    var id: UUID
    var dayOfWeek: Int
    var label: String
    var workoutType: String

    init(
        dayOfWeek: Int,
        label: String,
        workoutType: String
    ) {
        self.id = UUID()
        self.dayOfWeek = dayOfWeek
        self.label = label
        self.workoutType = workoutType
    }
}
