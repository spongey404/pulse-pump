import Testing
import Foundation
import SwiftData
@testable import PulsePump

// MARK: - Journey tests: shared harness
//
// A "journey" drives the SAME code the screens use (WorkoutViewModel, SwiftData models, the pure stats
// types behind each screen, the widget snapshot builder, the predictor, the post builder) against an
// in-memory store and a clock the test moves. Assertions are concrete numbers the test computes itself,
// from `UserSim.ledger` (an independent record of every set the simulated person typed), never by calling
// the function under test a second time.
//
// To add a scenario: build a `UserSim`, call `startSession` / `log` / `finish` / `skipToDay`, then read what the
// user would see through the screen accessors (`home()`, `body()`, `recap()`, `progress(of:)`, `historyRows()`,
// `widget()`, `prediction()`) and compare with numbers derived from `sim.ledger`.

struct JourneyError: Error { let message: String }

enum WeekStart { case monday, sunday }

extension Calendar {
    /// A fixed Gregorian calendar for journeys. `.monday` = ISO-style (ISO / most of the world),
    /// `.sunday` = US-style locale (first weekday Sunday, week 1 contains 1 Jan).
    static func journey(_ start: WeekStart = .monday, timeZone: String = "UTC") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: timeZone)!
        c.firstWeekday = start == .monday ? 2 : 1
        c.minimumDaysInFirstWeek = start == .monday ? 4 : 1
        return c
    }
}

/// One set the simulated person logged, recorded by the harness independently of SwiftData.
struct LoggedSet: Equatable {
    var session: Int            // 0-based index of the finished session
    var day: Date               // start of the day the session started
    var exercise: String
    var kg: Double              // what ends up stored (kg)
    var reps: Int
    var type: SetType
    var isWorking: Bool { type != .warmup }
}

enum SplitKind {
    case ppl, upperLower, broSplit, fullBody, arnold, torsoLimbs, custom, none

    var type: SplitType {
        switch self {
        case .ppl: .ppl
        case .upperLower: .upperLower
        case .broSplit: .broSplit
        case .fullBody: .fullBody
        case .arnold: .arnoldSplit
        case .torsoLimbs: .torsoLimbs
        case .custom: .custom
        case .none: .none
        }
    }

    /// (weekday 1=Sun…7=Sat, label)
    var schedule: [(Int, String)] {
        switch self {
        case .ppl: [(2, "Push Day"), (3, "Pull Day"), (4, "Leg Day"), (5, "Push Day"), (6, "Pull Day"), (7, "Leg Day")]
        case .upperLower: [(2, "Upper Body"), (3, "Lower Body"), (5, "Upper Body"), (6, "Lower Body")]
        case .broSplit: [(2, "Chest"), (3, "Back"), (4, "Shoulders"), (5, "Arms"), (6, "Legs")]
        case .fullBody: [(2, "Full Body A"), (4, "Full Body B"), (6, "Full Body A")]
        case .arnold: [(2, "Chest & Back"), (3, "Shoulders & Arms"), (4, "Legs"), (5, "Chest & Back"), (6, "Shoulders & Arms"), (7, "Legs")]
        case .torsoLimbs: [(2, "Torso"), (3, "Limbs"), (5, "Torso"), (6, "Limbs")]
        case .custom: [(2, "Alpha"), (4, "Beta"), (6, "Gamma")]
        case .none: []
        }
    }

    func make() -> Split {
        Split(type: type, days: schedule.map { SplitDay(dayOfWeek: $0.0, label: $0.1, workoutType: $0.1) })
    }
}

@MainActor
final class UserSim {
    let container: ModelContainer
    let ctx: ModelContext
    let user: User
    let calendar: Calendar
    /// Midnight of day 0.
    let origin: Date
    private(set) var now: Date
    private(set) var vm: WorkoutViewModel
    let restNotifier: FakeRestNotifier
    let restMode: RestTimerMode
    /// Private defaults standing in for the shared App Group (widget builder + bodyweight log); never the real one.
    let widgetDefaults: UserDefaults
    var catalogue: [String: Exercise] = [:]

