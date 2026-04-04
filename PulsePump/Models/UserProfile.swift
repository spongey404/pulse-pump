import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var firebaseUid: String
    var username: String
    var avatarData: Data?
    var totalWorkouts: Int
    var currentStreak: Int
    var longestStreak: Int
    var friendIds: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        firebaseUid: String = "",
        username: String,
        totalWorkouts: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        friendIds: [String] = []
    ) {
        self.id = UUID()
        self.firebaseUid = firebaseUid
        self.username = username
        self.totalWorkouts = totalWorkouts
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.friendIds = friendIds
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
