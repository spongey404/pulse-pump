import SwiftUI
import SwiftData

// MARK: - Helpers

private func feedBodyHeatIntensities(item: WorkoutFeedItem) -> BodyHeat.Intensities {
    BodyHeat.Intensities(muscleSets: item.muscleSets)
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
                    .accessibilityIdentifier(AX.social.screen)
                Spacer()
                NavigationLink {
                    ActivityView(viewModel: viewModel)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 32, height: 32)
                        if viewModel.inboxCount > 0 {
                            Circle().fill(Color.pumpAccent).frame(width: 8, height: 8)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Activity")
                .accessibilityIdentifier(AX.social.bell)

                NavigationLink {
                    YourProfileView(viewModel: viewModel)
                } label: {
                    Avatar(initial: viewModel.myName, size: 32, showBorder: false)
                }
                .accessibilityLabel("Your profile")
                .accessibilityIdentifier(AX.social.profile)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 6)

            HStack(spacing: 0) {
                ForEach(["FRIENDS", "CHALLENGES"].indices, id: \.self) { i in
                    let label = ["FRIENDS", "CHALLENGES"][i]
                    let isActive = selectedTab == i
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedTab = i }
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
                    .accessibilityIdentifier(i == 0 ? AX.social.tabFriends : AX.social.tabChallenges)
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
            if viewModel.pendingPost != nil {
                HStack {
                    Text("YOUR LAST SESSION DIDN'T POST")
                        .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkPrimary)
                    Spacer()
                    SocialPill(title: "RETRY", style: .filled) { Task { await viewModel.retryPendingPost() } }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.activeRowBg)
            }

            if viewModel.isLoadingFeed && viewModel.feedItems.isEmpty {
                FeedSkeleton()
            } else if viewModel.feedItems.isEmpty, viewModel.feedError != nil {
                RetryNotice(message: viewModel.feedError ?? "") { Task { await viewModel.loadFeed(forceRefresh: true) } }
            } else if viewModel.feedItems.isEmpty {
                if viewModel.graphLoaded && viewModel.friends.isEmpty {
                    NoFriendsEmptyState(onFindFriends: { showFindFriends = true })
                } else {
                    NoPostsEmptyState()
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, item in
                        FeedPostCard(item: item, viewModel: viewModel)
                            .onAppear {
                                if index >= viewModel.feedItems.count - 3 { Task { await viewModel.loadMoreFeed() } }
                            }
                        if index < viewModel.feedItems.count - 1 {
                            Rectangle().fill(Color.ruleStrong).frame(height: 1)
                        }
                    }
                    if viewModel.isLoadingMoreFeed { SkeletonRows(count: 1, rowHeight: 60) }
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
    @Environment(\.weightUnit) private var unit
    let item: WorkoutFeedItem
    var viewModel: SocialViewModel

    @Environment(\.modelContext) private var modelContext
    @State private var showDetail = false
    @State private var showComments = false
    @State private var menuOpen = false
    @State private var showProfile = false
    @State private var confirmBlock = false
    @State private var confirmDelete = false
    @State private var actionMessage: String?

    private var isMine: Bool { item.userId == viewModel.currentUid }
    private var displayName: String { item.username.isEmpty ? (item.handle.isEmpty ? "Pump user" : item.handle) : item.username }

    var body: some View {
        VStack(spacing: 0) {
            cardHeader

            if item.includesBodyMap {
                mapSlide
                    .frame(height: 330)
                    .clipped()
            }

            statsStrip

            if !item.caption.isEmpty { captionSection }

            if !item.includesBodyMap { fullSessionRow }

            reactRow
        }
        .fullScreenCover(isPresented: $showDetail) {
            FeedSessionSheet(item: item, viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showComments) {
            CommentsView(item: item, viewModel: viewModel)
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                FriendProfileView(uid: item.userId, handle: item.handle, name: displayName, viewModel: viewModel)
            }
        }
        .alert(actionMessage ?? "", isPresented: Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })) {
            Button("OK") {}
        }
        .alert("Block @\(item.handle)?", isPresented: $confirmBlock) {
            Button("Block", role: .destructive) {
                Task {
                    let ok = await viewModel.block(uid: item.userId, name: displayName, handle: item.handle)
                    actionMessage = ok ? "Blocked. You won't see their posts." : nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They disappear from your feed, search and lists, and can't follow you.")
        }
        .alert("Delete this post?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await viewModel.deletePost(item.id) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's removed for everyone. The session stays in your history.")
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
        let byName = Dictionary(library.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

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
        let name = "\(displayName)'s \(item.templateName ?? "Workout")"
        let template = WorkoutTemplate(name: name, templateExercises: templateExercises)
        modelContext.insert(template)
        actionMessage = "Saved \"\(name)\" to your programs."
    }

    private func reportPost() {
        Task {
            let ok = await viewModel.reportPost(item.id)
            if ok { actionMessage = "Reported. This post is hidden for you." }
        }
    }

    private func unfollow() {
        Task {
            let ok = await viewModel.unfollow(item.userId)
            if ok { actionMessage = "Unfollowed \(displayName)." }
        }
    }

    private func toggleSaved() {
        viewModel.toggleSavedPost(postId: item.id)
        let isSaved = viewModel.savedPostIds.contains(item.id)
        actionMessage = isSaved ? "Workout saved." : "Removed from saved."
    }

    // MARK: Header

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { if !isMine { showProfile = true } } label: {
                Avatar(initial: displayName, size: 38)
            }
            .buttonStyle(.plain)

            Button { if !isMine { showProfile = true } } label: {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 0) {
                        Text(displayName)
                            .font(.archivo(14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        if !item.handle.isEmpty {
                            Text("  @\(item.handle)")
                                .font(Font.spaceMono(9))
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                    Text("\((item.templateName ?? "WORKOUT").uppercased()) · \(durationLabel) · \(relativeLabel)")
                        .font(Font.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AX.social.postCard(item.handle))

            Spacer()

            Button { menuOpen.toggle() } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Post options")
            .confirmationDialog("Post options", isPresented: $menuOpen) {
                if isMine {
                    Button("Delete post", role: .destructive) { confirmDelete = true }
                } else {
                    Button("Steal program") { stealProgram() }
                    Button(viewModel.savedPostIds.contains(item.id) ? "Unsave workout" : "Save workout") { toggleSaved() }
                    Button("Report post", role: .destructive) { reportPost() }
                    Button("Block @\(item.handle)", role: .destructive) { confirmBlock = true }
                    if viewModel.relationship(with: item.userId) != .stranger {
                        Button("Unfollow", role: .destructive) { unfollow() }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var durationLabel: String { "\(item.durationSeconds / 60):\(String(format: "%02d", item.durationSeconds % 60))" }
    private var relativeLabel: String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: item.date, relativeTo: Date()).uppercased()
    }

    // MARK: Body-map slide (the only media: photos are not uploaded)

    private var mapSlide: some View {
        ZStack(alignment: .topLeading) {
            Color.surf2
            BodyHeat(intensities: feedBodyHeatIntensities(item: item))
                .frame(width: 183, height: 290)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(MuscleSetsFormat.top(item.muscleSets), id: \.label) { m in
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
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Full session")
    }

    /// Posts without a body map (hidden by the author, or not visible to the viewer) still open the session.
    private var fullSessionRow: some View {
        Button { showDetail = true } label: {
            HStack {
                Text("\(item.exercises.count) EXERCISES")
                    .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                Spacer()
                Text("FULL SESSION ›").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.accentInk)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats strip (4-up)

    private var statsStrip: some View {
        HStack(spacing: 6) {
            KPIBlock(label: "SETS", value: "\(item.workingSetCount)", alignment: .center)
            KPIBlock(label: "VOLUME", value: unit.compactVolume(item.volumeKg), alignment: .center)   // feed weights are kg
            KPIBlock(label: "IMPROVED", value: "\(item.improvedCount)", valueColor: .signalUp, delta: "/\(item.totalExercises)", alignment: .center)
            KPIBlock(label: "PRS", value: "\(item.prCount)", valueColor: .prGold, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Caption

    private var captionSection: some View {
        Text("\(Text(displayName + " ").font(.archivo(13, weight: .bold)))\(Text(item.caption).font(.archivo(13)))")
        .foregroundStyle(Color.inkPrimary)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    // MARK: React row

    private var reactRow: some View {
        HStack(spacing: 22) {
            Button { Task { await viewModel.toggleLike(postId: item.id) } } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.likedByMe ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(item.likedByMe ? Color.pumpAccent : Color.inkMuted)
                    Text("\(item.likeCount)")
                        .font(Font.spaceMono(14, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.likedByMe ? "Unlike" : "Like")

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
            .accessibilityLabel("Comments")

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }
}

// MARK: - Session sheet (post detail; opens from 4a's body-map slide)

struct FeedSessionSheet: View {
    @Environment(\.weightUnit) private var unit
    let item: WorkoutFeedItem
    var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExerciseName: String?
    @State private var showComments = false

    /// The freshest copy (likes and comments update it while the sheet is open).
    private var current: WorkoutFeedItem { viewModel.post(id: item.id, fallback: item) }
    private var displayName: String { item.username.isEmpty ? item.handle : item.username }

    private var tickerItems: [TickerItem] {
        item.exercises.compactMap { ex in
            guard ex.improvementScore > 0 else { return nil }
            return TickerItem(label: ex.name.uppercased(), value: "\(String(format: "%.0f", ex.improvementScore))%", direction: .up)
        }
    }

    /// Exercises sorted PR-first-then-improved, matching the composer's share-card
    /// ordering — the top `item.prCount` by improvement score are treated as PRs (the
    /// post doesn't carry a per-exercise PR flag).
    private var sortedExercises: [(exercise: FeedExercise, isPR: Bool)] {
        let sorted = item.exercises.sorted { $0.improvementScore > $1.improvementScore }
        return sorted.enumerated().map { index, ex in (ex, index < item.prCount) }
    }

    private var durationLabel: String { "\(item.durationSeconds / 60):\(String(format: "%02d", item.durationSeconds % 60))" }

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(item: $selectedExerciseName) { name in
                    LiftHistoryView(exerciseName: name, ownerUid: item.userId, ownerUsername: displayName, viewModel: viewModel)
                }
        }
        .fullScreenCover(isPresented: $showComments) {
            CommentsView(item: current, viewModel: viewModel)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button { dismiss() } label: {
                    Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary)
                        .frame(minWidth: 28, minHeight: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(displayName.uppercased()) · \(item.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated)) · \(durationLabel)")
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
                    HStack(spacing: 18) {
                        if item.includesBodyMap {
                            BodyHeat(intensities: feedBodyHeatIntensities(item: item))
                                .frame(width: 66, height: 106)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 18) {
                            sessionStat(label: "SETS", value: "\(item.workingSetCount)")
                            sessionStat(label: "VOLUME", value: unit.compactVolume(item.volumeKg))   // feed weights are kg
                            sessionStat(label: "IMPROVED", value: "\(item.improvedCount)", valueColor: Color.signalUp, delta: "/\(item.totalExercises)")
                            sessionStat(label: "PRS", value: "\(item.prCount)", valueColor: Color.prGold, glow: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

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
        // Bolted to the bottom of the screen via safeAreaInset so a short session still anchors it low.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 22) {
                    Button { Task { await viewModel.toggleLike(postId: item.id) } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: current.likedByMe ? "heart.fill" : "heart").font(.system(size: 24))
                                .foregroundStyle(current.likedByMe ? Color.pumpAccent : Color.inkMuted)
                            Text("\(current.likeCount)").font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(current.likedByMe ? "Unlike" : "Like")

                    Button { showComments = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left").font(.system(size: 24)).foregroundStyle(Color.inkMuted)
                            Text("\(current.commentCount)").font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Comments")
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

    /// Stats-row cell — Space Mono 7px/1.2 tracking label, Archivo 900 26px value.
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
        // Driven by the same raw kg/rep delta shown in "VS LAST" — not `improvementScore`.
        let improved = exercise.weightDelta > 0 || exercise.repsDelta > 0
        let bestSetIndex = exercise.sets.indices.max(by: { exercise.sets[$0].weight * Double(exercise.sets[$0].reps) < exercise.sets[$1].weight * Double(exercise.sets[$1].reps) })
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
                                .foregroundStyle(Color.inkPrimary.opacity(0.18))
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
        return set.weight > 0 ? "\(unit.number(set.weight))×\(set.reps)" : "\(set.reps)r"
    }

    /// "VS LAST" is a raw weight/rep gain, not a %. `weightDelta` beating last time takes
    /// priority; a rep-only gain at the same weight shows as "+N REPS" instead.
    private func vsLastLabel(for exercise: FeedExercise) -> String {
        if exercise.weightDelta > 0 {
            return "▲ +\(unit.formatTight(exercise.weightDelta))"
        } else if exercise.repsDelta > 0 {
            return "▲ +\(exercise.repsDelta) REP\(exercise.repsDelta == 1 ? "" : "S")"
        }
        return "—"
    }
}

// MARK: - Legacy alias
typealias FeedItemView = FeedPostCard
typealias FeedWorkoutDetailView = FeedSessionSheet
