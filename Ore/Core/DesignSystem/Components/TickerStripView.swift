import SwiftUI

struct TickerItem: Equatable {
    let label: String
    let value: String
    let direction: Direction?
    /// Suppresses the auto-prepended ▲/▼ for items whose value already carries its own
    /// glyph (e.g. a "★" PR item) — direction still drives the value's colour.
    var showArrow: Bool = true
    /// A personal-record item: label and value in PR gold (#C9892E).
    var gold: Bool = false

    enum Direction: Equatable { case up, down }
}

struct TickerStripView: View {
    let items: [TickerItem]
    @Environment(\.colorScheme) private var colorScheme
    @State private var startDate = Date()

    private var bg: Color { colorScheme == .dark ? Color.tickerBgDark : Color.tickerBgLight }
    private var fg: Color { colorScheme == .dark ? Color.tickerFgDark : Color.tickerFgLight }

    private let speed: Double = 40.0 // points per second

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                guard !items.isEmpty, size.width > 0 else { return }

                let elapsed = timeline.date.timeIntervalSince(startDate)
                let measureBounds = CGSize(width: 10_000, height: size.height)
                let midY = size.height / 2

                // Resolve text symbols and compute one full tile width. Arrow and value are
                // resolved as separate runs (not one concatenated string) so the gap between
                // them is an explicit, fixed pixel value — not at the mercy of `.tracking()`
                // compounding with a literal space character.
                var labels: [GraphicsContext.ResolvedText] = []
                var arrows: [GraphicsContext.ResolvedText?] = []
                var values: [GraphicsContext.ResolvedText] = []
                var dots:   [GraphicsContext.ResolvedText] = []
                var widths: [(l: CGFloat, a: CGFloat, v: CGFloat, d: CGFloat)] = []
                var tileW:  CGFloat = 0
                let arrowGap: CGFloat = 3

                for item in items {
                    let l = ctx.resolve(Text(item.label)
                        .font(Font.mono(10, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(item.gold ? Color.prGold : fg.opacity(0.55)))
                    let a: GraphicsContext.ResolvedText? = (item.showArrow ? item.direction : nil).map { dir in
                        ctx.resolve(Text(dir == .up ? "▲" : "▼")
                            .font(Font.mono(10, weight: .medium))
                            .fontWeight(.bold)
                            .foregroundStyle(valueColor(item.direction)))
                    }
                    let v = ctx.resolve(Text(item.value)
                        .font(Font.mono(10, weight: .medium))
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(item.gold ? Color.prGold : valueColor(item.direction)))
                    let d = ctx.resolve(Text("·")
                        .font(Font.mono(10, weight: .medium))
                        .foregroundStyle(fg.opacity(0.18)))

                    let lW = l.measure(in: measureBounds).width
                    let aW = a.map { $0.measure(in: measureBounds).width + arrowGap } ?? 0
                    let vW = v.measure(in: measureBounds).width
                    let dW = d.measure(in: measureBounds).width

                    labels.append(l); arrows.append(a); values.append(v); dots.append(d)
                    widths.append((lW, aW, vW, dW))
                    // 28pt leading gap + label + 6pt + [arrow + gap] + value + 6pt + dot
                    tileW += 28 + lW + 6 + aW + vW + 6 + dW
                }

                guard tileW > 0 else { return }

                let offset = CGFloat(elapsed * speed).truncatingRemainder(dividingBy: tileW)
                var tileX = -offset

                while tileX < size.width {
                    var x = tileX
                    for i in items.indices {
                        x += 28
                        ctx.draw(labels[i], at: CGPoint(x: x, y: midY), anchor: .leading)
                        x += widths[i].l + 6
                        if let arrow = arrows[i] {
                            ctx.draw(arrow, at: CGPoint(x: x, y: midY), anchor: .leading)
                        }
                        x += widths[i].a
                        ctx.draw(values[i], at: CGPoint(x: x, y: midY), anchor: .leading)
                        x += widths[i].v + 6
                        ctx.draw(dots[i],   at: CGPoint(x: x, y: midY), anchor: .leading)
                        x += widths[i].d
                    }
                    tileX += tileW
                }
            }
        }
        .frame(height: 26)
        .background(bg)
        .clipped()
        .onChange(of: items) { _, _ in startDate = Date() }
    }

    private func valueColor(_ dir: TickerItem.Direction?) -> Color {
        switch dir {
        // Design-system ticker signals: --ticker-up / --ticker-down per scheme.
        case .up:   return colorScheme == .dark ? Color(hex: "#00E07A") : Color(hex: "#00AA55")
        case .down: return colorScheme == .dark ? Color(hex: "#FF3B30") : Color(hex: "#E5281C")
        case .none: return fg.opacity(0.6)
        }
    }
}
