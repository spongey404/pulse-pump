import SwiftUI

/// 4a — friend challenge leaderboard: the top three on a podium, the rest as rows, then who scored lately, with your place pinned at
/// the bottom. Rows, ranks and movement come from the entries the Cloud Functions maintain (equal scores share a rank);
/// nothing is scored on the device.
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

    private var label: String {
        var parts = [metric.displayName]
        if let exercise = challenge.exerciseName { parts.append(exercise) }
        parts.append(challengeTimeLeft(challenge))
        return parts.joined(separator: " · ").uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            ChallengeHeader(label: label, title: challenge.name.uppercased(), onBack: { dismiss() })

            ScrollView {
                VStack(spacing: 0) {
                    if board == nil {
                        SkeletonRows(count: 4).padding(.horizontal, 16).padding(.top, 14)
                    } else if rows.isEmpty {
                        Text("NO ONE IS ON THE BOARD YET · SCORES UPDATE AS WORKOUTS ARE LOGGED")
                            .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    } else {
                        ChallengePodium(rows: rows, metric: metric, weightUnit: weightUnit)
                        ForEach(Array(rows.dropFirst(3))) { row in
                            ChallengeBoardRow(row: row) {
                                ScoreText(value: metric.formatScore(row.entry.score, weightUnit), suffix: metric.scoreSuffix(weightUnit), size: 15)
                            }
                        }
                        ChallengeActivityList(rows: rows, metric: metric, weightUnit: weightUnit)
                    }
                    if board != nil {
                        // Invite and options live under the list, so the header stays as the design draws it (just the back button).
                        HStack(spacing: 8) {
                            if canInvite { SocialSmallAction(title: "+ INVITE", style: .outlined) { showInvite = true } }
                            SocialSmallAction(title: "OPTIONS", style: .outlined) { menuOpen = true }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.top, 22)
                    }
                }
                Color.clear.frame(height: 16)
            }
            .refreshable { await viewModel.loadBoard(challenge) }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadBoard(challenge) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let mine { ChallengePinnedYou(mine: mine, rows: rows, metric: metric, weightUnit: weightUnit) }
        }
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
}
