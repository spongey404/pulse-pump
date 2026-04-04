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

    var sfSymbol: String {
        switch self {
        case .barbell: "scalemass"
        case .dumbbell: "dumbbell"
        case .cable: "arrow.up.and.down"
        case .machine: "gearshape"
        case .bodyweight: "figure.strengthtraining.functional"
        case .kettlebell: "drop.circle"
        case .band: "waveform"
        case .ezBar: "alternatingcurrent"
        case .trapBar: "trapezoid.and.line.horizontal"
        case .smithMachine: "gearshape.2"
        case .plate: "circle.fill"
        case .other: "questionmark.circle"
        }
    }
}
