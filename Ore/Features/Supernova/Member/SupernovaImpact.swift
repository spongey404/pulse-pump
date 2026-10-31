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

/// What the membership page's Overview shows, decided from the four counts. A zero is never presented as a score: the headline
/// is the first non-zero of PRs on a suggested weight, suggested weights used and weekly recaps (with its own sentence), and a
/// brand-new member gets a prompt with no number. The grid shows "—" for a zero, and the whole section waits for a real number.
enum SupernovaOverview {
    struct Headline: Equatable { var number: Int; var text: String }

    static let emptyHeadline = "Your first suggested weight is waiting in your next session."

    static func headline(prs: Int, suggested: Int, recaps: Int) -> Headline? {
        if prs > 0 { return Headline(number: prs, text: prs == 1 ? "PR came from a suggested weight." : "PRs came from a suggested weight.") }
        if suggested > 0 { return Headline(number: suggested, text: suggested == 1 ? "set used a suggested weight." : "sets used a suggested weight.") }
        if recaps > 0 { return Headline(number: recaps, text: recaps == 1 ? "weekly recap sent." : "weekly recaps sent.") }
        return nil
    }

    /// The grid cell's value: "—" for zero.
    static func cell(_ n: Int) -> String { n > 0 ? "\(n)" : "—" }

    /// "WHAT SUPERNOVA DID FOR YOU" and its grid appear once any of the four is above zero.
    static func showsStats(prs: Int, suggested: Int, lagging: Int, recaps: Int) -> Bool {
        prs > 0 || suggested > 0 || lagging > 0 || recaps > 0
    }
}
