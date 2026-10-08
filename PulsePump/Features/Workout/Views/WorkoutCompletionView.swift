import SwiftUI
import FirebaseAuth
import PhotosUI

struct WorkoutCompletionView: View {
    let data: WorkoutCompletionData
    let userName: String
    let onDismiss: () -> Void

    @State private var caption = ""
    /// Guards the one-and-only post for this workout.
    @State private var hasPosted = false
    @AppStorage("autoShareToFeed") private var autoShare = true
    @State private var showComposerMenu = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var thumbnailImage: Image?
    @State private var thumbnailUIImage: UIImage?
    @State private var avatarImage: Image?
    @State private var shareCardHeight: CGFloat = 560
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
            TickerItem(label: (data.workoutName ?? "WORKOUT").uppercased(), value: "DONE", direction: nil),
        ]
        if data.prCount > 0 {
            items.append(TickerItem(label: "\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")", value: "★", direction: .up, showArrow: false))
        }
        items.append(TickerItem(label: "IMPROVED",  value: "\(data.improvedCount)/\(data.totalExercises)", direction: .up))
        items.append(TickerItem(label: "SETS",      value: "\(data.totalSets)",           direction: nil))
        items.append(TickerItem(label: "KCAL",      value: "\(Int(data.calories))",       direction: nil))
        items.append(TickerItem(label: "DURATION",  value: data.formattedDuration,        direction: nil))
        return items + items
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    VStack(spacing: 0) {
                        if let photo = thumbnailImage {
                            GeometryReader { proxy in
                                let w = proxy.size.width
                                ScrollView(.horizontal) {
                                    HStack(alignment: .top, spacing: 0) {
                                        // Photo slide — natural aspect-ratio height
                                        photo
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: w)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                                            .background(GeometryReader { g in
                                                Color.clear.onAppear { photoSlideHeight = g.size.height }
                                            })
                                            .id(0)

                                        // Share card slide — natural content height
                                        shareCard
                                            .frame(width: w)
                                            .background(GeometryReader { g in
                                                Color.clear.onAppear { shareCardHeight = g.size.height }
                                            })
                                            .id(1)
                                    }
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                                .scrollBounceBehavior(.basedOnSize)
                                .scrollIndicators(.hidden)
                                .scrollPosition(id: $carouselPage)
                            }
                            .frame(height: (carouselPage ?? 0) == 0 ? photoSlideHeight : shareCardHeight)
                            .animation(.spring(response: 0.18, dampingFraction: 0.95), value: carouselPage)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)

                            // Page dots — outside the animated frame so they don't jump
                            HStack(spacing: 6) {
                                ForEach(0..<2, id: \.self) { i in
                                    Circle()
                                        .fill((carouselPage ?? 0) == i ? Color.inkPrimary : Color.inkMuted.opacity(0.4))
                                        .frame(width: 6, height: 6)
                                        .animation(.easeInOut(duration: 0.12), value: carouselPage)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            shareCard
                                .background(GeometryReader { geo in
                                    Color.clear.onAppear { shareCardHeight = geo.size.height }
                                })
                                .padding(.horizontal, 14)
                                .padding(.top, 14)
                        }
                        captionComposer
                        Color.clear.frame(height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                }
            }
            .safeAreaInset(edge: .bottom) {
                DockedCTA(
                    // Auto-share off ("Never post automatically"): the screen defaults to DONE and
                    // posting becomes an explicit choice in the overflow menu.
                    primaryLabel: autoShare ? "POST" : "DONE",
                    secondaryIcon: "ellipsis",
                    secondaryAction: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { showComposerMenu.toggle() }
                    },
                    action: { autoShare ? postAndDismiss(includeBodyMap: true) : dismissWithoutPosting() }
                )
            }

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
        .task { await loadAvatar() }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    thumbnailUIImage = uiImage
                    thumbnailImage = Image(uiImage: uiImage)
                    let availableWidth = UIScreen.main.bounds.width - 28
                    let ratio = uiImage.size.height / uiImage.size.width
                    photoSlideHeight = availableWidth * ratio
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

    private func loadAvatar() async {
        guard let url = Auth.auth().currentUser?.photoURL else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        avatarImage = Image(uiImage: uiImage)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text("‹")
                        .font(.mono(24, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORKOUT COMPLETE")
                        .font(Font.spaceMono(8))
                        .foregroundStyle(Color.inkMuted)
                        .tracking(1.5)
                    Text((data.workoutName ?? "WORKOUT").uppercased())
                        .font(.display(22))
                        .foregroundStyle(Color.inkPrimary)
                        .tracking(0.5)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(shortDateBrief)
                .font(Font.spaceMono(10))
                .foregroundStyle(Color.inkMuted)
                .tracking(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Share Card

    private var shareCard: some View {
        VStack(spacing: 0) {
            TickerStripView(items: tickerItems)
            VStack(spacing: 0) {
                // Name + duration
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shortDate)
                            .font(Font.spaceMono(9))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(1.6)
                        Text((data.workoutName ?? "WORKOUT").uppercased())
                            .font(.display(44))
                            .foregroundStyle(Color.inkPrimary)
                            .tracking(0.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("DURATION")
                            .font(Font.spaceMono(8))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(1.2)
                        Text(data.formattedDuration)
                            .font(.display(26))
                            .foregroundStyle(Color.inkPrimary)
                            .tracking(1)
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 12)

                statsRow.padding(.bottom, 12)
                bodyHeroRow.padding(.bottom, 12)
                exerciseTable

                // Watermark
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.pumpAccent).frame(width: 7, height: 7)
                    Text("PULSE/PUMP")
                        .font(Font.spaceMono(8))
                        .foregroundStyle(Color.inkMuted)
                        .tracking(1.5)
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsHairLine, lineWidth: 1))
    }

    // MARK: Stats Row

    private var volString: String {
        let t = data.exercises.flatMap(\.workingSets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return t >= 1000 ? String(format: "%.1fK", t / 1000) : "\(Int(t))"
    }

    private var statsRow: some View {
        HStack(spacing: 6) {
            KPIBlock(label: "SETS", value: "\(data.totalSets)", alignment: .center)
            KPIBlock(label: "VOLUME", value: volString, alignment: .center)
            KPIBlock(label: "STREAK", value: "\(data.streakCount)D", alignment: .center)
            KPIBlock(label: "PRS", value: "\(data.prCount)", valueColor: .prGold, alignment: .center)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top)    { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: Body + Hero Row

    private var bodyHeroRow: some View {
        HStack(alignment: .center, spacing: 14) {
            BodyHeat(intensities: BodyHeat.Intensities(exercises: data.exercises))
                .frame(width: 69, height: 110)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(data.improvedCount)")
                        .font(Font.spaceMono(42, weight: .bold))
                        .foregroundStyle(Color.signalUp)
                        .lineLimit(1)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("OF \(data.totalExercises)")
                            .font(Font.spaceMono(9))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(0.8)
                        Text("IMPROVED")
                            .font(Font.spaceMono(8))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(0.8)
                    }
                }

                if data.prCount > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")")
                            .font(.display(15))
                            .foregroundStyle(Color.prGold)
                            .tracking(0.5)
                        if let firstPR = data.prDetails.first {
                            HStack(spacing: 5) {
                                Text(firstPR.exerciseName.uppercased())
                                    .font(Font.spaceMono(8))
                                    .foregroundStyle(Color.inkMuted)
                                    .tracking(1.2)
                                    .lineLimit(1)
                                Text(firstPR.isWeightPR
                                     ? "\(String(format: "%g", firstPR.weightDelta))KG"
                                     : "\(firstPR.repsDelta) REP\(firstPR.repsDelta == 1 ? "" : "S")")
                                    .font(Font.spaceMono(8, weight: .bold))
                                    .foregroundStyle(Color.signalUp)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Exercise Table

    private var exerciseTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("EXERCISE").frame(maxWidth: .infinity, alignment: .leading)
                Text("SETS").frame(width: 30, alignment: .center)
                Text("BEST SET").frame(width: 62, alignment: .trailing)
                Text("▲").frame(width: 24, alignment: .trailing)
            }
            .font(Font.spaceMono(7))
            .foregroundStyle(Color.inkMuted)
            .tracking(1.2)
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            let sorted = data.exercises.sorted { $0.improvementScore > $1.improvementScore }
            let rows = Array(sorted.prefix(7).enumerated())
            let prExerciseNames = Set(data.prDetails.map { $0.exerciseName })
            ForEach(rows, id: \.element.id) { i, ex in
                let improved = ex.improvementScore > 0
                let isPR = prExerciseNames.contains(ex.name)
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Text(ex.name.uppercased())
                            .font(.archivo(13, weight: isPR ? .bold : .regular))
                            .tracking(0.3)
                            .foregroundStyle(isPR ? Color.prGold : Color.inkPrimary)
                            .lineLimit(1)
                        if isPR {
                            Text("PR")
                                .font(Font.spaceMono(7, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Color.prGold)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(ex.workingSets.count)")
                        .font(Font.spaceMono(10))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 30, alignment: .center)
                    Text(bestSetText(ex))
                        .font(Font.spaceMono(11, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 62, alignment: .trailing)
                    Text(improved ? "▲" : "—")
                        .font(Font.spaceMono(9, weight: .bold))
                        .foregroundStyle(improved ? Color.signalUp : Color.inkMuted)
                        .frame(width: 24, alignment: .trailing)
                }
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    if i < rows.count - 1 { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                }
            }

            if data.exercises.count > 7 {
                Text("+\(data.exercises.count - 7) MORE")
                    .font(Font.spaceMono(9))
                    .foregroundStyle(Color.inkMuted)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 5)
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func bestSetText(_ ex: FeedExercise) -> String {
        guard let best = ex.workingSets.max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) }) else { return "—" }
        return best.weight > 0 ? "\(String(format: "%g", best.weight))×\(best.reps)" : "\(best.reps)r"
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
                            .clipShape(RoundedRectangle(cornerRadius: 36 * 0.267, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 36 * 0.267, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                    } else {
                        Avatar(initial: avatarInitial, size: 36)
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
            .padding(.top, 12)

            // Tag friends
            SectionLabel(title: "Tag Friends", meta: "Friends Only ›")
                .padding(.top, 20)
                .padding(.bottom, 8)

            FlowLayout(spacing: 8) {
                ForEach(taggedFriends, id: \.uid) { friend in
                    HStack(spacing: 7) {
                        Avatar(initial: friend.displayName, size: 22, showBorder: false)
                        Text(friend.displayName)
                            .font(.archivo(13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
                    .overlay(Capsule().strokeBorder(Color.ruleStrong, lineWidth: 1))
                }

                Button { showTagFriendsSheet = true } label: {
                    HStack(spacing: 6) {
                        Text("+").font(Font.spaceMono(12))
                        Text("ADD").font(Font.spaceMono(9, weight: .bold)).tracking(1.2)
                    }
                    .foregroundStyle(Color.accentInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule().strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color.canvasBg)
    }

    // MARK: - Composer overflow menu (screen 7a)

    private var composerMenu: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.ruleStrong).frame(width: 36, height: 4).padding(.top, 10).padding(.bottom, 10)
            SectionLabel(title: "Session Saved Either Way")
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            composerMenuRow(title: "Don't post", note: "STAYS IN YOUR HISTORY, NOBODY SEES IT") {
                dismissWithoutPosting()
            }
            composerMenuRow(title: "Post without body map", note: "STATS AND PHOTO ONLY") {
                postAndDismiss(includeBodyMap: false)
            }
            Group {
                if autoShare {
                    composerMenuRow(title: "Never post automatically", note: "POSTING BECOMES OPT-IN") {
                        autoShare = false
                        dismissWithoutPosting()
                    }
                } else {
                    composerMenuRow(title: "Post to feed", note: "SHARE THIS SESSION ONCE") {
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

    private func composerMenuRow(title: String, note: String, action: @escaping () -> Void) -> some View {
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
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Helpers

    private var avatarInitial: String {
        String((userName.isEmpty ? "U" : userName).prefix(1)).uppercased()
    }

    /// - Parameter includeBodyMap: false for the overflow's "Post without body map" row —
    ///   posts stats + photo only, `WorkoutFeedItem.includesBodyMap` gates the feed/session
    ///   sheet's body-map slide.
    private func postAndDismiss(includeBodyMap: Bool) {
        // At most one post per workout, and never when the audience is "Only me".
        guard !hasPosted else { return }
        hasPosted = true
        if FeedPostBuilder.audience() != .onlyMe {
            let item = FeedPostBuilder.makeItem(
                data: data,
                userId: Auth.auth().currentUser?.uid ?? "",
                username: Auth.auth().currentUser?.displayName ?? "User",
                caption: caption,
                taggedFriendUids: taggedFriends.map(\.uid),
                includeBodyMap: includeBodyMap
            )
            Task { try? await FirestoreService().shareWorkoutToFeed(item) }
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
