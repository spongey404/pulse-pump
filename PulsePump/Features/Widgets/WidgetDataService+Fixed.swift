import Foundation
import SwiftData
import WidgetKit

// MARK: - Data for the fixed widget set (PWFixedData)
//
// Everything here is derived from SwiftData; nothing is estimated unless noted.
// Thresholds (all in one place, see the constants below):
//  - muscle "stale": 0 sets in the last 7 days or last trained more than 5 days ago
//  - balances (4 weeks, working sets): PUSH:PULL 0.80-1.25, UPPER:LOWER 0.67-1.50, ANT:POST 0.80-1.25
//  - PR watch: lift is "close" when 4-week best Epley e1RM is within 5% of the all-time PR weight
//  - deload week: weekly load (sets x RPE, RPE = 10 - RIR, default 7) < 60% of the prior-4-week
//    average, or any workout in that week flagged `isDeload`
//  - rolling block = 6 weeks, program block = 8 weeks

extension WidgetDataService {
    static let plusFlagKey = "widget_isPlusSubscribed"
    static let friendsKey = "widget_friends"
    static let ecoFuelKey = "pulse_eco_fuel"
    static let ecoStrideKey = "pulse_eco_stride"

    enum Band {
        static let pushPull: ClosedRange<Double> = 0.80...1.25
        static let upperLower: ClosedRange<Double> = 0.67...1.50
        static let antPost: ClosedRange<Double> = 0.80...1.25
        static let staleDays = 5
        static let prGap = 0.05
        static let deloadFraction = 0.6
        static let rollingBlock = 6
        static let programBlock = 8
    }

    /// A working (non-warm-up) set with everything the widget maths needs.
    struct FSet {
        let name: String
        let muscles: [MuscleGroup]
        let pattern: MovementPattern?
        let weight: Double
        let reps: Int
        let rir: Int?
        let date: Date
        var rpe: Double { rir.map { Double(10 - max(0, min(10, $0))) } ?? 7 }
        var e1rm: Double { reps <= 1 ? weight : weight * (1 + Double(reps) / 30) }
    }

    static func fsets(_ w: Workout) -> [FSet] {
        w.exerciseLogs.flatMap { log in
            log.sets.filter { $0.setType != .warmup }.compactMap { s -> FSet? in
                guard let ex = log.exercise else { return nil }
                return FSet(name: ex.name, muscles: ex.primaryMuscleGroups, pattern: ex.movementPattern,
                            weight: s.weight, reps: s.reps, rir: s.rir, date: w.date)
            }
        }
    }

    // MARK: Entry point

    static func buildFixed(workouts: [Workout], modelContext: ModelContext, user: User?, snap: PumpWidgetSnapshot,
                           now: Date = Date(), defaults: UserDefaults? = UserDefaults(suiteName: "group.com.pulse.PulsePump")) -> PWFixedData {
        var f = PWFixedData()
        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: now)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let todayIdx = max(0, min(6, cal.dateComponents([.day], from: weekStart, to: today).day ?? 0))
        func daysBetween(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0 }
        func text(_ pattern: String, _ d: Date) -> String {
            let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.calendar = cal; df.dateFormat = pattern
            return df.string(from: d).uppercased()
        }
        func name(of w: Workout) -> String { w.template?.name ?? "Workout" }
        func short(_ s: String) -> String {
            s.lowercased().hasSuffix(" day") ? String(s.dropLast(4)) : s
        }

        let done = workouts.filter { !$0.isDraft }.sorted { $0.date > $1.date }   // newest first
        let allSets = done.map { ($0, fsets($0)) }
        let flat = allSets.flatMap { $0.1 }

        // --- Subscription
        f.isPlus = currentIsPlus(defaults: defaults)

