import Foundation

enum UnitPreference: String, Codable, CaseIterable, Identifiable {
    case kg
    case lbs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kg: "Kilograms (kg)"
        case .lbs: "Pounds (lbs)"
        }
    }

    var abbreviation: String {
        rawValue
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case experienced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .experienced: "Experienced"
        }
    }
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case other
    case preferNotToSay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .other: "Other"
        case .preferNotToSay: "Prefer Not to Say"
        }
    }
}

enum Side: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .both: "Both"
        }
    }
}
