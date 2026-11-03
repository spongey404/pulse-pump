import Foundation

/// The add-exercises page's data (Ore Programs 07–09): filters, grouping into "N TYPES", and search that matches the types too. Pure.
enum ProgramPicker {
    enum Move: String, CaseIterable {
        case all = "ALL MOVES", push = "PUSH", pull = "PULL", squat = "SQUAT", hinge = "HINGE"
        var pattern: MovementPattern? {
            switch self { case .all: nil; case .push: .push; case .pull: .pull; case .squat: .squat; case .hinge: .hinge }
        }
    }

    enum Muscle: String, CaseIterable {
        case all = "ALL MUSCLES", chest = "CHEST", back = "BACK", shoulders = "SHOULDERS", arms = "ARMS", legs = "LEGS", core = "CORE"
        var groups: Set<MuscleGroup> {
            switch self {
            case .all: []
            case .chest: [.chest]
            case .back: [.back, .lats, .upperBack, .lowerBack, .traps]
            case .shoulders: [.shoulders, .rearDelts, .sideDelts, .frontDelts]
            case .arms: [.biceps, .triceps, .forearms]
            case .legs: [.quads, .hamstrings, .glutes, .calves, .adductors, .abductors, .hipFlexors]
            case .core: [.abs, .obliques]
            }
        }
    }

    struct Item: Identifiable, Equatable {
        /// The group's name, or the exercise's own name when it has no types.
        let title: String
        let exercises: [Exercise]
        var id: String { title }
        var isGroup: Bool { exercises.count > 1 }
        var muscles: String { exercises.first.map { $0.primaryMuscleGroups.map { $0.displayName.uppercased() }.joined(separator: " · ") } ?? "" }
        static func == (a: Item, b: Item) -> Bool { a.id == b.id && a.exercises.map(\.id) == b.exercises.map(\.id) }
    }

    /// Groups from `exerciseGroupDefinitions`, in that order, then the exercises that have no types, by name.
    static func items(exercises: [Exercise], query: String, move: Move, muscle: Muscle, excluded: Set<UUID> = []) -> [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let pool = exercises.filter { ($0.isApproved || $0.isCustom) && $0.deletedAt == nil && !excluded.contains($0.id) }
            .filter { move.pattern == nil || $0.movementPattern == move.pattern }
            .filter { muscle == .all || !muscle.groups.isDisjoint(with: $0.primaryMuscleGroups) }

        var groupOf: [String: String] = [:]
        for (group, names) in exerciseGroupDefinitions { for n in names { groupOf[n] = group } }
        let order = exerciseGroupDefinitions.map(\.name)

        var grouped: [String: [Exercise]] = [:]
        var loose: [Exercise] = []
        for e in pool { if let g = groupOf[e.name] { grouped[g, default: []].append(e) } else { loose.append(e) } }

        var out: [Item] = order.compactMap { name in
            guard let es = grouped[name], !es.isEmpty else { return nil }
            return Item(title: es.count == 1 ? es[0].name : name, exercises: es.sorted { $0.name < $1.name })
        }
        out += loose.sorted { $0.name < $1.name }.map { Item(title: $0.name, exercises: [$0]) }
        guard !q.isEmpty else { return out }
        // A group matches on its own name or any type's name.
        return out.filter { $0.title.lowercased().contains(q) || $0.exercises.contains { $0.name.lowercased().contains(q) } }
    }

    /// "3 TYPES ›" or "1 PICKED · 3 TYPES ›".
    static func typesLabel(typeCount: Int, picked: Int) -> String { picked > 0 ? "\(picked) PICKED · \(typeCount) TYPES" : "\(typeCount) TYPES" }

    /// The docked button: grey "PICK EXERCISES" with none, "ADD 3 EXERCISES" otherwise.
    static func dockTitle(count: Int) -> String { count == 0 ? "PICK EXERCISES" : "ADD \(count) EXERCISE\(count == 1 ? "" : "S")" }
}
