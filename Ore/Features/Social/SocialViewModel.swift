import Foundation
import Observation

/// Challenge leaderboard as shown by 3c/3d/7b.
struct ChallengeBoard: Equatable {
    var rows: [LeaderboardRow]
    var mine: LeaderboardRow?
    var isMember: Bool
}

/// A profile page (6b / 7c) for the signed-in viewer.
struct ProfilePage: Equatable {
    var uid: String
    var relationship: Relationship
    var access: ProfileAccess
    var profile: FirestoreUserProfile?
    var posts: [WorkoutFeedItem]
}

/// Owns everything the Social tab shows: the follow graph (friends / fans), the feed, comments and
/// likes, profiles, challenges and invites, blocks and reports, and privacy.
///
/// Rules this type follows (docs/sync-architecture.md):
/// - Counters (`likeCount`, `commentCount`, `friendCount`, `fanCount`, `memberCount`, scores, ranks)
///   are never written. Likes and comments adjust the shown count optimistically and roll back on failure.
/// - Posts are only queried per author with an audience the viewer may see; blocked users are never queried.
/// - There are no demo fixtures here. DEBUG fixtures, if any, arrive through the `SocialRemote`.
@MainActor
@Observable
final class SocialViewModel {
    @ObservationIgnored let remote: SocialRemote
    @ObservationIgnored let me: CurrentUser
    @ObservationIgnored let privacyService: PrivacyService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let displayName: () -> String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let onFeedLoaded: ([WorkoutFeedItem], String) -> Void

    // MARK: State

    /// The uid the current state belongs to. When Auth reports a different uid every cache is dropped.
    @ObservationIgnored private var stateUid: String?

    private(set) var myProfile: FirestoreUserProfile?

    // Follow graph
    private(set) var graph = FriendGraph()
    private(set) var graphLoaded = false
    private(set) var profileCache: [String: FirestoreUserProfile] = [:]
    /// Accounts that no longer exist; dropped from every list.
    private(set) var goneUids: Set<String> = []
    private(set) var blockedUsers: [BlockedUser] = []

    // Search
    private(set) var searchResults: [UserLookup] = []
    private(set) var isSearching = false
    @ObservationIgnored private var searchToken = UUID()

    // Feed
    private(set) var feedItems: [WorkoutFeedItem] = []
    private(set) var isLoadingFeed = false
    private(set) var isLoadingMoreFeed = false
    private(set) var hasMoreFeed = false
    private(set) var feedError: String?
    @ObservationIgnored private var lastFeedFetch: Date?
    @ObservationIgnored private var singleAuthorQueries = false
    private(set) var hiddenPostIds: Set<String> = []
    /// Friends whose posts the viewer muted (kept on this device; they are still friends and still see yours).
    private(set) var mutedUids: Set<String> = []
    static let cacheTTL: TimeInterval = 5 * 60

    // Comments
    private(set) var comments: [String: [FeedComment]] = [:]

    // Challenges
    private(set) var myChallenges: [SocialChallenge] = []
    private(set) var globalChallenges: [SocialChallenge] = []
    private(set) var pendingChallengeInvites: [ChallengeInvite] = []
    private(set) var boards: [String: ChallengeBoard] = [:]
    private(set) var isLoadingChallenges = false
    private(set) var challengesError: String?

    // Posting
    /// A post that could not be published; shown with a RETRY.
    private(set) var pendingPost: PostPayload?
    @ObservationIgnored private var publishedPostIds: Set<String> = []

    /// Set when an optimistic action fails and was rolled back; views surface it once.
    var lastError: String?

    @ObservationIgnored private var likeInFlight: Set<String> = []

    /// - Parameters:
    ///   - displayName: the name for a new profile; defaults to the local `User` name, then Firebase's.
    ///   - onFeedLoaded: called with a freshly loaded page; defaults to refreshing the widget's friends.
    init(remote: SocialRemote, me: CurrentUser, privacy: PrivacyService, defaults: UserDefaults = .standard,
         displayName: (() -> String)? = nil,
         now: @escaping () -> Date = { Date() },
         onFeedLoaded: (([WorkoutFeedItem], String) -> Void)? = nil) {
        self.remote = remote
        self.me = me
        self.privacyService = privacy
        self.defaults = defaults
        self.displayName = displayName ?? { SocialServices.localName ?? SocialServices.currentUser.displayName ?? Brand.defaultUserName }
        self.now = now
        self.onFeedLoaded = onFeedLoaded ?? { items, uid in WidgetDataService.writeFriends(from: items, myUid: uid) }
    }

    /// Shared instance used by the tab views.
    static var shared: SocialViewModel { SocialServices.viewModel }

    var currentUid: String? { me.uid }

    // MARK: Identity

