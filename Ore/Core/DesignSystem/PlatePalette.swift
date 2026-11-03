import SwiftUI

/// The plate colour tokens (IPF), one place for the logger's plate calculator, the plate calculator tool and Equipment:
/// 25 #E51B1B, 20 #1F4EA3, 15 #F2C200 (dark text), 10 #1F8F5A, 5 #F4F4F2 (dark text, hairline), 2.5 #151515 (white text, light hairline),
/// 1.25 chrome gradient (dark text).
enum PlatePalette {
    struct Style {
        var fill: Color
        /// Only the chrome plate has a second stop (a vertical gradient).
        var fillBottom: Color?
        var text: Color
        var border: Color?

        var shape: AnyShapeStyle {
            if let fillBottom { AnyShapeStyle(LinearGradient(colors: [fill, fillBottom], startPoint: .top, endPoint: .bottom)) } else { AnyShapeStyle(fill) }
        }
    }

    private static let dark = Color(hex: "#151A21")

    static func style(_ tier: PlateMath.Tier) -> Style {
        switch tier {
        case .red: Style(fill: Color(hex: "#E51B1B"), text: .white)
        case .blue: Style(fill: Color(hex: "#1F4EA3"), text: .white)
        case .yellow: Style(fill: Color(hex: "#F2C200"), text: dark)
        case .green: Style(fill: Color(hex: "#1F8F5A"), text: .white)
        case .white: Style(fill: Color(hex: "#F4F4F2"), text: dark, border: Color(red: 21 / 255, green: 26 / 255, blue: 33 / 255).opacity(0.28))
        case .black: Style(fill: Color(hex: "#151515"), text: .white, border: Color.white.opacity(0.28))
        case .chrome: Style(fill: Color(hex: "#E6E8EA"), fillBottom: Color(hex: "#A9AEB3"), text: dark, border: Color(red: 21 / 255, green: 26 / 255, blue: 33 / 255).opacity(0.2))
        }
    }

    static func style(forKg kg: Double) -> Style { style(PlateMath.tier(forKg: kg)) }

    /// Drawn size (points) of a plate on the bar: the design's heights and widths per plate.
    static func size(_ tier: PlateMath.Tier) -> CGSize {
        switch tier {
        case .red: CGSize(width: 16, height: 68)
        case .blue: CGSize(width: 15, height: 68)
        case .yellow: CGSize(width: 14, height: 60)
        case .green: CGSize(width: 12, height: 50)
        case .white: CGSize(width: 10, height: 38)
        case .black: CGSize(width: 8, height: 28)
        case .chrome: CGSize(width: 7, height: 22)
        }
    }
}

/// A plate tag (take off / put on, or the chips elsewhere): 20 pt tall, radius 4, the plate's colours, its number in Space Mono bold.
struct PlateTag: View {
    let label: String
    let kg: Double
    var body: some View {
        let st = PlatePalette.style(forKg: kg)
        Text(label).font(.spaceMono(10, weight: .bold)).foregroundStyle(st.text)
            .padding(.horizontal, 5).frame(minWidth: 24).frame(height: 20)
            .background(st.shape, in: RoundedRectangle(cornerRadius: 4))
            .overlay { if let b = st.border { RoundedRectangle(cornerRadius: 4).strokeBorder(b, lineWidth: 1) } }
    }
}
