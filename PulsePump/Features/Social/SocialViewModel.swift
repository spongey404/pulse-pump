import Foundation
import FirebaseAuth
import Observation

@MainActor
@Observable
class SocialViewModel {
    let firestoreService = FirestoreService()

    // Feed
    var feedItems: [WorkoutFeedItem] = []
    var isLoadingFeed = false
    private var lastFeedFetch: Date?
    private static let cacheTTL: TimeInterval = 5 * 60  // 5 minutes

    // Friends
    var friends: [FirestoreUserProfile] = []
    var pendingRequests: [(docId: String, friendship: FriendshipDoc, profile: FirestoreUserProfile?)] = []
    var searchResults: [FirestoreUserProfile] = []
    var contactMatches: [FirestoreUserProfile] = []
    var isSearching = false

    // Challenges
    var activeChallenges: [FirestoreChallenge] = []
    var myChallenges: [FirestoreChallenge] = []
    var isLoadingChallenges = false
    var pendingChallengeInvites: [(docId: String, invite: ChallengeInvite)] = []

    var currentUid: String? { Auth.auth().currentUser?.uid }

    // MARK: - Demo data (shown when feed is empty and user has no friends yet)

    // Demo fixtures only surface when `DevFlags.socialFixtures` is on (DEBUG dev data) — never in Release.
    static var fixtureFeed: [WorkoutFeedItem] { DevFlags.socialFixtures ? demoFeedItems : [] }
    static var fixtureFriends: [FirestoreUserProfile] { DevFlags.socialFixtures ? demoFriends : [] }

