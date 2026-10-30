import Testing
import Foundation
import SwiftData
@testable import Ore

@MainActor
struct WorkoutPredictorTests {
    static let templates = ["Push Day", "Pull Day", "Leg Day"]

    @Test func cleanPPLCycleIsLearned() {
        // newest first: Legs, Pull, Push, Legs, Pull, Push
        let history = ["Leg Day", "Pull Day", "Push Day", "Leg Day", "Pull Day", "Push Day"]
        #expect(WorkoutPredictor.detectNextByPattern(from: history) == "Push Day")
        #expect(WorkoutPredictor.predict(history: history, templateNames: Self.templates, split: nil, todayWeekday: 2) == "Push Day")
    }

    @Test func tiesGoToTheMostRecentSuccessor() {
        // After "A" came B (older) and C (newer): deterministic -> C.
        let history = ["A", "C", "A", "B", "A"]
        #expect(WorkoutPredictor.detectNextByPattern(from: history) == "C")
    }

    @Test func inventedKeywordNameResolvesToTheUsersTemplate() {
        // Keyword fallback invents "Leg Day"; the user's template is "Legs & Core".
        let split = SplitSchedule.makeSplit(type: .ppl)
        let templates = ["Push Day", "Legs & Core"]
        let history = ["Pull Day", "Push Day"]           // last = Pull; no pattern for Pull -> keyword "Leg Day"
        let predicted = WorkoutPredictor.predict(history: history, templateNames: templates, split: split, todayWeekday: 3)
        // "Leg Day" resolves to "Legs & Core" by keyword, so it is a real template rather than a blank workout.
        #expect(predicted == "Legs & Core")
    }

    @Test func unresolvablePatternUsesSplitNextDay() {
        let split = SplitSchedule.makeSplit(type: .upperLower)     // Mon U, Tue L, Thu U, Fri L
        let templates = ["Upper Body", "Lower Body"]
        // The learned pattern says "Mobility" follows "X", but no template matches it: the old code
        // started a blank workout; now the split's slot for today (Wed -> Thursday's Upper) is used.
        let history = ["X", "Mobility", "X", "Mobility"]
        #expect(WorkoutPredictor.detectNextByPattern(from: history) == "Mobility")
        let predicted = WorkoutPredictor.predict(history: history, templateNames: templates, split: split, todayWeekday: 4)
        #expect(predicted == "Upper Body")
    }

    @Test func splitNextDayFollowsLastWorkout() {
        let days = SplitSchedule.defaultDays(for: .ppl)
        #expect(WorkoutPredictor.nextFromSplit(days: days, lastName: "Pull Day", todayWeekday: 4) == "Leg Day")
        #expect(WorkoutPredictor.nextFromSplit(days: days, lastName: "Leg Day", todayWeekday: 4) == "Push Day")
    }

    @Test func splitWithNoHistoryUsesTodaysSlot() {
        let days = SplitSchedule.defaultDays(for: .upperLower)    // Mon U, Tue L, Thu U, Fri L
        #expect(WorkoutPredictor.nextFromSplit(days: days, lastName: nil, todayWeekday: 3) == "Lower Body")   // Tue
        #expect(WorkoutPredictor.nextFromSplit(days: days, lastName: nil, todayWeekday: 7) == "Upper Body")   // Sat -> wraps
    }

    @Test func noHistoryNoSplitIsNil() {
        #expect(WorkoutPredictor.predict(history: [], templateNames: Self.templates, split: nil, todayWeekday: 2) == nil)
    }

    @Test func templateResolution() {
        #expect(WorkoutPredictor.resolveTemplate("push", among: Self.templates) == "Push Day")
        #expect(WorkoutPredictor.resolveTemplate("LEG DAY", among: Self.templates) == "Leg Day")
        #expect(WorkoutPredictor.resolveTemplate("Legs", among: Self.templates) == "Leg Day")
        #expect(WorkoutPredictor.resolveTemplate("Yoga", among: Self.templates) == nil)
    }

    @Test func predictNextWorkoutReadsSwiftData() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let user = User(name: "T")
        ctx.insert(user)
        user.selectedSplit = SplitSchedule.makeSplit(type: .ppl)
        for name in Self.templates { ctx.insert(WorkoutTemplate(name: name)) }
        let vm = WorkoutViewModel()
        // No history: the split's slot for today, resolved to a real template.
        let name = try #require(vm.predictNextWorkout(user: user, modelContext: ctx))
        #expect(Self.templates.contains(name))
    }

    @Test func confidenceDotsComeFromRealData() {
        // Strong cycle -> high; unseen last workout -> low; no prediction -> 0.
        let strong = (0..<12).map { ["Leg Day", "Pull Day", "Push Day"][$0 % 3] }
        let high = WidgetDataService.predictionConfidence(names: strong, hasSplit: true, predicted: true)
        let low = WidgetDataService.predictionConfidence(names: ["A", "B"], hasSplit: false, predicted: true)
        #expect(high >= 0.9)
        #expect(low < 0.5)
        #expect(WidgetDataService.predictionConfidence(names: strong, hasSplit: true, predicted: false) == 0)
        #expect(Int((high * 5).rounded()) == 5)
        #expect(Int((low * 5).rounded()) < 3)
    }
}