        // --- 02 Streak strip / last workout / week
        let loggedDays = Set(done.map { cal.startOfDay(for: $0.date) })
        for off in stride(from: -6, through: 0, by: 1) {
            let d = cal.date(byAdding: .day, value: off, to: today) ?? today
            f.streakLogged.append(loggedDays.contains(d))
            f.streakLetters.append(["S", "M", "T", "W", "T", "F", "S"][cal.component(.weekday, from: d) - 1])
        }
        if let last = done.first {
            f.lastWorkoutName = name(of: last)
            f.lastWorkoutWeekday = text("EEE", last.date)
            f.lastWorkoutDaysAgo = max(0, daysBetween(last.date, today))
            f.lastWorkoutExercises = last.exerciseLogs.count
            f.lastWorkoutMinutes = Int(last.duration / 60)
        }
        f.todayIndex = todayIdx
        f.weekSetsPerDay = [Double](repeating: 0, count: 7)
        f.weekDone = [Bool](repeating: false, count: 7)
        let weekWorkouts = done.filter { $0.date >= weekStart }
        for (w, sets) in allSets where w.date >= weekStart {
            let i = max(0, min(6, daysBetween(weekStart, w.date)))
            f.weekSetsPerDay[i] += Double(sets.count)
            f.weekDone[i] = true
        }
        f.recentSessions = done.prefix(3).map { w in
            let d = max(0, daysBetween(w.date, today))
            let ago = d == 0 ? "TODAY" : d == 1 ? "1 DAY AGO" : "\(d) DAYS AGO"
            return PWRecentSession(name: name(of: w), when: "\(text("EEE", w.date)) · \(ago)",
                                   meta: "\(w.exerciseLogs.count) EX · \(Int(w.duration / 60))M")
        }

        // --- 03 Weekly volume (this week up to today vs last week up to the same weekday)
        let lastWeekStart = cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let lastCutoff = cal.date(byAdding: .day, value: todayIdx + 1, to: lastWeekStart) ?? lastWeekStart
        let thisW = allSets.filter { $0.0.date >= weekStart }
        let lastW = allSets.filter { $0.0.date >= lastWeekStart && $0.0.date < lastCutoff }
        func tonnes(_ g: [(Workout, [FSet])]) -> Double { g.flatMap { $0.1 }.reduce(0) { $0 + $1.weight * Double($1.reps) } / 1000 }
        func seconds(_ g: [(Workout, [FSet])]) -> Double { g.reduce(0) { $0 + $1.0.duration } }
        f.setsThisWeek = thisW.reduce(0) { $0 + $1.1.count }
        f.setsLastWeekSameDay = lastW.reduce(0) { $0 + $1.1.count }
        f.volumeTonnes = (tonnes(thisW) * 10).rounded() / 10
        f.volumeDeltaPct = pctDelta(tonnes(thisW), tonnes(lastW))
        let secs = Int(seconds(thisW))
        f.trainingHours = String(format: "%d:%02d", secs / 3600, (secs % 3600) / 60)
        f.hoursDeltaPct = pctDelta(seconds(thisW), seconds(lastW))
        f.weekdayShort = text("EEE", today)
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        var lastPerDay = [Double](repeating: 0, count: 7)
        for (w, sets) in allSets where w.date >= lastWeekStart && w.date < weekStart {
            lastPerDay[max(0, min(6, daysBetween(lastWeekStart, w.date)))] += Double(sets.count)
        }
        f.volDays = (0..<7).map { PWVolDay(day: letters[$0], thisWeek: f.weekSetsPerDay[$0], lastWeek: lastPerDay[$0]) }

        // --- 04 Body map
        let window7 = cal.date(byAdding: .day, value: -6, to: today) ?? today
        var sets7: [String: Int] = [:]
        var lastHit: [String: Date] = [:]
        for s in flat {
            for g in Set(s.muscles.compactMap(displayGroup)) {
                if s.date >= window7 { sets7[g, default: 0] += 1 }
                if lastHit[g] == nil || s.date > lastHit[g]! { lastHit[g] = s.date }
            }
        }
        func daysSince(_ g: String) -> Int? { lastHit[g].map { max(0, daysBetween($0, today)) } }
        func dayText(_ g: String) -> String { daysSince(g).map { "\($0)D" } ?? "—" }
        let heatGroups = ["CHEST", "TRAPS", "SHOULDERS", "BICEPS", "FOREARMS", "CORE", "GLUTES", "QUADS", "CALVES"]
        f.neglected = heatGroups
            .sorted { (daysSince($0) ?? .max) > (daysSince($1) ?? .max) }   // never trained first
            .prefix(3).map { PWNamedValue(name: $0, value: dayText($0)) }
        let allGroups = ["CHEST", "BACK", "SHOULDERS", "TRICEPS", "BICEPS", "TRAPS", "FOREARMS", "QUADS", "HAMSTRINGS", "GLUTES", "CORE", "CALVES"]
        let ranked = allGroups.sorted {
            let a = sets7[$0] ?? 0, b = sets7[$1] ?? 0
            return a != b ? a > b : (daysSince($0) ?? .max) < (daysSince($1) ?? .max)
        }
        f.topMuscles = ranked.filter { (sets7[$0] ?? 0) > 0 }.prefix(4).map { PWNamedValue(name: $0, value: "\(sets7[$0] ?? 0)") }
        f.muscleRows = ranked.prefix(10).map { g in
            let n = sets7[g] ?? 0
            return PWMuscleRow(muscle: g, sets: n, last: dayText(g), stale: n == 0 || (daysSince(g) ?? .max) > Band.staleDays)
        }

