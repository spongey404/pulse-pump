#if DEBUG
import Foundation
import SwiftData
import WidgetKit

/// Builds the local dev dataset. DEBUG-only (the whole directory compiles out of Release).
///
/// Run it by launching the app with `-createDevData 1` (see `DevDataConfig` for every option) or via
/// `bin/createdevdata.sh`. It's idempotent: unless `-devDataReset 1` is passed it does nothing when a
/// user already exists, so a normal launch never clobbers what you were testing.
@MainActor
enum DevDataService {
    struct Summary: Equatable {
        var workouts = 0, sets = 0, prs = 0, templates = 0, bodyweightDays = 0
        var skipped = false
    }

    // Everything the app keeps outside SwiftData that dev data must be able to reset.
    private static let defaultsKeys = [
        "wantsTutorial", "tutorialCompleted", "debugStartTab", "debugMoreScreen",
    ]
    private static let appGroupKeys = [
        "widget_snapshot", "custom_widget_library", BodyweightLog.key, "widget_friends",
        "widget_streak", "widget_lastWorkoutName", "widget_lastWorkoutDate", "widget_exerciseCount",
        "widget_durationMinutes", "widget_recentWorkouts",
    ]

    /// Entry point for the app: runs when the launch arguments ask for it.
    @discardableResult
    static func runIfRequested(modelContext: ModelContext) -> Summary? {
        guard let config = DevDataConfig.fromLaunchArguments() else { return nil }
        return run(config, modelContext: modelContext)
    }

