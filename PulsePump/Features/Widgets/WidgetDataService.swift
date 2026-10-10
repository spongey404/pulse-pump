import Foundation
import SwiftData
import WidgetKit

struct WidgetDataService {
    private static let appGroupId = "group.com.pulse.PulsePump"

    static func updateWidgetData(modelContext: ModelContext, now: Date = Date()) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let workouts = try? modelContext.fetch(descriptor) else { return }

        // Streak
        let streak = StreakCalculator.currentStreak(from: workouts.map(\.date), now: now)
        defaults.set(streak, forKey: "widget_streak")

        // Last workout
        if let last = workouts.first {
            defaults.set(last.template?.name ?? "Workout", forKey: "widget_lastWorkoutName")
            defaults.set(last.date, forKey: "widget_lastWorkoutDate")
            defaults.set(last.exerciseLogs.count, forKey: "widget_exerciseCount")
            defaults.set(Int(last.duration / 60), forKey: "widget_durationMinutes")
        }

        // Recent workouts
        let recent = workouts.prefix(3).map {
            WidgetWorkoutDTO(name: $0.template?.name, date: $0.date, exercises: $0.exerciseLogs.count)
        }
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: "widget_recentWorkouts")
        }

        // Snapshot for custom widgets (PumpShared / Widget Builder)
        PumpWidgetStore.saveSnapshot(buildSnapshot(workouts: workouts, modelContext: modelContext, now: now))

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Custom-widget snapshot

    private static func workingSets(_ w: Workout) -> [(name: String, set: SetLog, log: ExerciseLog)] {
        w.exerciseLogs.flatMap { log in
            log.sets.filter { $0.setType != .warmup }.compactMap { s in
                log.exercise.map { (name: $0.name, set: s, log: log) }
            }
        }
    }

    /// Best working weight per exercise name in a workout.
    private static func topWeights(_ w: Workout) -> [String: Double] {
        var out: [String: Double] = [:]
        for (name, set, _) in workingSets(w) { out[name] = max(out[name] ?? 0, set.weight) }
        return out
    }

    /// (improved, compared, biggest gain) for `w` against the previous session of each lift.
    private static func improvements(_ w: Workout, history: [Workout]) -> (improved: Int, total: Int, gain: Double, gainName: String) {
        let prior = history.filter { $0.date < w.date }   // newest first
        var improved = 0, total = 0, gain = 0.0, gainName = ""
        for (name, top) in topWeights(w) {
            guard let prev = prior.lazy.compactMap({ topWeights($0)[name] }).first else { continue }
            total += 1
            if top > prev + 0.01 { improved += 1 }
            if top - prev > gain { gain = top - prev; gainName = name }
        }
        return (improved, total, gain, gainName)
    }

    static func buildSnapshot(workouts: [Workout], modelContext: ModelContext, now: Date = Date(),
                              fixedDefaults: UserDefaults? = UserDefaults(suiteName: appGroupId),
                              calendar: Calendar = Calendar(identifier: .iso8601)) -> PumpWidgetSnapshot {
        var snap = PumpWidgetSnapshot()
        snap.hasData = !workouts.isEmpty
        snap.updated = now
        let cal = calendar

        snap.streak = StreakCalculator.currentStreak(from: workouts.map(\.date), now: now)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let weekWorkouts = workouts.filter { $0.date >= weekStart }
        snap.sessionsThisWeek = weekWorkouts.count
        snap.weekNumber = cal.component(.weekOfYear, from: now)
        snap.todayIndex = ((cal.component(.weekday, from: now) + 5) % 7)

        let user = (try? modelContext.fetch(FetchDescriptor<User>()))?.first
        snap.weightUnit = user?.unitPreference ?? UnitPreference.current   // widgets convert + label from this
        snap.bodyweight = user?.weight ?? 0   // kg
        let goal = user?.selectedSplit?.days.count ?? 0
        snap.sessionGoal = goal > 0 ? goal : 5

        // This week, per day
        for w in weekWorkouts {
            let i = ((cal.component(.weekday, from: w.date) + 5) % 7)
            let sets = workingSets(w)
            snap.setsPerDay[i] += Double(sets.count)
            snap.volumePerDay[i] += sets.reduce(0) { $0 + $1.set.weight * Double($1.set.reps) } / 1000
            snap.improvedPerDay[i] += Double(improvements(w, history: workouts).improved)
        }

        // Last session
        if let last = workouts.first {
            let imp = improvements(last, history: workouts)
            snap.improvedCount = imp.improved
            snap.improvedTotal = imp.total
            snap.topGainKg = imp.gain
            snap.topGainExercise = imp.gainName
        }

        // PRs + e1RM series (Epley, weekly best over 12 weeks)
        var e1rmWeeks: [String: [Int: Double]] = [:]
        for w in workouts {
            let weeksAgo = cal.dateComponents([.weekOfYear], from: w.date, to: now).weekOfYear ?? 0
            for (name, set, _) in workingSets(w) where set.weight > 0 {
                if set.weight > (snap.prs[name]?.weight ?? 0) { snap.prs[name] = .init(weight: set.weight, date: w.date) }
                guard weeksAgo < 12 else { continue }
                let est = set.weight * (1 + Double(set.reps) / 30)
                let key = name.lowercased().contains("bench") && !name.lowercased().contains("incline") ? "Bench Press"
                        : (name.lowercased().contains("squat") && !name.lowercased().contains("split")) ? "Squat" : nil
                if let key { e1rmWeeks[key, default: [:]][weeksAgo] = max(e1rmWeeks[key]?[weeksAgo] ?? 0, est) }
            }
        }
        for (key, weeks) in e1rmWeeks {
            var series: [Double] = []
            var carry: Double?
            for ago in stride(from: 11, through: 0, by: -1) {
                if let v = weeks[ago] { carry = v }
                if let carry { series.append((carry * 10).rounded() / 10) }
            }
            if series.count > 1 { snap.e1rm[key] = series }
        }

        // Body map (volume 7d vs target; recency over 48h) onto BodyHeat's nine regions
        let region: [MuscleGroup: String] = [
            .chest: "chest", .traps: "traps", .shoulders: "shoulders", .frontDelts: "shoulders", .sideDelts: "shoulders",
            .biceps: "biceps", .forearms: "forearms", .abs: "core", .obliques: "core",
            .glutes: "glutes", .quads: "quads", .calves: "calves",
        ]
        let regionTarget: [String: Double] = ["chest": 16, "traps": 8, "shoulders": 26, "biceps": 10, "forearms": 6, "core": 14, "glutes": 12, "quads": 20, "calves": 8]
        var sets7: [String: Double] = [:]
        var lastHit: [String: Date] = [:]
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        for w in workouts {
            for log in w.exerciseLogs {
                guard let ex = log.exercise else { continue }
                for m in ex.primaryMuscleGroups {
                    guard let r = region[m] else { continue }
                    if w.date >= weekAgo { sets7[r, default: 0] += Double(log.workingSets.count) }
                    if lastHit[r] == nil || w.date > lastHit[r]! { lastHit[r] = w.date }
                }
            }
        }
        for (r, target) in regionTarget {
            if let v = sets7[r], v > 0 { snap.bodyVolume[r] = min(1, v / target) }
            if let d = lastHit[r] {
                let fade = max(0, 1 - now.timeIntervalSince(d) / (48 * 3600))
                if fade > 0 { snap.bodyRecency[r] = fade }
            }
        }

        // Next workout (prediction) + quick-start templates
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        snap.templates = templates.map { .init(name: $0.name, exercises: $0.templateExercises.count) }
        let predictor = WorkoutViewModel()
        predictor.now = { now }
        if let user, let name = predictor.predictNextWorkout(user: user, modelContext: modelContext) {
            snap.nextName = name
            let df = DateFormatter(); df.dateFormat = "EEE"; df.timeZone = cal.timeZone
            snap.nextDay = df.string(from: now).uppercased()
            if let t = templates.first(where: { $0.name == name }) {
                snap.nextExercises = t.templateExercises.count
                let sets = t.templateExercises.reduce(0) { $0 + $1.targetSets }
                snap.nextEstMinutes = max(10, sets * 3)
                if let first = t.templateExercises.sorted(by: { $0.order < $1.order }).first {
                    let reps = first.targetReps.map { "×\($0)" } ?? ""
                    snap.nextFirst = "\(first.exerciseName) \(first.targetSets)\(reps)"
                }
            }
        }
        snap.fixed = buildFixed(workouts: workouts, modelContext: modelContext, user: user, snap: snap, now: now, defaults: fixedDefaults, calendar: cal)
        return snap
    }
}

// DTO for encoding to UserDefaults (shared with widget via same key)
struct WidgetWorkoutDTO: Codable {
    let name: String?
    let date: Date
    let exercises: Int
}
