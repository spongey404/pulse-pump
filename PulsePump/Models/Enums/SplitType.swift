import Foundation

enum SplitType: String, Codable, CaseIterable, Identifiable {
    case ppl
    case upperLower
    case fullBody
    case broSplit
    case arnoldSplit
    case pushPullLegs
    case torsoLimbs
    case custom
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ppl: "Push/Pull/Legs"
        case .upperLower: "Upper/Lower"
        case .fullBody: "Full Body"
        case .broSplit: "Bro Split"
        case .arnoldSplit: "Arnold Split"
        case .pushPullLegs: "Push/Pull/Legs (6-day)"
        case .torsoLimbs: "Torso/Limbs"
        case .custom: "Custom"
        case .none: "No Split"
        }
    }

    var daysPerWeek: Int? {
        switch self {
        case .ppl: 6
        case .upperLower: 4
        case .fullBody: 3
        case .broSplit: 5
        case .arnoldSplit: 6
        case .pushPullLegs: 6
        case .torsoLimbs: 4
        case .custom, .none: nil
        }
    }
}
