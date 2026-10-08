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

// Matches the Social redesign's 5a "MEASURED BY" options exactly
// (design/design_handoff_social_tab/README.md). Everything is scored from logged sessions —
// nothing to enter by hand.
enum ChallengeMetric: String, Codable, CaseIterable, Identifiable {
    case totalVolume
    case heaviestLift
    case mostReps
    case longestHold
    case sessionsLogged
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .totalVolume: "Total volume"
        case .heaviestLift: "Heaviest lift"
        case .mostReps: "Most reps"
        case .longestHold: "Longest hold"
        case .sessionsLogged: "Sessions logged"
        case .custom: "Custom"
        }
    }

    /// 5a's unit column, e.g. "KG LIFTED".
    var unit: String {
        switch self {
        case .totalVolume: "KG LIFTED"
        case .heaviestLift: "BEST 1RM"
        case .mostReps: "REPS"
        case .longestHold: "TIME HELD"
        case .sessionsLogged: "WORKOUTS"
        case .custom: "ENTERED BY HAND"
        }
    }

    /// 5a's rule column, e.g. "Every working set, summed".
    var rule: String {
        switch self {
        case .totalVolume: "Every working set, summed"
        case .heaviestLift: "Top estimated single, one exercise"
        case .mostReps: "Every rep logged, summed"
        case .longestHold: "Best single hold — plank, dead hang, wall sit"
        case .sessionsLogged: "Any session over 10 minutes"
        case .custom: "Everyone types their own score"
        }
    }

    /// 3b's global-challenge-card subheading, e.g. "EVERY KG LIFTED · ALL SESSIONS COUNT".
    var globalSubheading: String {
        switch self {
        case .totalVolume: "EVERY KG LIFTED · ALL SESSIONS COUNT"
        case .heaviestLift: "BEST SINGLE LIFT · ONE EXERCISE"
        case .mostReps: "EVERY REP LOGGED · ALL SESSIONS COUNT"
        case .longestHold: "BEST SINGLE HOLD · ALL SESSIONS COUNT"
        case .sessionsLogged: "ANY SESSION OVER 10 MINUTES"
        case .custom: "ENTERED BY HAND · EVERYONE COUNTS THEIR OWN"
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
    /// When this entry joined the challenge — drives 5b's "late joiners scored from the
    /// day they join" copy.
    var joinedAt: Date
    /// Rank before the most recent `updateLeaderboardEntry` re-sort — drives 3c's MOVE
    /// column (▲/▼/—). Written back by the caller before re-sorting, never hand-set
    /// alongside `rank` in the same pass.
    var previousRank: Int

    init(userId: String, username: String, score: Double = 0, rank: Int = 0, previousRank: Int = 0, joinedAt: Date = Date()) {
        self.id = UUID()
        self.userId = userId
        self.username = username
        self.score = score
        self.rank = rank
        self.previousRank = previousRank
        self.joinedAt = joinedAt
        self.updatedAt = Date()
    }
}
