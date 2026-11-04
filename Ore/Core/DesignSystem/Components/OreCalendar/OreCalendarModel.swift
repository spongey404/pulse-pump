import Foundation

/// One logged session as the calendar shows it.
struct CalendarSession: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let name: String
    let sets: Int
    let seconds: TimeInterval
}

/// What the program says a day is: a workout or a rest day. `nil` from the data source means there is no program.
struct CalendarPlanDay: Equatable {
    let name: String          // "Push Day"
    let isRest: Bool
}

/// Where the calendar gets its days. History and Body both give it one built from the finished workouts and the programs.
protocol CalendarDataSource {
    /// First day with a logged session (the ‹ arrow stops at its month). Today when nothing is logged.
    var firstDate: Date { get }
    func sessions(on day: Date) -> [CalendarSession]
    func plan(on day: Date) -> CalendarPlanDay?
}

enum CalendarSelection: Equatable {
    case none
    case day(Date)
    /// The Monday that starts the week.
    case week(Date)
}

/// What a tapped card does: History opens the workout, Body shows the day or week on the map.
enum CalendarCardAction { case openWorkout, showOnMap }

struct CalendarTile: Equatable {
    enum State { case blank, selected, trained, today, planned, rest, other }
    let date: Date?
    let state: State
    let label: String
    let selectable: Bool
}

struct CalendarWeekRow: Equatable {
    let monday: Date
    let number: Int
    let selectable: Bool
    let selected: Bool
    let tiles: [CalendarTile]
}

struct CalendarCard: Equatable {
    let date: String
    let name: String
    let meta: String
    /// Set when tapping the card has somewhere to go.
    let session: CalendarSession?
    let hasSessions: Bool
    let showsChevron: Bool
}

/// The calendar's rules with no SwiftUI: month bounds, the Monday-first rows, week numbers, tile states and labels, and the card text.
/// Shared by History (fullscreen) and Body (modal), so the two can never differ.
struct OreCalendarLogic {
    let source: CalendarDataSource
    var today: Date = Date()
    var calendar: Calendar = Calendar.current

    private var cal: Calendar {
        var c = calendar; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4; return c   // ISO weeks, Monday first
    }

