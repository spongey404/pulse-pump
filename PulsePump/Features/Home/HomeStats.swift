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
        return "▲ 0%"
    }

    func improvedExercises(in workout: Workout) -> Int {
        workout.exerciseLogs.filter { log in
            guard let exercise = log.exercise else { return false }
            let thisVol = log.workingSets.map { $0.weight * Double($0.reps) }.max() ?? 0
            let prevBest = workouts
                .filter { $0.date < workout.date }
                .flatMap(\.exerciseLogs)
                .filter { $0.exercise?.id == exercise.id }
                .flatMap(\.workingSets)
                .map { $0.weight * Double($0.reps) }
                .max() ?? 0
            return thisVol > prevBest && thisVol > 0
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
