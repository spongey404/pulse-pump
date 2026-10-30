import Foundation

/// Tiny App Group-backed bodyweight history. The app has no weight history of its own
/// (`User.weight` is a single value), so one point per calendar day is appended whenever the
/// widget snapshot is rebuilt or the profile weight is edited. Same day -> last write wins.
enum BodyweightLog {
    struct Entry: Codable, Equatable {
        var day: String   // "yyyy-MM-dd" in the user's calendar
        var kg: Double
        /// When this value was last changed (cloud sync, last write wins). Absent in entries saved before sync existed.
        var updatedAt: Date? = nil
        /// The `updatedAt` last pushed to / received from the cloud; nil = never synced.
        var syncedAt: Date? = nil
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
        let now = Date()
        if let i = log.firstIndex(where: { $0.day == k }) {
            guard log[i].kg != kg else { return }   // unchanged (the widget refresh re-records constantly): not an edit
            log[i].kg = kg
            log[i].updatedAt = max(now, (log[i].updatedAt ?? now).addingTimeInterval(0.001))
        } else {
            log.append(Entry(day: k, kg: kg, updatedAt: now))
        }
        log.sort { $0.day < $1.day }
        if log.count > maxEntries { log.removeFirst(log.count - maxEntries) }
        if let data = try? JSONEncoder().encode(log) { store.set(data, forKey: key) }
    }

    // MARK: Cloud sync (users/{uid}/bodyweight/{yyyyMMdd})

    private static func save(_ log: [Entry], to store: UserDefaults) {
        if let data = try? JSONEncoder().encode(log) { store.set(data, forKey: key) }
    }

    /// Entries not yet pushed, or edited since the last push.
    static func dirtyEntries(defaults: UserDefaults? = nil) -> [Entry] {
        load(defaults: defaults).filter { e in
            guard let synced = e.syncedAt else { return true }
            return (e.updatedAt ?? synced).syncMs > synced.syncMs
        }
    }

    /// Marks entries as pushed (stores the `updatedAt` that was sent, so a later edit is still dirty).
    static func markSynced(_ sent: [Entry], defaults: UserDefaults? = nil) {
        guard let store = defaults ?? defaultStore() else { return }
        var log = load(defaults: store)
        for s in sent {
            // Legacy entries (saved before sync) have no updatedAt: adopt the one that was sent.
            guard let i = log.firstIndex(where: { $0.day == s.day }),
                  log[i].updatedAt == nil || log[i].updatedAt == s.updatedAt else { continue }
            if log[i].updatedAt == nil { log[i].updatedAt = s.updatedAt }
            log[i].syncedAt = s.updatedAt
        }
        save(log, to: store)
    }

    /// Applies a cloud entry when it is newer than the local one (last write wins). Returns whether it changed.
    @discardableResult
    static func applyRemote(day: String, kg: Double, updatedAt: Date, defaults: UserDefaults? = nil) -> Bool {
        guard kg > 0, let store = defaults ?? defaultStore() else { return false }
        var log = load(defaults: store)
        if let i = log.firstIndex(where: { $0.day == day }) {
            guard updatedAt.syncMs > (log[i].updatedAt ?? Date(syncMs: 0)).syncMs else { return false }
            log[i].kg = kg; log[i].updatedAt = updatedAt; log[i].syncedAt = updatedAt
        } else {
            log.append(Entry(day: day, kg: kg, updatedAt: updatedAt, syncedAt: updatedAt))
        }
        log.sort { $0.day < $1.day }
        if log.count > maxEntries { log.removeFirst(log.count - maxEntries) }
        save(log, to: store)
        return true
    }

    /// Sign-out / account switch.
    static func clear(defaults: UserDefaults? = nil) {
        (defaults ?? defaultStore())?.removeObject(forKey: key)
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
