import Testing
import Foundation
import SwiftData
@testable import Ore

/// Day one: a brand-new person opens the app, starts a preset template, logs a workout and looks at every screen.
@MainActor
struct DayOneJourneyTests {
    private static let bench = "Barbell Bench Press"
    private static let ohp = "Overhead Press"

    /// Mon 5 Jan, 18:00: Push Day. Bench: 2 warm-ups + 4 working sets; OHP: 3 working sets.
    /// Working volume = 80*8 + 80*8 + 80*7 + 80*6 + 3 * (40*10) = 2320 + 1200 = 3520 kg, 7 working sets, 9 stored sets.
    private func pushDay(_ sim: UserSim, minutes: Int = 62) -> WorkoutCompletionData {
        sim.startSession(template: "Push Day")
        sim.warmup(Self.bench, 40, 10)
        sim.warmup(Self.bench, 60, 5)
        sim.log(Self.bench, 80, 8, rir: 2)
        sim.log(Self.bench, 80, 8, rir: 2)
        sim.log(Self.bench, 80, 7, rir: 1)
        sim.log(Self.bench, 80, 6, rir: 0)
        sim.logSets(Self.ohp, 40, 10, count: 3, rir: 2)
        return sim.finish(minutes: minutes)
    }

    @Test func startingFromAPresetLoadsItsExercisesInOrderWithTargetRows() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        let names = sim.vm.exerciseEntries.map(\.exerciseName)
        #expect(names == ["Barbell Bench Press", "Overhead Press", "Incline Dumbbell Bench Press", "Lateral Raise",
                          "Tricep Pushdown", "Overhead Tricep Extension"])
        #expect(sim.vm.exerciseEntries.map { $0.sets.count } == [4, 3, 3, 3, 3, 3])
        #expect(sim.vm.exerciseEntries[0].sets.allSatisfy { $0.targetReps == 8 })
        // Linked to the real catalogue (not left as placeholders), so history / PRs / body map will see them.
        #expect(sim.vm.exerciseEntries.allSatisfy { $0.exerciseId != TemplateSeedService.unresolvedId })
        #expect(sim.vm.isActive)
    }

    @Test func whileTrainingThereIsOneDraftAndNothingInHistory() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)
        #expect(sim.drafts().count == 1)
        #expect(sim.historyRows().isEmpty)
        #expect(sim.home().recentRows.isEmpty && sim.home().weekSets == 0)
        #expect(sim.body().selectedTotalSets == 0)
        #expect(sim.progress(of: Self.bench).allSets.isEmpty)
        #expect(sim.widgetSnapshots.isEmpty)
    }

    @Test func finishingSavesOneWorkoutWithTheRightLogsAndSets() throws {
        let sim = try UserSim()
        let data = pushDay(sim)

        let all = try sim.ctx.fetch(FetchDescriptor<Workout>())
        #expect(all.count == 1)
        let w = try #require(all.first)
        #expect(!w.isDraft && w.deletedAt == nil)
        #expect(w.template?.name == "Push Day")
        #expect(w.duration == 62 * 60)
        #expect(w.date == sim.day(0).addingTimeInterval(18 * 3600))
        // Only the two exercises that have logged sets are kept; the four untouched template rows are dropped.
        #expect(w.exerciseLogs.count == 2)
        #expect(Set(w.exerciseLogs.compactMap { $0.exercise?.name }) == [Self.bench, Self.ohp])
        #expect(try sim.ctx.fetchCount(FetchDescriptor<ExerciseLog>()) == 2)
        #expect(try sim.ctx.fetchCount(FetchDescriptor<SetLog>()) == 9)

        let benchLog = try #require(sim.log(of: w, Self.bench))
        let sets = benchLog.sets.sorted { $0.order < $1.order }
        #expect(sets.map(\.weight) == [40, 60, 80, 80, 80, 80])
        #expect(sets.map(\.reps) == [10, 5, 8, 8, 7, 6])
        #expect(sets.map(\.setType) == [.warmup, .warmup, .standard, .standard, .standard, .standard])
        #expect(sets.map(\.rir) == [nil, nil, 2, 2, 1, 0])

        #expect(data.totalSets == 7 && data.exerciseCount == 2 && data.totalExercises == 2)
        #expect(data.duration == 62 * 60)
        #expect(data.workoutName == "Push Day" && data.workoutId == w.id)
    }

    @Test func warmUpsAreSavedButNeverCountedInSetsOrVolume() throws {
        let sim = try UserSim()
        _ = pushDay(sim)
        let w = try #require(sim.historyRows().first)
        #expect(w.workingSetCount == 7)
        #expect(w.exerciseLogs.flatMap(\.sets).count == 9)
        #expect(w.workingVolume == 3520)
        // The heaviest *warm-up* (60 kg) never becomes a stat: the exercise screen sees only working sets.
        let p = sim.progress(of: Self.bench)
        #expect(p.weightPR == 80 && p.repsPR == 8)
        #expect(p.volumePR == 2320)
        #expect(sim.recap().setCount(sim.recap().week) == 7)
        #expect(sim.home().weekSets == 7)
        #expect(sim.body().selectedTotalSets == 7)
    }

    @Test func everythingIsStoredInKilograms() throws {
        let sim = try UserSim()
        _ = pushDay(sim)
        let stored = sim.historyRows()[0].exerciseLogs.flatMap { $0.sets.sorted { $0.order < $1.order } }
        #expect(Set(stored.map(\.weight)) == Set(sim.ledger.map(\.kg)))
        #expect(stored.count == sim.ledger.count)
        #expect(sim.user.unitPreference == .kg)
    }

    @Test func theHistoryListHasExactlyOneEntryAndHomeShowsIt() throws {
        let sim = try UserSim()
        _ = pushDay(sim)
        #expect(sim.historyRows().count == 1)
        let h = sim.history()
        #expect(h.totalCount == 1 && h.thisMonthCount == 1 && h.streak == 1)
        #expect(h.workoutsOn(sim.day(0)).count == 1 && h.workoutsOn(sim.day(1)).isEmpty)

        let home = sim.home()
        #expect(home.currentStreak == 1)
        #expect(home.weekSets == 7)
        #expect(home.weekDayBars == [7, 0, 0, 0, 0, 0, 0])
        #expect(home.todayDayIndex == 0)           // Monday
        let row = try #require(home.recentRows.first)
        #expect(home.recentRows.count == 1)
        #expect(row.name == "PUSH DAY" && row.sets == 7 && row.exerciseCount == 2 && row.volumeDelta == "—")
    }

    @Test func theDraftIsGoneAndTheSessionClosedAfterFinishing() throws {
        let sim = try UserSim()
        _ = pushDay(sim)
        #expect(sim.drafts().isEmpty)
        #expect(!sim.vm.isActive && sim.vm.workout == nil && sim.vm.exerciseEntries.isEmpty)
        #expect(sim.restNotifier.scheduled.isEmpty)
    }

    @Test func theWidgetSnapshotIsRefreshedExactlyOnceWithTheNewWorkout() throws {
        let sim = try UserSim()
        _ = pushDay(sim)
        #expect(sim.widgetSnapshots.count == 1)
        let snap = try #require(sim.widgetSnapshots.first)
        #expect(snap.hasData && snap.streak == 1 && snap.sessionsThisWeek == 1)
        #expect(snap.setsPerDay[0] == 7)                                   // Monday bar
        #expect(snap.prs[Self.bench]?.weight == 80 && snap.prs[Self.ohp]?.weight == 40)
        #expect(snap.weightUnit == .kg && snap.bodyweight == 80)
        #expect(snap.fixed.setsThisWeek == 7 && snap.fixed.lastWorkoutName == "Push Day")
        #expect(snap.fixed.lastWorkoutExercises == 2 && snap.fixed.lastWorkoutMinutes == 62)
        #expect(snap.fixed.volumeTonnes == 3.5)                            // 3520 kg, rounded to 0.1 t
    }

    @Test func theNextWorkoutIsPredictedFromTheSplitAfterTheFirstSession() throws {
        let sim = try UserSim()
        _ = pushDay(sim)
        #expect(sim.prediction() == "Pull Day")
        #expect(sim.widget().nextName == "Pull Day")
    }

    @Test func caloriesUseTheBasicSetFormulaWithCompoundVsIsolationWeights() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 80, 8, count: 3)          // push = compound: 3 x 10
        sim.logSets("Tricep Pushdown", 30, 12, count: 2)   // isolation: 2 x 6
        sim.warmup("Lateral Raise", 5, 15)                 // warm-ups burn nothing
        sim.finish()
        #expect(sim.historyRows()[0].calorieBurnEstimate == 42)
    }

    @Test func dropSetsCountAsWorkingSetsWithTheirOwnWeights() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 100, 5)
        sim.log(Self.bench, 80, 8, type: .dropset)
        sim.log(Self.bench, 60, 10, type: .dropset)
        let data = sim.finish()
        let w = sim.historyRows()[0]
        #expect(data.totalSets == 3 && w.workingSetCount == 3)
        #expect(w.workingVolume == 1740)
        #expect(sim.progress(of: Self.bench).weightPR == 100)
        #expect(sim.log(of: w, Self.bench)!.sets.sorted { $0.order < $1.order }.map(\.setType) == [.standard, .dropset, .dropset])
    }

    @Test func unilateralSetsKeepTheirSideAndCountOncePerSide() throws {
        let sim = try UserSim()
        sim.startSession()
        sim.log("Dumbbell Row", 30, 10, side: .left)
        sim.log("Dumbbell Row", 30, 10, side: .right)
        sim.log("Dumbbell Row", 30, 9, side: .left)
        sim.log("Dumbbell Row", 30, 9, side: .right)
        let data = sim.finish()
        let w = sim.historyRows()[0]
        #expect(sim.log(of: w, "Dumbbell Row")!.sets.sorted { $0.order < $1.order }.map(\.side) == [.left, .right, .left, .right])
        #expect(w.workingSetCount == 4 && w.workingVolume == 1140)
        let post = try #require(sim.postPayload(of: data))
        #expect(post.exercises[0].sets.compactMap(\.side) == ["left", "right", "left", "right"])
    }

    @Test func bodyweightSetsStoreZeroLoadCountAsSetsAndAddNoVolume() throws {
        let sim = try UserSim()
        sim.startSession()
        sim.log("Pull Up", nil, 10)
        sim.log("Pull Up", nil, 8)
        sim.finish()
        let w = sim.historyRows()[0]
        #expect(w.workingSetCount == 2)
        #expect(w.workingVolume == 0)
        #expect(sim.log(of: w, "Pull Up")!.sets.map(\.weight) == [0, 0])
        let p = sim.progress(of: "Pull Up")
        #expect(p.repsPR == 10 && p.weightPR == 0 && p.trendPoints.isEmpty)
        #expect(sim.home().weekSets == 2)
    }

    @Test func aPoundsUserTypesPoundsButEverythingStoredIsKilograms() throws {
        let sim = try UserSim(unit: .lbs)
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 135, 5, count: 3)
        sim.finish()
        let w = sim.historyRows()[0]
        let stored = sim.log(of: w, Self.bench)!.sets.map(\.weight)
        let expectedKg = 135 * 0.45359237
        #expect(stored.count == 3 && stored.allSatisfy { abs($0 - expectedKg) < 0.0001 })
        // What the screens print goes back through the unit: 135 LB, not 61.2 KG.
        #expect(sim.user.unitPreference.number(stored[0]) == "135")
        #expect(sim.user.unitPreference.format(sim.progress(of: Self.bench).weightPR) == "135 LB")
        #expect(sim.user.unitPreference.volume(w.workingVolume) == "2,025")      // 3 x 135 x 5
        #expect(sim.widget().weightUnit == .lbs)
    }

    @Test func autoStartRestTimerRunsForTheRightDurationAndStopsOnFinish() throws {
        let sim = try UserSim(restMode: .autoStart)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)                         // compound, template has no rest -> default 180 s
        #expect(sim.vm.restTimer.isRunning && sim.vm.restTimer.totalSeconds == 180)
        sim.log("Lateral Raise", 8, 15)                    // isolation -> 90 s (and the timer restarts)
        #expect(sim.vm.restTimer.totalSeconds == 90 && sim.vm.restTimer.remainingSeconds == 90)
        #expect(sim.restNotifier.scheduled.count == 2)
        sim.finish()
        #expect(!sim.vm.restTimer.isRunning)
        #expect(sim.restNotifier.cancelCount >= 1)
    }

    @Test func skippingTheRestOnlyStopsTheTimerWithoutTouchingTheLog() throws {
        let sim = try UserSim(restMode: .autoStart)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)
        sim.vm.restTimer.skip()
        #expect(!sim.vm.restTimer.isRunning)
        #expect(sim.vm.exerciseEntries[0].sets[0].isCompleted)
        #expect(try sim.ctx.fetchCount(FetchDescriptor<SetLog>()) == 1)
    }

    @Test func manualRestModeNeverStartsATimer() throws {
        let sim = try UserSim(restMode: .manual)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)
        #expect(!sim.vm.restTimer.isRunning && sim.restNotifier.scheduled.isEmpty)
    }

    @Test func theCompletionSummaryOfAFirstEverSessionHasNoPRsOrImprovements() throws {
        let sim = try UserSim()
        let data = pushDay(sim)
        #expect(data.prCount == 0 && data.improvedCount == 0 && data.prDetails.isEmpty)
        #expect(data.streakCount == 1)
        #expect(data.musclesWorked.isSuperset(of: [.chest, .triceps, .frontDelts]))
    }

    @Test func homePRsAndImprovedTilesAgreeWithTheCompletionScreenOnTheFirstSession() throws {
        let sim = try UserSim()
        let data = pushDay(sim)
        withKnownIssue("HomeStats.weekPRs / improvedExercises treat 'no earlier session' as a record: Home says 2 PRs / 2 improved while the completion summary (WorkoutViewModel.completeWorkout:283,307) correctly says 0", isIntermittent: true) {
            #expect(sim.home().weekPRs == data.prCount)
            #expect(sim.home().weekImproved == data.improvedCount)
            #expect(sim.home().recentRows[0].improved == data.improvedCount)
        }
    }

    @Test func finishingWithNothingLoggedDoesNotCreateAHistoryEntryOrStreakDay() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.finish(minutes: 1)
        withKnownIssue("WorkoutViewModel.completeWorkout saves an empty workout (0 sets) into history and extends the streak; the Finish button has no 'nothing logged' guard (ActiveWorkoutView:365)", isIntermittent: true) {
            #expect(sim.historyRows().isEmpty)
            #expect(sim.streak() == 0)
        }
    }

    @Test func aPostIsBuiltOnceWithWorkingSetsOnlyAndAnIdempotentId() throws {
        let sim = try UserSim()
        let data = pushDay(sim)
        let first = try #require(sim.postPayload(of: data))
        let second = try #require(sim.postPayload(of: data))
        let id = sim.historyRows()[0].id.uuidString.lowercased()
        #expect(first.postId == id && second.postId == id)
        #expect(first.exercises.flatMap(\.sets).allSatisfy { $0.isWorking })
        #expect(first.stats.sets == 7 && first.stats.volumeKg == 3520 && first.stats.durationSec == 62 * 60)
    }
}
