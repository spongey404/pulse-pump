import Foundation

/// Every number on the Home tab (KPI row, week bars, RECENT table, ticker), computed from the finished
/// workouts. Pure: no SwiftUI, no clock of its own (`now` / `calendar` are injected), so journey tests
/// can drive the exact maths the screen shows. `HomeTabView` builds one of these per render.
struct HomeStats {
    /// Finished, non-deleted workouts, newest first (the view's `@Query`).
    let workouts: [Workout]
    var now: Date = Date()
    var calendar: Calendar = .current

    // MARK: KPI row

    var currentStreak: Int {
        StreakCalculator.currentStreak(from: workouts.map(\.date), now: now, calendar: calendar)
    }

    var weekStart: Date {
        WeekMath.mondayWeekStart(of: now, calendar: calendar)   // Monday-based, like Recap/Body/widgets
    }

    var weekWorkouts: [Workout] {
        let start = weekStart
        return workouts.filter { $0.date >= start }
    }

    var weekSets: Int {
        weekWorkouts.reduce(0) { $0 + $1.workingSetCount }
    }

    var weekPRs: Int {
        let weekStart = self.weekStart
        var weekMaxByExercise: [UUID: Double] = [:]
        var prevMaxByExercise: [UUID: Double] = [:]
        for workout in workouts {
            let isThisWeek = workout.date >= weekStart
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                let maxWeight = log.workingSets.map(\.weight).max() ?? 0
                if isThisWeek {
                    weekMaxByExercise[exercise.id] = max(weekMaxByExercise[exercise.id] ?? 0, maxWeight)
                } else {
                    prevMaxByExercise[exercise.id] = max(prevMaxByExercise[exercise.id] ?? 0, maxWeight)
                }
            }
        }
        return weekMaxByExercise.filter { id, weekMax in
            weekMax > (prevMaxByExercise[id] ?? 0) && weekMax > 0
        }.count
    }

    var weekImproved: Int {
        let weekStart = self.weekStart
        let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? now
        var thisWeekBest: [UUID: Double] = [:]
        var prevWeekBest: [UUID: Double] = [:]
        for workout in workouts {
            // Only this week and last week matter: don't open the logs of older workouts at all.
            guard workout.date >= prevWeekStart else { continue }
            let isThisWeek = workout.date >= weekStart
            let isPrevWeek = workout.date >= prevWeekStart && workout.date < weekStart
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                let bestVol = log.workingSets.map { $0.weight * Double($0.reps) }.max() ?? 0
                if isThisWeek { thisWeekBest[exercise.id] = max(thisWeekBest[exercise.id] ?? 0, bestVol) }
                else if isPrevWeek { prevWeekBest[exercise.id] = max(prevWeekBest[exercise.id] ?? 0, bestVol) }
            }
        }
        return thisWeekBest.filter { id, vol in vol > (prevWeekBest[id] ?? 0) && vol > 0 }.count
    }

    // MARK: Week bars

    /// Sets per day for the current week (Mon=0 … Sun=6)
    var weekDayBars: [Int] {
        var bars = [Int](repeating: 0, count: 7)
        for workout in weekWorkouts {
            let weekday = calendar.component(.weekday, from: workout.date) // 1=Sun…7=Sat
            let idx = (weekday + 5) % 7  // Mon=0…Sun=6
            bars[idx] += workout.workingSetCount
        }
        return bars
    }

    var todayDayIndex: Int {
        let weekday = calendar.component(.weekday, from: now)
        return (weekday + 5) % 7
    }

    /// "WK n" in the bars header: weeks since the join date (or the oldest workout), 1-based.
    func currentWeekNumber(userCreatedAt: Date?) -> Int {
        let origin = userCreatedAt ?? workouts.last?.date ?? now
        let weeks = calendar.dateComponents([.weekOfYear], from: origin, to: now).weekOfYear ?? 0
        return max(1, weeks + 1)
    }

    // MARK: RECENT table

    struct RecentRow: Equatable {
        let name: String
        let sets: Int
        let improved: Int
        let exerciseCount: Int
        let volumeDelta: String
    }

    var recentWorkouts: [Workout] { Array(workouts.prefix(3)) }

    var recentRows: [RecentRow] {
        recentWorkouts.map { w in
            RecentRow(name: (w.template?.name ?? "Workout").uppercased(), sets: w.workingSetCount,
                      improved: improvedExercises(in: w), exerciseCount: max(w.exerciseLogs.count, 1),
                      volumeDelta: volumeDelta(for: w))
        }
    }

    func volumeDelta(for workout: Workout) -> String {
        let curVol = workout.workingVolume
        guard curVol > 0, let templateName = workout.template?.name else { return "—" }
        let prev = workouts.first { $0.id != workout.id && $0.template?.name.lowercased() == templateName.lowercased() && $0.date < workout.date }
        guard let prevWorkout = prev else { return "—" }
        let prevVol = prevWorkout.workingVolume
        guard prevVol > 0 else { return "—" }
        let pct = Int(((curVol - prevVol) / prevVol) * 100)
        // Arrow alone carries direction — no redundant +/- sign, and a real space (not
        // glued to the number) matching the ticker's own arrow-to-value gap.
        if pct > 0 { return "▲ \(pct)%" }
        if pct < 0 { return "▼ \(abs(pct))%" }
        return "—"
    }

    /// How many of the workout's exercises beat their best set volume from every earlier session. One pass over
    /// the earlier history, not one pass per exercise.
    func improvedExercises(in workout: Workout) -> Int {
        var prevBest: [UUID: Double] = [:]
        for earlier in workouts where earlier.date < workout.date {
            for log in earlier.exerciseLogs {
                guard let id = log.exercise?.id else { continue }
                let best = log.workingSets.map { $0.weight * Double($0.reps) }.max() ?? 0
                if best > (prevBest[id] ?? 0) { prevBest[id] = best }
            }
        }
        return workout.exerciseLogs.filter { log in
            guard let exercise = log.exercise else { return false }
            let thisVol = log.workingSets.map { $0.weight * Double($0.reps) }.max() ?? 0
            return thisVol > (prevBest[exercise.id] ?? 0) && thisVol > 0
        }.count
    }

    // MARK: Ticker

    struct TickerRow: Equatable {
        let label: String
        let value: String
        let up: Bool
    }

    /// Per-muscle working sets: last 7 days vs the 7 before.
    var tickerRows: [TickerRow] {
        var muscleVolume: [MuscleGroup: Int] = [:]
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let prevWeekStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        var prevVolume: [MuscleGroup: Int] = [:]
        for workout in workouts {
            guard workout.date >= prevWeekStart else { continue }   // older workouts don't count: skip their logs
            let isThisWeek = workout.date >= weekAgo
            let isPrevWeek = workout.date >= prevWeekStart && workout.date < weekAgo
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                for muscle in exercise.primaryMuscleGroups {
                    if isThisWeek { muscleVolume[muscle, default: 0] += log.workingSets.count }
                    if isPrevWeek { prevVolume[muscle, default: 0] += log.workingSets.count }
                }
            }
        }

        return MuscleGroup.allCases.compactMap { muscle -> TickerRow? in
            let cur = muscleVolume[muscle] ?? 0
            let prev = prevVolume[muscle] ?? 0
            guard cur > 0 || prev > 0 else { return nil }
            let label = String(muscle.displayName.uppercased().prefix(6))
            if prev == 0 {
                return TickerRow(label: label, value: "\(cur)", up: true)
            } else {
                let pct = Int(((Double(cur) - Double(prev)) / Double(prev)) * 100)
                return TickerRow(label: label, value: "\(abs(pct))%", up: pct >= 0)
            }
        }
    }
}

