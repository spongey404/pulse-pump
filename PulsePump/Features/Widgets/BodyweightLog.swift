import Foundation

/// Tiny App Group-backed bodyweight history. The app has no weight history of its own
/// (`User.weight` is a single value), so one point per calendar day is appended whenever the
/// widget snapshot is rebuilt or the profile weight is edited. Same day -> last write wins.
enum BodyweightLog {
    struct Entry: Codable, Equatable {
        var day: String   // "yyyy-MM-dd" in the user's calendar
        var kg: Double
    }

    struct Summary: Equatable {
        var series: [Double] = []      // up to 30 daily points, oldest -> newest (gaps carried forward)
        var delta7d = 0.0              // latest minus the value 7 days earlier
        var start = ""                 // "6 SEP" — date of the first point
    }

    static let key = "widget_bodyweight_log"
    private static let maxEntries = 400

    private static func defaultStore() -> UserDefaults? { UserDefaults(suiteName: "group.com.pulse.PulsePump") }

    private static func dayKey(_ date: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func load(defaults: UserDefaults? = nil) -> [Entry] {
        guard let store = defaults ?? defaultStore(),
              let data = store.data(forKey: key),
              let log = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return log
    }

    /// Appends (or replaces today's) weight. Non-positive weights are ignored.
    static func record(kg: Double, on date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults? = nil) {
        guard kg > 0, let store = defaults ?? defaultStore() else { return }
        var log = load(defaults: store)
        let k = dayKey(date, calendar)
        if let i = log.firstIndex(where: { $0.day == k }) { log[i].kg = kg } else { log.append(Entry(day: k, kg: kg)) }
        log.sort { $0.day < $1.day }
        if log.count > maxEntries { log.removeFirst(log.count - maxEntries) }
        if let data = try? JSONEncoder().encode(log) { store.set(data, forKey: key) }
    }

    /// Last `days` daily points ending today. Days without an entry carry the previous value
    /// forward; days before the first entry are omitted (so the series may be shorter than 30).
    static func summary(now: Date = Date(), days: Int = 30, calendar: Calendar = .current, defaults: UserDefaults? = nil) -> Summary {
        let log = load(defaults: defaults)
        guard !log.isEmpty else { return Summary() }
        let byDay = Dictionary(log.map { ($0.day, $0.kg) }, uniquingKeysWith: { $1 })
        let today = calendar.startOfDay(for: now)

        // Value in force at the start of the window = last entry on/before it.
        let firstDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        var carry: Double? = log.last(where: { $0.day <= dayKey(firstDate, calendar) })?.kg
        var points: [(Date, Double)] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if let v = byDay[dayKey(d, calendar)] { carry = v }
            if let carry { points.append((d, carry)) }
        }
        guard let last = points.last, let first = points.first else { return Summary() }

        // 7d delta: against the point 7 days before the latest (or the earliest point if younger).
        let ref = points.count > 7 ? points[points.count - 8].1 : first.1
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = calendar; f.dateFormat = "d MMM"
        return Summary(
            series: points.map { ($0.1 * 10).rounded() / 10 },
            delta7d: ((last.1 - ref) * 10).rounded() / 10,
            start: f.string(from: first.0).uppercased()
        )
    }
}
