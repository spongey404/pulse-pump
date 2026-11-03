import SwiftUI

// MARK: - 04 Body map heatmap  (Ore Widgets.dc.html · w4)  PLUS
// 4A small: silhouette + neglected list · 4B small: silhouette + worst muscle ·
// 4 medium: silhouette + top sets / neglected · 4 large: silhouette + muscle table.

/// What the silhouette is shaded by.
enum PWBodyMetric: String, Codable, CaseIterable {
    case volume, recency
    var label: String { self == .volume ? "VOLUME · 7D" : "RECENCY" }
    var short: String { self == .volume ? "VOLUME" : "RECENCY" }
}

struct BodyMapWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: OreWidgetSnapshot
    var metric: PWBodyMetric = .volume

    private var f: PWFixedData { snap.fixed }

    private var heat: BodyHeat {
        let b = metric == .volume ? snap.bodyVolume : snap.bodyRecency
        let dark = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(pwHex: "ECE5D6").withAlphaComponent(0.10) : UIColor(pwHex: "151A21").withAlphaComponent(0.035) })
        let stroke = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(pwHex: "ECE5D6").withAlphaComponent(0.12) : UIColor(pwHex: "151A21").withAlphaComponent(0.07) })
        return BodyHeat(intensities: .init(
            traps: b["traps"], chest: b["chest"], shoulders: b["shoulders"], biceps: b["biceps"],
            forearms: b["forearms"], core: b["core"], glutes: b["glutes"], quads: b["quads"], calves: b["calves"]),
            base: dark, stroke: stroke)
    }

    var body: some View {
        Group {
            switch (family, variant) {
            case (.small, .a): smallA.padding(14)
            case (.small, .b): smallB.padding(.horizontal, 14).padding(.vertical, 12)
            case (.medium, _): medium.padding(14)
            case (.large, _): large.padding(16)
            }
        }
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    // 4A · small
    private var smallA: some View {
        HStack(alignment: .top, spacing: 8) {
            heat.frame(width: 64, height: 142)
            VStack(alignment: .leading, spacing: 0) {
                Text(metric.label).pwCap(8, tracking: 1.2)
                Spacer(minLength: 0)
                Text("NEGLECTED").pwCap(8, tracking: 1.2)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { PWHair() }
                ForEach(Array(f.neglected.prefix(3).enumerated()), id: \.offset) { _, n in
                    HStack {
                        Text(n.name).pwMono(9)
                        Spacer(minLength: 0)
                        Text(n.value).pwMono(9, color: OreTheme.down)
                    }
                    .frame(height: 22)
                    .overlay(alignment: .bottom) { PWHair() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    // 4B · small
    private var smallB: some View {
        VStack(spacing: 0) {
            heat.frame(width: 72, height: 118)
            Spacer(minLength: 0)
            if let n = f.neglected.first {
                HStack {
                    Text(n.name).pwCap(9, tracking: 1)
                    Spacer()
                    Text(n.value).pwCap(9, tracking: 1, color: OreTheme.down)
                }
            }
        }
    }

    // 4 · medium
    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            heat.frame(width: 84, height: 142)
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    colHeader("TOP · SETS 7D")
                    ForEach(Array(f.topMuscles.prefix(4).enumerated()), id: \.offset) { _, n in
                        row(n.name, n.value, bold: true, color: OreTheme.ink)
                    }
                }
                VStack(spacing: 0) {
                    colHeader("NEGLECTED")
                    ForEach(Array(f.neglected.prefix(3).enumerated()), id: \.offset) { _, n in
                        row(n.name, n.value, bold: false, color: OreTheme.down)
                    }
                    Color.clear.frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func colHeader(_ t: String) -> some View {
        Text(t).pwCap(8, tracking: 1.2)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { PWHair() }
    }

    private func row(_ l: String, _ r: String, bold: Bool, color: Color) -> some View {
        HStack {
            Text(l).pwMono(10)
            Spacer(minLength: 0)
            Text(r).pwMono(10, bold: bold, color: color)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) { PWHair() }
    }

    // 4 · large
    private var large: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MUSCLE MAP · 7D").pwCap()
                Spacer()
                Text(metric.short).pwCap(9, tracking: 1)
            }
            HStack(alignment: .top, spacing: 16) {
                heat.frame(width: 140, height: 320)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("MUSCLE").pwCap(8, tracking: 1.2).frame(maxWidth: .infinity, alignment: .leading)
                        Text("SETS").pwCap(8, tracking: 1.2).frame(width: 32, alignment: .trailing)
                        Text("LAST").pwCap(8, tracking: 1.2).frame(width: 32, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    .overlay(alignment: .bottom) { PWHair(strong: true) }
                    ForEach(Array(f.muscleRows.prefix(10).enumerated()), id: \.offset) { _, m in
                        HStack(spacing: 0) {
                            Text(m.muscle).pwMono(10).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(m.sets)").pwMono(10, bold: true).frame(width: 32, alignment: .trailing)
                            Text(m.last).pwMono(10, color: m.stale ? OreTheme.down : OreTheme.muted)
                                .frame(width: 32, alignment: .trailing)
                        }
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .bottom) { PWHair() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 12)
            .frame(maxHeight: .infinity)
        }
    }
}

extension BodyMapWidget {
    static let blurb = "Front silhouette from the Body tab. Configurable: VOLUME (sets, 7 days) or RECENCY (days since trained). Neglected muscles are flagged with days since."

    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("4A · SMALL", .small) { AnyView(BodyMapWidget(family: .small, variant: .a, snap: $0)) },
            PWGalleryItem("4B · SMALL", .small) { AnyView(BodyMapWidget(family: .small, variant: .b, snap: $0)) },
            PWGalleryItem("4 · MEDIUM", .medium) { AnyView(BodyMapWidget(family: .medium, variant: .a, snap: $0)) },
            PWGalleryItem("4 · LARGE", .large) { AnyView(BodyMapWidget(family: .large, variant: .a, snap: $0)) },
        ]
    }
}
