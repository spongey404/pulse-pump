import Foundation

/// What the redesigned Home shows beyond the original KPIs (Ore Home Final): the weekly streak, the week ledger, the stats strip with its
/// changes against last week, the "LAST WEEK" line and the ticker. Pure: `now` and `calendar` are injected, there is no SwiftUI.
struct HomeWeekStats {
    /// Finished, non-deleted workouts, newest first.
    let workouts: [Workout]
    let templates: [WorkoutTemplate]
    var now: Date = Date()
    var calendar: Calendar = .current

    // MARK: Weeks

    func monday(of date: Date) -> Date {
        let d = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -((calendar.component(.weekday, from: d) + 5) % 7), to: d) ?? d
    }
    var thisMonday: Date { monday(of: now) }
    var lastMonday: Date { calendar.date(byAdding: .day, value: -7, to: thisMonday) ?? thisMonday }
    /// 0 = Monday … 6 = Sunday.
    var todayIndex: Int { (calendar.component(.weekday, from: now) + 5) % 7 }
    func date(ofDay i: Int, weekStart: Date? = nil) -> Date { calendar.date(byAdding: .day, value: i, to: weekStart ?? thisMonday) ?? thisMonday }

    func workouts(from start: Date, to end: Date) -> [Workout] { workouts.filter { $0.date >= start && $0.date < end } }
    var thisWeek: [Workout] { workouts(from: thisMonday, to: date(ofDay: 7)) }
    var lastWeek: [Workout] { workouts(from: lastMonday, to: thisMonday) }
    /// Last week up to the same moment of the week as now, so this week isn't compared with a whole one.
    var lastWeekSoFar: [Workout] {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return workouts(from: lastMonday, to: cutoff.addingTimeInterval(1))
    }

    /// Weeks in a row with at least one workout, counting back from this week (a week still to start doesn't break it).
    var weekStreak: Int {
        let weeks = Set(workouts.map { monday(of: $0.date) })
        var cursor = weeks.contains(thisMonday) ? thisMonday : lastMonday
        var n = 0
        while weeks.contains(cursor) {
            n += 1
            cursor = calendar.date(byAdding: .day, value: -7, to: cursor) ?? cursor
            if n > 520 { break }
        }
        return n
    }

    /// "WEEK 6": weeks since the first workout, 1-based.
    var weekNumber: Int {
        guard let first = workouts.map(\.date).min() else { return 1 }
        let weeks = calendar.dateComponents([.weekOfYear], from: monday(of: first), to: thisMonday).weekOfYear ?? 0
        return max(1, weeks + 1)
    }

    // MARK: Stats strip

    struct StatsStrip: Equatable {
        let sets: Int, setsDelta: Int?
        let volumeKg: Double, volumeDelta: Double?
        let prs: Int, prsDelta: Int?
    }

    /// PRs in a set of workouts: exercises whose best working weight beats everything before the first of them.
    func prCount(in set: [Workout], before start: Date) -> Int {
        var best: [UUID: Double] = [:]
        for w in set {
            for l in w.exerciseLogs {
                guard let e = l.exercise else { continue }
                best[e.id] = max(best[e.id] ?? 0, l.workingSets.map(\.weight).max() ?? 0)
            }
        }
        guard !best.isEmpty else { return 0 }
        var prior: [UUID: Double] = [:]
        for w in workouts where w.date < start {
            for l in w.exerciseLogs {
                guard let e = l.exercise, best[e.id] != nil else { continue }
                prior[e.id] = max(prior[e.id] ?? 0, l.workingSets.map(\.weight).max() ?? 0)
            }
        }
        return best.filter { id, w in w > 0 && w > (prior[id] ?? 0) }.count
    }

    var strip: StatsStrip {
        let cur = thisWeek, prev = lastWeekSoFar
        let sets = cur.reduce(0) { $0 + $1.workingSetCount }, prevSets = prev.reduce(0) { $0 + $1.workingSetCount }
        let vol = cur.reduce(0) { $0 + $1.workingVolume }, prevVol = prev.reduce(0) { $0 + $1.workingVolume }
        let prs = prCount(in: cur, before: thisMonday)
        let prevPRs = prCount(in: lastWeek, before: lastMonday)
        return StatsStrip(sets: sets, setsDelta: prevSets > 0 ? sets - prevSets : nil, volumeKg: vol,
                          volumeDelta: DeltaText.change(now: vol, before: prevVol), prs: prs, prsDelta: lastWeek.isEmpty ? nil : prs - prevPRs)
    }

    // MARK: Program plan

    /// The program Home plans from: the most recently trained, else the first.
    var program: ProgramSummary? {
        ProgramPlan.programs(from: templates).sorted { (ProgramPlan.lastUsed($0) ?? .distantPast) > (ProgramPlan.lastUsed($1) ?? .distantPast) }.first
    }

    /// The workout planned for a Calendar weekday (1 = Sunday); nil on a rest day or without a program.
    func planned(weekday: Int) -> WorkoutTemplate? {
        guard let p = program, !p.workouts.isEmpty else { return nil }
        guard let i = ProgramPlan.assignment(days: p.days, workoutCount: p.workouts.count)[weekday] else { return nil }
        return p.workouts[i]
    }

    /// Training days per week in the program (the denominator of "3/6 DONE"); nil without a program.
    var plannedDays: Int? { program.map { $0.days.count } }

    // MARK: Ledger

    struct LedgerRow: Identifiable {
        let id: Int
        let day: String
        let name: String
        let isToday: Bool
        let workout: Workout?
        let sets: Int?
        let volumeText: String
        let isRest: Bool
    }

    static let dayNames = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    /// Volume change of a workout against the previous session of the same template ("—" when there is none or nothing changed).
    func volumeText(for workout: Workout) -> String {
        guard let name = workout.template?.name.lowercased() else { return "—" }
        let prev = workouts.first { $0.id != workout.id && $0.template?.name.lowercased() == name && $0.date < workout.date }
        guard let prev else { return "—" }
        return DeltaText.percent(DeltaText.change(now: workout.workingVolume, before: prev.workingVolume))
    }

    var ledger: [LedgerRow] {
        let week = thisWeek
        return (0..<7).map { i in
            let day = date(ofDay: i)
            let weekday = calendar.component(.weekday, from: day)
            let done = week.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
            if let w = done.first {
                return LedgerRow(id: i, day: Self.dayNames[i], name: w.template?.name ?? "Workout", isToday: i == todayIndex, workout: w,
                                 sets: done.reduce(0) { $0 + $1.workingSetCount }, volumeText: volumeText(for: w), isRest: false)
            }
            let plan = planned(weekday: weekday)
            let rest = program != nil && plan == nil
            return LedgerRow(id: i, day: Self.dayNames[i], name: rest ? "Rest" : (plan?.name ?? "—"), isToday: i == todayIndex, workout: nil,
                             sets: nil, volumeText: "", isRest: rest)
        }
    }

    var doneDays: Int { Set(thisWeek.map { calendar.startOfDay(for: $0.date) }).count }

    /// "3/6" with a program, "3" without.
    var doneText: String { plannedDays.map { "\(doneDays)/\($0)" } ?? "\(doneDays)" }

    /// "6/6 · 98 SETS · 51.0K KG"; nil when last week is empty.
    func lastWeekLine(unit: UnitPreference) -> String? {
        let w = lastWeek
        guard !w.isEmpty else { return nil }
        let days = Set(w.map { calendar.startOfDay(for: $0.date) }).count
        let sets = w.reduce(0) { $0 + $1.workingSetCount }
        let vol = w.reduce(0) { $0 + $1.workingVolume }
        let head = plannedDays.map { "\(days)/\($0)" } ?? "\(days) DAY\(days == 1 ? "" : "S")"
        return "\(head) · \(sets) SETS · \(unit.compactVolume(vol)) \(unit.label)"
    }

    // MARK: Hero

    /// A workout was logged today.
    var trainedToday: Bool { workouts.contains { calendar.isDate($0.date, inSameDayAs: now) } }

    /// "TODAY", or "UP NEXT · FRI" once today's workout is logged (or today is a rest day): the hero then shows the next one.
    var heroLabel: String {
        guard let p = program, !p.days.isEmpty else { return "TODAY" }
        let isTrainingDay = p.days.contains(calendar.component(.weekday, from: now))
        guard trainedToday || !isTrainingDay,
              let next = ProgramPlan.nextTrainingDay(from: now, days: p.days, trainedToday: true, calendar: calendar),
              let name = ProgramPlan.weekdayNames[next.weekday] else { return "TODAY" }
        return "UP NEXT · \(name)"
    }

    /// "THURSDAY 5 NOVEMBER".
    var dateLine: String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEEE d MMMM"
        return f.string(from: now).uppercased()
    }

    /// "PUSH PULL LEGS · DAY 1 OF 3" for the workout that is up next.
    func programLine(upNext template: WorkoutTemplate?) -> String? {
        guard let p = program, let template, let i = p.workouts.firstIndex(where: { $0.id == template.id }) else { return nil }
        return "\(p.name.uppercased()) · DAY \(i + 1) OF \(p.workouts.count)"
    }

    /// "AVG 52 MIN · 5 EXERCISES · LAST MON" (parts without data are left out).
    func metaLine(for template: WorkoutTemplate) -> String {
        var parts: [String] = []
        // The mean of the last 5 sessions, shown whenever they exist (an edit to the workout since doesn't hide it).
        if let m = ProgramPlan.averageMinutes(durations: template.liveWorkouts.map { ($0.date, $0.duration) }, editedAt: .distantPast) { parts.append("AVG \(m) MIN") }
        let n = template.templateExercises.count
        if n > 0 { parts.append("\(n) EXERCISE\(n == 1 ? "" : "S")") }
        if let last = template.liveWorkouts.map(\.date).max() {
            let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE"
            parts.append("LAST \(f.string(from: last).uppercased())")
        } else if workouts.isEmpty { parts.append("FIRST SESSION") }
        return parts.joined(separator: " · ")
    }

    func exerciseLine(for template: WorkoutTemplate) -> String {
        template.templateExercises.sorted { $0.order < $1.order }.map(\.exerciseName).joined(separator: " · ")
    }

    // MARK: Ticker

    /// Lift changes (top weight, last session against the one before), the week's volume, the weekly streak and PRs. Zero changes are left out.
    func tickerItems(unit: UnitPreference) -> [TickerItem] {
        guard !workouts.isEmpty else { return [] }
        var items: [TickerItem] = []
        var seen = Set<UUID>()
        for w in workouts {      // newest first
            for l in w.exerciseLogs {
                guard items.count < 4, let e = l.exercise, !seen.contains(e.id), let top = l.workingSets.map(\.weight).max() else { continue }
                seen.insert(e.id)
                let prev = workouts.first { $0.date < w.date && $0.exerciseLogs.contains { $0.exercise?.id == e.id } }
                guard let prevTop = prev?.exerciseLogs.first(where: { $0.exercise?.id == e.id })?.workingSets.map(\.weight).max() else { continue }
                let d = top - prevTop
                if abs(d) > 0.001 {
                    items.append(TickerItem(label: e.name.uppercased(), value: unit.format(abs(d)), direction: d > 0 ? .up : .down))
                }
            }
        }
        let s = strip
        if let v = s.volumeDelta, Int(v.rounded()) != 0 {
            items.append(TickerItem(label: "WK VOL", value: "\(abs(Int(v.rounded())))%", direction: v > 0 ? .up : .down))
        }
        if weekStreak > 0 { items.append(TickerItem(label: "STREAK", value: "\(weekStreak) WK", direction: nil)) }
        if s.prs > 0 { items.append(TickerItem(label: "PRS", value: "\(s.prs)", direction: nil)) }
        return items
    }
}


/// Everything Home shows from `HomeWeekStats`, worked out once per change to the workouts (like `HomeKPIs`), not per redraw.
struct HomeSnapshot {
    var weekStreak = 0
    var strip = HomeWeekStats.StatsStrip(sets: 0, setsDelta: nil, volumeKg: 0, volumeDelta: nil, prs: 0, prsDelta: nil)
    var ledger: [HomeWeekStats.LedgerRow] = []
    var weekNumber = 1
    var doneText = "0"
    var lastWeekLine: String?
    var ticker: [TickerItem] = []
    var hasHistory = false

    static let empty = HomeSnapshot()

    init() {}

    init(_ stats: HomeWeekStats, unit: UnitPreference) {
        weekStreak = stats.weekStreak
        strip = stats.strip
        ledger = stats.ledger
        weekNumber = stats.weekNumber
        doneText = stats.doneText
        lastWeekLine = stats.lastWeekLine(unit: unit)
        ticker = stats.tickerItems(unit: unit)
        hasHistory = !stats.workouts.isEmpty
    }
}
