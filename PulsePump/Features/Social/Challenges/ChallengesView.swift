import SwiftUI

/// 3b — Challenges tab: the global challenge (joinable), invites, friend challenges and create.
/// Everything shown comes from Firestore; scores and ranks are computed by Cloud Functions.
struct ChallengesView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var showCreateChallenge = false
    @State private var isJoiningGlobal = false
    @Environment(\.weightUnit) private var weightUnit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoadingChallenges && viewModel.myChallenges.isEmpty && viewModel.globalChallenge == nil {
                    SkeletonRows(count: 3, rowHeight: 84).padding(.horizontal, 16).padding(.top, 14)
                } else {
                    if let error = viewModel.challengesError, viewModel.myChallenges.isEmpty, viewModel.globalChallenge == nil {
                        RetryNotice(message: error) { Task { await viewModel.loadChallenges() } }
                    }

                    if let global = viewModel.globalChallenge {
                        globalChallengeCard(global).padding(.horizontal, 16).padding(.top, 14)
                    }

                    if !viewModel.pendingChallengeInvites.isEmpty {
                        SectionLabel(title: "Invites", meta: "\(viewModel.pendingChallengeInvites.count)")
                            .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 4)
                        ForEach(viewModel.pendingChallengeInvites) { invite in
                            inviteRow(invite)
                        }
                    }

                    SectionLabel(title: "Friend Challenges", meta: "\(viewModel.activeFriendChallenges.count) Active")
                        .padding(.horizontal, 16)
                        .padding(.top, 22)
                        .padding(.bottom, 8)

                    if viewModel.activeFriendChallenges.isEmpty {
                        NoChallengesEmptyState(onCreateChallenge: { showCreateChallenge = true })
                    } else {
                        ForEach(viewModel.activeFriendChallenges) { challenge in
                            NavigationLink {
                                ChallengeLeaderboardView(challenge: challenge, viewModel: viewModel)
                            } label: {
                                friendChallengeRow(challenge)
                            }
                            .buttonStyle(.plain)
                        }
                        DashedAdd(title: "Create Challenge") { showCreateChallenge = true }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    let ended = viewModel.endedChallenges
                    if !ended.isEmpty {
                        SectionLabel(title: "Ended", meta: "\(ended.count)")
                            .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 4)
                        ForEach(ended) { challenge in
                            NavigationLink {
                                ChallengeEndedView(challenge: challenge, viewModel: viewModel)
                            } label: {
                                endedChallengeRow(challenge)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Color.clear.frame(height: 32)
            }
        }
        .background(Color.canvasBg)
        .navigationDestination(isPresented: $showCreateChallenge) {
            CreateChallengeStep1View(viewModel: viewModel)
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        await viewModel.loadGraph()
        await viewModel.loadChallenges()
        for challenge in viewModel.activeFriendChallenges.prefix(10) where viewModel.boards[challenge.id] == nil {
            await viewModel.loadBoard(challenge)
        }
    }

    // MARK: Global card

    private func globalChallengeCard(_ challenge: SocialChallenge) -> some View {
        let metric = challenge.metric
        let board = viewModel.boards[challenge.id]
        let mine = board?.mine
        let joined = board?.isMember ?? viewModel.isJoined(challenge)
        let gap = mine.flatMap { m in board.flatMap { Leaderboard.gapToNext(rows: $0.rows, mine: m) } }

        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Global", meta: "Ends \(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)))")
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SET BY PULSE · \(challenge.startAt.formatted(.dateTime.day().month(.abbreviated)))–\(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .padding(.bottom, 5)
                    Text(challenge.name.uppercased())
                        .font(.archivo(26, weight: .black)).tracking(0.5).lineSpacing(0)
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.bottom, 3)
                        .accessibilityIdentifier(AX.social.challengeName)
                    Text(metric.globalSubheading(weightUnit))
                        .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)

                HStack(spacing: 0) {
                    kpiCell(label: "Your Total", value: mine.map { metric.formatScoreCompact($0.entry.score, weightUnit) } ?? "—", showTrailingBorder: true)
                    kpiCell(label: "Rank", value: mine.map { "\($0.rank)" } ?? "—", delta: "OF \(challenge.memberCount.formatted())", showTrailingBorder: true)
                    kpiCell(label: "To Next", value: gap.map { metric.formatScoreCompact($0, weightUnit) } ?? "—", showTrailingBorder: false)
                }
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                if joined {
                    NavigationLink {
                        GlobalLeaderboardView(challenge: challenge, viewModel: viewModel)
                    } label: {
                        actionRow("VIEW LEADERBOARD")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AX.social.challengeView)
                } else {
                    Button {
                        isJoiningGlobal = true
                        Task { await viewModel.join(challenge); isJoiningGlobal = false }
                    } label: {
                        actionRow(isJoiningGlobal ? "JOINING…" : "JOIN")
                    }
                    .buttonStyle(.plain)
                    .disabled(isJoiningGlobal)
                    .accessibilityIdentifier(AX.social.challengeJoin)
                }
            }
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
        }
    }

    private func actionRow(_ title: String) -> some View {
        HStack {
            Text(title).font(.archivo(14, weight: .black)).tracking(0.5).foregroundStyle(Color.accentInk)
            Spacer()
            Text("›").font(Font.spaceMono(14)).foregroundStyle(Color.accentInk)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func kpiCell(label: String, value: String, delta: String? = nil, showTrailingBorder: Bool) -> some View {
        KPIBlock(label: label, value: value, delta: delta, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                if showTrailingBorder { Rectangle().fill(Color.dsHairLine).frame(width: 1) }
            }
    }

    // MARK: Rows

    private func inviteRow(_ invite: ChallengeInvite) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(invite.challengeName).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Text("INVITED BY \(invite.fromUsername.isEmpty ? "A FRIEND" : "@" + invite.fromUsername.uppercased())")
                    .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            SocialPill(title: "JOIN", style: .filled) { Task { await viewModel.respond(to: invite, accept: true) } }
            SocialPill(title: "IGNORE", style: .outlined) { Task { await viewModel.respond(to: invite, accept: false) } }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func friendChallengeRow(_ challenge: SocialChallenge) -> some View {
        let mine = viewModel.boards[challenge.id]?.mine
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(challenge.name).font(.archivo(17, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Spacer()
                Text(timeLeft(challenge)).font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            Text("\(challenge.metric.displayName.uppercased()) · \(challenge.memberCount) \(challenge.memberCount == 1 ? "PARTICIPANT" : "PARTICIPANTS")")
                .font(Font.spaceMono(9)).tracking(1).foregroundStyle(Color.inkMuted)

            HStack {
                KPIBlock(label: "You", value: mine.map { challenge.metric.formatScore($0.entry.score, weightUnit) } ?? "—")
                Spacer()
                KPIBlock(label: "Position", value: mine.map { "\($0.rank)" } ?? "—", alignment: .trailing)
                Text("›").font(.system(size: 14)).foregroundStyle(Color.inkMuted).padding(.leading, 8)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func endedChallengeRow(_ challenge: SocialChallenge) -> some View {
        let mine = viewModel.boards[challenge.id]?.mine
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.name).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                Text("ENDED \(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                    .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            if let mine { Text(Leaderboard.ordinal(mine.rank)).font(Font.spaceMono(11, weight: .bold)).foregroundStyle(Color.inkPrimary) }
            Text("›").font(.system(size: 14)).foregroundStyle(Color.inkMuted).padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func timeLeft(_ challenge: SocialChallenge) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: challenge.endAt).day ?? 0
        if days <= 0 {
            let hours = max(1, Calendar.current.dateComponents([.hour], from: Date(), to: challenge.endAt).hour ?? 1)
            return "\(hours)H LEFT"
        }
        return "\(days)D LEFT"
    }
}
