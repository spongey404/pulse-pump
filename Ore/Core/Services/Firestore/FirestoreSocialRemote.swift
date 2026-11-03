import Foundation
import FirebaseAuth
import FirebaseFirestore

/// The real `SocialRemote`, backed by Firestore. Document shapes come from `SocialWire`, which
/// follows `docs/sync-architecture.md` and `firebase/firestore.rules` exactly (the rules use
/// `hasOnly` on most documents).
///
/// Queries rely on these indexes from `firebase/firestore.indexes.json`:
/// posts (authorUid, audience, createdAt desc) and (authorUid, createdAt desc);
/// follows (followerUid|followeeUid, createdAt desc); entries (score desc, scoreAt asc) and (hidden, rank);
/// invites (toUid, status, createdAt desc); challenges (isGlobal, status, endAt) and (creatorUid, startAt desc);
/// plus the `members.uid` collection-group override.
@MainActor
final class FirestoreSocialRemote: SocialRemote {
    private let db: Firestore
    private let user: CurrentUser

    init(user: CurrentUser? = nil, db: Firestore? = nil) {
        self.user = user ?? FirebaseCurrentUser()
        self.db = db ?? Firestore.firestore()
    }

    // MARK: Helpers

    private func requireUid() throws -> String {
        guard let uid = user.uid else { throw SocialError.notSignedIn }
        return uid
    }

