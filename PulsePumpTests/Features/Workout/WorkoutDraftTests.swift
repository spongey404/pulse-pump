import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// Draft persistence / crash recovery, warm-up exclusion, ghost values and decimal-comma input.
@MainActor
struct WorkoutDraftTests {
    struct Fixture {
        let ctx: ModelContext
        let user: User
        let bench: Exercise
        let row: Exercise
        let vm: WorkoutViewModel
    }

    /// A rest timer on private defaults (manual mode) with a fake notifier: no shared state, no
    /// real notifications, no timer started by logging sets.
    static func isolatedRestTimer(notifier: RestEndNotifying = FakeRestNotifier()) -> RestTimerService {
        let suite = UserDefaults(suiteName: "rest-\(UUID().uuidString)")!
        let timer = RestTimerService(notifier: notifier, defaults: suite)
        timer.mode = .manual
        return timer
    }

    static func fixture() throws -> Fixture {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let user = User(name: "T", weight: 80)
        ctx.insert(user)
        let bench = Exercise(name: "Barbell Bench Press", primaryMuscleGroups: [.chest], equipmentType: .barbell, movementPattern: .push)
        let row = Exercise(name: "Barbell Row", primaryMuscleGroups: [.lats], equipmentType: .barbell, movementPattern: .pull)
        ctx.insert(bench); ctx.insert(row)
        let vm = WorkoutViewModel(restTimer: isolatedRestTimer())
        return Fixture(ctx: ctx, user: user, bench: bench, row: row, vm: vm)
    }

    /// Adds an exercise and logs sets given as (weight, reps, type).
    @discardableResult
    static func log(_ f: Fixture, _ exercise: Exercise, _ sets: [(String, String, SetType)], vm: WorkoutViewModel? = nil) -> Int {
        let vm = vm ?? f.vm
        vm.addExercise(exercise)
        let ei = vm.exerciseEntries.count - 1
        for (i, s) in sets.enumerated() {
            if i > 0 { vm.addSet(to: ei) }
            vm.exerciseEntries[ei].sets[i].weight = s.0
            vm.exerciseEntries[ei].sets[i].reps = s.1
            vm.exerciseEntries[ei].sets[i].setType = s.2
            vm.logSet(exerciseIndex: ei, setIndex: i, modelContext: f.ctx)
        }
        return ei
    }

    /// A finished past session of `exercise`.
    static func addHistory(_ f: Fixture, _ exercise: Exercise, daysAgo: Int, sets: [(Double, Int, SetType)]) {
        let w = Workout(date: Date().addingTimeInterval(-Double(daysAgo) * 86_400), duration: 3000, isDraft: false)
        w.user = f.user
        f.ctx.insert(w)
        let log = ExerciseLog(order: 0)
        f.ctx.insert(log); log.workout = w; log.exercise = exercise
        for (i, s) in sets.enumerated() {
            let set = SetLog(order: i, weight: s.0, reps: s.1, setType: s.2)
            f.ctx.insert(set); set.exerciseLog = log
        }
    }

    // MARK: Draft persistence

    @Test func loggedSetsArePersistedImmediately() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        Self.log(f, f.bench, [("80", "8", .standard), ("40", "10", .warmup)])
        // An unlogged row is not persisted.
        f.vm.addSet(to: 0)
        f.vm.exerciseEntries[0].sets[2].weight = "85"

