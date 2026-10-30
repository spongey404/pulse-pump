import Testing
import Foundation
@testable import Ore

/// Pure double-progression rule (ProgressionRule). Weights are kg throughout.
struct ProgressionRuleTests {
    private func s(_ w: Double, _ r: Int, _ t: SetType = .standard, _ side: Side = .both, done: Bool = true) -> ProgressionSet {
        ProgressionSet(weightKg: w, reps: r, setType: t, side: side, isCompleted: done)
    }
    private func suggest(_ sets: [ProgressionSet], at t: Int? = 8, inc: Double = 2.5, unit: UnitPreference = .kg) -> Double? {
        ProgressionRule.suggestedWeightKg(sets: sets, threshold: t, incrementKg: inc, unit: unit)
    }

    // MARK: Threshold met / not met

    @Test func thresholdExactlyMetSuggestsNextWeight() { #expect(suggest([s(100, 8)]) == 102.5) }
    @Test func thresholdExceededSuggestsNextWeight() { #expect(suggest([s(100, 12)]) == 102.5) }
    @Test func thresholdNotMetGivesNoSuggestion() { #expect(suggest([s(100, 7)]) == nil) }
    @Test func nilThresholdGivesNoSuggestion() { #expect(suggest([s(100, 20)], at: nil) == nil) }
    @Test func outOfRangeThresholdIsIgnored() {
        #expect(suggest([s(100, 20)], at: 0) == nil)
        #expect(suggest([s(100, 40)], at: 31) == nil)
    }
    @Test func firstSetOfSessionHasNothingToSuggest() { #expect(suggest([]) == nil) }
    @Test func incompleteRowsAreIgnored() { #expect(suggest([s(100, 10, done: false)]) == nil) }
    @Test func zeroOrNegativeIncrementGivesNoSuggestion() {
        #expect(suggest([s(100, 8)], inc: 0) == nil)
        #expect(suggest([s(100, 8)], inc: -2.5) == nil)
    }

    // MARK: Latest set at the top weight decides

    @Test func laterFailureAtTopWeightCancelsTheSuggestion() {
        #expect(suggest([s(100, 8), s(100, 6)]) == nil)
    }
    @Test func laterSuccessAtTopWeightRestoresTheSuggestion() {
        #expect(suggest([s(100, 6), s(100, 8)]) == 102.5)
    }

    // MARK: Multiple working weights

    @Test func highestWeightWinsEvenIfLighterSetHitThreshold() {
        // 100 x 10 then 105 x 5: 105 is the top weight and has not reached 8.
        #expect(suggest([s(100, 10), s(105, 5)]) == nil)
    }
    @Test func thresholdCheckMovesToTheHeavierWeight() {
        #expect(suggest([s(100, 8), s(105, 8)]) == 107.5)
    }
    @Test func lighterSetAfterTopWeightDoesNotMoveTheCheck() {
        // Went back down to 95 after 105 x 8: top is still 105.
        #expect(suggest([s(105, 8), s(95, 12)]) == 107.5)
    }

    // MARK: Warm-ups and other set types

    @Test func onlyWarmUpsLoggedGivesNoSuggestion() {
        #expect(suggest([s(60, 15, .warmup), s(80, 12, .warmup)]) == nil)
    }
    @Test func warmUpHeavierThanWorkingSetsIsIgnored() {
        // Odd but legal: a "warm-up" of 120 must not become the highest weight.
        #expect(suggest([s(120, 10, .warmup), s(100, 8)]) == 102.5)
    }
    @Test func warmUpRepsNeverTriggerTheThreshold() {
        #expect(suggest([s(100, 12, .warmup), s(100, 5)]) == nil)
    }
    @Test func dropSetIsIgnoredForHighestWeightAndThreshold() {
        #expect(suggest([s(100, 6), s(80, 15, .dropset)]) == nil)
        #expect(suggest([s(100, 8), s(80, 5, .dropset)]) == 102.5)
    }
    @Test func failureAndRestPauseSetsAreIgnored() {
        #expect(suggest([s(100, 12, .failureSet)]) == nil)
        #expect(suggest([s(100, 12, .restPause)]) == nil)
        #expect(suggest([s(110, 12, .failureSet), s(100, 8)]) == 102.5)
    }
    @Test func amrapSupersetAndStandardCount() {
        #expect(suggest([s(100, 10, .amrap)]) == 102.5)
        #expect(suggest([s(100, 8, .superset)]) == 102.5)
    }

    // MARK: Unilateral

    @Test func unilateralNeedsBothSides() {
        #expect(suggest([s(20, 10, .leftRight, .left)]) == nil)
        #expect(suggest([s(20, 10, .leftRight, .left), s(20, 10, .leftRight, .right)]) == 22.5)
    }
    @Test func unilateralWeakSideBlocksProgression() {
        #expect(suggest([s(20, 10, .leftRight, .left), s(20, 7, .leftRight, .right)]) == nil)
        #expect(suggest([s(20, 7, .leftRight, .left), s(20, 10, .leftRight, .right)]) == nil)
    }
    @Test func unilateralSecondPairStartingMeansWaiting() {
        let done = [s(20, 10, .leftRight, .left), s(20, 10, .leftRight, .right), s(20, 10, .leftRight, .left)]
        #expect(suggest(done) == nil)
    }

    // MARK: Bodyweight / zero weight

    @Test func bodyweightExerciseNeverSuggests() {
        #expect(suggest([s(0, 20), s(0, 25)]) == nil)
    }
    @Test func weightedBodyweightWorksOnAddedLoad() {
        #expect(suggest([s(0, 12), s(10, 8)]) == 12.5)
    }

    // MARK: Increments, units, rounding, kg storage

    @Test(arguments: [1.0, 1.25, 2.5, 5.0])
    func kgIncrementVariants(_ inc: Double) {
        #expect(suggest([s(100, 8)], inc: inc) == 100 + inc)
    }
    @Test func lbIncrementsConvertToKg() {
        for lb in ProgressionRule.incrementChoices(.lbs) {
            let kg = UnitPreference.lbs.kg(fromDisplay: lb)
            #expect(abs(kg - lb * 0.45359237) < 1e-9)
        }
        #expect(ProgressionRule.incrementChoices(.kg) == [1, 1.25, 2.5, 5])
        #expect(ProgressionRule.incrementChoices(.lbs) == [2.5, 5, 10])
    }
    @Test func lbUserGetsAWholePoundSuggestion() {
        let top = UnitPreference.lbs.kg(fromDisplay: 100)          // stored kg
        let out = suggest([s(top, 8)], inc: UnitPreference.lbs.kg(fromDisplay: 5), unit: .lbs)
        #expect(abs(UnitPreference.lbs.display(out ?? 0) - 105) < 1e-9)
    }
    @Test func defaultIncrementsFollowTheUnit() {
        #expect(ProgressionRule.defaultIncrementKg(for: .kg) == 2.5)
        #expect(abs(ProgressionRule.defaultIncrementKg(for: .lbs) - 5 * 0.45359237) < 1e-9)
    }
    @Test func suggestionsSnapToLoadableKgValues() {
        #expect(suggest([s(100.1, 8)], inc: 1.25) == 101.25)
        #expect(ProgressionRule.rounded(101.37, unit: .kg) == 101.25)
        #expect(ProgressionRule.rounded(101.38, unit: .kg) == 101.5)
    }
    @Test func lbSuggestionsSnapToHalfPounds() {
        let r = ProgressionRule.rounded(UnitPreference.lbs.kg(fromDisplay: 105.3), unit: .lbs)
        #expect(abs(UnitPreference.lbs.display(r) - 105.5) < 1e-9)
    }
    @Test func rulePreservesKgRegardlessOfUnitForKgInputs() {
        // Same kg history, kg vs lbs display unit: the kg increment is applied, only snapping differs.
        let kg = suggest([s(100, 8)], inc: 2.5, unit: .kg)
        #expect(kg == 102.5)
    }
    @Test func equalWeightsWithinToleranceAreTheSameWeight() {
        #expect(suggest([s(100.004, 8), s(100, 5)]) == nil)   // latest set at "100" missed
    }

    // MARK: Conversions

    @Test func setEntryAndSetLogAdaptersCarryKg() {
        var e = SetEntry(order: 0, weight: "62.5", reps: "8")
        e.isCompleted = true
        #expect(ProgressionSet(e) == s(62.5, 8))
        let log = SetLog(order: 0, weight: 62.5, reps: 8, setType: .warmup)
        #expect(ProgressionSet(log) == s(62.5, 8, .warmup))
    }
}
