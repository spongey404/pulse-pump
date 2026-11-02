#if DEBUG
import Foundation

/// In-memory `SocialRemote` for unit tests and DEBUG fixtures (no network).
///
/// It behaves like the backend where it matters to the client:
/// - post queries are checked against the visibility rules (a query that asks for an audience the
///   caller may not see, includes a blocked author, or exceeds 30 disjunctions is refused), so a test
///   fails if the app ever builds a query the real rules would reject;
/// - counters (`likeCount`, `commentCount`, `friendCount`, ...) are never touched by client calls;
///   tests set them directly, the way Cloud Functions would;
/// - any operation can be made to fail with `fail(_:)` and every write is recorded in `log`.
@MainActor
final class FakeSocialRemote: SocialRemote {
    var meUid: String

    // Stored data
    var profiles: [String: FirestoreUserProfile] = [:]
    var handles: [String: String] = [:]               // handle -> uid
    var privateUids: Set<String> = []                 // profiles the caller may not read
    var follows: Set<String> = []                     // "a_b" = a follows b
    var blocked: [String: BlockedUser] = [:]          // my blocks
    var blockedMe: Set<String> = []                   // users who blocked me
    var posts: [WorkoutFeedItem] = []                 // every post on the "server"
    var bodyMaps: [String: [String: Int]] = [:]
    var likes: [String: Set<String>] = [:]            // postId -> liker uids
    var comments: [String: [FeedComment]] = [:]
    var challenges: [String: SocialChallenge] = [:]
    var members: [String: Set<String>] = [:]          // challengeId -> member uids
    var entries: [String: [ChallengeEntry]] = [:]     // challengeId -> entries (as written by functions)
    var invites: [String: ChallengeInvite] = [:]      // id -> invite
    var privacyDocument: PrivacySettings?
    var myPrivacyOnProfile: (visibility: PostAudience, leaderboardVisible: Bool)?

    // Recording
    private(set) var postQueries: [PostQuery] = []
    private(set) var log: [String] = []
    private(set) var createdPosts: [PostPayload] = []
    private(set) var reports: [(target: ReportTarget, id: String, reason: String)] = []
    private(set) var writtenPrivacy: [PrivacySettings] = []
    private(set) var createdChallenges: [ChallengeDraft] = []
    private(set) var profileUpdates: [ProfileUpdate] = []

    /// Operation names that throw (see `fail`). Names are the protocol method names.
    private var failing: [String: SocialError] = [:]
    /// When true, a posts query with more than one author is refused (what the rules may do to `in`).
    var rejectsMultiAuthorQueries = false
    /// The server clock used for "challenge still open" checks.
    var now: () -> Date = { Date() }

    init(meUid: String = "me") { self.meUid = meUid }

    func fail(_ operation: String, with error: SocialError = .unavailable("offline")) { failing[operation] = error }
    func heal(_ operation: String) { failing[operation] = nil }
    func healAll() { failing = [:] }

    private func check(_ operation: String) throws {
        if let error = failing[operation] { throw error }
    }

    // MARK: Test helpers

    func addProfile(_ uid: String, name: String, handle: String, streak: Int = 0, workouts: Int = 0,
                    visibility: PostAudience = .everyone) {
        profiles[uid] = FirestoreUserProfile(uid: uid, username: handle, displayName: name, totalWorkouts: workouts,
                                             currentStreak: streak, profileVisibility: visibility)
        handles[handle] = uid
    }

    func setFollow(_ a: String, follows b: String, _ on: Bool = true) {
        if on { follows.insert("\(a)_\(b)") } else { follows.remove("\(a)_\(b)") }
    }

    func makeFriends(_ a: String, _ b: String) { setFollow(a, follows: b); setFollow(b, follows: a) }

    func areFriends(_ a: String, _ b: String) -> Bool { follows.contains("\(a)_\(b)") && follows.contains("\(b)_\(a)") }

    func addPost(_ post: WorkoutFeedItem, bodyMap: [String: Int]? = nil) {
        posts.append(post)
        if let bodyMap { bodyMaps[post.id] = bodyMap }
    }

    /// Mirrors `audienceAllows` in the rules.
    func canRead(audience: PostAudience, of owner: String) -> Bool {
        if owner == meUid { return true }
        if blocked[owner] != nil || blockedMe.contains(owner) { return false }
        switch audience {
        case .everyone: return true
        case .friends: return areFriends(meUid, owner)
        case .onlyMe: return false
        }
    }

    // MARK: Profiles