    // What the harness saw happen.
    private(set) var ledger: [LoggedSet] = []
    private(set) var completions: [WorkoutCompletionData] = []
    private(set) var finished: [Workout] = []
    private(set) var widgetSnapshots: [PumpWidgetSnapshot] = []
    private(set) var sessionCount = 0

    static func suite() -> UserDefaults {
        let name = "journey-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private init(ctx: ModelContext, container: ModelContainer, calendar: Calendar, now: Date, origin: Date? = nil, user: User,
                 restMode: RestTimerMode, defaults: UserDefaults) {
        let notifier = FakeRestNotifier()
        self.restNotifier = notifier
        self.restMode = restMode
        self.container = container
        self.ctx = ctx
        self.calendar = calendar
        self.now = now
        self.origin = origin ?? calendar.startOfDay(for: now)
        self.user = user
        self.widgetDefaults = defaults
        self.vm = WorkoutViewModel(restTimer: Self.manualRestTimer(notifier, mode: restMode))
        self.catalogue = Dictionary(((try? ctx.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        wire(vm)
    }

    /// Defaults: Monday 5 Jan 2026, 18:00 UTC, a kg user on a 6-day PPL split with the seeded catalogue and preset templates.
    /// Pass `context` to build the world inside an existing store (a sync device); `defaults` is the bodyweight/widget store.
    convenience init(unit: UnitPreference = .kg, week: WeekStart = .monday, timeZone: String = "UTC",
                     start: DateComponents = DateComponents(year: 2026, month: 1, day: 5, hour: 18),
                     split: SplitKind = .ppl, bodyweightKg: Double = 80, presets: Bool = true,
                     restMode: RestTimerMode = .manual, context: ModelContext? = nil, defaults: UserDefaults? = nil) throws {
        let cal = Calendar.journey(week, timeZone: timeZone)
        let container = try context?.container ?? WidgetFixedDataTests.container()
        let ctx = context ?? ModelContext(container)
        let startDate = cal.date(from: start)!

        for e in ExerciseSeedService.allExercises { ctx.insert(e) }
        if presets { TemplateSeedService.seedIfNeeded(modelContext: ctx) }

        let u = User(name: "Journey", username: "journey", weight: bodyweightKg, height: 180, age: 30,
                     gender: .male, unitPreference: unit, experienceLevel: .intermediate)
        u.createdAt = startDate
        ctx.insert(u)
        let s = split == .none ? Split(type: .none) : split.make()
        ctx.insert(s)
        u.selectedSplit = s
        try? ctx.save()
        self.init(ctx: ctx, container: container, calendar: cal, now: startDate, user: u, restMode: restMode,
                  defaults: defaults ?? Self.suite())
    }

    /// A phone that already holds a user's data (restored from the cloud): read the screens, keep training.
    convenience init(adopting ctx: ModelContext, week: WeekStart = .monday, timeZone: String = "UTC", now: Date,
                     origin: Date? = nil, defaults: UserDefaults? = nil) throws {
        guard let user = try ctx.fetch(FetchDescriptor<User>()).first else { throw JourneyError(message: "no user in this store") }
        self.init(ctx: ctx, container: ctx.container, calendar: Calendar.journey(week, timeZone: timeZone), now: now, origin: origin, user: user,
                  restMode: .manual, defaults: defaults ?? Self.suite())
    }

    static func manualRestTimer(_ notifier: FakeRestNotifier, mode: RestTimerMode = .manual) -> RestTimerService {
        let suite = UserDefaults(suiteName: "rest-\(UUID().uuidString)")!
        let timer = RestTimerService(notifier: notifier, defaults: suite)
        timer.mode = mode
        return timer
    }

    private func wire(_ vm: WorkoutViewModel) {
        vm.now = { [unowned self] in self.now }
        vm.calendar = calendar
        vm.widgetUpdater = { [unowned self] context, date in
            let ws = self.historyRows()
            self.widgetSnapshots.append(WidgetDataService.buildSnapshot(workouts: ws, modelContext: context, now: date,
                                                                        fixedDefaults: self.widgetDefaults, calendar: self.isoCalendar))
        }
    }

    /// Edit profile > weight: stores kg on the user and appends to the bodyweight log (the widget's source).
    func setBodyweight(_ kg: Double) {
        user.weight = kg
        user.markUpdated(now: now)
        BodyweightLog.record(kg: kg, on: now, calendar: calendar, defaults: widgetDefaults)
    }

    // MARK: Clock

    func goTo(_ date: Date) { now = date }

    func advance(days: Int = 0, hours: Int = 0, minutes: Int = 0) {
        var d = now
        if days != 0 { d = calendar.date(byAdding: .day, value: days, to: d)! }
        d = d.addingTimeInterval(TimeInterval(hours * 3600 + minutes * 60))
        now = d
    }

    /// Jumps to day `n` (0 = the day the sim started) at `hour`:`minute`.
    func skipToDay(_ n: Int, hour: Int = 18, minute: Int = 0) {
        let day = calendar.date(byAdding: .day, value: n, to: origin)!
        now = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    /// `n` full days with no training (the clock moves; nothing is logged).
    func restDays(_ n: Int) { advance(days: n) }

    var today: Date { calendar.startOfDay(for: now) }
    func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: origin)! }

    // MARK: Lookups

    func exercise(_ name: String) -> Exercise { catalogue[name]! }

    func template(_ name: String) -> WorkoutTemplate? {
        ((try? ctx.fetch(FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []).first { $0.name == name }
    }

    func drafts() -> [Workout] {
        (try? ctx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.isDraft && $0.deletedAt == nil }))) ?? []
    }

    // MARK: Session

    /// "Start workout" from a template (or blank). Uses the same view-model call as the Home dock.
    func startSession(template name: String? = nil) {
        vm.startWorkout(modelContext: ctx, user: user, template: name.flatMap(template))
        vm.durationTimer?.invalidate()    // real clocks must not tick during a simulated session
        vm.durationTimer = nil
    }

    /// The Home "discard draft and start new" path.
    func startSessionOverDraft(template name: String? = nil) {
        guard let draft = drafts().first else { return startSession(template: name) }
        vm.discardDraftAndStart(draft: draft, modelContext: ctx, user: user, template: name.flatMap(template))
        vm.durationTimer?.invalidate(); vm.durationTimer = nil
    }

    /// Replaces the view model (app killed and relaunched); the store survives.
    @discardableResult
    func crash() -> WorkoutViewModel {
        vm.durationTimer?.invalidate()
        vm.removeLiveActivityObservers()
        vm = WorkoutViewModel(restTimer: Self.manualRestTimer(restNotifier, mode: restMode))
        wire(vm)
        return vm
    }

    /// Continue card on Home after a relaunch.
    func resumeDraft() {
        guard let draft = drafts().first else { return }
        vm.resumeDraft(workout: draft, modelContext: ctx)
        vm.durationTimer?.invalidate(); vm.durationTimer = nil
    }

    func entryIndex(_ name: String) -> Int? { vm.exerciseEntries.firstIndex { $0.exerciseName == name } }

    /// Types and logs one set. `weight` is in the user's display unit (what they type); nil leaves the field empty
    /// (the ghost value from last time is used when there is one).
    @discardableResult
    func log(_ name: String, _ weight: Double?, _ reps: Int?, rir: Int? = nil, type: SetType = .standard,
             side: Side = .both, duration: Int? = nil) -> (exercise: Int, set: Int) {
        let ei: Int
        if let existing = entryIndex(name) { ei = existing } else {
            vm.addExercise(exercise(name))
            ei = vm.exerciseEntries.count - 1
        }
        let si: Int
        if let open = vm.exerciseEntries[ei].sets.firstIndex(where: { !$0.isCompleted }) { si = open } else {
            vm.addSet(to: ei)
            si = vm.exerciseEntries[ei].sets.count - 1
        }
        if let weight { vm.exerciseEntries[ei].sets[si].weight = user.unitPreference.kgString(displayText: Self.typed(weight)) }
        if let reps { vm.exerciseEntries[ei].sets[si].reps = String(reps) }
        if let rir { vm.exerciseEntries[ei].sets[si].rir = String(rir) }
        if let duration { vm.exerciseEntries[ei].sets[si].duration = String(duration) }
        vm.exerciseEntries[ei].sets[si].setType = type
        vm.exerciseEntries[ei].sets[si].side = side
        vm.logSet(exerciseIndex: ei, setIndex: si, modelContext: ctx)

        let entry = vm.exerciseEntries[ei].sets[si]
        ledger.append(LoggedSet(session: sessionCount, day: today, exercise: name, kg: parseDecimal(entry.weight) ?? 0,
                                reps: parseWholeNumber(entry.reps) ?? 0, type: type))
        return (ei, si)
    }

    /// The text a person types for `value`: whole numbers without a decimal point, otherwise full precision (never rounded).
    static func typed(_ value: Double) -> String { value == value.rounded() ? String(Int(value)) : "\(value)" }

    /// Several identical working sets.
    func logSets(_ name: String, _ weight: Double?, _ reps: Int, count: Int, rir: Int? = nil) {
        for _ in 0..<count { log(name, weight, reps, rir: rir) }
    }

    func warmup(_ name: String, _ weight: Double, _ reps: Int) { log(name, weight, reps, type: .warmup) }

    /// "Finish": the same call the Finish button makes, then the summary is dismissed (view model reset).
    @discardableResult
    func finish(minutes: Int = 60) -> WorkoutCompletionData {
        let w = vm.workout!
        let start = w.date
        vm.elapsedSeconds = minutes * 60
        advance(minutes: minutes)
        vm.completeWorkout(modelContext: ctx)
        let data = vm.completionData!
        // Real time and simulated time coincide for a real user; keep the logs' creation stamps on the simulated clock.
        for (i, log) in w.exerciseLogs.sorted(by: { $0.order < $1.order }).enumerated() {
            log.createdAt = start.addingTimeInterval(Double(i) * 0.001)
        }
        completions.append(data)
        finished.append(w)
        sessionCount += 1
        vm.reset()
        return data
    }

    /// One whole session in a single call: start (optional template), log, finish.
    @discardableResult
    func session(template name: String? = nil, minutes: Int = 60, _ body: (UserSim) -> Void) -> WorkoutCompletionData {
        startSession(template: name)
        body(self)
        return finish(minutes: minutes)
    }

    // MARK: What the screens read

    /// ISO weeks in the sim's time zone (what the widget builder and Weekly Recap use, whatever the locale's first weekday).
    var isoCalendar: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = calendar.timeZone
        return c
    }

