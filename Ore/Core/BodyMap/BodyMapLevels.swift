import Foundation

/// Maps the app's muscle vocabularies onto the artwork's muscle ids.
enum BodyMapLevels {
    /// Artwork ids a tracked group fills.
    static func ids(_ g: MuscleGroup) -> [String] {
        switch g {
        case .chest: ["chest", "upper_chest"]
        case .shoulders: ["front_delt", "side_delt", "rear_delt"]
        case .frontDelts: ["front_delt"]
        case .sideDelts: ["side_delt"]
        case .rearDelts: ["rear_delt"]
        case .biceps: ["bicep_long_head", "bicep_short_head"]
        case .triceps: ["tricep"]
        case .forearms: ["brachioradialis", "forearm_flexor", "forearm_extensor"]
        case .traps: ["traps", "upper_trap", "lower_trap"]
        case .lats: ["lats"]
        case .upperBack: ["infraspinatus_teres_major"]
        case .lowerBack: ["spinal_erector"]
        case .back: ["lats", "infraspinatus_teres_major", "spinal_erector"]
        case .quads: ["quad_rectus_femoris", "quad_vastus_lateralis", "quad_vastus_medialis"]
        case .hamstrings: ["hamstring"]
        case .glutes: ["glute_max", "glute_med"]
        case .calves: ["calves"]
        case .abs: ["abs"]
        case .obliques: ["obliques", "external_oblique"]
        case .adductors: ["adductor"]
        case .hipFlexors, .abductors, .neck: []
        }
    }

    /// The tracked group an artwork muscle belongs to (a tap opens that group's sheet).
    static func group(of id: String) -> MuscleGroup? {
        switch id {
        case "chest", "upper_chest": .chest
        case "front_delt": .frontDelts
        case "side_delt": .sideDelts
        case "rear_delt": .rearDelts
        case "bicep_long_head", "bicep_short_head": .biceps
        case "tricep": .triceps
        case "brachioradialis", "forearm_flexor", "forearm_extensor": .forearms
        case "traps", "upper_trap", "lower_trap": .traps
        case "lats": .lats
        case "infraspinatus_teres_major": .upperBack
        case "spinal_erector": .lowerBack
        case "quad_rectus_femoris", "quad_vastus_lateralis", "quad_vastus_medialis": .quads
        case "hamstring": .hamstrings
        case "glute_max", "glute_med": .glutes
        case "calves": .calves
        case "abs": .abs
        case "obliques", "external_oblique": .obliques
        case "adductor": .adductors
        default: nil
        }
    }

    static func levels(_ groups: [MuscleGroup: Double]) -> [String: Double] {
        var out: [String: Double] = [:]
        for (g, v) in groups where v > 0 { for id in ids(g) { out[id] = max(out[id] ?? 0, min(1, v)) } }
        return out
    }

    /// The Social surfaces' nine coarse regions.
    static func levels(_ i: BodyHeat.Intensities) -> [String: Double] {
        var out: [String: Double] = [:]
        func put(_ v: Double?, _ ids: [String]) { if let v, v > 0 { for id in ids { out[id] = min(1, v) } } }
        put(i.traps, ["traps", "upper_trap", "lower_trap"])
        put(i.chest, ["chest", "upper_chest"])
        put(i.shoulders, ["front_delt", "side_delt", "rear_delt"])
        put(i.biceps, ["bicep_long_head", "bicep_short_head"])
        put(i.forearms, ["brachioradialis", "forearm_flexor", "forearm_extensor"])
        put(i.core, ["abs", "obliques", "external_oblique"])
        put(i.glutes, ["glute_max", "glute_med"])
        put(i.quads, ["quad_rectus_femoris", "quad_vastus_lateralis", "quad_vastus_medialis"])
        put(i.calves, ["calves"])
        return out
    }

    /// Artwork muscle ids that exist on each side (a muscle like the triceps is on both).
    static let frontIds: Set<String> = ["chest", "upper_chest", "front_delt", "side_delt", "tricep", "bicep_long_head", "bicep_short_head", "brachioradialis",
                                        "forearm_flexor", "traps", "abs", "obliques", "adductor", "quad_rectus_femoris", "quad_vastus_lateralis",
                                        "quad_vastus_medialis", "calves"]
    static let backIds: Set<String> = ["rear_delt", "upper_trap", "lower_trap", "infraspinatus_teres_major", "lats", "spinal_erector", "external_oblique",
                                       "glute_max", "glute_med", "hamstring", "calves", "tricep", "forearm_extensor", "forearm_flexor"]

    /// Levels (0-1, against the busiest muscle) from a post's `muscleSets` (muscle display name -> weighted sets), front and back muscles both.
    static func levels(muscleSets: [String: Int]) -> [String: Double] {
        var counts: [MuscleGroup: Double] = [:]
        for (name, sets) in muscleSets where sets > 0 {
            guard let g = MuscleGroup.allCases.first(where: { $0.displayName == name }) else { continue }
            counts[g, default: 0] += Double(sets)
        }
        let peak = counts.values.max() ?? 0
        guard peak > 0 else { return [:] }
        return levels(counts.mapValues { $0 / peak })
    }

    /// Rule: a side is shown only if a muscle on it was trained. Never an empty side.
    static func trainedSides(_ levels: [String: Double]) -> [BodyMapSide] {
        let worked = Set(levels.filter { $0.value > 0 }.keys)
        var sides: [BodyMapSide] = []
        if !worked.isDisjoint(with: frontIds) { sides.append(.front) }
        if !worked.isDisjoint(with: backIds) { sides.append(.back) }
        return sides
    }
}
