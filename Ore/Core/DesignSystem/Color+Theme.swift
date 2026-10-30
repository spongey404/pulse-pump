import SwiftUI

extension Color {
    // MARK: - Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// Light/dark pair resolved at render time.
    init(light: String, dark: String) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }

    // MARK: - Legacy aliases
    static var oreSoft: Color   { Color.accentSoft }

    // MARK: - Accent
    // `oreAccent` (#0A6FC0, flat in both schemes) is for FILLED surfaces —
    // CTA fill, tab-bar active fill, chip fill — so white `onAccent` text keeps its contrast.
    // `accentInk` (AccentInk.colorset) lifts to #4DB8FF on the dark canvas and is for accent
    // TEXT, glyphs, borders and the active-row left border, which read as under-saturated ink
    // at #0A6FC0 on a dark background. `accentSoft` (AccentSoft.colorset) is the matching
    // 8%-light/14%-dark tint. Both are Xcode-generated asset symbols — no declaration needed
    // here. See design_handoff_pulse_color_system/README.md.
    static var onAccent: Color    { .white }
    static var activeRowBg: Color { Color.accentSoft }

    // MARK: - Derived opacity tokens
    static var inkMuted: Color   { Color.inkPrimary.opacity(0.50) }
    /// `--text-secondary` (ink-2 / bone-2).
    static var inkSecondary: Color { Color(light: "#3A424D", dark: "#C8BFB0") }
    static var inkFaint: Color   { Color.inkPrimary.opacity(0.13) }
    static var dsHairLine: Color { Color.inkPrimary.opacity(0.08) }
    // `--rule-strong` (design_handoff_social_tab) — 14% ink, one step up from dsHairLine.
    static var ruleStrong: Color { Color.inkPrimary.opacity(0.14) }

    // MARK: - Social tab: leaderboard medals (deliberate spec deviation)
    // Ranks 1/2/3 — darkened from the obvious medal colours to clear 4.5:1 contrast on
    // cream. See design/design_handoff_social_tab/README.md "Deliberate deviations from the system".
    static let medalGold   = Color(hex: "#A06E1E")
    static let medalSteel  = Color(hex: "#6E7C87")
    static let medalBronze = Color(hex: "#96602A")

    // MARK: - Ticker bar (adapts to color scheme — use TickerStripView which reads environment)
    static let tickerBgDark  = Color(hex: "#0E0C0A")
    static let tickerFgDark  = Color(hex: "#ECE5D6")
    static let tickerBgLight = Color(hex: "#E0E5EB")   // --surface-sunken
    static let tickerFgLight = Color(hex: "#151A21")

    // Legacy: keep tickerBg/tickerFg pointing to dark variant for any hardcoded uses
    static let tickerBg = Color(hex: "#0E0C0A")
    static let tickerFg = Color(hex: "#ECE5D6")
}
