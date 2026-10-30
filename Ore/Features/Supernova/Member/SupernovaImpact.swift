import Foundation

/// The numbers on the member page's Overview ("what Supernova did for you"): real counts, kept on the device.
///  - suggested weights used and PRs on a suggested weight: counted when a workout is finished (`WorkoutViewModel`);
///  - lagging muscles flagged: how many of the five muscle groups trail the others over the last four weeks;
///  - weekly recaps sent: weeks since membership began in which the member trained (the recap exists for those).
enum SupernovaImpact {
    static let suggestedKey = "supernovaImpactSuggestedWeights"
    static let prsKey = "supernovaImpactPRs"

    static func suggestedWeightsUsed(_ d: UserDefaults = .standard) -> Int { d.integer(forKey: suggestedKey) }
    static func prsOnSuggestedWeight(_ d: UserDefaults = .standard) -> Int { d.integer(forKey: prsKey) }

    /// Adds a finished workout's counts. Members only: for anyone else the suggestions aren't offered, so there is nothing to count.
    static func record(suggestedWeightsUsed n: Int, prsOnSuggestedWeight prs: Int, defaults d: UserDefaults = .standard) {
        guard n > 0 || prs > 0 else { return }
        d.set(suggestedWeightsUsed(d) + n, forKey: suggestedKey)
        d.set(prsOnSuggestedWeight(d) + prs, forKey: prsKey)
    }

    static let muscleGroups = ["Back", "Chest", "Legs", "Shoulders", "Arms"]

    /// A group "lags" when its sets are under 60 % of the groups' average (and the member has trained at all).
    static func laggingMuscles(setsByGroup sets: [String: Int], groups: [String] = muscleGroups) -> Int {
        let counts = groups.map { sets[$0] ?? 0 }
        let total = counts.reduce(0, +)
        guard total > 0 else { return 0 }
        let average = Double(total) / Double(groups.count)
        return counts.filter { Double($0) < average * 0.6 }.count
    }

    /// Complete weeks since `since`, up to `now`, in which at least one workout was done.
    static func weeklyRecapsSent(since: Date, workoutDates: [Date], now: Date = Date(), calendar: Calendar = WeeklyRecapStats.isoMonday) -> Int {
        guard let first = calendar.dateInterval(of: .weekOfYear, for: since)?.start else { return 0 }
        var weekStart = first
        var count = 0
        while let end = calendar.date(byAdding: .day, value: 7, to: weekStart), end <= now {
            if workoutDates.contains(where: { $0 >= weekStart && $0 < end && $0 >= since }) { count += 1 }
            weekStart = end
        }
        return count
    }
}
