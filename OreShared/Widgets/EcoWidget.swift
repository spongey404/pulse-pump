import SwiftUI

// MARK: - 15 App ecosystem  (Ore Widgets.dc.html · w12)
// ORE square is accent; Tare and Drift accents are unresolved so their marks are ink.

struct EcoWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: OreWidgetSnapshot

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TODAY").pwMono(9, bold: true, tracking: 2)
                Spacer()
                Text("WK \(snap.weekNumber)").pwCap(9, tracking: 1)
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { PWHair() }
            ForEach(Array(snap.fixed.eco.prefix(3).enumerated()), id: \.offset) { _, e in
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Rectangle().fill(e.app == "ORE" ? OreTheme.accent : OreTheme.ink).frame(width: 8, height: 8)
                        Text(e.app).pwMono(9, bold: true, tracking: 1.5)
                    }
                    .frame(width: 76, alignment: .leading)
                    Text(e.key).pwCap(8, tracking: 1.2).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(e.value).pwMono(15, bold: true)
                        Text(e.of).pwMono(10, color: OreTheme.muted)
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { PWHair() }
            }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }
}

extension EcoWidget {
    static let blurb = "One line per app. Tare and Drift accents are unresolved, so their marks are ink."
    static var gallery: [PWGalleryItem] {
        [PWGalleryItem("15 · MEDIUM", .medium) { AnyView(EcoWidget(family: .medium, snap: $0)) }]
    }
}
