import SwiftUI

// MARK: - 07 Deload & recovery  (Ore Widgets.dc.html · w7)  PLUS
// 7A small: block week + mini load bars · 7B small: load ratio · 7 medium: labelled 8-week load bars.

struct DeloadWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: OreWidgetSnapshot

    private var f: PWFixedData { snap.fixed }
    private var ratio: String { String(format: "%.2f", f.loadRatio) }
    private var maxLoad: Double { max(f.loadWeeks.filter { !$0.next }.map(\.load).max() ?? 1, 1) }
    private var weeksLeft: Int { f.blockWeeks - f.blockWeek }
    private var headline: [String] {
        switch weeksLeft {
        case 1: ["DELOAD", "NEXT WEEK"]
        case ..<1: ["DELOAD", "THIS WEEK"]
        default: ["DELOAD", "IN \(weeksLeft) WEEKS"]
        }
    }

    private func barColor(_ w: PWLoadWeek) -> Color {
        w.current ? OreTheme.accent : (w.deload ? OreTheme.faint : OreTheme.ink)
    }
    private func barOpacity(_ w: PWLoadWeek) -> Double { w.current || w.deload ? 1 : 0.35 }
    private func barHeight(_ w: PWLoadWeek, max h: CGFloat) -> CGFloat {
        w.next ? 4 : (CGFloat(w.load / maxLoad) * h).rounded()
    }

    var body: some View {
        Group {
            switch (family, variant) {
            case (.small, .a): smallA
            case (.small, .b): smallB
            default: medium
            }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    // 7A · small
    private var smallA: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BLOCK · WK \(f.blockWeek)/\(f.blockWeeks)").pwCap()
            Text(headline[0]).pwDisplay(20, tracking: 0).padding(.top, 8)
            Text(headline[1]).pwDisplay(20, tracking: 0).padding(.top, 2)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(f.loadWeeks.enumerated()), id: \.offset) { _, w in
                    RoundedRectangle(cornerRadius: 1).fill(barColor(w)).opacity(barOpacity(w))
                        .frame(height: barHeight(w, max: 36))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 36, alignment: .bottom)
            HStack {
                Text("LOAD RATIO").pwCap(8, tracking: 1.2)
                Spacer()
                Text(ratio).pwMono(8, bold: true, tracking: 1.2)
            }
            .padding(.top, 6)
        }
    }

    // 7B · small
    private var smallB: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LOAD RATIO").pwCap()
            Text(ratio).pwMono(48, bold: true).padding(.top, 6)
            Text("VS 4-WK AVG").pwCap(8, tracking: 1.2)
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                HStack {
                    Text("DELOAD").pwCap(9, tracking: 1)
                    Spacer()
                    Text(f.nextDeloadWeek).pwMono(9, tracking: 1)
                }
                HStack {
                    Text("LAST").pwCap(9, tracking: 1)
                    Spacer()
                    Text(f.lastDeloadWeek).pwMono(9, tracking: 1)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) { PWHair() }
        }
    }

    // 7 · medium
    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("BLOCK · WK \(f.blockWeek)/\(f.blockWeeks)").pwCap()
                Text(headline.joined(separator: " ")).pwDisplay(18, tracking: 0)
                    .lineSpacing(0)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                Spacer(minLength: 0)
                Text("LOAD RATIO").pwCap(8, tracking: 1.2)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ratio).pwMono(22, bold: true)
                    PWTrend(text: (f.loadRatioDelta >= 0 ? "+" : "") + String(format: "%.2f", f.loadRatioDelta),
                            up: f.loadRatioDelta == 0 ? nil : f.loadRatioDelta > 0, size: 10)
                }
            }
            .frame(width: 110, alignment: .leading)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(f.loadWeeks.enumerated()), id: \.offset) { _, w in
                    VStack(spacing: 4) {
                        Text(w.deload ? "D" : "").pwMono(8, bold: true, color: OreTheme.muted)
                        RoundedRectangle(cornerRadius: 1).fill(barColor(w)).opacity(barOpacity(w))
                            .frame(height: barHeight(w, max: 96))
                        Text(w.label).pwMono(7, color: OreTheme.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension DeloadWidget {
    static let blurb = "Weekly training load (sets × RPE) for 8 weeks. Past deloads marked D, the next one shown as an empty slot. Load ratio is this week against the 4-week average."

    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("7A · SMALL", .small) { AnyView(DeloadWidget(family: .small, variant: .a, snap: $0)) },
            PWGalleryItem("7B · SMALL", .small) { AnyView(DeloadWidget(family: .small, variant: .b, snap: $0)) },
            PWGalleryItem("7 · MEDIUM", .medium) { AnyView(DeloadWidget(family: .medium, variant: .a, snap: $0)) },
        ]
    }
}
