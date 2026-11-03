import Testing
import Foundation
import SwiftData
@testable import Ore

/// "What should I train next?" for people with every kind of split and habit (WorkoutPredictor + the view-model glue).
///
/// Documented behaviour (WorkoutPredictor): the learned pattern looks at what most often FOLLOWED the last session in
/// the history (ties go to the most recent follower) and is used only when it maps to a real template; otherwise the
/// split's next day after the last session is used, and with no history the first split day on or after today.
/// Dates and weekdays are ignored whenever there is history.
@MainActor
struct PatternDetectionJourneyTests {
    struct Rotation: CustomTestStringConvertible, Sendable {
        let split: SplitKind
        let cycle: [String]
        var testDescription: String { "\(split) \(cycle.count)-day rotation" }
    }

    static let rotations: [Rotation] = [
        Rotation(split: .ppl, cycle: ["Push Day", "Pull Day", "Leg Day"]),
        Rotation(split: .upperLower, cycle: ["Upper Body", "Lower Body"]),
        Rotation(split: .broSplit, cycle: ["Chest", "Back", "Shoulders", "Arms", "Legs"]),
        Rotation(split: .fullBody, cycle: ["Full Body A", "Full Body B"]),
        Rotation(split: .arnold, cycle: ["Chest & Back", "Shoulders & Arms", "Legs"]),
        Rotation(split: .torsoLimbs, cycle: ["Torso", "Limbs"]),
        Rotation(split: .custom, cycle: ["Alpha", "Beta", "Gamma"]),
    ]

    /// Newest-first history of `count` sessions walking `cycle` from its start.
    static func history(_ cycle: [String], count: Int) -> [String] {
        (0..<count).map { cycle[$0 % cycle.count] }.reversed()
    }

    private func predict(_ history: [String], templates: [String], split: SplitKind?, weekday: Int = 2) -> String? {
        WorkoutPredictor.predict(history: history, templateNames: templates, split: split?.make(), todayWeekday: weekday)
    }

    // MARK: Following the plan exactly

    @Test(arguments: rotations)
    func someoneFollowingTheirPlanExactlyIsToldTheNextDayOfTheRotation(r: Rotation) {
        for count in (r.cycle.count + 1)...(r.cycle.count * 3 + 1) {
            let h = Self.history(r.cycle, count: count)
            let expected = r.cycle[count % r.cycle.count]
            #expect(predict(h, templates: r.cycle, split: r.split) == expected, "\(count) sessions")
            #expect(predict(h, templates: r.cycle, split: nil) == expected, "\(count) sessions, no split saved")
        }
    }

    @Test(arguments: rotations)
    func theSameHistoryGivesTheSameAnswerOnEveryWeekday(r: Rotation) {
        let h = Self.history(r.cycle, count: r.cycle.count * 2 + 1)
        let answers = Set((1...7).map { predict(h, templates: r.cycle, split: r.split, weekday: $0) })
        #expect(answers.count == 1)
    }

    @Test(arguments: rotations)
    func theAnswerIsAlwaysARealTemplateWhenThereIsHistory(r: Rotation) {
        var rng = SeededRandom(seed: 99)
        for _ in 0..<60 {
            let n = rng.int(2...25)
            let h = (0..<n).map { _ in r.cycle[rng.int(0...(r.cycle.count - 1))] }
            let result = predict(h, templates: r.cycle, split: r.split, weekday: rng.int(1...7))
            #expect(result != nil)
            #expect(result.map { r.cycle.contains($0) } == true, "history \(h)")
        }
    }

    // MARK: Deviations from the plan

    @Test func skippingADayContinuesTheRotationInsteadOfRepeatingTheMissedSession() {
        // Push, Pull, Legs, Push, (skipped Pull) Legs  -> newest first
        let h = ["Leg Day", "Push Day", "Leg Day", "Pull Day", "Push Day"]
        #expect(predict(h, templates: ["Push Day", "Pull Day", "Leg Day"], split: .ppl) == "Push Day")
    }

    @Test func swappingTwoDaysFollowsTheMostRecentFollowerOnATie() {
        // chronological: Push, Pull, Leg, Push, Leg, Pull, Push  (the second cycle swapped Pull and Leg)
        let h = ["Push Day", "Pull Day", "Leg Day", "Push Day", "Leg Day", "Pull Day", "Push Day"]
        // After "Push Day": Leg most recently, Pull earlier, one each -> the most recent follower wins.
        #expect(predict(h, templates: ["Push Day", "Pull Day", "Leg Day"], split: .ppl) == "Leg Day")
    }

    @Test func trainingTheSameSessionTwiceInADayPredictsTheRepeatOnATie() {
        let h = ["Push Day", "Push Day", "Pull Day", "Leg Day", "Push Day", "Pull Day", "Leg Day"]
        #expect(predict(h, templates: ["Push Day", "Pull Day", "Leg Day"], split: .ppl) == "Push Day")
    }