    func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }

    func monthStart(_ d: Date) -> Date { cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d }

    func monday(of d: Date) -> Date {
        let s = startOfDay(d)
        let offset = (cal.component(.weekday, from: s) + 5) % 7
        return cal.date(byAdding: .day, value: -offset, to: s) ?? s
    }

    var firstMonth: Date { monthStart(source.firstDate) }
    var currentMonth: Date { monthStart(today) }

    func canGoBack(from month: Date) -> Bool { monthStart(month) > firstMonth }
    func canGoForward(from month: Date) -> Bool { monthStart(month) < currentMonth }

    func shift(_ month: Date, by delta: Int) -> Date {
        let next = cal.date(byAdding: .month, value: delta, to: monthStart(month)) ?? month
        if next < firstMonth { return firstMonth }
        if next > currentMonth { return currentMonth }
        return next
    }

    /// "NOVEMBER 2026".
    func title(of month: Date) -> String {
        let f = DateFormatter(); f.calendar = cal; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "LLLL yyyy"
        return f.string(from: month).uppercased()
    }

    func weekNumber(of monday: Date) -> Int { cal.component(.weekOfYear, from: monday) }

    /// The last day a tile can be tapped: the end of the current week (so this week's plan can be looked at).
    private var lastSelectable: Date { cal.date(byAdding: .day, value: 6, to: monday(of: today)) ?? today }
    func isSelectable(_ d: Date) -> Bool { startOfDay(d) >= startOfDay(source.firstDate) && startOfDay(d) <= lastSelectable }

    /// "PUSH", "PULL", "LEGS": the first word of the workout's name, at most five letters.
    static func shortName(_ name: String) -> String {
        let stripped = name.uppercased()
            .replacingOccurrences(of: " DAY", with: "").replacingOccurrences(of: " WORKOUT", with: "")
        let first = stripped.split(separator: " ").first.map(String.init) ?? "WORKOUT"
        if first == "LEG" { return "LEGS" }
        return String(first.prefix(5))
    }

    func rows(for month: Date, selection: CalendarSelection) -> [CalendarWeekRow] {
        let first = monthStart(month)
        var out: [CalendarWeekRow] = []
        var ws = monday(of: first)
        let selectedWeek: Date? = { if case .week(let w) = selection { return monday(of: w) }; return nil }()
        let selectedDay: Date? = { if case .day(let d) = selection { return startOfDay(d) }; return nil }()
        for r in 0..<6 {
            if r > 0, cal.component(.month, from: ws) != cal.component(.month, from: first) { break }
            let days: [Date] = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: ws) }
            let weekHasData = days.contains { isSelectable($0) && cal.isDate($0, equalTo: first, toGranularity: .month) }
            let tiles = days.map { tile($0, month: first, selectedDay: selectedDay) }
            out.append(CalendarWeekRow(monday: ws, number: weekNumber(of: ws), selectable: weekHasData,
                                       selected: selectedWeek == ws, tiles: tiles))
            ws = cal.date(byAdding: .day, value: 7, to: ws) ?? ws
        }
        return out
    }

    func tile(_ d: Date, month: Date, selectedDay: Date?) -> CalendarTile {
        guard cal.isDate(d, equalTo: month, toGranularity: .month) else {
            return CalendarTile(date: nil, state: .blank, label: "", selectable: false)     // other months' days are never shown
        }
        let day = startOfDay(d)
        let sessions = source.sessions(on: day)
        let sets = sessions.reduce(0) { $0 + $1.sets }
        let isToday = day == startOfDay(today)
        let isFuture = day > startOfDay(today)
        let plan = source.plan(on: day)
        let selectable = isSelectable(day)
        if selectedDay == day { return CalendarTile(date: day, state: .selected, label: labelFor(sessions, sets: sets, isToday: isToday, plan: plan, future: isFuture), selectable: selectable) }
        if !sessions.isEmpty { return CalendarTile(date: day, state: .trained, label: labelFor(sessions, sets: sets, isToday: isToday, plan: plan, future: isFuture), selectable: selectable) }
        if isToday { return CalendarTile(date: day, state: .today, label: "TODAY", selectable: selectable) }
        if let plan, day >= startOfDay(source.firstDate), isFuture || plan.isRest {
            return CalendarTile(date: day, state: plan.isRest ? .rest : .planned, label: plan.isRest ? "REST" : Self.shortName(plan.name), selectable: selectable)
        }
        return CalendarTile(date: day, state: .other, label: "", selectable: selectable)
    }

    private func labelFor(_ sessions: [CalendarSession], sets: Int, isToday: Bool, plan: CalendarPlanDay?, future: Bool) -> String {
        if let s = sessions.first { return "\(Self.shortName(s.name)) \(sets)" }
        if isToday { return "TODAY" }
        if let plan { return plan.isRest ? "REST" : Self.shortName(plan.name) }
        return ""
    }

    // MARK: Cards

    private func dateText(_ d: Date) -> String {
        let f = DateFormatter(); f.calendar = cal; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE d MMM"
        return f.string(from: d).uppercased()
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// The card for one day: the session, or why there isn't one.
    func card(for d: Date) -> CalendarCard {
        let day = startOfDay(d)
        let sessions = source.sessions(on: day)
        let date = dateText(day)
        if let s = sessions.first {
            let sets = sessions.reduce(0) { $0 + $1.sets }
            return CalendarCard(date: date, name: s.name.uppercased(), meta: "\(sets) SETS · \(Self.clock(sessions.reduce(0) { $0 + $1.seconds }))",
                                session: s, hasSessions: true, showsChevron: true)
        }
        let plan = source.plan(on: day)
        let isToday = day == startOfDay(today), isFuture = day > startOfDay(today)
        if isToday {
            return CalendarCard(date: date, name: "NO WORKOUT", meta: plan.map { $0.isRest ? "REST DAY TODAY" : "\($0.name.uppercased()) IS UP NEXT" } ?? "",
                                session: nil, hasSessions: false, showsChevron: false)
        }
        if plan?.isRest == true { return CalendarCard(date: date, name: "REST DAY", meta: "", session: nil, hasSessions: false, showsChevron: false) }
        if isFuture, let plan { return CalendarCard(date: date, name: "PLANNED · \(plan.name.uppercased())", meta: "", session: nil, hasSessions: false, showsChevron: false) }
        return CalendarCard(date: date, name: "NO WORKOUT", meta: "", session: nil, hasSessions: false, showsChevron: false)
    }

    /// History's week selection: one card per session that week, oldest first.
    func cards(forWeek mondayDate: Date) -> [CalendarCard] {
        let ws = monday(of: mondayDate)
        let cards = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: ws) }
            .flatMap { day -> [CalendarCard] in
                source.sessions(on: day).map { s in
                    CalendarCard(date: dateText(day), name: s.name.uppercased(), meta: "\(s.sets) SETS · \(Self.clock(s.seconds))",
                                 session: s, hasSessions: true, showsChevron: true)
                }
            }
        if cards.isEmpty {
            return [CalendarCard(date: "WEEK \(weekNumber(of: ws))", name: "NO WORKOUTS", meta: "", session: nil, hasSessions: false, showsChevron: false)]
        }
        return cards
    }

    /// Body's week selection: one card for the whole week.
    func weekCard(forWeek mondayDate: Date) -> CalendarCard {
        let ws = monday(of: mondayDate)
        let sessions = source.sessionsInWeek(of: ws, calendar: cal)
        let sets = sessions.reduce(0) { $0 + $1.sets }
        return CalendarCard(date: "WEEK \(weekNumber(of: ws))", name: "WHOLE WEEK",
                            meta: sessions.isEmpty ? "NO WORKOUTS" : "\(sessions.count) SESSION\(sessions.count == 1 ? "" : "S") · \(sets) SETS",
                            session: nil, hasSessions: !sessions.isEmpty, showsChevron: false)
    }
}

extension CalendarDataSource {
    func sessionsInWeek(of monday: Date, calendar: Calendar) -> [CalendarSession] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }.flatMap { sessions(on: $0) }
    }
}