    /// Drops all cached state when the signed-in account changed (sign-out, account switch, deletion).
    /// Returns false when nobody is signed in.
    @discardableResult
    private func syncIdentity() -> Bool {
        if stateUid != me.uid {
            reset()
            stateUid = me.uid
            if let uid = me.uid {
                hiddenPostIds = Set(defaults.stringArray(forKey: Self.hiddenKey(uid)) ?? [])
                mutedUids = Set(defaults.stringArray(forKey: Self.mutedKey(uid)) ?? [])
            }
        }
        return me.uid != nil
    }

    func reset() {
        myProfile = nil
        graph = FriendGraph()
        graphLoaded = false
        profileCache = [:]
        goneUids = []
        blockedUsers = []
        searchResults = []
        feedItems = []
        hasMoreFeed = false
        feedError = nil
        lastFeedFetch = nil
        comments = [:]
        myChallenges = []
        globalChallenges = []
        pendingChallengeInvites = []
        boards = [:]
        hiddenPostIds = []
        mutedUids = []
        pendingPost = nil
        likeInFlight = []
    }

    var myName: String {
        if let name = myProfile?.displayName, !name.isEmpty { return name }
        return displayName()
    }
    var myHandle: String { myProfile?.username ?? "" }

    func loadMyProfile() async {
        guard syncIdentity() else { return }
        do {
            myProfile = try await remote.ensureOwnProfile(displayName: displayName(), handleHint: SocialServices.localHandle, privacy: privacyService.settings)
        } catch {
            // Offline: keep whatever we had.
        }
    }

    /// Keeps `profiles/{me}` (name, streak, total workouts) in step with the local workouts. Only
    /// changed values are written, so a returning user is never reset to zeros.
    func syncOwnStats(streak: Int, totalWorkouts: Int) async {
        guard syncIdentity() else { return }
        if myProfile == nil { await loadMyProfile() }
        guard let profile = myProfile else { return }
        var update = ProfileUpdate()
        if profile.currentStreak != streak { update.streak = streak }
        if profile.totalWorkouts != totalWorkouts { update.totalWorkouts = totalWorkouts }
        let name = displayName()
        if !name.isEmpty, !Brand.isPlaceholderUserName(name), profile.displayName != name { update.displayName = name }
        guard update != ProfileUpdate() else { return }
        do {
            try await remote.updateOwnProfile(update)
            if let v = update.streak { myProfile?.currentStreak = v }
            if let v = update.totalWorkouts { myProfile?.totalWorkouts = v }
            if let v = update.displayName { myProfile?.displayName = v }
        } catch {
            // Retried on the next sync.
        }
    }

    // MARK: Privacy

    var privacy: PrivacySettings { privacyService.settings }

    func setPrivacy(_ row: PrivacyRow, _ level: PrivacyLevel) async {
        await privacyService.set(row, to: level)
        if row == .profile { myProfile?.profileVisibility = level.audience }
        if row == .globalLeaderboards { myProfile?.globalLeaderboardVisible = privacy.globalLeaderboardVisible }
    }

    func restorePrivacy() async {
        guard syncIdentity() else { return }
        await privacyService.restore()
    }

    // MARK: Follow graph

    func loadGraph() async {
        guard syncIdentity() else { return }
        do {
            async let following = remote.fetchFollowing()
            async let followers = remote.fetchFollowers()
            async let blocked = remote.fetchBlocked()
            let (a, b, c) = try await (following, followers, blocked)
            blockedUsers = c
            graph = FriendGraph(following: a, followers: b, blocked: Set(c.map(\.uid)), dismissedFans: loadDismissed())
            graphLoaded = true
            await loadProfiles(for: graph.friends.union(graph.fans).union(graph.pendingOutgoing))
        } catch {
            // Keep the previous graph; the views show their last known state.
        }
    }

    /// Fills the profile cache for the given uids. A profile the viewer may not read becomes a
    /// "private" placeholder; a missing one marks the account as gone (deleted).
    func loadProfiles(for uids: Set<String>) async {
        let missing = uids.filter { profileCache[$0] == nil && !goneUids.contains($0) }.sorted().prefix(80)
        guard !missing.isEmpty else { return }
        let results = await withTaskGroup(of: (String, Result<FirestoreUserProfile, SocialError>).self) { group -> [(String, Result<FirestoreUserProfile, SocialError>)] in
            for uid in missing {
                group.addTask { @MainActor in
                    do { return (uid, .success(try await self.remote.fetchProfile(uid: uid))) }
                    catch let e as SocialError { return (uid, .failure(e)) }
                    catch { return (uid, .failure(.unavailable(error.localizedDescription))) }
                }
            }
            var all: [(String, Result<FirestoreUserProfile, SocialError>)] = []
            for await r in group { all.append(r) }
            return all
        }
        for (uid, result) in results {
            switch result {
            case .success(let profile): profileCache[uid] = profile
            case .failure(.notFound): goneUids.insert(uid)
            case .failure(.permissionDenied): profileCache[uid] = .restricted(uid: uid)
            case .failure: break   // transient: try again next time
            }
        }
    }

    private func visibleProfiles(_ uids: Set<String>) -> [FirestoreUserProfile] {
        uids.subtracting(goneUids).compactMap { profileCache[$0] }
            .sorted { $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending }
    }

