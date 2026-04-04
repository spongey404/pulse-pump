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

    // MARK: - Feed

    func loadFeed() async {
        guard let uid = currentUid else { return }
        isLoadingFeed = true
        do {
            let friendUids = try await firestoreService.fetchFriendUids(for: uid)
            if friendUids.isEmpty {
                feedItems = try await firestoreService.fetchOwnFeed()
            } else {
                let allUids = friendUids + [uid]
                feedItems = try await firestoreService.fetchFeed(friendUids: allUids)
            }
        } catch {
            feedItems = []
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