    private static func mapError(_ error: Error) -> SocialError {
        if let social = error as? SocialError { return social }
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .permissionDenied, .unauthenticated: return .permissionDenied
            case .notFound: return .notFound
            default: break
            }
        }
        return .unavailable(ns.localizedDescription)
    }

    private func run<T>(_ body: () async throws -> T) async throws -> T {
        do { return try await body() } catch { throw Self.mapError(error) }
    }

    /// `Date` -> `Timestamp`, recursively.
    private static func encode(_ data: [String: Any]) -> [String: Any] {
        data.mapValues(encodeValue)
    }

    private static func encodeValue(_ value: Any) -> Any {
        switch value {
        case let d as Date: return Timestamp(date: d)
        case let dict as [String: Any]: return dict.mapValues(encodeValue)
        case let arr as [Any]: return arr.map(encodeValue)
        default: return value
        }
    }

    /// `Timestamp` -> `Date`, recursively.
    private static func decode(_ data: [String: Any]?) -> [String: Any] {
        (data ?? [:]).mapValues(decodeValue)
    }

    private static func decodeValue(_ value: Any) -> Any {
        switch value {
        case let t as Timestamp: return t.dateValue()
        case let dict as [String: Any]: return dict.mapValues(decodeValue)
        case let arr as [Any]: return arr.map(decodeValue)
        default: return value
        }
    }

    private func set(_ ref: DocumentReference, _ data: [String: Any], merge: Bool = false) async throws {
        try await ref.setData(Self.encode(data), merge: merge)
    }

    // MARK: Profiles

    func fetchProfile(uid: String) async throws -> FirestoreUserProfile {
        try await run {
            let snap = try await db.collection("profiles").document(uid).getDocument()
            guard snap.exists else { throw SocialError.notFound }
            return SocialWire.profile(from: Self.decode(snap.data()), uid: uid)
        }
    }

    func lookupUser(handle: String) async throws -> UserLookup? {
        let normalized = HandleRules.normalize(handle)
        guard HandleRules.isValid(normalized) else { return nil }
        return try await run {
            let snap = try await db.collection("usernames").document(normalized).getDocument()
            guard snap.exists, let uid = snap.data()?["uid"] as? String else { return nil }
            do {
                let profile = try await fetchProfile(uid: uid)
                return UserLookup(uid: uid, handle: normalized, profile: profile)
            } catch SocialError.permissionDenied {
                return UserLookup(uid: uid, handle: normalized, profile: nil)
            } catch SocialError.notFound {
                return nil
            }
        }
    }

    func ensureOwnProfile(displayName: String, handleHint: String?, privacy: PrivacySettings) async throws -> FirestoreUserProfile {
        let uid = try requireUid()
        // The owner can always read their own profile; a missing document is reported by the rules as
        // a denial because `resource` is null, so both outcomes mean "create it".
        do { return try await fetchProfile(uid: uid) }
        catch SocialError.notFound {}
        catch SocialError.permissionDenied {}

        let name = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        for handle in HandleRules.candidates(hint: handleHint ?? name, uid: uid) {
            var claim = true
            if let taken = try? await db.collection("usernames").document(handle).getDocument(), taken.exists {
                if (taken.data()?["uid"] as? String) == uid { claim = false } else { continue }
            }
            do { return try await createProfile(uid: uid, handle: handle, name: name, privacy: privacy, claim: claim) }
            catch SocialError.permissionDenied { continue }   // lost the race for this handle
        }
        throw SocialError.unavailable("Couldn't reserve a handle")
    }

    private func createProfile(uid: String, handle: String, name: String, privacy: PrivacySettings, claim: Bool) async throws -> FirestoreUserProfile {
        try await run {
            let now = Date()
            if claim {
                try await set(db.collection("usernames").document(handle), ["uid": uid, "createdAt": now])
            }
            try await set(db.collection("profiles").document(uid),
                          SocialWire.newProfileDocument(name: name, handle: handle, privacy: privacy, now: now))
            return FirestoreUserProfile(uid: uid, username: handle, displayName: name,
                                        profileVisibility: privacy.profileVisibility,
                                        globalLeaderboardVisible: privacy.globalLeaderboardVisible)
        }
    }

    func updateOwnProfile(_ update: ProfileUpdate) async throws {
        let uid = try requireUid()
        let fields = Self.encode(SocialWire.profileUpdateDocument(update, now: Date()))
        try await run { try await db.collection("profiles").document(uid).updateData(fields) }
    }

    // MARK: Privacy

    func savePrivacy(_ settings: PrivacySettings) async throws {
        let uid = try requireUid()
        try await run {
            try await set(db.collection("users").document(uid), SocialWire.privacyDocument(settings), merge: true)
        }
        try await updateOwnProfile(ProfileUpdate(profileVisibility: settings.profileVisibility,
                                                 globalLeaderboardVisible: settings.globalLeaderboardVisible))
    }

    func loadPrivacy() async throws -> PrivacySettings? {
        let uid = try requireUid()
        return try await run {
            let snap = try await db.collection("users").document(uid).getDocument()
            guard let map = snap.data()?["privacy"] as? [String: Any], !map.isEmpty else { return nil }
            return PrivacySettings(firestoreMap: map)
        }
    }

    // MARK: Follows

    func follow(uid target: String) async throws {
        let me = try requireUid()
        guard target != me else { throw SocialError.invalid("Can't follow yourself") }
        do {
            try await run {
                try await set(db.collection("follows").document(SocialWire.followId(follower: me, followee: target)),
                              SocialWire.followDocument(follower: me, followee: target, now: Date()))
            }
        } catch SocialError.permissionDenied {
            // The rules forbid updating an edge, so following someone you already follow (a retry after a lost
            // response, a double tap) is "denied". That is success, not an error; a real denial (a block) stays one.
            if try await edgeExists(follower: me, followee: target) { return }
            throw SocialError.permissionDenied
        }
    }

    /// A query (not a get): reading a missing edge document by id is refused by the rules, the query is allowed.
    private func edgeExists(follower: String, followee: String) async throws -> Bool {
        try await run {
            let snap = try await db.collection("follows")
                .whereField("followerUid", isEqualTo: follower)
                .whereField("followeeUid", isEqualTo: followee)
                .limit(to: 1)
                .getDocuments()
            return !snap.documents.isEmpty
        }
    }

    func unfollow(uid target: String) async throws {
        let me = try requireUid()
        try await run { try await db.collection("follows").document(SocialWire.followId(follower: me, followee: target)).delete() }
    }

    private func edges(field: String) async throws -> [FollowEdge] {
        let me = try requireUid()
        return try await run {
            let snap = try await db.collection("follows")
                .whereField(field, isEqualTo: me)
                .order(by: "createdAt", descending: true)
                .limit(to: 1000)
                .getDocuments()
            return snap.documents.compactMap { SocialWire.follow(from: Self.decode($0.data())) }
        }
    }

    func fetchFollowing() async throws -> [FollowEdge] { try await edges(field: "followerUid") }
    func fetchFollowers() async throws -> [FollowEdge] { try await edges(field: "followeeUid") }

    // MARK: Blocks and reports

    func fetchBlocked() async throws -> [BlockedUser] {
        let me = try requireUid()
        return try await run {
            let snap = try await db.collection("users").document(me).collection("blocked").getDocuments()
            return snap.documents.map { SocialWire.blocked(from: Self.decode($0.data()), uid: $0.documentID) }
        }
    }

    func block(_ blocked: BlockedUser) async throws {
        let me = try requireUid()
        guard blocked.uid != me else { throw SocialError.invalid("Can't block yourself") }
        try await run {
            try await set(db.collection("users").document(me).collection("blocked").document(blocked.uid), SocialWire.blockedDocument(blocked))
        }
    }

    func unblock(uid other: String) async throws {
        let me = try requireUid()
        try await run { try await db.collection("users").document(me).collection("blocked").document(other).delete() }
    }

    func report(target: ReportTarget, targetId: String, reason: String, details: String?) async throws {
        let me = try requireUid()
        let data = Self.encode(SocialWire.reportDocument(reporter: me, target: target, targetId: targetId,
                                                         reason: reason, details: details, now: Date()))
        try await run { _ = try await db.collection("reports").addDocument(data: data) }
    }

    // MARK: Posts

    func createPost(_ p: PostPayload) async throws {
        let me = try requireUid()
        guard p.authorUid == me else { throw SocialError.invalid("Author mismatch") }
        try await run {
            let now = Date()
            let ref = db.collection("posts").document(p.postId)
            // merge:true keeps the function-owned counters of an already existing post unchanged, so
            // re-posting the same workout is idempotent instead of being refused by the rules.
            try await set(ref, SocialWire.postDocument(p, now: now), merge: true)

            // The body map is a separate document guarded by `bodyMapAudience`. It needs the post to
            // exist first (its rules read the parent post).
            if let sets = p.muscleSets, !sets.isEmpty {
                try await set(ref.collection("extras").document("bodymap"), SocialWire.bodyMapDocument(sets, now: now))
            }
        }
    }

    func updatePost(_ p: PostPayload) async throws {
        let me = try requireUid()
        guard p.authorUid == me else { throw SocialError.invalid("Author mismatch") }
        try await run {
            let ref = db.collection("posts").document(p.postId)
            let full = SocialWire.postDocument(p, now: Date())
            // Only the content fields: counters, author, audience and createdAt stay as they were.
            var fields: [String: Any] = ["stats": full["stats"] as Any, "exercises": full["exercises"] as Any, "workoutName": full["workoutName"] as Any,
                                          "editedAt": p.editedAt ?? Date()]
            for key in ["caption", "taggedUids", "taggedNames", "photoURL", "song"] { fields[key] = full[key] ?? FieldValue.delete() }
            try await ref.updateData(Self.encode(fields))
            if let sets = p.muscleSets, !sets.isEmpty {
                try await set(ref.collection("extras").document("bodymap"), SocialWire.bodyMapDocument(sets, now: Date()))
            } else {
                try? await ref.collection("extras").document("bodymap").delete()
            }
        }
    }

    func deletePost(id: String) async throws {
        try await run {
            let ref = db.collection("posts").document(id)
            try? await ref.collection("extras").document("bodymap").delete()   // its rules need the post to still exist
            try await ref.delete()
        }
    }

    func fetchPosts(_ query: PostQuery) async throws -> [WorkoutFeedItem] {
        guard !query.authorUids.isEmpty else { return [] }
        return try await run {
            var q: Query = db.collection("posts")
            q = query.authorUids.count == 1
                ? q.whereField("authorUid", isEqualTo: query.authorUids[0])
                : q.whereField("authorUid", in: query.authorUids)
            if query.audiences.count == 1 {
                q = q.whereField("audience", isEqualTo: query.audiences[0].rawValue)
            } else if query.audiences.count > 1 {
                q = q.whereField("audience", in: query.audiences.map(\.rawValue))
            }
            if let before = query.before { q = q.whereField("createdAt", isLessThan: Timestamp(date: before)) }
            let snap = try await q.order(by: "createdAt", descending: true).limit(to: query.limit).getDocuments()
            return snap.documents.compactMap { SocialWire.post(from: Self.decode($0.data()), id: $0.documentID) }
        }
    }

    func fetchBodyMap(postId: String) async throws -> [String: Int]? {
        do {
            let snap = try await db.collection("posts").document(postId).collection("extras").document("bodymap").getDocument()
            return SocialWire.muscleSets(from: Self.decode(snap.data()))
        } catch {
            let mapped = Self.mapError(error)
            if mapped == .permissionDenied || mapped == .notFound { return nil }
            throw mapped
        }
    }

    func likedPostIds(among postIds: [String]) async throws -> Set<String> {
        let me = try requireUid()
        var liked = Set<String>()
        for id in postIds {
            if let snap = try? await db.collection("posts").document(id).collection("likes").document(me).getDocument(), snap.exists {
                liked.insert(id)
            }
        }
        return liked
    }

    // MARK: Likes and comments

    func setLike(postId: String, liked: Bool) async throws {
        let me = try requireUid()
        try await run {
            let ref = db.collection("posts").document(postId).collection("likes").document(me)
            if liked {
                try await set(ref, SocialWire.likeDocument(uid: me, now: Date()))
            } else {
                try await ref.delete()
            }
        }
    }

    func fetchComments(postId: String, limit: Int) async throws -> [FeedComment] {
        try await run {
            let snap = try await db.collection("posts").document(postId).collection("comments")
                .order(by: "createdAt", descending: false)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { SocialWire.comment(from: Self.decode($0.data()), id: $0.documentID) }
        }
    }

    func addComment(postId: String, text: String, authorName: String, authorUsername: String) async throws -> FeedComment {
        let me = try requireUid()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 500 else { throw SocialError.invalid("Comments are 1 to 500 characters") }
        return try await run {
            let ref = db.collection("posts").document(postId).collection("comments").document()
            let now = Date()
            try await set(ref, SocialWire.commentDocument(authorUid: me, authorName: authorName, authorUsername: authorUsername, text: trimmed, now: now))
            return FeedComment(id: ref.documentID, userId: me, username: authorName, handle: authorUsername, text: trimmed, date: now)
        }
    }

    func deleteComment(postId: String, commentId: String) async throws {
        try await run { try await db.collection("posts").document(postId).collection("comments").document(commentId).delete() }
    }

    // MARK: Challenges

    private static func challenge(from doc: DocumentSnapshot) -> SocialChallenge? {
        SocialWire.challenge(from: decode(doc.data()), id: doc.documentID)
    }

    func fetchMyChallenges() async throws -> [SocialChallenge] {
        let me = try requireUid()
        return try await run {
            var byId: [String: SocialChallenge] = [:]
            let created = try await db.collection("challenges")
                .whereField("creatorUid", isEqualTo: me)
                .order(by: "startAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            for doc in created.documents { if let c = Self.challenge(from: doc) { byId[c.id] = c } }

            let memberships = try await db.collectionGroup("members").whereField("uid", isEqualTo: me).getDocuments()
            for doc in memberships.documents {
                guard let id = doc.reference.parent.parent?.documentID, byId[id] == nil else { continue }
                // A challenge deleted by its creator can't be read any more; skip it.
                if let snap = try? await db.collection("challenges").document(id).getDocument(),
                   snap.exists, let c = Self.challenge(from: snap) { byId[id] = c }
            }
            return byId.values.sorted { $0.startAt > $1.startAt }
        }
    }

    func fetchGlobalChallenges() async throws -> [SocialChallenge] {
        try await run {
            let snap = try await db.collection("challenges")
                .whereField("isGlobal", isEqualTo: true)
                .whereField("status", isEqualTo: ChallengeStatus.active.rawValue)
                .order(by: "endAt", descending: false)
                .limit(to: 10)
                .getDocuments()
            return snap.documents.compactMap(Self.challenge(from:))
        }
    }

    func fetchChallenge(id: String) async throws -> SocialChallenge {
        try await run {
            let snap = try await db.collection("challenges").document(id).getDocument()
            guard snap.exists, let c = Self.challenge(from: snap) else { throw SocialError.notFound }
            return c
        }
    }

    func createChallenge(_ draft: ChallengeDraft) async throws -> String {
        let me = try requireUid()
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else { throw SocialError.invalid("Name must be 1 to 100 characters") }
        guard draft.endAt > draft.startAt else { throw SocialError.invalid("The end must be after the start") }
        return try await run {
            let ref = db.collection("challenges").document()
            try await set(ref, SocialWire.challengeDocument(draft, creator: me, now: Date()))
            return ref.documentID
        }
    }

    func joinChallenge(id: String, username: String) async throws {
        let me = try requireUid()
        try await run {
            try await set(db.collection("challenges").document(id).collection("members").document(me),
                          SocialWire.memberDocument(uid: me, username: username, now: Date()))
        }
    }

    func leaveChallenge(id: String) async throws {
        let me = try requireUid()
        try await run { try await db.collection("challenges").document(id).collection("members").document(me).delete() }
    }

    func isMember(challengeId: String) async throws -> Bool {
        let me = try requireUid()
        return try await run {
            try await db.collection("challenges").document(challengeId).collection("members").document(me).getDocument().exists
        }
    }

    func fetchLeaderboard(challengeId: String, isGlobal: Bool, limit: Int) async throws -> [ChallengeEntry] {
        try await run {
            let entries = db.collection("challenges").document(challengeId).collection("entries")
            let snap: QuerySnapshot
            if isGlobal {
                // Globally readable entries are the visible ones; the rules require the query to say so.
                snap = try await entries.whereField("hidden", isEqualTo: false).order(by: "rank").limit(to: limit).getDocuments()
            } else {
                snap = try await entries.order(by: "score", descending: true).order(by: "scoreAt").limit(to: limit).getDocuments()
            }
            return snap.documents.map { SocialWire.entry(from: Self.decode($0.data()), id: $0.documentID) }
        }
    }

    func fetchMyEntry(challengeId: String) async throws -> ChallengeEntry? {
        let me = try requireUid()
        return try await run {
            let snap = try await db.collection("challenges").document(challengeId).collection("entries").document(me).getDocument()
            return snap.exists ? SocialWire.entry(from: Self.decode(snap.data()), id: snap.documentID) : nil
        }
    }

    func fetchEntries(challengeId: String, ranks: ClosedRange<Int>) async throws -> [ChallengeEntry] {
        try await run {
            let snap = try await db.collection("challenges").document(challengeId).collection("entries")
                .whereField("hidden", isEqualTo: false)
                .whereField("rank", isGreaterThanOrEqualTo: ranks.lowerBound)
                .whereField("rank", isLessThanOrEqualTo: ranks.upperBound)
                .order(by: "rank")
                .getDocuments()
            return snap.documents.map { SocialWire.entry(from: Self.decode($0.data()), id: $0.documentID) }
        }
    }

    // MARK: Invites

    func fetchPendingInvites() async throws -> [ChallengeInvite] {
        let me = try requireUid()
        return try await run {
            let snap = try await db.collection("invites")
                .whereField("toUid", isEqualTo: me)
                .whereField("status", isEqualTo: ChallengeInviteStatus.pending.rawValue)
                .order(by: "createdAt", descending: true)
                .limit(to: 25)
                .getDocuments()
            return snap.documents.compactMap { SocialWire.invite(from: Self.decode($0.data()), id: $0.documentID, me: me) }
        }
    }

    func sendInvite(challengeId: String, challengeName: String, fromUsername: String, toUid: String) async throws {
        let me = try requireUid()
        let invite = ChallengeInvite(challengeId: challengeId, challengeName: challengeName, fromUid: me,
                                     fromUsername: fromUsername, toUid: toUid)
        try await run {
            let ref = db.collection("invites").document(invite.id)
            // Idempotent: an existing invite (readable by its sender) is never rewritten.
            if let existing = try? await ref.getDocument(), existing.exists { return }
            try await set(ref, SocialWire.inviteDocument(invite))
        }
    }

    func respondToInvite(_ invite: ChallengeInvite, accept: Bool) async throws {
        try await run {
            try await db.collection("invites").document(invite.id).updateData([
                "status": (accept ? ChallengeInviteStatus.accepted : ChallengeInviteStatus.declined).rawValue,
            ])
        }
    }
}

// MARK: - Handles

/// Rules for `usernames/{handle}`: `[a-z0-9._]{3,20}`.
enum HandleRules {
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
    }

    static func isValid(_ handle: String) -> Bool {
        guard (3...20).contains(handle.count) else { return false }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._")
        return handle.allSatisfy { allowed.contains($0) }
    }

    /// A valid base handle derived from a name (or an email local part).
    static func sanitize(_ hint: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._")
        var base = String(hint.lowercased().filter { allowed.contains($0) }.prefix(16))
        if base.count < 3 { base = String((base + "pumper").prefix(10)) }
        return base
    }

    /// Handles to try in order: the plain one, then numbered variants. Deterministic for a given uid.
    static func candidates(hint: String, uid: String) -> [String] {
        let base = sanitize(hint)
        let seed = uid.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 9000 } + 1000
        var list = [base]
        for i in 0..<6 {
            let suffix = String((seed + i * 137) % 10000)
            list.append(String(base.prefix(20 - suffix.count)) + suffix)
        }
        return list
    }
}
