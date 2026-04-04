import Foundation

enum MovementPattern: String, Codable, CaseIterable, Identifiable {
    case push
    case pull
    case hinge
    case squat
    case carry
    case rotation
    case isolation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .push: "Push"
        case .pull: "Pull"
        case .hinge: "Hinge"
        case .squat: "Squat"
        case .carry: "Carry"
        case .rotation: "Rotation"
        case .isolation: "Isolation"
        }
    }

    var isCompound: Bool {
        switch self {
        case .push, .pull, .hinge, .squat, .carry:
            return true
        case .rotation, .isolation:
            return false
        }
    }
}
