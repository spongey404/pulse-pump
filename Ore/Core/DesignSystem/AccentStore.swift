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

    private struct Saved: Codable { var pick: AccentPick; var swatches: [AccentSwatch] }

    private let defaults: UserDefaults
    private var accountKey: String
    private(set) var pick: AccentPick
    private(set) var swatches: [AccentSwatch]
    private(set) var isMember: Bool

    init(defaults: UserDefaults = .standard, account: String? = nil) {
        self.defaults = defaults
        accountKey = account ?? "-"
        let loaded = Self.load(defaults: defaults, key: Self.key(account))
        pick = loaded.pick
        swatches = loaded.swatches
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
        let fresh = Saved(pick: defaultPick, swatches: AccentMath.defaultSwatches(picker))
        guard let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return fresh }
        return Saved(pick: saved.pick, swatches: AccentMath.normalized(saved.swatches, picker: picker))
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
        guard let data = try? JSONEncoder().encode(Saved(pick: pick, swatches: swatches)) else { return }
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

    /// The picker changes the colour (live: the page glitter, the card glitter and the app follow).
    func set(_ new: AccentPick) {
        guard new != pick else { return }
        pick = new
        saveSoon()
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

    /// Palette for the member glitter, derived from the colour (`AccentMath.palette`).
    var starPalette: StarPalette { AccentMath.palette(for: active, rule: Self.picker.palette) }
    /// The same for what the member has picked, even while it isn't in use (the membership page and card).
    var pickedPalette: StarPalette { AccentMath.palette(for: pick, rule: Self.picker.palette) }
}
