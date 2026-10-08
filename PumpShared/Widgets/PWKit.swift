import SwiftUI

// MARK: - Fixed widget kit
//
// Shared building blocks for every widget in Pump Widgets.dc.html. Each widget view lays itself
// out at the design's point size (`PWFamily.size`) and `PWFrame` scales it to the real container.

enum PWFamily: String, CaseIterable {
    case small, medium, large

    /// Design points (iPhone Pro Max home screen) from Pump Widgets.dc.html.
    var size: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
    }
    var padding: CGFloat { self == .large ? 16 : 14 }
}

enum PWVariant: String, CaseIterable, Codable { case a, b }

// MARK: Tokens beyond PumpTheme

extension PumpTheme {
    static func dyn(light: String, dark: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(pwHex: dark) : UIColor(pwHex: light) })
    }
    /// `--text-secondary` (ink-2 / bone-2)
    static var secondary: Color { dyn(light: "3A424D", dark: "C8BFB0") }
    /// `--text-ghost` (13% light / 18% dark)
    static var ghost: Color { Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(pwHex: "ECE5D6").withAlphaComponent(0.18) : UIColor(pwHex: "151A21").withAlphaComponent(0.13) }) }
    static var ruleStrong: Color { ink.opacity(0.14) }
    static var accentRow: Color { Color(pwHex: "1AA7FF").opacity(0.08) }
    static var accentBorder: Color { Color(pwHex: "1AA7FF").opacity(0.33) }
    static var deep: Color { dyn(light: "D4DAE2", dark: "363028") }
    // Ticker surface (3B)
    static var tickerBg: Color { dyn(light: "E0E5EB", dark: "0E0C0A") }
    static var tickerFg: Color { dyn(light: "151A21", dark: "ECE5D6") }
    static var tickerUp: Color { dyn(light: "00AA55", dark: "00E07A") }
    static var tickerDown: Color { dyn(light: "E5281C", dark: "FF3B30") }
    static var tickerSep: Color { Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(pwHex: "ECE5D6").withAlphaComponent(0.18) : UIColor(pwHex: "151A21").withAlphaComponent(0.20) }) }
}

extension UIColor {
    convenience init(pwHex hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
extension Color {
    init(pwHex hex: String) { self.init(UIColor(pwHex: hex)) }
}

// MARK: Frame (scale-to-fit)

/// Draws `content` at the family's design size and scales it to the available width.
/// `background` is on for the gallery / previews; WidgetKit supplies its own container background.
struct PWFrame<Content: View>: View {
    let family: PWFamily
    var background: Color? = nil
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / family.size.width
            content()
                .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
                .background {
                    if let background { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(background) }
                }
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: geo.size.width, height: family.size.height * s, alignment: .topLeading)
        }
        .aspectRatio(family.size.width / family.size.height, contentMode: .fit)
    }
}

// MARK: Typography

extension Text {
    /// Space Mono caption: uppercase label, tracked, muted by default.
    func pwCap(_ size: CGFloat = 9, tracking: CGFloat = 1.5, color: Color = PumpTheme.muted) -> some View {
        font(.spaceMono(size)).tracking(tracking).foregroundStyle(color)
    }
    /// Space Mono number / value.
    func pwMono(_ size: CGFloat, bold: Bool = false, color: Color = PumpTheme.ink, tracking: CGFloat = 0) -> some View {
        font(.spaceMono(size, weight: bold ? .bold : .regular)).tracking(tracking).foregroundStyle(color)
    }
    /// Archivo display (900) title.
    func pwDisplay(_ size: CGFloat, tracking: CGFloat = 0.3, color: Color = PumpTheme.ink) -> some View {
        font(.archivo(size, weight: .black)).tracking(tracking).foregroundStyle(color)
    }
    /// Archivo body.
    func pwBody(_ size: CGFloat, weight: Font.Weight = .semibold, color: Color = PumpTheme.ink) -> some View {
        font(.archivo(size, weight: weight)).foregroundStyle(color)
    }
}

// MARK: Components (design-system equivalents)

