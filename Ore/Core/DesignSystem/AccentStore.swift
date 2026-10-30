import SwiftUI
import Observation

/// One selectable accent colour, from `supernovaMember.config.json` (the design's five: Sky, Pink, Signal red, Violet, Teal).
typealias AccentChoice = SupernovaMemberConfig.Accent

enum AccentChoices {
    /// The picker's choices.
    @MainActor static var all: [AccentChoice] { SupernovaMemberConfigStore.shared.current.accents }
    /// What nobody has changed: Ore's own accent. It is the first swatch (Sky), so it can always be put back; it is drawn with the
    /// catalogue colour, not the swatch's hex.
    @MainActor static var ore: AccentChoice { SupernovaMemberConfigStore.shared.current.accent(id: SupernovaMemberConfigStore.shared.current.defaultAccent) }
    @MainActor static func choice(id: String?) -> AccentChoice { SupernovaMemberConfigStore.shared.current.accent(id: id) }
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
        choiceId = defaults.string(forKey: Self.defaultsKey) ?? SupernovaMemberConfigStore.shared.current.defaultAccent
        isMember = SupernovaPaywallGate.isMember(defaults)
    }

    /// The accent in use: the member's pick, or Ore's.
    var active: AccentChoice { isMember ? AccentChoices.choice(id: choiceId) : AccentChoices.ore }
    /// What the member has picked, even while it isn't in use.
    var picked: AccentChoice { AccentChoices.choice(id: choiceId) }
    /// Ore's own colour is in use (the default pick, or not a member).
    var usesOreAccent: Bool { active.id == AccentChoices.ore.id }

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
    var accent: Color { usesOreAccent ? .oreAccentDefault : Color(hex: active.hex) }
    var accentInk: Color { usesOreAccent ? .accentInkDefault : Color(hex: active.hex) }
    /// 8% (light) / 14%… the catalogue's tint, 8% in both schemes.
    var accentSoft: Color { usesOreAccent ? .accentSoftDefault : Color(hex: active.hex).opacity(0.08) }

    /// Palette for the member glitter: the design's three stops for the chosen accent.
    var starPalette: StarPalette { active.palette }
}
