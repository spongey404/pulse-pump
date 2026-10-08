import SwiftUI

// MARK: - 12 Bodyweight  (Pump Widgets.dc.html · w12)
// Direction is neutral (secondary ink) — never a signal colour.

struct BodyweightWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var f: PWFixedData { snap.fixed }
    private var deltaText: String {
        let d = f.bodyweightDelta7d
        let arrow = d < 0 ? "▼" : d > 0 ? "▲" : "•"
        return "\(arrow) \(d > 0 ? "+" : "")\(String(format: "%.1f", snap.unit.display(d))) · 7D"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BODYWEIGHT").pwCap()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", snap.unit.display(snap.bodyweight))).pwMono(36, bold: true)
                Text(snap.unit.label).pwCap(8, tracking: 1.2)
            }
            .frame(height: 36 * 1.1, alignment: .leading).padding(.top, 6)
            Text(deltaText).pwMono(10, color: PumpTheme.secondary)
            Spacer(minLength: 0)
            PWSpark(values: f.bodyweightSeries).frame(width: 142, height: 34)
            HStack {
                Text(f.bodyweightStart).pwCap(7, tracking: 0)
                Spacer()
                Text("TODAY").pwCap(7, tracking: 0)
            }
            .padding(.top, 4)
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }
}

extension BodyweightWidget {
    static let blurb = "Bodyweight with a 30-day trend. Direction is neutral, not a signal."
    static var gallery: [PWGalleryItem] {
        [PWGalleryItem("12 · SMALL", .small) { AnyView(BodyweightWidget(family: .small, snap: $0)) }]
    }
}