    /// Mutual follows.
    var friends: [FirestoreUserProfile] { visibleProfiles(graph.friends) }
    /// People who follow me and I don't follow back (all of them, including ignored requests).
    var fans: [FirestoreUserProfile] { visibleProfiles(graph.fans) }
    /// The inbox: fans I haven't answered. ACCEPT = follow back, IGNORE = dismiss.
    var fanRequests: [FirestoreUserProfile] { visibleProfiles(graph.fanRequests) }
    /// People I follow who haven't followed back.
    var followingOnly: [FirestoreUserProfile] { visibleProfiles(graph.pendingOutgoing) }

    /// Counts for the More tab: the loaded graph once available, the function-maintained counters before.
    var friendCount: Int { graphLoaded ? graph.friends.subtracting(goneUids).count : (myProfile?.friendCount ?? 0) }
    var fanCount: Int { graphLoaded ? graph.fans.subtracting(goneUids).count : (myProfile?.fanCount ?? 0) }

    /// Badge on the bell: requests + challenge invites.
    var inboxCount: Int { graph.fanRequests.subtracting(goneUids).count + pendingChallengeInvites.count }

    func relationship(with uid: String) -> Relationship { graph.relationship(with: uid, me: me.uid) }

    private static func dismissedKey(_ uid: String) -> String { "social.dismissedFans.\(uid)" }
    private static func hiddenKey(_ uid: String) -> String { "social.hiddenPosts.\(uid)" }
    private static func mutedKey(_ uid: String) -> String { "social.mutedFriends.\(uid)" }

    private func loadDismissed() -> Set<String> {
        guard let uid = me.uid else { return [] }
        return Set(defaults.stringArray(forKey: Self.dismissedKey(uid)) ?? [])
    }

    private func saveDismissed() {
        guard let uid = me.uid else { return }
        defaults.set(Array(graph.dismissedFans).sorted(), forKey: Self.dismissedKey(uid))
    }

    /// FOLLOW (stranger -> following) and ACCEPT / FOLLOW BACK (fan -> friend). Optimistic, rolled back on failure.
    @discardableResult
    func follow(_ uid: String) async -> Bool {
        guard syncIdentity(), uid != me.uid else { return false }
        let before = graph
        guard graph.follow(uid) else {
            lastError = "You can't follow someone you blocked."
            return false
        }
        saveDismissed()
        do {
            try await remote.follow(uid: uid)
            lastFeedFetch = nil
            await loadProfiles(for: [uid])
            return true
        } catch {
            graph = before
            saveDismissed()
            lastError = "Couldn't follow. Try again."
            return false
        }
    }

    @discardableResult
    func unfollow(_ uid: String) async -> Bool {
        guard syncIdentity() else { return false }
        let before = graph
        graph.unfollow(uid)
        do {
            try await remote.unfollow(uid: uid)
            lastFeedFetch = nil
            feedItems.removeAll { $0.userId == uid && !isFriendOrMe($0.userId) }
            return true
        } catch {
            graph = before
            lastError = "Couldn't unfollow. Try again."
            return false
        }
    }

    private func isFriendOrMe(_ uid: String) -> Bool { uid == me.uid || graph.friends.contains(uid) }

    /// ACCEPT on a request: follow back, which makes you friends.
    @discardableResult
    func accept(_ uid: String) async -> Bool { await follow(uid) }

    /// IGNORE on a request: dismiss it. Nothing is written; the person stays a fan.
    func ignore(_ uid: String) {
        graph.ignoreFan(uid)
        saveDismissed()
    }

    // MARK: Search

    /// Exact-handle lookup (the rules allow reading `usernames/{handle}` but not listing). Results never
    /// include me or people I blocked.
    func searchUsers(query: String) async {
        let handle = HandleRules.normalize(query)
        guard HandleRules.isValid(handle) else {
            searchResults = []
            isSearching = false
            return
        }
        let token = UUID()
        searchToken = token
        isSearching = true
        defer { if searchToken == token { isSearching = false } }
        do {
            let found = try await remote.lookupUser(handle: handle)
            guard searchToken == token else { return }   // a newer search superseded this one
            if let found, found.uid != me.uid, !graph.blocked.contains(found.uid) {
                if let profile = found.profile { profileCache[found.uid] = profile }
                searchResults = [found]
            } else {
                searchResults = []
            }
        } catch {
            if searchToken == token { searchResults = [] }
        }
    }

    // MARK: Blocks and reports

    @discardableResult
    func block(uid: String, name: String, handle: String) async -> Bool {
        guard syncIdentity(), uid != me.uid else { return false }
        let entry = BlockedUser(uid: uid, username: handle, displayName: name, createdAt: now())
        do {
            try await remote.block(entry)
        } catch {
            lastError = "Couldn't block. Try again."
            return false
        }
        try? await remote.unfollow(uid: uid)   // a blocked user cannot be followed
        graph.block(uid)
        blockedUsers.removeAll { $0.uid == uid }
        blockedUsers.append(entry)
        feedItems.removeAll { $0.userId == uid }
        searchResults.removeAll { $0.uid == uid }
        lastFeedFetch = nil
        return true
    }

