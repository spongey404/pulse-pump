import SwiftUI

/// The look of the asterisk after "Supernova", in one place: restyle it here, or set `isShown = false` to remove it from every
/// branded surface. It is the text character "*" in gold, raised the way the face draws it (a superscript mark), on purpose:
/// that is the design. In code the name stays "Supernova"; the "*" is added by `SupernovaWordmark`, never stored in a string.
enum SupernovaAsterisk {
    static let isShown = true
    static let glyph = "*"
    /// Asset-catalog colour (gold). A token, not a hex, so the app and the widget share it.
    static let colorName = "SupernovaGold"
    static var color: Color { Color(colorName) }
    /// Gap before the asterisk in em: the design uses 0.04 beside the 44pt paywall name and 0.06 elsewhere.
    static let gapEm: CGFloat = 0.06
    static let paywallGapEm: CGFloat = 0.04
}

/// Where the asterisk is on screen (global coordinates), so a `StarField` can pull its glitter toward it.
struct SupernovaAsteriskFrameKey: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = nextValue() ?? value }
}

/// "Supernova" + the gold "*", for branded surfaces only (paywall wordmark, "GO SUPERNOVA*", locked sections, the member tag).
/// Plain-text surfaces use `Brand.membershipName`.
///
/// VoiceOver reads "Supernova", not "Supernova asterisk".
struct SupernovaWordmark: View {
    enum Face { case archivo(Font.Weight), mono(bold: Bool) }

    var size: CGFloat
    var face: Face = .archivo(.black)
    var tracking: CGFloat = 0
    var color: Color = .white
    /// Text before the name on the same line, e.g. "GO " or "UNLOCK WITH ".
    var prefix: String = ""
    var uppercase = true
    /// Gap before the asterisk in em.
    var gapEm: CGFloat = SupernovaAsterisk.gapEm
    /// The name's opacity and downward offset, for the banner's staggered entrance. The asterisk is excluded: it is never
    /// faded or moved by them.
    var nameOpacity: Double = 1
    var nameOffsetY: CGFloat = 0
    /// The asterisk is swapped for the transition's flyer (hidden in one frame, never faded).
    var asteriskHidden = false

    private var fontName: String {
        switch face {
        case .archivo(let weight):
            switch weight {
            case .black, .heavy: "Archivo-Black"
            case .bold: "Archivo-Bold"
            case .semibold: "Archivo-SemiBold"
            default: "Archivo-Regular"
            }
        case .mono(let bold): bold ? "SpaceMono-Bold" : "SpaceMono-Regular"
        }
    }
    private var font: Font { Font.custom(fontName, size: size) }
    private var name: String { uppercase ? Brand.membershipName.uppercased() : Brand.membershipName }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(prefix + name)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .opacity(nameOpacity)
                .offset(y: nameOffsetY)
            if SupernovaAsterisk.isShown {
                Text(SupernovaAsterisk.glyph)
                    .font(font)
                    .foregroundStyle(SupernovaAsterisk.color)
                    .fixedSize()
                    .opacity(asteriskHidden ? 0 : 1)
                    .transaction { $0.animation = nil }
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: SupernovaAsteriskFrameKey.self, value: proxy.frame(in: .global))
                    })
                    .padding(.leading, size * gapEm + tracking)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(prefix + Brand.membershipName))
    }
}
