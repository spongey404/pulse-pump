import Testing
import Foundation
import CoreGraphics
import SwiftData
@testable import Ore

/// The logger of Ore Logger 1a: stepping, hold-and-drag, plates, prefill and auto progression, set types, replace, superset, finish.
@MainActor
struct LoggerTests {
    // MARK: Pure rules

    @Test func stepsAreWholeEighteenPointSteps() {
        #expect(LoggerMath.steps(dragUp: 17) == 0)
        #expect(LoggerMath.steps(dragUp: 18) == 1)
        #expect(LoggerMath.steps(dragUp: 37) == 2)
        #expect(LoggerMath.steps(dragUp: -19) == -1)
        #expect(LoggerMath.scrubbed(base: 60, dragUp: 54, step: 2.5) == 67.5)
        #expect(LoggerMath.scrubbed(base: 5, dragUp: -200, step: 2.5) == 0)         // never below zero
    }

    @Test func slidingRightSwitchesKgToFineSteps() {
        var t = LoggerMath.ScrubTracker(base: 60, isKg: true, step: 2.5, fineStep: 1.25)
        t.update(dragUp: 36, slideRight: 0)
        #expect(t.value == 65 && !t.fine)
        t.update(dragUp: 36, slideRight: 41)                  // switch: counted from 65, from here
        #expect(t.fine && t.value == 65)
        t.update(dragUp: 36 + 18, slideRight: 41)
        #expect(t.value == 66.25)
        var reps = LoggerMath.ScrubTracker(base: 8, isKg: false, step: 1, fineStep: 1)
        reps.update(dragUp: 36, slideRight: 100)               // reps never go fine
        #expect(!reps.fine && reps.value == 10)
    }

    @Test func kgStepsFollowTheUnit() {
        #expect(LoggerMath.kgStep(.kg) == 2.5 && LoggerMath.kgStep(.kg, fine: true) == 1.25)
        #expect(LoggerMath.kgStep(.lbs) == 5 && LoggerMath.kgStep(.lbs, fine: true) == 2.5)
    }

    @Test func equipmentLabels() {
        let weighted = LoggerMath.load(equipment: .bodyweight, exerciseType: .weighted, name: "Weighted Pull Up")
        #expect(weighted == .weightedBodyweight && weighted.header(unit: "KG") == "+KG" && weighted.format("7.5") == "+7.5")
        let assisted = LoggerMath.load(equipment: .machine, exerciseType: .weighted, name: "Assisted Pull Up")
        #expect(assisted == .assisted && assisted.header(unit: "KG") == "−KG" && assisted.format("20") == "−20")
        #expect(LoggerMath.load(equipment: .dumbbell, exerciseType: .weighted, name: "Hammer Curl").header(unit: "KG") == "KG / HAND")
        #expect(LoggerMath.load(equipment: .barbell, exerciseType: .weighted, name: "Barbell Row") == .standard)
        #expect(LoggerMath.load(equipment: .bodyweight, exerciseType: .bodyweight, name: "Pull Up") == .standard)
    }

    @Test func liveOneRepMaxOnlyShowsWhenBeaten() {
        let none = LoggerMath.liveBest(history: 100, logged: [(60, 8)], assisted: false)       // 76
        #expect(!none.beat && none.value == 100)
        let beat = LoggerMath.liveBest(history: 80, logged: [(100, 5)], assisted: false)       // 116.7
        #expect(beat.beat && abs(beat.value - 116.67) < 0.01)
        #expect(!LoggerMath.liveBest(history: 0, logged: [(40, 10)], assisted: true).beat)    // assisted: no 1RM
    }

    @Test func plateStacksAndChanges() {
        #expect(LoggerMath.plateStack(totalKg: 100, barKg: 20) == [25, 15])
        #expect(LoggerMath.plateStack(totalKg: 62.5, barKg: 20) == [20, 1.25])
        #expect(LoggerMath.plateStack(totalKg: 20, barKg: 20).isEmpty)
        let c = LoggerMath.plateChange(from: [25, 10, 2.5], to: [25, 15])
        #expect(c.takeOff == [10, 2.5] && c.putOn == [15] && !c.none)
        #expect(LoggerMath.plateChange(from: [20], to: [20]).none)
        #expect(LoggerMath.plateChange(from: [], to: [25, 5]).putOn == [25, 5])
    }