    /// History list: finished, non-deleted, newest first (the `@Query` on More › History / Home). Only workouts that have
    /// started by `now`: when a test moves the clock back it sees the world as it was then.
    func historyRows() -> [Workout] {
        let at = now
        return (try? ctx.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil && $0.date <= at },
            sortBy: [SortDescriptor(\Workout.date, order: .reverse)]))) ?? []
    }

    func history() -> HistoryStats { HistoryStats(workouts: historyRows(), now: now, calendar: calendar) }

    func home() -> HomeStats { HomeStats(workouts: historyRows(), now: now, calendar: calendar) }

    /// Body tab: every non-deleted workout, drafts included (as the screen queries).
    func body(weekOffset: Int = 0, day: Int = -1) -> BodyMapStats {
        let at = now
        let all = (try? ctx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.deletedAt == nil && $0.date <= at }))) ?? []
        return BodyMapStats(workouts: all, weekOffset: weekOffset, selectedDayIndex: day, now: now, calendar: calendar)
    }

    func recap(weeksBack: Int = 0) -> WeeklyRecapStats {
        var c = WeeklyRecapStats(workouts: historyRows(), weeksBack: weeksBack, now: now, unit: user.unitPreference,
                                 splitDayCount: user.selectedSplit?.days.count ?? 0)
        c.calendar = WeeklyRecapStats.isoMonday
        c.calendar.timeZone = calendar.timeZone
        return c
    }

    func progress(of name: String) -> ExerciseProgress { ExerciseProgress(exercise: exercise(name)) }

    func widget() -> PumpWidgetSnapshot {
        WidgetDataService.buildSnapshot(workouts: historyRows(), modelContext: ctx, now: now, fixedDefaults: widgetDefaults, calendar: isoCalendar)
    }

    func prediction() -> String? { vm.predictNextWorkout(user: user, modelContext: ctx) }

    /// Template names of finished workouts, newest first (the predictor's input).
    func historyNames() -> [String] { historyRows().compactMap { $0.template?.name } }

    func confidence() -> Double {
        WidgetDataService.predictionConfidence(names: Array(historyNames().prefix(14)), hasSplit: user.selectedSplit != nil,
                                               predicted: prediction() != nil)
    }

    func streak() -> Int { StreakCalculator.currentStreak(from: historyRows().map(\.date), now: now, calendar: calendar) }

    func calories(of w: Workout) -> Double { w.calorieBurnEstimate }

    /// The post a finished session would publish (privacy from `privacy`).
    func postPayload(of data: WorkoutCompletionData, caption: String = "", privacy: PrivacySettings = .default,
                     includeBodyMap: Bool = true) -> PostPayload? {
        FeedPostBuilder.makePayload(data: data, author: .init(uid: "me", name: user.name, handle: user.username), caption: caption,
                                    taggedUids: [], includeBodyMap: includeBodyMap, privacy: privacy, date: now)
    }

    // MARK: Editing history (More › History › detail)

    func workout(onDay n: Int) -> Workout? {
        historyRows().first { calendar.isDate($0.date, inSameDayAs: day(n)) }
    }

    func log(of w: Workout, _ exerciseName: String) -> ExerciseLog? {
        w.exerciseLogs.first { $0.exercise?.name == exerciseName }
    }

    /// Edits a saved set the way the detail screen does (typed in the display unit), then "Done".
    func editSet(_ w: Workout, _ exerciseName: String, setIndex: Int, weight: Double? = nil, reps: Int? = nil) {
        let set = log(of: w, exerciseName)!.sets.sorted { $0.order < $1.order }[setIndex]
        if let weight { set.weight = user.unitPreference.parseKg(Self.typed(weight))! }
        if let reps { set.reps = reps }
        w.markUpdated()
    }

    func deleteSet(_ w: Workout, _ exerciseName: String, setIndex: Int) {
        let l = log(of: w, exerciseName)!
        let sorted = l.sets.sorted { $0.order < $1.order }
        ctx.delete(sorted[setIndex])                       // exactly the detail screen's deleteSets, then SwiftData autosaves
        for (i, s) in l.sets.sorted(by: { $0.order < $1.order }).enumerated() { s.order = i }
        ctx.markUpdated(l)
        try? ctx.save()
    }

    func deleteWorkout(_ w: Workout) {
        ctx.softDelete(w)
        try? ctx.save()
    }

    // MARK: Ledger oracles (independent of the app)

    func working(_ exercise: String? = nil) -> [LoggedSet] {
        ledger.filter { $0.isWorking && (exercise == nil || $0.exercise == exercise) }
    }
}

