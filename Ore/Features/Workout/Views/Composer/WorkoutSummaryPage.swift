import SwiftUI

/// The full-screen summary shown first (Ore Feed Post Final §3a): header, a large centred body map with the FRONT/BACK swap tile in the
/// map area's corner, SETS / VOLUME / IMPROVED / TIME, and below that every exercise in the finished-workout format (§5). Scrolls;
/// CONTINUE TO POST stays docked.
struct WorkoutSummaryPage: View {
    let data: WorkoutCompletionData
    var levels: [String: Double]
    var namespace: Namespace.ID
    /// Called with whether any part of the body map is on screen right now (decides shrink vs slide, §3b).
    var onContinue: (_ mapVisible: Bool) -> Void
    var onClose: () -> Void
    /// Fades the UI around the flying map (200 ms) during the shrink.
    var uiOpacity: Double = 1

    @Environment(\.weightUnit) private var unit
    @State private var mapFrame: CGRect = .zero
    @State private var viewport: CGRect = .zero
    private let mapAreaHeight: CGFloat = 500

    private var member: Bool { AccentStore.shared.stardustEnabled }
    private var dateLine: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return "WORKOUT COMPLETE · \(f.string(from: Date()).uppercased())"
    }

    /// Any part of the map visible (not fully scrolled off).
    static func mapIsVisible(map: CGRect, viewport: CGRect) -> Bool { map.intersects(viewport) && map.intersection(viewport).height > 1 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header.opacity(uiOpacity)
                BodyMapSwapView(levels: levels, member: member, accentHex: member ? AccentStore.shared.active.hexString : nil,
                                tileSize: CGSize(width: 76, height: 112))
                    .frame(height: mapAreaHeight)
                    .matchedGeometryEffect(id: "map", in: namespace)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("summary")) } action: { mapFrame = $0 }
                stats.opacity(uiOpacity)
                WorkoutDocumentExercises(exercises: data.exercises, prExerciseIds: WorkoutDocumentExercises.prIds(data.exercises, prCount: data.prCount))
                    .opacity(uiOpacity)
                    .padding(.bottom, 24)
            }
        }
        .coordinateSpace(name: "summary")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("summary")) } action: { _ in }
        .background(GeometryReader { g in Color.clear.onAppear { viewport = CGRect(origin: .zero, size: g.size) }.onChange(of: g.size) { _, s in viewport = CGRect(origin: .zero, size: s) } })
        .background(Color.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DockedPrimaryButton(title: "CONTINUE TO POST", id: AX.completion.continueToPost) {
                onContinue(Self.mapIsVisible(map: mapFrame, viewport: viewport))
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
            .background(Color.canvasBg.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .opacity(uiOpacity)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateLine).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).accessibilityIdentifier(AX.completion.title)
                Text((data.workoutName ?? "WORKOUT").uppercased()).font(.archivo(34, weight: .black)).foregroundStyle(Color.inkPrimary).lineLimit(2)
                if data.prCount > 0 {
                    HStack(spacing: 6) {
                        StarBullet(size: 12)
                        Text("\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
                    }
                }
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary).frame(width: 44, height: 44)
                    .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain).accessibilityLabel("Close summary").accessibilityIdentifier(AX.completion.back)
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
    }

    private var stats: some View {
        let volume = data.exercises.flatMap(\.workingSets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return HStack(alignment: .top, spacing: 8) {
            cell("SETS", "\(data.totalSets)", .inkPrimary)
            cell("VOLUME", unit.compactVolume(volume), .inkPrimary)
            cell("IMPROVED", "\(data.improvedCount)/\(data.totalExercises)", .signalUp)
            cell("TIME", PostTime.duration(Int(data.duration)), .inkPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func cell(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            Text(v).font(.spaceMono(17, weight: .bold)).foregroundStyle(c)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
