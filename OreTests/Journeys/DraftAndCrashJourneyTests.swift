import Testing
import Foundation
import SwiftData
@testable import Ore

/// The app is killed, backgrounded, discarded or double-started mid-session.
@MainActor
struct DraftAndCrashJourneyTests {
    private static let bench = "Barbell Bench Press"

    @Test func killingTheAppMidSessionLeavesOneRecoverableDraft() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)
        sim.log(Self.bench, 80, 7)
        sim.crash()

        let drafts = sim.drafts()
        #expect(drafts.count == 1)
        #expect(drafts[0].exerciseLogs.count == 6)                  // every template exercise has a (so far empty) log
        #expect(sim.log(of: drafts[0], Self.bench)?.sets.count == 2)
        #expect(drafts[0].exerciseLogs.flatMap(\.sets).count == 2)
        #expect(!sim.vm.isActive)                                  // the new process has not resumed yet
        #expect(sim.historyRows().isEmpty)
    }

    @Test func resumingRestoresTheSetsAndTheSessionCanBeFinished() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)
        sim.log(Self.bench, 80, 7)
        sim.crash()
        sim.resumeDraft()

        #expect(sim.vm.isActive)
        let done = sim.vm.exerciseEntries[0].sets.filter(\.isCompleted)
        let weights: [String] = done.map { $0.weight }
        let reps: [String] = done.map { $0.reps }
        #expect(weights == ["80", "80"])
        #expect(reps == ["8", "7"])
        // Keep training where we left off, then finish.
        sim.log(Self.bench, 80, 6)
        sim.finish()

        let all = try sim.ctx.fetch(FetchDescriptor<Workout>())
        #expect(all.count == 1 && !all[0].isDraft)
        #expect(try sim.ctx.fetchCount(FetchDescriptor<ExerciseLog>()) == 1)
        #expect(try sim.ctx.fetchCount(FetchDescriptor<SetLog>()) == 3)
        #expect(all[0].workingVolume == 1680)
        #expect(sim.drafts().isEmpty)
    }

    @Test func elapsedTimeAndNotesSurviveTheKill() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.vm.workoutNotes = "shoulder tight"
        sim.log(Self.bench, 80, 8)
        sim.vm.elapsedSeconds = 900
        sim.vm.saveDraft()
        sim.crash()
        sim.resumeDraft()
        #expect(sim.vm.elapsedSeconds == 900)
        #expect(sim.vm.workoutNotes == "shoulder tight")
    }

    @Test func aDraftIsInvisibleToEveryStatWhileItWaits() throws {
        let sim = try UserSim()
        sim.session(template: "Pull Day") { s in s.logSets("Barbell Row", 70, 8, count: 3) }
        sim.skipToDay(1)
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 100, 5, count: 5)
        sim.crash()

        // History, Home, Body, recap, the exercise screen and the widget only know the finished Pull Day.
        #expect(sim.historyRows().count == 1)
        #expect(sim.home().weekSets == 3 && sim.home().recentRows.count == 1)
        #expect(sim.body().selectedTotalSets == 3)
        #expect(sim.recap().setCount(sim.recap().week) == 3)
        #expect(sim.progress(of: Self.bench).allSets.isEmpty)
        #expect(sim.widget().fixed.setsThisWeek == 3)
        #expect(sim.streak() == 1)
        // The draft's heaviest bench set must not become a "previous best" either.
        #expect(sim.vm.ghostText(for: sim.exercise(Self.bench).id, setIndex: 0, modelContext: sim.ctx) == nil)
    }

    @Test func discardingDeletesTheDraftAndItsSetsWithoutTouchingHistory() throws {
        let sim = try UserSim()
        sim.session(template: "Pull Day") { s in s.logSets("Barbell Row", 70, 8, count: 3) }
        let widgetsBefore = sim.widgetSnapshots.count
        sim.skipToDay(1)
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 100, 5, count: 3)
        sim.vm.cancelWorkout(modelContext: sim.ctx)

        #expect(sim.drafts().isEmpty)
        #expect(!sim.vm.isActive && sim.vm.workout == nil)
        #expect(sim.historyRows().count == 1)
        #expect(try sim.ctx.fetchCount(FetchDescriptor<ExerciseLog>()) == 1)
        #expect(try sim.ctx.fetchCount(FetchDescriptor<SetLog>()) == 3)       // only the Pull Day sets remain
        #expect(sim.widgetSnapshots.count == widgetsBefore)                  // discarding is not a finished workout
        #expect(sim.streak() == 1)
    }

    @Test func startingASecondSessionOverADraftReplacesItCompletely() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 100, 5, count: 3)
        sim.crash()
        #expect(sim.drafts().count == 1)

        sim.startSessionOverDraft(template: "Pull Day")        // "DISCARD + START NEW"
        #expect(sim.drafts().count == 1)
        #expect(sim.drafts()[0].template?.name == "Pull Day")
        #expect(try sim.ctx.fetchCount(FetchDescriptor<SetLog>()) == 0)         // the old draft's sets are gone
        sim.logSets("Barbell Row", 70, 8, count: 3)
        sim.finish()
        #expect(sim.historyRows().count == 1 && sim.historyRows()[0].template?.name == "Pull Day")
        #expect(sim.progress(of: Self.bench).allSets.isEmpty)
    }

    @Test func aDraftStartedLateAtNightKeepsItsStartDayWhenFinishedAfterMidnight() throws {
        // Mon 23:40: start, kill the app, come back Tue 00:30 and finish. The workout belongs to Monday.
        let sim = try UserSim(start: DateComponents(year: 2026, month: 1, day: 5, hour: 23, minute: 40))
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)
        sim.crash()
        sim.advance(minutes: 50)
        sim.resumeDraft()
        sim.log(Self.bench, 80, 8)
        sim.finish(minutes: 5)

        let w = sim.historyRows()[0]
        #expect(sim.calendar.isDate(w.date, inSameDayAs: sim.day(0)))
        #expect(sim.calendar.component(.weekday, from: w.date) == 2)            // Monday
        #expect(sim.home().weekDayBars[0] == 2)                                   // Monday's bar, even though it is Tuesday now
        #expect(sim.home().todayDayIndex == 1)
        #expect(sim.streak() == 1)
    }

    @Test func aTypedButUntickedSetIsNotPersistedAndTheRowsComeBackFromTheTemplate() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.vm.exerciseEntries[0].sets[0].weight = "80"           // typed but not ticked
        sim.crash()
        let draft = try #require(sim.drafts().first)
        #expect(draft.exerciseLogs.flatMap(\.sets).isEmpty)
        sim.resumeDraft()
        #expect(sim.vm.exerciseEntries.map { $0.sets.count } == [4, 3, 3, 3, 3, 3])    // padded back to the template's rows
        #expect(sim.vm.exerciseEntries[0].sets[0].weight.isEmpty)
        #expect(sim.vm.exerciseEntries.flatMap(\.sets).allSatisfy { !$0.isCompleted })
    }

    @Test func unloggingASetOnADraftRemovesItFromTheStoredDraft() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 80, 8, count: 3)
        sim.vm.unlogSet(exerciseIndex: 0, setIndex: 2)
        sim.crash()
        #expect(sim.log(of: sim.drafts()[0], Self.bench)?.sets.count == 2)
    }

    @Test func finishingTwiceInARowDoesNotDuplicateTheWorkout() throws {
        let sim = try UserSim()
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 80, 8, count: 2)
        let w = try #require(sim.vm.workout)
        sim.vm.elapsedSeconds = 600
        sim.vm.completeWorkout(modelContext: sim.ctx)
        sim.vm.completeWorkout(modelContext: sim.ctx)             // double tap on FINISH
        #expect(try sim.ctx.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(try sim.ctx.fetchCount(FetchDescriptor<SetLog>()) == 2)
        #expect(w.workingSetCount == 2)
        #expect(sim.widgetSnapshots.count == 2)                    // refreshed twice, harmlessly: same content
        #expect(sim.widgetSnapshots[0].fixed.setsThisWeek == sim.widgetSnapshots[1].fixed.setsThisWeek)
    }
}
