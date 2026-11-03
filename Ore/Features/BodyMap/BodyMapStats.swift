import Foundation

enum HeatmapMode: String, CaseIterable {
    case volume = "Volume"
    case recency = "Recency"
}

enum ColdSpotsMode: String, CaseIterable {
    case freq = "FREQ"
    case vol = "VOL"
}

/// Everything the Body tab computes (week + day scrub, hero, VS PACE / VS WK, TOP / GAPS, heat levels,
/// cold spots, calendar jump). Pure: the view passes its scrub state (`weekOffset`, `selectedDayIndex`) and the
/// injected `now` / `calendar` make it testable. Weeks on this tab are Monday-first by construction.
struct BodyMapStats {
    /// Non-deleted workouts, drafts included (drafts are filtered below, as the screen does).
    let workouts: [Workout]
    var weekOffset = 0
    var selectedDayIndex = -1
    var now: Date = Date()
    var calendar: Calendar = .current

    /// How many weeks back the week row can scroll (current + 3).
    static let numWeeks = 4

    // MARK: Targets (sets per week) and training cadence (days) for the 17 tracked groups

    static let tracked: [MuscleGroup] = [
        .chest, .lats, .quads, .hamstrings, .glutes, .frontDelts, .sideDelts, .rearDelts,
        .biceps, .triceps, .traps, .upperBack, .forearms, .lowerBack, .calves, .abs, .obliques,
    ]
    static let targets: [MuscleGroup: Int] = [
        .chest: 16, .lats: 16, .quads: 20, .hamstrings: 12, .glutes: 12,
        .frontDelts: 8, .sideDelts: 10, .rearDelts: 8, .biceps: 10, .triceps: 10,
        .traps: 8, .upperBack: 12, .forearms: 6, .lowerBack: 6, .calves: 8, .abs: 8, .obliques: 6,
    ]
    static let cadence: [MuscleGroup: Int] = [
        .chest: 4, .lats: 4, .quads: 4, .hamstrings: 5, .glutes: 5,
        .frontDelts: 3, .sideDelts: 3, .rearDelts: 3, .biceps: 4, .triceps: 4,
        .traps: 5, .upperBack: 4, .forearms: 5, .lowerBack: 5, .calves: 5, .abs: 4, .obliques: 5,
    ]
    static let abbr: [MuscleGroup: String] = [
        .chest: "CHEST", .lats: "LATS", .quads: "QUADS", .hamstrings: "HAMS", .glutes: "GLUTE",
        .frontDelts: "F.DELT", .sideDelts: "S.DELT", .rearDelts: "R.DELT", .biceps: "BICEPS",
        .triceps: "TRICEPS", .traps: "TRAPS", .upperBack: "U.BACK", .forearms: "FOREARM",
        .lowerBack: "L.BACK", .calves: "CALVES", .abs: "ABS", .obliques: "OBLIQ",
    ]
    static var weeklyTarget: Int { targets.values.reduce(0, +) }
    static let dailyTarget = 26

    /// Generic groups on older exercises fold into the 17 tracked ones.
    func tracked(_ m: MuscleGroup) -> MuscleGroup? {
        switch m {
        case .back: .upperBack
        case .shoulders: .sideDelts
        default: Self.targets[m] != nil ? m : nil
        }
    }

    /// Tracked groups an exercise hits, each once (a generic group next to a specific child is dropped).
    func trackedSet(_ groups: [MuscleGroup]) -> Set<MuscleGroup> {
        MuscleGroup.trackedGroups(groups, tracked: Set(Self.tracked))
    }

    private var exerciseLogs: [ExerciseLog] { workouts.flatMap(\.exerciseLogs) }

    func setCount(_ w: Workout) -> Int { w.workingSetCount }

    // MARK: Week + day geometry

