import Foundation

/// The Body page's muscle tree (Ore Body Final): six groups, 20 muscles, and the heads some muscles split into. Every name is the artwork's
/// own part name, and every node knows which artwork muscle ids it lights up. Targets are weekly working sets.
struct BodyHeadDef: Identifiable, Equatable {
    let id: String          // the artwork muscle id
    let name: String
    let target: Int
}

struct BodyMuscleDef: Identifiable, Equatable {
    let id: String
    let name: String
    /// Artwork ids this muscle covers (the map lights all of them).
    let ids: [String]
    let target: Int
    var heads: [BodyHeadDef] = []
}

struct BodyGroupDef: Identifiable, Equatable {
    let id: String
    let name: String
    let muscles: [BodyMuscleDef]
    var target: Int { muscles.reduce(0) { $0 + $1.target } }
    var ids: [String] { muscles.flatMap(\.ids) }
}

enum BodyMuscleTree {
    static let groups: [BodyGroupDef] = [
        BodyGroupDef(id: "chest", name: "Chest", muscles: [
            BodyMuscleDef(id: "upper_chest", name: "Upper Chest", ids: ["upper_chest"], target: 6),
            BodyMuscleDef(id: "chest", name: "Lower Chest", ids: ["chest"], target: 10),
        ]),
        BodyGroupDef(id: "back", name: "Back", muscles: [
            BodyMuscleDef(id: "lats", name: "Lats", ids: ["lats"], target: 16),
            BodyMuscleDef(id: "infraspinatus_teres_major", name: "Infraspinatus / Teres Major", ids: ["infraspinatus_teres_major"], target: 12),
            BodyMuscleDef(id: "traps", name: "Traps", ids: ["traps", "upper_trap", "lower_trap"], target: 8, heads: [
                BodyHeadDef(id: "upper_trap", name: "Upper Trap", target: 4), BodyHeadDef(id: "lower_trap", name: "Lower Trap", target: 4)]),
            BodyMuscleDef(id: "spinal_erector", name: "Spinal Erector", ids: ["spinal_erector"], target: 6),
        ]),
        BodyGroupDef(id: "shoulders", name: "Shoulders", muscles: [
            BodyMuscleDef(id: "front_delt", name: "Front Delt", ids: ["front_delt"], target: 8),
            BodyMuscleDef(id: "side_delt", name: "Side Delt", ids: ["side_delt"], target: 10),
            BodyMuscleDef(id: "rear_delt", name: "Rear Delt", ids: ["rear_delt"], target: 8),
        ]),
        BodyGroupDef(id: "arms", name: "Arms", muscles: [
            BodyMuscleDef(id: "bicep", name: "Bicep", ids: ["bicep_long_head", "bicep_short_head"], target: 10, heads: [
                BodyHeadDef(id: "bicep_long_head", name: "Long Head", target: 5), BodyHeadDef(id: "bicep_short_head", name: "Short Head", target: 5)]),
            BodyMuscleDef(id: "tricep", name: "Tricep", ids: ["tricep"], target: 10),
            BodyMuscleDef(id: "forearm", name: "Forearm", ids: ["brachioradialis", "forearm_flexor", "forearm_extensor"], target: 6, heads: [
                BodyHeadDef(id: "brachioradialis", name: "Brachioradialis", target: 2), BodyHeadDef(id: "forearm_flexor", name: "Forearm Flexor", target: 2),
                BodyHeadDef(id: "forearm_extensor", name: "Forearm Extensor", target: 2)]),
        ]),
        BodyGroupDef(id: "core", name: "Core", muscles: [
            BodyMuscleDef(id: "abs", name: "Abs", ids: ["abs"], target: 8),
            BodyMuscleDef(id: "obliques", name: "Obliques", ids: ["obliques"], target: 6),
            BodyMuscleDef(id: "external_oblique", name: "External Oblique", ids: ["external_oblique"], target: 4),
        ]),
        BodyGroupDef(id: "legs", name: "Legs", muscles: [
            BodyMuscleDef(id: "quad", name: "Quad", ids: ["quad_rectus_femoris", "quad_vastus_lateralis", "quad_vastus_medialis"], target: 20, heads: [
                BodyHeadDef(id: "quad_rectus_femoris", name: "Rectus Femoris", target: 7), BodyHeadDef(id: "quad_vastus_lateralis", name: "Vastus Lateralis", target: 7),
                BodyHeadDef(id: "quad_vastus_medialis", name: "Vastus Medialis", target: 6)]),
            BodyMuscleDef(id: "glute", name: "Glute", ids: ["glute_max", "glute_med"], target: 12, heads: [
                BodyHeadDef(id: "glute_max", name: "Glute Max", target: 8), BodyHeadDef(id: "glute_med", name: "Glute Med", target: 4)]),
            BodyMuscleDef(id: "hamstring", name: "Hamstring", ids: ["hamstring"], target: 12),
            BodyMuscleDef(id: "adductor", name: "Adductor", ids: ["adductor"], target: 6),
            BodyMuscleDef(id: "calves", name: "Calves", ids: ["calves"], target: 8),
        ]),
    ]

    static var muscles: [BodyMuscleDef] { groups.flatMap(\.muscles) }
    static var weeklyTarget: Int { groups.reduce(0) { $0 + $1.target } }
    static var allIds: Set<String> { Set(groups.flatMap(\.ids)) }

    /// Artwork ids an exercise credits: its primary groups' ids, narrowed to the sub-regions it names when it names any for that group.
    static func creditedIds(for exercise: Exercise) -> Set<String> {
        var out = Set<String>()
        let sub = Set(exercise.primarySubRegions.flatMap { subRegionIds($0) })
        for g in exercise.primaryMuscleGroups {
            let ids = BodyMapLevels.ids(g)
            let narrowed = ids.filter { sub.contains($0) }
            out.formUnion(narrowed.isEmpty ? ids : narrowed)
        }
        return out
    }

    static func subRegionIds(_ r: MuscleSubRegion) -> [String] {
        switch r {
        case .upperChest: ["upper_chest"]
        case .lowerChest: ["chest"]
        case .upperTraps: ["upper_trap"]
        case .lowerTraps: ["lower_trap"]
        case .bicepsLongHead: ["bicep_long_head"]
        case .bicepsShortHead: ["bicep_short_head"]
        case .brachioradialis: ["brachioradialis"]
        case .wristFlexors: ["forearm_flexor"]
        case .wristExtensors: ["forearm_extensor"]
        case .rectusFemoris: ["quad_rectus_femoris"]
        case .vastusLateralis: ["quad_vastus_lateralis"]
        case .vastusMedialis: ["quad_vastus_medialis"]
        case .gluteusMaximus: ["glute_max"]
        case .gluteusMedius: ["glute_med"]
        default: []
        }
    }
}
