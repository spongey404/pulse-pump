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
                            Circle().fill(Color.oreAccent).frame(width: 8, height: 8)
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
            .padding(.top, 6)
            .padding(.bottom, 10)

            HStack(spacing: 20) {
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
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(isActive ? Color.oreAccent : Color.clear).frame(height: 2)
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier(i == 0 ? AX.social.tabFriends : AX.social.tabChallenges)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

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
                LazyVStack(spacing: 14) {
                    ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, item in
                        FeedPostCard(item: item, viewModel: viewModel)
                            .onAppear {
                                if index >= viewModel.feedItems.count - 3 { Task { await viewModel.loadMoreFeed() } }
                            }
                    }
                    if viewModel.isLoadingMoreFeed { SkeletonRows(count: 1, rowHeight: 60) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 14)
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
    private var displayName: String { item.username.isEmpty ? (item.handle.isEmpty ? Brand.defaultUserName : item.handle) : item.username }

    private var member: SocialMemberStyle? { SocialMembership.style(for: item.userId, currentUid: viewModel.currentUid) }

    var body: some View {
        VStack(spacing: 0) {
            hero
            statsStrip
            if !item.caption.isEmpty { captionSection }
            reactRow
        }
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var durationLabel: String { "\(item.durationSeconds / 60):\(String(format: "%02d", item.durationSeconds % 60))" }
    private var relativeLabel: String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: item.date, relativeTo: Date()).uppercased()
    }

    // MARK: Hero (body map + who, what, PRs)

    private var hero: some View {
        let tall = item.prCount > 0
        return ZStack(alignment: tall ? .topLeading : .leading) {
            Color.surf2
            if item.includesBodyMap {
                SocialBodyMap(muscleSets: item.muscleSets, style: member,
                              width: tall ? 150 : 100, height: tall ? 240 : 160)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 22)
            }
            heroText(tall: tall)
                .padding(tall ? 16 : 0)
                .padding(.leading, tall ? 0 : 16)
                .frame(maxWidth: tall ? 170 : .infinity, alignment: .leading)
        }
        .frame(height: tall ? 280 : 180)
        .overlay(alignment: .topTrailing) { postMenu }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Full session")
    }

    private func heroText(tall: Bool) -> some View {
        VStack(alignment: .leading, spacing: tall ? 6 : 4) {
            Button { if !isMine { showProfile = true } } label: {
                HStack(spacing: 10) {
                    Group {
                        if let member {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: member.palette.accent.hex))
                                Text(displayName.prefix(1).uppercased()).font(.archivo(14, weight: .black)).foregroundStyle(.white)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.surf)
                                Text(displayName.prefix(1).uppercased()).font(.archivo(14, weight: .black)).foregroundStyle(Color.inkSecondary)
                            }
                        }
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(displayName).font(.archivo(15, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        if member != nil { SupernovaTag() }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AX.social.postCard(item.handle))

            Text((item.templateName ?? "WORKOUT").uppercased())
                .font(.archivo(30, weight: .black))
                .foregroundStyle(Color.inkPrimary)
                .cssLineHeight(fontName: "Archivo-Black", size: 30, multiple: 0.95)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, tall ? 8 : 4)

            Text("\(durationLabel) · \(relativeLabel)")
                .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)

            if item.prCount > 0 {
                HStack(spacing: 6) {
                    PRStar(size: 12)
                    Text("\(item.prCount) NEW PR\(item.prCount == 1 ? "" : "S")")
                        .font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.surf, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 4)
            }
        }
    }

    private var postMenu: some View {
        Button { menuOpen.toggle() } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
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

    // MARK: Stats (3-up, 18 pt)

    private var statsStrip: some View {
        HStack(alignment: .top, spacing: 8) {
            feedStat("SETS", "\(item.workingSetCount)")
            feedStat("VOLUME", unit.compactVolume(item.volumeKg))   // feed weights are kg
            feedStat("IMPROVED", "\(item.improvedCount)", color: .signalUp, suffix: "/\(item.totalExercises)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func feedStat(_ label: String, _ value: String, color: Color = .inkPrimary, suffix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(value).font(.spaceMono(18, weight: .bold)).foregroundStyle(color)
                if let suffix { Text(suffix).font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkMuted) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Caption

    private var captionSection: some View {
        Text(item.caption)
            .font(.archivo(14))
            .foregroundStyle(Color.inkPrimary)
            .cssLineHeight(fontName: "Archivo-Regular", size: 14, multiple: 1.45)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }

    // MARK: React row (bare 24 pt icons + Space Mono 14 bold counts)

    private var reactRow: some View {
        SocialReactRow(liked: item.likedByMe, likeCount: item.likeCount, commentCount: item.commentCount,
                       onLike: { Task { await viewModel.toggleLike(postId: item.id) } },
                       onComment: { showComments = true })
    }
}

/// Like and comment: a bare 24 pt stroked icon with its Space Mono bold 14 count, no outline. Shared by the feed card and the session.
struct SocialReactRow: View {
    let liked: Bool
    let likeCount: Int
    let commentCount: Int
    let onLike: () -> Void
    let onComment: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            Button(action: onLike) {
                HStack(spacing: 8) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(liked ? Color.oreAccent : Color.inkMuted)
                    Text("\(likeCount)").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(liked ? "Unlike" : "Like")

            Button(action: onComment) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                    Text("\(commentCount)").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comments")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
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

    private var member: SocialMemberStyle? { SocialMembership.style(for: item.userId, currentUid: viewModel.currentUid) }

    private var content: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(displayName.uppercased()) · \(item.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased()) · \(durationLabel)")
                        .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    Text((item.templateName ?? "WORKOUT").uppercased())
                        .font(.archivo(26, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier(AX.nav.back)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 18) {
                        if item.includesBodyMap {
                            SocialBodyMap(muscleSets: item.muscleSets, style: member, width: 75, height: 120)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                            sessionStat(label: "SETS", value: "\(item.workingSetCount)")
                            sessionStat(label: "VOLUME", value: unit.compactVolume(item.volumeKg))   // feed weights are kg
                            sessionStat(label: "IMPROVED", value: "\(item.improvedCount)", valueColor: Color.signalUp, delta: "/\(item.totalExercises)")
                            sessionStat(label: "PRS", value: "\(item.prCount)", valueColor: Color.prGold, star: item.prCount > 0)
                        }
                    }
                    .padding(16)

                    HStack {
                        Text("EXERCISES")
                        Spacer()
                        Text("BEST · VS LAST")
                    }
                    .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(sortedExercises.enumerated()), id: \.element.exercise.id) { index, entry in
                            Button { selectedExerciseName = entry.exercise.name } label: {
                                exerciseRow(entry.exercise, isPR: entry.isPR, starDelay: -0.5 * Double(index))
                            }
                            .buttonStyle(RowPressStyle())
                        }
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    SocialReactRow(liked: current.likedByMe, likeCount: current.likeCount, commentCount: current.commentCount,
                                   onLike: { Task { await viewModel.toggleLike(postId: item.id) } },
                                   onComment: { showComments = true })
                        .padding(.bottom, 22)
                }
            }
        }
        .background(Color.canvasBg)
    }

    /// Stats cell: Space Mono 8 label, Space Mono bold 22 value (a gold star before the PRs).
    private func sessionStat(label: String, value: String, valueColor: Color = Color.inkPrimary, delta: String? = nil, star: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            HStack(spacing: 5) {
                if star { PRStar(size: 14) }
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(value).font(.spaceMono(22, weight: .bold)).foregroundStyle(valueColor)
                    if let delta { Text(delta).font(.spaceMono(22, weight: .bold)).foregroundStyle(Color.inkMuted) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A settings-style row: name (16 bold) with its sets line under it, the best set and vs-last on the right; a gold star on PRs.
    private func exerciseRow(_ exercise: FeedExercise, isPR: Bool, starDelay: Double) -> some View {
        let improved = exercise.weightDelta > 0 || exercise.repsDelta > 0
        let bestSetIndex = exercise.sets.indices.max(by: { exercise.sets[$0].weight * Double(exercise.sets[$0].reps) < exercise.sets[$1].weight * Double(exercise.sets[$1].reps) })
        let vsLast = vsLastLabel(for: exercise)

        return HStack(alignment: .center, spacing: 10) {
            if isPR { PRStar(size: 13, delay: starDelay).frame(width: 14) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(exercise.name)
                        .font(.archivo(16, weight: .bold))
                        .foregroundStyle(improved || isPR ? Color.inkPrimary : Color.inkMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(bestSetIndex.map { setValueLabel(exercise.sets[$0]) } ?? "—")
                        .font(.spaceMono(14, weight: .bold))
                        .foregroundStyle(isPR ? Color.prGold : Color.inkPrimary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(exercise.sets.map(setValueLabel).joined(separator: " · "))
                        .font(.spaceMono(10)).tracking(0.6).foregroundStyle(Color.inkMuted)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(vsLast)
                        .font(.spaceMono(9, weight: .bold)).tracking(0.8)
                        .foregroundStyle(improved ? Color.signalUp : Color.inkGhost)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .contentShape(Rectangle())
    }

    private func setValueLabel(_ set: FeedSetLog) -> String {
        if set.duration > 0 { return "\(set.duration)s" }
        if set.distance > 0 { return String(format: "%.0fm", set.distance) }
        return set.weight > 0 ? "\(unit.number(set.weight))×\(set.reps)" : "\(set.reps)r"
    }

    /// "VS LAST" is a raw weight/rep gain, not a %. A weight gain shows "▲ +5KG"; a rep-only gain at the same weight "▲ +2 REPS".
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
