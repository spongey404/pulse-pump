import Foundation
import SwiftData

@Model
final class Challenge {
    var id: UUID
    var name: String
    var challengeDescription: String
    var creatorId: String
    var participantIds: [String]
    var rules: String
    var metric: ChallengeMetric
    var winCondition: ChallengeWinCondition
    var startDate: Date
    var endDate: Date
    var leaderboard: [LeaderboardEntry]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        challengeDescription: String = "",
        creatorId: String,
        rules: String = "",
        metric: ChallengeMetric = .totalVolume,
        winCondition: ChallengeWinCondition = .highest,
        startDate: Date,
        endDate: Date
    ) {
        self.id = UUID()
        self.name = name
        self.challengeDescription = challengeDescription
        self.creatorId = creatorId
        self.participantIds = [creatorId]
        self.rules = rules
        self.metric = metric
        self.winCondition = winCondition
        self.startDate = startDate
        self.endDate = endDate
        self.leaderboard = []
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum ChallengeMetric: String, Codable, CaseIterable, Identifiable {
    case totalVolume
    case totalWorkouts
    case totalSets
    case specificExerciseWeight
    case specificExerciseReps
    case consistency

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .totalVolume: "Total Volume"
        case .totalWorkouts: "Total Workouts"
        case .totalSets: "Total Sets"
        case .specificExerciseWeight: "Exercise Weight PR"
        case .specificExerciseReps: "Exercise Rep PR"
        case .consistency: "Consistency"
        }
    }
}

enum ChallengeWinCondition: String, Codable, CaseIterable, Identifiable {
    case highest
    case lowest
    case first

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highest: "Highest Wins"
        case .lowest: "Lowest Wins"
        case .first: "First to Reach Goal"
        }
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    var id: UUID
    var userId: String
    var username: String
    var score: Double
    var rank: Int
    var updatedAt: Date

    init(userId: String, username: String, score: Double = 0, rank: Int = 0) {
        self.id = UUID()
        self.userId = userId
        self.username = username
        self.score = score
        self.rank = rank
        self.updatedAt = Date()
    }
}
