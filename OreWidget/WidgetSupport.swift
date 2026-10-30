import SwiftUI

// The app's `Font+Design` / `Color+Theme` helpers aren't visible to the extension; OreShared
// code uses the same names, so they're mirrored here.

extension Font {
    static func archivo(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black, .heavy:             name = "Archivo-Black"
        case .bold:                      name = "Archivo-Bold"
        case .semibold:                  name = "Archivo-SemiBold"
        case .light, .thin, .ultraLight: name = "Archivo-Light"
        default:                         name = "Archivo-Regular"
        }
        return Font.custom(name, size: size)
    }

    static func spaceMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let bold = (weight == .bold || weight == .heavy || weight == .black || weight == .semibold)
        return Font.custom(bold ? "SpaceMono-Bold" : "SpaceMono-Regular", size: size)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
