import Foundation

/// One cell of a Monday-first month grid (the History and Body-tab calendars).
struct MonthGridDay {
    let date: Date?
    let day: Int?
}

enum MonthGrid {
    /// Monday-first grid for the month containing `month`, padded to 42 cells (6 rows).
    static func days(for month: Date, calendar cal: Calendar = .current) -> [MonthGridDay] {
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let range = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }

        // Monday-based offset (Mon=0 … Sun=6)
        let weekday = cal.component(.weekday, from: startOfMonth)
        let offset = (weekday + 5) % 7

        var days: [MonthGridDay] = Array(repeating: MonthGridDay(date: nil, day: nil), count: offset)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: startOfMonth) {
                days.append(MonthGridDay(date: date, day: d))
            }
        }
        // Always pad to 42 (6 rows) for fixed height
        while days.count < 42 { days.append(MonthGridDay(date: nil, day: nil)) }
        return days
    }
}

/// The numbers on More › History: the stats row, the list order and the calendar's day lookups.
struct HistoryStats {
    /// Finished, non-deleted workouts, newest first (the view's `@Query`).
    let workouts: [Workout]
    var now: Date = Date()
    var calendar: Calendar = .current

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    func dateKey(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// Days with a workout (calendar dots).
    var workoutDateSet: Set<String> {
        let f = dayFormatter
        return Set(workouts.map { f.string(from: $0.date) })
    }

    func workoutsOn(_ date: Date) -> [Workout] {
        let key = dateKey(date)
        return workouts.filter { dateKey($0.date) == key }
    }

    var totalCount: Int { workouts.count }

    var thisMonthCount: Int {
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        return workouts.filter {
            calendar.component(.month, from: $0.date) == month && calendar.component(.year, from: $0.date) == year
        }.count
    }

    var streak: Int { StreakCalculator.currentStreak(from: workouts.map(\.date), now: now, calendar: calendar) }
}
