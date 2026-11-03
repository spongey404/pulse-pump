import Foundation

// Social data model (docs/sync-architecture.md). These are value types that mirror the Firestore
// schema for the social collections; they are separate from the SwiftData models. The Firestore
// mapping (field names, Timestamps) lives in `FirestoreSocialRemote`, not here.

// MARK: - Audience

/// Who may see a post, its body map, or a profile. Raw values are the strings the security rules check.
enum PostAudience: String, Codable, CaseIterable {
    case everyone, friends, onlyMe
}

// MARK: - Profiles

/// `profiles/{uid}` plus the owner-visible counters. `friendCount`/`fanCount` are written by Cloud
/// Functions only; the client shows them but never writes them.
struct FirestoreUserProfile: Codable, Identifiable, Equatable {
    var id: String { uid }
    var uid: String
    var username: String
    var displayName: String
    var totalWorkouts: Int
    var currentStreak: Int
    var friendCount: Int
    var fanCount: Int
    var profileVisibility: PostAudience
    var globalLeaderboardVisible: Bool
    /// True for a placeholder standing in for a profile this user may not read (private profile,
    /// blocked, or a deleted account). Placeholders carry only the uid (and a handle when known).
    var isRestricted: Bool

    init(uid: String, username: String, displayName: String, totalWorkouts: Int = 0, currentStreak: Int = 0,
         friendCount: Int = 0, fanCount: Int = 0, profileVisibility: PostAudience = .everyone,
         globalLeaderboardVisible: Bool = true, isRestricted: Bool = false) {
        self.uid = uid
        self.username = username
        self.displayName = displayName
        self.totalWorkouts = totalWorkouts
        self.currentStreak = currentStreak
        self.friendCount = friendCount
        self.fanCount = fanCount
        self.profileVisibility = profileVisibility
        self.globalLeaderboardVisible = globalLeaderboardVisible
        self.isRestricted = isRestricted
    }

    /// Stand-in for a profile that cannot be read (shown as "PRIVATE PROFILE").
    static func restricted(uid: String, handle: String = "") -> FirestoreUserProfile {
        FirestoreUserProfile(uid: uid, username: handle, displayName: "Private profile", isRestricted: true)
    }

    /// The name to show in lists; never empty.
    var shownName: String { displayName.isEmpty ? (username.isEmpty ? Brand.defaultUserName : username) : displayName }
}

/// A handle search hit. The profile is nil when the owner's profile is not visible to the caller.
struct UserLookup: Equatable {
    var uid: String
    var handle: String
    var profile: FirestoreUserProfile?
}

/// Own-profile fields the client may write (never the counters).
struct ProfileUpdate: Equatable {
    var displayName: String?
    var streak: Int?
    var totalWorkouts: Int?
    var profileVisibility: PostAudience?
    var globalLeaderboardVisible: Bool?
}

// MARK: - Follows, blocks

/// `follows/{followerUid}_{followeeUid}`.
struct FollowEdge: Equatable {
    var followerUid: String
    var followeeUid: String
    var createdAt: Date
}

/// `users/{me}/blocked/{other}`; the name and handle are stored at block time so the blocked list
/// can still be shown (their profile is unreadable while blocked).
struct BlockedUser: Equatable, Identifiable {
    var id: String { uid }
    var uid: String
    var username: String
    var displayName: String
    var createdAt: Date
}

enum ReportTarget: String {
    case post, comment, user, challenge
}

// MARK: - Feed

struct FeedSetLog: Codable, Equatable {
    var weight: Double   // kg, 0 for bodyweight
    var reps: Int
    var duration: Int    // seconds, for time-based exercises (0 otherwise)
    var distance: Double // metres, for distance-based (0 otherwise)
    var setType: String  // SetType.rawValue
    var side: String?    // Side.rawValue, nil when bilateral

    /// False for warm-up sets, which are shown in the breakdown but never counted in totals.
    var isWorking: Bool { setType != SetType.warmup.rawValue }
}

