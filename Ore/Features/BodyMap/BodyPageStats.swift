import Foundation

enum BodyLens: String, CaseIterable { case volume, frequency }

/// Config for the Body page, one place for the numbers the design names.
enum BodyPageConfig {
    /// The Frequency lens's window, in hours.
    static var windowHours: Double = 48
    /// A day's target is this share of the weekly one.
    static let dayShare = 0.5
    /// Freshness right after training, and at the end of the window (grey after).
    static let freshMax = 1.0
    static let freshMin = 0.25
    /// After this many hours the "ago" text switches to days.
    static let daysAfterHours = 72.0
}

/// Everything the Body page shows, with no SwiftUI: the scrubbed week or day, the Volume lens (sets vs target per group, muscle and head) and
/// the Frequency lens (how long ago each muscle was trained, against the window). `now` and `calendar` are injected so tests move the clock.
struct BodyPageStats {
    /// Finished and unfinished workouts as the query returns them; drafts and deleted ones are filtered here.
    let workouts: [Workout]
    var weekOffset = 0
    /// 0 = Monday … 6 = Sunday; nil = the whole week.
    var dayIndex: Int? = nil
    var now: Date = Date()
    var calendar: Calendar = .current
    var plan: ((Date) -> CalendarPlanDay?)? = nil

    private var live: [Workout] { workouts.filter { !$0.isDraft && $0.deletedAt == nil } }

    // MARK: Week geometry

