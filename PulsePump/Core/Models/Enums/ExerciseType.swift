import Foundation

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case weighted
    case bodyweight
    case timeBased
    case distanceBased

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weighted: "Weighted"
        case .bodyweight: "Bodyweight"
        case .timeBased: "Time Based"
        case .distanceBased: "Distance Based"
        }
    }
}