    @Test func plateColoursAreTheIPFTokens() {
        #expect(LoggerMath.plateStyle(25).fill == "#E51B1B" && LoggerMath.plateStyle(20).fill == "#1F4EA3")
        #expect(LoggerMath.plateStyle(15).fill == "#F2C200" && LoggerMath.plateStyle(15).text == "#151A21")
        #expect(LoggerMath.plateStyle(10).fill == "#1F8F5A")
        #expect(LoggerMath.plateStyle(5).fill == "#F4F4F2" && LoggerMath.plateStyle(5).border != nil)
        #expect(LoggerMath.plateStyle(2.5).fill == "#151515" && LoggerMath.plateStyle(2.5).text == "#FFFFFF")
        #expect(LoggerMath.plateStyle(1.25).border != nil)
        #expect(LoggerMath.bars.map(\.name) == ["BARBELL", "EZ", "TRAP", "SAFETY", "LIGHT"] && LoggerMath.bars.map(\.kg) == [20, 7.5, 25, 32, 15])
        #expect(PlateMath.barOptions.map(\.name) == ["BARBELL", "EZ", "TRAP", "SAFETY", "LIGHT"])
    }

    @Test func autoProgressionPrefill() {
        let p = LoggerMath.ProgressionConfig(enabled: true, reps: 8, incrementKg: 2.5)
        #expect(LoggerMath.isBumped(p, previousLoggedReps: 8, lastTimeReps: 5))             // the set before reached it
        #expect(!LoggerMath.isBumped(p, previousLoggedReps: 6, lastTimeReps: 9))            // it didn't, whatever last time did
        #expect(LoggerMath.isBumped(p, previousLoggedReps: nil, lastTimeReps: 8))           // nothing logged yet: last time's reps
        #expect(!LoggerMath.isBumped(.off, previousLoggedReps: 12, lastTimeReps: 12))
        #expect(LoggerMath.prefillKg(p, lastTimeKg: 60, previousLoggedKg: 65, bumped: true) == 67.5)
        #expect(LoggerMath.prefillKg(p, lastTimeKg: 60, previousLoggedKg: nil, bumped: false) == 60)
    }

    @Test func dropsRoundsAndTotals() {
        #expect(LoggerMath.dropWeights(from: 100) == [80, 65])
        #expect(LoggerMath.dropWeights(from: 62.5) == [50, 40])
        #expect(LoggerMath.restPauseReps(from: 12) == [4, 3])
        #expect(LoggerMath.totalReps(main: 10, subs: [8, 6], type: .dropset) == 24)
        #expect(LoggerMath.totalReps(main: 0, subs: [10, 9], type: .leftRight) == 19)
        #expect(LoggerMath.totalReps(main: 10, subs: [], type: .standard) == 10)
        let avg = LoggerMath.averageKg(mainKg: 100, mainReps: 10, drops: [(80, 8), (65, 6)])
        #expect(abs(avg * 24 - (1000 + 640 + 390)) < 0.001)                                 // volume stays exact
    }

    @Test func finishBarAndModalText() {
        #expect(LoggerMath.fill(done: 3, total: 12) == 0.25 && LoggerMath.fill(done: 0, total: 0) == 0)
        #expect(LoggerMath.leftLabel(done: 9, total: 12) == "3 LEFT" && LoggerMath.leftLabel(done: 12, total: 12) == "ALL DONE ›")
        #expect(LoggerMath.finishMessage(unlogged: 4) == "4 sets aren't logged and will be left out. Only logged sets count toward your body map.")
        #expect(LoggerMath.finishMessage(unlogged: 0) == "Every set is logged.")
    }

