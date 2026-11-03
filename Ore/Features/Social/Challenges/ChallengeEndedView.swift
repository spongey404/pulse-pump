import SwiftUI

/// 7b — challenge ended: winner card with a gold star, your result, the final board (from the entries the functions wrote)
/// and a rematch.
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
    /// "4 WEEKS" when the length is whole weeks, else "30 DAYS".
    /// Whole days the challenge ran: one that ends at the last instant of a day is one day short of its whole length.
    private var wholeDays: Int {
        Calendar.current.dateComponents([.day], from: challenge.startAt, to: challenge.endAt.addingTimeInterval(60)).day ?? lengthDays
    }
    private var lengthLabel: String {
        let days = wholeDays
        if days >= 7, days % 7 == 0 { return "\(days / 7) \(days / 7 == 1 ? "WEEK" : "WEEKS")" }
        return "\(days) \(days == 1 ? "DAY" : "DAYS")"
    }
    private var label: String {
        var parts = ["Ended \(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)))", metric.displayName]
        parts.append("\(challenge.memberCount) \(challenge.memberCount == 1 ? "person" : "people")")
        return parts.joined(separator: " · ").uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            ChallengeHeader(label: label, title: challenge.name.uppercased(), onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let winner {
                        winnerCard(winner).padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                    } else if board != nil {
                        Text("NO WINNER · NOBODY SCORED")
                            .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(16)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        stat("You finished", mine.map { Leaderboard.ordinal($0.rank) } ?? "—")
                        stat("Your best", mine.map { metric.formatScore($0.entry.score, weightUnit) } ?? "—")
                        stat("People", "\(max(challenge.memberCount, rows.count))")
                    }
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    SectionLabel(title: "Final Board")
                        .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
                    if board == nil { SkeletonRows(count: 4).padding(.horizontal, 16) }
                    ForEach(rows) { row in
                        ChallengeBoardRow(row: row, minHeight: 52) {
                            ScoreText(value: metric.formatScore(row.entry.score, weightUnit), suffix: metric.scoreSuffix(weightUnit), size: 14)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadBoard(challenge) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Clients can only create private challenges, so a global one can't be re-run from here.
            if !challenge.isGlobal {
                SocialDock {
                    SocialCTA(title: isRunningAgain ? "…" : "RUN IT AGAIN", info: "SAME METRIC · \(lengthLabel)",
                              disabled: isRunningAgain, id: AX.row("Run it again")) { runAgain() }
                }
            }
        }
    }

    private func winnerCard(_ winner: LeaderboardRow) -> some View {
        let name = winner.entry.username.isEmpty ? Brand.defaultUserName : winner.entry.username
        let suffix = metric.scoreSuffix(weightUnit)
        return VStack(spacing: 8) {
            PRStar(size: 22)
            Text("WINNER").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            ChallengeAvatar(name: name, isMe: winner.isMe, size: 56)
            Text(winner.isMe ? "You" : name).font(.archivo(26, weight: .black)).foregroundStyle(Color.inkPrimary).lineLimit(1)
            ScoreText(value: metric.formatScore(winner.entry.score, weightUnit), suffix: suffix, size: 20, color: .prGold)
        }
        .padding(.vertical, 22).padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            Text(value).font(.spaceMono(20, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1).minimumScaleFactor(0.6)
                .frame(height: 20)   // the design's line-height 1
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func runAgain() {
        isRunningAgain = true
        let start = Date()
        let draft = ChallengeDraft(
            name: challenge.name, metric: challenge.metric, exerciseName: challenge.exerciseName,
            startAt: start, endAt: start.addingTimeInterval(Double(wholeDays) * 86_400),
            visibility: challenge.visibility, winCondition: challenge.winCondition,
            unit: challenge.unit, customLabel: challenge.customLabel)
        Task {
            if await viewModel.createChallenge(draft) != nil { dismiss() }
            isRunningAgain = false
        }
    }
}
