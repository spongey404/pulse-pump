import SwiftUI
import FirebaseAuth
import PhotosUI

struct WorkoutCompletionView: View {
    let data: WorkoutCompletionData
    let userName: String
    let onDismiss: () -> Void
    @Environment(\.weightUnit) private var unit

    @State private var caption = ""
    /// Guards the one-and-only post for this workout.
    @State private var hasPosted = false
    @AppStorage("autoShareToFeed") private var autoShare = true
    @State private var showComposerMenu = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var thumbnailImage: Image?
    @State private var thumbnailUIImage: UIImage?
    @State private var avatarImage: Image?
    @State private var keyboardUp = false
    @State private var cardContentHeight: CGFloat = 430
    @State private var photoSlideHeight: CGFloat = 300
    @State private var carouselPage: Int? = 0
    @State private var taggedFriends: [FirestoreUserProfile] = []
    @State private var showTagFriendsSheet = false

    private var shortDate: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: Date()).uppercased()
    }
    private var shortDateBrief: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: Date()).uppercased()
    }


    private var tickerItems: [TickerItem] {
        var items: [TickerItem] = [
            TickerItem(label: "", value: "DONE", direction: nil),
        ]
        if data.prCount > 0 {
            items.append(TickerItem(label: "\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")", value: "★", direction: nil, showArrow: false, gold: true))
        }
        if data.totalExercises > 0 {
            items.append(TickerItem(label: "IMPROVED", value: "\(data.improvedCount)/\(data.totalExercises)", direction: .up))
        }
        items.append(TickerItem(label: "SETS", value: "\(data.totalSets)", direction: nil))
        if data.streakCount > 0 {
            items.append(TickerItem(label: "STREAK", value: "\(data.streakCount)D", direction: nil))
        }
        return items + items
    }

    /// Clock-style duration for the card (58:42, or 1:02:09 past an hour).
    private var clockDuration: String {
        let t = Int(data.duration)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// Distance from the screen's bottom edge to the docked bar's content (design: 30 pt), minus the safe area the inset already gives.
    private var dockBottomPadding: CGFloat {
        let inset = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.safeAreaInsets.bottom ?? 0
        return keyboardUp ? 10 : 30 - inset   // negative: the bar's content sits 30 pt from the screen edge, inside the home-indicator area
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerBar
                Color.clear.frame(height: 14)
                cardArea
                captionComposer
                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { dockedBar }

            if showComposerMenu {
                Color(hex: "#1F1C19").opacity(0.45)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { showComposerMenu = false }
                    }
                    .transition(.opacity)
                composerMenu
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .task { await loadAvatar() }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    thumbnailUIImage = uiImage
                    thumbnailImage = Image(uiImage: uiImage)
                    let availableWidth = UIScreen.main.bounds.width - 32
                    let ratio = uiImage.size.height / uiImage.size.width
                    photoSlideHeight = min(availableWidth * ratio, Self.cardMaxHeight)
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.95)) {
                        carouselPage = 0
                    }
                }
            }
        }
        .sheet(isPresented: $showTagFriendsSheet) {
            TagFriendsSheet(alreadyTagged: taggedFriends) { picked in
                taggedFriends = picked
            }
        }
    }

    // MARK: - Card area (the only part that scrolls)

    @ViewBuilder private var cardArea: some View {
        if let photo = thumbnailImage {
            GeometryReader { proxy in
                let w = proxy.size.width
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        photo
                            .resizable()
                            .scaledToFit()
                            .frame(width: w)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    thumbnailImage = nil
                                    thumbnailUIImage = nil
                                    selectedPhotoItem = nil
                                    carouselPage = nil
                                } label: {
                                    Text("REMOVE")
                                        .font(Font.spaceMono(8, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundStyle(Color(hex: "#F9F8F4"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: "#1F1C19").opacity(0.6))
                                        .clipShape(Capsule())
                                        .padding(8)
                                }
                                .buttonStyle(.plain)
                            }
                            .id(0)
                        shareCard
                            .frame(width: w)
                            .id(1)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $carouselPage)
            }
            .frame(height: (carouselPage ?? 0) == 0 ? photoSlideHeight : min(cardContentHeight, Self.cardMaxHeight))
            .animation(.spring(response: 0.18, dampingFraction: 0.95), value: carouselPage)
            .padding(.horizontal, 16)

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill((carouselPage ?? 0) == i ? Color.inkPrimary : Color.inkMuted.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
        } else {
            shareCard
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    static let cardMaxHeight: CGFloat = 430

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("WORKOUT COMPLETE")
                        .accessibilityIdentifier(AX.completion.title)
                    Text(" · \(shortDateBrief)")
                }
                .font(Font.spaceMono(9))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
                Text((data.workoutName ?? "WORKOUT").uppercased())
                    .font(.archivo(26, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Text("‹")
                    .font(.archivo(18))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.surf2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close summary")
            .accessibilityIdentifier(AX.completion.back)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Share Card

    private var shareCard: some View {
        ScrollView {
            VStack(spacing: 0) {
                TickerStripView(items: tickerItems, height: 33)
                heroBlock
                statsRow
                exerciseTable
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardContentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .frame(maxHeight: min(cardContentHeight, Self.cardMaxHeight))   // gives way when the keyboard is up
        .frame(maxWidth: .infinity)
        .layoutPriority(-1)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// The design breaks a short name onto one word per line (PUSH / DAY).
    private var heroTitle: String {
        let words = (data.workoutName ?? "WORKOUT").uppercased().split(separator: " ")
        return words.count <= 3 ? words.joined(separator: "\n") : words.joined(separator: " ")
    }

    private var isMember: Bool { AccentStore.shared.isMember }

    /// Title, time and PR chip on the left; the body map (Stardust in the member's accent for members) on the right.
    private var heroBlock: some View {
        let intensities = BodyHeat.Intensities(exercises: data.exercises)
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(heroTitle)
                    .font(.archivo(30, weight: .black))
                    .cssLineHeight(fontName: "Archivo-Black", size: 30, multiple: 0.95)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                Text(clockDuration)
                    .font(Font.spaceMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 6)
                if data.prCount > 0 {
                    HStack(spacing: 6) {
                        PRStar(size: 12)
                        Text("\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")")
                            .font(Font.spaceMono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.surf, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                BodyHeat(intensities: intensities)
                if isMember {
                    StardustMuscleOverlay(intensities: intensities, palette: AccentStore.shared.starPalette)
                }
            }
            .frame(width: 110, height: 176)
        }
        .padding(.leading, 16).padding(.trailing, 22)
        .frame(height: 220)
        .background(Color.surf2)
    }

    // MARK: Stats Row

    private var volString: String {
        let t = data.exercises.flatMap(\.workingSets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return unit.compactVolume(t)   // set weights are kg
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 8) {
            statCell("SETS", "\(data.totalSets)", .inkPrimary)
            statCell("VOLUME · \(unit.label)", volString, .inkPrimary)
            statCell("IMPROVED", "\(data.improvedCount)/\(data.totalExercises)", .signalUp)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func statCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            Text(value).font(Font.spaceMono(18, weight: .bold)).foregroundStyle(color).frame(height: 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Exercise Table (every exercise)

    private var exerciseTable: some View {
        let prNames = Set(data.prDetails.map(\.exerciseName))
        let rows = data.exercises.enumerated().sorted { a, b in
            let ap = prNames.contains(a.element.name), bp = prNames.contains(b.element.name)
            if ap != bp { return ap }
            if a.element.improvementScore != b.element.improvementScore { return a.element.improvementScore > b.element.improvementScore }
            return a.offset < b.offset
        }.map(\.element)
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("EXERCISE").frame(maxWidth: .infinity, alignment: .leading)
                Text("SETS").frame(width: 34, alignment: .leading)
                Text("BEST").frame(width: 64, alignment: .trailing)
            }
            .font(Font.spaceMono(7))
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            ForEach(rows) { ex in
                let isPR = prNames.contains(ex.name)
                let muted = !isPR && ex.improvementScore <= 0
                HStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(ex.name)
                            .font(.archivo(14, weight: .bold))
                            .foregroundStyle(isPR ? Color.prGold : (muted ? Color.inkMuted : Color.inkPrimary))
                            .lineLimit(1)
                        if isPR { PRStar(size: 11) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(ex.workingSets.count)")
                        .font(Font.spaceMono(12))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 34, alignment: .leading)
                    Text(bestSetText(ex))
                        .font(Font.spaceMono(13, weight: .bold))
                        .foregroundStyle(muted ? Color.inkMuted : Color.inkPrimary)
                        .frame(width: 64, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Color.oreAccent).frame(width: 7, height: 7)
                Text("ORE").font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private func bestSetText(_ ex: FeedExercise) -> String {
        guard let best = ex.workingSets.max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) }) else { return "—" }
        return best.weight > 0 ? "\(unit.number(best.weight))×\(best.reps)" : "\(best.reps)r"
    }

    // MARK: - Docked POST bar

    private var dockedBar: some View {
        let store = AccentStore.shared
        return VStack(spacing: 0) {
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
            HStack(spacing: 10) {
                Button {
                    // Auto-share off ("Never post automatically"): the screen defaults to DONE and
                    // posting becomes an explicit choice in the overflow menu.
                    if autoShare { postAndDismiss(includeBodyMap: true) } else { dismissWithoutPosting() }
                } label: {
                    Text(autoShare ? "POST" : "DONE")
                        .font(.archivo(15, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            ZStack {
                                Color.oreAccent
                                if store.stardustEnabled {
                                    StardustView(variant: "cta", budget: .more,
                                                 overrides: StardustParams.Overrides(palette: store.starPalette, density: 1600, gold: 0.4, sparkle: 0.55, fps: 30))
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.completion.cta)

                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { showComposerMenu.toggle() }
                } label: {
                    Text("···")
                        .font(Font.spaceMono(16, weight: .bold))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 52, height: 52)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More")
                .accessibilityIdentifier(AX.completion.menu)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, dockBottomPadding)
        }
        .background(Color.canvasBg.ignoresSafeArea(edges: .bottom))
    }


    private func loadAvatar() async {
        guard let url = Auth.auth().currentUser?.photoURL else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        avatarImage = Image(uiImage: uiImage)
    }

    // MARK: - Caption Composer

    private var captionComposer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Caption row — 36px avatar, bottom-border field, trailing camera button
            // (hidden once a photo is attached).
            HStack(alignment: .center, spacing: 12) {
                Group {
                    if let img = avatarImage {
                        img.resizable().scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                    } else {
                        Text(avatarInitial)
                            .font(.archivo(15, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.oreAccent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                HStack {
                    if caption.isEmpty {
                        Text("Add a caption")
                            .font(.archivo(15))
                            .foregroundStyle(Color.inkMuted)
                    }
                    TextField("", text: $caption, axis: .vertical)
                        .font(.archivo(15))
                        .foregroundStyle(Color.inkPrimary)
                        .accessibilityIdentifier(AX.completion.caption)
                }
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                if thumbnailImage == nil {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "camera")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.accentInk)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)

            // Tag friends
            SectionLabel(title: "Tag Friends", meta: "Friends Only ›")
                .padding(.top, 22)
                .padding(.bottom, 8)

            FlowLayout(spacing: 8) {
                ForEach(taggedFriends, id: \.uid) { friend in
                    HStack(spacing: 7) {
                        Avatar(initial: friend.shownName, size: 24, showBorder: false, textColor: .inkSecondary)
                        Text(friend.shownName)
                            .font(.archivo(13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .padding(.leading, 4).padding(.trailing, 10)
                    .frame(height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                }

                Button { showTagFriendsSheet = true } label: {
                    Text("+ ADD").font(Font.spaceMono(9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .background(Color.canvasBg)
    }

    // MARK: - Composer overflow menu (screen 7a)

    private var composerMenu: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.ruleStrong).frame(width: 36, height: 4).padding(.top, 10).padding(.bottom, 10)
            SectionLabel(title: "Session Saved Either Way")
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            composerMenuRow(id: AX.completion.dontPost, title: "Don't post", note: "STAYS IN YOUR HISTORY, NOBODY SEES IT") {
                dismissWithoutPosting()
            }
            composerMenuRow(id: AX.completion.postNoBodyMap, title: "Post without body map", note: "STATS ONLY, NO BODY MAP") {
                postAndDismiss(includeBodyMap: false)
            }
            Group {
                if autoShare {
                    composerMenuRow(id: nil, title: "Never post automatically", note: "POSTING BECOMES OPT-IN") {
                        autoShare = false
                        dismissWithoutPosting()
                    }
                } else {
                    composerMenuRow(id: AX.completion.postToFeed, title: "Post to feed", note: "SHARE THIS SESSION ONCE") {
                        postAndDismiss(includeBodyMap: true)
                    }
                }
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .padding(.bottom, 26)
        .background(Color.canvasBg)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 8, style: .continuous))
    }

    private func composerMenuRow(id: String?, title: String, note: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { showComposerMenu = false }
            action()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text(note).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Text("›").font(Font.spaceMono(14)).foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
        }
        .buttonStyle(.plain)
        .axID(id)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Helpers

    private var avatarInitial: String {
        String((userName.isEmpty ? "U" : userName).prefix(1)).uppercased()
    }

    /// Publishes this session once (the post id is the workout's id, and `hasPosted` guards double taps).
    /// The post is built from the workout's working sets only, with `audience` / `bodyMapAudience` taken
    /// from the privacy settings; with "Workout posts" set to "Only me" nothing is posted.
    /// - Parameter includeBodyMap: false for the overflow's "Post without body map" row, which skips
    ///   the `extras/bodymap` document entirely.
    private func postAndDismiss(includeBodyMap: Bool) {
        guard !hasPosted else { return }
        hasPosted = true
        let tagged = taggedFriends.map(\.uid)
        let text = caption
        let completion = data
        Task {
            await SocialViewModel.shared.publishWorkoutPost(data: completion, caption: text, taggedUids: tagged, includeBodyMap: includeBodyMap)
        }
        onDismiss()
    }

    /// "Don't post" / "Never post automatically" — session stays in local history only.
    private func dismissWithoutPosting() {
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
