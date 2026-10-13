import SwiftUI

/// 3d — global leaderboard, GLOBAL/FRIENDS filter, your row pinned above the tab bar. People who hid
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

    private var visibleRows: [(row: LeaderboardRow, gapBefore: Bool)] {
        // The pinned row already shows me, so the list leaves me out.
        let others = rows.filter { !$0.isMe }
        return showFriendsOnly ? others.map { ($0, false) } : Leaderboard.condensed(rows: others, mine: mine)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SocialScreenHeader(title: challenge.name.uppercased(), onBack: { dismiss() })

            HStack(spacing: 8) {
                FilterChip(title: "Global", isSelected: !showFriendsOnly) { showFriendsOnly = false }
                FilterChip(title: "Friends", isSelected: showFriendsOnly) { showFriendsOnly = true }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 0) {
                    boardHeader
                    if board == nil {
                        SkeletonRows(count: 5)
                    } else if rows.isEmpty {
                        Text(showFriendsOnly ? "NONE OF YOUR FRIENDS ARE ON THIS BOARD YET" : "NO ONE IS ON THE BOARD YET")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
                    }
                    ForEach(visibleRows, id: \.row.id) { item in
                        if item.gapBefore {
                            Text("· · ·").font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        boardRow(item.row)
                    }
                    if !viewModel.privacy.globalLeaderboardVisible, mine != nil {
                        Text("YOU'RE HIDDEN FROM OTHERS ON THIS BOARD · CHANGE IT IN ACTIVITY › PRIVACY")
                            .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(.top, 14)
                    }
                }
                .padding(.horizontal, 16)
                Color.clear.frame(height: 24)
            }
            .refreshable { await viewModel.loadBoard(challenge) }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadGraph()
            await viewModel.loadBoard(challenge)
        }
        .safeAreaInset(edge: .bottom) {
            if let mine {
                pinnedRow(mine)
            } else if board != nil, !(board?.isMember ?? false) {
                DockedCTA(leadingText: "YOU'RE NOT ON THIS BOARD", primaryLabel: "JOIN ›", style: .quiet) {
                    Task { await viewModel.join(challenge) }
                }
            }
        }
    }

    private var boardHeader: some View {
        HStack(spacing: 10) {
            Text("#").frame(width: 22, alignment: .leading)
            Color.clear.frame(width: 32)
            Text("ATHLETE").frame(maxWidth: .infinity, alignment: .leading)
            Text("SCORE").frame(width: 76, alignment: .trailing)
            Color.clear.frame(width: 40)
        }
        .font(Font.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func boardRow(_ row: LeaderboardRow) -> some View {
        let (fg, glow) = medalColor(for: row.rank)
        let name = row.entry.username.isEmpty ? "Pump user" : row.entry.username
        return HStack(spacing: 10) {
            Text("\(row.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(width: 22, alignment: .leading)
            Avatar(initial: name, size: 32)
            Text(name).font(.archivo(16, weight: row.rank <= 3 ? .bold : .regular)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metric.formatScore(row.entry.score, weightUnit)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 76, alignment: .trailing)
            Color.clear.frame(width: 40)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private func pinnedRow(_ row: LeaderboardRow) -> some View {
        let above = allRows.last { $0.rank < row.rank }
        return HStack(spacing: 10) {
            Text("\(row.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 22, alignment: .leading)
            Avatar(initial: row.entry.username.isEmpty ? "You" : row.entry.username, size: 32, showBorder: false)
            VStack(alignment: .leading, spacing: 1) {
                Text("You").font(.archivo(16, weight: .bold)).foregroundStyle(Color.accentInk)
                if let above {
                    Text("\(metric.formatScore(max(0, above.entry.score - row.entry.score), weightUnit)) TO \(Leaderboard.ordinal(above.rank))")
                        .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            Text(metric.formatScore(row.entry.score, weightUnit)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        // `activeRowBg` is a translucent tint meant to sit over an opaque surface; this row lives in a
        // safeAreaInset outside the screen background, so it brings its own opaque layer first.
        .background(Color.canvasBg)
        .background(Color.activeRowBg)
        .overlay(alignment: .leading) { Rectangle().fill(Color.pumpAccent).frame(width: 2) }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func medalColor(for rank: Int) -> (Color, Color) {
        switch rank {
        case 1: (Color.medalGold, Color.medalGold.opacity(0.45))
        case 2: (Color.medalSteel, .clear)
        case 3: (Color.medalBronze, .clear)
        default: (Color.inkMuted, .clear)
        }
    }
}