    @discardableResult
    func unblock(uid: String) async -> Bool {
        do {
            try await remote.unblock(uid: uid)
            graph.unblock(uid)
            blockedUsers.removeAll { $0.uid == uid }
            lastFeedFetch = nil
            await loadGraph()
            return true
        } catch {
            lastError = "Couldn't unblock. Try again."
            return false
        }
    }

    func loadBlocked() async {
        guard syncIdentity() else { return }
        if let list = try? await remote.fetchBlocked() {
            blockedUsers = list
            graph.blocked = Set(list.map(\.uid))
        }
    }

    /// Reports a post and hides it for me. Returns false (and keeps the post) when the report failed.
    @discardableResult
    func reportPost(_ postId: String, reason: String = "Inappropriate content") async -> Bool {
        guard syncIdentity() else { return false }
        do {
            try await remote.report(target: .post, targetId: postId, reason: reason, details: nil)
        } catch {
            lastError = "Couldn't send the report. Try again."
            return false
        }
        hidePost(postId)
        return true
    }

    @discardableResult
    func reportUser(_ uid: String, reason: String = "Inappropriate profile or behaviour") async -> Bool {
        do {
            try await remote.report(target: .user, targetId: uid, reason: reason, details: nil)
            return true
        } catch {
            lastError = "Couldn't send the report. Try again."
            return false
        }
    }

    @discardableResult
    func reportComment(postId: String, commentId: String, reason: String = "Inappropriate comment") async -> Bool {
        do {
            try await remote.report(target: .comment, targetId: "\(postId)/\(commentId)", reason: reason, details: nil)
            return true
        } catch {
            lastError = "Couldn't send the report. Try again."
            return false
        }
    }

    @discardableResult
    func reportChallenge(_ id: String, reason: String = "Inappropriate challenge") async -> Bool {
        do {
            try await remote.report(target: .challenge, targetId: id, reason: reason, details: nil)
            return true
        } catch {
            lastError = "Couldn't send the report. Try again."
            return false
        }
    }

    /// "Hide this post": gone from this viewer's feed, nothing sent to anyone.
    func hide(postId: String) { hidePost(postId) }

    /// "Mute <name>": their posts leave this viewer's feed; they stay friends.
    func mute(uid: String) {
        mutedUids.insert(uid)
        feedItems.removeAll { $0.userId == uid }
        if let me = me.uid { defaults.set(Array(mutedUids).sorted(), forKey: Self.mutedKey(me)) }
    }

    func unmute(uid: String) {
        mutedUids.remove(uid)
        if let me = me.uid { defaults.set(Array(mutedUids).sorted(), forKey: Self.mutedKey(me)) }
    }

    private func hidePost(_ id: String) {
        hiddenPostIds.insert(id)
        feedItems.removeAll { $0.id == id }
        if let uid = me.uid { defaults.set(Array(hiddenPostIds).sorted(), forKey: Self.hiddenKey(uid)) }
    }

    // MARK: Feed

    /// The feed: [friends + me], newest first, a page at a time.
    func loadFeed(forceRefresh: Bool = false) async {
        guard syncIdentity(), let uid = me.uid else { return }
        if !forceRefresh, let last = lastFeedFetch, now().timeIntervalSince(last) < Self.cacheTTL { return }
        if feedItems.isEmpty { isLoadingFeed = true }
        defer { isLoadingFeed = false }
        if !graphLoaded || forceRefresh { await loadGraph() }
        do {
            let page = try await fetchFeedPage(uid: uid, before: nil)
            feedItems = page.items
            hasMoreFeed = page.hasMore
            feedError = nil
            lastFeedFetch = now()
            if !page.items.isEmpty { onFeedLoaded(page.items, uid) }
        } catch {
            feedError = "Couldn't load your feed."
        }
    }

    func loadMoreFeed() async {
        guard hasMoreFeed, !isLoadingMoreFeed, let uid = me.uid, let cursor = feedItems.last?.createdAt else { return }
        isLoadingMoreFeed = true
        defer { isLoadingMoreFeed = false }
        if let page = try? await fetchFeedPage(uid: uid, before: cursor) {
            let known = Set(feedItems.map(\.id))
            feedItems.append(contentsOf: page.items.filter { !known.contains($0.id) })
            hasMoreFeed = page.hasMore
        }
    }

