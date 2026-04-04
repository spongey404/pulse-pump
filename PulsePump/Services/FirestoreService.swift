import Foundation
import FirebaseAuth
import FirebaseFirestore
import Observation

@MainActor
@Observable
class FirestoreService {
    private let db = Firestore.firestore()

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - User Profile

    func createOrUpdateUserProfile(_ profile: FirestoreUserProfile) async throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
    }

    func fetchUserProfile(uid: String) async throws -> FirestoreUserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        return try? doc.data(as: FirestoreUserProfile.self)
    }

    func searchUsers(query: String) async throws -> [FirestoreUserProfile] {
        let query = query.lowercased()
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreUserProfile.self) }
    }

    // MARK: - Friends

    func sendFriendRequest(to targetUid: String) async throws {
        guard let uid = currentUid else { return }
        let doc = FriendshipDoc(userId1: uid, userId2: targetUid, requestedBy: uid)
        try db.collection("friendships").addDocument(from: doc)
    }

    func acceptFriendRequest(docId: String) async throws {
        try await db.collection("friendships").document(docId).updateData([
            "status": FriendshipStatus.accepted.rawValue
        ])
    }

    func removeFriend(docId: String) async throws {
        try await db.collection("friendships").document(docId).delete()
    }

    func fetchFriendships(for uid: String) async throws -> [(docId: String, friendship: FriendshipDoc)] {
        let asUser1 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: uid)
            .getDocuments()
        let asUser2 = try await db.collection("friendships")
            .whereField("userId2", isEqualTo: uid)
            .getDocuments()

        var results: [(String, FriendshipDoc)] = []
        for doc in asUser1.documents + asUser2.documents {
            if let friendship = try? doc.data(as: FriendshipDoc.self) {
                results.append((doc.documentID, friendship))
            }
        }
        return results
    }

    func fetchFriendUids(for uid: String) async throws -> [String] {
        let friendships = try await fetchFriendships(for: uid)
        return friendships
            .filter { $0.friendship.status == .accepted }
            .map { $0.friendship.userId1 == uid ? $0.friendship.userId2 : $0.friendship.userId1 }
    }

    // MARK: - Activity Feed

    func shareWorkoutToFeed(_ item: WorkoutFeedItem) async throws {
        try db.collection("feed").document(item.id).setData(from: item)
    }

    func fetchFeed(friendUids: [String]) async throws -> [WorkoutFeedItem] {
        guard !friendUids.isEmpty else { return [] }

        // Firestore `in` queries limited to 30 values
        let batches = stride(from: 0, to: friendUids.count, by: 30).map {
            Array(friendUids[$0..<min($0 + 30, friendUids.count)])
        }

        var allItems: [WorkoutFeedItem] = []
        for batch in batches {
            let snapshot = try await db.collection("feed")
                .whereField("userId", in: batch)
                .order(by: "date", descending: true)
                .limit(to: 50)
                .getDocuments()
            let items = snapshot.documents.compactMap { try? $0.data(as: WorkoutFeedItem.self) }
            allItems.append(contentsOf: items)
        }
        return allItems.sorted { $0.date > $1.date }
    }

    func fetchOwnFeed() async throws -> [WorkoutFeedItem] {
        guard let uid = currentUid else { return [] }
        let snapshot = try await db.collection("feed")
            .whereField("userId", isEqualTo: uid)
            .order(by: "date", descending: true)
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: WorkoutFeedItem.self) }
    }

    func likePost(postId: String) async throws {
        guard let uid = currentUid else { return }
        try await db.collection("feed").document(postId).updateData([
            "likes": FieldValue.arrayUnion([uid])
        ])
    }

    func unlikePost(postId: String) async throws {
        guard let uid = currentUid else { return }
        try await db.collection("feed").document(postId).updateData([
            "likes": FieldValue.arrayRemove([uid])
        ])
    }

    // MARK: - Comments

    func addComment(postId: String, comment: FeedComment) async throws {
        let ref = db.collection("feed").document(postId).collection("comments").document(comment.id)
        try ref.setData(from: comment)
        try await db.collection("feed").document(postId).updateData([
            "commentCount": FieldValue.increment(Int64(1))
        ])
    }

    func fetchComments(postId: String) async throws -> [FeedComment] {
        let snapshot = try await db.collection("feed").document(postId).collection("comments")
            .order(by: "date", descending: false)
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FeedComment.self) }
    }

    // MARK: - Challenges

    func createChallenge(_ challenge: FirestoreChallenge) async throws -> String {
        let ref = try db.collection("challenges").addDocument(from: challenge)
        return ref.documentID
    }

    func joinChallenge(id: String, entry: LeaderboardEntry) async throws {
        guard let uid = currentUid else { return }
        let challengeRef = db.collection("challenges").document(id)
        try await challengeRef.updateData([
            "participantIds": FieldValue.arrayUnion([uid])
        ])
        // Add leaderboard entry
        let entryData = try Firestore.Encoder().encode(entry)
        try await challengeRef.updateData([
            "leaderboard": FieldValue.arrayUnion([entryData])
        ])
    }

    func fetchActiveChallenges() async throws -> [FirestoreChallenge] {
        let snapshot = try await db.collection("challenges")
            .whereField("isActive", isEqualTo: true)
            .order(by: "startDate", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            var challenge = try? doc.data(as: FirestoreChallenge.self)
            challenge?.id = doc.documentID
            return challenge
        }
    }

    func fetchUserChallenges() async throws -> [FirestoreChallenge] {
        guard let uid = currentUid else { return [] }
        let snapshot = try await db.collection("challenges")
            .whereField("participantIds", arrayContains: uid)
            .order(by: "startDate", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            var challenge = try? doc.data(as: FirestoreChallenge.self)
            challenge?.id = doc.documentID
            return challenge
        }
    }

    func updateLeaderboardEntry(challengeId: String, updatedLeaderboard: [LeaderboardEntry]) async throws {
        let encoded = try updatedLeaderboard.map { try Firestore.Encoder().encode($0) }
        try await db.collection("challenges").document(challengeId).updateData([
            "leaderboard": encoded
        ])
    }
}

// Firestore-specific challenge DTO (separate from local SwiftData Challenge)
struct FirestoreChallenge: Codable, Identifiable {
    var id: String
    var name: String
    var challengeDescription: String
    var creatorId: String
    var participantIds: [String]
    var metric: String
    var winCondition: String
    var startDate: Date
    var endDate: Date
    var leaderboard: [LeaderboardEntry]
    var isActive: Bool

    init(name: String, challengeDescription: String = "", creatorId: String, metric: ChallengeMetric, winCondition: ChallengeWinCondition, startDate: Date, endDate: Date) {
        self.id = ""
        self.name = name
        self.challengeDescription = challengeDescription
        self.creatorId = creatorId
        self.participantIds = [creatorId]
        self.metric = metric.rawValue
        self.winCondition = winCondition.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.leaderboard = []
        self.isActive = true
    }
}
