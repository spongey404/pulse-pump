import Testing
@testable import Ore

struct CalorieEstimationServiceTests {

    // MARK: - Basic Formula

    @Test func basicEstimateCompoundOnly() {
        let result = CalorieEstimationService.basicEstimate(totalSets: 5, compoundSets: 5, isolationSets: 0)
        #expect(result == 50.0) // 5 × 10
    }

    @Test func basicEstimateIsolationOnly() {
        let result = CalorieEstimationService.basicEstimate(totalSets: 5, compoundSets: 0, isolationSets: 5)
        #expect(result == 30.0) // 5 × 6
    }

    @Test func basicEstimateMixed() {
        let result = CalorieEstimationService.basicEstimate(totalSets: 10, compoundSets: 4, isolationSets: 3)
        // 4×10 + 3×6 + 3×8 = 40 + 18 + 24 = 82
        #expect(result == 82.0)
    }

    @Test func basicEstimateZeroSets() {
        let result = CalorieEstimationService.basicEstimate(totalSets: 0, compoundSets: 0, isolationSets: 0)
        #expect(result == 0.0)
    }

    @Test func basicEstimateDefaultCaloriesForUnknownType() {
        // All "remaining" sets get 8 cal each
        let result = CalorieEstimationService.basicEstimate(totalSets: 3, compoundSets: 0, isolationSets: 0)
        #expect(result == 24.0) // 3 × 8
    }

    // MARK: - MET Formula

    @Test func metEstimateModerateIntensity() {
        // MET=5.0, 80kg, 60min → 5.0 × 80 × 1.0 = 400
        let result = CalorieEstimationService.metEstimate(bodyWeightKg: 80, durationMinutes: 60, intensity: .moderate)
        #expect(result == 400.0)
    }

    @Test func metEstimateLightIntensity() {
        // MET=3.5, 70kg, 30min → 3.5 × 70 × 0.5 = 122.5
        let result = CalorieEstimationService.metEstimate(bodyWeightKg: 70, durationMinutes: 30, intensity: .light)
        #expect(result == 122.5)
    }

    @Test func metEstimateVigorousIntensity() {
        // MET=6.0, 90kg, 45min → 6.0 × 90 × 0.75 = 405
        let result = CalorieEstimationService.metEstimate(bodyWeightKg: 90, durationMinutes: 45, intensity: .vigorous)
        #expect(result == 405.0)
    }

    // MARK: - Estimate Dispatcher

    @Test func estimateUsesBasicFormula() {
        let result = CalorieEstimationService.estimate(
            formula: .basic, totalSets: 10, compoundSets: 5, isolationSets: 5,
            bodyWeightKg: 80, durationMinutes: 60, intensity: .moderate
        )
        // Should use basic: 5×10 + 5×6 = 80
        #expect(result == 80.0)
    }

    @Test func estimateUsesMetFormula() {
        let result = CalorieEstimationService.estimate(
            formula: .met, totalSets: 10, compoundSets: 5, isolationSets: 5,
            bodyWeightKg: 80, durationMinutes: 60, intensity: .moderate
        )
        // Should use MET: 5.0 × 80 × 1.0 = 400
        #expect(result == 400.0)
    }

    @Test func estimateMetFallsBackToBasicWhenZeroWeight() {
        let result = CalorieEstimationService.estimate(
            formula: .met, totalSets: 10, compoundSets: 5, isolationSets: 5,
            bodyWeightKg: 0, durationMinutes: 60, intensity: .moderate
        )
        // Falls back to basic: 5×10 + 5×6 = 80
        #expect(result == 80.0)
    }

    @Test func estimateMetFallsBackToBasicWhenZeroDuration() {
        let result = CalorieEstimationService.estimate(
            formula: .met, totalSets: 10, compoundSets: 5, isolationSets: 5,
            bodyWeightKg: 80, durationMinutes: 0, intensity: .moderate
        )
        #expect(result == 80.0)
    }
}
