import SwiftUI
import Observation

/// The accent colour the whole app draws with. Everyone sees Ore's accent; a Supernova member's own colour (More › Supernova
/// membership › Account) replaces it.
///
/// The member picks any colour: a preset, a typed hex, or the hue / saturation / shade sliders (`AccentMath`). The pick is kept per
/// account on this device (`setAccount`), together with the presets & recent row. `Color.oreAccent`, `.accentInk` and
/// `.accentSoft` read from here, so a view that uses them re-renders as the colour moves (the store is `@Observable`, and reading it
/// inside `body` is tracked). A lapsed membership goes back to Ore's accent without losing the pick.
@MainActor
@Observable
final class AccentStore {
    static let shared = AccentStore()
    static let defaultsPrefix = "accentState.v2"

    private struct Saved: Codable {
        var pick: AccentPick
        var swatches: [AccentSwatch]
        var stardustEnabled: Bool?
        /// The saved blob still has the pre-rename `glitterButtons` key: it is read once and rewritten as `stardustEnabled` at once.
        var migrated = false

        enum CodingKeys: String, CodingKey { case pick, swatches, stardustEnabled, legacyGlitterButtons = "glitterButtons" }

        init(pick: AccentPick, swatches: [AccentSwatch], stardustEnabled: Bool?) {
            self.pick = pick; self.swatches = swatches; self.stardustEnabled = stardustEnabled
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            pick = try c.decode(AccentPick.self, forKey: .pick)
            swatches = try c.decode([AccentSwatch].self, forKey: .swatches)
            if let now = try c.decodeIfPresent(Bool.self, forKey: .stardustEnabled) {
                stardustEnabled = now
            } else if let old = try c.decodeIfPresent(Bool.self, forKey: .legacyGlitterButtons) {
                stardustEnabled = old
                migrated = true
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pick, forKey: .pick)
            try c.encode(swatches, forKey: .swatches)
            try c.encodeIfPresent(stardustEnabled, forKey: .stardustEnabled)
        }
    }

    private let defaults: UserDefaults
    private var accountKey: String
    private(set) var pick: AccentPick
    private(set) var swatches: [AccentSwatch]
    /// The member's setting: filled accent buttons get the Stardust behind their label (Appearance tab).
    private(set) var stardustSetting: Bool
    private(set) var isMember: Bool

    init(defaults: UserDefaults = .standard, account: String? = nil) {
        self.defaults = defaults
        accountKey = account ?? "-"
        let loaded = Self.load(defaults: defaults, key: Self.key(account))
        pick = loaded.pick
        swatches = loaded.swatches
        stardustSetting = loaded.stardustEnabled ?? true
        isMember = SupernovaPaywallGate.isMember(defaults)
    }

    // MARK: Config

    private static var picker: SupernovaMemberConfig.Picker { SupernovaMemberConfigStore.shared.current.picker }
    private static func key(_ account: String?) -> String { "\(defaultsPrefix).\(account ?? "-")" }

    /// Ore's own colour as a pick: the first preset (Sky).
    static var defaultPick: AccentPick {
        let c = AccentMath.hsl(fromHex: picker.defaultHex) ?? (201, 100, 62)
        return AccentPick(h: c.h, s: c.s, l: c.l, hex: AccentMath.normalizeHex(picker.defaultHex))
    }

    private static func load(defaults: UserDefaults, key: String) -> Saved {
        let fresh = Saved(pick: defaultPick, swatches: AccentMath.defaultSwatches(picker), stardustEnabled: true)
        guard let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return fresh }
        let result = Saved(pick: saved.pick, swatches: AccentMath.normalized(saved.swatches, picker: picker), stardustEnabled: saved.stardustEnabled)
        if saved.migrated, let out = try? JSONEncoder().encode(result) { defaults.set(out, forKey: key) }   // read the old key, write the new one, drop the old
        return result
    }

    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// A slider moves the colour every frame; writing it that often is wasted work, so a change is saved shortly after it stops.
    private func saveSoon() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { self?.save() }
        }
    }

    /// Writes any pending change now (leaving the page, switching account, tests).
    func flush() { saveTask?.cancel(); saveTask = nil; save() }

    private func save() {
        guard let data = try? JSONEncoder().encode(Saved(pick: pick, swatches: swatches, stardustEnabled: stardustSetting)) else { return }
        defaults.set(data, forKey: Self.key(accountKey == "-" ? nil : accountKey))
    }

    // MARK: State

    /// The accent in use: the member's pick, or Ore's.
    var active: AccentPick { isMember ? pick : Self.defaultPick }
    /// What the member has picked, even while it isn't in use.
    var picked: AccentPick { pick }
    /// Ore's own colour is in use (not a member, or the default pick).
    var usesOreAccent: Bool { active.hexString == Self.defaultPick.hexString }
    /// The name shown under the hex field.
    var pickedName: String { AccentMath.name(for: pick, in: swatches) }

    /// The picker changes the colour (live: the page Stardust, the card Stardust and the app follow).
    func set(_ new: AccentPick) {
        guard new != pick else { return }
        pick = new
        saveSoon()
    }

    /// Filled accent buttons show the Stardust: the member's setting, and only while the membership is active.
    var stardustEnabled: Bool { isMember && stardustSetting }

    func setStardustEnabled(_ on: Bool) {
        guard on != stardustSetting else { return }
        stardustSetting = on
        flush()
    }

    /// The member leaves the page: the colour goes to the front of the recent row.
    func commitColour() {
        let next = AccentMath.committed(swatches, pick: pick, limit: Self.picker.recentLimit)
        guard next != swatches else { flush(); return }
        swatches = next
        flush()
    }

    /// Another account signed in (or out): its own pick and recent row.
    func setAccount(_ uid: String?) {
        let key = uid ?? "-"
        guard key != accountKey else { return }
        flush()   // the account we are leaving keeps its latest colour
        accountKey = key
        let loaded = Self.load(defaults: defaults, key: Self.key(uid))
        pick = loaded.pick
        swatches = loaded.swatches
        stardustSetting = loaded.stardustEnabled ?? true
    }

    /// Re-reads membership (after a purchase, a restore, or the status refresh).
    func refreshMembership() {
        let member = SupernovaPaywallGate.isMember(defaults)
        if member != isMember { isMember = member }
    }

    // MARK: Tokens

    /// Ore's own accent comes from the asset catalogue; a member's pick is a flat colour in both schemes.
    var accent: Color { usesOreAccent ? .oreAccentDefault : Color(hex: active.hexString) }
    var accentInk: Color { usesOreAccent ? .accentInkDefault : Color(hex: active.hexString) }
    /// The catalogue's tint, 8% in both schemes.
    var accentSoft: Color { usesOreAccent ? .accentSoftDefault : Color(hex: active.hexString).opacity(0.08) }

    /// Palette for the member Stardust, derived from the colour (`AccentMath.palette`).
    var starPalette: StarPalette { AccentMath.palette(for: active, rule: Self.picker.palette) }
    /// The same for what the member has picked, even while it isn't in use (the membership page and card).
    var pickedPalette: StarPalette { AccentMath.palette(for: pick, rule: Self.picker.palette) }
}
