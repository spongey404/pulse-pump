import SwiftUI

/// 3c — friend challenge leaderboard. Rows, ranks and movement come from the entries the Cloud
/// Functions maintain (equal scores share a rank); nothing is scored on the device.
struct ChallengeLeaderboardView: View {
    let challenge: SocialChallenge
    @Environment(\.weightUnit) private var weightUnit
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showInvite = false
    @State private var menuOpen = false
    @State private var confirmLeave = false

    private var board: ChallengeBoard? { viewModel.boards[challenge.id] }
    private var rows: [LeaderboardRow] { board?.rows ?? [] }
    private var mine: LeaderboardRow? { board?.mine }
    private var metric: ChallengeMetric { challenge.metric }
    private var isCreator: Bool { challenge.creatorUid == viewModel.currentUid }
    private var canInvite: Bool { challenge.isActive() && (isCreator || (board?.isMember ?? false)) }

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: challenge.name.uppercased(), onBack: { dismiss() }) {
                Button { menuOpen = true } label: {
                    Image(systemName: "ellipsis").font(.system(size: 18)).foregroundStyle(Color.inkMuted).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Challenge options")
            }

            HStack {
                Text("\(metric.displayName.uppercased())\(challenge.exerciseName.map { " · " + $0.uppercased() } ?? "") · \(challenge.memberCount) \(challenge.memberCount == 1 ? "PERSON" : "PEOPLE")")
                    .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).lineLimit(1)
                Spacer()
                if canInvite {
                    Button { showInvite = true } label: {
                        Text("+ INVITE").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.accentInk)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.top, 4)

            HStack(spacing: 0) {
                KPIBlock(label: "Your Count", value: mine.map { metric.formatScore($0.entry.score, weightUnit) } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                KPIBlock(label: "Position", value: mine.map { "\($0.rank)" } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                KPIBlock(label: "Ends", value: challenge.endAt.formatted(.dateTime.day().month(.abbreviated)), alignment: .center).frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14).padding(.top, 6)

            ScrollView {
                VStack(spacing: 0) {
                    boardHeader
                    if board == nil {
                        SkeletonRows(count: 4)
                    } else if rows.isEmpty {
                        Text("NO ONE IS ON THE BOARD YET · SCORES UPDATE AS WORKOUTS ARE LOGGED")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
                    }
                    ForEach(rows) { row in
                        boardRow(row)
                    }
                }
                .padding(.horizontal, 16)
                Color.clear.frame(height: 24)
            }
            .refreshable { await viewModel.loadBoard(challenge) }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadBoard(challenge) }
        .navigationDestination(isPresented: $showInvite) {
            InviteFriendsView(viewModel: viewModel, challenge: challenge)
        }
        .confirmationDialog("Challenge options", isPresented: $menuOpen) {
            if !isCreator && (board?.isMember ?? false) {
                Button("Leave challenge", role: .destructive) { confirmLeave = true }
            }
            Button("Report challenge", role: .destructive) { Task { await viewModel.reportChallenge(challenge.id) } }
        }
        .alert("Leave \(challenge.name)?", isPresented: $confirmLeave) {
            Button("Leave", role: .destructive) { Task { if await viewModel.leave(challenge) { dismiss() } } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll come off the board and your score is removed.")
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

    private func boardRow(_ row: LeaderboardRow) -> some View {
        let entry = row.entry
        // "You" always renders in accent blue so it never washes out against the highlighted row.
        let (fg, glow): (Color, Color) = row.isMe ? (Color.accentInk, .clear) : medalColor(for: row.rank)
        let name = entry.username.isEmpty ? "Pump user" : entry.username

        return HStack(spacing: 10) {
            Text("\(row.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(width: 22, alignment: .leading)
            Avatar(initial: name, size: 32)
            Text(row.isMe ? "You" : name).font(.archivo(16, weight: row.rank <= 3 || row.isMe ? .bold : .regular)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metric.formatScore(entry.score, weightUnit)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 54, alignment: .trailing)
            moveLabel(row.movement).frame(width: 44, alignment: .trailing)
        }
        .frame(minHeight: 56)
        .background(row.isMe ? Color.activeRowBg : Color.clear)
        .overlay(alignment: .leading) {
            if row.isMe { Rectangle().fill(Color.pumpAccent).frame(width: 2).offset(x: -16) }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
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
