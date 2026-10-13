import Foundation

/// Smart weight suggestions settings stored on `User` (see `ProgressionRule`). Weights are kg.
extension User {
    static let maxProgressionThresholds = 200

    /// Increment actually used: the saved one, else 2.5 kg / 5 lb for the user's unit.
    var effectiveProgressionIncrementKg: Double {
        if let kg = progressionIncrementKg, kg > 0 { return kg }
        return ProgressionRule.defaultIncrementKg(for: unitPreference)
    }

    func progressionThreshold(forExercise name: String) -> Int? {
        progressionThresholds[Exercise.normalisedName(name)]
    }

    /// nil (or an out-of-range value) clears the threshold. Marks the user dirty for sync only on a real change.
    func setProgressionThreshold(_ reps: Int?, forExercise name: String) {
        let key = Exercise.normalisedName(name)
        guard !key.isEmpty else { return }
        var next = progressionThresholds
        if let reps, ProgressionRule.thresholdRange.contains(reps) {
            guard next[key] != nil || next.count < Self.maxProgressionThresholds else { return }
            next[key] = reps
        } else {
            next.removeValue(forKey: key)
        }
        guard next != progressionThresholds else { return }
        progressionThresholds = next
        markUpdated()
    }

    func setProgressionIncrementKg(_ kg: Double?) {
        let value = kg.flatMap { $0 > 0 && $0 <= 50 ? $0 : nil }
        guard value != progressionIncrementKg else { return }
        progressionIncrementKg = value
        markUpdated()
    }
}