    func fetchProfile(uid: String) async throws -> FirestoreUserProfile {
        try check("fetchProfile")
        guard let profile = profiles[uid] else { throw SocialError.notFound }
        if uid == meUid { return profile }
        if privateUids.contains(uid) || blocked[uid] != nil || blockedMe.contains(uid) { throw SocialError.permissionDenied }
        switch profile.profileVisibility {
        case .everyone: return profile
        case .friends: if areFriends(meUid, uid) { return profile }; throw SocialError.permissionDenied
        case .onlyMe: throw SocialError.permissionDenied
        }
    }

    func lookupUser(handle: String) async throws -> UserLookup? {
        try check("lookupUser")
        let normalized = HandleRules.normalize(handle)
        guard HandleRules.isValid(normalized), let uid = handles[normalized] else { return nil }
        do { return UserLookup(uid: uid, handle: normalized, profile: try await fetchProfile(uid: uid)) }
        catch SocialError.permissionDenied { return UserLookup(uid: uid, handle: normalized, profile: nil) }
    }

    func ensureOwnProfile(displayName: String, handleHint: String?, privacy: PrivacySettings) async throws -> FirestoreUserProfile {
        try check("ensureOwnProfile")
        if let existing = profiles[meUid] { return existing }
        let handle = HandleRules.candidates(hint: handleHint ?? displayName, uid: meUid).first { handles[$0] == nil } ?? "pumper"
        addProfile(meUid, name: displayName, handle: handle, visibility: privacy.profileVisibility)
        profiles[meUid]?.globalLeaderboardVisible = privacy.globalLeaderboardVisible
        log.append("ensureOwnProfile")
        return profiles[meUid]!
    }

    func updateOwnProfile(_ update: ProfileUpdate) async throws {
        try check("updateOwnProfile")
        guard var profile = profiles[meUid] else { throw SocialError.notFound }
        if let v = update.displayName { profile.displayName = v }
        if let v = update.streak { profile.currentStreak = v }
        if let v = update.totalWorkouts { profile.totalWorkouts = v }
        if let v = update.profileVisibility { profile.profileVisibility = v }
        if let v = update.globalLeaderboardVisible { profile.globalLeaderboardVisible = v }
        profiles[meUid] = profile
        profileUpdates.append(update)
        log.append("updateOwnProfile")
    }

    // MARK: Privacy

    func savePrivacy(_ settings: PrivacySettings) async throws {
        try check("savePrivacy")
        privacyDocument = settings
        writtenPrivacy.append(settings)
        log.append("savePrivacy")
        try await updateOwnProfile(ProfileUpdate(profileVisibility: settings.profileVisibility,
                                                 globalLeaderboardVisible: settings.globalLeaderboardVisible))
    }

    func loadPrivacy() async throws -> PrivacySettings? {
        try check("loadPrivacy")
        return privacyDocument
    }

    // MARK: Follows

    func follow(uid: String) async throws {
        try check("follow")
        guard uid != meUid else { throw SocialError.invalid("self") }
        guard !blockedMe.contains(uid) else { throw SocialError.permissionDenied }
        follows.insert("\(meUid)_\(uid)")
        log.append("follow:\(uid)")
    }

    func unfollow(uid: String) async throws {
        try check("unfollow")
        follows.remove("\(meUid)_\(uid)")
        log.append("unfollow:\(uid)")
    }

