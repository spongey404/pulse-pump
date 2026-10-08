import Testing
import Foundation
import SwiftData
@testable import PulsePump

@MainActor
struct WidgetFixedDataTests {
    // Fri 9 Oct 2026, 12:00 — an ISO week Mon 5 Oct … Sun 11 Oct.
    static let cal = Calendar(identifier: .iso8601)
    static let now: Date = cal.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12))!

    static func day(_ offset: Int, hour: Int = 9) -> Date {
        let d = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
        return cal.date(byAdding: .hour, value: hour, to: d)!
    }

    static func container() throws -> ModelContainer {
        let schema = Schema([User.self, Exercise.self, WorkoutTemplate.self, Workout.self, ExerciseLog.self,
                             SetLog.self, Split.self, EquipmentProfile.self, UserProfile.self, Challenge.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    static func suite() -> UserDefaults {
        let name = "widget-fixed-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @discardableResult
    static func addWorkout(_ ctx: ModelContext, daysAgo: Int, exercise: Exercise, sets: [(Double, Int)],
                           rir: Int? = nil, duration: TimeInterval = 3600, deload: Bool = false) -> Workout {
        let w = Workout(date: day(-daysAgo), duration: duration, isDraft: false, isDeload: deload)
        let log = ExerciseLog(order: 0)
        log.exercise = exercise
        w.exerciseLogs.append(log)
        for (i, s) in sets.enumerated() {
            let set = SetLog(order: i, weight: s.0, reps: s.1, rir: rir)
            log.sets.append(set)
        }
        ctx.insert(w)
        return w
    }

    static func exercise(_ ctx: ModelContext, _ name: String, _ m: MuscleGroup, _ p: MovementPattern) -> Exercise {
        let e = Exercise(name: name, primaryMuscleGroups: [m], equipmentType: .barbell, movementPattern: p)
        ctx.insert(e)
        return e
    }

    // MARK: weekly sets

    @Test func weeklySetsCompareUpToSameWeekday() throws {
        let c = try Self.container(); let ctx = ModelContext(c)
        let bench = Self.exercise(ctx, "Barbell Bench Press", .chest, .push)
        // This week (Mon 5 … Fri 9): 3 + 2 sets.
        Self.addWorkout(ctx, daysAgo: 4, exercise: bench, sets: [(80, 5), (80, 5), (80, 5)])
        Self.addWorkout(ctx, daysAgo: 0, exercise: bench, sets: [(80, 5), (80, 5)])
        // Last week: Mon 28 Sep (4 sets) and Sat 3 Oct (6 sets) — only Monday falls on/before a Friday.
        Self.addWorkout(ctx, daysAgo: 11, exercise: bench, sets: [(70, 5), (70, 5), (70, 5), (70, 5)])
        Self.addWorkout(ctx, daysAgo: 6, exercise: bench, sets: Array(repeating: (70, 5), count: 6))
        let all = try ctx.fetch(FetchDescriptor<Workout>())
        let f = WidgetDataService.buildFixed(workouts: all, modelContext: ctx, user: nil, snap: PumpWidgetSnapshot(), now: Self.now, defaults: Self.suite())
        #expect(f.setsThisWeek == 5)
        #expect(f.setsLastWeekSameDay == 4)
        #expect(f.todayIndex == 4)
        #expect(f.weekdayShort == "FRI")
        #expect(f.weekDone == [true, false, false, false, true, false, false])
        #expect(f.volDays[0].lastWeek == 4 && f.volDays[5].lastWeek == 6)
        #expect(f.volumeTonnes == 2.0)   // 5 sets x 80 x 5
    }

    @Test func warmupsAreSkipped() throws {
        let c = try Self.container(); let ctx = ModelContext(c)
        let bench = Self.exercise(ctx, "Barbell Bench Press", .chest, .push)
        let w = Self.addWorkout(ctx, daysAgo: 0, exercise: bench, sets: [(40, 10), (80, 5)])
        w.exerciseLogs[0].sets[0].setType = .warmup
        let f = WidgetDataService.buildFixed(workouts: [w], modelContext: ctx, user: nil, snap: PumpWidgetSnapshot(), now: Self.now, defaults: Self.suite())
        #expect(f.setsThisWeek == 1)
    }

    // MARK: balances

    @Test func balanceRatioAndFlagText() {
        let b = WidgetDataService.balanceRow(key: "PUSH : PULL", aName: "PUSH", bName: "PULL", a: 48, b: 34, band: WidgetDataService.Band.pushPull)
        #expect(b.ratio == "1.41")
        #expect(b.flag == "▼ PULL -14 SETS")
        #expect(b.flagged)
        #expect(abs(b.share - 0.585) < 0.001)
        #expect(b.a == "PUSH 48" && b.b == "PULL 34")

        let ok = WidgetDataService.balanceRow(key: "ANT : POST", aName: "ANT", bName: "POST", a: 61, b: 51, band: WidgetDataService.Band.antPost)
        #expect(ok.ratio == "1.20")
        #expect(ok.flag == "IN RANGE" && !ok.flagged)

        let ul = WidgetDataService.balanceRow(key: "UPPER : LOWER", aName: "UPPER", bName: "LOWER", a: 82, b: 30, band: WidgetDataService.Band.upperLower)
        #expect(ul.ratio == "2.73" && ul.flag == "▼ LOWER -52 SETS")

        // Lagging side is named when A trails
        let rev = WidgetDataService.balanceRow(key: "PUSH : PULL", aName: "PUSH", bName: "PULL", a: 20, b: 40, band: WidgetDataService.Band.pushPull)
        #expect(rev.flag == "▼ PUSH -20 SETS")
    }

    @Test func balancesFromHistory() throws {
        let c = try Self.container(); let ctx = ModelContext(c)
        let bench = Self.exercise(ctx, "Barbell Bench Press", .chest, .push)
        let row = Self.exercise(ctx, "Barbell Row", .back, .pull)
        Self.addWorkout(ctx, daysAgo: 2, exercise: bench, sets: Array(repeating: (80, 5), count: 6))
        Self.addWorkout(ctx, daysAgo: 1, exercise: row, sets: Array(repeating: (70, 5), count: 3))
        Self.addWorkout(ctx, daysAgo: 40, exercise: row, sets: Array(repeating: (70, 5), count: 30)) // outside 4 weeks
        let all = try ctx.fetch(FetchDescriptor<Workout>())
        let f = WidgetDataService.buildFixed(workouts: all, modelContext: ctx, user: nil, snap: PumpWidgetSnapshot(), now: Self.now, defaults: Self.suite())
        #expect(f.balances[0].a == "PUSH 6" && f.balances[0].b == "PULL 3")
        #expect(f.balances[0].flag == "▼ PULL -3 SETS")
    }

    // MARK: deload

    @Test func deloadWeekDetection() {
        // 12 weeks, current = last. Week index 8 drops to 40 after ~75 average.
        let loads: [Double] = [0, 0, 60, 70, 78, 74, 80, 82, 40, 74, 88, 50]
        let flags = [Bool](repeating: false, count: 12)
        let d = WidgetDataService.detectDeloadWeeks(loads: loads, flagged: flags, firstActive: 2)
        #expect(d[8])
        #expect(!d[9] && !d[10])
        #expect(!d[11])               // current week is partial: never auto-flagged
        #expect(!d[0] && !d[1])       // before first activity
        // Explicit flag wins even when load is normal.
        var f2 = flags; f2[6] = true
        #expect(WidgetDataService.detectDeloadWeeks(loads: loads, flagged: f2, firstActive: 2)[6])
    }

    @Test func deloadFieldsFromWorkouts() throws {
        let c = try Self.container(); let ctx = ModelContext(c)
        let squat = Self.exercise(ctx, "Back Squat", .quads, .squat)
        // Four normal weeks (1–4 weeks ago), then a light week 2 weeks ago, then normal last week.
        for w in [5, 4, 3, 1] { Self.addWorkout(ctx, daysAgo: w * 7, exercise: squat, sets: Array(repeating: (100, 5), count: 10)) }
        Self.addWorkout(ctx, daysAgo: 2 * 7, exercise: squat, sets: Array(repeating: (60, 5), count: 3))
        let all = try ctx.fetch(FetchDescriptor<Workout>())
        let f = WidgetDataService.buildFixed(workouts: all, modelContext: ctx, user: nil, snap: PumpWidgetSnapshot(), now: Self.now, defaults: Self.suite())
        #expect(f.loadWeeks.count == 9)
        #expect(f.loadWeeks.last?.next == true)
        #expect(f.loadWeeks[f.loadWeeks.count - 2].current)
        // weeks ago 2 is index 8-... current at count-2, so 2 weeks ago is count-4
        #expect(f.loadWeeks[f.loadWeeks.count - 4].deload)
        #expect(f.lastDeloadWeek != "—")
    }

    // MARK: PR watch

    @Test func prWatchSortsByGapAndFilters() {
        func lift(_ n: String, _ e: Double, _ pr: Double) -> PWLift { PWLift(name: n, short: n, e1rm: e, pr: pr, series: [Double](repeating: e, count: 12)) }
        let picked = WidgetDataService.selectPRLifts([
            lift("Squat", 131, 135),     // 3.0%
            lift("Bench", 98.5, 100),    // 1.5%
            lift("Deadlift", 150, 170),  // 11.8% -> out
            lift("Row", 92, 95),         // 3.2%
        ])
        #expect(picked.map(\.name) == ["Bench", "Squat", "Row"])

        // Nothing within 5% -> the 3 closest
        let fallback = WidgetDataService.selectPRLifts([lift("A", 80, 100), lift("B", 70, 100), lift("C", 90, 100), lift("D", 60, 100)])
        #expect(fallback.map(\.name) == ["C", "A", "B"])
    }

    @Test func bigLiftNameMatching() {
        #expect(WidgetDataService.bigLift("Barbell Bench Press")?.short == "Bench")
        #expect(WidgetDataService.bigLift("Incline Barbell Bench Press") == nil)
        #expect(WidgetDataService.bigLift("Barbell Row")?.short == "Row")
        #expect(WidgetDataService.bigLift("Dumbbell Row") == nil)
        #expect(WidgetDataService.bigLift("Overhead Press")?.short == "OHP")
        #expect(WidgetDataService.bigLift("Romanian Deadlift") == nil)
        #expect(WidgetDataService.bigLift("Back Squat")?.short == "Squat")
    }

    @Test func prLiftsFromHistory() throws {
        let c = try Self.container(); let ctx = ModelContext(c)
        let bench = Self.exercise(ctx, "Barbell Bench Press", .chest, .push)
        Self.addWorkout(ctx, daysAgo: 60, exercise: bench, sets: [(100, 1)])
        Self.addWorkout(ctx, daysAgo: 3, exercise: bench, sets: [(90, 5)])   // e1RM 105
        let all = try ctx.fetch(FetchDescriptor<Workout>())
        let f = WidgetDataService.buildFixed(workouts: all, modelContext: ctx, user: nil, snap: PumpWidgetSnapshot(), now: Self.now, defaults: Self.suite())
        #expect(f.prLifts.count == 1)
        #expect(f.prLifts[0].pr == 100)
        #expect(f.prLifts[0].e1rm == 105)
        #expect(f.prLifts[0].series.count == 12)
    }

    // MARK: bodyweight

    @Test func bodyweightSeriesAndDelta() {
        let d = Self.suite()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Self.now)
        func at(_ off: Int) -> Date { cal.date(byAdding: .day, value: off, to: today)! }
        BodyweightLog.record(kg: 83.0, on: at(-20), calendar: cal, defaults: d)
        BodyweightLog.record(kg: 82.8, on: at(-7), calendar: cal, defaults: d)
        BodyweightLog.record(kg: 82.2, on: at(0), calendar: cal, defaults: d)
        BodyweightLog.record(kg: 82.4, on: at(0), calendar: cal, defaults: d)   // same day: last write wins
        let s = BodyweightLog.summary(now: Self.now, calendar: cal, defaults: d)
        #expect(s.series.count == 21)          // from the first entry (20 days ago) through today
        #expect(s.series.last == 82.4)
        #expect(s.series.first == 83.0)
        #expect(s.delta7d == -0.4)             // 82.4 vs 82.8 seven days earlier
        #expect(BodyweightLog.load(defaults: d).count == 3)
        #expect(s.start == "19 SEP")
    }

    @Test func bodyweightEmpty() {
        let s = BodyweightLog.summary(now: Self.now, defaults: Self.suite())
        #expect(s.series.isEmpty && s.delta7d == 0 && s.start == "")
    }

    // MARK: friends

    @Test func friendSessionsFormatting() {
        let now = Self.now
        func item(_ user: String, _ ago: TimeInterval, pr: Int = 0, uid: String = "u2") -> WorkoutFeedItem {
            let ex = FeedExercise(id: "e", name: "Deadlift", sets: [FeedSetLog(weight: 140, reps: 3, duration: 0, distance: 0, setType: "standard", side: nil),
                                                                    FeedSetLog(weight: 60, reps: 5, duration: 0, distance: 0, setType: "warmup", side: nil)])
            return WorkoutFeedItem(userId: uid, username: user, templateName: "Pull Day", exerciseCount: 1, durationSeconds: 55 * 60,
                                   caloriesBurned: 0, musclesWorked: [], prCount: pr, date: now.addingTimeInterval(-ago), exercises: [ex])
        }
        let out = WidgetDataService.friendSessions(from: [item("maya.k", 3600), item("riya s", 86400 * 1.2, pr: 1), item("me", 10, uid: "me")], myUid: "me", now: now)
        #expect(out.count == 2)
        #expect(out[0].initials == "MK" && out[0].name == "Maya K" && out[0].ago == "1H" && out[0].meta == "1 SET · 55 MIN")
        #expect(out[1].meta == "PR · DEADLIFT 140×3" && out[1].ago == "1D")
    }
}
