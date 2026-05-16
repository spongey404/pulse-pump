import Foundation

struct FirestoreUserProfile: Codable, Identifiable {
    var id: String { uid }
    var uid: String
    var username: String
    var displayName: String
    var totalWorkouts: Int
    var currentStreak: Int
    var longestStreak: Int
    var createdAt: Date

    init(uid: String, username: String, displayName: String, totalWorkouts: Int = 0, currentStreak: Int = 0, longestStreak: Int = 0) {
        self.uid = uid
        self.username = username
        self.displayName = displayName
        self.totalWorkouts = totalWorkouts
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.createdAt = Date()
    }
}

// MARK: - Feed exercise breakdown

struct FeedSetLog: Codable {
    var weight: Double   // 0 for bodyweight
    var reps: Int
    var duration: Int    // seconds, for time-based exercises (0 otherwise)
    var distance: Double // metres/feet, for distance-based (0 otherwise)
    var setType: String  // SetType.rawValue
    var side: String?    // Side.rawValue, nil when bilateral
}

struct FeedExercise: Codable, Identifiable {
    var id: String
    var name: String
    var sets: [FeedSetLog]
    var improvementScore: Double = 0  // % 1RM gain vs previous session; 0 = no history
}

// MARK: - Feed post

struct WorkoutFeedItem: Codable, Identifiable {
    var id: String
    var userId: String
    var username: String
    var templateName: String?
    var exerciseCount: Int
    var durationSeconds: Int
    var caloriesBurned: Int
    var musclesWorked: [String]
    var prCount: Int
    var improvedCount: Int
    var totalExercises: Int
    var date: Date
    var likes: [String]
    var commentCount: Int
    var caption: String
    var exercises: [FeedExercise]  // full exercise breakdown

    init(id: String = UUID().uuidString, userId: String, username: String,
         templateName: String? = nil, exerciseCount: Int, durationSeconds: Int,
         caloriesBurned: Int, musclesWorked: [String], prCount: Int = 0,
         improvedCount: Int = 0, totalExercises: Int = 0, date: Date,
         caption: String = "", exercises: [FeedExercise] = []) {
        self.id = id
        self.userId = userId
        self.username = username
        self.templateName = templateName
        self.exerciseCount = exerciseCount
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.musclesWorked = musclesWorked
        self.prCount = prCount
        self.improvedCount = improvedCount
        self.totalExercises = totalExercises
        self.date = date
        self.likes = []
        self.commentCount = 0
        self.caption = caption
        self.exercises = exercises
    }
}

struct FeedComment: Codable, Identifiable {
    var id: String
    var userId: String
    var username: String
    var text: String
    var date: Date

    init(id: String = UUID().uuidString, userId: String, username: String, text: String) {
        self.id = id
        self.userId = userId
        self.username = username
        self.text = text
        self.date = Date()
    }
}

struct FriendshipDoc: Codable {
    var userId1: String
    var userId2: String
    var status: FriendshipStatus
    var requestedBy: String
    var createdAt: Date

    init(userId1: String, userId2: String, requestedBy: String) {
        self.userId1 = userId1
        self.userId2 = userId2
        self.status = .pending
        self.requestedBy = requestedBy
        self.createdAt = Date()
    }
}

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
}