    func fetchFollowing() async throws -> [FollowEdge] {
        try check("fetchFollowing")
        return follows.compactMap { id in
            let parts = id.split(separator: "_", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == meUid else { return nil }
            return FollowEdge(followerUid: parts[0], followeeUid: parts[1], createdAt: Date())
        }
    }

    func fetchFollowers() async throws -> [FollowEdge] {
        try check("fetchFollowers")
        return follows.compactMap { id in
            let parts = id.split(separator: "_", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[1] == meUid else { return nil }
            return FollowEdge(followerUid: parts[0], followeeUid: parts[1], createdAt: Date())
        }
    }

    // MARK: Blocks and reports

    func fetchBlocked() async throws -> [BlockedUser] {
        try check("fetchBlocked")
        return Array(blocked.values)
    }

    func block(_ user: BlockedUser) async throws {
        try check("block")
        blocked[user.uid] = user
        log.append("block:\(user.uid)")
    }

    func unblock(uid: String) async throws {
        try check("unblock")
        blocked[uid] = nil
        log.append("unblock:\(uid)")
    }

    func report(target: ReportTarget, targetId: String, reason: String, details: String?) async throws {
        try check("report")
        reports.append((target, targetId, reason))
        log.append("report:\(target.rawValue):\(targetId)")
    }

    // MARK: Posts

    func createPost(_ payload: PostPayload) async throws {
        try check("createPost")
        createdPosts.append(payload)
        log.append("createPost:\(payload.postId)")
        let existing = posts.first { $0.id == payload.postId }
        posts.removeAll { $0.id == payload.postId }
        posts.append(WorkoutFeedItem(
            id: payload.postId, userId: payload.authorUid, username: payload.authorName, handle: payload.authorUsername,
            templateName: payload.workoutName, exerciseCount: payload.exercises.count, durationSeconds: payload.stats.durationSec,
            prCount: payload.stats.prCount, totalExercises: payload.exercises.count, date: payload.date, createdAt: Date(),
            caption: payload.caption, exercises: payload.exercises, taggedFriendUids: payload.taggedUids,
            audience: payload.audience.rawValue, bodyMapAudience: payload.bodyMapAudience.rawValue,
            likeCount: existing?.likeCount ?? 0, commentCount: existing?.commentCount ?? 0))
        if let sets = payload.muscleSets { bodyMaps[payload.postId] = sets }
    }

    func updatePost(_ payload: PostPayload) async throws {
        try check("updatePost")
        log.append("updatePost:\(payload.postId)")
        guard let i = posts.firstIndex(where: { $0.id == payload.postId }), posts[i].userId == meUid else { throw SocialError.permissionDenied }
        posts[i].caption = payload.caption
        posts[i].exercises = payload.exercises
        posts[i].prCount = payload.stats.prCount
        posts[i].taggedFriendUids = payload.taggedUids
        posts[i].taggedNames = payload.taggedNames
        posts[i].photoURL = payload.photoURL
        posts[i].song = payload.song
        posts[i].isEdited = true
        bodyMaps[payload.postId] = payload.muscleSets
    }

    func deletePost(id: String) async throws {
        try check("deletePost")
        posts.removeAll { $0.id == id }
        bodyMaps[id] = nil
        log.append("deletePost:\(id)")
    }

    func fetchPosts(_ query: PostQuery) async throws -> [WorkoutFeedItem] {
        try check("fetchPosts")
        postQueries.append(query)
        // Rule emulation: visibility depends on other documents, so the query must pin the author
        // and an audience the caller may read, and stay within Firestore's 30-disjunction limit.
        guard !query.authorUids.isEmpty else { throw SocialError.invalid("no authors") }
        if rejectsMultiAuthorQueries && query.authorUids.count > 1 { throw SocialError.permissionDenied }
        if query.authorUids.count * max(1, query.audiences.count) > 30 { throw SocialError.invalid("too many disjunctions") }
        for author in query.authorUids {
            if author == meUid { continue }
            if blocked[author] != nil || blockedMe.contains(author) { throw SocialError.permissionDenied }
            guard !query.audiences.isEmpty else { throw SocialError.permissionDenied }   // unpinned audience
            for audience in query.audiences where !canRead(audience: audience, of: author) { throw SocialError.permissionDenied }
        }
        return posts
            .filter { query.authorUids.contains($0.userId) }
            .filter { post in
                query.audiences.isEmpty || query.audiences.contains(PostAudience(rawValue: post.audience ?? "") ?? .friends)
            }
            .filter { post in query.before.map { post.createdAt < $0 } ?? true }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(query.limit)
            .map { post in
                var copy = post
                copy.likedByMe = false            // per-viewer state comes from `likedPostIds`
                copy.muscleSets = [:]             // extras are separate documents
                return copy
            }
    }

    func fetchBodyMap(postId: String) async throws -> [String: Int]? {
        try check("fetchBodyMap")
        guard let post = posts.first(where: { $0.id == postId }), let map = bodyMaps[postId] else { return nil }
        let audience = PostAudience(rawValue: post.bodyMapAudience ?? "") ?? .friends
        return canRead(audience: audience, of: post.userId) ? map : nil
    }

    func likedPostIds(among postIds: [String]) async throws -> Set<String> {
        try check("likedPostIds")
        return Set(postIds.filter { likes[$0]?.contains(meUid) == true })
    }

    // MARK: Likes and comments

    func setLike(postId: String, liked: Bool) async throws {
        try check("setLike")
        if liked { likes[postId, default: []].insert(meUid) } else { likes[postId]?.remove(meUid) }
        log.append("setLike:\(postId):\(liked)")
    }

    func fetchComments(postId: String, limit: Int) async throws -> [FeedComment] {
        try check("fetchComments")
        return Array((comments[postId] ?? []).sorted { $0.date < $1.date }.prefix(limit))
    }

    func addComment(postId: String, text: String, authorName: String, authorUsername: String) async throws -> FeedComment {
        try check("addComment")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 500 else { throw SocialError.invalid("length") }
        let comment = FeedComment(userId: meUid, username: authorName, handle: authorUsername, text: trimmed)
        comments[postId, default: []].append(comment)
        log.append("addComment:\(postId)")
        return comment
    }

    func deleteComment(postId: String, commentId: String) async throws {
        try check("deleteComment")
        comments[postId]?.removeAll { $0.id == commentId }
        log.append("deleteComment:\(commentId)")
    }

    // MARK: Challenges

    func fetchMyChallenges() async throws -> [SocialChallenge] {
        try check("fetchMyChallenges")
        return challenges.values.filter { $0.creatorUid == meUid || members[$0.id]?.contains(meUid) == true }
            .sorted { $0.startAt > $1.startAt }
    }

    func fetchGlobalChallenges() async throws -> [SocialChallenge] {
        try check("fetchGlobalChallenges")
        return challenges.values.filter { $0.isGlobal && $0.status == .active }.sorted { $0.endAt < $1.endAt }
    }

    func fetchChallenge(id: String) async throws -> SocialChallenge {
        try check("fetchChallenge")
        guard let c = challenges[id] else { throw SocialError.notFound }
        return c
    }

    func createChallenge(_ draft: ChallengeDraft) async throws -> String {
        try check("createChallenge")
        let id = "ch\(challenges.count + 1)"
        createdChallenges.append(draft)
        challenges[id] = SocialChallenge(id: id, creatorUid: meUid, name: draft.name, metric: draft.metric,
                                         exerciseName: draft.exerciseName, startAt: draft.startAt, endAt: draft.endAt,
                                         isGlobal: false, visibility: draft.visibility, status: .active, memberCount: 0,
                                         winCondition: draft.winCondition, unit: draft.unit, customLabel: draft.customLabel)
        log.append("createChallenge:\(id)")
        return id
    }

    func joinChallenge(id: String, username: String) async throws {
        try check("joinChallenge")
        guard let c = challenges[id] else { throw SocialError.notFound }
        guard c.status == .active, c.endAt > now() else { throw SocialError.permissionDenied }
        let invited = invites[ChallengeInvite.docId(challengeId: id, toUid: meUid)] != nil
        guard c.isGlobal || c.creatorUid == meUid || invited else { throw SocialError.permissionDenied }
        members[id, default: []].insert(meUid)
        log.append("joinChallenge:\(id)")
    }

    func leaveChallenge(id: String) async throws {
        try check("leaveChallenge")
        members[id]?.remove(meUid)
        log.append("leaveChallenge:\(id)")
    }

    func isMember(challengeId: String) async throws -> Bool {
        try check("isMember")
        return members[challengeId]?.contains(meUid) == true
    }

    func fetchLeaderboard(challengeId: String, isGlobal: Bool, limit: Int) async throws -> [ChallengeEntry] {
        try check("fetchLeaderboard")
        let all = entries[challengeId] ?? []
        if isGlobal {
            return Array(all.filter { !$0.hidden }.sorted { $0.rank < $1.rank }.prefix(limit))
        }
        return Array(all.sorted { $0.score != $1.score ? $0.score > $1.score : ($0.scoreAt ?? .distantFuture) < ($1.scoreAt ?? .distantFuture) }.prefix(limit))
    }

    func fetchMyEntry(challengeId: String) async throws -> ChallengeEntry? {
        try check("fetchMyEntry")
        return entries[challengeId]?.first { $0.uid == meUid }
    }

    func fetchEntries(challengeId: String, ranks: ClosedRange<Int>) async throws -> [ChallengeEntry] {
        try check("fetchEntries")
        return (entries[challengeId] ?? []).filter { !$0.hidden && ranks.contains($0.rank) }.sorted { $0.rank < $1.rank }
    }

    // MARK: Invites

    func fetchPendingInvites() async throws -> [ChallengeInvite] {
        try check("fetchPendingInvites")
        return invites.values.filter { $0.toUid == meUid && $0.status == .pending }.sorted { $0.createdAt > $1.createdAt }
    }

    func sendInvite(challengeId: String, challengeName: String, fromUsername: String, toUid: String) async throws {
        try check("sendInvite")
        guard !blocked.keys.contains(toUid), toUid != meUid else { throw SocialError.permissionDenied }
        let invite = ChallengeInvite(challengeId: challengeId, challengeName: challengeName, fromUid: meUid,
                                     fromUsername: fromUsername, toUid: toUid)
        if invites[invite.id] == nil { invites[invite.id] = invite }
        log.append("sendInvite:\(invite.id)")
    }

    func respondToInvite(_ invite: ChallengeInvite, accept: Bool) async throws {
        try check("respondToInvite")
        invites[invite.id]?.status = accept ? .accepted : .declined
        log.append("respondToInvite:\(invite.id):\(accept)")
    }
}
#endif
