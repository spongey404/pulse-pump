import Foundation

enum MuscleSubRegion: String, Codable, CaseIterable, Identifiable {
    // Chest
    case upperChest
    case lowerChest

    // Back
    case upperBackRhomboids
    case latsSubRegion
    case lowerBackErectors

    // Traps
    case upperTraps
    case lowerTraps

    // Biceps
    case bicepsLongHead
    case bicepsShortHead
    case brachialis

    // Triceps
    case tricepsLongHead
    case tricepsLateralHead
    case tricepsMedialHead

    // Forearms
    case wristFlexors
    case wristExtensors
    case brachioradialis

    // Quads
    case rectusFemoris
    case vastusLateralis
    case vastusMedialis
    case vastusIntermedius

    // Hamstrings
    case bicepsFemoris
    case semitendinosus
    case semimembranosus

    // Glutes
    case gluteusMaximus
    case gluteusMedius
    case gluteusMinimus

    // Calves
    case gastrocnemius
    case soleus

    // Abs
    case upperAbs
    case lowerAbs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        // Chest
        case .upperChest: "Upper Chest"
        case .lowerChest: "Lower Chest"
        // Back
        case .upperBackRhomboids: "Upper Back (Rhomboids)"
        case .latsSubRegion: "Lats"
        case .lowerBackErectors: "Lower Back (Erectors)"
        // Traps
        case .upperTraps: "Upper Traps"
        case .lowerTraps: "Lower Traps"
        // Biceps
        case .bicepsLongHead: "Long Head"
        case .bicepsShortHead: "Short Head"
        case .brachialis: "Brachialis"
        // Triceps
        case .tricepsLongHead: "Long Head"
        case .tricepsLateralHead: "Lateral Head"
        case .tricepsMedialHead: "Medial Head"
        // Forearms
        case .wristFlexors: "Wrist Flexors"
        case .wristExtensors: "Wrist Extensors"
        case .brachioradialis: "Brachioradialis"
        // Quads
        case .rectusFemoris: "Rectus Femoris"
        case .vastusLateralis: "Vastus Lateralis"
        case .vastusMedialis: "Vastus Medialis"
        case .vastusIntermedius: "Vastus Intermedius"
        // Hamstrings
        case .bicepsFemoris: "Biceps Femoris"
        case .semitendinosus: "Semitendinosus"
        case .semimembranosus: "Semimembranosus"
        // Glutes
        case .gluteusMaximus: "Gluteus Maximus"
        case .gluteusMedius: "Gluteus Medius"
        case .gluteusMinimus: "Gluteus Minimus"
        // Calves
        case .gastrocnemius: "Gastrocnemius"
        case .soleus: "Soleus"
        // Abs
        case .upperAbs: "Upper Abs"
        case .lowerAbs: "Lower Abs"
        }
    }

    var parentGroup: MuscleGroup {
        switch self {
        case .upperChest, .lowerChest:
            return .chest
        case .upperBackRhomboids:
            return .upperBack
        case .latsSubRegion:
            return .lats
        case .lowerBackErectors:
            return .lowerBack
        case .upperTraps, .lowerTraps:
            return .traps
        case .bicepsLongHead, .bicepsShortHead, .brachialis:
            return .biceps
        case .tricepsLongHead, .tricepsLateralHead, .tricepsMedialHead:
            return .triceps
        case .wristFlexors, .wristExtensors, .brachioradialis:
            return .forearms
        case .rectusFemoris, .vastusLateralis, .vastusMedialis, .vastusIntermedius:
            return .quads
        case .bicepsFemoris, .semitendinosus, .semimembranosus:
            return .hamstrings
        case .gluteusMaximus, .gluteusMedius, .gluteusMinimus:
            return .glutes
        case .gastrocnemius, .soleus:
            return .calves
        case .upperAbs, .lowerAbs:
            return .abs
        }
    }

    /// Returns all sub-regions for a given parent muscle group.
    /// Returns empty array for groups without sub-regions (adductors, abductors, obliques, etc.)
    static func subRegions(for parent: MuscleGroup) -> [MuscleSubRegion] {
        allCases.filter { $0.parentGroup == parent }
    }

    /// Whether a given muscle group has sub-regions
    static func hasSubRegions(_ parent: MuscleGroup) -> Bool {
        !subRegions(for: parent).isEmpty
    }
}