        let draft = try #require(f.vm.workout)
        #expect(draft.isDraft)
        #expect(draft.exerciseLogs.count == 1)
        let sets = draft.exerciseLogs[0].sets.sorted { $0.order < $1.order }
        #expect(sets.count == 2)
        #expect(sets[0].weight == 80 && sets[0].reps == 8)
        #expect(sets[1].setType == .warmup)
    }

    @Test func resumeRestoresExercisesSetsTypesSidesAndNotes() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        f.vm.workoutNotes = "felt strong"
        let ei = Self.log(f, f.bench, [("60", "10", .warmup), ("80", "8", .standard)])
        f.vm.exerciseEntries[ei].sets[1].side = .left
        f.vm.exerciseEntries[ei].notes = "paused reps"
        Self.log(f, f.row, [("70", "10", .standard)])
        f.vm.saveDraftAndClose(modelContext: f.ctx)

        #expect(!f.vm.isActive && f.vm.exerciseEntries.isEmpty)       // session closed, draft kept
        let drafts = try f.ctx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.isDraft }))
        #expect(drafts.count == 1)

        // "Crash": a brand-new view model resumes from SwiftData alone.
        let fresh = WorkoutViewModel(restTimer: Self.isolatedRestTimer())
        fresh.resumeDraft(workout: drafts[0], modelContext: f.ctx)

        #expect(fresh.isActive)
        #expect(fresh.workoutNotes == "felt strong")
        #expect(fresh.exerciseEntries.map(\.exerciseName) == ["Barbell Bench Press", "Barbell Row"])
        let bench = fresh.exerciseEntries[0]
        let done = bench.sets.filter(\.isCompleted)
        #expect(done.count == 2)
        #expect(done[0].setType == .warmup && done[0].weight == "60")
        #expect(done[1].side == .left && done[1].reps == "8")
        #expect(bench.notes == "paused reps")
        #expect(bench.sets.count == 2)
        fresh.stopDurationTimer()
    }

    @Test func resumeThenFinishDoesNotDuplicateLogs() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        Self.log(f, f.bench, [("80", "8", .standard), ("80", "8", .standard)])
        f.vm.saveDraftAndClose(modelContext: f.ctx)
        let draft = try #require(try f.ctx.fetch(FetchDescriptor<Workout>()).first)

        let fresh = WorkoutViewModel(restTimer: Self.isolatedRestTimer())
        fresh.resumeDraft(workout: draft, modelContext: f.ctx)
        fresh.addSet(to: 0)
        fresh.exerciseEntries[0].sets[2].weight = "82,5"
        fresh.exerciseEntries[0].sets[2].reps = "6"
        fresh.logSet(exerciseIndex: 0, setIndex: 2, modelContext: f.ctx)
        fresh.completeWorkout(modelContext: f.ctx)

        let workouts = try f.ctx.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1 && !workouts[0].isDraft)
        #expect(try f.ctx.fetchCount(FetchDescriptor<ExerciseLog>()) == 1)
        #expect(try f.ctx.fetchCount(FetchDescriptor<SetLog>()) == 3)
        let weights = workouts[0].exerciseLogs[0].sets.sorted { $0.order < $1.order }.map(\.weight)
        #expect(weights == [80, 80, 82.5])                             // decimal comma parsed
    }

    @Test func unloggingASetRemovesItFromTheDraft() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        Self.log(f, f.bench, [("80", "8", .standard), ("80", "8", .standard)])
        f.vm.unlogSet(exerciseIndex: 0, setIndex: 1)
        #expect(f.vm.workout?.exerciseLogs[0].sets.count == 1)
        f.vm.removeExercise(at: 0)
        #expect(f.vm.workout?.exerciseLogs.isEmpty == true)
    }

    @Test func finishDropsExercisesWithNoCompletedSets() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        Self.log(f, f.bench, [("80", "8", .standard)])
        f.vm.addExercise(f.row)                                        // never logged
        f.vm.completeWorkout(modelContext: f.ctx)
        #expect(try f.ctx.fetchCount(FetchDescriptor<ExerciseLog>()) == 1)
    }

    @Test func draftsAreNotHistory() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        Self.log(f, f.bench, [("200", "5", .standard)])
        // The in-progress draft must not feed ghost text or "previous" comparisons.
        #expect(f.vm.ghostText(for: f.bench.id, setIndex: 0, modelContext: f.ctx) == nil)
        #expect(f.bench.finalLogs.isEmpty)
        #expect(f.ctx.finalLogs(forExercise: f.bench.id).isEmpty)
    }

    // MARK: Warm-ups

    @Test func warmupsAreExcludedFromCompletionStats() throws {
        let f = try Self.fixture()
        Self.addHistory(f, f.bench, daysAgo: 7, sets: [(100, 5, .standard)])
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        // Heavy warm-up must not count as a PR; the working set (+5 kg) is the PR.
        Self.log(f, f.bench, [("140", "3", .warmup), ("105", "5", .standard)])
        f.vm.completeWorkout(modelContext: f.ctx)

        let data = try #require(f.vm.completionData)
        #expect(data.totalSets == 1)
        #expect(data.prCount == 1)
        #expect(data.prDetails.first?.weightDelta == 5)
        // Warm-ups stay saved and in the feed breakdown...
        #expect(data.exercises[0].sets.count == 2)
        // ...but never in totals.
        #expect(data.exercises[0].workingSets.count == 1)
        #expect(try f.ctx.fetchCount(FetchDescriptor<SetLog>()) == 3)
    }

    @Test func workoutStatHelpersSkipWarmups() throws {
        let f = try Self.fixture()
        Self.addHistory(f, f.bench, daysAgo: 1, sets: [(40, 10, .warmup), (80, 5, .standard), (80, 5, .dropset)])
        let w = try #require(try f.ctx.fetch(FetchDescriptor<Workout>()).first)
        #expect(w.exerciseLogs.flatMap(\.sets).count == 3)
        #expect(w.workingSetCount == 2)
        #expect(w.workingVolume == 800)
    }

    @Test func feedBodyHeatIgnoresWarmups() {
        func s(_ t: String) -> FeedSetLog { FeedSetLog(weight: 50, reps: 5, duration: 0, distance: 0, setType: t, side: nil) }
        let ex = FeedExercise(id: "1", name: "Bench", sets: [s("warmup"), s("warmup"), s("standard")],
                              primaryMuscles: [MuscleGroup.chest.displayName])
        #expect([ex].muscleSetCounts()[.chest] == 1)
    }

    // MARK: Ghost values

    @Test func tickingWithEmptyFieldsSavesGhostValues() throws {
        let f = try Self.fixture()
        Self.addHistory(f, f.bench, daysAgo: 7, sets: [(100, 5, .standard), (95, 6, .standard)])
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        f.vm.addExercise(f.bench)
        f.vm.addSet(to: 0)
        // Row 0: nothing typed -> ghost 100 x 5 saved. Row 1: only reps typed -> weight ghost only.
        f.vm.logSet(exerciseIndex: 0, setIndex: 0, modelContext: f.ctx)
        f.vm.exerciseEntries[0].sets[1].reps = "8"
        f.vm.logSet(exerciseIndex: 0, setIndex: 1, modelContext: f.ctx)

        #expect(f.vm.exerciseEntries[0].sets[0].weight == "100" && f.vm.exerciseEntries[0].sets[0].reps == "5")
        #expect(f.vm.exerciseEntries[0].sets[1].weight == "95")
        #expect(f.vm.exerciseEntries[0].sets[1].reps == "8")           // typed value wins
        let saved = f.vm.workout!.exerciseLogs[0].sets.sorted { $0.order < $1.order }
        #expect(saved.map(\.weight) == [100, 95] && saved.map(\.reps) == [5, 8])
    }

    @Test func noGhostMeansNothingIsInvented() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        f.vm.addExercise(f.row)                                        // no history
        f.vm.logSet(exerciseIndex: 0, setIndex: 0, modelContext: f.ctx)
        #expect(f.vm.exerciseEntries[0].sets[0].weight.isEmpty && f.vm.exerciseEntries[0].sets[0].reps.isEmpty)
    }

    @Test func typedValuesAreNeverOverwrittenByGhost() throws {
        let f = try Self.fixture()
        Self.addHistory(f, f.bench, daysAgo: 7, sets: [(100, 5, .standard)])
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        f.vm.addExercise(f.bench)
        f.vm.exerciseEntries[0].sets[0].weight = "60"
        f.vm.exerciseEntries[0].sets[0].reps = "12"
        f.vm.logSet(exerciseIndex: 0, setIndex: 0, modelContext: f.ctx)
        #expect(f.vm.exerciseEntries[0].sets[0].weight == "60" && f.vm.exerciseEntries[0].sets[0].reps == "12")
    }

    // MARK: Template linking

    @Test func startWorkoutLinksTemplateExercisesByNameWhenIdIsStale() throws {
        let f = try Self.fixture()
        let template = WorkoutTemplate(name: "Push Day", templateExercises: [
            TemplateExercise(exerciseId: UUID(), exerciseName: "barbell  bench-press", order: 0, targetSets: 3, targetReps: 8, restSeconds: 120),
        ])
        f.ctx.insert(template)
        f.vm.startWorkout(modelContext: f.ctx, user: f.user, template: template)
        let entry = f.vm.exerciseEntries[0]
        #expect(entry.exerciseId == f.bench.id)
        #expect(entry.restSeconds == 120)
        #expect(entry.isCompound)
        #expect(entry.sets.count == 3)
    }

    @Test func resumePadsTemplateRowsBackToTargetSets() throws {
        let f = try Self.fixture()
        let template = WorkoutTemplate(name: "Push Day", templateExercises: [
            TemplateExercise(exerciseId: f.bench.id, exerciseName: f.bench.name, order: 0, targetSets: 4, targetReps: 8),
        ])
        f.ctx.insert(template)
        f.vm.startWorkout(modelContext: f.ctx, user: f.user, template: template)
        f.vm.exerciseEntries[0].sets[0].weight = "80"
        f.vm.exerciseEntries[0].sets[0].reps = "8"
        f.vm.logSet(exerciseIndex: 0, setIndex: 0, modelContext: f.ctx)
        f.vm.saveDraftAndClose(modelContext: f.ctx)

        let fresh = WorkoutViewModel(restTimer: Self.isolatedRestTimer())
        fresh.resumeDraft(workout: try #require(try f.ctx.fetch(FetchDescriptor<Workout>()).first), modelContext: f.ctx)
        #expect(fresh.exerciseEntries[0].sets.count == 4)
        #expect(fresh.exerciseEntries[0].sets.filter(\.isCompleted).count == 1)
        #expect(fresh.exerciseEntries[0].sets[3].targetReps == 8)
        fresh.stopDurationTimer()
    }

    // MARK: Feed post payload

    @Test func feedPostUsesWorkoutIdAndCarriesAudience() throws {
        let f = try Self.fixture()
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        Self.log(f, f.bench, [("80", "8", .standard)])
        f.vm.completeWorkout(modelContext: f.ctx)
        let data = try #require(f.vm.completionData)
        #expect(data.workoutId == f.vm.workout?.id)

        var privacy = PrivacySettings()
        privacy.workoutPosts = .friendsOnly
        privacy.bodyMap = .onlyMe
        let author = FeedPostBuilder.Author(uid: "u", name: "n", handle: "n_n")
        let payload = try #require(FeedPostBuilder.makePayload(data: data, author: author, caption: "hi",
                                                               taggedUids: [], includeBodyMap: true, privacy: privacy))
        #expect(payload.postId == data.workoutId?.uuidString.lowercased())   // same workout -> same doc: posts at most once
        #expect(payload.audience == .friends)
        #expect(payload.bodyMapAudience == .onlyMe)
        #expect(payload.muscleSets == nil)                                    // body-map row is "only me": no extras document

        privacy.workoutPosts = .onlyMe
        #expect(FeedPostBuilder.makePayload(data: data, author: author, caption: "", taggedUids: [], includeBodyMap: true, privacy: privacy) == nil)

        let suite = UserDefaults(suiteName: "feed-\(UUID().uuidString)")!
        suite.set(PrivacyLevel.onlyMe.rawValue, forKey: PrivacyRow.workoutPosts.storageKey)
        #expect(FeedPostBuilder.audience(defaults: suite) == .onlyMe)
    }
}
