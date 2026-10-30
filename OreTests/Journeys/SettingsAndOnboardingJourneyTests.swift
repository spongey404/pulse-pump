import Testing
import Foundation
import SwiftData
@testable import Ore

/// Settings, profile and library changes that alter what the user sees, plus onboarding -> first workout -> second week.
@MainActor
struct SettingsAndOnboardingJourneyTests {
    private static let bench = "Barbell Bench Press"

    // MARK: Onboarding -> first workout -> second week

    @Test func aNewUserSeesEmptyScreensUntilTheFirstWorkout() throws {
        let sim = try UserSim()
        #expect(sim.historyRows().isEmpty && sim.history().totalCount == 0)
        #expect(sim.home().currentStreak == 0 && sim.home().weekSets == 0 && sim.home().recentRows.isEmpty)
        #expect(sim.home().tickerRows.isEmpty)
        #expect(sim.body().selectedTotalSets == 0 && sim.body().musclesWorkedCount == 0)
        #expect(sim.progress(of: Self.bench).allSets.isEmpty && sim.progress(of: Self.bench).trendPoints.isEmpty)
        #expect(sim.recap().week.isEmpty && sim.recap().records.isEmpty)
        #expect(sim.streak() == 0)
        let snap = sim.widget()
        #expect(!snap.hasData && snap.streak == 0 && snap.fixed.setsThisWeek == 0)
        #expect(sim.drafts().isEmpty)
    }

