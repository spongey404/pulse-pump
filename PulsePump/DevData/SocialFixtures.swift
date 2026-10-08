#if DEBUG
import Foundation

/// A seeded in-memory social backend for DEBUG runs without Firebase data. Only reachable through
/// `SocialRemoteFactory` when `DevFlags.socialFixtures` is on, which is never the case while the
/// emulator is in use (`-useFirebaseEmulator 1`) and never in Release (this file is compiled out).
@MainActor
enum SocialFixtures {
    /// The Firebase user when there is one, otherwise a fixed dev identity.
    struct FixtureUser: CurrentUser {
        var uid: String? { FirebaseCurrentUser().uid ?? "dev-me" }
        var displayName: String? { FirebaseCurrentUser().displayName ?? "Dev User" }
    }
    static let currentUser: CurrentUser = FixtureUser()

    static func makeRemote(meUid: String) -> FakeSocialRemote {
        let r = FakeSocialRemote(meUid: meUid)
        let cal = Calendar.current
        let now = Date()
        func ago(hours: Int) -> Date { cal.date(byAdding: .hour, value: -hours, to: now) ?? now }
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: now) ?? now }

        r.addProfile(meUid, name: SocialServices.localName ?? "You", handle: SocialServices.localHandle ?? "you", streak: 4, workouts: 38)

        // Friends (mutual), a fan (follows me), and someone I follow who hasn't followed back.
        r.addProfile("fx-priya", name: "Priya", handle: "priyastrength", streak: 5, workouts: 214)
        r.addProfile("fx-jay", name: "Jay", handle: "jaypump", streak: 1, workouts: 188)
        r.addProfile("fx-marc", name: "Marc", handle: "marclifts", streak: 2, workouts: 142)
        r.addProfile("fx-sanne", name: "Sanne", handle: "sanne.b", streak: 3, workouts: 96)
        r.addProfile("fx-tom", name: "Tom", handle: "tom_pressed", streak: 0, workouts: 61, visibility: .friends)
        for friend in ["fx-priya", "fx-jay", "fx-marc"] { r.makeFriends(meUid, friend) }
        r.setFollow("fx-sanne", follows: meUid)
        r.setFollow(meUid, follows: "fx-tom")

        func sets(_ pairs: [(Double, Int)]) -> [FeedSetLog] {
            pairs.map { FeedSetLog(weight: $0.0, reps: $0.1, duration: 0, distance: 0, setType: "standard", side: nil) }
        }
        r.addPost(WorkoutFeedItem(
            id: "fx-post-1", userId: "fx-priya", username: "Priya", handle: "priyastrength", templateName: "Push Day",
            exerciseCount: 2, durationSeconds: 3720, prCount: 1, improvedCount: 2, totalExercises: 2, date: ago(hours: 2),
            createdAt: ago(hours: 2), caption: "New bench PR.",
            exercises: [FeedExercise(id: "e1", name: "Barbell Bench Press", sets: sets([(100, 5), (95, 6), (90, 8)]), improvementScore: 6, weightDelta: 5),
                        FeedExercise(id: "e2", name: "Lateral Raise", sets: sets([(12, 15), (12, 15)]))],
            audience: "friends", bodyMapAudience: "friends", likeCount: 3, commentCount: 1),
            bodyMap: ["Chest": 9, "Shoulders": 6, "Triceps": 5])
        r.addPost(WorkoutFeedItem(
            id: "fx-post-2", userId: "fx-jay", username: "Jay", handle: "jaypump", templateName: "Pull Day",
            exerciseCount: 1, durationSeconds: 4500, prCount: 0, improvedCount: 1, totalExercises: 1, date: ago(hours: 20),
            createdAt: ago(hours: 20), caption: "Back width coming along.",
            exercises: [FeedExercise(id: "e3", name: "Barbell Row", sets: sets([(70, 8), (70, 8), (65, 10)]), improvementScore: 3, repsDelta: 1)],
            audience: "everyone", bodyMapAudience: "friends", likeCount: 1), bodyMap: ["Lats": 8, "Biceps": 5])
        r.comments["fx-post-1"] = [FeedComment(userId: "fx-jay", username: "Jay", handle: "jaypump", text: "Beast.", date: ago(hours: 1))]

        // Challenges: a global one anyone can join, and a friend one with a board.
        r.challenges["fx-global"] = SocialChallenge(id: "fx-global", creatorUid: "pulse", name: "Monthly Volume", metric: .totalVolume,
                                                    startAt: days(-10), endAt: days(20), isGlobal: true, visibility: .public,
                                                    status: .active, memberCount: 3, winCondition: .highest)
        r.entries["fx-global"] = [
            ChallengeEntry(uid: "fx-priya", username: "priyastrength", score: 198_100, rank: 1, previousRank: 1, scoreAt: days(-2)),
            ChallengeEntry(uid: "fx-jay", username: "jaypump", score: 184_600, rank: 2, previousRank: 3, scoreAt: days(-3)),
            ChallengeEntry(uid: "fx-marc", username: "marclifts", score: 171_200, rank: 3, previousRank: 2, scoreAt: days(-1)),
        ]
        r.challenges["fx-bench"] = SocialChallenge(id: "fx-bench", creatorUid: "fx-priya", name: "Bench 100 Club", metric: .heaviestLift,
                                                   exerciseName: "Barbell Bench Press", startAt: days(-14), endAt: days(14),
                                                   isGlobal: false, visibility: .invite, status: .active, memberCount: 3, winCondition: .highest)
        r.members["fx-bench"] = [meUid, "fx-priya", "fx-jay"]
        r.entries["fx-bench"] = [
            ChallengeEntry(uid: "fx-priya", username: "priyastrength", score: 112, rank: 1, previousRank: 1, scoreAt: days(-3)),
            ChallengeEntry(uid: meUid, username: SocialServices.localHandle ?? "you", score: 105, rank: 2, previousRank: 3, scoreAt: days(-2)),
            ChallengeEntry(uid: "fx-jay", username: "jaypump", score: 105, rank: 2, previousRank: 2, scoreAt: days(-1)),
        ]
        let invite = ChallengeInvite(challengeId: "fx-global", challengeName: "Monthly Volume", fromUid: "fx-priya", fromUsername: "priyastrength", toUid: meUid)
        r.invites[invite.id] = invite
        return r
    }
}
#endif
