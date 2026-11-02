import SwiftUI

/// "Share outside Ore" (Ore Feed Post Final §4): TICKER / CLASSIC (members), a live preview of the 9:16 loop, then SHARE TO STORY
/// (primary) and SAVE VIDEO (secondary), both left-aligned. The video is rendered once and reused.
struct ShareOutsideSheet: View {
    @State var model: ShareCardModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @State private var geometry: [BodyMapSide: BodyFigureGeometry] = [:]
    @State private var progress: Double?
    @State private var fileURL: URL?
    @State private var shareURL: URL?
    @State private var saved = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.inkGhost).frame(width: 36, height: 4).padding(.top, 8).padding(.bottom, 10)
            HStack {
                Text("Share outside Ore").font(.archivo(22, weight: .black)).foregroundStyle(Color.inkPrimary)
                Spacer()
                Button("Close") { dismiss() }.font(.archivo(14, weight: .semibold)).foregroundStyle(Color.accentInk)
            }
            .padding(.horizontal, 16)

            if ShareCardModel.styles(member: model.member).count > 1 {
                SegmentedChoice(options: ShareCardModel.Style.allCases.map { ($0.rawValue, $0) }, selection: $model.style)
                    .padding(.top, 12).onChange(of: model.style) { _, _ in fileURL = nil; saved = false }
            }

            preview.padding(.top, 12)

            Text("9:16 · 6-SECOND LOOP · VIDEO").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.top, 10)

            VStack(spacing: 10) {
                leftButton(title: "SHARE TO STORY", primary: true, id: "share.story") { Task { await shareToStory() } }
                leftButton(title: saved ? "SAVED ✓" : "SAVE VIDEO", primary: false, id: "share.save") { Task { await save() } }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .task { for s in model.sides { if let g = await BodyMapGeometry.figure(s) { geometry[s] = g } } }
        .sheet(item: $shareURL) { ShareSheet(items: [$0]) }
        .alert("Couldn't make the video", isPresented: $failed) { Button("OK") {} }
    }

    private var preview: some View {
        let h: CGFloat = 430, w = h * 9 / 16
        return TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: ShareCardModel.loopSeconds)
            PostShareCardView(model: model, t: t, geometry: geometry)
                .scaleEffect(w / ShareCardModel.size.width, anchor: .topLeading)
                .frame(width: w, height: h, alignment: .topLeading)
        }
        .frame(width: w, height: h).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Share card preview")
    }

    private func leftButton(title: String, primary: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let p = progress, title != "SAVED ✓" { Text(primary ? "RENDERING \(Int(p * 100))%" : title) } else { Text(title) }
                Spacer()
                Text("›").font(.archivo(24))
            }
            .font(.archivo(19, weight: .black)).tracking(0.5)
            .foregroundStyle(primary ? Color.white : Color.inkPrimary)
            .padding(.horizontal, 20).frame(height: 60).frame(maxWidth: .infinity)
            .background { if primary { AccentFill() } else { Color.surf2 } }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressOpacityButtonStyle()).disabled(progress != nil).accessibilityIdentifier(id)
    }

    private func video() async -> URL? {
        if let fileURL { return fileURL }
        progress = 0
        defer { progress = nil }
        do {
            let url = try await ShareVideoExporter.shared.export(model, weightUnit: unit) { progress = $0 }
            fileURL = url
            return url
        } catch { failed = true; return nil }
    }

    private func shareToStory() async { if let url = await video() { shareURL = url } }
    private func save() async { if let url = await video() { saved = await ShareVideoExporter.saveToPhotos(url) } }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

extension ShareCardModel {
    /// From a finished workout (the composer) .
    init(data: WorkoutCompletionData, levels: [String: Double]) {
        let store = AccentStore.shared
        let member = store.stardustEnabled
        let volume = data.exercises.flatMap(\.workingSets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        self.init(title: data.workoutName ?? "Workout", date: Date(), prCount: data.prCount, sets: data.totalSets, volumeKg: volume,
                  durationSeconds: Int(data.duration), improved: data.improvedCount, totalExercises: data.totalExercises, levels: levels,
                  member: member, accentHex: member ? store.active.hexString : BodyMapConfigStore.shared.current.heatAccent,
                  style: member ? .ticker : .classic)
    }

    /// From a post in the feed (the ··· › Share outside Ore on your own post).
    init(post: WorkoutFeedItem, member: Bool, accentHex: String?) {
        self.init(title: post.templateName ?? "Workout", date: post.date, prCount: post.prCount, sets: post.workingSetCount, volumeKg: post.volumeKg,
                  durationSeconds: post.durationSeconds, improved: post.improvedCount, totalExercises: post.totalExercises,
                  levels: BodyMapLevels.levels(muscleSets: post.muscleSets), member: member,
                  accentHex: accentHex ?? BodyMapConfigStore.shared.current.heatAccent, style: member ? .ticker : .classic)
    }
}