struct PWHair: View {
    var strong = false
    var vertical = false
    var body: some View {
        Rectangle().fill(strong ? PumpTheme.ruleStrong : PumpTheme.hair)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

/// Signed delta in signal colour: "▲ +11.9%".
struct PWTrend: View {
    let text: String
    var up: Bool?              // nil = neutral
    var size: CGFloat = 13
    var bold = true
    var arrow = true

    var body: some View {
        let glyph = up == true ? "▲ " : up == false ? "▼ " : ""
        Text((arrow ? glyph : "") + text)
            .pwMono(size, bold: bold, color: up == nil ? PumpTheme.muted : (up! ? PumpTheme.up : PumpTheme.down))
    }
}

/// PR value: ink with a 1.5px underline — never a colour.
struct PWPRMark: View {
    let value: String
    var label: String? = nil
    var size: CGFloat = 10
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value).pwMono(size, bold: true)
                .overlay(alignment: .bottom) { Rectangle().fill(PumpTheme.ink).frame(height: 1.5).offset(y: 3) }
            if let label { Text(label).pwCap(max(size - 3, 7), tracking: 1.2) }
        }
        .padding(.bottom, 3)
    }
}

/// Five-square prediction confidence (0–1).
struct PWConfidenceDots: View {
    let confidence: Double
    var showLabel = true
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Double(i) < (confidence * 5).rounded() ? PumpTheme.accent : PumpTheme.faint)
                        .frame(width: 5, height: 5)
                }
            }
            if showLabel {
                Text(confidence >= 0.7 ? "HIGH CONF" : confidence >= 0.4 ? "MED CONF" : "LOW CONF").pwCap(8, tracking: 1.2)
            }
        }
    }
}

/// Mon–Sun style bars with a letter under each; done = ink, today = accent, none = faint.
struct PWWeekBars: View {
    let data: [Double]
    let done: [Bool]
    var today: Int = -1
    var height: CGFloat = 44
    var letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let mx = max(data.max() ?? 1, 0.0001)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(data.enumerated()), id: \.offset) { i, v in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i == today ? PumpTheme.accent : (done.indices.contains(i) && done[i] ? PumpTheme.ink : PumpTheme.faint))
                        .frame(height: v > 0 ? max(2, height * v / mx) : 2)
                    Text(letters.indices.contains(i) ? letters[i] : "").pwCap(7, tracking: 0)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: height + 14, alignment: .bottom)
    }
}

/// Polyline through `values`, matching the design's spark() normalisation.
struct PWSpark: View {
    let values: [Double]
    var lineWidth: CGFloat = 1.5
    var color: Color = PumpTheme.ink

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard values.count > 1 else { return }
                let mn = values.min()!, mx = values.max()!, r = max(mx - mn, 0.0001)
                let w = geo.size.width, h = geo.size.height
                for (i, v) in values.enumerated() {
                    let pt = CGPoint(x: w * Double(i) / Double(values.count - 1), y: h - 2 - (v - mn) / r * (h - 4))
                    i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
        }
    }
}

/// Number formatting used across widgets.
enum PWFormat {
    static func signedPct(_ v: Double, digits: Int = 1) -> String {
        (v >= 0 ? "+" : "") + String(format: "%.\(digits)f%%", v)
    }
    static func trimmed(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
    static func thousands(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

// MARK: - Gallery registry

/// One drawn variant of a widget, e.g. "1A · SMALL". Each widget file exposes `static var gallery`.
struct PWGalleryItem: Identifiable {
    let id = UUID()
    let title: String
    let family: PWFamily
    let make: (PumpWidgetSnapshot) -> AnyView
    var isLock = false           // lock-screen accessory (rendered on a dark tile)
    var customSize: CGSize? = nil

    init(_ title: String, _ family: PWFamily, isLock: Bool = false, customSize: CGSize? = nil,
         _ make: @escaping (PumpWidgetSnapshot) -> AnyView) {
        self.title = title; self.family = family; self.make = make; self.isLock = isLock; self.customSize = customSize
    }
}

struct PWGallerySection: Identifiable {
    let id: String               // "01"
    let name: String             // "Next workout"
    let tier: String             // "FREE" / "PLUS"
    let blurb: String
    let items: [PWGalleryItem]
}