    var mondayOfThisWeek: Date {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        return calendar.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: today)!
    }

    var weekMonday: Date {
        calendar.date(byAdding: .weekOfYear, value: weekOffset, to: mondayOfThisWeek)!
    }

    var weekNumber: Int { calendar.component(.weekOfYear, from: weekMonday) }

    func setsInWeek(offset: Int) -> Int {
        let mon = calendar.date(byAdding: .weekOfYear, value: offset, to: mondayOfThisWeek)!
        let end = calendar.date(byAdding: .day, value: 7, to: mon)!
        return workouts.filter { !$0.isDraft && $0.date >= mon && $0.date < end }.reduce(0) { $0 + setCount($1) }
    }

    /// Which days of the scrubbed week have a finished workout (the dots under the day letters).
    var loggedDays: [Bool] {
        (0..<7).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: weekMonday)!
            return workouts.contains { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: date) }
        }
    }

    // MARK: Hero + VS

    struct VSInfo: Equatable {
        let label: String
        let value: String
        let sub: String
        /// +1 up, -1 down, 0 neutral (drives the colour and the ticker arrow).
        let sign: Int
    }

    private func pctText(_ p: Int) -> String { p > 0 ? "▲ +\(p)%" : p < 0 ? "▼ \(p)%" : "● 0%" }
    private func sign(_ p: Int) -> Int { p > 0 ? 1 : p < 0 ? -1 : 0 }

    var vsInfo: VSInfo {
        let cal = calendar
        if selectedDayIndex >= 0 {
            let date = cal.date(byAdding: .day, value: selectedDayIndex, to: weekMonday)!
            guard let w = workouts.first(where: { !$0.isDraft && cal.isDate($0.date, inSameDayAs: date) }) else {
                return VSInfo(label: "VS LAST", value: "—", sub: "REST DAY", sign: 0)
            }
            let name = w.template?.name
            let prev = workouts.filter { !$0.isDraft && $0.date < w.date && $0.template?.name == name && name != nil }
                .max(by: { $0.date < $1.date })
            let cur = setCount(w)
            if let prev, setCount(prev) > 0 {
                let p = Int((Double(cur - setCount(prev)) / Double(setCount(prev)) * 100).rounded())
                let f = DateFormatter(); f.dateFormat = "MMM d"; f.timeZone = cal.timeZone
                return VSInfo(label: "VS LAST " + (name?.uppercased().split(separator: " ").first.map(String.init) ?? ""),
                              value: pctText(p),
                              sub: "\(f.string(from: prev.date).uppercased()) · \(setCount(prev)) SETS", sign: sign(p))
            }
            return VSInfo(label: "VS LAST", value: "—", sub: "FIRST SESSION", sign: 0)
        }
        let prevTotal = setsInWeek(offset: weekOffset - 1)
        if weekOffset == 0 {
            let elapsed = (cal.dateComponents([.day], from: weekMonday, to: cal.startOfDay(for: now)).day ?? 0) + 1
            let expected = max(1, Int((Double(Self.weeklyTarget) * Double(elapsed) / 7).rounded()))
            let p = Int((Double(selectedTotalSets - expected) / Double(expected) * 100).rounded())
            let dayNames = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            return VSInfo(label: "VS PACE", value: pctText(p),
                          sub: "\(expected) DUE BY \(dayNames[min(max(elapsed, 1), 7) - 1])", sign: sign(p))
        }
        let weekNum = cal.component(.weekOfYear, from: weekMonday)
        guard prevTotal > 0 else { return VSInfo(label: "VS WK \(weekNum - 1)", value: "—", sub: "0 SETS", sign: 0) }
        let p = Int((Double(selectedTotalSets - prevTotal) / Double(prevTotal) * 100).rounded())
        return VSInfo(label: "VS WK \(weekNum - 1)", value: pctText(p), sub: "\(prevTotal) SETS", sign: sign(p))
    }

    // MARK: Selection

    var filteredLogs: [ExerciseLog] {
        let monday = weekMonday
        if selectedDayIndex >= 0 {
            let targetDate = calendar.date(byAdding: .day, value: selectedDayIndex, to: monday)!
            return exerciseLogs.filter { log in
                guard let workout = log.workout, !workout.isDraft else { return false }
                return calendar.isDate(workout.date, inSameDayAs: targetDate)
            }
        }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: monday) else { return exerciseLogs }
        return exerciseLogs.filter { log in
            guard let workout = log.workout, !workout.isDraft else { return false }
            return workout.date >= monday && workout.date < weekEnd
        }
    }

    var selectedTotalSets: Int { filteredLogs.reduce(0) { $0 + $1.workingSets.count } }

    var selectedDayLabel: String {
        let df = DateFormatter(); df.dateFormat = "MMM d"; df.timeZone = calendar.timeZone
        if selectedDayIndex >= 0 {
            let dayNames = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            let date = calendar.date(byAdding: .day, value: selectedDayIndex, to: weekMonday)!
            let workout = workouts.first { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: date) }
            let name = workout?.template?.name.uppercased() ?? (workout != nil ? "WORKOUT" : "REST")
            return "\(dayNames[selectedDayIndex]) · \(df.string(from: date).uppercased()) · \(name)"
        }
        let sunday = calendar.date(byAdding: .day, value: 6, to: weekMonday)!
        let sameMonth = calendar.component(.month, from: weekMonday) == calendar.component(.month, from: sunday)
        let end = sameMonth ? "\(calendar.component(.day, from: sunday))" : df.string(from: sunday).uppercased()
        return "WEEK \(weekNumber) · \(df.string(from: weekMonday).uppercased())–\(end)"
    }

    var musclesWorkedCount: Int {
        var muscles = Set<MuscleGroup>()
        for log in filteredLogs {
            guard let exercise = log.exercise else { continue }
            muscles.formUnion(trackedSet(exercise.primaryMuscleGroups))
        }
        return muscles.count
    }

    // MARK: TOP / GAPS

    struct MuscleItem: Identifiable, Equatable {
        let key: String
        let sets: Int
        let target: Int
        var id: String { key }
        var ratio: Double { Double(sets) / Double(max(target, 1)) }
    }

    var setsByMuscle: [MuscleGroup: Int] {
        var out: [MuscleGroup: Int] = [:]
        for log in filteredLogs {
            guard let exercise = log.exercise else { continue }
            for t in trackedSet(exercise.primaryMuscleGroups) { out[t, default: 0] += log.workingSets.count }
        }
        return out
    }

    var muscleSetsData: [MuscleItem] {
        let sets = setsByMuscle
        return Self.tracked.map { MuscleItem(key: Self.abbr[$0] ?? $0.displayName.uppercased(),
                                             sets: sets[$0] ?? 0, target: Self.targets[$0] ?? 10) }
            .sorted { $0.ratio > $1.ratio }
    }

    var topMuscles: [MuscleItem] { Array(muscleSetsData.prefix(3)) }
    var gapMuscles: [MuscleItem] { Array(muscleSetsData.suffix(3).reversed()) }

    // MARK: Heat

    /// Heat intensity per group — VOLUME (sets vs target / vs the day's peak) or LAST 48H (recency fade).
    func heatLevels(mode: HeatmapMode) -> [MuscleGroup: Double] {
        var levels: [MuscleGroup: Double] = [:]
        if mode == .recency {
            let cal = calendar
            let end: Date = selectedDayIndex >= 0
                ? cal.date(byAdding: .day, value: selectedDayIndex, to: weekMonday)!
                : min(cal.date(byAdding: .day, value: 6, to: weekMonday)!, cal.startOfDay(for: now))
            let now = cal.date(byAdding: .hour, value: 21, to: end)!
            for m in Self.tracked {
                var last: Date?
                for log in exerciseLogs {
                    guard let ex = log.exercise, let w = log.workout, !w.isDraft, w.date <= now else { continue }
                    if trackedSet(ex.primaryMuscleGroups).contains(m), last == nil || w.date > last! { last = w.date }
                }
                if let last { levels[m] = max(0, 1 - now.timeIntervalSince(last) / (48 * 3600)) }
            }
            return levels
        }
        let sets = setsByMuscle
        let peak = Double(max(sets.values.max() ?? 1, 1))
        for m in Self.tracked {
            let v = Double(sets[m] ?? 0)
            levels[m] = selectedDayIndex >= 0 ? v / peak : min(1, v / Double(Self.targets[m] ?? 10))
        }
        return levels
    }

    // MARK: Cold spots

    struct ColdSpotItem: Identifiable, Equatable {
        let muscleName: String
        let value: Int
        let target: Int
        let isFlagged: Bool
        var id: String { muscleName }
        var ratio: Double { Double(value) / Double(max(target, 1)) }
    }

    func coldSpots(mode: ColdSpotsMode) -> [ColdSpotItem] {
        let calendar = self.calendar
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        if mode == .freq {
            return Self.tracked.map { muscle in
                var latest: Date? = nil
                for log in exerciseLogs {
                    guard let ex = log.exercise, let w = log.workout, !w.isDraft else { continue }
                    let hit = trackedSet(ex.primaryMuscleGroups + ex.secondaryMuscleGroups).contains(muscle)
                    if hit, latest == nil || w.date > latest! { latest = w.date }
                }
                let days = latest.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day ?? 0 } ?? 99
                let cad = Self.cadence[muscle] ?? 4
                return ColdSpotItem(muscleName: muscle.displayName, value: days, target: cad,
                                    isFlagged: days >= Int(Double(cad) * 1.5))
            }
            .sorted { Double($0.value) / Double($0.target) > Double($1.value) / Double($1.target) }
            .prefix(3).map { $0 }
        }
        var setsByMuscle: [MuscleGroup: Int] = [:]
        for log in exerciseLogs {
            guard let ex = log.exercise, let w = log.workout, !w.isDraft, w.date >= weekAgo else { continue }
            let primary = trackedSet(ex.primaryMuscleGroups)
            for t in primary { setsByMuscle[t, default: 0] += log.workingSets.count }
            for t in trackedSet(ex.secondaryMuscleGroups).subtracting(primary) { setsByMuscle[t, default: 0] += log.workingSets.count / 2 }
        }
        return Self.tracked.map { muscle in
            let sets = setsByMuscle[muscle] ?? 0
            let tgt = Self.targets[muscle] ?? 10
            return ColdSpotItem(muscleName: muscle.displayName, value: sets, target: tgt,
                                isFlagged: Double(sets) / Double(tgt) < 0.5)
        }
        .sorted { $0.ratio < $1.ratio }
        .prefix(3).map { $0 }
    }

    // MARK: Calendar "VIEW ›"

    /// Where the Body tab lands when the calendar's VIEW › is tapped for `date`: the week offset and day index to scrub
    /// to, or nil when the day is older than the week scrubber covers (clamping would land on a different week).
    func viewTarget(for date: Date) -> (weekOffset: Int, dayIndex: Int)? {
        let cal = calendar
        let selWD = cal.component(.weekday, from: date)
        let selMon = cal.date(byAdding: .day, value: -(selWD == 1 ? 6 : selWD - 2), to: cal.startOfDay(for: date))!
        let weekDiff = cal.dateComponents([.weekOfYear], from: selMon, to: mondayOfThisWeek).weekOfYear ?? 0
        guard weekDiff < Self.numWeeks else { return nil }
        return (-weekDiff, selWD == 1 ? 6 : selWD - 2)
    }

    // MARK: Ticker

    /// Days since the last finished workout whose template name contains `name` ("5D"), or "—".
    func daysSince(workoutNamed name: String) -> String {
        guard let w = workouts.filter({ !$0.isDraft && ($0.template?.name.uppercased().contains(name) ?? false) })
            .max(by: { $0.date < $1.date }) else { return "—" }
        return "\(calendar.dateComponents([.day], from: calendar.startOfDay(for: w.date), to: calendar.startOfDay(for: now)).day ?? 0)D"
    }
}
