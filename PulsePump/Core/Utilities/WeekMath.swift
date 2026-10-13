import Foundation

/// Monday-based week maths shared by Home and the Body tab (the bars, week labels and widgets all
/// assume Monday, whatever the device locale's first weekday is).
enum WeekMath {
    /// Start of the Monday-based week containing `date`.
    static func mondayWeekStart(of date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)   // 1 = Sunday
        let back = weekday == 1 ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -back, to: day) ?? day
    }

    /// How many Monday-weeks `date` is before the week containing `now` (0 = this week).
    static func weeksAgo(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let a = mondayWeekStart(of: date, calendar: calendar)
        let b = mondayWeekStart(of: now, calendar: calendar)
        let days = calendar.dateComponents([.day], from: a, to: b).day ?? 0
        return Int((Double(days) / 7).rounded())
    }
}
