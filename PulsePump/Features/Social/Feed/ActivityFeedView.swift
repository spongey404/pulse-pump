import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - Helpers

/// Real per-muscle set counts for the feed carousel's body-map overlay (4a) and session
/// sheet — the top 3 muscles by weighted set count (primary sets full credit, secondary
/// half, per `muscleSetCounts()`), not an even split. A Push Day where Bench Press (primary
/// chest, secondary triceps) carries most of the volume now actually shows chest ahead of
/// triceps, matching what the session really trained.
private func feedMuscleSetCounts(item: WorkoutFeedItem) -> [(label: String, count: Int)] {
    let counts = item.exercises.muscleSetCounts()
    return counts.sorted { $0.value > $1.value }
        .prefix(3)
        .map { (abbreviateMuscle($0.key.displayName), Int($0.value.rounded())) }
}

private func abbreviateMuscle(_ name: String) -> String {
    switch name.lowercased() {
    case "shoulders": "SHLDR"
    case "triceps": "TRI"
    case "biceps": "BI"
    case "forearms": "FA"
    case "hamstrings": "HAM"
    default: name.uppercased()
    }
}

private func feedBodyHeatIntensities(item: WorkoutFeedItem) -> BodyHeat.Intensities {
    BodyHeat.Intensities(exercises: item.exercises)
}

/// Row tap affordance for the session view's exercise rows — no chevron (a chevron in a
/// four-column numeric table would either steal width from the name or collide with VS
/// LAST). The tap itself is the only signal, so the press state carries the affordance:
/// background drops to `--accent-row` for 150ms ease-out.
private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.activeRowBg : Color.clear)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Activity Feed View (4a masthead + FRIENDS/CHALLENGES tabs)