    func monday(of date: Date) -> Date {
        let d = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -((calendar.component(.weekday, from: d) + 5) % 7), to: d) ?? d
    }

    var thisMonday: Date { monday(of: now) }
    var weekMonday: Date { calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisMonday) ?? thisMonday }
    var weekSunday: Date { calendar.date(byAdding: .day, value: 6, to: weekMonday) ?? weekMonday }
    var weekNumber: Int {
        var c = calendar; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4
        return c.component(.weekOfYear, from: weekMonday)
    }

    /// The oldest week the page can go back to: the week of the first logged workout.
    var oldestOffset: Int {
        guard let first = live.map(\.date).min() else { return 0 }
        let weeks = calendar.dateComponents([.weekOfYear], from: monday(of: first), to: thisMonday).weekOfYear ?? 0
        return -max(0, weeks)
    }
    var canGoBack: Bool { weekOffset > oldestOffset }
    var canGoForward: Bool { weekOffset < 0 }

    /// "WEEK 45 · NOV 2–8" (or "NOV 30–DEC 6" across months).
    var weekLabel: String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMM d"
        let a = f.string(from: weekMonday).uppercased()
        let sameMonth = calendar.component(.month, from: weekMonday) == calendar.component(.month, from: weekSunday)
        let b = sameMonth ? "\(calendar.component(.day, from: weekSunday))" : f.string(from: weekSunday).uppercased()
        return "WEEK \(weekNumber) · \(a)–\(b)"
    }

    /// "THIS WEEK" / "LAST WEEK" / "N WEEKS AGO".
    var relativeLabel: String {
        switch weekOffset {
        case 0: "THIS WEEK"
        case -1: "LAST WEEK"
        default: "\(-weekOffset) WEEKS AGO"
        }
    }

    func date(ofDay i: Int) -> Date { calendar.date(byAdding: .day, value: i, to: weekMonday) ?? weekMonday }

    /// The offset and day index that show `date`.
    func target(for date: Date) -> (weekOffset: Int, dayIndex: Int) {
        let mon = monday(of: date)
        let weeks = calendar.dateComponents([.weekOfYear], from: thisMonday, to: mon).weekOfYear ?? 0
        return (weeks, (calendar.component(.weekday, from: date) + 5) % 7)
    }

    // MARK: Selection

    private func workouts(inWeek offset: Int) -> [Workout] {
        let mon = calendar.date(byAdding: .weekOfYear, value: offset, to: thisMonday) ?? thisMonday
        let end = calendar.date(byAdding: .day, value: 7, to: mon) ?? mon
        return live.filter { $0.date >= mon && $0.date < end }
    }

    /// The workouts the page is showing: the whole week or one day.
    var selected: [Workout] {
        let week = workouts(inWeek: weekOffset)
        guard let i = dayIndex else { return week }
        let day = date(ofDay: i)
        return week.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Workout sets (a set counts once, whatever muscles it works), not the per-muscle sum.
    var workoutSets: Int { selected.reduce(0) { $0 + $1.workingSetCount } }

    /// Sets per day for the strip, Monday first, and the week's total.
    var daySets: [Int] {
        (0..<7).map { i in
            let day = date(ofDay: i)
            return workouts(inWeek: weekOffset).filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.workingSetCount }
        }
    }
    var weekSets: Int { daySets.reduce(0, +) }

    // MARK: Volume lens

    struct Tally: Equatable {
        var muscle: [String: Int] = [:]
        var head: [String: Int] = [:]
        var group: [String: Int] = [:]
    }

    static func tally(_ workouts: [Workout]) -> Tally {
        var t = Tally()
        for w in workouts {
            for log in w.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                let n = log.workingSets.count
                guard n > 0 else { continue }
                let credited = BodyMuscleTree.creditedIds(for: exercise)
                for g in BodyMuscleTree.groups {
                    var hit = false
                    for m in g.muscles {
                        if !credited.isDisjoint(with: m.ids) { t.muscle[m.id, default: 0] += n; hit = true }
                        for h in m.heads where credited.contains(h.id) { t.head[h.id, default: 0] += n }
                    }
                    if hit { t.group[g.id, default: 0] += n }
                }
            }
        }
        return t
    }

    var tally: Tally { Self.tally(selected) }

    /// Sets a node is measured against: weekly, or half of it for a single day.
    func target(_ weekly: Int) -> Double { dayIndex == nil ? Double(weekly) : Double(weekly) * BodyPageConfig.dayShare }

    var groupsHit: Int { let t = tally; return BodyMuscleTree.groups.filter { (t.group[$0.id] ?? 0) > 0 }.count }
    var musclesHit: Int { let t = tally; return BodyMuscleTree.muscles.filter { (t.muscle[$0.id] ?? 0) > 0 }.count }
    var muscleCount: Int { BodyMuscleTree.muscles.count }

    /// 0–1 per artwork id (sets against target).
    var volumeLevels: [String: Double] {
        let t = tally
        var out: [String: Double] = [:]
        for m in BodyMuscleTree.muscles {
            for id in m.ids {
                let v: Double
                if let h = m.heads.first(where: { $0.id == id }) { v = Double(t.head[id] ?? 0) / max(1, target(h.target)) }
                else { v = Double(t.muscle[m.id] ?? 0) / max(1, target(m.target)) }
                if v > 0 { out[id] = min(1, v) }
            }
        }
        return out
    }

    func ratio(sets: Int, weeklyTarget: Int) -> Double { min(1, Double(sets) / max(1, target(weeklyTarget))) }

    /// "6 / 10" target text for a node.
    func targetText(_ weekly: Int) -> String { String(format: "%g", target(weekly).rounded(.up)) }

    // MARK: Empty-day note

    /// The dashed note over the map when the selected day has nothing logged.
    var dayNote: String? {
        guard let i = dayIndex, selected.isEmpty else { return nil }
        let day = date(ofDay: i), today = calendar.startOfDay(for: now)
        let p = plan?(day)
        if day > today { return p.map { $0.isRest ? "Rest day." : "Planned: \($0.name)." } ?? "Nothing logged." }
        if day == today { return p.map { $0.isRest ? "Rest day." : "Nothing logged yet. \($0.name) is up next." } ?? "Nothing logged yet." }
        if p?.isRest == true { return "Rest day." }
        return "Nothing logged."
    }

    // MARK: Frequency lens

    /// When each artwork muscle was last trained (the end of the workout), over everything up to now.
    var lastTrainedById: [String: Date] {
        var out: [String: Date] = [:]
        for w in live where w.date <= now {
            let end = w.date.addingTimeInterval(w.duration)
            for log in w.exerciseLogs {
                guard let exercise = log.exercise, !log.workingSets.isEmpty else { continue }
                for id in BodyMuscleTree.creditedIds(for: exercise) where (out[id] ?? .distantPast) < end { out[id] = end }
            }
        }
        return out
    }

    func hours(since last: Date?) -> Double? { last.map { max(0, now.timeIntervalSince($0) / 3600) } }

    /// 1.0 just after training, easing to 0.25 at the end of the window; nil (grey) after it or when never trained.
    static func freshness(hours: Double?) -> Double? {
        guard let hours, hours <= BodyPageConfig.windowHours else { return nil }
        return BodyPageConfig.freshMax - (BodyPageConfig.freshMax - BodyPageConfig.freshMin) * (hours / BodyPageConfig.windowHours)
    }

    /// "22H AGO", or "3D AGO" past 72 hours; "—" when never trained.
    static func agoText(hours: Double?) -> String {
        guard let hours else { return "—" }
        if hours >= BodyPageConfig.daysAfterHours { return "\(Int(hours / 24))D AGO" }
        return "\(max(0, Int(hours)))H AGO"
    }

    struct Freshness: Equatable {
        let hours: Double?
        var inWindow: Bool { hours.map { $0 <= BodyPageConfig.windowHours } ?? false }
        var isDue: Bool { hours.map { $0 > BodyPageConfig.windowHours } ?? false }
        /// Share of the window left (1 just trained, 0 at the end).
        var windowLeft: Double { hours.map { max(0, 1 - $0 / BodyPageConfig.windowHours) } ?? 0 }
        var level: Double? { BodyPageStats.freshness(hours: hours) }
    }

    /// Per artwork id.
    var frequencyLevels: [String: Double] {
        var out: [String: Double] = [:]
        for (id, last) in lastTrainedById {
            if let f = Self.freshness(hours: hours(since: last)) { out[id] = f }
        }
        return out
    }

    func freshness(of muscle: BodyMuscleDef, last: [String: Date]) -> Freshness {
        Freshness(hours: hours(since: muscle.ids.compactMap { last[$0] }.max()))
    }
    func freshness(of head: BodyHeadDef, last: [String: Date]) -> Freshness { Freshness(hours: hours(since: last[head.id])) }
    func freshness(of group: BodyGroupDef, last: [String: Date]) -> Freshness {
        Freshness(hours: hours(since: group.ids.compactMap { last[$0] }.max()))
    }

    var inWindowCount: Int { let l = lastTrainedById; return BodyMuscleTree.muscles.filter { freshness(of: $0, last: l).inWindow }.count }
    var dueCount: Int { let l = lastTrainedById; return BodyMuscleTree.muscles.filter { freshness(of: $0, last: l).isDue }.count }

    /// The muscle that leaves the window first: its name and the hours left.
    var nextDue: (name: String, hoursLeft: Int)? {
        let l = lastTrainedById
        let inWin = BodyMuscleTree.muscles.compactMap { m -> (String, Double)? in
            let f = freshness(of: m, last: l)
            guard f.inWindow, let h = f.hours else { return nil }
            return (m.name, BodyPageConfig.windowHours - h)
        }
        guard let first = inWin.min(by: { $0.1 < $1.1 }) else { return nil }
        return (first.0, max(1, Int(first.1.rounded(.up))))
    }

    // MARK: Ticker

    /// Set changes per muscle group (CHEST, BACK…), the scrubbed week against the same point of the week before: this week so far
    /// against last week up to the same weekday and time (a past week against the whole week before it), so early in the week isn't all
    /// negatives. Zero changes are left out; biggest first.
    var groupChanges: [(name: String, delta: Int)] {
        let cutoff: Date? = weekOffset == 0 ? now : nil
        func inWeek(_ offset: Int, upTo limit: Date?) -> [Workout] {
            guard let limit else { return workouts(inWeek: offset) }
            return workouts(inWeek: offset).filter { $0.date <= limit }
        }
        let cur = Self.tally(inWeek(weekOffset, upTo: cutoff))
        let prev = Self.tally(inWeek(weekOffset - 1, upTo: cutoff.flatMap { calendar.date(byAdding: .day, value: -7, to: $0) }))
        return BodyMuscleTree.groups
            .map { (name: $0.name, delta: (cur.group[$0.id] ?? 0) - (prev.group[$0.id] ?? 0)) }
            .filter { $0.delta != 0 }
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    /// At most 6 items, ups and downs alternating (the biggest of each first) so the strip is never one colour when both exist.
    func tickerItems(member: Bool) -> [TickerItem] {
        guard !live.isEmpty else { return [] }
        let changes = groupChanges
        var ups = changes.filter { $0.delta > 0 }[...], downs = changes.filter { $0.delta < 0 }[...]
        var mixed: [(name: String, delta: Int)] = []
        let limit = member ? 5 : 6          // a member's IN WINDOW item is the sixth
        while mixed.count < limit, !(ups.isEmpty && downs.isEmpty) {
            if let u = ups.popFirst() { mixed.append(u) }
            if mixed.count < limit, let d = downs.popFirst() { mixed.append(d) }
        }
        var items = mixed.map {
            TickerItem(label: $0.name.uppercased(), value: "\(abs($0.delta)) SET\(abs($0.delta) == 1 ? "" : "S")", direction: $0.delta > 0 ? .up : .down)
        }
        if member { items.append(TickerItem(label: "IN WINDOW", value: "\(inWindowCount)/\(muscleCount)", direction: nil)) }
        return items
    }
}
