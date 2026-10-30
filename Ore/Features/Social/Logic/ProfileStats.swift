import Foundation

/// How a profile page should render for the signed-in viewer.
enum ProfileAccess: Equatable {
    /// The profile document is readable.
    case visible
    /// The owner's profile is private to the viewer (friends/only-me visibility, or a block).
    /// Only the handle is shown, with FOLLOW; no stats or posts.
    case restricted
    /// No such profile any more (a deleted account).
    case unavailable
}

enum ProfileAccessRules {
    /// Maps the result of reading `profiles/{uid}` to a page state.
    static func access(for result: Result<FirestoreUserProfile, SocialError>) -> ProfileAccess {
        switch result {
        case .success: .visible
        case .failure(.notFound): .unavailable
        case .failure: .restricted
        }
    }
}

/// Numbers on a profile page, derived from the person's *posted* sessions (only posts are ever
/// visible to others). Pure so the windows are testable.
struct ProfileStats {
    let posts: [WorkoutFeedItem]
    let now: Date
    let calendar: Calendar

    init(posts: [WorkoutFeedItem], now: Date = Date(), calendar: Calendar = .current) {
        self.posts = posts
        self.now = now
        self.calendar = calendar
    }

    private var thirtyDayCutoff: Date { calendar.date(byAdding: .day, value: -30, to: now) ?? now }

    var last30Days: [WorkoutFeedItem] { posts.filter { $0.date >= thirtyDayCutoff && $0.date <= now.addingTimeInterval(86_400) } }

    /// Working-set volume (kg) over the last 30 days.
    var volumeKg30d: Double { last30Days.reduce(0) { $0 + $1.volumeKg } }
    var prs30d: Int { last30Days.reduce(0) { $0 + $1.prCount } }

    /// The 7 days ending today (oldest first). Ids are the start-of-day dates so they stay stable.
    var week: [(day: Date, post: WorkoutFeedItem?)] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let post = posts.filter { calendar.isDate($0.date, inSameDayAs: day) }.max { $0.date < $1.date }
            return (day, post)
        }
    }

    var trainedDaysThisWeek: Int { week.filter { $0.post != nil }.count }

    /// Summed per-muscle weighted set counts across the last 30 days of posts that share a body map.
    var muscleSets30d: [String: Int] {
        last30Days.reduce(into: [:]) { acc, post in
            for (muscle, sets) in post.muscleSets { acc[muscle, default: 0] += sets }
        }
    }
}

/// A friend's history on one lift, built from their posts (never fabricated).
struct LiftSession: Identifiable, Equatable {
    var id: String
    var date: Date
    var sets: [FeedSetLog]
    var isPR: Bool

    /// Heaviest working set (reps as tie-break).
    var bestSet: FeedSetLog? {
        sets.filter(\.isWorking).max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }
    var bestWeight: Double { bestSet?.weight ?? 0 }
}

enum LiftHistory {
    /// Sessions of `exerciseName` found in `posts`, oldest first. A session is a PR only when it beats
    /// an earlier session in the list; the first session is the baseline and is never flagged.
    static func sessions(from posts: [WorkoutFeedItem], exerciseName: String) -> [LiftSession] {
        let matches: [(WorkoutFeedItem, FeedExercise)] = posts.compactMap { post in
            guard let ex = post.exercises.first(where: { $0.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame }),
                  !ex.workingSets.isEmpty else { return nil }
            return (post, ex)
        }
        .sorted { $0.0.date < $1.0.date }

        var best: Double?
        return matches.map { post, ex in
            let weight = ex.workingSets.map(\.weight).max() ?? 0
            let isPR = best.map { weight > $0 } ?? false
            best = max(best ?? 0, weight)
            return LiftSession(id: post.id, date: post.date, sets: ex.sets, isPR: isPR)
        }
    }

    /// Best estimated one-rep max (Epley) across every working set of every session, in kg. A one-rep
    /// set counts as the weight itself. Nil for bodyweight / timed lifts (no external load).
    static func estimatedOneRepMax(sessions: [LiftSession]) -> Double? {
        let values = sessions.flatMap(\.sets).filter { $0.isWorking && $0.weight > 0 && $0.reps > 0 }.map { set in
            set.reps == 1 ? set.weight : set.weight * (1 + Double(set.reps) / 30)
        }
        return values.max()
    }

    /// Change in best weight between the session closest to `weeks` ago (or the first on file when
    /// the history is shorter) and the latest one. Nil with fewer than two sessions.
    static func weightChange(sessions: [LiftSession], weeks: Int = 12, now: Date = Date(), calendar: Calendar = .current) -> Double? {
        guard sessions.count >= 2, let latest = sessions.last else { return nil }
        let target = calendar.date(byAdding: .weekOfYear, value: -weeks, to: now) ?? now
        let earlier = sessions.dropLast()
        guard let baseline = earlier.min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) }) else { return nil }
        return latest.bestWeight - baseline.bestWeight
    }
}
