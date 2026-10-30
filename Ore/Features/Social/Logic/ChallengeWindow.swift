import Foundation

/// 5a's RUNS FOR chips. The chosen window decides the challenge's `endAt`.
enum ChallengeWindow: String, CaseIterable, Identifiable {
    case oneWeek = "1week"
    case fourWeeks = "4weeks"
    case restOfMonth
    case oneYear = "1year"
    case custom

    var id: String { rawValue }

    /// Chip label, e.g. "REST OF OCT".
    func label(now: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case .oneWeek: return "1 WEEK"
        case .fourWeeks: return "4 WEEKS"
        case .oneYear: return "1 YEAR"
        case .custom: return "CUSTOM"
        case .restOfMonth:
            let f = DateFormatter()
            f.calendar = calendar
            f.dateFormat = "MMM"
            return "REST OF \(f.string(from: now).uppercased())"
        }
    }

    /// When the challenge ends if it starts at `start`. `restOfMonth` ends at the last instant of the
    /// start's month; `custom` uses `customEnd` (falling back to 4 weeks). The result is always after `start`.
    func endDate(from start: Date, customEnd: Date? = nil, calendar: Calendar = .current) -> Date {
        let end: Date
        switch self {
        case .oneWeek: end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86_400)
        case .fourWeeks: end = calendar.date(byAdding: .day, value: 28, to: start) ?? start.addingTimeInterval(28 * 86_400)
        case .oneYear: end = calendar.date(byAdding: .year, value: 1, to: start) ?? start.addingTimeInterval(365 * 86_400)
        case .restOfMonth:
            let interval = calendar.dateInterval(of: .month, for: start)
            end = interval.map { $0.end.addingTimeInterval(-1) } ?? start.addingTimeInterval(28 * 86_400)
        case .custom:
            end = customEnd ?? calendar.date(byAdding: .day, value: 28, to: start) ?? start.addingTimeInterval(28 * 86_400)
        }
        // endAt must be after startAt (the rules enforce it); never hand back a zero-length window.
        return end > start ? end : (calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
    }
}