    static let demoFeedItems: [WorkoutFeedItem] = {
        let cal = Calendar.current
        let now = Date()
        return [
            WorkoutFeedItem(
                id: "demo-1",
                userId: "demo-alex",
                username: "alex_lifts",
                templateName: "PUSH DAY",
                exerciseCount: 6,
                durationSeconds: 3720,
                caloriesBurned: 412,
                musclesWorked: ["Chest", "Shoulders", "Triceps"],
                prCount: 2,
                improvedCount: 4,
                totalExercises: 6,
                date: cal.date(byAdding: .hour, value: -2, to: now) ?? now,
                caption: "Huge session today. New PR on bench — finally hit 100kg! 🔥",
                exercises: [
                    FeedExercise(id: "fe-1", name: "Barbell Bench Press", sets: [
                        FeedSetLog(weight: 100, reps: 5, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 95, reps: 6, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 90, reps: 8, duration: 0, distance: 0, setType: "standard", side: nil),
                    ], primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps", "Front Delts"]),
                    FeedExercise(id: "fe-2", name: "Incline Dumbbell Press", sets: [
                        FeedSetLog(weight: 34, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 34, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                    ], primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps", "Front Delts"]),
                    FeedExercise(id: "fe-3", name: "Lateral Raise", sets: [
                        FeedSetLog(weight: 12, reps: 15, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 12, reps: 15, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 12, reps: 12, duration: 0, distance: 0, setType: "standard", side: nil),
                    ], primaryMuscles: ["Side Delts", "Shoulders"], secondaryMuscles: []),
                ]
            ),
            WorkoutFeedItem(
                id: "demo-2",
                userId: "demo-priya",
                username: "priya.trains",
                templateName: "LEG DAY",
                exerciseCount: 5,
                durationSeconds: 4200,
                caloriesBurned: 536,
                musclesWorked: ["Quads", "Hamstrings", "Glutes"],
                prCount: 1,
                improvedCount: 3,
                totalExercises: 5,
                date: cal.date(byAdding: .hour, value: -5, to: now) ?? now,
                caption: "First leg day in 2 weeks and I'm already dreading stairs tomorrow",
                exercises: [
                    FeedExercise(id: "fe-4", name: "Barbell Squat", sets: [
                        FeedSetLog(weight: 80, reps: 5, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 80, reps: 5, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 75, reps: 6, duration: 0, distance: 0, setType: "standard", side: nil),
                    ], primaryMuscles: ["Quads", "Glutes"], secondaryMuscles: ["Hamstrings", "Lower Back"]),
                    FeedExercise(id: "fe-5", name: "Romanian Deadlift", sets: [
                        FeedSetLog(weight: 60, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 60, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                    ], primaryMuscles: ["Hamstrings", "Glutes"], secondaryMuscles: ["Lower Back"]),
                ]
            ),
            WorkoutFeedItem(
                id: "demo-3",
                userId: "demo-james",
                username: "james_bulk",
                templateName: "PULL DAY",
                exerciseCount: 7,
                durationSeconds: 4500,
                caloriesBurned: 489,
                musclesWorked: ["Back", "Biceps"],
                prCount: 0,
                improvedCount: 5,
                totalExercises: 7,
                date: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                caption: "Back width is coming along nicely. Weighted pull-ups feeling strong.",
                exercises: [
                    FeedExercise(id: "fe-6", name: "Weighted Pull Up", sets: [
                        FeedSetLog(weight: 10, reps: 8, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 10, reps: 7, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 7.5, reps: 8, duration: 0, distance: 0, setType: "standard", side: nil),
                    ], primaryMuscles: ["Back", "Lats"], secondaryMuscles: ["Biceps", "Rear Delts"]),
                    FeedExercise(id: "fe-7", name: "Barbell Row", sets: [
                        FeedSetLog(weight: 70, reps: 8, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 70, reps: 8, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 65, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                    ], primaryMuscles: ["Back", "Lats"], secondaryMuscles: ["Biceps", "Rear Delts"]),
                ]
            ),
        ]
    }()

    // MARK: - Demo friends (shown when signed out or no real friendships yet)

    static let demoFriends: [FirestoreUserProfile] = [
        FirestoreUserProfile(uid: "demo-priya", username: "priyastrength", displayName: "Priya", totalWorkouts: 214, currentStreak: 5, longestStreak: 22),
        FirestoreUserProfile(uid: "demo-jay", username: "jaypump", displayName: "Jay", totalWorkouts: 188, currentStreak: 1, longestStreak: 30),
        FirestoreUserProfile(uid: "demo-marc", username: "marclifts", displayName: "Marc", totalWorkouts: 142, currentStreak: 2, longestStreak: 15),
        FirestoreUserProfile(uid: "demo-sanne", username: "sanne.b", displayName: "Sanne", totalWorkouts: 96, currentStreak: 3, longestStreak: 9),
        FirestoreUserProfile(uid: "demo-tom", username: "tom_pressed", displayName: "Tom", totalWorkouts: 61, currentStreak: 0, longestStreak: 12),
        FirestoreUserProfile(uid: "demo-kate", username: "kf_barbell", displayName: "Kate", totalWorkouts: 133, currentStreak: 4, longestStreak: 18),
    ]

    // MARK: - Demo challenges (shown when signed out or no real challenges yet)
    // Values pulled from the design mockups (3d's RANK 47 OF 2,412, 7b's PRIYA WINNER
    // 112KG / YOU 2ND 105KG / GAINED +5KG) so every leaderboard/challenge screen renders
    // realistic, spec-matching content instead of an empty state.

    static let demoChallenges: [FirestoreChallenge] = {
        let cal = Calendar.current
        let now = Date()

        var global = FirestoreChallenge(
            name: "August Volume",
            challengeDescription: "Total volume lifted this month, everyone on Pump.",
            creatorId: "pulse-admin",
            metric: .totalVolume,
            winCondition: .highest,
            startDate: cal.date(byAdding: .day, value: -11, to: now) ?? now,
            endDate: cal.date(byAdding: .day, value: 19, to: now) ?? now,
            runsFor: "restOfMonth",
            isGlobal: true
        )
        global.id = "demo-global-august-volume"
        global.participantIds = (0..<2412).map { "demo-p\($0)" }
        global.leaderboard = [
            LeaderboardEntry(userId: "demo-alex", username: "alex_lifts", score: 212_400, rank: 1, previousRank: 1),
            LeaderboardEntry(userId: "demo-priya", username: "priyastrength", score: 198_100, rank: 2, previousRank: 2),
            LeaderboardEntry(userId: "demo-jay", username: "jaypump", score: 184_600, rank: 3, previousRank: 4),
            LeaderboardEntry(userId: "demo-marc", username: "marclifts", score: 171_200, rank: 4, previousRank: 3),
            LeaderboardEntry(userId: "demo-sanne", username: "sanne.b", score: 163_800, rank: 5, previousRank: 5),
            LeaderboardEntry(userId: "demo-p45", username: "kelvin.h", score: 49_100, rank: 45, previousRank: 44),
            LeaderboardEntry(userId: "demo-p46", username: "reneelifts", score: 48_700, rank: 46, previousRank: 46),
            LeaderboardEntry(userId: "you", username: "You", score: 48_200, rank: 47, previousRank: 52),
            LeaderboardEntry(userId: "demo-p48", username: "diego_r", score: 47_600, rank: 48, previousRank: 47),
            LeaderboardEntry(userId: "demo-p49", username: "millie.b", score: 46_900, rank: 49, previousRank: 49),
        ]

        var friend = FirestoreChallenge(
            name: "Bench 100 Club",
            challengeDescription: "First to a 100kg bench single wins.",
            creatorId: "demo-priya",
            metric: .heaviestLift,
            winCondition: .highest,
            startDate: cal.date(byAdding: .day, value: -14, to: now) ?? now,
            endDate: cal.date(byAdding: .day, value: 14, to: now) ?? now,
            runsFor: "4weeks",
            isGlobal: false,
            customExercise: "Bench Press"
        )
        friend.id = "demo-friend-bench-100"
        friend.participantIds = ["demo-priya", "demo-jay", "demo-marc", "demo-sanne", "you"]
        friend.leaderboard = [
            LeaderboardEntry(userId: "demo-priya", username: "priyastrength", score: 112, rank: 1, previousRank: 1),
            LeaderboardEntry(userId: "you", username: "You", score: 105, rank: 2, previousRank: 3),
            LeaderboardEntry(userId: "demo-jay", username: "jaypump", score: 100, rank: 3, previousRank: 2),
            LeaderboardEntry(userId: "demo-marc", username: "marclifts", score: 92, rank: 4, previousRank: 4),
            LeaderboardEntry(userId: "demo-sanne", username: "sanne.b", score: 80, rank: 5, previousRank: 5),
        ]

        // A second, already-ended friend challenge — matches 7b's exact spec figures
        // (Priya winner 112kg, you 2nd 105kg, gained +5kg) for testing ChallengeEndedView.
        var ended = FirestoreChallenge(
            name: "Bench 100 Club",
            challengeDescription: "First to a 100kg bench single wins.",
            creatorId: "demo-priya",
            metric: .heaviestLift,
            winCondition: .highest,
            startDate: cal.date(byAdding: .day, value: -42, to: now) ?? now,
            endDate: cal.date(byAdding: .day, value: -10, to: now) ?? now,
            runsFor: "4weeks",
            isGlobal: false,
            customExercise: "Bench Press"
        )
        ended.id = "demo-friend-bench-100-ended"
        ended.isActive = false
        ended.participantIds = ["demo-priya", "demo-jay", "demo-marc", "demo-sanne", "you"]
        ended.leaderboard = [
            LeaderboardEntry(userId: "demo-priya", username: "priyastrength", score: 112, rank: 1, previousRank: 2),
            LeaderboardEntry(userId: "you", username: "You", score: 105, rank: 2, previousRank: 1),
            LeaderboardEntry(userId: "demo-jay", username: "jaypump", score: 97, rank: 3, previousRank: 3),
            LeaderboardEntry(userId: "demo-marc", username: "marclifts", score: 90, rank: 4, previousRank: 4),
            LeaderboardEntry(userId: "demo-sanne", username: "sanne.b", score: 78, rank: 5, previousRank: 5),
        ]

        return [global, friend, ended]
    }()

    /// `demoChallenges` uses a placeholder `userId: "you"` on the current-user leaderboard
    /// entries (fixed at compile time, no access to `currentUid`). Substitutes the real
    /// signed-in uid at load time so "your" row actually matches and isn't blank.
    private func demoChallengesForCurrentUser() -> [FirestoreChallenge] {
        let uid = currentUid ?? "demo-you"
        return Self.demoChallenges.map { challenge in
            var c = challenge
            c.leaderboard = c.leaderboard.map { entry in
                guard entry.userId == "you" else { return entry }
                var e = entry
                e.userId = uid
                return e
            }
            c.participantIds = c.participantIds.map { $0 == "you" ? uid : $0 }
            return c
        }
    }

    // MARK: - Feed

    func loadFeed(forceRefresh: Bool = false) async {
        guard let uid = currentUid else {
            if feedItems.isEmpty { feedItems = Self.fixtureFeed }
            return
        }

        // If cache is fresh and we have items, skip the network call
        if !forceRefresh,
           let last = lastFeedFetch,
           Date().timeIntervalSince(last) < Self.cacheTTL,
           !feedItems.isEmpty {
            return
        }

        // Only show the spinner when there's nothing to display yet
        if feedItems.isEmpty { isLoadingFeed = true }

        do {
            let friendUids = try await firestoreService.fetchFriendUids(for: uid)
            var fetched: [WorkoutFeedItem]
            if friendUids.isEmpty {
                fetched = try await firestoreService.fetchOwnFeed()
            } else {
                let allUids = friendUids + [uid]
                fetched = try await firestoreService.fetchFeed(friendUids: allUids)
            }
            feedItems = fetched.isEmpty ? Self.fixtureFeed : fetched
            lastFeedFetch = Date()
            if !fetched.isEmpty { WidgetDataService.writeFriends(from: fetched, myUid: uid) }
        } catch {
            if feedItems.isEmpty { feedItems = Self.fixtureFeed }
        }
        isLoadingFeed = false
    }

    func toggleLike(postId: String) async {
        guard let uid = currentUid else { return }
        if let index = feedItems.firstIndex(where: { $0.id == postId }) {
            if feedItems[index].likes.contains(uid) {
                feedItems[index].likes.removeAll { $0 == uid }
                try? await firestoreService.unlikePost(postId: postId)
            } else {
                feedItems[index].likes.append(uid)
                try? await firestoreService.likePost(postId: postId)
            }
        }
    }

    // MARK: - Friends

    func loadFriends() async {
        guard let uid = currentUid else {
            if friends.isEmpty { friends = Self.fixtureFriends }
            return
        }
        do {
            let friendships = try await firestoreService.fetchFriendships(for: uid)
            var loadedFriends: [FirestoreUserProfile] = []
            var loadedPending: [(String, FriendshipDoc, FirestoreUserProfile?)] = []

            for (docId, friendship) in friendships {
                let otherUid = friendship.userId1 == uid ? friendship.userId2 : friendship.userId1
                let profile = try? await firestoreService.fetchUserProfile(uid: otherUid)

                if friendship.status == .accepted {
                    if let profile { loadedFriends.append(profile) }
                } else if friendship.requestedBy != uid {
                    loadedPending.append((docId, friendship, profile))
                }
            }

            friends = loadedFriends.isEmpty ? Self.fixtureFriends : loadedFriends
            pendingRequests = loadedPending
        } catch {
            friends = Self.fixtureFriends
            pendingRequests = []
        }
    }

    func searchUsers(query: String) async {
        guard !query.isEmpty else { searchResults = []; return }
        isSearching = true
        do {
            searchResults = try await firestoreService.searchUsers(query: query)
            // Filter out self
            if let uid = currentUid {
                searchResults.removeAll { $0.uid == uid }
            }
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func sendFriendRequest(to uid: String) async {
        try? await firestoreService.sendFriendRequest(to: uid)
    }

    func acceptFriendRequest(docId: String) async {
        try? await firestoreService.acceptFriendRequest(docId: docId)
        await loadFriends()
    }

    func removeFriend(docId: String) async {
        try? await firestoreService.removeFriend(docId: docId)
        await loadFriends()
    }

    /// Removes the friendship with `uid` when only the other user's uid is known — e.g. a
    /// feed post's "Unfollow" menu item, which doesn't have the friendship doc id handy the
    /// way a friend-request row does.
    func unfollow(uid: String) async {
        guard let me = currentUid else { return }
        if let match = try? await firestoreService.fetchFriendships(for: me)
            .first(where: { $0.friendship.userId1 == uid || $0.friendship.userId2 == uid }) {
            await removeFriend(docId: match.docId)
        } else {
            friends.removeAll { $0.uid == uid }
        }
    }

    func reportPost(postId: String) async {
        try? await firestoreService.reportPost(postId: postId, reason: "user_reported")
    }

    // MARK: - Saved posts (local bookmark list, UserDefaults-backed — no server-side
    // "saved" collection exists yet)

    private static let savedPostsKey = "savedFeedPostIds"

    var savedPostIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.savedPostsKey) ?? [])
    }

    func toggleSavedPost(postId: String) {
        var saved = savedPostIds
        if saved.contains(postId) { saved.remove(postId) } else { saved.insert(postId) }
        UserDefaults.standard.set(Array(saved), forKey: Self.savedPostsKey)
    }

    func findFriendsFromContacts(emails: [String]) async {
        // Search for each email — in a real app this would be a batch query
        var matches: [FirestoreUserProfile] = []
        for email in emails.prefix(50) {
            if let results = try? await firestoreService.searchUsers(query: email), !results.isEmpty {
                matches.append(contentsOf: results)
            }
        }
        // Filter out self and existing friends
        let friendUids = Set(friends.map(\.uid))
        contactMatches = matches.filter { profile in
            profile.uid != currentUid && !friendUids.contains(profile.uid)
        }
    }

    // MARK: - Comments

    func fetchComments(postId: String) async -> [FeedComment] {
        (try? await firestoreService.fetchComments(postId: postId)) ?? []
    }

    func postComment(postId: String, text: String) async {
        guard let uid = currentUid, !text.isEmpty else { return }
        let username = Auth.auth().currentUser?.displayName ?? "User"
        let comment = FeedComment(userId: uid, username: username, text: text)
        try? await firestoreService.addComment(postId: postId, comment: comment)
        // Update local comment count
        if let index = feedItems.firstIndex(where: { $0.id == postId }) {
            feedItems[index].commentCount += 1
        }
    }

    // MARK: - Challenges

    func loadChallenges() async {
        isLoadingChallenges = true
        let demo = DevFlags.socialFixtures ? demoChallengesForCurrentUser() : []
        let demoGlobal = demo.first { $0.isGlobal }
        let demoFriend = demo.filter { !$0.isGlobal }

        var active: [FirestoreChallenge] = []
        var mine: [FirestoreChallenge] = []
        do {
            active = try await firestoreService.fetchActiveChallenges()
            mine = try await firestoreService.fetchUserChallenges()
        } catch {
            active = []
            mine = []
        }

        // The global card falls back to the demo challenge independently of the friend
        // challenges — there's no admin backend writing a real "Pulse admin" global
        // challenge to Firestore yet, so without this a single real friend challenge would
        // silently drop the global card entirely (all real data replaced the whole demo
        // set, global included).
        let realFriendActive = active.filter { !$0.isGlobal }
        let hasRealFriendData = !realFriendActive.isEmpty || !mine.isEmpty
        let global = active.first { $0.isGlobal } ?? demoGlobal

        activeChallenges = [global].compactMap { $0 } + (hasRealFriendData ? realFriendActive : demoFriend)
        myChallenges = mine.isEmpty ? (hasRealFriendData ? [] : demoFriend) : mine
        isLoadingChallenges = false
    }

    /// Creates a challenge and joins the creator to it (`LeaderboardEntry.joinedAt = now`).
    /// Returns the new challenge id so 5b can invite friends into it in the same flow —
    /// per spec the challenge already exists by step 2, so there is no separate "create"
    /// action there.
    @discardableResult
    func createChallenge(
        name: String, description: String = "", metric: ChallengeMetric,
        winCondition: ChallengeWinCondition = .highest, startDate: Date, endDate: Date,
        runsFor: String = "4weeks", isGlobal: Bool = false,
        customExercise: String? = nil, customCountBy: String? = nil, customUnit: String? = nil
    ) async -> String? {
        guard let uid = currentUid else { return nil }
        let challenge = FirestoreChallenge(
            name: name,
            challengeDescription: description,
            creatorId: uid,
            metric: metric,
            winCondition: winCondition,
            startDate: startDate,
            endDate: endDate,
            runsFor: runsFor,
            isGlobal: isGlobal,
            customExercise: customExercise,
            customCountBy: customCountBy,
            customUnit: customUnit
        )
        let id = try? await firestoreService.createChallenge(challenge)
        if let id {
            let username = Auth.auth().currentUser?.displayName ?? "You"
            try? await firestoreService.joinChallenge(id: id, entry: LeaderboardEntry(userId: uid, username: username))
        }
        await loadChallenges()
        return id
    }

    func joinChallenge(id: String, username: String) async {
        guard let uid = currentUid else { return }
        let entry = LeaderboardEntry(userId: uid, username: username)
        try? await firestoreService.joinChallenge(id: id, entry: entry)
        await loadChallenges()
    }

    // MARK: - Challenge invites (5b)

    func sendChallengeInvite(challengeId: String, challengeName: String, toUid: String) async {
        guard let uid = currentUid else { return }
        let username = Auth.auth().currentUser?.displayName ?? "A friend"
        let invite = ChallengeInvite(challengeId: challengeId, challengeName: challengeName, fromUid: uid, fromUsername: username, toUid: toUid)
        try? await firestoreService.sendChallengeInvite(invite)
    }

    func loadChallengeInvites() async {
        guard let uid = currentUid else { pendingChallengeInvites = []; return }
        pendingChallengeInvites = (try? await firestoreService.fetchPendingChallengeInvites(for: uid)) ?? []
    }

    func respondToChallengeInvite(docId: String, accept: Bool) async {
        try? await firestoreService.respondToChallengeInvite(docId: docId, accept: accept)
        pendingChallengeInvites.removeAll { $0.docId == docId }
        if accept { await loadChallenges() }
    }
}
