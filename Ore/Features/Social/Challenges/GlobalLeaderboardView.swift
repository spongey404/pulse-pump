import SwiftUI

/// 4a — global leaderboard: podium, rows, activity, GLOBAL/FRIENDS filter, your place pinned at the bottom. People who hid
/// themselves from global boards (privacy) are not in the data at all; if you hid yourself you see a note.
struct GlobalLeaderboardView: View {
    let challenge: SocialChallenge
    @Environment(\.weightUnit) private var weightUnit
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFriendsOnly = false

    private var metric: ChallengeMetric { challenge.metric }
    private var board: ChallengeBoard? { viewModel.boards[challenge.id] }
    private var allRows: [LeaderboardRow] { board?.rows ?? [] }
    private var mine: LeaderboardRow? { board?.mine }

    /// The FRIENDS filter keeps global ranks, it just hides everyone who isn't a friend.
    private var rows: [LeaderboardRow] {
        guard showFriendsOnly else { return allRows }
        let friends = viewModel.graph.friends
        return allRows.filter { $0.isMe || friends.contains($0.entry.uid) }
    }

    /// Below the podium. The pinned card already shows me, so the list leaves me out.
    private var visibleRows: [(row: LeaderboardRow, gapBefore: Bool)] {
        let others = Array(rows.dropFirst(3)).filter { !$0.isMe }
        return showFriendsOnly ? others.map { ($0, false) } : Leaderboard.condensed(rows: others, mine: mine)
    }

    private var label: String {
        var parts = ["Global", metric.displayName]
        parts.append(challengeTimeLeft(challenge))
        return parts.joined(separator: " · ").uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChallengeHeader(label: label, title: challenge.name.uppercased(), onBack: { dismiss() })

            HStack(spacing: 8) {
                FilterChip(title: "Global", isSelected: !showFriendsOnly) { showFriendsOnly = false }
                FilterChip(title: "Friends", isSelected: showFriendsOnly) { showFriendsOnly = true }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 0) {
                    if board == nil {
                        SkeletonRows(count: 5).padding(.horizontal, 16).padding(.top, 14)
                    } else if rows.isEmpty {
                        Text(showFriendsOnly ? "NONE OF YOUR FRIENDS ARE ON THIS BOARD YET" : "NO ONE IS ON THE BOARD YET")
                            .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    } else {
                        ChallengePodium(rows: rows, metric: metric, weightUnit: weightUnit)
                        ForEach(visibleRows, id: \.row.id) { item in
                            if item.gapBefore {
                                Text("· · ·").font(.spaceMono(12)).foregroundStyle(Color.inkMuted)
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            ChallengeBoardRow(row: item.row) {
                                ScoreText(value: metric.formatScore(item.row.entry.score, weightUnit), suffix: metric.scoreSuffix(weightUnit), size: 15)
                            }
                        }
                        ChallengeActivityList(rows: rows, metric: metric, weightUnit: weightUnit)
                    }
                    if !viewModel.privacy.globalLeaderboardVisible, mine != nil {
                        Text("YOU'RE HIDDEN FROM OTHERS ON THIS BOARD · CHANGE IT IN ACTIVITY › PRIVACY")
                            .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    }
                }
                Color.clear.frame(height: 16)
            }
            .refreshable { await viewModel.loadBoard(challenge) }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadGraph()
            await viewModel.loadBoard(challenge)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let mine {
                ChallengePinnedYou(mine: mine, rows: allRows, metric: metric, weightUnit: weightUnit)
            } else if board != nil, !(board?.isMember ?? false) {
                SocialDock {
                    SocialCTA(title: "JOIN", info: "YOU'RE NOT ON THIS BOARD") { Task { await viewModel.join(challenge) } }
                }
            }
        }
    }
}
