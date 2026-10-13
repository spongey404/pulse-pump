import SwiftUI

// MARK: - 10 Program progress  (Pump Widgets.dc.html · w9)

struct ProgramWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var f: PWFixedData { snap.fixed }

    var body: some View {
        Group {
            if family == .small { small } else { medium }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    private func ticks(height: CGFloat, radius: CGFloat, spacing: CGFloat = 3) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(f.programWeeks, 0), id: \.self) { i in
                RoundedRectangle(cornerRadius: radius)
                    .fill(i < f.programWeek - 1 ? PumpTheme.ink : i == f.programWeek - 1 ? PumpTheme.accent : PumpTheme.faint)
                    .frame(height: height)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PROGRAM").pwCap()
            Text(f.programName).pwBody(14).lineLimit(1).padding(.top, 6)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(f.programWeek)/\(f.programWeeks)").pwMono(32, bold: true)
                Text("WEEKS").pwCap(8, tracking: 1.2)
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
            ticks(height: 10, radius: 2)
            Text("\(f.programSessionsDone)/\(f.programSessionsTarget) SESSIONS THIS WK").pwCap(8, tracking: 1.2).padding(.top, 6)
        }
    }

    private func dayTile(_ d: PWProgramDay) -> some View {
        let bg: Color, bd: Color, lc: Color
        switch d.state {
        case .done: bg = PumpTheme.sunken; bd = .clear; lc = PumpTheme.muted
        case .next: bg = PumpTheme.accentRow; bd = PumpTheme.accentBorder; lc = PumpTheme.accentInk
        case .later: bg = .clear; bd = PumpTheme.ruleStrong; lc = PumpTheme.muted
        }
        return VStack(alignment: .leading, spacing: 0) {
            Text(d.tag).pwCap(8, tracking: 1.2, color: lc)
            Spacer(minLength: 0)
            Text(d.name).pwBody(12, weight: .bold)
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 52)
        .background(bg, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(bd, lineWidth: 1))
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(f.programName).pwBody(18, weight: .bold)
                Spacer()
                Text("WK \(f.programWeek) OF \(f.programWeeks)").pwCap(9, tracking: 1)
            }
            ticks(height: 6, radius: 1).padding(.top, 10)
            Spacer(minLength: 0)
            Text("THIS WEEK").pwCap(8, tracking: 1.2).padding(.bottom, 6)
            HStack(spacing: 6) {
                ForEach(Array(f.programDays.prefix(4).enumerated()), id: \.offset) { _, d in dayTile(d) }
            }
        }
    }
}

extension ProgramWidget {
    static let blurb = "Progress through the active template block: weeks done, this week's sessions."
    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("10 · SMALL", .small) { AnyView(ProgramWidget(family: .small, snap: $0)) },
            PWGalleryItem("10 · MEDIUM", .medium) { AnyView(ProgramWidget(family: .medium, snap: $0)) },
        ]
    }
}