        // --- 05 Balance (4 weeks)
        let window28 = cal.date(byAdding: .day, value: -27, to: today) ?? today
        let recent28 = flat.filter { $0.date >= window28 }
        var push = 0, pull = 0, upper = 0, lower = 0, ant = 0, post = 0
        for s in recent28 {
            switch pushPull(s) { case true?: push += 1; case false?: pull += 1; default: break }
            switch isUpper(s) { case true?: upper += 1; case false?: lower += 1; default: break }
            switch isAnterior(s) { case true?: ant += 1; case false?: post += 1; default: break }
        }
        f.balances = [
            balanceRow(key: "PUSH : PULL", aName: "PUSH", bName: "PULL", a: push, b: pull, band: Band.pushPull),
            balanceRow(key: "UPPER : LOWER", aName: "UPPER", bName: "LOWER", a: upper, b: lower, band: Band.upperLower),
            balanceRow(key: "ANT : POST", aName: "ANT", bName: "POST", a: ant, b: post, band: Band.antPost),
        ]

        // --- 06 PR watch
        var candidates: [PWLift] = []
        for lift in bigLifts {
            let sets = flat.filter { bigLift($0.name)?.display == lift.display && $0.weight > 0 }
            guard !sets.isEmpty else { continue }
            let pr = sets.map(\.weight).max() ?? 0
            let recentBest = sets.filter { $0.date >= window28 }.map(\.e1rm).max() ?? 0
            var weekly = [Double?](repeating: nil, count: 12)   // index 0 = oldest
            for s in sets {
                let ago = daysBetween(cal.dateInterval(of: .weekOfYear, for: s.date)?.start ?? s.date, weekStart) / 7
                guard ago >= 0, ago < 12 else { continue }
                weekly[11 - ago] = max(weekly[11 - ago] ?? 0, s.e1rm)
            }
            guard let firstKnown = weekly.compactMap({ $0 }).first else {
                // Older than 12 weeks: flat series from the best-ever value
                candidates.append(PWLift(name: lift.display, short: lift.short, e1rm: 0, pr: pr, series: [Double](repeating: sets.map(\.e1rm).max() ?? 0, count: 12)))
                continue
            }
            var carry = firstKnown
            let series = weekly.map { v -> Double in if let v { carry = v }; return (carry * 10).rounded() / 10 }
            candidates.append(PWLift(name: lift.display, short: lift.short, e1rm: (recentBest * 10).rounded() / 10, pr: pr, series: series))
        }
        f.prLifts = selectPRLifts(candidates)

