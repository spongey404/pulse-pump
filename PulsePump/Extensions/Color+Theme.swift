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

    // MARK: - Legacy aliases
    static var pumpPrimary: Color { Color.pumpAccent }
    static var pumpSoft: Color   { Color.pumpAccent.opacity(0.08) }

    // MARK: - Design-reference token names
    static var accentSoft: Color  { Color.pumpAccent.opacity(0.08) }
    static var activeRowBg: Color { Color.pumpAccent.opacity(0.07) }

    // MARK: - Derived opacity tokens
    static var inkMuted: Color   { Color.inkPrimary.opacity(0.50) }
    static var inkFaint: Color   { Color.inkPrimary.opacity(0.13) }
    static var dsHairLine: Color { Color.inkPrimary.opacity(0.08) }

    // MARK: - Ticker bar (adapts to color scheme — use TickerStripView which reads environment)
    static let tickerBgDark  = Color(hex: "#1a1816")
    static let tickerFgDark  = Color(hex: "#ece5d6")
    static let tickerBgLight = Color(hex: "#f0ebe0")
    static let tickerFgLight = Color(hex: "#1a1816")

    // Legacy: keep tickerBg/tickerFg pointing to dark variant for any hardcoded uses
    static let tickerBg = Color(hex: "#1a1816")
    static let tickerFg = Color(hex: "#ece5d6")
}