struct FeedExercise: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var sets: [FeedSetLog]
    var improvementScore: Double = 0  // % 1RM gain vs previous session; 0 = no history
    // Raw kg/rep gain on the best set vs the previous session — what the feed's "VS LAST"
    // column actually displays. At most one is nonzero: weight beating last time takes priority.
    var weightDelta: Double = 0
    var repsDelta: Int = 0
    // `MuscleGroup.displayName` strings. Used locally to build the body-map extras at post time;
    // NEVER written inside a post document (that would leak the body map to the post's audience).
    var primaryMuscles: [String] = []
    var secondaryMuscles: [String] = []

    /// Sets that count toward set totals / volume (warm-ups excluded).
    var workingSets: [FeedSetLog] { sets.filter(\.isWorking) }

    /// The copy that goes into a post document: no muscle tags.
    var forPost: FeedExercise {
        var copy = self
        copy.primaryMuscles = []
        copy.secondaryMuscles = []
        return copy
    }
}

/// A feed post as the UI sees it. Built from `posts/{id}` (+ `extras/bodymap` and the viewer's like).
struct WorkoutFeedItem: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    /// Author display name (`authorName`).
    var username: String
    /// Author handle without the `@` (`authorUsername`).
    var handle: String
    var templateName: String?
    var exerciseCount: Int
    var durationSeconds: Int
    var caloriesBurned: Int
    var musclesWorked: [String]
    var prCount: Int
    var improvedCount: Int
    var totalExercises: Int
    var date: Date
    /// Server timestamp used for ordering and pagination.
    var createdAt: Date
    /// Counters maintained by Cloud Functions. The client shows them (optimistically adjusted
    /// while a like/comment is in flight) but never writes them.
    var likeCount: Int
    var commentCount: Int
    var likedByMe: Bool
    var caption: String
    var exercises: [FeedExercise]
    var taggedFriendUids: [String]
    /// `PostAudience.rawValue` captured at post time.
    var audience: String?
    var bodyMapAudience: String?
    /// `extras/bodymap`: muscle group display name -> weighted set count. Empty when the viewer may
    /// not see the body map (or the author chose not to share it).
    var muscleSets: [String: Int]
    /// Optional extras of the Feed Post design. nil = none; absent in older documents.
    var photoURL: String?
    var song: PostSong?
    /// Display names of `taggedFriendUids`, in the same order ("Trained with Sam and Jordan").
    var taggedNames: [String]?
    var isEdited: Bool?

    var includesBodyMap: Bool { !muscleSets.isEmpty }

    init(id: String = UUID().uuidString, userId: String, username: String, handle: String = "",
         templateName: String? = nil, exerciseCount: Int, durationSeconds: Int,
         caloriesBurned: Int = 0, musclesWorked: [String] = [], prCount: Int = 0,
         improvedCount: Int = 0, totalExercises: Int = 0, date: Date, createdAt: Date? = nil,
         caption: String = "", exercises: [FeedExercise] = [],
         taggedFriendUids: [String] = [], audience: String? = nil, bodyMapAudience: String? = nil,
         likeCount: Int = 0, commentCount: Int = 0, likedByMe: Bool = false,
         muscleSets: [String: Int] = [:]) {
        self.id = id
        self.userId = userId
        self.username = username
        self.handle = handle
        self.templateName = templateName
        self.exerciseCount = exerciseCount
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.musclesWorked = musclesWorked
        self.prCount = prCount
        self.improvedCount = improvedCount
        self.totalExercises = totalExercises
        self.date = date
        self.createdAt = createdAt ?? date
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.likedByMe = likedByMe
        self.caption = caption
        self.exercises = exercises
        self.taggedFriendUids = taggedFriendUids
        self.audience = audience
        self.bodyMapAudience = bodyMapAudience
        self.muscleSets = muscleSets
    }

    // MARK: Derived (session totals are always derived, never stored twice)

    var workingSetCount: Int { exercises.reduce(0) { $0 + $1.workingSets.count } }
    var volumeKg: Double { exercises.flatMap(\.workingSets).reduce(0) { $0 + $1.weight * Double($1.reps) } }
}

/// What the client writes to create a post. Counters are intentionally absent (functions own them).
struct PostPayload: Equatable, Codable {
    struct Stats: Equatable, Codable {
        var sets: Int
        var volumeKg: Double
        var durationSec: Int
        var prCount: Int
    }

