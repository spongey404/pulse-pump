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
    // Raw kg/rep gain on the best set vs the previous session — what the feed's "VS LAST"
    // column actually displays (a %, unlike `improvementScore`, doesn't say what changed).
    // At most one is nonzero: weight beating last time takes priority over a rep-only gain.
    var weightDelta: Double = 0
    var repsDelta: Int = 0
    // `MuscleGroup.displayName` strings — matches `WorkoutFeedItem.musclesWorked`'s
    // string-not-enum convention so old feed documents keep decoding if cases are ever
    // renamed. Sourced from `Exercise.primaryMuscleGroups`/`secondaryMuscleGroups` at log
    // time (see `WorkoutViewModel.completeWorkout`) — real per-exercise tags, not derived.
    var primaryMuscles: [String] = []
    var secondaryMuscles: [String] = []
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
    /// Attached photo (7a composer) — nil means the feed post (4a) skips the photo slide
    /// and opens straight on the body map.
    var photoURL: String?
    /// TAG FRIENDS chips (7a).
    var taggedFriendUids: [String]
    /// False when posted via the composer overflow's "Post without body map" (stats and
    /// photo only) — feed/session-sheet rendering skips the body-map slide when false.
    var includesBodyMap: Bool

    init(id: String = UUID().uuidString, userId: String, username: String,
         templateName: String? = nil, exerciseCount: Int, durationSeconds: Int,
         caloriesBurned: Int, musclesWorked: [String], prCount: Int = 0,
         improvedCount: Int = 0, totalExercises: Int = 0, date: Date,
         caption: String = "", exercises: [FeedExercise] = [],
         photoURL: String? = nil, taggedFriendUids: [String] = [], includesBodyMap: Bool = true) {
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
        self.photoURL = photoURL
        self.taggedFriendUids = taggedFriendUids
        self.includesBodyMap = includesBodyMap
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
