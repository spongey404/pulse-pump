import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case traps
    case lats
    case quads
    case hamstrings
    case glutes
    case calves
    case abs
    case obliques
    case lowerBack
    case upperBack
    case rearDelts
    case sideDelts
    case frontDelts
    case hipFlexors
    case adductors
    case abductors
    case neck

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .traps: "Traps"
        case .lats: "Lats"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .calves: "Calves"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .lowerBack: "Lower Back"
        case .upperBack: "Upper Back"
        case .rearDelts: "Rear Delts"
        case .sideDelts: "Side Delts"
        case .frontDelts: "Front Delts"
        case .hipFlexors: "Hip Flexors"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .neck: "Neck"
        }
    }

    var bodyRegion: BodyRegion {
        switch self {
        case .chest, .shoulders, .frontDelts, .sideDelts:
            return .upper
        case .back, .lats, .traps, .upperBack, .rearDelts:
            return .upper
        case .biceps, .triceps, .forearms:
            return .arms
        case .quads, .hamstrings, .glutes, .calves, .hipFlexors, .adductors, .abductors:
            return .lower
        case .abs, .obliques, .lowerBack:
            return .core
        case .neck:
            return .upper
        }
    }
}

enum BodyRegion: String, Codable, CaseIterable, Identifiable {
    case upper
    case lower
    case core
    case arms

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upper: "Upper Body"
        case .lower: "Lower Body"
        case .core: "Core"
        case .arms: "Arms"
        }
    }
}