    private func fetchFeedPage(uid: String, before: Date?) async throws -> (items: [WorkoutFeedItem], hasMore: Bool) {
        let limit = FeedQueryPlanner.pageSize
        var queries = FeedQueryPlanner.feedQueries(me: uid, friends: graph.friends, blocked: graph.blocked, before: before, limit: limit)
        if singleAuthorQueries { queries = queries.flatMap(FeedQueryPlanner.perAuthor) }

        var pages: [[WorkoutFeedItem]] = []
        var hasMore = false
        for query in queries {
            do {
                let page = try await remote.fetchPosts(query)
                pages.append(page)
                hasMore = hasMore || page.count >= limit
            } catch SocialError.permissionDenied where query.authorUids.count > 1 {
                // The rules refused a multi-author query (or one author in the chunk is unreadable,
                // e.g. they blocked me). Retry author by author and skip the ones that fail.
                singleAuthorQueries = true
                for single in FeedQueryPlanner.perAuthor(query) {
                    if let page = try? await remote.fetchPosts(single) {
                        pages.append(page)
                        hasMore = hasMore || page.count >= limit
                    }
                }
            } catch SocialError.permissionDenied {
                continue   // an unreadable single author: skip them, keep the rest of the feed
            }
        }
        let merged = FeedQueryPlanner.merge(pages, blocked: graph.blocked.union(mutedUids), hidden: hiddenPostIds, limit: limit)
        return (await hydrate(merged), hasMore)
    }

    /// Adds the per-viewer parts a post query can't return: my like, and the body map extras.
    private func hydrate(_ items: [WorkoutFeedItem], bodyMapsSince: Date? = nil) async -> [WorkoutFeedItem] {
        guard !items.isEmpty else { return items }
        let liked = (try? await remote.likedPostIds(among: items.map(\.id))) ?? []
        let wantMaps = items.filter { $0.bodyMapAudience != PostAudience.onlyMe.rawValue && ($0.date >= (bodyMapsSince ?? .distantPast)) }
        let maps = await withTaskGroup(of: (String, [String: Int]?).self) { group -> [String: [String: Int]] in
            for item in wantMaps {
                group.addTask { @MainActor in (item.id, try? await self.remote.fetchBodyMap(postId: item.id)) }
            }
            var result: [String: [String: Int]] = [:]
            for await (id, map) in group { if let map { result[id] = map } }
            return result
        }
        return items.map { item in
            var copy = item
            copy.likedByMe = liked.contains(item.id)
            copy.muscleSets = maps[item.id] ?? [:]
            return copy
        }
    }

    /// The freshest copy of a post (feed or a loaded profile), so sheets reflect optimistic updates.
    func post(id: String, fallback: WorkoutFeedItem) -> WorkoutFeedItem {
        feedItems.first { $0.id == id } ?? profilePosts[id] ?? fallback
    }

    /// Posts seen on profile pages, kept so likes and comments there update the visible copy too.
    @ObservationIgnored private var profilePosts: [String: WorkoutFeedItem] = [:]

    private func mutatePost(_ id: String, _ change: (inout WorkoutFeedItem) -> Void) {
        if let i = feedItems.firstIndex(where: { $0.id == id }) { change(&feedItems[i]) }
        if var p = profilePosts[id] { change(&p); profilePosts[id] = p }
    }

    // MARK: Likes and comments

    /// Optimistic like toggle: the heart and count change at once, the like document is written, and
    /// both are rolled back if the write fails. The counter itself belongs to a Cloud Function.
    func toggleLike(postId: String) async {
        guard syncIdentity(), !likeInFlight.contains(postId) else { return }
        guard let current = feedItems.first(where: { $0.id == postId }) ?? profilePosts[postId] else { return }
        likeInFlight.insert(postId)
        defer { likeInFlight.remove(postId) }
        let wasLiked = current.likedByMe
        let oldCount = current.likeCount
        let liked = !wasLiked
        mutatePost(postId) {
            $0.likedByMe = liked
            $0.likeCount = max(0, oldCount + (liked ? 1 : -1))
        }
        do {
            try await remote.setLike(postId: postId, liked: liked)
        } catch {
            mutatePost(postId) {
                $0.likedByMe = wasLiked
                $0.likeCount = oldCount
            }
            lastError = "Couldn't update your like. Try again."
        }
    }

    func loadComments(postId: String) async {
        do { comments[postId] = try await remote.fetchComments(postId: postId, limit: 100) }
        catch { if comments[postId] == nil { comments[postId] = [] } }
    }

    /// Posts a comment. The shown count goes up at once and is rolled back if the write fails; the
    /// text is only cleared by the caller on success.
    @discardableResult
    func postComment(postId: String, text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard syncIdentity(), !trimmed.isEmpty, trimmed.count <= 500 else { return false }
        let oldCount = (feedItems.first { $0.id == postId } ?? profilePosts[postId])?.commentCount
        mutatePost(postId) { $0.commentCount += 1 }
        do {
            let comment = try await remote.addComment(postId: postId, text: trimmed, authorName: myName, authorUsername: myHandle)
            comments[postId, default: []].append(comment)
            return true
        } catch {
            if let oldCount { mutatePost(postId) { $0.commentCount = oldCount } }
            lastError = "Couldn't post your comment. Try again."
            return false
        }
    }

