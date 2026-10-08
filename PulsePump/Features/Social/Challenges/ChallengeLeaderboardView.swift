import SwiftUI

/// 3c — friend challenge leaderboard.
struct ChallengeLeaderboardView: View {
    let challenge: FirestoreChallenge
    @Environment(\.weightUnit) private var weightUnit
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showInvite = false

    private var board: [LeaderboardEntry] { challenge.leaderboard.sorted { $0.rank < $1.rank } }
    private var myEntry: LeaderboardEntry? { board.first { $0.userId == viewModel.currentUid } }
    private var metric: ChallengeMetric { ChallengeMetric(rawValue: challenge.metric) ?? .totalVolume }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                Text(challenge.name.uppercased()).font(.archivo(22, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            HStack {
                Text("\(metric.displayName.uppercased()) · \(challenge.participantIds.count) FRIENDS")
                    .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                Spacer()
                Button { showInvite = true } label: {
                    Text("+ INVITE").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.accentInk)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.top, 12)

            HStack(spacing: 0) {
                KPIBlock(label: "Your Count", value: myEntry.map { metric.formatScore($0.score, weightUnit) } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                KPIBlock(label: "Position", value: myEntry.map { "\($0.rank)" } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                KPIBlock(label: "Ends", value: challenge.endDate.formatted(.dateTime.day().month(.abbreviated)), alignment: .center).frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14).padding(.top, 6)

            ScrollView {
                VStack(spacing: 0) {
                    boardHeader
                    ForEach(Array(board.enumerated()), id: \.element.id) { _, entry in
                        boardRow(entry)
                    }
                }
                .padding(.horizontal, 16)
                Color.clear.frame(height: 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showInvite) {
            InviteFriendsView(
                viewModel: viewModel,
                challengeId: challenge.id,
                challengeName: challenge.name,
                metricLabel: metric.displayName,
                windowLabel: "Ends \(challenge.endDate.formatted(.dateTime.day().month(.abbreviated)))"
            )
        }
    }

    private var boardHeader: some View {
        HStack(spacing: 10) {
            Text("#").frame(width: 22, alignment: .leading)
            Color.clear.frame(width: 32)
            Text("ATHLETE").frame(maxWidth: .infinity, alignment: .leading)
            Text("COUNT").frame(width: 54, alignment: .trailing)
            Text("MOVE").frame(width: 44, alignment: .trailing)
        }
        .font(Font.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func boardRow(_ entry: LeaderboardEntry) -> some View {
        let isMe = entry.userId == viewModel.currentUid
        // "You" always renders in accent blue, even on a non-medal or silver/bronze rank —
        // both so it never washes out against the highlighted row background, and so it
        // reads as visibly different from every other row at a glance.
        let (fg, glow): (Color, Color) = isMe ? (Color.accentInk, .clear) : medalColor(for: entry.rank)
        let move = entry.previousRank == 0 ? 0 : entry.previousRank - entry.rank

        return HStack(spacing: 10) {
            Text("\(entry.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(width: 22, alignment: .leading)
            Avatar(initial: entry.username, size: 32)
            Text(entry.username).font(.archivo(16, weight: entry.rank <= 3 || isMe ? .bold : .regular)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metric.formatScore(entry.score, weightUnit)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 54, alignment: .trailing)
            moveLabel(move).frame(width: 44, alignment: .trailing)
        }
        .frame(minHeight: 56)
        // No extra horizontal padding on the "You" row's content — it previously got +8pt
        // that the other rows (and the ATHLETE/COUNT/MOVE header) didn't, which shifted its
        // rank number out of line with every column above and below it.
        .background(isMe ? Color.activeRowBg : Color.clear)
        .overlay(alignment: .leading) {
            if isMe {
                // Bar sits in the list's outer 16pt margin (like the pinned row in
                // GlobalLeaderboardView), not glued to the rank digit — flush-left inside
                // the row would draw the bar directly through the "2" glyph.
                Rectangle().fill(Color.pumpAccent).frame(width: 2).offset(x: -16)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func moveLabel(_ move: Int) -> some View {
        Group {
            if move > 0 {
                Text("▲ \(move)").foregroundStyle(Color.signalUp)
            } else if move < 0 {
                Text("▼ \(-move)").foregroundStyle(Color.signalDown)
            } else {
                Text("—").foregroundStyle(Color.inkMuted)
            }
        }
        .font(Font.spaceMono(9, weight: .bold))
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
