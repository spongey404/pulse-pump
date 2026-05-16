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

    var currentUid: String? { Auth.auth().currentUser?.uid }

    // MARK: - Demo data (shown when feed is empty and user has no friends yet)

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
                    ]),
                    FeedExercise(id: "fe-2", name: "Incline Dumbbell Press", sets: [
                        FeedSetLog(weight: 34, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 34, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                    ]),
                    FeedExercise(id: "fe-3", name: "Lateral Raise", sets: [
                        FeedSetLog(weight: 12, reps: 15, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 12, reps: 15, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 12, reps: 12, duration: 0, distance: 0, setType: "standard", side: nil),
                    ]),
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
                    ]),
                    FeedExercise(id: "fe-5", name: "Romanian Deadlift", sets: [
                        FeedSetLog(weight: 60, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 60, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                    ]),
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
                    ]),
                    FeedExercise(id: "fe-7", name: "Barbell Row", sets: [
                        FeedSetLog(weight: 70, reps: 8, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 70, reps: 8, duration: 0, distance: 0, setType: "standard", side: nil),
                        FeedSetLog(weight: 65, reps: 10, duration: 0, distance: 0, setType: "standard", side: nil),
                    ]),
                ]
            ),
        ]
    }()

    // MARK: - Feed

    func loadFeed(forceRefresh: Bool = false) async {
        guard let uid = currentUid else {
            if feedItems.isEmpty { feedItems = Self.demoFeedItems }
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
            feedItems = fetched.isEmpty ? Self.demoFeedItems : fetched
            lastFeedFetch = Date()
        } catch {
            if feedItems.isEmpty { feedItems = Self.demoFeedItems }
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
        guard let uid = currentUid else { return }
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

            friends = loadedFriends
            pendingRequests = loadedPending
        } catch {
            friends = []
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
        do {
            activeChallenges = try await firestoreService.fetchActiveChallenges()
            myChallenges = try await firestoreService.fetchUserChallenges()
        } catch {
            activeChallenges = []
            myChallenges = []
        }
        isLoadingChallenges = false
    }

    func createChallenge(name: String, description: String, metric: ChallengeMetric, winCondition: ChallengeWinCondition, startDate: Date, endDate: Date) async {
        guard let uid = currentUid else { return }
        let challenge = FirestoreChallenge(
            name: name,
            challengeDescription: description,
            creatorId: uid,
            metric: metric,
            winCondition: winCondition,
            startDate: startDate,
            endDate: endDate
        )
        _ = try? await firestoreService.createChallenge(challenge)
        await loadChallenges()
    }

    func joinChallenge(id: String, username: String) async {
        guard let uid = currentUid else { return }
        let entry = LeaderboardEntry(userId: uid, username: username)
        try? await firestoreService.joinChallenge(id: id, entry: entry)
        await loadChallenges()
    }
}
