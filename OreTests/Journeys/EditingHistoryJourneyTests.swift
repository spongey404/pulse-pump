import Testing
import Foundation
import SwiftData
@testable import Ore

/// Past workouts are corrected or removed; every derived number has to follow.
@MainActor
struct EditingHistoryJourneyTests {
    private static let bench = "Barbell Bench Press"
    private static let ohp = "Overhead Press"

    /// Two weeks of Mon Push / Wed Pull: bench 60 -> 62.5 (a weight PR in week 1), row 60 -> 62.5.
    /// Per session: bench 3x5, OHP 2x5 (push); row 3x5, curl 2x5 (pull). The clock ends Thursday of week 1 (day 10), 20:00.
    private func twoWeeks() throws -> UserSim {
        let sim = try UserSim()
        for week in 0..<2 {
            let up = 2.5 * Double(week)
            sim.skipToDay(7 * week)
            sim.session(template: "Push Day") { s in
                s.logSets(Self.bench, 60 + up, 5, count: 3)
                s.logSets(Self.ohp, 35 + up, 5, count: 2)
            }
            sim.skipToDay(7 * week + 2)
            sim.session(template: "Pull Day") { s in
                s.logSets("Barbell Row", 60 + up, 5, count: 3)
                s.logSets("Barbell Curl", 25 + up, 5, count: 2)
            }
        }
        sim.skipToDay(10, hour: 20)        // Thursday of week 1
        return sim
    }

    @Test func editingASetUpdatesTheWorkoutTheChartsAndTheStatCards() throws {
        let sim = try twoWeeks()
        let w = try #require(sim.workout(onDay: 7))                          // week-1 push
        let volumeBefore = w.workingVolume
        let stampBefore = w.updatedAt
        #expect(volumeBefore == 1312.5)
        sim.editSet(w, Self.bench, setIndex: 0, weight: 70, reps: 6)         // 62.5x5 -> 70x6

        #expect(w.workingVolume == 1420)
        let p = sim.progress(of: Self.bench)
        #expect(p.weightPR == 70 && p.repsPR == 6)
        #expect(p.trendPoints.map(\.maxWeight) == [60, 70])
        #expect(abs(p.estimated1RM - 84) < 1e-9)                              // 70 x 6 = 70 * 1.2
        #expect(p.volumePR == 1045)                                           // 420 + 625
        #expect(sim.historyRows().count == 4)                                 // nothing added or lost
        #expect(sim.home().weekSets == 10 && sim.body().selectedTotalSets == 10)
        #expect(w.updatedAt > stampBefore)                                    // queued for cloud sync
    }