    @Test func keypadBuffer() {
        #expect(KeypadBuffer.apply("7", to: "", allowsDecimal: true) == "7")
        #expect(KeypadBuffer.apply(".", to: "", allowsDecimal: true) == "0.")
        #expect(KeypadBuffer.apply(".", to: "12.5", allowsDecimal: true) == "12.5")           // one point only
        #expect(KeypadBuffer.apply(".", to: "8", allowsDecimal: false) == "8")                // reps have none
        #expect(KeypadBuffer.apply("⌫", to: "82.5", allowsDecimal: true) == "82.")
        #expect(KeypadBuffer.apply("1", to: "123456", allowsDecimal: true) == "123456")       // six characters
        #expect(KeypadBuffer.value("") == nil && KeypadBuffer.value(".") == nil && KeypadBuffer.value("0.") == 0)
    }

    // MARK: View model

    private func active() throws -> (WorkoutDraftTests.Fixture, Int) {
        let f = try WorkoutDraftTests.fixture()
        f.vm.settings = UserDefaults(suiteName: "logger-\(UUID().uuidString)")!
        f.vm.hasPlusAccess = { true }
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        f.vm.addExercise(f.bench)
        return (f, 0)
    }

    @Test func steppingMakesAGhostSolidAndKeepsItInTheUnit() throws {
        let (f, ei) = try active()
        WorkoutDraftTests.addHistory(f, f.bench, daysAgo: 7, sets: [(60, 8, .standard)])
        f.vm.step(.weight, by: 2.5, exerciseIndex: ei, setIndex: 0, modelContext: f.ctx, unit: .kg)
        #expect(f.vm.exerciseEntries[ei].sets[0].weight == "62.5")
        f.vm.step(.reps, by: -1, exerciseIndex: ei, setIndex: 0, modelContext: f.ctx, unit: .kg)
        #expect(f.vm.exerciseEntries[ei].sets[0].reps == "7")
        f.vm.step(.weight, by: -1000, exerciseIndex: ei, setIndex: 0, modelContext: f.ctx, unit: .kg)
        #expect(f.vm.exerciseEntries[ei].sets[0].weight == "0")
        // Pounds: a 5 lb step on 100 kg (220.5 lb) is shown as 225.5 and stored as kg.
        f.vm.setValue(.weight, 100, exerciseIndex: ei, setIndex: 0)
        f.vm.step(.weight, by: 5, exerciseIndex: ei, setIndex: 0, modelContext: f.ctx, unit: .lbs)
        let kg = Double(f.vm.exerciseEntries[ei].sets[0].weight) ?? 0
        #expect(abs(UnitPreference.lbs.display(kg) - (UnitPreference.lbs.display(100) + 5)) < 0.01)
    }

    @Test func aNewSetCarriesTheRowAboveWhenNoHistoryReachesIt() throws {
        let (f, ei) = try active()
        f.vm.exerciseEntries[ei].sets[0].weight = "80"; f.vm.exerciseEntries[ei].sets[0].reps = "5"
        f.vm.addSet(to: ei)
        let g = f.vm.ghost(exerciseIndex: ei, setIndex: 1, modelContext: f.ctx)
        #expect(g == WorkoutViewModel.LoggerGhost(weight: "80", reps: "5", bumped: false))
    }

    @Test func autoProgressionBumpsTheNextSessionPrefillAndShowsItBlue() throws {
        let (f, ei) = try active()
        f.user.setProgressionThreshold(8, forExercise: f.bench.name)
        WorkoutDraftTests.addHistory(f, f.bench, daysAgo: 7, sets: [(60, 8, .standard), (60, 6, .standard)])
        let first = f.vm.ghost(exerciseIndex: ei, setIndex: 0, modelContext: f.ctx)
        #expect(first?.weight == "62.5" && first?.bumped == true)           // last time's set 1 reached 8
        f.vm.addSet(to: ei)
        let second = f.vm.ghost(exerciseIndex: ei, setIndex: 1, modelContext: f.ctx)
        #expect(second?.bumped == false)                                    // last time's set 2 did not
        f.vm.setProgression(.init(enabled: false, reps: 8, incrementKg: 5), exerciseIndex: ei, modelContext: f.ctx)
        #expect(f.vm.progressionConfig(exerciseIndex: ei).enabled == false)
        f.vm.setProgression(.init(enabled: true, reps: 6, incrementKg: 5), exerciseIndex: ei, modelContext: f.ctx)
        #expect(f.vm.progressionConfig(exerciseIndex: ei) == .init(enabled: true, reps: 6, incrementKg: 5))
    }