/// The Home tab's numbers worked out once, not on every redraw.
///
/// They read the whole history (the PR count compares this week with everything before it), and SwiftData
/// loads each record as it is touched, so recomputing them inside the view body kept Home busy and made
/// everything drawn on top of it slow. Two parts to the fix:
/// - `HomeTabView` keeps one of these in state and rebuilds it only when the workouts change;
/// - `init(onePassOver:)` answers every question in a single walk over the history, reading each exercise
///   log's sets once, where the individual `HomeStats` properties each walk it again (the PR count, the
///   "improved" count, the ticker, and one more walk for each of the three RECENT rows).
///
/// Both ways give the same numbers; `HomeKPIsTests` holds them to that. The individual `HomeStats`
/// properties stay as the plain, readable definition of each number.
struct HomeKPIs: Equatable {
    var currentStreak = 0
    var weekSets = 0
    var weekPRs = 0
    var weekImproved = 0
    var weekDayBars = [Int](repeating: 0, count: 7)
    var todayDayIndex = 0
    var tickerRows: [HomeStats.TickerRow] = []
    /// The three RECENT rows, in the order of `HomeStats.recentWorkouts`.
    var recentRows: [HomeStats.RecentRow] = []

    static let empty = HomeKPIs()

    init() {}

    /// The reference way: each number from its own `HomeStats` property.
    init(_ stats: HomeStats) {
        currentStreak = stats.currentStreak
        weekSets = stats.weekSets
        weekPRs = stats.weekPRs
        weekImproved = stats.weekImproved
        weekDayBars = stats.weekDayBars
        todayDayIndex = stats.todayDayIndex
        tickerRows = stats.tickerRows
        recentRows = stats.recentRows
    }

    /// What one exercise log contributed, read once.
    private struct LogFacts {
        let exerciseId: UUID?
        let muscles: [MuscleGroup]
        let maxWeight: Double
        let maxVolume: Double
        let workingSets: Int
    }

