import SwiftUI

// App-only helpers that derive BodyHeat intensities from feed / SwiftData models.
// (BodyHeat itself lives in PumpShared so the widget extension can draw it too.)

extension Array where Element == FeedExercise {
    /// Per-muscle set counts across these exercises — primary muscles get full credit per
    /// set, secondary get half credit. Mirrors the Body tab's established
    /// weighting convention (the Body Map tab's real heatmap), so a session with 12 chest
    /// sets and 7 triceps sets on Bench Press (primary chest, secondary triceps) actually
    /// shows chest hotter than triceps, instead of both lighting up equally.
    func muscleSetCounts() -> [MuscleGroup: Double] {
        var counts: [MuscleGroup: Double] = [:]
        for exercise in self {
            let setCount = Double(exercise.workingSets.count)   // warm-ups do not heat muscles
            for name in exercise.primaryMuscles {
                guard let muscle = MuscleGroup.allCases.first(where: { $0.displayName == name }) else { continue }
                counts[muscle, default: 0] += setCount
            }
            for name in exercise.secondaryMuscles {
                guard let muscle = MuscleGroup.allCases.first(where: { $0.displayName == name }) else { continue }
                counts[muscle, default: 0] += setCount / 2
            }
        }
        return counts
    }
}

extension BodyHeat.Intensities {
    /// Real per-exercise-weighted intensities, relative to the session's peak muscle —
    /// the primary path. BodyHeat is front-view-only per spec, so posterior-only groups
    /// (back, lats, upperBack, lowerBack, hamstrings, triceps, neck) have no region here
    /// and are dropped from the peak/display — that's expected, not a gap.
    init(exercises: [FeedExercise]) {
        let counts = exercises.muscleSetCounts()
        let peak = counts.values.max() ?? 0
        func level(_ groups: MuscleGroup...) -> Double? {
            let best = groups.compactMap { counts[$0] }.max() ?? 0
            guard best > 0, peak > 0 else { return nil }
            return min(1.0, best / peak)
        }
        self.init(
            traps: level(.traps),
            chest: level(.chest),
            shoulders: level(.shoulders, .frontDelts, .sideDelts),
            biceps: level(.biceps),
            forearms: level(.forearms),
            core: level(.abs, .obliques),
            glutes: level(.glutes),
            quads: level(.quads, .adductors, .hipFlexors, .abductors),
            calves: level(.calves)
        )
    }

    /// Binary worked/not-worked fallback for call sites with only a session-level muscle
    /// set (demo data, or items with no per-exercise tags) — prefer `init(exercises:)`
    /// wherever a `[FeedExercise]` array is available.
    init(worked muscles: Set<MuscleGroup>) {
        func hit(_ groups: MuscleGroup...) -> Double? { groups.contains(where: muscles.contains) ? 1.0 : nil }
        self.init(
            traps: hit(.traps),
            chest: hit(.chest),
            shoulders: hit(.shoulders, .frontDelts, .sideDelts),
            biceps: hit(.biceps),
            forearms: hit(.forearms),
            core: hit(.abs, .obliques),
            glutes: hit(.glutes),
            quads: hit(.quads, .adductors, .hipFlexors, .abductors),
            calves: hit(.calves)
        )
    }
}