    @Test func editingASetAfterTheFactDoesNotRewriteTheStoredCompletionHistory() throws {
        let sim = try twoWeeks()
        let flagged = sim.completions[2].prCount            // week-1 push was a PR session when it finished
        #expect(flagged == 2)
        sim.editSet(try #require(sim.workout(onDay: 7)), Self.bench, setIndex: 0, weight: 50)
        #expect(sim.completions[2].prCount == 2)            // the summary was a moment in time
    }

    @Test func loweringThePRSetTakesTheRecordBackAwayFromHomeRecapAndTheExerciseScreen() throws {
        let sim = try twoWeeks()
        #expect(sim.home().weekPRs == 4)                    // bench, OHP, row, curl all beat last week
        #expect(sim.recap().records.contains { $0.name == Self.bench })
        let w = try #require(sim.workout(onDay: 7))
        for i in 0..<3 { sim.editSet(w, Self.bench, setIndex: i, weight: 55) }
        #expect(sim.home().weekPRs == 3)
        #expect(!sim.recap().records.contains { $0.name == Self.bench })
        #expect(sim.recap().records.count == 3)
        #expect(sim.progress(of: Self.bench).weightPR == 60)               // back to week 0's best
        #expect(sim.widget().prs[Self.bench]?.weight == 60)
    }

    @Test func deletingASetShrinksSetsVolumeAndEveryWeeklyTotal() throws {
        let sim = try twoWeeks()
        let w = try #require(sim.workout(onDay: 7))
        sim.deleteSet(w, Self.bench, setIndex: 2)
        #expect(w.workingSetCount == 4)
        #expect(w.workingVolume == 1000)
        #expect(sim.log(of: w, Self.bench)!.sets.sorted { $0.order < $1.order }.map(\.order) == [0, 1])     // renumbered
        #expect(sim.home().weekSets == 9 && sim.body().selectedTotalSets == 9)
        #expect(sim.recap().setCount(sim.recap().week) == 9)
        #expect(sim.widget().fixed.setsThisWeek == 9)
        #expect(sim.progress(of: Self.bench).allSets.count == 5)
    }

    @Test func deletingTheFirstSetKeepsTheRemainingSetsNumberedFromOne() throws {
        let sim = try twoWeeks()
        let w = try #require(sim.workout(onDay: 7))
        sim.deleteSet(w, Self.bench, setIndex: 0)
        let orders = sim.log(of: w, Self.bench)!.sets.map(\.order).sorted()
        withKnownIssue("WorkoutDetailView.deleteSets renumbers `log.sets` right after modelContext.delete, before SwiftData drops the deleted set from the relationship, so deleting the first set leaves orders [1, 2] and the screen labels the survivors S2, S3", isIntermittent: true) {
            #expect(orders == [0, 1])                                          // the detail screen labels them S1, S2
        }
    }

    @Test func deletingTheOnlyWarmUpOrWorkingSetOfALiftLeavesNoPhantomVolume() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in
            s.warmup(Self.bench, 40, 10)
            s.logSets(Self.bench, 80, 5, count: 1)
        }
        let w = sim.historyRows()[0]
        sim.deleteSet(w, Self.bench, setIndex: 1)               // the working set
        #expect(w.workingSetCount == 0 && w.workingVolume == 0)
        #expect(sim.progress(of: Self.bench).weightPR == 0)
    }

    @Test func deletingEverySetOfAnExerciseRemovesItFromTheCountsAndTheBodyMap() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in
            s.logSets(Self.bench, 80, 5, count: 3)
            s.logSets("Tricep Pushdown", 30, 12, count: 2)
        }
        let w = sim.historyRows()[0]
        #expect(w.exerciseLogs.count == 2 && sim.body().musclesWorkedCount == 2)
        for _ in 0..<3 { sim.deleteSet(w, Self.bench, setIndex: 0) }
        #expect(w.workingSetCount == 2)
        withKnownIssue("Deleting every set of an exercise (WorkoutDetailView.deleteSets) leaves an empty ExerciseLog: History/Home still count the exercise ('2 EX', 'n/2 improved') and the Body tab still lists its muscles as worked", isIntermittent: true) {
            #expect(w.exerciseLogs.count == 1)
            #expect(sim.body().musclesWorkedCount == 1)
            #expect(sim.home().recentRows[0].exerciseCount == 1)
        }
    }

    @Test func softDeletingAWorkoutRemovesItFromHistoryHomeBodyRecapAndWidgets() throws {
        let sim = try twoWeeks()
        let w = try #require(sim.workout(onDay: 9))                           // week-1 pull, the newest
        sim.deleteWorkout(w)

        #expect(w.deletedAt != nil && w.isDirty)                              // tombstone for sync
        #expect(try sim.ctx.fetchCount(FetchDescriptor<Workout>()) == 4)      // still stored
        #expect(sim.historyRows().count == 3)
        #expect(sim.history().totalCount == 3 && sim.history().workoutsOn(sim.day(9)).isEmpty)
        #expect(sim.home().recentRows.count == 3 && sim.home().weekSets == 5)
        #expect(sim.body().selectedTotalSets == 5)
        #expect(sim.recap().setCount(sim.recap().week) == 5 && sim.recap().week.count == 1)
        #expect(sim.widget().fixed.setsThisWeek == 5 && sim.widget().fixed.lastWorkoutName == "Push Day")
        #expect(sim.progress(of: "Barbell Row").allSets.count == 3 && sim.progress(of: "Barbell Row").weightPR == 60)
        #expect(sim.body().daysSince(workoutNamed: "PULL") == "8D")           // the week-0 pull on day 2, today is day 10
    }

    @Test func theStreakFollowsDeletedWorkouts() throws {
        let sim = try twoWeeks()
        #expect(sim.streak() == 3)                                   // days 0,2 | 7,9: the 5-day gap breaks it -> 7..9
        sim.deleteWorkout(try #require(sim.workout(onDay: 9)))
        #expect(sim.streak() == 1)                                   // only day 7 (3 days ago: still alive)
        sim.deleteWorkout(try #require(sim.workout(onDay: 7)))
        #expect(sim.streak() == 0)                                   // days 0,2 are more than 3 days ago
    }

    @Test func deletingThePRSessionUndoesThePRAndTheNextSessionEarnsItAgain() throws {
        let sim = try twoWeeks()
        let pr = try #require(sim.workout(onDay: 7))
        sim.deleteWorkout(pr)
        #expect(sim.progress(of: Self.bench).weightPR == 60)
        #expect(sim.widget().prs[Self.bench]?.weight == 60)

        // Training again at 62.5 now counts as a new best, because the deleted session no longer stands in the way.
        sim.advance(days: 1)
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 62.5, 5, count: 3)
        let data = sim.finish()
        #expect(data.prCount == 1)
        #expect(data.prDetails.first?.weightDelta == 2.5)
    }

    @Test func aDeletedSessionNoLongerSuppliesTheGhostValuesForTheNextOne() throws {
        let sim = try twoWeeks()
        let benchId = sim.exercise(Self.bench).id
        #expect(sim.vm.ghostText(for: benchId, setIndex: 0, modelContext: sim.ctx)?.weight == "62.5")
        sim.deleteWorkout(try #require(sim.workout(onDay: 7)))
        #expect(sim.vm.ghostText(for: benchId, setIndex: 0, modelContext: sim.ctx)?.weight == "60")
    }

    @Test func aDeletedWorkoutIsExcludedFromTheWeeklyChallengeInputs() throws {
        let sim = try twoWeeks()
        func inputs() -> (sessions: Int, volume: Double, sets: Int) {
            let rows = sim.historyRows()
            return (rows.count, rows.reduce(0) { $0 + $1.workingVolume }, rows.reduce(0) { $0 + $1.workingSetCount })
        }
        let before = inputs()
        #expect(before.sessions == 4 && before.sets == 20)
        let gone = try #require(sim.workout(onDay: 9))
        let goneVolume = gone.workingVolume
        sim.deleteWorkout(gone)
        let after = inputs()
        #expect(after.sessions == 3 && after.sets == 15)
        #expect(abs(after.volume - (before.volume - goneVolume)) < 1e-9)
    }

    @Test func editingAWorkoutInPoundsStoresKilogramsAndDoesNotDriftOnReopen() throws {
        let sim = try UserSim(unit: .lbs)
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 135, 5, count: 3) }
        let w = sim.historyRows()[0]
        sim.editSet(w, Self.bench, setIndex: 0, weight: 140)                  // typed in lb
        let set = sim.log(of: w, Self.bench)!.sets.sorted { $0.order < $1.order }[0]
        #expect(abs(set.weight - 140 * 0.45359237) < 1e-9)
        #expect(sim.user.unitPreference.inputText(set.weight) == "140")      // what the field shows on reopening
        #expect(sim.user.unitPreference.number(sim.progress(of: Self.bench).weightPR) == "140")
    }

    @Test func aDeletedWorkoutStaysOutOfHistoryAfterANewSessionIsFinished() throws {
        let sim = try twoWeeks()
        sim.deleteWorkout(try #require(sim.workout(onDay: 2)))
        sim.advance(days: 1)
        sim.session(template: "Pull Day") { s in s.logSets("Barbell Row", 65, 5, count: 3) }
        #expect(sim.historyRows().count == 4)
        #expect(sim.historyRows().allSatisfy { $0.deletedAt == nil })
    }
}