    @Test func dropSetsAddLinesAndLogAsOneSetWithSummedReps() throws {
        let (f, ei) = try active()
        f.vm.exerciseEntries[ei].sets[0].weight = "100"; f.vm.exerciseEntries[ei].sets[0].reps = "10"
        f.vm.setSetType(.dropset, exerciseIndex: ei, setIndex: 0, modelContext: f.ctx, unit: .kg)
        let subs = f.vm.exerciseEntries[ei].sets[0].subs
        #expect(subs.map(\.ghostWeight) == ["80", "65"] && subs.map(\.ghostReps) == ["10", "10"])
        f.vm.addSub(exerciseIndex: ei, setIndex: 0, unit: .kg)
        #expect(f.vm.exerciseEntries[ei].sets[0].subs.count == 3)
        f.vm.removeSub(exerciseIndex: ei, setIndex: 0, subIndex: 2)
        f.vm.exerciseEntries[ei].sets[0].subs[0].reps = "8"
        f.vm.logSet(exerciseIndex: ei, setIndex: 0, modelContext: f.ctx)
        let set = f.vm.exerciseEntries[ei].sets[0]
        #expect(set.isCompleted && set.loggedReps == 28)                    // 10 + 8 + 10
        #expect(set.subs.allSatisfy { !$0.weight.isEmpty && !$0.reps.isEmpty })
        f.vm.persistDraft(modelContext: f.ctx)
        let stored = try #require(f.vm.workout?.exerciseLogs.first?.sets.first)
        #expect(f.vm.workout?.exerciseLogs.first?.sets.count == 1)          // one set
        #expect(stored.reps == 28 && stored.setType == .dropset)
        #expect(abs(stored.weight * 28 - (1000 + 640 + 650)) < 0.01)        // volume exact
    }

    @Test func restPauseAndUnilateralLines() throws {
        let (f, ei) = try active()
        f.vm.exerciseEntries[ei].sets[0].weight = "50"; f.vm.exerciseEntries[ei].sets[0].reps = "12"
        f.vm.setSetType(.restPause, exerciseIndex: ei, setIndex: 0, modelContext: f.ctx, unit: .kg)
        #expect(f.vm.exerciseEntries[ei].sets[0].subs.map(\.ghostReps) == ["4", "3"])
        f.vm.addSet(to: ei)
        f.vm.exerciseEntries[ei].sets[1].weight = "20"; f.vm.exerciseEntries[ei].sets[1].reps = "10"
        f.vm.setSetType(.leftRight, exerciseIndex: ei, setIndex: 1, modelContext: f.ctx, unit: .kg)
        let uni = f.vm.exerciseEntries[ei].sets[1].subs
        #expect(uni.count == 2 && uni.map(\.ghostReps) == ["10", "10"])
        f.vm.removeSub(exerciseIndex: ei, setIndex: 1, subIndex: 0)         // left and right cannot be removed
        #expect(f.vm.exerciseEntries[ei].sets[1].subs.count == 2)
        // Back to standard clears the lines.
        f.vm.setSetType(.standard, exerciseIndex: ei, setIndex: 1, modelContext: f.ctx, unit: .kg)
        #expect(f.vm.exerciseEntries[ei].sets[1].subs.isEmpty)
    }

    @Test func toFailureLocksRIRAtZeroWhenRIRIsOn() throws {
        let (f, ei) = try active()
        f.vm.exerciseEntries[ei].rirOn = true
        f.vm.exerciseEntries[ei].sets[0].weight = "70"; f.vm.exerciseEntries[ei].sets[0].reps = "6"; f.vm.exerciseEntries[ei].sets[0].rir = "3"
        f.vm.setSetType(.failureSet, exerciseIndex: ei, setIndex: 0, modelContext: f.ctx, unit: .kg)
        #expect(f.vm.exerciseEntries[ei].sets[0].rir == "0")
        f.vm.logSet(exerciseIndex: ei, setIndex: 0, modelContext: f.ctx)
        #expect(f.vm.exerciseEntries[ei].sets[0].rir == "0")
    }

