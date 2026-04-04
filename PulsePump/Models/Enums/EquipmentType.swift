import Foundation

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case kettlebell
    case band
    case ezBar
    case trapBar
    case smithMachine
    case plate
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .bodyweight: "Bodyweight"
        case .kettlebell: "Kettlebell"
        case .band: "Band"
        case .ezBar: "EZ Bar"
        case .trapBar: "Trap Bar"
        case .smithMachine: "Smith Machine"
        case .plate: "Plate"
        case .other: "Other"
        }
    }
}
