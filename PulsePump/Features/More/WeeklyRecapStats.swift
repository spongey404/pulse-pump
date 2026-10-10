import Foundation

/// The numbers on the Weekly Recap screen for one ISO week (Monday start). Pure: `now` / `calendar` / `unit`
/// are injected so journey tests can read exactly what the screen shows. `WeeklyRecapView` wraps one of these.
struct WeeklyRecapStats {
    /// Finished, non-deleted workouts (the view's `@Query`).
    let workouts: [Workout]
    /// 0 = this week, 1 = last week, …
    var weeksBack = 0
    var now: Date = Date()
    var unit: UnitPreference = .kg
    /// Days in the user's split (the session target); 0 when there is none.
    var splitDayCount = 0
    var calendar: Calendar = WeeklyRecapStats.isoMonday

    static var isoMonday: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.firstWeekday = 2
        return c
    }

    var weekStart: Date {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        return calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: thisWeek)!
    }
    var weekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekStart)! }
    var prevStart: Date { calendar.date(byAdding: .day, value: -7, to: weekStart)! }

    func inRange(_ from: Date, _ to: Date) -> [Workout] {
        workouts.filter { $0.date >= from && $0.date < to }
    }
    var week: [Workout] { inRange(weekStart, weekEnd) }
    var prev: [Workout] { inRange(prevStart, weekStart) }

    func working(_ w: Workout) -> [(log: ExerciseLog, set: SetLog)] {
        w.exerciseLogs.flatMap { log in log.sets.filter { $0.setType != .warmup }.map { (log, $0) } }
    }
    /// Total working volume in thousands of the display unit (tonnes for kg, K lb for lbs). SetLog.weight is kg.
    func volumeTonnes(_ ws: [Workout]) -> Double {
        unit.display(ws.flatMap(working).reduce(0) { $0 + $1.set.weight * Double($1.set.reps) }) / 1000
    }
    func setCount(_ ws: [Workout]) -> Int { ws.flatMap(working).count }
    func minutes(_ ws: [Workout]) -> Int { Int(ws.reduce(0) { $0 + $1.duration } / 60) }

    var target: Int {
        splitDayCount > 0 ? splitDayCount : max(week.count, 5)
    }

    var weekNumber: Int { calendar.component(.weekOfYear, from: weekStart) }

    var bars: [(value: Double, done: Bool)] {
        (0..<7).map { i in
            let day = calendar.date(byAdding: .day, value: i, to: weekStart)!
            let ws = week.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return (Double(setCount(ws)), !ws.isEmpty)
        }
    }

    // Muscle buckets from the design: Back / Chest / Legs / Shoulders / Arms
    func bucket(_ m: MuscleGroup) -> String? {
        switch m {
        case .back, .lats, .traps: "Back"
        case .chest: "Chest"
        case .quads, .hamstrings, .glutes, .calves: "Legs"
        case .shoulders: "Shoulders"
        case .biceps, .triceps, .forearms: "Arms"
        default: nil
        }
    }
    func muscleSets(_ ws: [Workout]) -> [String: Int] {
        var out: [String: Int] = [:]
        for (log, _) in ws.flatMap(working) {
            guard let m = log.exercise?.primaryMuscleGroups.first, let b = bucket(m) else { continue }
            out[b, default: 0] += 1
        }
        return out
    }

    struct Record: Equatable {
        let name: String
        let meta: String
        let value: String
        /// The set that beat the old best (kg, reps).
        let weightKg: Double
        let reps: Int
    }

    var records: [Record] {
        // Heaviest working set per exercise this week that beats everything logged before the week.
        let before = workouts.filter { $0.date < weekStart }.flatMap(working)
        var bestBefore: [String: Double] = [:]
        for (log, s) in before { if let n = log.exercise?.name { bestBefore[n] = max(bestBefore[n] ?? 0, s.weight) } }
        var out: [Record] = []
        for w in week.sorted(by: { $0.date < $1.date }) {
            var top: [String: SetLog] = [:]
            for (log, s) in working(w) {
                guard let n = log.exercise?.name else { continue }
                if s.weight > (top[n]?.weight ?? 0) { top[n] = s }
            }
            for (n, s) in top where s.weight > (bestBefore[n] ?? 0) && bestBefore[n] != nil {
                bestBefore[n] = s.weight
                let f = DateFormatter(); f.dateFormat = "EEE d MMM"
                out.append(Record(name: n,
                                  meta: "\(f.string(from: w.date).uppercased()) · \(w.template?.name.uppercased() ?? "WORKOUT")",
                                  value: "\(unit.number(s.weight))×\(s.reps)", weightKg: s.weight, reps: s.reps))
            }
        }
        return out
    }
}
