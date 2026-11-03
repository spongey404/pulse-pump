import Foundation
import FirebaseAuth

// MARK: - Current user

/// The signed-in user, behind a protocol so the social layer can be tested without Firebase Auth.
protocol CurrentUser {
    var uid: String? { get }
    var displayName: String? { get }
}

struct FirebaseCurrentUser: CurrentUser {
    var auth: Auth?
    init(auth: Auth? = nil) { self.auth = auth }
    private var current: FirebaseAuth.User? { (auth ?? Auth.auth()).currentUser }
    var uid: String? { current?.uid }
    var displayName: String? { current?.displayName }
}

// MARK: - Errors

enum SocialError: Error, Equatable {
    case notSignedIn
    /// The document does not exist (e.g. the account was deleted).
    case notFound
    /// The rules refused the read/write: a private profile, a block in either direction, or a post
    /// outside the caller's audience. Callers must not distinguish these from each other.
    case permissionDenied
    case invalid(String)
    case unavailable(String)
}

// MARK: - Remote

/// Everything the social features need from the backend. `FirestoreSocialRemote` is the real
/// implementation; `FakeSocialRemote` is the in-memory one used by tests and DEBUG fixtures.
///
/// Rules of the contract (docs/sync-architecture.md):
/// - Counters (`likeCount`, `commentCount`, `friendCount`, `fanCount`, `memberCount`, entry scores and
///   ranks) are written by Cloud Functions. No method here writes them.
/// - Posts can only be queried with a pinned `authorUid` and an `audience` the caller may see.
@MainActor
protocol SocialRemote: AnyObject {
    // Profiles
    func fetchProfile(uid: String) async throws -> FirestoreUserProfile
    /// Exact-handle lookup through `usernames/{handle}` (the rules do not allow listing).
    func lookupUser(handle: String) async throws -> UserLookup?
    /// Creates `profiles/{me}` (claiming a handle) when it does not exist yet; returns the profile.
    /// A new profile starts with `privacy.profile` / `privacy.globalLeaderboards` as its visibility.
    func ensureOwnProfile(displayName: String, handleHint: String?, privacy: PrivacySettings) async throws -> FirestoreUserProfile
    func updateOwnProfile(_ update: ProfileUpdate) async throws

    // Privacy: persisted at users/{me}.privacy (only that map) and mirrored to profiles/{me}
    func savePrivacy(_ settings: PrivacySettings) async throws
    func loadPrivacy() async throws -> PrivacySettings?

    // Follows
    func follow(uid: String) async throws
    func unfollow(uid: String) async throws
    /// People I follow.
    func fetchFollowing() async throws -> [FollowEdge]
    /// People who follow me.
    func fetchFollowers() async throws -> [FollowEdge]

    // Blocks and reports
    func fetchBlocked() async throws -> [BlockedUser]
    func block(_ user: BlockedUser) async throws
    func unblock(uid: String) async throws
    func report(target: ReportTarget, targetId: String, reason: String, details: String?) async throws

    // Posts
    func createPost(_ payload: PostPayload) async throws
    /// Author-only edit: replaces the post's content fields (not its counters, author or creation time) and its body map.
    func updatePost(_ payload: PostPayload) async throws
    func deletePost(id: String) async throws
    func fetchPosts(_ query: PostQuery) async throws -> [WorkoutFeedItem]
    /// `extras/bodymap` of a post; nil when absent or not visible to the caller.
    func fetchBodyMap(postId: String) async throws -> [String: Int]?
    /// The subset of `postIds` that I have liked.
    func likedPostIds(among postIds: [String]) async throws -> Set<String>

    // Likes and comments (docs only; the counters come from functions)
    func setLike(postId: String, liked: Bool) async throws
    func fetchComments(postId: String, limit: Int) async throws -> [FeedComment]
    func addComment(postId: String, text: String, authorName: String, authorUsername: String) async throws -> FeedComment
    func deleteComment(postId: String, commentId: String) async throws

    // Challenges
    /// Challenges I created or joined.
    func fetchMyChallenges() async throws -> [SocialChallenge]
    /// Active global challenges anyone may join.
    func fetchGlobalChallenges() async throws -> [SocialChallenge]
    func fetchChallenge(id: String) async throws -> SocialChallenge
    func createChallenge(_ draft: ChallengeDraft) async throws -> String
    func joinChallenge(id: String, username: String) async throws
    func leaveChallenge(id: String) async throws
    func isMember(challengeId: String) async throws -> Bool
    /// Entries ordered by score descending (earliest `scoreAt` first on ties).
    func fetchLeaderboard(challengeId: String, isGlobal: Bool, limit: Int) async throws -> [ChallengeEntry]
    func fetchMyEntry(challengeId: String) async throws -> ChallengeEntry?
    /// Global boards: the rows with `rank` in `range`, for the "neighbourhood" around the user.
    func fetchEntries(challengeId: String, ranks: ClosedRange<Int>) async throws -> [ChallengeEntry]

    // Invites (`invites/{challengeId}_{toUid}`)
    func fetchPendingInvites() async throws -> [ChallengeInvite]
    func sendInvite(challengeId: String, challengeName: String, fromUsername: String, toUid: String) async throws
    func respondToInvite(_ invite: ChallengeInvite, accept: Bool) async throws
}