// MARK: - Independent maths used by assertions

enum Oracle {
    /// Epley as the PR / completion code defines it (also valid for a single).
    static func epley(_ kg: Double, _ reps: Int) -> Double { kg * (1 + Double(reps) / 30) }
    /// The exercise detail screen's variant: a single is just the weight.
    static func epleyDetail(_ kg: Double, _ reps: Int) -> Double { reps > 1 ? kg * (1 + Double(reps) / 30) : kg }

    static func volume(_ sets: [LoggedSet]) -> Double { sets.reduce(0) { $0 + $1.kg * Double($1.reps) } }

    /// Days between two start-of-days, written without Calendar.
    static func days(from a: Date, to b: Date) -> Int { Int((b.timeIntervalSince(a) / 86_400).rounded()) }

    /// Streak by the documented rule: unique training days, newest first; alive when the newest is <= 3 days before
    /// `today`; the streak is the calendar span of the unbroken chain (gaps <= 3 days) + 1.
    static func streak(trainingDays: [Date], today: Date) -> Int {
        let uniq = Array(Set(trainingDays)).sorted(by: >)
        guard let first = uniq.first, days(from: first, to: today) <= 3 else { return 0 }
        var total = 1
        var prev = first
        for d in uniq.dropFirst() {
            let gap = days(from: d, to: prev)
            if gap > 3 { break }
            total += gap
            prev = d
        }
        return total
    }
}
