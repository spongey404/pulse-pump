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
                    .frame(width: 44, height: 44).padding(.vertical, -6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Activity")
                .accessibilityIdentifier(AX.social.bell)

                NavigationLink {
                    YourProfileView(viewModel: viewModel)
                } label: {
                    Avatar(initial: viewModel.myName, size: 32, showBorder: false)
                        .frame(width: 44, height: 44).contentShape(Rectangle()).padding(.vertical, -6)
                }
                .accessibilityLabel("Your profile")
                .accessibilityIdentifier(AX.social.profile)
            }
            .padding(.horizontal, 16)
            .padding(.top, 5)
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
                            .padding(.vertical, 14)
                            .padding(.bottom, 2)
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
            .padding(.bottom, 1)
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

// MARK: - Legacy alias
typealias FeedItemView = FeedPostCard
typealias FeedWorkoutDetailView = FeedSessionSheet
