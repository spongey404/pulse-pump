import SwiftUI

// MARK: - 03 Weekly volume  (pump_widgets.html · w3)
// 3A small: sets vs last week · 3B small: ticker surface, three quotes · 3 medium: paired day bars.

struct WeeklyVolumeWidget: View {
    static let blurb = "Sets this week against last week, to the same weekday. 3B uses the ticker surface and stacks three quotes."

    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var f: PWFixedData { snap.fixed }
    private var setsDeltaPct: Double {
        f.setsLastWeekSameDay > 0 ? (Double(f.setsThisWeek - f.setsLastWeekSameDay) / Double(f.setsLastWeekSameDay)) * 100 : 0
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
        .background {
            // 3B sits on the ticker surface instead of the canvas.
            if family == .small && variant == .b {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(PumpTheme.tickerBg)
            }
        }
    }

    // 3A · small
    private var smallA: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETS · WK \(snap.weekNumber)").pwCap()
            Text("\(f.setsThisWeek)").pwMono(52, bold: true).padding(.top, 6)
            PWTrend(text: PWFormat.signedPct(setsDeltaPct), up: setsDeltaPct >= 0, size: 13)
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                PWHair()
                HStack {
                    Text("VS LAST").pwCap(8, tracking: 1.2)
                    Spacer()
                    Text("\(f.setsLastWeekSameDay)").pwCap(8, tracking: 1.2, color: PumpTheme.ink)
                }
                .padding(.top, 8)
            }
        }
    }

    // 3B · small (ticker surface)
    private var smallB: some View {
        let quotes: [(String, String, Double)] = [
            ("SETS", "\(f.setsThisWeek)", setsDeltaPct),
            (snap.unit == .kg ? "VOL T" : "VOL KLB", PWFormat.trimmed(snap.unit.display(f.volumeTonnes * 1000) / 1000), f.volumeDeltaPct),
            ("HRS", f.trainingHours, f.hoursDeltaPct),
        ]
        return VStack(spacing: 0) {
            HStack {
                Text("WK \(snap.weekNumber) VS \(snap.weekNumber - 1)").pwCap(8, tracking: 1.2, color: PumpTheme.tickerFg)
                Spacer()
                Text(f.weekdayShort).pwCap(8, tracking: 1.2, color: PumpTheme.tickerFg)
            }
            .opacity(0.6)
            ForEach(Array(quotes.enumerated()), id: \.offset) { _, q in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(q.0).pwCap(9, tracking: 1.5, color: PumpTheme.tickerFg).opacity(0.7)
                        Spacer()
                        Text(q.1).pwMono(16, bold: true, color: PumpTheme.tickerFg)
                    }
                    HStack {
                        Spacer()
                        Text((q.2 >= 0 ? "▲ " : "▼ ") + PWFormat.signedPct(q.2))
                            .pwMono(9, bold: true, color: q.2 >= 0 ? PumpTheme.tickerUp : PumpTheme.tickerDown)
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { Rectangle().fill(PumpTheme.tickerSep).frame(height: 1) }
            }
        }
    }

    // 3 · medium
    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SETS · WK \(snap.weekNumber)").pwCap()
                Text("\(f.setsThisWeek)").pwMono(48, bold: true).padding(.top, 6)
                PWTrend(text: PWFormat.signedPct(setsDeltaPct), up: setsDeltaPct >= 0, size: 13)
                Spacer(minLength: 0)
                Text("\(f.setsLastWeekSameDay) SAME DAY LAST WK").pwCap(8, tracking: 1.2)
            }
            .frame(width: 120, alignment: .leading)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Spacer()
                    legend("THIS", PumpTheme.ink)
                    legend("LAST", PumpTheme.ghost)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(f.volDays.enumerated()), id: \.offset) { i, v in
                        VStack(spacing: 4) {
                            HStack(alignment: .bottom, spacing: 2) {
                                RoundedRectangle(cornerRadius: 1).fill(PumpTheme.ghost)
                                    .frame(width: 7, height: max(v.lastWeek / 30 * 84, 3))
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(i == f.todayIndex ? PumpTheme.accent : (v.thisWeek > 0 ? PumpTheme.ink : PumpTheme.faint))
                                    .frame(width: 7, height: max(v.thisWeek / 30 * 84, 3))
                            }
                            .frame(height: 84, alignment: .bottom)
                            Text(v.day).pwCap(7, tracking: 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func legend(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(c).frame(width: 6, height: 6)
            Text(t).pwCap(8, tracking: 1.2)
        }
    }
}

extension WeeklyVolumeWidget {
    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("3A · SMALL", .small) { AnyView(WeeklyVolumeWidget(family: .small, variant: .a, snap: $0)) },
            PWGalleryItem("3B · SMALL", .small) { AnyView(WeeklyVolumeWidget(family: .small, variant: .b, snap: $0)) },
            PWGalleryItem("3 · MEDIUM", .medium) { AnyView(WeeklyVolumeWidget(family: .medium, variant: .a, snap: $0)) },
        ]
    }
}
