import SwiftUI

/// The look of the asterisk after "Supernova", in one place: restyle it here, or set `isShown = false` to
/// remove it from every branded surface. It is a drawn six-point asterisk centred on the cap height, not a text
/// "*" (which sits raised and reads as a footnote marker).
enum SupernovaAsterisk {
    static let isShown = true
    /// Asset-catalog colour (gold). A token, not a hex, so the app and the widget share it.
    static let colorName = "SupernovaGold"
    static var color: Color { Color(colorName) }
    /// Spokes (a six-point asterisk is three crossing strokes).
    static let spokes = 3
    /// Width/height as a multiple of the type size.
    static let sizeEm: CGFloat = 0.46
    /// Stroke thickness as a fraction of the asterisk's size.
    static let strokeFraction: CGFloat = 0.2
    /// Gap before the asterisk, in em.
    static let gapEm: CGFloat = 0.07
}

/// Three strokes through the centre, 60° apart: six points.
struct SixPointAsterisk: Shape {
    var strokeFraction: CGFloat = SupernovaAsterisk.strokeFraction

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let half = size / 2
        let thickness = size * strokeFraction
        var path = Path()
        for i in 0..<SupernovaAsterisk.spokes {
            let angle = Double(i) * .pi / Double(SupernovaAsterisk.spokes)
            let bar = Path(roundedRect: CGRect(x: -half, y: -thickness / 2, width: size, height: thickness),
                           cornerRadius: thickness * 0.2)
            path.addPath(bar, transform: CGAffineTransform(rotationAngle: angle + .pi / 2)
                .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y)))
        }
        return path
    }
}

/// Where the asterisk is on screen (global coordinates), so a `StarField` can pull its glitter toward it.
struct SupernovaAsteriskFrameKey: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = nextValue() ?? value }
}

/// "Supernova" + the gold asterisk, for branded surfaces only (paywall wordmark, "GO SUPERNOVA*", locked
/// sections, the More row). Plain-text surfaces use `Brand.membershipName`.
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
    /// Cap height of the face, so the asterisk is centred on the capitals rather than the line box.
    private var capHeight: CGFloat { UIFont(name: fontName, size: size)?.capHeight ?? size * 0.7 }
    private var name: String { uppercase ? Brand.membershipName.uppercased() : Brand.membershipName }
    private var asteriskSize: CGFloat { size * SupernovaAsterisk.sizeEm }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(prefix + name)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
            if SupernovaAsterisk.isShown {
                SixPointAsterisk()
                    .fill(SupernovaAsterisk.color)
                    .frame(width: asteriskSize, height: asteriskSize)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: SupernovaAsteriskFrameKey.self, value: proxy.frame(in: .global))
                    })
                    .padding(.leading, size * SupernovaAsterisk.gapEm + tracking)
                    // Baseline of the row sits capHeight/2 below the asterisk's centre.
                    .alignmentGuide(.firstTextBaseline) { $0.height / 2 + capHeight / 2 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(prefix + Brand.membershipName))
    }
}