struct ActivityFeedView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var selectedTab = 0
    @State private var showFindFriends = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("SOCIAL")
                    .font(.display(28))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                NavigationLink {
                    ActivityView(viewModel: viewModel)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 32, height: 32)
                        if !viewModel.pendingRequests.isEmpty || !viewModel.pendingChallengeInvites.isEmpty {
                            Circle().fill(Color.pumpAccent).frame(width: 8, height: 8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)

                NavigationLink {
                    YourProfileView(viewModel: viewModel)
                } label: {
                    Avatar(initial: "Y", size: 32, showBorder: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                ForEach(["FRIENDS", "CHALLENGES"].indices, id: \.self) { i in
                    let label = ["FRIENDS", "CHALLENGES"][i]
                    let isActive = selectedTab == i
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = i }
                    } label: {
                        Text(label)
                            .font(Font.spaceMono(10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(isActive ? Color.inkPrimary : Color.inkMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(isActive ? Color.pumpAccent : Color.clear).frame(height: 2)
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                Spacer()
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            if selectedTab == 0 {
                feedContent
            } else {
                ChallengesView(viewModel: viewModel)
            }
        }
        .background(Color.canvasBg)
        .sheet(isPresented: $showFindFriends) {
            NavigationStack { FriendsListView(viewModel: viewModel) }
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        ScrollView {
            if viewModel.isLoadingFeed {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
            } else if viewModel.feedItems.isEmpty {
                NoFriendsEmptyState(onFindFriends: { showFindFriends = true })
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, item in
                        FeedPostCard(
                            item: item,
                            currentUid: viewModel.currentUid ?? "",
                            onLike: { Task { await viewModel.toggleLike(postId: item.id) } },
                            viewModel: viewModel
                        )
                        if index < viewModel.feedItems.count - 1 {
                            Rectangle().fill(Color.ruleStrong).frame(height: 1)
                        }
                    }
                }
            }
        }
        .background(Color.canvasBg)
        .refreshable { await viewModel.loadFeed(forceRefresh: true) }
        .task { await viewModel.loadFeed() }
    }
}

// MARK: - Feed Post Card (screen 4a)

struct FeedPostCard: View {
    let item: WorkoutFeedItem
    let currentUid: String
    let onLike: () -> Void
    var viewModel: SocialViewModel?

    @Environment(\.modelContext) private var modelContext
    @State private var showDetail = false
    @State private var showComments = false
    @State private var menuOpen = false
    @State private var carouselSlide = 0
    @State private var showProfile = false
    @State private var actionMessage: String?

    private var isLiked: Bool { item.likes.contains(currentUid) }

    // Slide order: photo (if attached) → body map (if the composer included one). At
    // least one of the two is present in practice; if neither is, the carousel is skipped.
    private enum Slide { case photo, map }
    private var slides: [Slide] {
        var s: [Slide] = []
        if item.photoURL != nil { s.append(.photo) }
        if item.includesBodyMap { s.append(.map) }
        return s
    }

    var body: some View {
        VStack(spacing: 0) {
            cardHeader

            if !slides.isEmpty {
                carouselArea
                if slides.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(slides.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == carouselSlide ? Color.inkPrimary : Color.inkFaint)
                                .frame(width: i == carouselSlide ? 16 : 5, height: 5)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                }
            }

            statsStrip

            if !item.caption.isEmpty { captionSection }

            reactRow
        }
        .fullScreenCover(isPresented: $showDetail) {
            FeedSessionSheet(item: item, viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showComments) {
            CommentsView(item: item)
        }
        .sheet(isPresented: $showProfile) {
            if let viewModel {
                NavigationStack {
                    FriendProfileView(
                        profile: FirestoreUserProfile(uid: item.userId, username: item.username, displayName: item.username),
                        viewModel: viewModel
                    )
                }
            }
        }
        .alert(actionMessage ?? "", isPresented: Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })) {
            Button("OK") {}
        }
    }

    // MARK: Menu actions

    /// Copies this feed post's exercises into a new local `WorkoutTemplate` the user can
    /// start from Programs. Exercises are matched to the local library by name (case-
    /// insensitive) since `FeedExercise` only carries a name, not the library's UUID;
    /// unmatched names are skipped rather than failing the whole import.
    private func stealProgram() {
        let descriptor = FetchDescriptor<Exercise>()
        guard let library = try? modelContext.fetch(descriptor) else {
            actionMessage = "Couldn't access your exercise library."
            return
        }
        let byName = Dictionary(uniqueKeysWithValues: library.map { ($0.name.lowercased(), $0) })

        let templateExercises: [TemplateExercise] = item.exercises.enumerated().compactMap { index, ex in
            guard let match = byName[ex.name.lowercased()] else { return nil }
            return TemplateExercise(
                exerciseId: match.id,
                exerciseName: match.name,
                order: index,
                targetSets: max(ex.sets.count, 1)
            )
        }
        guard !templateExercises.isEmpty else {
            actionMessage = "None of these exercises matched your library."
            return
        }
        let name = "\(item.username)'s \(item.templateName ?? "Workout")"
        let template = WorkoutTemplate(name: name, templateExercises: templateExercises)
        modelContext.insert(template)
        actionMessage = "Saved \"\(name)\" to your programs."
    }

    private func reportPost() {
        Task { await viewModel?.reportPost(postId: item.id) }
        actionMessage = "Post reported."
    }

    private func unfollow() {
        Task { await viewModel?.unfollow(uid: item.userId) }
        actionMessage = "Unfollowed \(item.username)."
    }

    private func toggleSaved() {
        viewModel?.toggleSavedPost(postId: item.id)
        let isSaved = viewModel?.savedPostIds.contains(item.id) ?? false
        actionMessage = isSaved ? "Workout saved." : "Removed from saved."
    }

    // MARK: Header

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { showProfile = true } label: {
                Avatar(initial: item.username, size: 38)
            }
            .buttonStyle(.plain)

            Button { showProfile = true } label: {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 0) {
                        Text(item.username)
                            .font(.archivo(14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("  @\(item.userId.prefix(8).lowercased())")
                            .font(Font.spaceMono(9))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Text("\((item.templateName ?? "WORKOUT").uppercased()) · \(durationLabel) · \(relativeLabel)")
                        .font(Font.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button { menuOpen.toggle() } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PressScaleButtonStyle())
            .confirmationDialog("Post options", isPresented: $menuOpen) {
                Button("Steal program") { stealProgram() }
                Button(viewModel?.savedPostIds.contains(item.id) == true ? "Unsave workout" : "Save workout") { toggleSaved() }
                if let url = URL(string: "https://pulsepump.app/post?id=\(item.id)") {
                    ShareLink("Send to friend", item: url)
                }
                Button("Report post", role: .destructive) { reportPost() }
                Button("Unfollow", role: .destructive) { unfollow() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var durationLabel: String { "\(item.durationSeconds / 60):\(String(format: "%02d", item.durationSeconds % 60))" }
    private var relativeLabel: String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: item.date, relativeTo: Date()).uppercased()
    }

    // MARK: Carousel

    @ViewBuilder
    private var carouselArea: some View {
        ZStack(alignment: .topTrailing) {
            switch slides[carouselSlide] {
            case .photo: photoSlide
            case .map: mapSlide
            }

            if slides.count > 1 {
                Text("\(carouselSlide + 1)/\(slides.count)")
                    .font(Font.spaceMono(8))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#1F1C19").opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 10)
                    .padding(.trailing, 12)
            }
        }
        .frame(height: 330)
        .clipped()
    }

    private var photoSlide: some View {
        Rectangle()
            .fill(Color.surf3)
            .frame(maxWidth: .infinity)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if slides.count > 1 { withAnimation(.easeInOut(duration: 0.2)) { carouselSlide = 1 } }
            }
    }

    private var mapSlide: some View {
        ZStack(alignment: .topLeading) {
            Color.surf2
            BodyHeat(intensities: feedBodyHeatIntensities(item: item))
                .frame(width: 183, height: 290)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(feedMuscleSetCounts(item: item), id: \.label) { m in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(m.label).font(Font.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        Text("\(m.count)").font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    }
                }
            }
            .padding(.leading, 16).padding(.top, 14)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("FULL SESSION").font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.accentInk)
                        Text("›").font(Font.spaceMono(12)).foregroundStyle(Color.accentInk)
                    }
                }
            }
            .padding(.trailing, 16).padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
    }

    // MARK: Stats strip (4-up)

    private var statsStrip: some View {
        HStack(spacing: 6) {
            KPIBlock(label: "SETS", value: "\(item.exercises.reduce(0) { $0 + $1.workingSets.count })", alignment: .center)
            KPIBlock(label: "VOLUME", value: volumeLabel, alignment: .center)
            KPIBlock(label: "IMPROVED", value: "\(item.improvedCount)", valueColor: .signalUp, delta: "/\(item.totalExercises)", alignment: .center)
            KPIBlock(label: "PRS", value: "\(item.prCount)", valueColor: .prGold, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var volumeLabel: String {
        let total = item.exercises.flatMap(\.workingSets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return total >= 1000 ? String(format: "%.1fK", total / 1000) : "\(Int(total))"
    }

    // MARK: Caption

    private var captionSection: some View {
        (
            Text(item.username + " ").font(.archivo(13, weight: .bold))
            + Text(item.caption).font(.archivo(13))
        )
        .foregroundStyle(Color.inkPrimary)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    // MARK: React row

    private var reactRow: some View {
        HStack(spacing: 22) {
            Button(action: onLike) {
                HStack(spacing: 8) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(isLiked ? Color.pumpAccent : Color.inkMuted)
                    Text("\(item.likes.count)")
                        .font(Font.spaceMono(14, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            Button { showComments = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color.inkMuted)
                    Text("\(item.commentCount)")
                        .font(Font.spaceMono(14, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }
}

// MARK: - Session sheet (opens from 4a's body-map slide)

struct FeedSessionSheet: View {
    let item: WorkoutFeedItem
    var viewModel: SocialViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExerciseName: String?

    private var tickerItems: [TickerItem] {
        item.exercises.compactMap { ex in
            guard ex.improvementScore > 0 else { return nil }
            return TickerItem(label: ex.name.uppercased(), value: "\(String(format: "%.0f", ex.improvementScore))%", direction: .up)
        }
    }

    /// Exercises sorted PR-first-then-improved, matching the composer's share-card
    /// ordering — the top `item.prCount` by improvement score are treated as PRs (the
    /// model doesn't carry a per-exercise PR flag, so this is the same heuristic used in
    /// `WorkoutCompletionView`'s share card).
    private var sortedExercises: [(exercise: FeedExercise, isPR: Bool)] {
        let sorted = item.exercises.sorted { $0.improvementScore > $1.improvementScore }
        return sorted.enumerated().map { index, ex in (ex, index < item.prCount) }
    }

    private var durationLabel: String { "\(item.durationSeconds / 60):\(String(format: "%02d", item.durationSeconds % 60))" }

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(item: $selectedExerciseName) { name in
                    if let viewModel {
                        LiftHistoryView(exerciseName: name, ownerUid: item.userId, ownerUsername: item.username, viewModel: viewModel)
                    }
                }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button { dismiss() } label: {
                    Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.username.uppercased()) · \(item.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated)) · \(durationLabel)")
                        .font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    Text((item.templateName ?? "WORKOUT").uppercased())
                        .font(.display(24)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)

            if !tickerItems.isEmpty {
                TickerStripView(items: tickerItems)
                    .padding(.bottom, 14)
            }

            ScrollView {
                VStack(spacing: 0) {
                    if item.includesBodyMap {
                        HStack(spacing: 18) {
                            BodyHeat(intensities: feedBodyHeatIntensities(item: item))
                                .frame(width: 66, height: 106)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 18) {
                                sessionStat(label: "SETS", value: "\(item.exercises.reduce(0) { $0 + $1.workingSets.count })")
                                sessionStat(label: "VOLUME", value: volumeLabel)
                                sessionStat(label: "IMPROVED", value: "\(item.improvedCount)", valueColor: Color.signalUp, delta: "/\(item.totalExercises)")
                                sessionStat(label: "PRS", value: "\(item.prCount)", valueColor: Color.prGold, glow: true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }

                    exerciseTableHeader

                    ForEach(sortedExercises, id: \.exercise.id) { entry in
                        Button { selectedExerciseName = entry.exercise.name } label: {
                            exerciseRow(entry.exercise, isPR: entry.isPR)
                        }
                        .buttonStyle(RowPressStyle())
                    }
                }
            }
        }
        .background(Color.canvasBg)
        // Bolted to the bottom of the screen via safeAreaInset instead of sitting inside the
        // ScrollView's content — previously it just trailed the last exercise row, so a short
        // session left it floating mid-screen with empty space below instead of anchored low.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 22) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart").font(.system(size: 24)).foregroundStyle(Color.inkMuted)
                        Text("\(item.likes.count)").font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    }
                    .frame(minHeight: 44)
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left").font(.system(size: 24)).foregroundStyle(Color.inkMuted)
                        Text("\(item.commentCount)").font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    }
                    .frame(minHeight: 44)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
            .background(Color.canvasBg)
        }
    }

    private var volumeLabel: String {
        let total = item.exercises.flatMap(\.workingSets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return total >= 1000 ? String(format: "%.1fK", total / 1000) : "\(Int(total))"
    }

    /// Stats-row cell — Space Mono 7px/1.2 tracking label, Archivo 900 26px value. Built
    /// bespoke rather than via the shared `KPIBlock` (22px value) since this screen's spec
    /// calls for a larger value than that component renders elsewhere in the app.
    private func sessionStat(label: String, value: String, valueColor: Color = Color.inkPrimary, delta: String? = nil, glow: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Font.spaceMono(7))
                .kerning(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.archivo(26, weight: .black))
                    .lineSpacing(0)
                    .foregroundStyle(valueColor)
                    .shadow(color: glow ? Color.prGold.opacity(0.45) : .clear, radius: 5)
                if let delta {
                    Text(delta)
                        .font(Font.spaceMono(8))
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
    }

    /// `EXERCISE / SET / BEST / VS LAST`, grid `1fr 30px 68px 70px`, gap 6.
    private var exerciseTableHeader: some View {
        HStack(spacing: 6) {
            Text("EXERCISE").frame(maxWidth: .infinity, alignment: .leading)
            Text("SET").frame(width: 30, alignment: .trailing)
            Text("BEST").frame(width: 68, alignment: .trailing)
            Text("VS LAST").frame(width: 70, alignment: .trailing)
        }
        .font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 16)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func exerciseRow(_ exercise: FeedExercise, isPR: Bool) -> some View {
        // Driven by the same raw kg/rep delta shown in "VS LAST" — not `improvementScore`
        // (a % 1RM figure) — so a row only reads as "improved" when there's an actual
        // weight-or-reps gain to show for it.
        let improved = exercise.weightDelta > 0 || exercise.repsDelta > 0
        let bestSetIndex = exercise.sets.indices.max(by: { exercise.sets[$0].weight * Double(exercise.sets[$0].reps) < exercise.sets[$1].weight * Double(exercise.sets[$1].reps) })
        // Gold if PR, ink if improved (no PR), muted if neither. Bold is reserved for rows
        // that actually moved (PR or improved) — a flat row (no change) stays regular weight
        // and muted, matching the mockup where only "went up" rows read as emphasized.
        let emphasized = isPR || improved
        let nameColor: Color = isPR ? Color.prGold : (improved ? Color.inkPrimary : Color.inkMuted)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                HStack(spacing: 6) {
                    Text(exercise.name.uppercased())
                        .font(.archivo(14, weight: emphasized ? .bold : .regular))
                        .tracking(0.2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(nameColor)
                    if isPR {
                        Text("PR")
                            .font(Font.spaceMono(8, weight: .bold)).tracking(1.2)
                            .foregroundStyle(Color.prGold)
                            .shadow(color: Color.prGold.opacity(0.5), radius: 4)
                            .fixedSize()
                            .layoutPriority(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(exercise.sets.count)")
                    .font(Font.spaceMono(13))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 30, alignment: .trailing)

                Text(bestSetIndex.map { setValueLabel(exercise.sets[$0]) } ?? "—")
                    .font(Font.spaceMono(14, weight: emphasized ? .bold : .regular))
                    .foregroundStyle(nameColor)
                    .frame(width: 68, alignment: .trailing)

                Text(vsLastLabel(for: exercise))
                    .font(Font.spaceMono(11, weight: .bold))
                    .foregroundStyle(improved ? Color.signalUp : Color.inkMuted)
                    .frame(width: 70, alignment: .trailing)
            }

            // Row 2 — every set typed by what it was. Exactly one (the exercise's BEST) takes
            // emphasis; the rest recede. Trailing separator after the last set is suppressed.
            FlowLayout(spacing: 0) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { i, set in
                    HStack(spacing: 0) {
                        Text(setValueLabel(set))
                            .font(Font.spaceMono(12, weight: (i == bestSetIndex && emphasized) ? .bold : .regular))
                            .foregroundStyle(setColor(isBest: i == bestSetIndex, isPR: isPR, emphasized: emphasized))
                            .shadow(color: (i == bestSetIndex && isPR && emphasized) ? Color.prGold.opacity(0.5) : .clear, radius: 4)
                        if i != exercise.sets.count - 1 {
                            Text("·")
                                .font(Font.spaceMono(12))
                                .foregroundStyle(Color.inkPrimary.opacity(0.18))  // --text-ghost
                                .padding(.horizontal, 6)
                        }
                    }
                }
            }
            .padding(.top, 7)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func setColor(isBest: Bool, isPR: Bool, emphasized: Bool) -> Color {
        guard isBest && emphasized else { return Color.inkMuted }
        return isPR ? Color.prGold : Color.inkPrimary
    }

    private func setValueLabel(_ set: FeedSetLog) -> String {
        if set.duration > 0 { return "\(set.duration)s" }
        if set.distance > 0 { return String(format: "%.0fm", set.distance) }
        return set.weight > 0 ? "\(String(format: "%g", set.weight))×\(set.reps)" : "\(set.reps)r"
    }

    /// "VS LAST" is a raw weight/rep gain, not a %. `weightDelta` beating last time takes
    /// priority; a rep-only gain at the same weight shows as "+N REPS" instead.
    private func vsLastLabel(for exercise: FeedExercise) -> String {
        if exercise.weightDelta > 0 {
            return "▲ +\(String(format: "%g", exercise.weightDelta))KG"
        } else if exercise.repsDelta > 0 {
            return "▲ +\(exercise.repsDelta) REP\(exercise.repsDelta == 1 ? "" : "S")"
        }
        return "—"
    }
}

// MARK: - Legacy alias
typealias FeedItemView = FeedPostCard
typealias FeedWorkoutDetailView = FeedSessionSheet
