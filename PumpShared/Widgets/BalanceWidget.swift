import SwiftUI

// MARK: - 05 Muscle balance  (Pump Widgets.dc.html · w5)  PLUS
// 5A small: push:pull hero · 5B small: two ratios · 5 medium: three ratio rows.

/// Two-segment bar: leading share in ink, remainder ghost, 2pt gap.
struct PWSplitBar: View {
    let share: Double
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 1).fill(PumpTheme.ink)
                    .frame(width: max(0, g.size.width * min(max(share, 0), 1)))
                RoundedRectangle(cornerRadius: 1).fill(PumpTheme.ghost)
            }
        }
        .frame(height: height)
    }
}

struct BalanceWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var bal: [PWBalance] { snap.fixed.balances }

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

    private func flagColor(_ b: PWBalance) -> Color { b.flagged ? PumpTheme.down : PumpTheme.muted }

    // 5A · small
    @ViewBuilder private var smallA: some View {
        if let b = bal.first {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(b.key) · 4W").pwCap()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(b.ratio).pwMono(40, bold: true)
                    Text(": 1").pwMono(14, color: PumpTheme.muted)
                }
                .padding(.top, 8)
                Spacer(minLength: 0)
                PWSplitBar(share: b.share, height: 8)
                HStack {
                    Text(b.a).pwCap(8, tracking: 1.2)
                    Spacer()
                    Text(b.b).pwCap(8, tracking: 1.2)
                }
                .padding(.top, 6)
                Text(b.flag).pwCap(9, tracking: 1, color: flagColor(b))
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { PWHair() }
                    .padding(.top, 8)
            }
        }
    }

    // 5B · small
    private var smallB: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BALANCE · 4W").pwCap()
            ForEach(Array(bal.prefix(2).enumerated()), id: \.offset) { _, b in
                VStack(spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(b.key).pwCap(8, tracking: 1.2)
                        Spacer()
                        Text(b.ratio).pwMono(16, bold: true)
                    }
                    PWSplitBar(share: b.share, height: 6)
                    Text(b.flag).pwCap(8, tracking: 1, color: flagColor(b))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) { PWHair() }
            }
        }
    }

    // 5 · medium
    private var medium: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MUSCLE BALANCE · 4W").pwCap()
                Spacer()
                Text("SETS").pwCap(9, tracking: 1)
            }
            ForEach(Array(bal.prefix(3).enumerated()), id: \.offset) { _, b in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.key).pwCap(8, tracking: 1.2)
                        Text(b.flag.replacingOccurrences(of: " SETS", with: "")).pwCap(8, tracking: 1, color: flagColor(b))
                    }
                    .frame(width: 76, alignment: .leading)
                    VStack(spacing: 3) {
                        PWSplitBar(share: b.share, height: 6)
                        HStack {
                            Text(b.a).pwMono(8, color: PumpTheme.muted)
                            Spacer()
                            Text(b.b).pwMono(8, color: PumpTheme.muted)
                        }
                    }
                    Text(b.ratio).pwMono(14, bold: true).frame(width: 48, alignment: .trailing)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { PWHair() }
            }
        }
    }
}

extension BalanceWidget {
    static let blurb = "Push versus pull ratio over 4 weeks, by sets. The lagging side is stated as a set deficit. Medium adds upper/lower and anterior/posterior."

    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("5A · SMALL", .small) { AnyView(BalanceWidget(family: .small, variant: .a, snap: $0)) },
            PWGalleryItem("5B · SMALL", .small) { AnyView(BalanceWidget(family: .small, variant: .b, snap: $0)) },
            PWGalleryItem("5 · MEDIUM", .medium) { AnyView(BalanceWidget(family: .medium, variant: .a, snap: $0)) },
        ]
    }
}