    private static func facts(_ log: ExerciseLog) -> LogFacts {
        let sets = log.workingSets   // loads each set's fields: do it once per log
        return LogFacts(exerciseId: log.exercise?.id, muscles: log.exercise?.primaryMuscleGroups ?? [],
                        maxWeight: sets.map(\.weight).max() ?? 0,
                        maxVolume: sets.map { $0.weight * Double($0.reps) }.max() ?? 0,
                        workingSets: sets.count)
    }

    /// The same numbers as `init(_:)`, from one oldest-to-newest walk over the history.
    init(onePassOver stats: HomeStats) {
        let calendar = stats.calendar, now = stats.now
        currentStreak = stats.currentStreak
        todayDayIndex = stats.todayDayIndex

        let weekStart = stats.weekStart
        let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? now
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let recent = stats.recentWorkouts
        let recentIDs = Set(recent.map(\.id))

        var bars = [Int](repeating: 0, count: 7)
        var sets = 0
        var weekMaxWeight: [UUID: Double] = [:], beforeWeekMaxWeight: [UUID: Double] = [:]
        var thisWeekBestVol: [UUID: Double] = [:], prevWeekBestVol: [UUID: Double] = [:]
        var tickerThis: [MuscleGroup: Int] = [:], tickerPrev: [MuscleGroup: Int] = [:]
        var improvedByWorkout: [UUID: Int] = [:]

        // Best set volume per exercise over everything strictly before the current date. Updates for workouts that
        // share a date wait until the date moves on, so "earlier" means earlier, as in `improvedExercises(in:)`.
        var bestVolume: [UUID: Double] = [:]
        var pending: [(UUID, Double)] = []
        var pendingDate: Date?
        func flush() { for (id, v) in pending where v > (bestVolume[id] ?? 0) { bestVolume[id] = v }; pending = [] }

        for workout in stats.workouts.reversed() {
            if let d = pendingDate, workout.date > d { flush() }
            pendingDate = workout.date

            let isThisWeek = workout.date >= weekStart
            let isPrevWeek = workout.date >= prevWeekStart && workout.date < weekStart
            let isTickerThis = workout.date >= weekAgo
            let isTickerPrev = workout.date >= twoWeeksAgo && workout.date < weekAgo
            var workoutSets = 0
            var improved = 0

            for log in workout.exerciseLogs {
                let f = Self.facts(log)
                workoutSets += f.workingSets
                if let id = f.exerciseId {
                    if isThisWeek {
                        weekMaxWeight[id] = max(weekMaxWeight[id] ?? 0, f.maxWeight)
                        thisWeekBestVol[id] = max(thisWeekBestVol[id] ?? 0, f.maxVolume)
                    } else {
                        beforeWeekMaxWeight[id] = max(beforeWeekMaxWeight[id] ?? 0, f.maxWeight)
                    }
                    if isPrevWeek { prevWeekBestVol[id] = max(prevWeekBestVol[id] ?? 0, f.maxVolume) }
                    if recentIDs.contains(workout.id), f.maxVolume > (bestVolume[id] ?? 0), f.maxVolume > 0 { improved += 1 }
                    pending.append((id, f.maxVolume))
                    for muscle in f.muscles {
                        if isTickerThis { tickerThis[muscle, default: 0] += f.workingSets }
                        if isTickerPrev { tickerPrev[muscle, default: 0] += f.workingSets }
                    }
                }
            }
            if isThisWeek {
                sets += workoutSets
                let weekday = calendar.component(.weekday, from: workout.date)
                bars[(weekday + 5) % 7] += workoutSets
            }
            if recentIDs.contains(workout.id) { improvedByWorkout[workout.id] = improved }
        }

        weekSets = sets
        weekDayBars = bars
        weekPRs = weekMaxWeight.filter { id, w in w > (beforeWeekMaxWeight[id] ?? 0) && w > 0 }.count
        weekImproved = thisWeekBestVol.filter { id, v in v > (prevWeekBestVol[id] ?? 0) && v > 0 }.count
        tickerRows = MuscleGroup.allCases.compactMap { muscle -> HomeStats.TickerRow? in
            let cur = tickerThis[muscle] ?? 0, prev = tickerPrev[muscle] ?? 0
            guard cur > 0 || prev > 0 else { return nil }
            let label = String(muscle.displayName.uppercased().prefix(6))
            if prev == 0 { return HomeStats.TickerRow(label: label, value: "\(cur)", up: true) }
            let pct = Int(((Double(cur) - Double(prev)) / Double(prev)) * 100)
            return HomeStats.TickerRow(label: label, value: "\(abs(pct))%", up: pct >= 0)
        }
        recentRows = recent.map { w in
            HomeStats.RecentRow(name: (w.template?.name ?? "Workout").uppercased(), sets: w.workingSetCount,
                                improved: improvedByWorkout[w.id] ?? 0, exerciseCount: max(w.exerciseLogs.count, 1),
                                volumeDelta: stats.volumeDelta(for: w))
        }
    }
}
