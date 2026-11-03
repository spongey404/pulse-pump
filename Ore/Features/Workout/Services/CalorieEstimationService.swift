import Foundation

enum CalorieFormula: String, Codable, CaseIterable, Identifiable {
    case basic
    case met

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basic: "Basic (set-based)"
        case .met: "MET-Based"
        }
    }

    var description: String {
        switch self {
        case .basic: "Simple estimate based on number of sets completed"
        case .met: "Uses metabolic equivalent, body weight, and duration"
        }
    }
}

struct CalorieEstimationService {

    /// Basic formula: ~8 calories per set, adjusted for compound vs isolation
    static func basicEstimate(totalSets: Int, compoundSets: Int, isolationSets: Int) -> Double {
        let compoundCals = Double(compoundSets) * 10.0
        let isolationCals = Double(isolationSets) * 6.0
        let remaining = totalSets - compoundSets - isolationSets
        return compoundCals + isolationCals + Double(remaining) * 8.0
    }

    /// MET-based formula: calories = MET × bodyWeightKg × durationHours
    /// Resistance training MET ranges from 3.5 (light) to 6.0 (vigorous)
    static func metEstimate(bodyWeightKg: Double, durationMinutes: Double, intensity: WorkoutIntensity) -> Double {
        let met = intensity.metValue
        let hours = durationMinutes / 60.0
        return met * bodyWeightKg * hours
    }

    /// Choose formula based on user preference, with fallback.
    /// MET is a Supernova formula: Settings only offers it to Supernova users, so by default the requested
    /// formula is honoured. Callers that cannot vouch for entitlement pass `isSubscribed: false`.
    static func estimate(
        formula: CalorieFormula,
        totalSets: Int,
        compoundSets: Int,
        isolationSets: Int,
        bodyWeightKg: Double,
        durationMinutes: Double,
        intensity: WorkoutIntensity,
        isSubscribed: Bool = true
    ) -> Double {
        switch formula {
        case .basic:
            return basicEstimate(totalSets: totalSets, compoundSets: compoundSets, isolationSets: isolationSets)
        case .met:
            // Fall back to basic for free users or missing data
            guard isSubscribed, bodyWeightKg > 0, durationMinutes > 0 else {
                return basicEstimate(totalSets: totalSets, compoundSets: compoundSets, isolationSets: isolationSets)
            }
            return metEstimate(bodyWeightKg: bodyWeightKg, durationMinutes: durationMinutes, intensity: intensity)
        }
    }
}

enum WorkoutIntensity: String, Codable, CaseIterable, Identifiable {
    case light
    case moderate
    case vigorous

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .moderate: "Moderate"
        case .vigorous: "Vigorous"
        }
    }

    var metValue: Double {
        switch self {
        case .light: 3.5
        case .moderate: 5.0
        case .vigorous: 6.0
        }
    }
}