        // --- 07 Deload / load
        let nWeeks = 12
        var loads = [Double](repeating: 0, count: nWeeks)       // index 11 = current week
        var flagged = [Bool](repeating: false, count: nWeeks)
        for (w, sets) in allSets {
            let ago = daysBetween(cal.dateInterval(of: .weekOfYear, for: w.date)?.start ?? w.date, weekStart) / 7
            guard ago >= 0, ago < nWeeks else { continue }
            loads[nWeeks - 1 - ago] += sets.reduce(0) { $0 + $1.rpe }
            if w.isDeload { flagged[nWeeks - 1 - ago] = true }
        }
        let firstActive = loads.firstIndex(where: { $0 > 0 }) ?? nWeeks - 1
        let deloads = detectDeloadWeeks(loads: loads, flagged: flagged, firstActive: firstActive)
        func isoWeek(weeksAgo: Int) -> Int {
            cal.component(.weekOfYear, from: cal.date(byAdding: .day, value: -7 * weeksAgo, to: weekStart) ?? weekStart)
        }
        let lastDeloadIdx = deloads.lastIndex(of: true)
        let origin = lastDeloadIdx ?? max(0, firstActive - 1)
        let sinceAnchor = max(1, (nWeeks - 1) - origin)
        f.blockWeeks = Band.rollingBlock
        f.blockWeek = min(sinceAnchor, Band.rollingBlock)
        let nextIdxAhead = sinceAnchor >= Band.rollingBlock ? 1 : Band.rollingBlock - sinceAnchor   // weeks from now
        let nextDeloadIsNextWeek = nextIdxAhead == 1
        f.nextDeloadWeek = "WK \(isoWeek(weeksAgo: -nextIdxAhead))"
        f.lastDeloadWeek = lastDeloadIdx.map { "WK \(isoWeek(weeksAgo: nWeeks - 1 - $0))" } ?? "—"
        f.loadWeeks = (4..<nWeeks).map { i in
            PWLoadWeek(label: "W\(isoWeek(weeksAgo: nWeeks - 1 - i))", load: loads[i], deload: deloads[i], current: i == nWeeks - 1, next: false)
        } + [PWLoadWeek(label: "W\(isoWeek(weeksAgo: -1))", load: 0, deload: nextDeloadIsNextWeek, current: false, next: true)]
        // Load ratio: this week so far vs the prior-4-week average over the same elapsed period.
        let elapsed = now.timeIntervalSince(weekStart)
        func periodLoad(weeksAgo k: Int, upTo limit: TimeInterval?) -> Double {
            let start = cal.date(byAdding: .day, value: -7 * k, to: weekStart) ?? weekStart
            let end = limit.map { start.addingTimeInterval($0) } ?? (cal.date(byAdding: .day, value: 7, to: start) ?? start)
            return allSets.filter { $0.0.date >= start && $0.0.date < end }.reduce(0) { $0 + $1.1.reduce(0) { $0 + $1.rpe } }
        }
        let prior4 = (1...4).map { periodLoad(weeksAgo: $0, upTo: elapsed) }.reduce(0, +) / 4
        let ratio = prior4 > 0 ? periodLoad(weeksAgo: 0, upTo: nil) / prior4 : 0
        let prevPrior4 = (2...5).map { periodLoad(weeksAgo: $0, upTo: nil) }.reduce(0, +) / 4
        let prevRatio = prevPrior4 > 0 ? periodLoad(weeksAgo: 1, upTo: nil) / prevPrior4 : 0
        f.loadRatio = (ratio * 100).rounded() / 100
        f.loadRatioDelta = prevRatio > 0 ? ((ratio - prevRatio) * 100).rounded() / 100 : 0

        // --- 09 Recap (last session)
        if let last = allSets.first {
            let sets = last.1
            let vol = sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
            f.recapVolumeKg = vol.rounded()
            f.recapSets = sets.count
            let secs = Int(last.0.duration)
            f.recapTime = String(format: "%02d:%02d", secs / 60, secs % 60)
            let prev = allSets.dropFirst().first { name(of: $0.0) == name(of: last.0) && $0.0.date < last.0.date }
            if let prev {
                f.recapVolumeDeltaPct = pctDelta(vol, prev.1.reduce(0) { $0 + $1.weight * Double($1.reps) })
            }
            // Best PR set: an exercise whose best e1RM beats everything logged before this session.
            var best: (FSet, Double)?
            for exName in Set(sets.map(\.name)) {
                let prior = flat.filter { $0.name == exName && $0.date < last.0.date }.map(\.e1rm).max() ?? 0
                guard prior > 0, let top = sets.filter({ $0.name == exName }).max(by: { $0.e1rm < $1.e1rm }), top.e1rm > prior + 0.01 else { continue }
                if best == nil || top.weight > best!.0.weight { best = (top, prior) }
            }
            if let (s, _) = best {
                f.recapPRName = s.name
                f.recapPRValue = "\(fmt(s.weight))×\(s.reps)"
            }
        }

