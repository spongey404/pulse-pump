import Foundation

/// The numbers on More › Analytics: each exercise's best estimated 1RM over the last 30 days with its change on the 30 days before,
/// and the working volume of this week and last. Pure (`now` and `calendar` are injected) so a test can read exactly what the
/// screen shows. Warm-ups never count; drafts and deleted workouts are already out of `workouts`.
struct AnalyticsStats {
    struct E1RMRow: Equatable {
        let name: String
        /// Best estimated 1RM in the window, in kg (stored unit).
        let e1rmKg: Double
        /// Change on the previous window as a fraction (0.042 = ▲ 4.2 %), nil when there was nothing to compare with.
        let change: Double?
    }

    let workouts: [Workout]
    var now: Date = Date()
    var calendar: Calendar = WeeklyRecapStats.isoMonday
    var windowDays = 30

    /// Best e1RM per exercise name in [from, to).
    private func best(from: Date, to: Date) -> [String: Double] {
        var out: [String: Double] = [:]
        for w in workouts where w.date >= from && w.date < to {
            for log in w.exerciseLogs {
                guard let name = log.exercise?.name else { continue }
                for set in log.workingSets where set.weight > 0 && set.reps > 0 {
                    let e = ExerciseProgress.epley(weight: set.weight, reps: set.reps)
                    out[name] = max(out[name] ?? 0, e)
                }
            }
        }
        return out
    }

    /// Exercises trained in the last `windowDays` days, heaviest estimated 1RM first.
    func e1RMRows(limit: Int = 12) -> [E1RMRow] {
        let start = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let before = calendar.date(byAdding: .day, value: -windowDays, to: start) ?? start
        let current = best(from: start, to: now.addingTimeInterval(1))
        let previous = best(from: before, to: start)
        var rows: [E1RMRow] = []
        for (name, e) in current {
            var change: Double? = nil
            if let before = previous[name], before > 0 { change = e / before - 1 }
            rows.append(E1RMRow(name: name, e1rmKg: e, change: change))
        }
        rows.sort { a, b in a.e1rmKg == b.e1rmKg ? a.name < b.name : a.e1rmKg > b.e1rmKg }
        return Array(rows.prefix(limit))
    }

    /// Working volume (kg × reps, stored unit) of the ISO week `weeksBack` weeks ago (0 = this week).
    func volumeKg(weeksBack: Int) -> Double {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let start = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: thisWeek) ?? thisWeek
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return workouts.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.workingVolume }
    }
}
