import SwiftUI

/// 3d — global monthly leaderboard, GLOBAL/FRIENDS filter, your row pinned above the tab bar.
struct GlobalLeaderboardView: View {
    let challenge: FirestoreChallenge
    @Environment(\.weightUnit) private var weightUnit
    private var metric: ChallengeMetric { ChallengeMetric(rawValue: challenge.metric) ?? .totalVolume }
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFriendsOnly = false

    private var friendUids: Set<String> { Set(viewModel.friends.map(\.uid) + [viewModel.currentUid].compactMap { $0 }) }
    private var board: [LeaderboardEntry] {
        let sorted = challenge.leaderboard.sorted { $0.rank < $1.rank }
        return showFriendsOnly ? sorted.filter { friendUids.contains($0.userId) } : sorted
    }
    private var myEntry: LeaderboardEntry? { board.first { $0.userId == viewModel.currentUid } }

    /// Top 5, then the neighbourhood around the current user's rank — matches spec's
    /// "top 5, then · · ·, then ranks around the user" pattern. `ellipsisBefore` marks
    /// where a rank gap should render as `· · ·`.
    private var visibleRows: [(entry: LeaderboardEntry, ellipsisBefore: Bool)] {
        let rows: [LeaderboardEntry]
        if board.count > 8, let mine = myEntry {
            let top5 = Array(board.prefix(5))
            // Excludes the current user's own entry — it's already shown in the pinned row
            // below, so including it here would render "You" twice, stacked on top of
            // each other at the bottom of the list.
            let neighborhood = board.filter { entry in
                let isNearby = abs(entry.rank - mine.rank) <= 2
                let isBelowTop5 = entry.rank > 5
                let isSomeoneElse = entry.userId != mine.userId
                return isNearby && isBelowTop5 && isSomeoneElse
            }
            rows = top5 + neighborhood
        } else {
            rows = board
        }
        var lastRank = 0
        return rows.map { entry in
            let gap = lastRank != 0 && entry.rank - lastRank > 1
            lastRank = entry.rank
            return (entry, gap)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                Text(challenge.name.uppercased()).font(.archivo(22, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            HStack(spacing: 8) {
                FilterChip(title: "Global", isSelected: !showFriendsOnly) { showFriendsOnly = false }
                FilterChip(title: "Friends", isSelected: showFriendsOnly) { showFriendsOnly = true }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 0) {
                    boardHeader
                    ForEach(visibleRows, id: \.entry.id) { row in
                        if row.ellipsisBefore {
                            Text("· · ·").font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        boardRow(row.entry)
                    }
                }
                .padding(.horizontal, 16)
                Color.clear.frame(height: 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            if let mine = myEntry {
                pinnedRow(mine)
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

    private func boardRow(_ entry: LeaderboardEntry) -> some View {
        let (fg, glow) = medalColor(for: entry.rank)
        return HStack(spacing: 10) {
            Text("\(entry.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(width: 22, alignment: .leading)
            Avatar(initial: entry.username, size: 32)
            Text(entry.username).font(.archivo(16, weight: entry.rank <= 3 ? .bold : .regular)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metric.formatScore(entry.score, weightUnit)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 76, alignment: .trailing)
            Color.clear.frame(width: 40)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func pinnedRow(_ entry: LeaderboardEntry) -> some View {
        let above = board.last { $0.rank < entry.rank }
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Text("\(entry.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    .frame(width: 22, alignment: .leading)
                Avatar(initial: entry.username, size: 32, showBorder: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.username).font(.archivo(16, weight: .bold)).foregroundStyle(Color.accentInk)
                    if let above {
                        Text("\(metric.formatScore(above.score - entry.score, weightUnit)) TO \(above.rank)\(ordinalSuffix(above.rank))")
                            .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    }
                }
                Spacer()
                Text(metric.formatScore(entry.score, weightUnit)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        // `activeRowBg` is a translucent tint (8–14% alpha) meant to sit over an opaque
        // surface. This row lives in a `.safeAreaInset`, which lays out outside the screen's
        // own `.background(Color.canvasBg)` — without an opaque layer of its own here first,
        // the tint alone let whatever's behind the app bleed through.
        .background(Color.canvasBg)
        .background(Color.activeRowBg)
        .overlay(alignment: .leading) { Rectangle().fill(Color.pumpAccent).frame(width: 2) }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func ordinalSuffix(_ n: Int) -> String {
        switch (n % 100, n % 10) {
        case (11, _), (12, _), (13, _): "TH"
        case (_, 1): "ST"
        case (_, 2): "ND"
        case (_, 3): "RD"
        default: "TH"
        }
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
