import SwiftUI
import FirebaseAuth
import PhotosUI

/// After a workout: the full-screen summary (§3a) first, then the composer (§3c), joined by the shrink-into-place transition (§3b).
/// Ore Feed Post Final. If any part of the body map is on screen when CONTINUE is tapped, the map flies into the composer's preview
/// tile (600 ms, cubic-bezier(0.32, 0.72, 0, 1)) while the rest of the UI fades (200 ms). If the map is fully scrolled off, nothing
/// shrinks or fades: the whole summary slides off to the left (460 ms, same curve) and reveals the composer. The page never scrolls
/// back up first.
struct WorkoutCompletionView: View {
    let data: WorkoutCompletionData
    let userName: String
    let onDismiss: () -> Void

    private enum Phase { case summary, composer }
    @State private var phase: Phase = .summary
    @State private var slideOff = false
    @State private var uiOpacity = 1.0
    @State private var composer = PostComposerModel()
    @State private var hasPosted = false
    @State private var showShare = false
    @Namespace private var mapSpace
    @AppStorage("autoShareToFeed") private var autoShare = true

    static let curve = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.6)
    static let slideCurve = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.46)

    private var levels: [String: Double] { BodyMapLevels.levels(muscleSets: FeedPostBuilder.muscleSetCounts(for: data.exercises)) }

    var body: some View {
        ZStack {
            if phase == .composer {
                PostComposerPage(data: data, model: composer, levels: levels, namespace: mapSpace,
                                 onPost: post, onShare: { showShare = true }, onSaveDraft: saveDraft, onDontPost: onDismiss, onBack: back)
                    .transition(.opacity)
                    .zIndex(0)
            }
            if phase == .summary {
                WorkoutSummaryPage(data: data, levels: levels, namespace: mapSpace, onContinue: cont, onClose: onDismiss, uiOpacity: uiOpacity)
                    .transition(slideOff ? .move(edge: .leading) : .opacity)
                    .zIndex(1)
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .sheet(isPresented: $showShare) { ShareOutsideSheet(model: ShareCardModel(data: data, levels: levels)) }
    }

    private func cont(mapVisible: Bool) {
        slideOff = !mapVisible
        if mapVisible {
            withAnimation(.easeOut(duration: 0.2)) { uiOpacity = 0 }          // the UI fades while the map flies
            withAnimation(Self.curve) { phase = .composer }
        } else {
            withAnimation(Self.slideCurve) { phase = .composer }
        }
    }

    private func back() {
        slideOff = true
        uiOpacity = 1
        withAnimation(Self.slideCurve) { phase = .summary }
    }

    private var extrasWithoutPhoto: PostExtras { composer.extras }

    private func post() {
        guard !hasPosted else { return }
        hasPosted = true
        let completion = data, text = composer.caption, tags = composer.tagged.map(\.uid), extras = composer.extras, jpeg = composer.photoJPEG
        Task {
            await SocialViewModel.shared.publishWorkoutPost(data: completion, caption: text, taggedUids: tags, includeBodyMap: true, extras: extras, photoJPEG: jpeg)
        }
        onDismiss()
    }

    /// "Save as draft": the post is kept on this device and posted from History later.
    private func saveDraft() {
        if let payload = SocialViewModel.shared.draftPayload(data: data, caption: composer.caption, taggedUids: composer.tagged.map(\.uid),
                                                             includeBodyMap: true, extras: composer.extras) {
            PostDraftStore.shared.save(payload, photoJPEG: composer.photoJPEG)
        }
        onDismiss()
    }
}

// MARK: - Legacy helpers

struct CompletionStatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.display(20)).foregroundStyle(Color.accentInk)
            Text(value).font(.display(20))
            Text(title).font(.mono(11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []; var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            positions.append(.init(x: x, y: y)); rowH = max(rowH, sz.height); x += sz.width + spacing
        }
        return (CGSize(width: maxW, height: y + rowH), positions)
    }
}

#Preview {
    WorkoutCompletionView(data: .preview, userName: "Vasanth", onDismiss: {})
}