        // --- 10 Program / 11 Goal
        let split = user?.selectedSplit
        let cycle = programCycle(split: split, history: done.map(name(of:)))
        let target = max(1, (split?.days.count ?? 0) > 0 ? split!.days.count : snap.sessionGoal)
        f.programName = split.map { $0.name } ?? "Program"
        f.programWeeks = Band.programBlock
        let splitLabels = Set((split?.days ?? []).flatMap { [$0.label.lowercased(), $0.workoutType.lowercased()] })
        let originDate = done.last(where: { splitLabels.contains(name(of: $0).lowercased()) })?.date ?? done.last?.date ?? split?.createdAt ?? now
        let originWeek = cal.dateInterval(of: .weekOfYear, for: originDate)?.start ?? weekStart
        let weeksSince = max(0, daysBetween(originWeek, weekStart) / 7)
        f.programWeek = weeksSince % Band.programBlock + 1
        f.programSessionsDone = weekWorkouts.count
        f.programSessionsTarget = target
        let nextName = snap.nextName
        var tiles: [PWProgramDay] = weekWorkouts.sorted { $0.date < $1.date }.suffix(3).map {
            PWProgramDay(tag: "✓ \(text("EEE", $0.date))", name: short(name(of: $0)), state: .done)
        }
        if !nextName.isEmpty {
            tiles.append(PWProgramDay(tag: "NEXT", name: short(nextName), state: .next))
            if let i = cycle.firstIndex(where: { $0.lowercased() == nextName.lowercased() }), cycle.count > 1 {
                var k = 1
                while tiles.count < 4 && k < cycle.count {
                    tiles.append(PWProgramDay(tag: "—", name: short(cycle[(i + k) % cycle.count]), state: .later)); k += 1
                }
            }
        }
        f.programDays = Array(tiles.prefix(4))
        let left = max(0, target - weekWorkouts.count)
        f.goalLeftLine = "\(left) LEFT · \(6 - todayIdx) DAYS"

        // --- 01 Next workout
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let nextTemplate = nextName.isEmpty ? nil : templates.first { $0.name.lowercased() == nextName.lowercased() }
        f.nextConfidence = predictionConfidence(names: done.prefix(14).compactMap { $0.template?.name }, hasSplit: split != nil, predicted: !nextName.isEmpty)
        let trainedToday = loggedDays.contains(today)
        f.nextDate = text("EEE d MMM", trainedToday ? (cal.date(byAdding: .day, value: 1, to: today) ?? today) : today)
        let detected = detectedSplitName(history: done.map(name(of:)))
        let namedSplit: String? = (split != nil && split!.type != SplitType.none) ? split!.name.uppercased() : nil
        f.nextSplitLine = "\(namedSplit ?? detected) · WK \(f.programWeek)"
        if let t = nextTemplate {
            f.nextSets = t.templateExercises.reduce(0) { $0 + $1.targetSets }
            f.nextExerciseList = t.templateExercises.sorted { $0.order < $1.order }.map { te in
                let lastSession = flat.filter { $0.name.lowercased() == te.exerciseName.lowercased() && $0.weight > 0 }
                    .max { $0.date < $1.date }
                var reps = te.targetReps.map(String.init) ?? "—"
                var kg = "—"
                if let ls = lastSession {
                    let sameDay = flat.filter { $0.name == ls.name && cal.isDate($0.date, inSameDayAs: ls.date) }
                    let top = sameDay.map(\.weight).max() ?? ls.weight
                    kg = fmt(top)
                    if te.targetReps == nil, let r = sameDay.first(where: { $0.weight == top })?.reps { reps = String(r) }
                }
                return PWExercise(name: te.exerciseName, target: "\(te.targetSets)×\(reps)", kg: kg)
            }
            if let lastSame = done.first(where: { $0.template?.id == t.id }) {
                f.nextLastSameDays = max(0, daysBetween(lastSame.date, today))
            }
        }
        f.nextLastSameName = nextName.split(separator: " ").first.map { $0.uppercased() } ?? ""

        // --- 12 Bodyweight
        if let kg = user?.weight, kg > 0 { BodyweightLog.record(kg: kg, on: now, calendar: .current, defaults: defaults) }
        let bw = BodyweightLog.summary(now: now, calendar: .current, defaults: defaults)
        f.bodyweightSeries = bw.series
        f.bodyweightDelta7d = bw.delta7d
        f.bodyweightStart = bw.start

        // --- 13 Friends (written by SocialViewModel after the feed loads)
        if let data = defaults?.data(forKey: friendsKey), let list = try? JSONDecoder().decode([PWFriendSession].self, from: data) {
            f.friends = Array(list.prefix(3))
        }

