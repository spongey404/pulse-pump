import Foundation
@testable import Ore

/// A signed-in (or signed-out) user that tests can switch, standing in for Firebase Auth.
@MainActor
final class TestUser: CurrentUser {
    var uid: String?
    var displayName: String?
    init(uid: String? = "me", displayName: String? = "Me Myself") {
        self.uid = uid
        self.displayName = displayName
    }
}

/// A view model wired to a `FakeSocialRemote`, private `UserDefaults` and a controllable clock.
@MainActor
struct SocialHarness {
    let remote: FakeSocialRemote
    let user: TestUser
    let defaults: UserDefaults
    let privacy: PrivacyService
    let vm: SocialViewModel
    let clock: Clock

    @MainActor final class Clock {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
    }

    init(me: String = "me", signedIn: Bool = true, defaults: UserDefaults? = nil) {
        let suite = defaults ?? UserDefaults(suiteName: "social-\(UUID().uuidString)")!
        let remote = FakeSocialRemote(meUid: me)
        let user = TestUser(uid: signedIn ? me : nil)
        let clock = Clock()
        remote.now = { clock.date }
        let privacy = PrivacyService(remote: remote, me: user, defaults: suite, displayName: { "Me Myself" })
        self.remote = remote
        self.user = user
        self.defaults = suite
        self.privacy = privacy
        self.clock = clock
        self.vm = SocialViewModel(remote: remote, me: user, privacy: privacy, defaults: suite,
                                  displayName: { "Me Myself" }, now: { clock.date }, onFeedLoaded: { _, _ in })
    }

    /// The same defaults/remote with a second view model (a relaunch).
    func relaunch() -> SocialViewModel {
        let clock = self.clock
        return SocialViewModel(remote: remote, me: user, privacy: privacy, defaults: defaults,
                               displayName: { "Me Myself" }, now: { clock.date }, onFeedLoaded: { _, _ in })
    }

    // MARK: Seed helpers

    @discardableResult
    func friend(_ uid: String, name: String? = nil, handle: String? = nil) -> String {
        remote.addProfile(uid, name: name ?? uid.capitalized, handle: handle ?? uid)
        remote.makeFriends(remote.meUid, uid)
        return uid
    }

    func post(_ id: String, by uid: String, audience: PostAudience = .friends, bodyMapAudience: PostAudience = .friends,
              ageMinutes: Double = 0, bodyMap: [String: Int]? = nil, likes: Int = 0, comments: Int = 0,
              exercises: [FeedExercise] = []) {
        let created = clock.date.addingTimeInterval(-ageMinutes * 60)
        remote.addPost(WorkoutFeedItem(
            id: id, userId: uid, username: uid.capitalized, handle: uid, templateName: "Push Day",
            exerciseCount: exercises.count, durationSeconds: 3000, date: created, createdAt: created,
            exercises: exercises, audience: audience.rawValue, bodyMapAudience: bodyMapAudience.rawValue,
            likeCount: likes, commentCount: comments), bodyMap: bodyMap)
    }
}

@MainActor
enum SocialTestData {
    static func set(_ weight: Double, _ reps: Int, _ type: String = "standard") -> FeedSetLog {
        FeedSetLog(weight: weight, reps: reps, duration: 0, distance: 0, setType: type, side: nil)
    }

    static func exercise(_ name: String, sets: [FeedSetLog], primary: [String] = [], secondary: [String] = [],
                         improvement: Double = 0) -> FeedExercise {
        FeedExercise(id: UUID().uuidString, name: name, sets: sets, improvementScore: improvement,
                     primaryMuscles: primary, secondaryMuscles: secondary)
    }

    static func completion(exercises: [FeedExercise], prCount: Int = 1, name: String? = "Push Day",
                           id: UUID? = UUID(), duration: TimeInterval = 3600) -> WorkoutCompletionData {
        WorkoutCompletionData(duration: duration, calories: 300, exerciseCount: exercises.count,
                              totalSets: exercises.reduce(0) { $0 + $1.workingSets.count }, prCount: prCount,
                              improvedCount: 0, totalExercises: exercises.count, streakCount: 3, prDetails: [],
                              musclesWorked: [], exercises: exercises, workoutName: name, workoutId: id)
    }

    static func challenge(_ id: String, creator: String = "me", metric: ChallengeMetric = .totalVolume, global: Bool = false,
                          start: Date, end: Date, status: ChallengeStatus = .active, members: Int = 0) -> SocialChallenge {
        SocialChallenge(id: id, creatorUid: creator, name: "Challenge \(id)", metric: metric, startAt: start, endAt: end,
                        isGlobal: global, visibility: global ? .public : .invite, status: status, memberCount: members,
                        winCondition: .highest)
    }
}
