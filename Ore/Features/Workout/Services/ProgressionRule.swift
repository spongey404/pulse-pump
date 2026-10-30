import Foundation

/// Double-progression weight suggestion (Supernova "Smart weight suggestions"). Pure: no SwiftData, no UI.
///
/// The user sets a REP THRESHOLD per exercise. Within the current session the rule looks at the heaviest
/// *working* weight logged so far; when the latest set at that weight reached the threshold, the next set
/// is suggested at that weight + the user's increment. All weights are kg (CLAUDE.md "Units").
///
/// Which sets count (decision, see docs/pulse-pump-spec.md Phase 10):
///  - counted: standard, superset, AMRAP and unilateral (L/R) sets that are completed and have a weight > 0.
///  - ignored entirely (not as the heaviest weight, not for the threshold): warm-up, drop set, rest-pause
///    and failure sets. Warm-ups are not working sets; drop sets are deliberately lighter; rest-pause and
///    failure sets are taken past a controlled rep target, so their rep count says nothing about readiness.
///  - unilateral: both sides at the top weight must reach the threshold (the pair is judged when the second
///    side is logged); while only one side of a pair is done there is no suggestion.
struct ProgressionSet: Equatable {
    var weightKg: Double
    var reps: Int
    var setType: SetType
    var side: Side
    var isCompleted: Bool

    init(weightKg: Double, reps: Int, setType: SetType = .standard, side: Side = .both, isCompleted: Bool = true) {
        self.weightKg = weightKg
        self.reps = reps
        self.setType = setType
        self.side = side
        self.isCompleted = isCompleted
    }

    /// From a logger row (weight is a kg string).
    init(_ e: SetEntry) {
        self.init(weightKg: parseDecimal(e.weight) ?? 0, reps: parseWholeNumber(e.reps) ?? 0,
                  setType: e.setType, side: e.side, isCompleted: e.isCompleted)
    }

    /// From a persisted set (kg).
    init(_ s: SetLog) {
        self.init(weightKg: s.weight, reps: s.reps, setType: s.setType, side: s.side, isCompleted: true)
    }

    /// Counts toward the "highest working weight" and the threshold check.
    var isEligible: Bool {
        guard isCompleted, weightKg > 0 else { return false }
        switch setType {
        case .standard, .superset, .amrap, .leftRight: return true
        case .warmup, .dropset, .restPause, .failureSet: return false
        }
    }
}

enum ProgressionRule {
    static let defaultIncrementKgValue = 2.5
    static let defaultIncrementLb = 5.0
    static let thresholdRange = 1...30
    static let tolerance = 0.01

    /// Increment steps offered in Settings, in the display unit.
    static func incrementChoices(_ unit: UnitPreference) -> [Double] {
        unit == .kg ? [1, 1.25, 2.5, 5] : [2.5, 5, 10]
    }

    /// The increment in kg used when the user has not picked one (2.5 kg / 5 lb).
    static func defaultIncrementKg(for unit: UnitPreference) -> Double {
        unit == .kg ? defaultIncrementKgValue : unit.kg(fromDisplay: defaultIncrementLb)
    }

    /// Suggested weight (kg) for the next set, or nil when there is nothing to suggest.
    /// `sets` are this session's sets of one exercise in logging order; incomplete rows are ignored.
    static func suggestedWeightKg(sets: [ProgressionSet], threshold: Int?, incrementKg: Double,
                                  unit: UnitPreference = .kg) -> Double? {
        guard let threshold, thresholdRange.contains(threshold), incrementKg > 0 else { return nil }
        let eligible = sets.filter(\.isEligible)
        guard let top = eligible.map(\.weightKg).max() else { return nil }
        guard let lastIdx = eligible.lastIndex(where: { abs($0.weightKg - top) <= tolerance }) else { return nil }
        let last = eligible[lastIdx]
        guard last.reps >= threshold else { return nil }
        if last.side != .both {
            // Needs the opposite side directly before it, at the top weight, also at/above the threshold.
            guard lastIdx > 0, eligible[...lastIdx].filter({ $0.side != .both }).count % 2 == 0 else { return nil }
            let prev = eligible[lastIdx - 1]
            guard prev.side != .both, prev.side != last.side,
                  abs(prev.weightKg - top) <= tolerance, prev.reps >= threshold else { return nil }
        }
        return rounded(top + incrementKg, unit: unit)
    }

    /// Snaps to a loadable value in the display unit (0.25 kg / 0.5 lb), then back to kg.
    static func rounded(_ kg: Double, unit: UnitPreference) -> Double {
        let step = unit == .kg ? 0.25 : 0.5
        let shown = (unit.display(kg) / step).rounded() * step
        return unit.kg(fromDisplay: shown)
    }
}