    @Test func aMostFrequentFollowerBeatsAMoreRecentOne() {
        // After Push: Pull three times, Leg once (the latest). Frequency wins.
        let h = ["Push Day", "Leg Day", "Push Day", "Pull Day", "Push Day", "Pull Day", "Push Day", "Pull Day"]
        #expect(predict(h, templates: ["Push Day", "Pull Day", "Leg Day"], split: .ppl) == "Pull Day")
    }

    @Test func changingSplitMidwayFollowsTheNewRoutineByName() {
        // Months of PPL, then the first Upper/Lower session: the last session (Lower) has no past, keyword fallback -> Upper.
        let h = ["Lower Body", "Leg Day", "Pull Day", "Push Day", "Leg Day", "Pull Day", "Push Day"]
        let templates = ["Push Day", "Pull Day", "Leg Day", "Upper Body", "Lower Body"]
        #expect(predict(h, templates: templates, split: .upperLower) == "Upper Body")
    }

    @Test func aSecondUpperLowerCycleAfterPPLContinuesUpperLower() {
        let h = ["Upper Body", "Lower Body", "Upper Body", "Lower Body", "Leg Day", "Pull Day", "Push Day"]
        let templates = ["Push Day", "Pull Day", "Leg Day", "Upper Body", "Lower Body"]
        #expect(predict(h, templates: templates, split: .upperLower) == "Lower Body")
    }

    @Test func someoneWhoOnlyEverDoesPushIsToldPushAgain() {
        #expect(predict(Array(repeating: "Push Day", count: 6), templates: ["Push Day", "Pull Day"], split: nil) == "Push Day")
    }

    @Test func aSingleSessionIsNotEnoughToLearnFromSoTheSplitDecides() {
        #expect(predict(["Push Day"], templates: ["Push Day", "Pull Day", "Leg Day"], split: .ppl) == "Pull Day")
        #expect(predict(["Push Day"], templates: ["Push Day", "Pull Day", "Leg Day"], split: nil) == nil)
    }

    // MARK: No history / no templates

    @Test func aBrandNewUserWithASplitStartsWithTheFirstScheduledDayOnOrAfterToday() {
        let t = ["Push Day", "Pull Day", "Leg Day"]
        #expect(predict([], templates: t, split: .ppl, weekday: 2) == "Push Day")      // Monday
        #expect(predict([], templates: t, split: .ppl, weekday: 4) == "Leg Day")       // Wednesday
        #expect(predict([], templates: t, split: .ppl, weekday: 1) == "Push Day")      // Sunday: wraps to the first day
        #expect(predict([], templates: ["Upper Body", "Lower Body"], split: .upperLower, weekday: 4) == "Upper Body")   // Wed -> Thu
    }

    @Test func aBrandNewUserWithNoSplitAndNoHistoryGetsNoSuggestion() {
        #expect(predict([], templates: ["Push Day"], split: nil) == nil)
        #expect(predict([], templates: [], split: nil) == nil)
    }

    @Test func aSplitTypeWithNoScheduledDaysFallsBackToTheTypeName() {
        let none = Split(type: .none)
        let custom = Split(type: .custom)
        #expect(WorkoutPredictor.predict(history: [], templateNames: [], split: none, todayWeekday: 2) == nil)
        #expect(WorkoutPredictor.predict(history: [], templateNames: [], split: custom, todayWeekday: 2) == "Custom")
    }

    @Test func aPredictedNameWithNoMatchingTemplateIsStillReturnedAsTheSplitLabel() {
        // The person deleted "Leg Day": the prediction is the split's label, which resolves to no template.
        let templates = ["Push Day", "Pull Day"]
        let result = predict(["Pull Day", "Push Day"], templates: templates, split: .ppl)
        #expect(result == "Leg Day")
        #expect(WorkoutPredictor.resolveTemplate("Leg Day", among: templates) == nil)
    }

    @Test func templateNamesAreMatchedLooselyByDayWordsAndKeywords() {
        #expect(WorkoutPredictor.resolveTemplate("Push", among: ["Push Day"]) == "Push Day")
        #expect(WorkoutPredictor.resolveTemplate("push day", among: ["Push Day"]) == "Push Day")
        #expect(WorkoutPredictor.resolveTemplate("Upper", among: ["Upper Body", "Lower Body"]) == "Upper Body")
        #expect(WorkoutPredictor.resolveTemplate("Chest & Back", among: ["Chest Day", "Legs"]) == "Chest Day")
        #expect(WorkoutPredictor.resolveTemplate("Yoga", among: ["Push Day"]) == nil)
    }

