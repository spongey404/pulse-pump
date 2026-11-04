import Foundation

/// The calendar's data from the finished workouts and the active program (the one most recently trained, else the first).
/// Built once per change: days are looked up by a "yyyy-MM-dd" key, never by scanning the history per tile.
struct WorkoutCalendarData: CalendarDataSource {
    private let byDay: [String: [CalendarSession]]
    private let planByWeekday: [Int: CalendarPlanDay]
    private let calendar: Calendar
    let firstDate: Date

    init(workouts: [Workout], templates: [WorkoutTemplate], now: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        let live = workouts.filter { !$0.isDraft && $0.deletedAt == nil }
        var dict: [String: [CalendarSession]] = [:]
        for w in live {
            let s = CalendarSession(id: w.id, date: w.date, name: w.template?.name ?? "Workout", sets: w.workingSetCount, seconds: w.duration)
            dict[Self.key(w.date, calendar), default: []].append(s)
        }
        for k in dict.keys { dict[k]?.sort { $0.date < $1.date } }
        byDay = dict
        firstDate = live.map(\.date).min() ?? now

        let programs = ProgramPlan.programs(from: templates)
        let active = programs.sorted { (ProgramPlan.lastUsed($0) ?? .distantPast) > (ProgramPlan.lastUsed($1) ?? .distantPast) }.first
        var plan: [Int: CalendarPlanDay] = [:]
        if let p = active, !p.workouts.isEmpty, !p.days.isEmpty {
            let assignment = ProgramPlan.assignment(days: p.days, workoutCount: p.workouts.count)
            for weekday in 1...7 {
                if let i = assignment[weekday] { plan[weekday] = CalendarPlanDay(name: p.workouts[i].name, isRest: false) }
                else { plan[weekday] = CalendarPlanDay(name: "Rest", isRest: true) }
            }
        }
        planByWeekday = plan
    }

    static func key(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    func sessions(on day: Date) -> [CalendarSession] { byDay[Self.key(day, calendar)] ?? [] }

    func plan(on day: Date) -> CalendarPlanDay? { planByWeekday[calendar.component(.weekday, from: day)] }
}