    @discardableResult
    static func run(_ config: DevDataConfig, modelContext ctx: ModelContext) -> Summary {
        let existingUsers = (try? ctx.fetchCount(FetchDescriptor<User>())) ?? 0
        if existingUsers > 0 && !config.reset {
            log("a user already exists — skipping (pass -devDataReset 1 to rebuild)")
            return Summary(skipped: true)
        }
        if config.reset { reset(ctx) }

        // Flags the rest of the app reads (DevFlags) + skip onboarding extras.
        let d = UserDefaults.standard
        d.set(config.plus, forKey: "devDataPlus")
        d.set(config.socialFixtures, forKey: "devDataSocialFixtures")
        d.set(true, forKey: "tutorialCompleted")
        d.set(false, forKey: "wantsTutorial")

        func catalogue() -> [String: Exercise] {
            Dictionary(((try? ctx.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isApproved }))) ?? []).map { ($0.name, $0) },
                       uniquingKeysWith: { a, _ in a })
        }
        ExerciseSeedService.seedIfNeeded(modelContext: ctx)
        var exercises = catalogue()
        if exercises.isEmpty {
            // ExerciseSeedService trusts a UserDefaults version flag, not the store — if the store was
            // wiped (or is a fresh in-memory test store) the flag lies. Force a reseed.
            UserDefaults.standard.removeObject(forKey: "exerciseSeedVersion")
            ExerciseSeedService.seedIfNeeded(modelContext: ctx)
            exercises = catalogue()
        }

        var rng = SeededRandom(seed: config.seed)
        var summary = Summary()
        let cal = config.calendar

        // Profile, split, equipment.
        let user = DevDataFactory.user(units: config.units)
        ctx.insert(user)
        let split = DevDataFactory.split()
        ctx.insert(split)
        user.selectedSplit = split
        for p in DevDataFactory.equipmentProfiles() { p.user = user; ctx.insert(p) }

        // Templates.
        var templates: [DevDay: WorkoutTemplate] = [:]
        for day in DevDay.allCases {
            let t = DevDataFactory.template(day, exercises: exercises)
            ctx.insert(t); templates[day] = t
        }
        summary.templates = templates.count

        // Bodyweight log (App Group) — a gentle cut with noise.
        let days = 60
        for i in stride(from: days, through: 0, by: -1) {
            let date = cal.date(byAdding: .day, value: -i, to: config.now) ?? config.now
            let kg = 84.2 - (84.2 - 82.4) * Double(days - i) / Double(days) + rng.jitter(0.3)
            BodyweightLog.record(kg: (kg * 10).rounded() / 10, on: date, calendar: cal)
            summary.bodyweightDays += 1
        }
        user.weight = 82.4

        // Workout history.
        if config.scenario != .newUser {
            let today = cal.startOfDay(for: config.now)
            let totalDays = config.weeks * 7
            let lapsedCutoff = cal.date(byAdding: .day, value: -12, to: today)
            let deloadWeek = config.weeks >= 8 ? config.weeks - 5 : nil   // ~4 weeks ago
            for back in stride(from: totalDays - 1, through: 0, by: -1) {
                guard let day = cal.date(byAdding: .day, value: -back, to: today),
                      let kind = DevDay.schedule[cal.component(.weekday, from: day)] else { continue }
                if config.scenario == .lapsed, let cutoff = lapsedCutoff, day > cutoff { continue }
                // Seeded skips — but never in the last 7 days, so the streak/week views stay predictable.
                if back >= 7, rng.chance(0.10) { continue }
                let week = (totalDays - 1 - back) / 7
                // Evenings, except today (so a session "today" is never in the future).
                let hour = back == 0 ? 7 : rng.int(17...19)
                let date = cal.date(bySettingHour: hour, minute: rng.int(0...55), second: 0, of: day) ?? day
                if date > config.now { continue }
                let w = DevDataFactory.workout(day: kind, date: date, week: week, deloadWeek: deloadWeek,
                                               template: templates[kind], exercises: exercises, user: user,
                                               bodyKg: 82.4, rng: &rng, context: ctx)
                summary.workouts += 1
                summary.sets += w.exerciseLogs.reduce(0) { $0 + $1.sets.count }
            }
        }
        if config.draft {
            _ = DevDataFactory.draftWorkout(now: config.now, template: templates[.push], exercises: exercises, user: user, context: ctx)
        }

        try? ctx.save()
        summary.prs = countPRs(ctx)

        WidgetDataService.updateWidgetData(modelContext: ctx)
        WidgetCenter.shared.reloadAllTimelines()
        log("created \(summary.workouts) workouts, \(summary.sets) sets (\(summary.prs) PR-setting lifts), "
            + "\(summary.templates) templates, \(summary.bodyweightDays) bodyweight days — scenario \(config.scenario.rawValue), seed \(config.seed)")
        return summary
    }

    // MARK: Reset

    /// Deletes everything the user created, plus app-group / defaults state tied to it. The exercise
    /// catalogue stays (seeded again if missing).
    static func reset(_ ctx: ModelContext) {
        // Delete fetched objects one by one (not batch `delete(model:)`): batch deletes leave stale,
        // invalidated instances in the context that crash on the next property access.
        func wipe<T: PersistentModel>(_ type: T.Type) {
            for obj in (try? ctx.fetch(FetchDescriptor<T>())) ?? [] { ctx.delete(obj) }
        }
        wipe(Workout.self)            // cascades to ExerciseLog → SetLog
        wipe(User.self)
        wipe(WorkoutTemplate.self)
        wipe(EquipmentProfile.self)
        wipe(Split.self)
        wipe(Challenge.self)
        wipe(UserProfile.self)
        for e in (try? ctx.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))) ?? [] { ctx.delete(e) }
        try? ctx.save()
        for k in defaultsKeys { UserDefaults.standard.removeObject(forKey: k) }
        if let g = PumpWidgetStore.defaults { for k in appGroupKeys { g.removeObject(forKey: k) } }
        log("reset: user data cleared")
    }

    // MARK: Helpers

    /// Exercises whose best weight was set in the most recent 7 days (what the Home PRS tile counts).
    private static func countPRs(_ ctx: ModelContext) -> Int {
        let workouts = (try? ctx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft }, sortBy: [SortDescriptor(\.date)]))) ?? []
        var best: [String: Double] = [:], prs = 0
        for w in workouts {
            var wBest: [String: Double] = [:]
            for l in w.exerciseLogs {
                guard let n = l.exercise?.name else { continue }
                for s in l.sets where s.setType != .warmup { wBest[n] = max(wBest[n] ?? 0, s.weight) }
            }
            for (n, v) in wBest { if v > (best[n] ?? 0) { if best[n] != nil { prs += 1 }; best[n] = v } }
        }
        return prs
    }

    private static func log(_ s: String) { NSLog("[DevData] %@", s) }
}
#endif
