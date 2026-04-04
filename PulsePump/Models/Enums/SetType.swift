import Foundation

enum SetType: String, Codable, CaseIterable, Identifiable {
    case standard
    case warmup
    case superset
    case dropset
    case restPause
    case amrap
    case failureSet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .warmup: "Warm Up"
        case .superset: "Superset"
        case .dropset: "Drop Set"
        case .restPause: "Rest-Pause"
        case .amrap: "AMRAP"
        case .failureSet: "Failure"
        }
    }
}
