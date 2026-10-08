import SwiftUI

// MARK: - 01 Next workout  (Pump Widgets.dc.html · w1)
// 1A small: START button · 1B small: first lift · 1A medium: START + exercise list ·
// 1B medium: stat row · 1 large: full exercise table + START.

struct NextWorkoutWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var f: PWFixedData { snap.fixed }
    private var name: String { snap.nextName.isEmpty ? "—" : snap.nextName.uppercased() }
    private var startURL: URL? { PumpWidgetSnapshot.startURL(template: snap.nextName) }
    private var meta: String {
        "\(snap.nextExercises) EX · \(f.nextSets) SETS · ~\(snap.nextEstMinutes)M"
    }

    var body: some View {
        Group {
            switch (family, variant) {
            case (.small, .a): smallA
            case (.small, .b): smallB
            case (.medium, .a): mediumA
            case (.medium, .b): mediumB
            case (.large, _): large
            }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    private var startButton: some View {
        Text("START ›").font(.archivo(13, weight: .black)).tracking(0.5).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 36)
            .background(PumpTheme.accent, in: RoundedRectangle(cornerRadius: 12))
    }

    // 1A · small
    private var smallA: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEXT · \(snap.nextDay)").pwCap()
                Spacer()
                PWConfidenceDots(confidence: f.nextConfidence, showLabel: false)
            }
            Text(name).pwDisplay(22).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 12)
            Text(meta).pwCap(8, tracking: 1.2).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 6)
            Spacer(minLength: 0)
            startLink(startButton)
        }
    }

    // 1B · small
    private var smallB: some View {
        let first = f.nextExerciseList.first
        return VStack(alignment: .leading, spacing: 0) {
            Text("NEXT WORKOUT").pwCap()
            Text(name).pwDisplay(22).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 12)
            PWHair().padding(.top, 12)
            Text("FIRST UP").pwCap(8, tracking: 1.2).padding(.top, 10)
            Text(first?.name ?? "—").pwBody(14).lineLimit(1).padding(.top, 4)
            Text(first.map { "\($0.target) · \($0.kg) KG" } ?? "").pwMono(10).padding(.top, 2)
            Spacer(minLength: 0)
            PWConfidenceDots(confidence: f.nextConfidence)
        }
    }

    // 1A · medium
    private var mediumA: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("NEXT · PREDICTED").pwCap()
                Text(name).pwDisplay(24).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 10)
                Text("\(snap.nextExercises) EX · ~\(snap.nextEstMinutes) MIN").pwCap(8, tracking: 1.2).padding(.top, 6)
                PWConfidenceDots(confidence: f.nextConfidence).padding(.top, 8)
                Spacer(minLength: 0)
                startLink(Text("START WORKOUT ›").font(.archivo(13, weight: .black)).tracking(0.5).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .background(PumpTheme.accent, in: RoundedRectangle(cornerRadius: 12)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 0) {
                ForEach(Array(f.nextExerciseList.prefix(4).enumerated()), id: \.offset) { _, ex in
                    HStack(spacing: 8) {
                        Text(ex.name).pwBody(12).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(ex.target).pwMono(10, color: PumpTheme.secondary)
                    }
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .bottom) { PWHair() }
                }
                HStack {
                    Text("+\(max(f.nextExerciseList.count - 4, 0)) MORE").pwCap(8, tracking: 1.2)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 160)
        }
    }

    // 1B · medium
    private var mediumB: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEXT WORKOUT").pwCap()
                Spacer()
                Text("LAST \(f.nextLastSameName) · \(f.nextLastSameDays) DAYS AGO").pwCap(9, tracking: 1)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(name).pwDisplay(26).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                PWConfidenceDots(confidence: f.nextConfidence)
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
            PWHair()
            HStack(spacing: 0) {
                statCell("EXERCISES", "\(snap.nextExercises)", first: true)
                statCell("SETS", "\(f.nextSets)", first: false)
                statCell("EST MIN", "\(snap.nextEstMinutes)", first: false)
            }
            .padding(.top, 10)
        }
    }

    private func statCell(_ k: String, _ v: String, first: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).pwCap(8, tracking: 1.2)
            Text(v).pwMono(20, bold: true)
        }
        .padding(.leading, first ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { if !first { PWHair(vertical: true) } }
    }

    // 1 · large
    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEXT · \(f.nextDate)").pwCap()
                Spacer()
                PWConfidenceDots(confidence: f.nextConfidence)
            }
            Text(name).pwDisplay(28, tracking: 0.5).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 10)
            Text("\(f.nextSplitLine) · \(snap.nextExercises) EX · ~\(snap.nextEstMinutes) MIN").pwCap(8, tracking: 1.2)
                .lineLimit(1).minimumScaleFactor(0.7).padding(.top, 6)
            HStack {
                Text("EXERCISE").pwCap(8, tracking: 1.2).frame(maxWidth: .infinity, alignment: .leading)
                Text("SETS").pwCap(8, tracking: 1.2).frame(width: 44, alignment: .trailing)
                Text("KG").pwCap(8, tracking: 1.2).frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(PumpTheme.sunken)
            .padding(.horizontal, -16).padding(.top, 14)
            ForEach(Array(f.nextExerciseList.prefix(6).enumerated()), id: \.offset) { _, ex in
                HStack {
                    Text(ex.name).pwBody(13).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(ex.target).pwMono(11).frame(width: 44, alignment: .trailing)
                    Text(ex.kg).pwMono(11).frame(width: 52, alignment: .trailing)
                }
                .frame(height: 30)
                .overlay(alignment: .bottom) { PWHair() }
            }
            Spacer(minLength: 0)
            startLink(Text("START WORKOUT ›").font(.archivo(14, weight: .black)).tracking(0.5).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(PumpTheme.accent, in: RoundedRectangle(cornerRadius: 12)))
        }
    }

    @ViewBuilder private func startLink<V: View>(_ label: V) -> some View {
        if let url = startURL { Link(destination: url) { label } } else { label }
    }
}

extension NextWorkoutWidget {
    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("1A · SMALL", .small) { AnyView(NextWorkoutWidget(family: .small, variant: .a, snap: $0)) },
            PWGalleryItem("1B · SMALL", .small) { AnyView(NextWorkoutWidget(family: .small, variant: .b, snap: $0)) },
            PWGalleryItem("1A · MEDIUM", .medium) { AnyView(NextWorkoutWidget(family: .medium, variant: .a, snap: $0)) },
            PWGalleryItem("1B · MEDIUM", .medium) { AnyView(NextWorkoutWidget(family: .medium, variant: .b, snap: $0)) },
            PWGalleryItem("1 · LARGE", .large) { AnyView(NextWorkoutWidget(family: .large, variant: .a, snap: $0)) },
        ]
    }
}
