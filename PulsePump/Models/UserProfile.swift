import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var username: String
    var avatarData: Data?
    var totalWorkouts: Int
    var currentStreak: Int
    var longestStreak: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        username: String,
        totalWorkouts: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0
    ) {
        self.id = UUID()
        self.username = username
        self.totalWorkouts = totalWorkouts
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
