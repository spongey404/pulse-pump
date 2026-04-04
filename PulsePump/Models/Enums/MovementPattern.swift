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

    var sfSymbol: String {
        switch self {
        case .push: "arrow.up.forward"
        case .pull: "arrow.down.backward"
        case .hinge: "figure.cooldown"
        case .squat: "figure.stand"
        case .carry: "figure.walk"
        case .rotation: "arrow.trianglehead.2.clockwise.rotate.90"
        case .isolation: "circle.dotted"
        }
    }
}
