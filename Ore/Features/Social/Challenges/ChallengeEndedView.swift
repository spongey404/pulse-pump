import SwiftUI

/// 7b — challenge ended: winner band and the final board, from the entries the functions wrote.
struct ChallengeEndedView: View {
    let challenge: SocialChallenge
    @Environment(\.weightUnit) private var weightUnit
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isRunningAgain = false

    private var metric: ChallengeMetric { challenge.metric }
    private var board: ChallengeBoard? { viewModel.boards[challenge.id] }
    private var rows: [LeaderboardRow] { board?.rows ?? [] }
    private var mine: LeaderboardRow? { board?.mine }
    /// A winner exists only when someone actually scored (an all-zero board has no winner).
    private var winner: LeaderboardRow? { rows.first.flatMap { $0.entry.score > 0 ? $0 : nil } }
    private var lengthDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: challenge.startAt, to: challenge.endAt).day ?? 28)
    }

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: challenge.name.uppercased(), onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text("ENDED \(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                            .font(Font.spaceMono(8, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("\(metric.displayName.uppercased()) · \(challenge.memberCount) \(challenge.memberCount == 1 ? "PERSON" : "PEOPLE")")
                            .font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, 12)

                    if let winner {
                        HStack(spacing: 14) {
                            Avatar(initial: winner.entry.username, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("WINNER").font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                                Text((winner.isMe ? "You" : winner.entry.username).uppercased())
                                    .font(.archivo(22, weight: .black)).tracking(0.5)
                                    .foregroundStyle(Color.medalGold)
                                    .shadow(color: Color.medalGold.opacity(0.45), radius: 5)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("BEST").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                Text(metric.formatScore(winner.entry.score, weightUnit)).font(Font.spaceMono(18, weight: .bold)).foregroundStyle(Color.inkPrimary)
                            }
                        }
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        .padding(.top, 14)
                    } else if board != nil {
                        Text("NO WINNER · NOBODY SCORED")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(.top, 16)
                    }

                    HStack(spacing: 0) {
                        KPIBlock(label: "You Finished", value: mine.map { Leaderboard.ordinal($0.rank) } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                        KPIBlock(label: "Your Best", value: mine.map { metric.formatScore($0.entry.score, weightUnit) } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                        KPIBlock(label: "People", value: "\(max(challenge.memberCount, rows.count))", alignment: .center).frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)

                    SectionLabel(title: "Final", meta: "Leaderboard").padding(.bottom, 6)
                    if board == nil { SkeletonRows(count: 4) }
                    ForEach(rows) { row in
                        boardRow(row)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadBoard(challenge) }
        .safeAreaInset(edge: .bottom) {
            // Clients can only create private challenges, so a global one can't be re-run from here.
            if !challenge.isGlobal {
                DockedCTA(leadingText: "SAME METRIC, NEW \(lengthDays) DAYS", primaryLabel: isRunningAgain ? "…" : "RUN IT AGAIN ›", style: .quiet) {
                    runAgain()
                }
                .disabled(isRunningAgain)
            }
        }
    }

    private func runAgain() {
        isRunningAgain = true
        let start = Date()
        let draft = ChallengeDraft(
            name: challenge.name, metric: challenge.metric, exerciseName: challenge.exerciseName,
            startAt: start, endAt: start.addingTimeInterval(Double(lengthDays) * 86_400),
            visibility: challenge.visibility, winCondition: challenge.winCondition,
            unit: challenge.unit, customLabel: challenge.customLabel)
        Task {
            if await viewModel.createChallenge(draft) != nil { dismiss() }
            isRunningAgain = false
        }
    }

    private func boardRow(_ row: LeaderboardRow) -> some View {
        let (fg, glow) = medalColor(for: row.rank)
        let name = row.entry.username.isEmpty ? Brand.defaultUserName : row.entry.username
        return HStack(spacing: 10) {
            Text("\(row.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(width: 22, alignment: .leading)
            Avatar(initial: name, size: 32, showBorder: false)
            Text(row.isMe ? "You" : name).font(.archivo(16, weight: row.rank <= 3 ? .bold : .regular)).foregroundStyle(row.isMe ? Color.accentInk : fg).shadow(color: glow, radius: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metric.formatScore(row.entry.score, weightUnit)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 68, alignment: .trailing)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
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