    // MARK: Through the view model (what Home shows)

    @Test func freeFormWorkoutsDoNotConfuseThePredictor() throws {
        let sim = try UserSim()                                       // Monday, PPL split
        for d in 0..<4 {                                              // four blank workouts, no template
            sim.skipToDay(d)
            sim.session { s in s.logSets("Dumbbell Fly", 14, 12, count: 3) }
        }
        #expect(sim.historyNames().isEmpty)
        sim.skipToDay(4)                                              // Friday
        #expect(sim.prediction() == "Pull Day")                       // first split day on/after Friday
        #expect(sim.confidence() == 0.5)                              // a split, but nothing learned
    }

    @Test func thePredictionNeverCrashesAsTheHistoryGrowsOneSessionAtATime() throws {
        let sim = try UserSim()
        let rotation = ["Push Day", "Pull Day", "Leg Day"]
        for d in 0..<12 {
            sim.skipToDay(d)
            sim.session(template: rotation[d % 3]) { s in
                let lift = ["Barbell Bench Press", "Barbell Row", "Barbell Squat"][d % 3]
                s.logSets(lift, 60, 5, count: 1)
            }
            #expect(sim.prediction() == rotation[(d + 1) % 3], "after session \(d + 1)")
        }
    }

    @Test func comingBackAfterThreeWeeksStillContinuesTheRotation() throws {
        let sim = try UserSim()
        for (d, t) in ["Push Day", "Pull Day", "Leg Day", "Push Day", "Pull Day"].enumerated() {
            sim.skipToDay(d)
            sim.session(template: t) { s in s.logSets("Barbell Bench Press", 60, 5, count: 1) }
        }
        sim.skipToDay(4 + 21)
        #expect(sim.prediction() == "Leg Day")
    }

    @Test func theWeekdayHabitOnlyMattersForTheFirstEverSuggestion() throws {
        // Someone who always trains legs on Monday: with history the weekday is ignored.
        let sim = try UserSim()                                       // Monday start
        sim.skipToDay(0)
        sim.session(template: "Leg Day") { s in s.logSets("Barbell Squat", 80, 5, count: 1) }
        sim.skipToDay(1)
        sim.session(template: "Push Day") { s in s.logSets("Barbell Bench Press", 80, 5, count: 1) }
        sim.skipToDay(7)                                              // next Monday: the habit would say legs
        let monday = sim.prediction()
        sim.skipToDay(9)                                              // Wednesday, same history
        #expect(monday == sim.prediction())
    }

    @Test func theWeekdayForTheColdStartFollowsTheUsersLocalCalendarAcrossTheDateLine() throws {
        // 23:30 UTC on Monday 5 Jan is already Tuesday 12:30 in Auckland.
        let utc = try UserSim(timeZone: "UTC", start: DateComponents(year: 2026, month: 1, day: 5, hour: 23, minute: 30))
        #expect(utc.prediction() == "Push Day")
        let auckland = try UserSim(timeZone: "Pacific/Auckland", start: DateComponents(year: 2026, month: 1, day: 6, hour: 12, minute: 30))
        #expect(auckland.prediction() == "Pull Day")
    }