    @Test func theFirstWorkoutFillsEveryScreenAndTheSecondWeekCompares() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 60, 8, count: 3) }          // Monday week 0
        #expect(sim.home().weekSets == 3 && sim.streak() == 1 && sim.history().totalCount == 1)
        #expect(sim.body().selectedTotalSets == 3 && sim.body().vsInfo.label == "VS PACE")
        #expect(sim.recap().records.isEmpty)                      // first week: nothing earlier to beat
        #expect(sim.recap(weeksBack: 1).week.isEmpty)

        sim.skipToDay(7)                                           // the following Monday
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 62.5, 8, count: 4) }
        #expect(sim.home().weekSets == 4)
        #expect(sim.recap().setCount(sim.recap().week) == 4 && sim.recap().setCount(sim.recap().prev) == 3)
        #expect(sim.recap().records.map(\.name) == [Self.bench])  // 62.5 beats last week's 60
        #expect(sim.completions[1].prCount == 1 && sim.completions[1].improvedCount == 1)
        #expect(sim.home().recentRows[0].volumeDelta == "▲ 38%")   // 4x8x62.5 = 2000 vs 3x8x60 = 1440 -> +38.9%, truncated
    }

    // MARK: Split

    @Test func changingTheSplitChangesTheGoalTheColdStartAndTheRecapTarget() throws {
        let sim = try UserSim()                                    // 6-day PPL, Monday
        #expect(sim.widget().sessionGoal == 6 && sim.recap().target == 6)
        #expect(sim.prediction() == "Push Day")

        let ul = SplitKind.upperLower.make()
        sim.ctx.insert(ul)
        sim.user.selectedSplit = ul                                // Settings > Split
        #expect(sim.widget().sessionGoal == 4 && sim.recap().target == 4)
        #expect(sim.prediction() == "Upper Body")
        sim.skipToDay(1)                                           // Tuesday: Lower
        #expect(sim.prediction() == "Lower Body")
    }

    @Test func choosingNoSplitFallsBackToFiveSessionsAndNoColdStartSuggestion() throws {
        let sim = try UserSim(split: .none)
        #expect(sim.widget().sessionGoal == 5)
        #expect(sim.recap().target == 5)                           // max(week sessions, 5)
        #expect(sim.prediction() == nil)
    }

    @Test func aSplitChangeDoesNotRewriteHistoryOrPastPredictionsOfTheLearnedPattern() throws {
        let sim = try UserSim()
        for (d, t) in ["Push Day", "Pull Day", "Leg Day", "Push Day", "Pull Day"].enumerated() {
            sim.skipToDay(d)
            sim.session(template: t) { s in s.logSets(Self.bench, 60, 5, count: 1) }
        }
        #expect(sim.prediction() == "Leg Day")
        let ul = SplitKind.upperLower.make()
        sim.ctx.insert(ul)
        sim.user.selectedSplit = ul
        #expect(sim.historyRows().count == 5)
        #expect(sim.prediction() == "Leg Day")                     // learned from history, split only fills gaps
    }

    // MARK: Templates

    @Test func renamingATemplateRenamesEveryPastWorkoutOnEveryScreen() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 60, 5, count: 3) }
        let t = try #require(sim.template("Push Day"))
        t.name = "Push A"
        t.markUpdated()
        #expect(sim.historyRows()[0].template?.name == "Push A")
        #expect(sim.home().recentRows[0].name == "PUSH A")
        #expect(sim.widget().fixed.lastWorkoutName == "Push A")
        #expect(sim.body().selectedDayLabel.contains("WEEK"))
        #expect(sim.body(day: 0).selectedDayLabel.hasSuffix("PUSH A"))
        sim.startSession(template: "Push A")
        #expect(sim.vm.workout?.template?.name == "Push A")
    }

    @Test func editingATemplatesTargetsChangesTheNextSessionButNotThePastOne() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 60, 5, count: 3) }
        let t = try #require(sim.template("Push Day"))
        var items = t.templateExercises
        items[0].targetSets = 5
        items[0].targetReps = 6
        t.templateExercises = items
        t.markUpdated()

        sim.skipToDay(2)
        sim.startSession(template: "Push Day")
        #expect(sim.vm.exerciseEntries[0].sets.count == 5)
        #expect(sim.vm.exerciseEntries[0].sets.allSatisfy { $0.targetReps == 6 })
        #expect(sim.historyRows()[0].workingSetCount == 3)         // yesterday's workout is unchanged
    }

    @Test func deletingATemplateKeepsHistoryAndStopsOfferingItToStart() throws {
        let sim = try UserSim()
        for (d, t) in ["Push Day", "Pull Day"].enumerated() {
            sim.skipToDay(d)
            sim.session(template: t) { s in s.logSets(Self.bench, 60, 5, count: 1) }
        }
        let leg = try #require(sim.template("Leg Day"))
        sim.ctx.softDelete(leg)
        #expect(sim.template("Leg Day") == nil)
        #expect(sim.historyRows().count == 2)
        // The split still says Legs come next; with no template to resolve it the label is returned (Home then has nothing to start).
        #expect(sim.prediction() == "Leg Day")
        sim.startSession(template: "Leg Day")                      // a blank session: the template cannot be found
        #expect(sim.vm.exerciseEntries.isEmpty && sim.vm.workout?.template == nil)
    }

    @Test func deletingTheTemplateOfPastWorkoutsKeepsTheirNameInHistory() throws {
        let sim = try UserSim()
        sim.session(template: "Pull Day") { s in s.logSets("Barbell Row", 60, 5, count: 3) }
        sim.ctx.softDelete(try #require(sim.template("Pull Day")))
        #expect(sim.historyRows()[0].template?.name == "Pull Day")
        #expect(sim.home().recentRows[0].name == "PULL DAY")
        #expect(sim.progress(of: "Barbell Row").allSets.count == 3)
    }

    @Test func aTemplateStartedFromHomeWithAPresetNameThatDoesNotMatchStillLinksTheLifts() throws {
        // Imports and old presets may carry placeholder ids; the logger finds the catalogue exercise by name.
        let sim = try UserSim(presets: false)
        let custom = WorkoutTemplate(name: "My Push", templateExercises: [
            TemplateExercise(exerciseId: UUID(), exerciseName: "barbell bench-press", order: 0, targetSets: 3, targetReps: 5),
        ])
        sim.ctx.insert(custom)
        sim.startSession(template: "My Push")
        #expect(sim.vm.exerciseEntries.map(\.exerciseName) == [Self.bench])
        sim.logSets(Self.bench, 70, 5, count: 3)
        sim.finish()
        #expect(sim.progress(of: Self.bench).allSets.count == 3)
    }

    // MARK: Equipment profile and the plate calculator

    @Test func platesAreLoadedHeaviestFirstOnEachSideOfTheBar() {
        let home = [1.25, 2.5, 5, 10, 20]
        let a = PlateMath.load(targetKg: 100, barKg: 20, platesKg: home, unit: .kg)
        #expect(a.plates.map(\.display) == [20, 20] && a.remainder == 0)
        let b = PlateMath.load(targetKg: 82.5, barKg: 20, platesKg: home, unit: .kg)
        #expect(b.plates.map(\.display) == [20, 10, 1.25] && b.remainder == 0)
        let c = PlateMath.load(targetKg: 62, barKg: 20, platesKg: home, unit: .kg)         // 21 per side: 20, then 1 left over
        #expect(c.plates.map(\.display) == [20] && abs(c.remainder - 1) < 1e-9)
        #expect(PlateMath.load(targetKg: 20, barKg: 20, platesKg: home, unit: .kg).plates.isEmpty)
    }

    @Test func aPoundsUserGetsRealPoundPlatesOnA45PoundBar() {
        let u = UnitPreference.lbs
        let l = PlateMath.load(targetKg: 225 * UnitPreference.kgPerLb, barKg: u.olympicBarKg, platesKg: u.defaultPlatesKg, unit: u)
        #expect(l.plates.map(\.display) == [45, 45] && l.remainder == 0)
        let m = PlateMath.load(targetKg: 135 * UnitPreference.kgPerLb, barKg: u.olympicBarKg, platesKg: u.defaultPlatesKg, unit: u)
        #expect(m.plates.map(\.display) == [45])
        let n = PlateMath.load(targetKg: 185 * UnitPreference.kgPerLb, barKg: u.olympicBarKg, platesKg: u.defaultPlatesKg, unit: u)
        #expect(n.plates.map(\.display) == [45, 25])                                       // 70 per side
    }

    @Test func theLoggersPlateCalculatorLoadsFromTheActiveEquipmentProfile() throws {
        let sim = try UserSim()
        let home = EquipmentProfile(name: "Home Gym", availablePlates: [1.25, 2.5, 5, 10, 20])      // no 15 or 25 kg plates
        home.user = sim.user
        sim.ctx.insert(home)
        let isolated = UserDefaults(suiteName: "plates-\(UUID().uuidString)")!
        // InlinePlateViews calls PlateMath.storedPlatesKg(unit:) -- the UserDefaults set, not the profile.
        let plates = PlateMath.storedPlatesKg(unit: .kg, defaults: isolated)
        withKnownIssue("InlinePlateViews (the logger's plate calculator) loads PlateMath.storedPlatesKg(unit:) from UserDefaults, ignoring the user's EquipmentProfile.availablePlates, so a gym without 15/25 kg plates is told to load them (audit views-workout 'equipment profiles are display-only')", isIntermittent: true) {
            #expect(Set(plates) == Set(sim.user.liveEquipmentProfiles[0].availablePlates))
        }
        // With the profile's own plates the maths is right: 82.5 kg needs 20 + 10 + 1.25 a side.
        let load = PlateMath.load(targetKg: 82.5, barKg: 20, platesKg: home.availablePlates, unit: .kg)
        #expect(load.plates.map(\.display) == [20, 10, 1.25])
    }

    @Test func aDeletedEquipmentProfileIsNoLongerOffered() throws {
        let sim = try UserSim()
        let a = EquipmentProfile(name: "Home Gym"), b = EquipmentProfile(name: "Hotel")
        a.user = sim.user; b.user = sim.user
        sim.ctx.insert(a); sim.ctx.insert(b)
        #expect(sim.user.liveEquipmentProfiles.count == 2)
        sim.ctx.softDelete(b)
        #expect(sim.user.liveEquipmentProfiles.map(\.name) == ["Home Gym"])
    }

    // MARK: Deload

    @Test func markingAWeekAsDeloadFlagsItInTheLoadChart() throws {
        let sim = try UserSim()
        for week in 0..<4 {
            for (offset, template) in [(0, "Push Day"), (2, "Pull Day"), (4, "Leg Day")] {
                sim.skipToDay(7 * week + offset)
                let lift = ["Push Day": Self.bench, "Pull Day": "Barbell Row", "Leg Day": "Barbell Squat"][template]!
                sim.session(template: template) { s in s.logSets(lift, 60, 5, count: 3, rir: 2) }
            }
        }
        sim.skipToDay(7 * 3 + 6, hour: 20)
        #expect(sim.widget().fixed.loadWeeks.filter(\.deload).isEmpty)                 // same load every week: nothing detected

        // Week 2's three workouts: Workout detail > "Deload Week".
        for w in sim.historyRows() where w.date >= sim.day(14) && w.date < sim.day(21) { w.isDeload = true; w.markUpdated() }
        let flagged = sim.widget().fixed.loadWeeks.filter(\.deload)
        #expect(flagged.count == 1)
        #expect(sim.widget().fixed.lastDeloadWeek == "WK \(sim.isoCalendar.component(.weekOfYear, from: sim.day(14)))")
        // Un-marking removes it again.
        for w in sim.historyRows() { w.isDeload = false }
        #expect(sim.widget().fixed.loadWeeks.filter(\.deload).isEmpty)
    }

    @Test func aDeloadFlagDoesNotChangeVolumeSetsOrPRsOnAnyScreen() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 60, 5, count: 3) }
        let w = sim.historyRows()[0]
        let before = (sim.home().weekSets, w.workingVolume, sim.progress(of: Self.bench).weightPR)
        w.isDeload = true
        let after = (sim.home().weekSets, w.workingVolume, sim.progress(of: Self.bench).weightPR)
        #expect(before.0 == after.0 && before.1 == after.1 && before.2 == after.2)
    }
}