    var postId: String
    var authorUid: String
    var authorName: String
    var authorUsername: String
    var date: Date
    var workoutName: String
    var audience: PostAudience
    var bodyMapAudience: PostAudience
    var stats: Stats
    /// Exercises without muscle tags.
    var exercises: [FeedExercise]
    var caption: String
    var taggedUids: [String]
    /// Contents of `extras/bodymap`; nil means no extras document is written.
    var muscleSets: [String: Int]?
    /// Composer extras (Feed Post design): the photo's download URL, the attached Apple Music song, and the names of `taggedUids`.
    var photoURL: String? = nil
    var song: PostSong? = nil
    var taggedNames: [String] = []
    /// Set when the author edits the post afterwards (the post shows EDITED).
    var editedAt: Date? = nil
}

struct FeedComment: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var username: String
    var handle: String
    var text: String
    var date: Date

    init(id: String = UUID().uuidString, userId: String, username: String, handle: String = "", text: String, date: Date = Date()) {
        self.id = id
        self.userId = userId
        self.username = username
        self.handle = handle
        self.text = text
        self.date = date
    }
}

/// One Firestore posts query. The rules only authorise a post query that pins `authorUid` and an
/// `audience` the caller may see, so every query carries both.
struct PostQuery: Equatable {
    var authorUids: [String]
    var audiences: [PostAudience]
    /// Only posts created before this instant (pagination cursor).
    var before: Date?
    var limit: Int
}

// MARK: - Challenges

enum ChallengeStatus: String, Codable { case active, ended }

enum ChallengeVisibility: String, Codable, CaseIterable { case friends, invite, `public` }

struct SocialChallenge: Identifiable, Equatable {
    var id: String
    var creatorUid: String
    var name: String
    var metric: ChallengeMetric
    var exerciseName: String?
    var startAt: Date
    var endAt: Date
    var isGlobal: Bool
    var visibility: ChallengeVisibility
    var status: ChallengeStatus
    var memberCount: Int
    var winCondition: ChallengeWinCondition
    var unit: String?
    var customLabel: String?

    /// A challenge is over once the server flips `status` or the end time has passed
    /// (the status flip is a scheduled function, so `endAt` is authoritative in between).
    func isEnded(now: Date = Date()) -> Bool { status == .ended || endAt <= now }
    func isActive(now: Date = Date()) -> Bool { !isEnded(now: now) }
}

/// What the client sends to create a (non-global) challenge.
struct ChallengeDraft: Equatable {
    var name: String
    var metric: ChallengeMetric
    var exerciseName: String?
    var startAt: Date
    var endAt: Date
    var visibility: ChallengeVisibility = .invite
    var winCondition: ChallengeWinCondition = .highest
    var unit: String?
    var customLabel: String?
}

/// `challenges/{id}/entries/{uid}` — written by functions only.
struct ChallengeEntry: Identifiable, Equatable {
    var id: String { uid }
    var uid: String
    var username: String
    var score: Double
    var rank: Int
    var previousRank: Int
    var scoreAt: Date?
    var hidden: Bool

    init(uid: String, username: String, score: Double = 0, rank: Int = 0, previousRank: Int = 0,
         scoreAt: Date? = nil, hidden: Bool = false) {
        self.uid = uid
        self.username = username
        self.score = score
        self.rank = rank
        self.previousRank = previousRank
        self.scoreAt = scoreAt
        self.hidden = hidden
    }
}

enum ChallengeInviteStatus: String, Codable {
    case pending, accepted, declined
}

/// `invites/{challengeId}_{toUid}`.
struct ChallengeInvite: Codable, Identifiable, Equatable {
    var id: String
    var challengeId: String
    var challengeName: String
    var fromUid: String
    var fromUsername: String
    var toUid: String
    var status: ChallengeInviteStatus
    var createdAt: Date

    /// The rules require invite ids of exactly this shape.
    static func docId(challengeId: String, toUid: String) -> String { "\(challengeId)_\(toUid)" }

    init(challengeId: String, challengeName: String, fromUid: String, fromUsername: String, toUid: String,
         status: ChallengeInviteStatus = .pending, createdAt: Date = Date()) {
        self.id = Self.docId(challengeId: challengeId, toUid: toUid)
        self.challengeId = challengeId
        self.challengeName = challengeName
        self.fromUid = fromUid
        self.fromUsername = fromUsername
        self.toUid = toUid
        self.status = status
        self.createdAt = createdAt
    }
}
