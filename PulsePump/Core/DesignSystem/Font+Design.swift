import SwiftUI

extension Font {
    // MARK: - Archivo
    // Level 1 (screen titles, CTAs): weight .black → 900
    // Level 2 (content titles, program names): weight .bold → 700
    // Level 3 (exercise rows, session names): weight .semibold → 600
    // Level 4 body (descriptions, notes): weight .regular → 400
    // Conversational headings (onboarding): weight .light → 300
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

    // MARK: - Space Mono
    // All numbers, all labels, all metadata — always
    // weight .bold → SpaceMono-Bold (hero numbers, set row data)
    // weight .regular → SpaceMono-Regular (labels, timestamps, section headers)
    static func spaceMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = (weight == .bold || weight == .heavy || weight == .black || weight == .semibold)
            ? "SpaceMono-Bold"
            : "SpaceMono-Regular"
        return Font.custom(name, size: size)
    }

    // MARK: - Callsite aliases (keep existing callsites compiling)
    static func display(_ size: CGFloat) -> Font {
        archivo(size, weight: .black)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        spaceMono(size, weight: weight)
    }
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        archivo(size, weight: weight)
    }
}

// MARK: - Label style: Space Mono all-caps tracked (section headers, metadata)
struct MonoLabelStyle: ViewModifier {
    let size: CGFloat
    var color: Color = Color.accentInk

    func body(content: Content) -> some View {
        content
            .font(.spaceMono(size))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

// MARK: - Column/table label: muted, all-caps, 1.5px tracking
struct CardLabelStyle: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.spaceMono(size))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
    }
}

extension View {
    func monoLabel(_ size: CGFloat = 9) -> some View {
        modifier(MonoLabelStyle(size: size))
    }
    func monoLabel(_ size: CGFloat = 9, color: Color) -> some View {
        modifier(MonoLabelStyle(size: size, color: color))
    }
    func cardLabel(_ size: CGFloat = 9) -> some View {
        modifier(CardLabelStyle(size: size))
    }
}
