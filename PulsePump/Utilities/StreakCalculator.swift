import Foundation

enum StreakCalculator {
    /// Calculates the current streak from a list of workout dates.
    ///
    /// Rules:
    /// - Streak expires if the most recent workout was more than 3 days ago.
    /// - Each gap between consecutive workouts adds that many days to the streak
    ///   (e.g. workout on day 1, next on day 3 → streak = 3).
    /// - Multiple workouts on the same day count as one.
    static func currentStreak(from dates: [Date]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let uniqueDays = Array(Set(dates.map { calendar.startOfDay(for: $0) }))
            .sorted(by: >)

        guard let mostRecent = uniqueDays.first else { return 0 }

        let daysSinceLast = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        guard daysSinceLast <= 3 else { return 0 }

        var streak = 1
        var previous = mostRecent

        for day in uniqueDays.dropFirst() {
            let gap = calendar.dateComponents([.day], from: day, to: previous).day ?? 0
            guard gap <= 3 else { break }
            streak += gap
            previous = day
        }

        return streak
    }
}
