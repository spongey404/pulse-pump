import SwiftUI

// MARK: - 06 PR watch  (Pump Widgets.dc.html · w6)  PLUS
// 6A small: closest lift + sparkline · 6B small: gap list · 6 medium: 12W sparklines · 6 large: chart + table.

/// Sparkline with the dashed PR line along the top (design: y = 2).
struct PWPRSpark: View {
    let values: [Double]
    var lineWidth: CGFloat = 1.5
    var body: some View {
        ZStack(alignment: .topLeading) {
            PWSpark(values: values, lineWidth: lineWidth)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 2)); p.addLine(to: CGPoint(x: 4000, y: 2))
            }
            .stroke(PumpTheme.ghost, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }
        .clipped()
    }
}

struct PRWatchWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var lifts: [PWLift] { snap.fixed.prLifts }
    private func f1(_ kg: Double) -> String { String(format: "%.1f", snap.unit.display(kg)) }   // values are kg
    private func gap(_ l: PWLift) -> String { "-" + f1(abs(l.pr - l.e1rm)) }

    var body: some View {
        Group {
            switch (family, variant) {
            case (.small, .a): smallA
            case (.small, .b): smallB
            case (.medium, _): medium
            case (.large, _): large
            }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    // 6A · small
    @ViewBuilder private var smallA: some View {
        if let l = lifts.first {
            VStack(alignment: .leading, spacing: 0) {
                Text("PR WATCH").pwCap()
                Text(l.name).pwBody(14).lineLimit(1).padding(.top, 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(f1(l.e1rm)).pwMono(30, bold: true)
                    Text("\(snap.unit.label) E1RM").pwCap(8, tracking: 1.2)
                }
                .padding(.top, 2)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    PWPRMark(value: f1(l.pr), label: "PR", size: 10)
                    Text(gap(l)).pwMono(10, color: PumpTheme.muted)
                }
                .padding(.top, 4)
                Spacer(minLength: 0)
                PWPRSpark(values: l.series, lineWidth: 1.5).frame(width: 142, height: 24)
            }
        }
    }

    // 6B · small
    private var smallB: some View {
        VStack(spacing: 0) {
            Text("PR WATCH · GAP").pwCap()
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { PWHair() }
            ForEach(Array(lifts.prefix(3).enumerated()), id: \.offset) { _, l in
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(l.short).pwBody(12)
                        Spacer()
                        Text("\(Int((l.e1rm / l.pr * 100).rounded()))%").pwMono(12, bold: true)
                    }
                    Text("\(f1(l.e1rm)) / \(f1(l.pr)) \(snap.unit.label)").pwCap(8, tracking: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { PWHair() }
            }
        }
    }

    // 6 · medium
    private var medium: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("PR WATCH").pwCap(8, tracking: 1.2).frame(maxWidth: .infinity, alignment: .leading)
                Text("12W").pwCap(8, tracking: 1.2).frame(width: 72, alignment: .leading)
                Text("E1RM").pwCap(8, tracking: 1.2).frame(width: 46, alignment: .trailing)
                Text("PR").pwCap(8, tracking: 1.2).frame(width: 50, alignment: .trailing)
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { PWHair(strong: true) }
            ForEach(Array(lifts.prefix(3).enumerated()), id: \.offset) { _, l in
                HStack(spacing: 8) {
                    Text(l.name).pwBody(13).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    PWSpark(values: l.series, lineWidth: 1.3).frame(width: 72, height: 18)
                    Text(f1(l.e1rm)).pwMono(12, bold: true).frame(width: 46, alignment: .trailing)
                    PWPRMark(value: f1(l.pr), size: 11).frame(width: 50, alignment: .trailing)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { PWHair() }
            }
        }
    }

    // 6 · large
    private var large: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PR WATCH").pwCap()
                Spacer()
                Text("EST 1RM · 12 WK").pwCap(9, tracking: 1)
            }
            if let l = lifts.first {
                HStack(alignment: .firstTextBaseline) {
                    Text(l.name).pwBody(18, weight: .bold)
                    Spacer()
                    Text("\(f1(abs(l.pr - l.e1rm))) \(snap.unit.label) TO PR").pwCap(9, tracking: 1)
                }
                .padding(.top, 10)
                PWPRSpark(values: l.series, lineWidth: 1.6)
                    .frame(width: 332, height: 64)
                    .padding(.top, 8)
            }
            HStack(spacing: 0) {
                Text("LIFT").pwCap(8, tracking: 1.2).frame(maxWidth: .infinity, alignment: .leading)
                Text("E1RM").pwCap(8, tracking: 1.2).frame(width: 50, alignment: .trailing)
                Text("PR").pwCap(8, tracking: 1.2).frame(width: 50, alignment: .trailing)
                Text("GAP").pwCap(8, tracking: 1.2).frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(PumpTheme.sunken)
            .padding(.horizontal, -16).padding(.top, 14)
            ForEach(Array(lifts.prefix(5).enumerated()), id: \.offset) { _, l in
                HStack(spacing: 0) {
                    Text(l.name).pwBody(13).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(f1(l.e1rm)).pwMono(11, bold: true).frame(width: 50, alignment: .trailing)
                    PWPRMark(value: f1(l.pr), size: 11).frame(width: 50, alignment: .trailing)
                    Text(gap(l)).pwMono(11, color: PumpTheme.muted).frame(width: 44, alignment: .trailing)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { PWHair() }
            }
        }
    }
}

extension PRWatchWidget {
    static let blurb = "Lifts within 5% of their PR, sorted by gap. Estimated 1RM trend over 12 weeks. The PR value carries the underline treatment, never a colour."

    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("6A · SMALL", .small) { AnyView(PRWatchWidget(family: .small, variant: .a, snap: $0)) },
            PWGalleryItem("6B · SMALL", .small) { AnyView(PRWatchWidget(family: .small, variant: .b, snap: $0)) },
            PWGalleryItem("6 · MEDIUM", .medium) { AnyView(PRWatchWidget(family: .medium, variant: .a, snap: $0)) },
            PWGalleryItem("6 · LARGE", .large) { AnyView(PRWatchWidget(family: .large, variant: .a, snap: $0)) },
        ]
    }
}
