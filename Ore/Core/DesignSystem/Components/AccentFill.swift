import SwiftUI

/// At most ~4 Stardust buttons animate on screen at once: docked primaries first (higher `priority`), then the top-most. The others draw
/// the plain accent. A button that is scrolled off screen gives its place up.
@MainActor
@Observable
final class StardustLimiter {
    static let shared = StardustLimiter()
    static let maxActive = 4

    struct Claim: Equatable { var priority: Int; var y: CGFloat }
    private(set) var claims: [UUID: Claim] = [:]

    /// The buttons that may animate now.
    var active: Set<UUID> { Self.winners(claims, limit: Self.maxActive) }

    /// Pure: highest priority first, then top-most on screen.
    static func winners(_ claims: [UUID: Claim], limit: Int) -> Set<UUID> {
        Set(claims.sorted { a, b in a.value.priority != b.value.priority ? a.value.priority > b.value.priority : a.value.y < b.value.y }
            .prefix(limit).map(\.key))
    }

    func update(_ id: UUID, priority: Int, y: CGFloat, visible: Bool) {
        let c = Claim(priority: priority, y: y)
        if visible { if claims[id] != c { claims[id] = c } } else { claims[id] = nil }
    }

    func remove(_ id: UUID) { claims[id] = nil }
}

/// The fill of a filled-accent button. Normally the accent colour; for a Supernova member who turned on Appearance › Stardust buttons,
/// the Stardust drifts over it in their colour. Use it as `.background { AccentFill() }` before the button's `clipShape`, or as an
/// `.overlay` on an accent-filled shape (it draws the colour too, so the overlay only needs the same clip).
///
/// Only solid accent buttons that perform a primary action use it (docked primaries, in-content primaries, accent "+" buttons); selection
/// states (selected chips, segments, day tiles, ADDED tags, the active row), outlined / grey / destructive buttons and anything under about
/// 32 pt never do. `priority` ranks docked primaries (10) above in-content ones (5) when more than four are on screen.
struct AccentFill: View {
    var priority = 5
    /// The Stardust variant and its density / sparkle / fps (the docked CTAs use "cta"; small actions "toggle").
    var variant = "button"
    var density: Double = 1200
    var gold: Double? = nil
    var sparkle: Double? = nil
    var fps = 20
    @State private var id = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let store = AccentStore.shared
        let limiter = StardustLimiter.shared
        ZStack {
            Color.oreAccent
            if store.stardustEnabled && limiter.active.contains(id) {
                StardustView(variant: variant, budget: .more,
                             overrides: StardustParams.Overrides(palette: store.starPalette, density: density, gold: gold, sparkle: sparkle, fps: min(fps, 30)),
                             frozen: reduceMotion)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { y in
            limiter.update(id, priority: priority, y: y, visible: store.stardustEnabled && y > -60 && y < UIScreen.main.bounds.height)
        }
        .onDisappear { limiter.remove(id) }
    }
}
