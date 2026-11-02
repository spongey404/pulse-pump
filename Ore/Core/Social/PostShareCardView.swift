import SwiftUI

/// The 9:16 share card as a pure function of time `t` (0..<6 s), so the same view draws the live preview and every exported frame.
struct PostShareCardView: View {
    let model: ShareCardModel
    var t: Double
    var geometry: [BodyMapSide: BodyFigureGeometry]
    @Environment(\.weightUnit) private var unit

    private var accent: Color { Color(hex: model.accentHex) }
    private static let bg = Color(hex: "#14110F")
    private static let ink = Color(hex: "#ECE5D6")
    private static let gold = Color(hex: "#FFC83D")

    var body: some View {
        ZStack {
            Self.bg
            sky
            VStack(spacing: 0) {
                switch model.style {
                case .ticker: tickerLayout
                case .classic: classicLayout
                }
            }
        }
        .frame(width: ShareCardModel.size.width, height: ShareCardModel.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    // MARK: Stardust sky (every card, free and member)

    private static let skyStars = ShareTwinkle.stars(count: 150, seed: 77)
    private var sky: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [accent.opacity(0.30), .clear]), startPoint: .zero, endPoint: CGPoint(x: size.width * 0.4, y: size.height * 0.55)))
            for s in Self.skyStars {
                let l = ShareTwinkle.level(s, t: t)
                let c = s.gold ? Self.gold : (model.member ? accent.mix(with: .white, by: 0.5) : .white)
                let r = s.size * (0.6 + 0.4 * l)
                ctx.fill(Path(ellipseIn: CGRect(x: s.x * size.width - r, y: s.y * size.height - r, width: r * 2, height: r * 2)), with: .color(c.opacity(l * 0.8)))
            }
        }
    }

    // MARK: Layouts

    private var tickerLayout: some View {
        VStack(spacing: 0) {
            tickerStrip.padding(.top, 70)
            VStack(alignment: .leading, spacing: 10) {
                HStack { mark; Spacer(); if model.member { SupernovaWordmark(size: 11, face: .mono(bold: true), tracking: 2, color: Self.ink) } }
                Text(model.title.uppercased()).font(.archivo(54, weight: .black)).foregroundStyle(Self.ink).lineLimit(2).minimumScaleFactor(0.6)
                Text(model.dateLine).font(.spaceMono(13)).tracking(2).foregroundStyle(Self.ink.opacity(0.6))
            }
            .padding(.horizontal, 32).padding(.top, 28)
            figures.padding(.top, 8)
            stats.padding(.horizontal, 32).padding(.bottom, 64)
        }
    }

    private var classicLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                mark
                if model.member { SupernovaWordmark(size: 11, face: .mono(bold: true), tracking: 2, color: Self.ink).padding(.leading, 10) }
                Spacer()
                Text(model.dateLine).font(.spaceMono(13)).tracking(2).foregroundStyle(Self.ink.opacity(0.6))
            }
            .padding(.horizontal, 32).padding(.top, 84)
            figures.padding(.top, 12)
            VStack(alignment: .leading, spacing: 12) {
                Text(model.title.uppercased()).font(.archivo(54, weight: .black)).foregroundStyle(Self.ink).lineLimit(2).minimumScaleFactor(0.6)
                if model.prCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill").font(.system(size: 14)).foregroundStyle(Self.gold)
                        Text("\(model.prCount) NEW PR\(model.prCount == 1 ? "" : "S")").font(.spaceMono(13, weight: .bold)).tracking(2).foregroundStyle(Self.ink)
                    }
                }
                stats
            }
            .padding(.horizontal, 32).padding(.bottom, 64)
        }
    }

    private var mark: some View {
        Text("ORE").font(.archivo(22, weight: .black)).tracking(4).foregroundStyle(model.member ? accent : Self.ink)
    }

    private var tickerStrip: some View {
        let items = model.tickerItems
        let cell = 190.0
        let tile = Double(items.count) * cell
        return ZStack(alignment: .leading) {
            Color(hex: "#0E0C0A")
            HStack(spacing: 0) {
                ForEach(0..<(Int(ShareCardModel.size.width / tile) + 3) * items.count, id: \.self) { i in
                    Text(items[i % items.count]).font(.spaceMono(13, weight: .bold)).tracking(2)
                        .foregroundStyle(items[i % items.count].hasPrefix("★") ? Self.gold : Self.ink).frame(width: cell, alignment: .leading)
                }
            }
            .offset(x: ShareTwinkle.tickerOffset(t: t, tile: tile))
        }
        .frame(height: 44).clipped()
    }

    // MARK: Body map (both sides side by side only if both were trained)

    private var figures: some View {
        HStack(spacing: 0) {
            ForEach(model.sides, id: \.self) { side in
                if let g = geometry[side] { ShareFigure(geometry: g, levels: model.levels, accent: accent, t: t) }
            }
        }
        .frame(maxWidth: .infinity).frame(height: 470)
    }

    private var stats: some View {
        HStack(alignment: .top) {
            cell("SETS", "\(model.sets)")
            cell("VOLUME", unit.compactVolume(model.volumeKg))
            cell("TIME", PostTime.duration(model.durationSeconds))
        }
    }

    private func cell(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l).font(.spaceMono(11)).tracking(2).foregroundStyle(Self.ink.opacity(0.6))
            Text(v).font(.spaceMono(30, weight: .bold)).foregroundStyle(Self.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One figure for the card: silhouette, heat at its final level, twinkling Stardust inside each worked muscle (loops seamlessly), ink on top.
struct ShareFigure: View {
    let geometry: BodyFigureGeometry
    let levels: [String: Double]
    let accent: Color
    var t: Double

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / BodyFigureGeometry.artSize.width
            var l = ctx
            l.scaleBy(x: k, y: k)
            l.fill(geometry.outline, with: .color(Color(hex: "#2E2A26")))
            let accentRGB = BodyMapColor.rgb(hex: UIColor(accent).hexString) ?? (0.1, 0.65, 1)
            let base = BodyMapColor.rgb(hex: "#433D37") ?? (0.26, 0.24, 0.21)
            for m in geometry.muscles {
                var rgb = base
                if let v = levels[m.id], v > 0 { rgb = BodyMapColor.mix(accent: accentRGB, base: base, pct: 25 + v * 75) }
                l.fill(m.path, with: .color(Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)))
            }
            for m in geometry.muscles {
                guard let v = levels[m.id], v > 0 else { continue }
                let n = min(m.candidates.count, max(3, Int(m.area * 0.0011 * v)))
                var c = l
                c.clip(to: m.path)
                for i in 0..<n {
                    let p = m.candidates[i]
                    let s = ShareTwinkle.Star(x: 0, y: 0, size: 0, phase: Double(i % 17) / 17, cycles: 1 + i % 3, gold: i % 4 == 0)
                    let lv = ShareTwinkle.level(s, t: t)
                    let r = 7.0 * (0.6 + 0.4 * lv)
                    c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                           with: .color((s.gold ? Color(hex: "#FFC83D") : Color.white).opacity(lv * 0.9)))
                }
            }
            for p in geometry.ink { l.fill(p, with: .color(Color(hex: "#6E6760"))) }
        }
        .aspectRatio(BodyFigureGeometry.artSize.width / BodyFigureGeometry.artSize.height, contentMode: .fit)
    }
}

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