    @discardableResult
    func deleteComment(postId: String, commentId: String) async -> Bool {
        let before = comments[postId]
        let oldCount = (feedItems.first { $0.id == postId } ?? profilePosts[postId])?.commentCount
        comments[postId]?.removeAll { $0.id == commentId }
        mutatePost(postId) { $0.commentCount = max(0, $0.commentCount - 1) }
        do {
            try await remote.deleteComment(postId: postId, commentId: commentId)
            return true
        } catch {
            comments[postId] = before
            if let oldCount { mutatePost(postId) { $0.commentCount = oldCount } }
            lastError = "Couldn't delete the comment. Try again."
            return false
        }
    }

    // MARK: Publishing a session

    /// Builds the post for a finished workout and publishes it, once. Returns the payload that was
    /// published; nil when nothing was posted (workout posts are "Only me", signed out, already
    /// posted, or the write failed — a failed post is kept in `pendingPost` for a retry).
    @discardableResult
    /// The payload the composer would post, for "Save as draft" (nothing is sent).
    func draftPayload(data: WorkoutCompletionData, caption: String, taggedUids: [String], includeBodyMap: Bool, extras: PostExtras) -> PostPayload? {
        guard syncIdentity(), let uid = me.uid else { return nil }
        return FeedPostBuilder.makePayload(data: data, author: .init(uid: uid, name: myName, handle: myHandle), caption: caption, taggedUids: taggedUids,
                                           includeBodyMap: includeBodyMap, privacy: privacyService.settings, date: now(), extras: extras)
    }

    func publishWorkoutPost(data: WorkoutCompletionData, caption: String, taggedUids: [String], includeBodyMap: Bool,
                            extras: PostExtras = PostExtras(), photoJPEG: Data? = nil) async -> PostPayload? {
        guard syncIdentity(), let uid = me.uid else { return nil }
        if myProfile == nil { await loadMyProfile() }
        let author = FeedPostBuilder.Author(uid: uid, name: myName, handle: myHandle)
        guard var payload = FeedPostBuilder.makePayload(data: data, author: author, caption: caption, taggedUids: taggedUids,
                                                       includeBodyMap: includeBodyMap, privacy: privacyService.settings, date: now(), extras: extras),
              !publishedPostIds.contains(payload.postId) else { return nil }
        if let photoJPEG, payload.photoURL == nil {
            // A failed upload posts without the photo rather than losing the whole session.
            payload.photoURL = try? await PostPhotoStore.shared.upload(jpeg: photoJPEG, authorUid: uid, postId: payload.postId)
        }
        return await publish(payload)
    }

    /// Posts a draft saved from the composer (History › POST IT) and removes it once it is up.
    @discardableResult
    func publishDraft(workoutId: String) async -> Bool {
        guard syncIdentity(), let uid = me.uid, var draft = PostDraftStore.shared.draft(forWorkout: workoutId),
              draft.payload.authorUid == uid, !publishedPostIds.contains(draft.payload.postId) else { return false }
        if draft.payload.photoURL == nil, let jpeg = PostDraftStore.shared.photo(of: draft) {
            draft.payload.photoURL = try? await PostPhotoStore.shared.upload(jpeg: jpeg, authorUid: uid, postId: draft.payload.postId)
        }
        guard await publish(draft.payload) != nil else { return false }
        PostDraftStore.shared.discard(workout: workoutId)
        return true
    }

    @discardableResult
    private func publish(_ payload: PostPayload) async -> PostPayload? {
        do {
            try await remote.createPost(payload)
            publishedPostIds.insert(payload.postId)
            pendingPost = nil
            lastFeedFetch = nil
            return payload
        } catch {
            pendingPost = payload
            lastError = "Your session didn't post. Try again from the Social tab."
            return nil
        }
    }

    func retryPendingPost() async {
        guard let payload = pendingPost, !publishedPostIds.contains(payload.postId) else { return }
        await publish(payload)
        if pendingPost == nil { await loadFeed(forceRefresh: true) }
    }

