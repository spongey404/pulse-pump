import Foundation

// UnitPreference (kg / lbs) lives in OreShared/WeightUnit.swift so the widget extension shares it.

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case experienced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner:     "New to lifting"
        case .intermediate: "Some experience"
        case .experienced:  "Advanced lifter"
        }
    }

    var sub: String {
        switch self {
        case .beginner:     "Less than 1 year of consistent training"
        case .intermediate: "1–3 years of consistent training"
        case .experienced:  "3+ years, training with intention"
        }
    }

    var detail: String {
        switch self {
        case .beginner:     "We'll guide you through the basics and build your first program."
        case .intermediate: "You know the lifts. We'll help you track and progress."
        case .experienced:  "Minimal setup. Full control. We'll get out of your way."
        }
    }
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case nonBinary
    case other
    case preferNotToSay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male:           "Male"
        case .female:         "Female"
        case .nonBinary:      "Non-binary"
        case .other:          "Other"
        case .preferNotToSay: "Prefer not to say"
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
