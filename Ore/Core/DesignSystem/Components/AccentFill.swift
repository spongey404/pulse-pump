import SwiftUI

/// The fill of a filled-accent button. Normally the accent colour; for a Supernova member who turned on Appearance › Stardust buttons,
/// the Stardust drifts over it in their colour. Use it as `.background { AccentFill() }` before the button's `clipShape`, or as an
/// `.overlay` on an accent-filled shape (it draws the colour too, so the overlay only needs the same clip).
///
/// Only buttons that are filled with the accent by default use it; outlined, text-only and destructive buttons never do.
struct AccentFill: View {
    var body: some View {
        let store = AccentStore.shared
        ZStack {
            Color.oreAccent
            if store.stardustEnabled {
                StardustView(variant: "button", budget: .more,
                              overrides: StardustParams.Overrides(palette: store.starPalette, density: 1200, fps: 20))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}