    @Test func supersetPairsWithTheNextExercise() throws {
        let (f, ei) = try active()
        f.vm.addExercise(f.row)
        f.vm.toggleSuperset(exerciseIndex: ei)
        #expect(f.vm.exerciseEntries[0].supersetGroup == "A" && f.vm.exerciseEntries[1].supersetGroup == "A")
        f.vm.toggleSuperset(exerciseIndex: 1)                                // removing from either takes both out
        #expect(f.vm.exerciseEntries.allSatisfy { $0.supersetGroup == nil })
        f.vm.toggleSuperset(exerciseIndex: 1)                                // the last exercise has nothing to pair with
        #expect(f.vm.exerciseEntries[1].supersetGroup == nil)
        f.vm.setSetType(.superset, exerciseIndex: 0, setIndex: 0, modelContext: f.ctx, unit: .kg)   // the SS set type does the same
        #expect(f.vm.exerciseEntries[0].supersetGroup == "A")
    }

    @Test func replacingWithNothingLoggedSwapsInPlace() throws {
        let (f, ei) = try active()
        f.vm.addSet(to: ei); f.vm.addSet(to: ei)
        f.vm.exerciseEntries[ei].sets[0].weight = "50"
        let kind = f.vm.replaceExerciseKeepingData(at: ei, with: f.row)
        #expect(kind == .swap && f.vm.exerciseEntries.count == 1)
        #expect(f.vm.exerciseEntries[0].exerciseName == "Barbell Row" && f.vm.exerciseEntries[0].sets.count == 3)
        #expect(f.vm.exerciseEntries[0].sets.allSatisfy { $0.weight.isEmpty && $0.reps.isEmpty })     // fresh prefills
        #expect(f.vm.exerciseEntries[0].familyName == "Barbell Bench Press")                          // so it can be swapped back
    }

    @Test func replacingWithSomeLoggedSwitchesAndNeverDeletesLoggedSets() throws {
        let (f, ei) = try active()
        f.vm.addSet(to: ei); f.vm.addSet(to: ei)
        f.vm.exerciseEntries[ei].sets[0].weight = "80"; f.vm.exerciseEntries[ei].sets[0].reps = "5"
        f.vm.logSet(exerciseIndex: ei, setIndex: 0, modelContext: f.ctx)
        let kind = f.vm.replaceExerciseKeepingData(at: ei, with: f.row)
        #expect(kind == .switchUnlogged && f.vm.exerciseEntries.count == 2)
        #expect(f.vm.exerciseEntries[0].exerciseName == "Barbell Bench Press" && f.vm.exerciseEntries[0].sets.count == 1 && f.vm.exerciseEntries[0].sets[0].isCompleted)
        #expect(f.vm.exerciseEntries[1].exerciseName == "Barbell Row" && f.vm.exerciseEntries[1].sets.count == 2)   // the 2 unlogged moved below
        // Every set logged: the new exercise still gets a set.
        let (g, gi) = try active()
        g.vm.exerciseEntries[gi].sets[0].weight = "80"; g.vm.exerciseEntries[gi].sets[0].reps = "5"
        g.vm.logSet(exerciseIndex: gi, setIndex: 0, modelContext: g.ctx)
        _ = g.vm.replaceExerciseKeepingData(at: gi, with: g.row)
        #expect(g.vm.exerciseEntries[1].sets.count == 1)
    }

    @Test func unloggedCountsDriveTheFinishBar() throws {
        let (f, ei) = try active()
        f.vm.addSet(to: ei)
        #expect(f.vm.totalSetCount == 2 && f.vm.unloggedSetCount == 2)
        f.vm.exerciseEntries[ei].sets[0].weight = "50"; f.vm.exerciseEntries[ei].sets[0].reps = "5"
        f.vm.logSet(exerciseIndex: ei, setIndex: 0, modelContext: f.ctx)
        #expect(f.vm.unloggedSetCount == 1)
    }
}
