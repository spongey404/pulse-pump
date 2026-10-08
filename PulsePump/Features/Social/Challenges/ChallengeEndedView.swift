import SwiftUI

/// 7b — challenge ended, final leaderboard + winner band.
struct ChallengeEndedView: View {
    let challenge: FirestoreChallenge
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    private var board: [LeaderboardEntry] { challenge.leaderboard.sorted { $0.rank < $1.rank } }
    private var winner: LeaderboardEntry? { board.first }
    private var myEntry: LeaderboardEntry? { board.first { $0.userId == viewModel.currentUid } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                Text(challenge.name.uppercased()).font(.archivo(20, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text("ENDED \(challenge.endDate.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(Font.spaceMono(8, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("\((ChallengeMetric(rawValue: challenge.metric) ?? .totalVolume).displayName.uppercased()) · \(challenge.participantIds.count) FRIENDS")
                            .font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, 12)

                    if let winner {
                        HStack(spacing: 14) {
                            Avatar(initial: winner.username, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("WINNER").font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                                Text(winner.username.uppercased())
                                    .font(.archivo(22, weight: .black)).tracking(0.5)
                                    .foregroundStyle(Color.medalGold)
                                    .shadow(color: Color.medalGold.opacity(0.45), radius: 5)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("BEST").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                Text(String(format: "%.0f", winner.score)).font(Font.spaceMono(18, weight: .bold)).foregroundStyle(Color.inkPrimary)
                            }
                        }
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        .padding(.top, 14)
                    }

                    HStack(spacing: 0) {
                        KPIBlock(label: "You Finished", value: myEntry.map { ordinal($0.rank) } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                        KPIBlock(label: "Your Best", value: myEntry.map { String(format: "%.0f", $0.score) } ?? "—", alignment: .center).frame(maxWidth: .infinity)
                        KPIBlock(label: "Gained", value: gainedLabel, valueColor: .signalUp, alignment: .center).frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)

                    SectionLabel(title: "Final", meta: "Leaderboard").padding(.bottom, 6)
                    ForEach(board) { entry in
                        boardRow(entry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            DockedCTA(leadingText: "SAME METRIC, NEW 4 WEEKS", primaryLabel: "RUN IT AGAIN ›", style: .quiet) {
                Task {
                    await viewModel.createChallenge(
                        name: challenge.name,
                        metric: ChallengeMetric(rawValue: challenge.metric) ?? .totalVolume,
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(28 * 24 * 3600),
                        runsFor: "4weeks"
                    )
                    dismiss()
                }
            }
        }
    }

    private var gainedLabel: String {
        guard let mine = myEntry else { return "—" }
        let delta = mine.score - (board.last?.score ?? mine.score)
        return String(format: "%.0f", max(0, delta))
    }

    private func ordinal(_ n: Int) -> String {
        switch (n % 100, n % 10) {
        case (11, _), (12, _), (13, _): "\(n)TH"
        case (_, 1): "\(n)ST"
        case (_, 2): "\(n)ND"
        case (_, 3): "\(n)RD"
        default: "\(n)TH"
        }
    }

    private func boardRow(_ entry: LeaderboardEntry) -> some View {
        let (fg, glow) = medalColor(for: entry.rank)
        let gained = entry.score - (board.last?.score ?? entry.score)
        return HStack(spacing: 10) {
            Text("\(entry.rank)").font(Font.spaceMono(15, weight: .bold)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(width: 22, alignment: .leading)
            Avatar(initial: entry.username, size: 32, showBorder: false)
            Text(entry.username).font(.archivo(16, weight: entry.rank <= 3 ? .bold : .regular)).foregroundStyle(fg).shadow(color: glow, radius: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.0f", entry.score)).font(Font.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 68, alignment: .trailing)
            Text(String(format: "%.0f", max(0, gained))).font(Font.spaceMono(10, weight: .bold)).foregroundStyle(Color.signalUp)
                .frame(width: 50, alignment: .trailing)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
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