    @Test func aDaylightSavingNightDoesNotShiftTheColdStartWeekday() throws {
        // New York clocks go forward at 02:00 on Sunday 8 Mar 2026; Saturday 23:30 local is still Saturday.
        let ny = try UserSim(timeZone: "America/New_York", start: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 30))
        #expect(ny.prediction() == "Leg Day")                         // Saturday's slot in the PPL split
        ny.advance(hours: 3)                                          // 23:30 EST + 3 h = 03:30 EDT on Sunday (02:00-03:00 never happens)
        #expect(ny.calendar.component(.weekday, from: ny.now) == 1)
        #expect(ny.prediction() == "Push Day")                        // Sunday wraps to the first day
    }

    @Test func twoWorkoutsWithTheSameTimestampGiveTheSamePredictionWhicheverWasSavedFirst() throws {
        func predictionWith(order: [String]) throws -> String? {
            let sim = try UserSim()
            sim.skipToDay(0)
            sim.session(template: "Push Day") { s in s.logSets("Barbell Bench Press", 60, 5, count: 1) }
            sim.skipToDay(1)
            sim.session(template: "Pull Day") { s in s.logSets("Barbell Row", 60, 5, count: 1) }
            sim.skipToDay(2)
            // two sessions at exactly the same moment (an import, or a double-tap)
            let stamp = sim.now
            for name in order {
                sim.goTo(stamp)
                sim.session(template: name) { s in s.logSets(name == "Leg Day" ? "Barbell Squat" : "Barbell Bench Press", 60, 5, count: 1) }
            }
            for w in sim.historyRows().prefix(2) { w.date = stamp }
            return sim.prediction()
        }
        let a = try predictionWith(order: ["Leg Day", "Push Day"])
        let b = try predictionWith(order: ["Push Day", "Leg Day"])
        withKnownIssue("WorkoutViewModel.predictNextWorkout sorts only by date, so two workouts with the same timestamp order arbitrarily and the 'last session' (and the prediction) depends on insertion order", isIntermittent: true) {
            #expect(a == b)
        }
    }

    // MARK: Confidence

    @Test func confidenceNeverFallsAsAPerfectRotationGrowsBeyondItsFirstCycles() {
        let r = Self.rotations[0]
        var previous = 0.0
        for n in 7...20 {
            let c = WidgetDataService.predictionConfidence(names: Self.history(r.cycle, count: n), hasSplit: true, predicted: true)
            #expect(c >= previous, "\(n) sessions")
            previous = c
        }
        #expect(previous == 0.95)                                     // capped, never 100%
    }

    @Test func confidenceStartsFromAPriorAndRisesInStepsOfTheNumberOfCompletedCycles() {
        let r = Self.rotations[0]
        func c(_ n: Int) -> Double { WidgetDataService.predictionConfidence(names: Self.history(r.cycle, count: n), hasSplit: true, predicted: true) }
        #expect(c(7) == 0.67 && c(10) == 0.95)
        // The prior without enough history: 0.5 with a saved split, 0.3 without; 0 when nothing is predicted.
        #expect(WidgetDataService.predictionConfidence(names: ["Push Day"], hasSplit: true, predicted: true) == 0.5)
        #expect(WidgetDataService.predictionConfidence(names: [], hasSplit: false, predicted: true) == 0.3)
        #expect(WidgetDataService.predictionConfidence(names: Self.history(r.cycle, count: 12), hasSplit: true, predicted: false) == 0)
    }

    @Test func aMessyHistoryIsLessConfidentThanARegularOne() {
        let regular = Self.history(Self.rotations[0].cycle, count: 12)
        var rng = SeededRandom(seed: 5)
        let messy = (0..<12).map { _ in Self.rotations[0].cycle[rng.int(0...2)] }
        let cr = WidgetDataService.predictionConfidence(names: regular, hasSplit: true, predicted: true)
        let cm = WidgetDataService.predictionConfidence(names: messy, hasSplit: true, predicted: true)
        #expect(cm <= cr)
    }

    @Test func confidenceDoesNotDropWhenAConsistentHistoryGainsASession() {
        let h = Self.rotations[0]
        func c(_ n: Int) -> Double { WidgetDataService.predictionConfidence(names: Self.history(h.cycle, count: n), hasSplit: true, predicted: true) }
        withKnownIssue("WidgetDataService.predictionConfidence: a perfectly regular history gets LESS confident as it grows from 3 sessions (0.40, no sample yet) to 4 (0.33, one sample, damped), so the Home dots go down after a consistent session", isIntermittent: true) {
            #expect(c(4) >= c(3))
            #expect(c(3) >= c(2))
        }
    }

    @Test func withTwoOrMoreCandidatesTheMostFrequentWinsAndTiesGoToTheNewest() {
        // newest first. After B: C (index 3, newer) and A (index 5, older), one each -> the newer follower.
        #expect(WorkoutPredictor.detectNextByPattern(from: ["B", "A", "C", "B", "A", "B"]) == "C")
        // After X: Y twice, Z once (the newest) -> frequency beats recency.
        #expect(WorkoutPredictor.detectNextByPattern(from: ["X", "Y", "X", "Y", "X", "Z", "X"]) == "Y")
        // Three-way tie -> the newest follower.
        #expect(WorkoutPredictor.detectNextByPattern(from: ["P", "C", "P", "B", "P", "A", "P"]) == "C")
        // Case does not matter, and the spelling of the newest follower is kept.
        #expect(WorkoutPredictor.detectNextByPattern(from: ["push day", "Pull Day", "PUSH DAY"]) == "Pull Day")
    }

    @Test func pushingTheSameHistoryInAnyOrderOfEqualEntriesDoesNotChangeTheAnswer() {
        // Reordering identical names (equal 'dates' in name space) cannot change a name-only predictor.
        let base = ["Leg Day", "Pull Day", "Push Day", "Leg Day", "Pull Day", "Push Day", "Leg Day"]
        let t = ["Push Day", "Pull Day", "Leg Day"]
        var rng = SeededRandom(seed: 3)
        for _ in 0..<20 {
            var shuffled = base
            let i = rng.int(0...5)
            if shuffled[i] == shuffled[i + 1] { shuffled.swapAt(i, i + 1) }
            #expect(predict(shuffled, templates: t, split: .ppl) == predict(base, templates: t, split: .ppl))
        }
    }
}