        // --- 14 Quick start
        let lastUsed: (WorkoutTemplate) -> Date = { t in done.first(where: { $0.template?.id == t.id })?.date ?? .distantPast }
        let ordered = templates.sorted { lastUsed($0) != lastUsed($1) ? lastUsed($0) > lastUsed($1) : $0.name < $1.name }
        let predictedT = ordered.first { $0.name.lowercased() == nextName.lowercased() }
        f.quickStarts = (predictedT.map { [$0] } ?? []).map {
            PWQuickStart(name: $0.name.uppercased(), meta: "PREDICTED · \($0.templateExercises.count) EX", predicted: true)
        } + ordered.filter { $0.id != predictedT?.id }.map {
            PWQuickStart(name: $0.name.uppercased(), meta: "\($0.templateExercises.count) EX", predicted: false)
        }
        f.quickStarts = Array(f.quickStarts.prefix(6))

        // --- 15 Pulse ecosystem
        func eco(_ key: String, app: String, label: String) -> PWEcoRow {
            if let data = defaults?.data(forKey: key), let row = try? JSONDecoder().decode(PWEcoRow.self, from: data) { return row }
            return PWEcoRow(app: app, key: label, value: "—", of: "")
        }
        f.eco = [PWEcoRow(app: "PUMP", key: "SESSIONS", value: "\(weekWorkouts.count)", of: "/ \(snap.sessionGoal)"),
                 eco(ecoFuelKey, app: "FUEL", label: "KCAL TODAY"),
                 eco(ecoStrideKey, app: "STRIDE", label: "KM THIS WK")]
        return f
    }

    // MARK: Pure helpers (unit-tested)

    static func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    static func pctDelta(_ now: Double, _ before: Double) -> Double {
        guard before > 0 else { return 0 }
        return ((now - before) / before * 1000).rounded() / 10
    }

    /// One balance bar. `ratio` is a/b (or "—" with no b); flagged when outside `band`;
    /// the flag names the lagging side and how many sets it trails by.
    static func balanceRow(key: String, aName: String, bName: String, a: Int, b: Int, band: ClosedRange<Double>) -> PWBalance {
        let total = a + b
        let share = total > 0 ? Double(a) / Double(total) : 0.5
        let diff = abs(a - b)
        guard total > 0 else {
            return PWBalance(key: key, ratio: "—", share: 0.5, a: "\(aName) 0", b: "\(bName) 0", flag: "NO DATA", flagged: false)
        }
        let ratioValue = b > 0 ? Double(a) / Double(b) : .infinity
        let ratioText = b > 0 ? String(format: "%.2f", Double(max(a, b)) / Double(max(1, min(a, b)))) : "—"
        let flagged = !band.contains(ratioValue)
        let lagging = a < b ? aName : bName
        return PWBalance(key: key, ratio: ratioText, share: share, a: "\(aName) \(a)", b: "\(bName) \(b)",
                         flag: flagged ? "▼ \(lagging) -\(diff) SETS" : "IN RANGE", flagged: flagged)
    }

    /// Weeks (oldest → newest, last = current partial week) whose load is a deload.
    static func detectDeloadWeeks(loads: [Double], flagged: [Bool], firstActive: Int) -> [Bool] {
        var out = [Bool](repeating: false, count: loads.count)
        for i in 0..<loads.count where i >= firstActive {
            if flagged[i] { out[i] = true; continue }
            guard i < loads.count - 1 else { continue }   // current week is still in progress
            let priors = loads[max(firstActive, i - 4)..<i]
            guard priors.count >= 2 else { continue }
            let avg = priors.reduce(0, +) / Double(priors.count)
            if avg > 0 && loads[i] < Band.deloadFraction * avg { out[i] = true }
        }
        return out
    }

    /// Lifts within 5% of their PR, smallest gap first (max 5); otherwise the 3 closest lifts.
    /// A lift with `e1rm == 0` has no set in the last 4 weeks: it can't qualify for the close list.
    static func selectPRLifts(_ lifts: [PWLift]) -> [PWLift] {
        func gap(_ l: PWLift) -> Double {
            let cur = l.e1rm > 0 ? l.e1rm : (l.series.last ?? 0)
            return l.pr > 0 ? (l.pr - cur) / l.pr : 1
        }
        let sorted = lifts.sorted { gap($0) < gap($1) }
        let close = sorted.filter { $0.e1rm > 0 && gap($0) <= Band.prGap }
        let pick = close.isEmpty ? Array(sorted.prefix(3)) : Array(close.prefix(5))
        return pick.map { l in var l = l; if l.e1rm == 0 { l.e1rm = l.series.last ?? 0 }; return l }
    }

    static let bigLifts: [(display: String, short: String)] = [
        ("Bench Press", "Bench"), ("Overhead Press", "OHP"), ("Barbell Row", "Row"), ("Squat", "Squat"), ("Deadlift", "Deadlift"),
    ]

    static func bigLift(_ rawName: String) -> (display: String, short: String)? {
        let n = rawName.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { n.contains($0) } }
        if n.contains("bench") && !has(["incline", "decline", "dumbbell", "close", "smith", "machine"]) { return bigLifts[0] }
        if has(["overhead press", "military press", "ohp"]) && !has(["dumbbell", "seated dumbbell", "tricep", "extension", "smith", "machine"]) { return bigLifts[1] }
        if n.contains("row") && has(["barbell", "bent", "pendlay"]) && !has(["upright", "dumbbell", "cable", "machine"]) { return bigLifts[2] }
        if n == "barbell row" { return bigLifts[2] }
        if n.contains("squat") && !has(["split", "goblet", "hack", "bulgarian", "overhead", "smith", "machine", "pistol", "jump"]) { return bigLifts[3] }
        if n.contains("deadlift") && !has(["romanian", "stiff", "single", "rdl", "trap bar"]) { return bigLifts[4] }
        return nil
    }

    /// Display group for a muscle (BACK folds lats / upper / lower back, CORE folds abs / obliques …).
    static func displayGroup(_ m: MuscleGroup) -> String? {
        switch m {
        case .chest: "CHEST"
        case .back, .lats, .upperBack, .lowerBack: "BACK"
        case .shoulders, .frontDelts, .sideDelts, .rearDelts: "SHOULDERS"
        case .biceps: "BICEPS"
        case .triceps: "TRICEPS"
        case .forearms: "FOREARMS"
        case .traps: "TRAPS"
        case .quads: "QUADS"
        case .hamstrings: "HAMSTRINGS"
        case .glutes: "GLUTES"
        case .calves: "CALVES"
        case .abs, .obliques: "CORE"
        default: nil
        }
    }

    /// true = push, false = pull, nil = neither (legs / core)
    static func pushPull(_ s: FSet) -> Bool? {
        if s.pattern == .push { return true }
        if s.pattern == .pull { return false }
        switch s.muscles.first {
        case .chest, .shoulders, .frontDelts, .sideDelts, .triceps: return true
        case .back, .lats, .upperBack, .rearDelts, .biceps, .traps: return false
        default: return nil
        }
    }

    static func isUpper(_ s: FSet) -> Bool? {
        if s.pattern == .squat || s.pattern == .hinge { return false }
        guard let m = s.muscles.first else { return nil }
        switch m.bodyRegion { case .upper, .arms: return true; case .lower: return false; case .core: return nil }
    }

    static func isAnterior(_ s: FSet) -> Bool? {
        switch s.muscles.first {
        case .chest, .frontDelts, .shoulders, .biceps, .abs, .obliques, .quads, .hipFlexors, .adductors: return true
        case .back, .lats, .upperBack, .lowerBack, .rearDelts, .traps, .triceps, .hamstrings, .glutes, .calves, .abductors: return false
        default: return nil
        }
    }

    /// Confidence 0-1 that the predicted template is right: how dominant the most common
    /// successor of the last session is across the last 14 sessions, damped when few samples.
    static func predictionConfidence(names: [String], hasSplit: Bool, predicted: Bool) -> Double {
        guard predicted else { return 0 }
        guard names.count >= 3, let last = names.first?.lowercased() else { return hasSplit ? 0.5 : 0.3 }
        var counts: [String: Int] = [:]
        for i in 1..<names.count where names[i].lowercased() == last { counts[names[i - 1].lowercased(), default: 0] += 1 }
        let total = counts.values.reduce(0, +)
        guard total > 0, let best = counts.values.max() else { return 0.4 }
        let conf = Double(best) / Double(total) * min(1, Double(total) / 3)
        return (max(0.2, min(0.95, conf)) * 100).rounded() / 100
    }

    /// Ordered day names of the program: split days (Mon→Sun) or, with none, the repeating cycle in history.
    static func programCycle(split: Split?, history: [String]) -> [String] {
        if let days = split?.days, !days.isEmpty {
            return days.sorted { (($0.dayOfWeek + 5) % 7) < (($1.dayOfWeek + 5) % 7) }.map { $0.label.isEmpty ? $0.workoutType : $0.label }
        }
        var seen: [String] = []
        for n in history.prefix(14) {   // newest first
            if seen.contains(where: { $0.lowercased() == n.lowercased() }) { break }
            seen.append(n)
        }
        return seen.reversed()
    }

    static func detectedSplitName(history: [String]) -> String {
        let r = history.prefix(9).map { $0.lowercased() }
        func any(_ s: String) -> Bool { r.contains { $0.contains(s) } }
        if any("push") && any("pull") && any("leg") { return "PUSH PULL LEGS" }
        if any("upper") && any("lower") { return "UPPER LOWER" }
        if any("full") { return "FULL BODY" }
        return "PROGRAM"
    }

    // MARK: Entitlement + friends (written outside the main rebuild, patched into the stored snapshot)

    static func currentIsPlus(defaults: UserDefaults?) -> Bool {
        (defaults?.bool(forKey: plusFlagKey) ?? false) || PulsePlusService().isInFreeTrial
    }

    /// Called whenever StoreKit entitlement is refreshed.
    static func setSubscribed(_ subscribed: Bool) {
        guard let defaults = UserDefaults(suiteName: PumpWidgetStore.appGroupId) else { return }
        guard defaults.bool(forKey: plusFlagKey) != subscribed || defaults.object(forKey: plusFlagKey) == nil else { return }
        defaults.set(subscribed, forKey: plusFlagKey)
        patchStoredSnapshot { $0.fixed.isPlus = subscribed || PulsePlusService().isInFreeTrial }
    }

    /// Stores the 3 most recent friend sessions for the widget (it can't reach Firebase).
    static func writeFriends(from items: [WorkoutFeedItem], myUid: String?, now: Date = Date()) {
        let sessions = friendSessions(from: items, myUid: myUid, now: now)
        guard let defaults = UserDefaults(suiteName: PumpWidgetStore.appGroupId),
              let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: friendsKey)
        patchStoredSnapshot { $0.fixed.friends = sessions }
    }

    static func friendSessions(from items: [WorkoutFeedItem], myUid: String?, now: Date = Date()) -> [PWFriendSession] {
        items.filter { $0.userId != myUid }.sorted { $0.date > $1.date }.prefix(3).map { item in
            let parts = item.username.split(whereSeparator: { " ._-".contains($0) }).map(String.init)
            let initials = parts.count >= 2
                ? String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
                : String(item.username.prefix(2)).uppercased()
            let display = parts.count >= 2
                ? "\(parts[0].capitalized) \(parts[1].prefix(1).uppercased())"
                : item.username.capitalized
            var meta: String
            if item.prCount > 0, let ex = item.exercises.max(by: { $0.improvementScore < $1.improvementScore }),
               let top = ex.sets.filter({ $0.setType != "warmup" }).max(by: { $0.weight < $1.weight }) {
                meta = "PR · \(ex.name.uppercased()) \(fmt(top.weight))×\(top.reps)"
            } else {
                let sets = item.exercises.flatMap(\.sets).filter { $0.setType != "warmup" }.count
                let mins = item.durationSeconds / 60
                meta = sets > 0 ? "\(sets) \(sets == 1 ? "SET" : "SETS") · \(mins) MIN" : "\(item.exerciseCount) EX · \(mins) MIN"
            }
            let secs = max(0, Int(now.timeIntervalSince(item.date)))
            let ago = secs < 3600 ? "\(max(1, secs / 60))M" : secs < 86400 ? "\(secs / 3600)H" : "\(secs / 86400)D"
            return PWFriendSession(initials: initials, name: display, workout: item.templateName ?? "Workout", meta: meta, ago: ago)
        }
    }

    private static func patchStoredSnapshot(_ edit: (inout PumpWidgetSnapshot) -> Void) {
        var snap = PumpWidgetStore.loadSnapshot()
        edit(&snap)
        PumpWidgetStore.saveSnapshot(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