    /// Saves an author's edit of their own post: the post document, the photo in Storage, and the recalculated stats and body map.
    @discardableResult
    func updatePost(_ post: WorkoutFeedItem, edit: EditPostModel, recalc: EditPostModel.Recalc) async -> Bool {
        guard syncIdentity(), let uid = me.uid, post.userId == uid else { return false }
        var photoURL = edit.photoURL
        if edit.removePhoto { await PostPhotoStore.shared.delete(authorUid: uid, postId: post.id); photoURL = nil }
        if let jpeg = edit.newPhotoJPEG { photoURL = try? await PostPhotoStore.shared.upload(jpeg: jpeg, authorUid: uid, postId: post.id) }
        let sets = FeedPostBuilder.muscleSetCounts(for: recalc.exercises)
        let payload = PostPayload(
            postId: post.id, authorUid: uid, authorName: post.username, authorUsername: post.handle, date: post.date,
            workoutName: post.templateName ?? "Workout", audience: PostAudience(rawValue: post.audience ?? "") ?? .friends,
            bodyMapAudience: PostAudience(rawValue: post.bodyMapAudience ?? "") ?? .friends,
            stats: .init(sets: recalc.sets, volumeKg: recalc.volumeKg, durationSec: post.durationSeconds, prCount: recalc.prCount),
            exercises: recalc.exercises.map(\.forPost), caption: edit.caption.trimmingCharacters(in: .whitespacesAndNewlines),
            taggedUids: edit.taggedUids, muscleSets: sets.isEmpty || post.bodyMapAudience == PostAudience.onlyMe.rawValue ? nil : sets,
            photoURL: photoURL, song: edit.song, taggedNames: edit.taggedNames, editedAt: now())
        do {
            try await remote.updatePost(payload)
            var updated = post
            updated.caption = payload.caption; updated.exercises = payload.exercises; updated.prCount = payload.stats.prCount
            updated.improvedCount = recalc.improved; updated.totalExercises = recalc.exercises.count
            updated.taggedFriendUids = payload.taggedUids; updated.taggedNames = payload.taggedNames
            updated.photoURL = photoURL; updated.song = edit.song; updated.isEdited = true; updated.muscleSets = sets
            if let i = feedItems.firstIndex(where: { $0.id == post.id }) { feedItems[i] = updated }
            if profilePosts[post.id] != nil { profilePosts[post.id] = updated }
            return true
        } catch {
            lastError = "Couldn't save your changes. Try again."
            return false
        }
    }

    func deletePost(_ id: String) async {
        do {
            try await remote.deletePost(id: id)
            feedItems.removeAll { $0.id == id }
            profilePosts[id] = nil
        } catch {
            lastError = "Couldn't delete the post. Try again."
        }
    }

    // MARK: Saved posts (local bookmarks; there is no server-side "saved" collection)

    private static let savedPostsKey = "savedFeedPostIds"

    var savedPostIds: Set<String> { Set(defaults.stringArray(forKey: Self.savedPostsKey) ?? []) }

    func toggleSavedPost(postId: String) {
        var saved = savedPostIds
        if saved.contains(postId) { saved.remove(postId) } else { saved.insert(postId) }
        defaults.set(Array(saved), forKey: Self.savedPostsKey)
    }

    // MARK: Profiles

    /// A profile page for `uid` as the viewer may see it: the profile, then (only when it is visible)
    /// their posts for the audiences the viewer may read.
    func loadProfilePage(uid: String) async -> ProfilePage {
        guard syncIdentity() else { return ProfilePage(uid: uid, relationship: .stranger, access: .unavailable, profile: nil, posts: []) }
        let relation = relationship(with: uid)
        if relation == .blocked {
            return ProfilePage(uid: uid, relationship: .blocked, access: .restricted, profile: nil, posts: [])
        }
        let result: Result<FirestoreUserProfile, SocialError>
        do { result = .success(try await remote.fetchProfile(uid: uid)) }
        catch let e as SocialError { result = .failure(e) }
        catch { result = .failure(.unavailable(error.localizedDescription)) }

        let access = ProfileAccessRules.access(for: result)
        var profile: FirestoreUserProfile?
        if case .success(let p) = result {
            profile = p
            if uid == me.uid { myProfile = p } else { profileCache[uid] = p }
        } else if access == .unavailable {
            goneUids.insert(uid)
        } else {
            profileCache[uid] = .restricted(uid: uid)
        }

        var posts: [WorkoutFeedItem] = []
        if access == .visible {
            let query = FeedQueryPlanner.profileQuery(author: uid, relationship: relation)
            if let fetched = try? await remote.fetchPosts(query) {
                let thirtyDays = Calendar.current.date(byAdding: .day, value: -30, to: now())
                posts = await hydrate(FeedQueryPlanner.merge([fetched], blocked: graph.blocked, hidden: hiddenPostIds, limit: query.limit), bodyMapsSince: thirtyDays)
                for p in posts { profilePosts[p.id] = p }
            }
        }
        return ProfilePage(uid: uid, relationship: relation, access: access, profile: profile, posts: posts)
    }

    /// A person's logged sessions of one lift, from their real posts. Nil when the posts couldn't be fetched.
    func loadLiftHistory(ownerUid: String, exerciseName: String) async -> [LiftSession]? {
        guard syncIdentity() else { return nil }
        let query = FeedQueryPlanner.profileQuery(author: ownerUid, relationship: relationship(with: ownerUid), limit: 100)
        guard let posts = try? await remote.fetchPosts(query) else { return nil }
        return LiftHistory.sessions(from: posts, exerciseName: exerciseName)
    }

    // MARK: Challenges

    var globalChallenge: SocialChallenge? {
        (globalChallenges + myChallenges.filter(\.isGlobal)).first { $0.isActive(now: now()) }
    }
    var activeFriendChallenges: [SocialChallenge] {
        myChallenges.filter { !$0.isGlobal && $0.isActive(now: now()) }
    }
    var endedChallenges: [SocialChallenge] {
        myChallenges.filter { $0.isEnded(now: now()) }
    }

