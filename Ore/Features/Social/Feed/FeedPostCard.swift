import SwiftUI
import SwiftData

/// A friend's (or your own) post in the feed, from Claude Design `Ore Feed Post Final.dc.html` §1. Your own post looks exactly like a
/// friend's; only the ··· menu differs. Card: header, "Trained with", carousel (photo, body map), song, title + stats, exercise preview,
/// caption, like + comment. Tapping the lower half opens the full workout.
struct FeedPostCard: View {
    @Environment(\.weightUnit) private var unit
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    let item: WorkoutFeedItem
    var viewModel: SocialViewModel
    /// Plugged in by the Edit post / Share outside Ore slices; a row shows only when its handler exists.
    var onEdit: ((WorkoutFeedItem) -> Void)? = nil
    var onShare: ((WorkoutFeedItem) -> Void)? = nil
    @State private var showShare = false
    @State private var showEdit = false

    @State private var showDetail = false
    @State private var showComments = false
    @State private var showProfile = false
    @State private var menuOpen = false
    @State private var confirmDelete = false
    @State private var confirmBlock = false
    @State private var actionMessage: String?
    @State private var slide: Int? = 0
    @State private var bursts = BurstController()
    @State private var likePop = 0
    @State private var likeBursts = BurstController()

    private var cfg: SocialConfig { SocialConfigStore.shared.current }
    private var current: WorkoutFeedItem { viewModel.post(id: item.id, fallback: item) }
    private var isMine: Bool { item.userId == viewModel.currentUid }
    private var displayName: String { item.username.isEmpty ? (item.handle.isEmpty ? Brand.defaultUserName : item.handle) : item.username }
    private var member: SocialMemberStyle? { SocialMembership.style(for: item.userId, currentUid: viewModel.currentUid) }
    /// The poster's accent, not the viewer's: their chosen colour if they are a member, Ore's blue otherwise.
    private var accent: Color { Color(hex: member?.accentHex ?? BodyMapConfigStore.shared.current.heatAccent) }
    private var levels: [String: Double] { BodyMapLevels.levels(muscleSets: item.muscleSets) }
    private var hasPhoto: Bool { item.photoURL != nil }
    private var hasMap: Bool { item.includesBodyMap && !BodyMapLevels.trainedSides(levels).isEmpty }
    private var slideCount: Int { (hasPhoto ? 1 : 0) + (hasMap ? 1 : 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let names = item.taggedNames, !names.isEmpty { trainedWith(names) }
            if slideCount > 0 { carousel }
            if slideCount > 1 { dots }
            if let song = item.song { SongRow(postId: item.id, song: song, accent: accent) }
            lower
        }
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: cfg.card.radius, style: .continuous))
        .fullScreenCover(isPresented: $showDetail) { FeedSessionSheet(item: item, viewModel: viewModel) }
        .fullScreenCover(isPresented: $showComments) { CommentsView(item: item, viewModel: viewModel) }
        .sheet(isPresented: $showProfile) {
            NavigationStack { FriendProfileView(uid: item.userId, handle: item.handle, name: displayName, viewModel: viewModel) }
        }
        .fullScreenCover(isPresented: $showEdit) { EditPostView(post: current, viewModel: viewModel) }
        .sheet(isPresented: $showShare) { ShareOutsideSheet(model: ShareCardModel(post: item, member: member != nil, accentHex: member?.accentHex)) }
        .alert(actionMessage ?? "", isPresented: Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })) { Button("OK") {} }
        .alert("Block @\(item.handle)?", isPresented: $confirmBlock) {
            Button("Block", role: .destructive) {
                Task { let ok = await viewModel.block(uid: item.userId, name: displayName, handle: item.handle); actionMessage = ok ? "Blocked. You won't see their posts." : nil }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("They disappear from your feed, search and lists, and can't follow you.") }
        .alert("Delete this post?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await viewModel.deletePost(item.id) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It's removed for everyone. The workout stays in your History.") }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button { if !isMine { showProfile = true } } label: {
                HStack(spacing: 10) {
                    Text(displayName.prefix(1).uppercased())
                        .font(.archivo(16, weight: .black)).foregroundStyle(.white)
                        .frame(width: cfg.card.avatar, height: cfg.card.avatar)
                        .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        if member != nil {
                            SupernovaTag()
                        } else {
                            Text("@\(item.handle.uppercased())").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AX.social.postCard(item.handle))
            Spacer(minLength: 0)
            Button { menuOpen = true } label: {
                Text("···").font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkSecondary).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Post options")
            .popover(isPresented: $menuOpen, attachmentAnchor: .point(.bottom), arrowEdge: .top) { menu }
        }
        .padding(.leading, 14).padding(.trailing, 8).padding(.top, 14)
    }

    @ViewBuilder private var menu: some View {
        PostMenuPopover {
            if isMine {
                PostMenuRow(title: "Edit post") { menuOpen = false; showEdit = true; onEdit?(item) }
                PostMenuRow(title: "Share outside Ore") { menuOpen = false; showShare = true; onShare?(item) }
                PostMenuRow(title: "Delete post", detail: "The workout stays in your History.", destructive: true) { menuOpen = false; confirmDelete = true }
            } else {
                PostMenuRow(title: "Hide this post") { menuOpen = false; viewModel.hide(postId: item.id) }
                PostMenuRow(title: "Mute \(displayName)") { menuOpen = false; viewModel.mute(uid: item.userId) }
                PostMenuRow(title: "Report post", destructive: true) {
                    menuOpen = false
                    Task { if await viewModel.reportPost(item.id) { actionMessage = "Reported. This post is hidden for you." } }
                }
            }
        }
    }

    // MARK: Trained with

    private func trainedWith(_ names: [String]) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: -6) {
                ForEach(Array(names.prefix(3).enumerated()), id: \.offset) { i, n in
                    Text(n.prefix(1).uppercased()).font(.archivo(10, weight: .black)).foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Self.friendTints[i % Self.friendTints.count], in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.surf, lineWidth: 2))
                }
            }
            Text(Self.trainedWithText(names)).font(.archivo(13)).foregroundStyle(Color.inkSecondary).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.top, 8)
    }

    static let friendTints = [Color(hex: "#14B8A6"), Color(hex: "#8B5CF6"), Color(hex: "#F59E0B")]

    /// "Trained with Sam and Jordan", "Sam, Jordan and Alex", "Sam, Jordan and 2 others".
    static func trainedWithText(_ names: [String]) -> AttributedString {
        var out = AttributedString("Trained with ")
        func bold(_ s: String) -> AttributedString { var a = AttributedString(s); a.font = .archivo(13, weight: .semibold); a.foregroundColor = UIColor(Color.inkPrimary); return a }
        let plain = { (s: String) in AttributedString(s) }
        switch names.count {
        case 0: break
        case 1: out += bold(names[0])
        case 2: out += bold(names[0]) + plain(" and ") + bold(names[1])
        case 3: out += bold(names[0]) + plain(", ") + bold(names[1]) + plain(" and ") + bold(names[2])
        default: out += bold(names[0]) + plain(", ") + bold(names[1]) + plain(" and \(names.count - 2) others")
        }
        return out
    }

    // MARK: Carousel

    private var carousel: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    if let url = item.photoURL {
                        photoSlide(url).containerRelativeFrame(.horizontal).id(0)
                    }
                    if hasMap {
                        BodyMapSwapView(levels: levels, member: member != nil, accentHex: member?.accentHex)
                            .frame(height: cfg.card.slideHeight)
                            .containerRelativeFrame(.horizontal)
                            .id(hasPhoto ? 1 : 0)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $slide)
            .frame(height: cfg.card.slideHeight)

            GeometryReader { _ in
                StarBurstLayer(bursts: bursts.bursts, accent: accent)
            }
            .allowsHitTesting(false)
        }
        .padding(.top, 10)
        .contentShape(Rectangle())
        .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { v in doubleTap(at: v.location) })
        .accessibilityElement(children: .contain)
    }

    private func photoSlide(_ url: String) -> some View {
        ZStack {
            Color.surf2
            AsyncImage(url: URL(string: url)) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
            }
        }
        .frame(height: cfg.card.slideHeight)
        .clipped()
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<slideCount, id: \.self) { i in
                Capsule().fill(i == (slide ?? 0) ? accent : Color.inkGhost)
                    .frame(width: i == (slide ?? 0) ? 16 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: slide)
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 2)
    }

    // MARK: Likes

    /// Double-tap likes on both slides and never unlikes; the heart and the burst appear where the finger landed.
    private func doubleTap(at p: CGPoint) {
        bursts.doubleTap(at: p, dark: scheme == .dark)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !current.likedByMe { Task { await viewModel.toggleLike(postId: item.id) } }
    }

    private func likeTapped() {
        let liking = !current.likedByMe
        Task { await viewModel.toggleLike(postId: item.id) }
        if liking { likePop += 1; likeBursts.likeButton(at: CGPoint(x: 70, y: 70)) }     // unlike has no animation
    }

    // MARK: Lower half (opens the full workout)

    private var lower: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.top, 6)
            VStack(alignment: .leading, spacing: 14) {
                Button { showDetail = true } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        titleRow
                        stats
                        exercisePreview
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Full workout")
                if !item.caption.isEmpty {
                    Text(item.caption).font(.archivo(15)).foregroundStyle(Color.inkPrimary)
                        .cssLineHeight(fontName: "Archivo-Regular", size: 15, multiple: 1.4)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                }
                reactRow
            }
            .padding(14)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text((item.templateName ?? "WORKOUT").uppercased()).font(.archivo(26, weight: .black)).foregroundStyle(Color.inkPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Text("\(PostTime.duration(item.durationSeconds)) · \(PostTime.ago(item.date))")
                    if item.isEdited == true { Text("· EDITED") }
                }
                .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 0)
            if item.prCount > 0 {
                HStack(spacing: 6) {
                    StarBullet(size: 11)
                    Text("\(item.prCount) NEW PR\(item.prCount == 1 ? "" : "S")").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
                }
                .padding(.horizontal, 10).frame(height: 26)
                .background(Color.surf2, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 8) {
            stat("SETS", Text("\(item.workingSetCount)"))
            stat("VOLUME", Text(unit.compactVolume(item.volumeKg)))
            stat("IMPROVED", Text("\(item.improvedCount)").foregroundStyle(Color.signalUp) + Text("/\(item.totalExercises)").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkMuted))
        }
    }

    private func stat(_ label: String, _ value: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            value.font(.spaceMono(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Exercise preview

    private var rankedExercises: [(exercise: FeedExercise, isPR: Bool)] {
        let order = item.exercises.sorted { $0.improvementScore > $1.improvementScore }.prefix(item.prCount).map(\.id)
        return item.exercises.map { ($0, order.contains($0.id)) }
    }

    private var exercisePreview: some View {
        let shown = Array(rankedExercises.prefix(cfg.card.previewRows))
        let more = max(0, item.exercises.count - shown.count)
        return VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.exercise.id) { i, e in
                HStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%02d", i + 1)).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        Text(e.exercise.name.exerciseTitleCase).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        if e.isPR { StarBullet(size: 10, delay: -0.53 * Double(i)) }
                        Text(Self.setSummary(e.exercise, unit: unit)).font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkSecondary)
                    }
                }
                .frame(minHeight: 38).padding(.horizontal, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
            HStack {
                Text("SEE FULL WORKOUT").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
                Spacer()
                HStack(spacing: 8) {
                    if more > 0 { Text("+\(more) MORE").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted) }
                    Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkPrimary)
                }
            }
            .frame(minHeight: 44).padding(.horizontal, 12)
        }
        .background(Color.surf2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// "4 × 120 KG": working sets × the heaviest weight (bodyweight work shows the reps).
    static func setSummary(_ e: FeedExercise, unit: UnitPreference) -> String {
        let working = e.workingSets
        guard let top = working.map(\.weight).max() else { return "\(e.sets.count) sets" }
        if top <= 0 { return "\(working.count) × \(working.map(\.reps).max() ?? 0)" }
        return "\(working.count) × \(unit.number(top)) \(unit.label)"
    }

    // MARK: Like + comment

    private var reactRow: some View {
        HStack(spacing: 20) {
            Button(action: likeTapped) {
                HStack(spacing: 8) {
                    ZStack {
                        Image(systemName: current.likedByMe ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(current.likedByMe ? accent : Color.inkSecondary)
                            .keyframeAnimator(initialValue: 1.0, trigger: likePop) { v, s in v.scaleEffect(s) } keyframes: { _ in
                                KeyframeTrack {
                                    CubicKeyframe(1.0, duration: 0.001)
                                    CubicKeyframe(cfg.like.popScale, duration: cfg.like.popMs / 1000 * 0.35)
                                    CubicKeyframe(1.0, duration: cfg.like.popMs / 1000 * 0.65)
                                }
                            }
                    }
                    .frame(width: 22, height: 22)
                    .overlay { StarBurstLayer(bursts: likeBursts.bursts, accent: accent).frame(width: 140, height: 140) }
                    Text("\(current.likeCount)").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(minWidth: 20, alignment: .leading)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(current.likedByMe ? "Unlike" : "Like")
            Button { showComments = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left").font(.system(size: 22, weight: .light)).foregroundStyle(Color.inkSecondary)
                    Text("\(current.commentCount)").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comments")
            Spacer()
        }
    }
}

/// The song row: 36 pt art, title, "ARTIST · PREVIEW 0:30" (or "0:12 / 0:30"), the level meter and the 32 pt play key. Nothing autoplays.
struct SongRow: View {
    let postId: String
    let song: PostSong
    let accent: Color
    private var player: PostSongPlayer { .shared }

    var body: some View {
        let state = player.state(postId)
        Button { player.toggle(postId: postId, song: song) } label: {
            HStack(spacing: 10) {
                Group {
                    if let a = song.artworkURL { AsyncImage(url: URL(string: a)) { $0.image?.resizable().scaledToFill() } } else { Color.surf }
                }
                .frame(width: SocialConfigStore.shared.current.song.artSize, height: SocialConfigStore.shared.current.song.artSize)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                    Text("\(song.artist.uppercased()) · \(state.label)").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
                SongLevelMeter(playing: state.playing, accent: accent)
                SongPlayKey(playing: state.playing, accent: accent, size: SocialConfigStore.shared.current.song.playSize)
            }
            .padding(8)
            .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 4)
        .accessibilityLabel("\(song.title), \(song.artist)")
        .accessibilityValue(state.playing ? "Playing" : "Paused")
        .accessibilityIdentifier("post.song")
    }
}
