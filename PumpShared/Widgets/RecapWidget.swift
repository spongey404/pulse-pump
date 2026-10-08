import SwiftUI

// MARK: - 09 Last session recap  (Pump Widgets.dc.html · w9)

struct RecapWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var f: PWFixedData { snap.fixed }
    private var agoText: String { f.lastWorkoutDaysAgo == 1 ? "1 DAY AGO" : "\(f.lastWorkoutDaysAgo) DAYS AGO" }
    private var delta: some View {
        PWTrend(text: PWFormat.signedPct(f.recapVolumeDeltaPct), up: f.recapVolumeDeltaPct >= 0, size: family == .small ? 10 : 9)
    }

    var body: some View {
        Group {
            if family == .small { small } else { medium }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    private var prRow: some View {
        HStack(alignment: .firstTextBaseline) {
            if family == .small { Text("ROW").pwCap(8, tracking: 1.2) }
            else { Text(f.recapPRName).pwBody(12) }
            Spacer(minLength: 0)
            PWPRMark(value: f.recapPRValue, label: "PR")
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LAST · \(f.lastWorkoutWeekday)").pwCap()
            Text(f.lastWorkoutName).pwBody(18, weight: .bold).lineLimit(1).padding(.top, 8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(PWFormat.thousands(snap.unit.display(f.recapVolumeKg))).pwMono(24, bold: true)
                Text(snap.unit.label).pwCap(8, tracking: 1.2)
            }
            .padding(.top, 6)
            delta
            Spacer(minLength: 0)
            if !f.recapPRName.isEmpty {
                VStack(spacing: 0) {
                    PWHair()
                    prRow.padding(.top, 8)
                }
            }
        }
    }

    private func cell(_ k: String, width: CGFloat, first: Bool, @ViewBuilder _ v: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).pwCap(8, tracking: 1.2)
            v()
        }
        .padding(.leading, first ? 0 : 10)
        .frame(width: width, alignment: .leading)
        .overlay(alignment: .leading) { if !first { PWHair(vertical: true) } }
    }

    private var medium: some View {
        let w = family.size.width - 28
        let unit = w / 3.3
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("LAST SESSION").pwCap()
                Spacer()
                Text(agoText).pwCap(9, tracking: 1)
            }
            Text(f.lastWorkoutName).pwBody(20, weight: .bold).padding(.top, 6)
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                PWHair()
                HStack(alignment: .top, spacing: 0) {
                    cell("VOLUME \(snap.unit.label)", width: unit * 1.3, first: true) {
                        Text(PWFormat.thousands(snap.unit.display(f.recapVolumeKg))).pwMono(18, bold: true)
                        delta
                    }
                    cell("SETS", width: unit, first: false) { Text("\(f.recapSets)").pwMono(18, bold: true) }
                    cell("TIME", width: unit, first: false) { Text(f.recapTime).pwMono(18, bold: true) }
                }
                .padding(.top, 8)
            }
            if !f.recapPRName.isEmpty {
                VStack(spacing: 0) {
                    PWHair()
                    prRow.padding(.top, 6)
                }
                .padding(.top, 8)
            }
        }
    }
}

extension RecapWidget {
    static let blurb = "Last finished session with its volume change and any PR set."
    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("9 · SMALL", .small) { AnyView(RecapWidget(family: .small, snap: $0)) },
            PWGalleryItem("9 · MEDIUM", .medium) { AnyView(RecapWidget(family: .medium, snap: $0)) },
        ]
    }
}
