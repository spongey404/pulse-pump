import SwiftUI
import Observation

/// One selectable accent colour.
struct AccentChoice: Identifiable, Equatable {
    let id: String
    let name: String
    let hex: String
    var rgba: StarRGBA { StarRGBA(css: hex) ?? StarRGBA(r: 26, g: 167, b: 255) }
}

enum AccentChoices {
    /// The app's own accent, what everyone without Supernova sees.
    static let ore = AccentChoice(id: "ore", name: "Ore", hex: "#1AA7FF")
    /// Ore first, then the blue family from the Supernova design's palettes, then a few that aren't blue. Amber is left out
    /// on purpose: it is reserved for Fuel's over-target signal, and gold for Supernova itself.
    static let all: [AccentChoice] = [
        ore,
        AccentChoice(id: "sky", name: "Sky", hex: "#3DB8FF"),
        AccentChoice(id: "electric", name: "Electric", hex: "#1A8CFF"),
        AccentChoice(id: "cyan", name: "Cyan", hex: "#14B4F0"),
        AccentChoice(id: "indigo", name: "Indigo", hex: "#5B6CFF"),
        AccentChoice(id: "violet", name: "Violet", hex: "#9B6BFF"),
        AccentChoice(id: "pink", name: "Pink", hex: "#FD4A9F"),
        AccentChoice(id: "coral", name: "Coral", hex: "#FF6B57"),
        AccentChoice(id: "mint", name: "Mint", hex: "#19C3A1"),
    ]
    static func choice(id: String?) -> AccentChoice { all.first { $0.id == id } ?? ore }
}

/// The accent colour the whole app draws with. Everyone sees Ore's accent; a Supernova member's own choice replaces it.
///
/// `Color.oreAccent`, `.accentInk` and `.accentSoft` read from here, so a view that uses them re-renders when the choice
/// changes (the store is `@Observable`, and reading it inside `body` is tracked). The choice is local to the device;
/// a lapsed membership goes back to Ore's accent without losing the choice.
@MainActor
@Observable
final class AccentStore {
    static let shared = AccentStore()
    static let defaultsKey = "accentChoiceId"

    private let defaults: UserDefaults
    private(set) var choiceId: String
    private(set) var isMember: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        choiceId = defaults.string(forKey: Self.defaultsKey) ?? AccentChoices.ore.id
        isMember = SupernovaPaywallGate.isMember(defaults)
    }

    /// The accent in use: the member's pick, or Ore's.
    var active: AccentChoice { isMember ? AccentChoices.choice(id: choiceId) : AccentChoices.ore }
    /// What the member has picked, even while it isn't in use.
    var picked: AccentChoice { AccentChoices.choice(id: choiceId) }

    func select(_ choice: AccentChoice) {
        choiceId = choice.id
        defaults.set(choice.id, forKey: Self.defaultsKey)
    }

    /// Re-reads membership (after a purchase, a restore, or the status refresh).
    func refreshMembership() {
        let member = SupernovaPaywallGate.isMember(defaults)
        if member != isMember { isMember = member }
    }

    // MARK: Tokens

    /// Ore's own accent comes from the asset catalogue; a member's pick is a flat colour in both schemes.
    var accent: Color { active == AccentChoices.ore ? .oreAccentDefault : Color(hex: active.hex) }
    var accentInk: Color { active == AccentChoices.ore ? .accentInkDefault : Color(hex: active.hex) }
    /// 8% (light) / 14%… the catalogue's tint, 8% in both schemes.
    var accentSoft: Color { active == AccentChoices.ore ? .accentSoftDefault : Color(hex: active.hex).opacity(0.08) }

    /// Palette for the member glitter, derived from the accent.
    var starPalette: StarPalette { StarPalette.derived(fromAccent: active.rgba) }
}
