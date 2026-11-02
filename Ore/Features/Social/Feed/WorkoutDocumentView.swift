import SwiftUI

/// A finished workout as a document (Ore Feed Post Final §5): flat sections split by hairlines, read-only and compact, consistent with
/// the logger. Used by the full workout view and under the summary's body map (§3a).
struct WorkoutDocumentExercises: View {
    @Environment(\.weightUnit) private var unit
    let exercises: [FeedExercise]
    /// Exercises whose best set is a PR (they get the animated star next to the KG).
    let prExerciseIds: Set<String>

    /// The post doesn't carry a per-exercise PR flag: the top `prCount` exercises by improvement are the PRs.
    static func prIds(_ exercises: [FeedExercise], prCount: Int) -> Set<String> {
        Set(exercises.sorted { $0.improvementScore > $1.improvementScore }.prefix(prCount).filter { $0.improvementScore > 0 || prCount > 0 }.map(\.id))
    }

    /// Epley best working set, the one that carries the PR star and the VS LAST gain.
    static func bestSetIndex(_ e: FeedExercise) -> Int? {
        e.sets.indices.filter { e.sets[$0].isWorking }.max(by: {
            e.sets[$0].weight * (1 + Double(e.sets[$0].reps) / 30) < e.sets[$1].weight * (1 + Double(e.sets[$1].reps) / 30)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { i, e in section(i, e) }
        }
    }

    private func section(_ i: Int, _ e: FeedExercise) -> some View {
        let best = Self.bestSetIndex(e)
        let top = e.workingSets.map(\.weight).max() ?? 0
        var standardNo = 0
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text(String(format: "%02d", i + 1)).font(.spaceMono(10)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.top, 5)
                VStack(alignment: .leading, spacing: 6) {
                    Text(e.name.uppercased()).font(.archivo(20, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary)
                    Text("\(e.workingSets.count) SETS" + (top > 0 ? " · TOP \(unit.number(top)) \(unit.label)" : ""))
                        .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)

            HStack(spacing: 8) {
                Text("TYPE").frame(width: 52, alignment: .leading)
                Text(unit.label).frame(maxWidth: .infinity, alignment: .leading)
                Text("REPS").frame(maxWidth: .infinity, alignment: .leading)
                Text("VS LAST").frame(width: 70, alignment: .trailing)
            }
            .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Color.surf2)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            ForEach(Array(e.sets.enumerated()), id: \.offset) { si, s in
                let type = SetType(rawValue: s.setType) ?? .standard
                let _ = { if type == .standard { standardNo += 1 } }()
                let isBest = si == best
                let vs = isBest ? Self.vsLast(e, unit: unit) : (text: "—", tone: VsTone.none)
                HStack(spacing: 8) {
                    Group {
                        if type == .standard {
                            Text(String(format: "%02d", standardNo)).font(.spaceMono(12)).foregroundStyle(Color.inkMuted)
                        } else {
                            SetTypeChipLabel(type: type)
                        }
                    }
                    .frame(width: 52, alignment: .leading)
                    HStack(spacing: 6) {
                        Text(s.weight > 0 ? unit.number(s.weight) : "—").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        if isBest && prExerciseIds.contains(e.id) { StarBullet(size: 10, delay: -1.06 * Double(i)) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(s.reps)").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(maxWidth: .infinity, alignment: .leading)
                    Text(vs.text).font(.spaceMono(11, weight: .bold)).foregroundStyle(vs.tone.color).frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 14).frame(minHeight: 34)
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
        }
        .padding(.top, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    enum VsTone { case up, down, none
        var color: Color { switch self { case .up: .signalUp; case .down: .signalDown; case .none: .inkMuted } }
    }

    /// ▲ green / ▼ red / — muted against that person's previous time on the exercise.
    static func vsLast(_ e: FeedExercise, unit: UnitPreference) -> (text: String, tone: VsTone) {
        if e.weightDelta > 0 { return ("▲ +\(unit.formatTight(e.weightDelta))", .up) }
        if e.weightDelta < 0 { return ("▼ \(unit.formatTight(e.weightDelta))", .down) }
        if e.repsDelta > 0 { return ("▲ +\(e.repsDelta) REP\(e.repsDelta == 1 ? "" : "S")", .up) }
        if e.repsDelta < 0 { return ("▼ \(e.repsDelta) REP\(e.repsDelta == -1 ? "" : "S")", .down) }
        return ("—", .none)
    }
}

/// Front and back figures side by side, only the trained ones (rule: never an empty side).
struct TrainedSidesFigures: View {
    var levels: [String: Double]
    var member = false
    var accentHex: String? = nil
    var height: CGFloat = 230

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(BodyMapLevels.trainedSides(levels), id: \.self) { side in
                BodyFigureView(side: side, levels: levels, member: member, accentHex: accentHex)
            }
        }
        .frame(height: height).frame(maxWidth: .infinity).padding(.top, 10)
    }
}

/// The full workout view: opened from a post, a profile's recent workouts, and (the exercise part) the summary. Your own workout has
/// a ··· with Edit post / Delete post; a friend's has none.
struct FeedSessionSheet: View {
    @Environment(\.weightUnit) private var unit
    @Environment(\.dismiss) private var dismiss
    let item: WorkoutFeedItem
    var viewModel: SocialViewModel
    var onEdit: ((WorkoutFeedItem) -> Void)? = nil

    @State private var menuOpen = false
    @State private var confirmDelete = false
    @State private var showComments = false
    @State private var showEdit = false

    private var current: WorkoutFeedItem { viewModel.post(id: item.id, fallback: item) }
    private var isMine: Bool { item.userId == viewModel.currentUid }
    private var who: String { isMine ? "YOU" : (item.username.isEmpty ? item.handle : item.username).uppercased() }
    private var member: SocialMemberStyle? { SocialMembership.style(for: item.userId, currentUid: viewModel.currentUid) }
    private var levels: [String: Double] { BodyMapLevels.levels(muscleSets: item.muscleSets) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    if item.includesBodyMap { TrainedSidesFigures(levels: levels, member: member != nil, accentHex: member?.accentHex) }
                    stats
                    WorkoutDocumentExercises(exercises: item.exercises, prExerciseIds: WorkoutDocumentExercises.prIds(item.exercises, prCount: item.prCount))
                    SocialReactRow(liked: current.likedByMe, likeCount: current.likeCount, commentCount: current.commentCount,
                                   onLike: { Task { await viewModel.toggleLike(postId: item.id) } }, onComment: { showComments = true })
                        .padding(.vertical, 12)
                }
            }
        }
        .background(Color.canvasBg)
        .fullScreenCover(isPresented: $showComments) { CommentsView(item: current, viewModel: viewModel) }
        .fullScreenCover(isPresented: $showEdit) { EditPostView(post: current, viewModel: viewModel) }
        .alert("Delete this post?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await viewModel.deletePost(item.id); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It's removed for everyone. The workout stays in your History.") }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary).frame(width: 44, height: 44)
                    .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain).accessibilityLabel("Back").accessibilityIdentifier(AX.nav.back)
            VStack(alignment: .leading, spacing: 5) {
                Text((item.templateName ?? "WORKOUT").uppercased()).font(.archivo(24, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary).lineLimit(1)
                Text("\(who) · \(PostTime.duration(item.durationSeconds)) · \(PostTime.ago(item.date))")
                    .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 0)
            if isMine {
                Button { menuOpen = true } label: {
                    Text("···").font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkSecondary).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).accessibilityLabel("Workout options")
                .popover(isPresented: $menuOpen, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                    PostMenuPopover {
                        PostMenuRow(title: "Edit post") { menuOpen = false; showEdit = true; onEdit?(item) }
                        PostMenuRow(title: "Delete post", detail: "The workout stays in your History.", destructive: true) { menuOpen = false; confirmDelete = true }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 8) {
            cell("SETS", "\(item.workingSetCount)", .inkPrimary)
            cell("VOLUME", unit.compactVolume(item.volumeKg), .inkPrimary)
            cell("IMPROVED", "\(item.improvedCount)/\(item.totalExercises)", .signalUp)
            cell("PRS", "\(item.prCount)", .inkPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
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