    func isJoined(_ challenge: SocialChallenge) -> Bool {
        myChallenges.contains { $0.id == challenge.id }
    }

    func loadChallenges() async {
        guard syncIdentity() else { return }
        isLoadingChallenges = true
        defer { isLoadingChallenges = false }
        challengesError = nil
        // Independent calls: one failure must not blank the others.
        do { myChallenges = try await remote.fetchMyChallenges() } catch { challengesError = "Couldn't load your challenges." }
        do { globalChallenges = try await remote.fetchGlobalChallenges() } catch { if challengesError == nil { challengesError = "Couldn't load the global challenge." } }
        await loadInvites()
        if let global = globalChallenge { await loadBoard(global) }
    }

    func loadInvites() async {
        guard syncIdentity() else { return }
        if let invites = try? await remote.fetchPendingInvites() {
            pendingChallengeInvites = invites.filter { !graph.blocked.contains($0.fromUid) }
        }
    }

    /// Creates a challenge (non-global) and joins its creator, so the creator is on the board. Returns the new id.
    @discardableResult
    func createChallenge(_ draft: ChallengeDraft) async -> String? {
        guard syncIdentity() else { return nil }
        do {
            let id = try await remote.createChallenge(draft)
            try await remote.joinChallenge(id: id, username: myHandle.isEmpty ? myName : myHandle)
            await loadChallenges()
            return id
        } catch {
            lastError = "Couldn't create the challenge. Try again."
            return nil
        }
    }

    /// JOIN on a global challenge, or on one I was invited to.
    @discardableResult
    func join(_ challenge: SocialChallenge) async -> Bool {
        guard syncIdentity() else { return false }
        do {
            try await remote.joinChallenge(id: challenge.id, username: myHandle.isEmpty ? myName : myHandle)
            if !myChallenges.contains(where: { $0.id == challenge.id }) { myChallenges.insert(challenge, at: 0) }
            await loadBoard(challenge)
            return true
        } catch {
            lastError = challenge.isEnded(now: now()) ? "This challenge has ended." : "Couldn't join. Try again."
            return false
        }
    }

    @discardableResult
    func leave(_ challenge: SocialChallenge) async -> Bool {
        do {
            try await remote.leaveChallenge(id: challenge.id)
            myChallenges.removeAll { $0.id == challenge.id }
            boards[challenge.id] = nil
            return true
        } catch {
            lastError = "Couldn't leave the challenge. Try again."
            return false
        }
    }

    /// Loads a board from the entries the functions wrote (scores and ranks are never computed here).
    func loadBoard(_ challenge: SocialChallenge) async {
        let limit = challenge.isGlobal ? 50 : 200
        guard let fetched = try? await remote.fetchLeaderboard(challengeId: challenge.id, isGlobal: challenge.isGlobal, limit: limit) else { return }
        var entries = fetched
        let myEntry = try? await remote.fetchMyEntry(challengeId: challenge.id)
        if let mine = myEntry {
            if !entries.contains(where: { $0.uid == mine.uid }) {
                entries.append(mine)
                // Outside the top 50 of a global board: show the neighbourhood around me too.
                if challenge.isGlobal, mine.rank > limit, mine.rank > 0,
                   let around = try? await remote.fetchEntries(challengeId: challenge.id, ranks: max(1, mine.rank - 2)...(mine.rank + 2)) {
                    for e in around where !entries.contains(where: { $0.uid == e.uid }) { entries.append(e) }
                }
            }
        }
        let rows = Leaderboard.rows(from: entries, me: me.uid)
        let isMember = (try? await remote.isMember(challengeId: challenge.id)) ?? myChallenges.contains { $0.id == challenge.id }
        boards[challenge.id] = ChallengeBoard(rows: rows, mine: rows.first { $0.isMe }, isMember: isMember)
    }

    // MARK: Invites

    @discardableResult
    func sendChallengeInvite(challenge: SocialChallenge, toUid: String) async -> Bool {
        guard syncIdentity() else { return false }
        do {
            try await remote.sendInvite(challengeId: challenge.id, challengeName: challenge.name,
                                        fromUsername: myHandle.isEmpty ? myName : myHandle, toUid: toUid)
            return true
        } catch {
            lastError = "Couldn't send the invite. Try again."
            return false
        }
    }

    /// ACCEPT joins the challenge first (the join needs the invite), then marks the invite accepted;
    /// IGNORE declines it. A failed join leaves the invite pending.
    @discardableResult
    func respond(to invite: ChallengeInvite, accept: Bool) async -> Bool {
        guard syncIdentity() else { return false }
        do {
            if accept {
                try await remote.joinChallenge(id: invite.challengeId, username: myHandle.isEmpty ? myName : myHandle)
            }
            try await remote.respondToInvite(invite, accept: accept)
            pendingChallengeInvites.removeAll { $0.id == invite.id }
            if accept { await loadChallenges() }
            return true
        } catch {
            lastError = accept ? "Couldn't join. The challenge may have ended." : "Couldn't update the invite. Try again."
            return false
        }
    }
}
