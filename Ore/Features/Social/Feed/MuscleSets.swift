import Foundation

// Body-map helpers driven by a post's `extras/bodymap` document (`muscleSets`: muscle display name ->
// weighted working sets). The muscle tags are not part of the post itself, so the privacy of the
// body map is enforced by the data model, not by hiding things in the UI.

extension BodyHeat.Intensities {
    /// Relative intensities (against the busiest muscle) from a `muscleSets` map. BodyHeat is
    /// front-view-only, so posterior-only groups have no region and are dropped.
    init(muscleSets: [String: Int]) {
        var counts: [MuscleGroup: Double] = [:]
        for (name, sets) in muscleSets {
            guard let muscle = MuscleGroup.allCases.first(where: { $0.displayName == name }) else { continue }
            counts[muscle, default: 0] += Double(sets)
        }
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
}

enum MuscleSetsFormat {
    static func abbreviate(_ name: String) -> String {
        switch name.lowercased() {
        case "shoulders": "SHLDR"
        case "triceps": "TRI"
        case "biceps": "BI"
        case "forearms": "FA"
        case "hamstrings": "HAM"
        default: name.uppercased()
        }
    }

    /// The `count` busiest muscles, e.g. [("CHEST", 12), ("SHLDR", 7)].
    static func top(_ muscleSets: [String: Int], count: Int = 3, abbreviated: Bool = true) -> [(label: String, count: Int)] {
        muscleSets.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(count)
            .map { (abbreviated ? abbreviate($0.key) : $0.key.uppercased(), $0.value) }
    }
}
