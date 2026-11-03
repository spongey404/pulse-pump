import SwiftUI

/// 3a — Challenges tab: the global (monthly) challenge as a card (Stardust for members who have it on, flat accent otherwise),
/// invites, friend challenges with mini podiums, and a dashed create button.
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
                            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            ForEach(viewModel.pendingChallengeInvites) { invite in
                                inviteRow(invite)
                            }
                        }
                        .padding(.top, 1).overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }

                    SectionLabel(title: "Friend Challenges", meta: "\(viewModel.activeFriendChallenges.count) Active")
                        .padding(.horizontal, 16)
                        .padding(.top, viewModel.pendingChallengeInvites.isEmpty ? 8 : 22)
                        .padding(.bottom, 8)

                    if viewModel.activeFriendChallenges.isEmpty {
                        NoChallengesEmptyState(onCreateChallenge: { showCreateChallenge = true })
                    } else {
                        ForEach(viewModel.activeFriendChallenges) { challenge in
                            NavigationLink {
                                ChallengeLeaderboardView(challenge: challenge, viewModel: viewModel)
                            } label: {
                                friendChallengeCard(challenge)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16).padding(.bottom, 14)
                        }
                        createButton
                    }

                    let ended = viewModel.endedChallenges
                    if !ended.isEmpty {
                        SectionLabel(title: "Ended", meta: "\(ended.count)")
                            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            ForEach(ended) { challenge in
                                NavigationLink {
                                    ChallengeEndedView(challenge: challenge, viewModel: viewModel)
                                } label: {
                                    endedChallengeRow(challenge)
                                }
                                .buttonStyle(OreRowPressStyle())
                            }
                        }
                        .padding(.top, 1).overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
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

    private var createButton: some View {
        Button { showCreateChallenge = true } label: {
            Text("+ CREATE CHALLENGE")
                .font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity).frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.bottom, 30)
        .accessibilityIdentifier(AX.row("Create challenge"))
    }

    // MARK: Global card

    private func globalChallengeCard(_ challenge: SocialChallenge) -> some View {
        let metric = challenge.metric
        let board = viewModel.boards[challenge.id]
        let mine = board?.mine
        let joined = board?.isMember ?? viewModel.isJoined(challenge)
        let total = max(challenge.memberCount, board?.rows.count ?? 0)
        let ends = challenge.endAt.formatted(.dateTime.day().month(.abbreviated)).uppercased()
        let monthly = challenge.endAt.timeIntervalSince(challenge.startAt) >= 25 * 86_400
        let white = Color.white

        return VStack(alignment: .leading, spacing: 0) {
            Text("\(monthly ? "THIS MONTH · " : "")GLOBAL · ENDS \(ends)")
                .font(.spaceMono(9)).tracking(1.5).foregroundStyle(white.opacity(0.9))
            Text(challenge.name.uppercased())
                .font(.archivo(32, weight: .black)).foregroundStyle(white)
                .padding(.top, 6)
                .accessibilityIdentifier(AX.social.challengeName)
            Text(Self.sentence(metric.globalSubheading(weightUnit)))
                .font(.archivo(13)).foregroundStyle(white.opacity(0.9))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(mine.map { "\($0.rank)" } ?? "—").font(.spaceMono(52, weight: .bold)).foregroundStyle(white)
                    .frame(height: 46.8)   // the design's line-height 0.9
                VStack(alignment: .leading, spacing: 0) {
                    Text("OF \(total.formatted())")
                    if let mine, let top = Self.topPercent(rank: mine.rank, of: total) {
                        Text("TOP \(top)%")
                    }
                }
                .font(.spaceMono(9)).tracking(1.5).foregroundStyle(white.opacity(0.9))
            }
            .padding(.top, 20)

            VStack(spacing: 0) {
                Rectangle().fill(white.opacity(0.3)).frame(height: 1)
                if joined {
                    NavigationLink {
                        GlobalLeaderboardView(challenge: challenge, viewModel: viewModel)
                    } label: {
                        cardFooter(left: footerScore(challenge: challenge, mine: mine, board: board), right: "BOARD ›")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AX.social.challengeView)
                } else {
                    Button {
                        isJoiningGlobal = true
                        Task { await viewModel.join(challenge); isJoiningGlobal = false }
                    } label: {
                        cardFooter(left: "JOIN TO GET ON THE BOARD", right: isJoiningGlobal ? "JOINING…" : "JOIN ›")
                    }
                    .buttonStyle(.plain)
                    .disabled(isJoiningGlobal)
                    .accessibilityIdentifier(AX.social.challengeJoin)
                }
            }
            .padding(.top, 16)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { SocialCardFill() }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 14)
    }

    /// "48.2K KG · 1.4K TO 46TH": your score, and the gap to the place above when there is one.
    private func footerScore(challenge: SocialChallenge, mine: LeaderboardRow?, board: ChallengeBoard?) -> String {
        guard let mine else { return "NO SCORE YET" }
        let metric = challenge.metric
        let suffix = metric.scoreSuffix(weightUnit)
        var text = metric.formatScoreCompact(mine.entry.score, weightUnit) + (suffix.isEmpty ? "" : " " + suffix)
        if let board, let gap = Leaderboard.gapToNext(rows: board.rows, mine: mine),
           let above = board.rows.last(where: { $0.rank < mine.rank }) {
            text += " · \(metric.formatScoreCompact(gap, weightUnit)) TO \(Leaderboard.ordinal(above.rank))"
        }
        return text
    }

    private func cardFooter(left: String, right: String) -> some View {
        HStack {
            Text(left).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.white).lineLimit(1)
            Spacer(minLength: 8)
            Text(right).font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.white)
        }
        .padding(.top, 12)
        .contentShape(Rectangle())
    }

    /// "EVERY KG LIFTED · ALL SESSIONS COUNT" → "Every kg lifted. All sessions count."
    static func sentence(_ shouting: String) -> String {
        shouting.split(separator: "·").map { part in
            let t = part.trimmingCharacters(in: .whitespaces).lowercased()
            return t.prefix(1).uppercased() + t.dropFirst() + "."
        }.joined(separator: " ")
    }

    /// Top x% of the board (1...100), nil when the board is empty.
    static func topPercent(rank: Int, of total: Int) -> Int? {
        guard total > 0, rank > 0 else { return nil }
        return min(100, max(1, Int((Double(rank) / Double(total) * 100).rounded(.up))))
    }

    // MARK: Rows

    private func inviteRow(_ invite: ChallengeInvite) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(invite.challengeName).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Text("Invited by \(invite.fromUsername.isEmpty ? "a friend" : "@" + invite.fromUsername)")
                    .font(.archivo(12)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            SocialSmallAction(title: "JOIN", style: .filled) { Task { await viewModel.respond(to: invite, accept: true) } }
            SocialSmallAction(title: "IGNORE", style: .outlined) { Task { await viewModel.respond(to: invite, accept: false) } }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func friendChallengeCard(_ challenge: SocialChallenge) -> some View {
        let board = viewModel.boards[challenge.id]
        let mine = board?.mine
        let sub = [challenge.exerciseName ?? challenge.metric.displayName, challengeTimeLeft(challenge)].joined(separator: " · ")
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.name).font(.archivo(17, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                Text(sub).font(.archivo(12)).foregroundStyle(Color.inkMuted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let rows = board?.rows, !rows.isEmpty { miniPodium(rows) }
            Text(mine.map { Leaderboard.ordinal($0.rank) } ?? "—")
                .font(.spaceMono(15, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(14)
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AX.social.challengeRow)
    }

    /// Second, first, third: initial tile over a bar (18 / 26 / 12 pt) in the sunken tone, you in the accent.
    private func miniPodium(_ rows: [LeaderboardRow]) -> some View {
        let top = Array(rows.prefix(3))
        let heights: [CGFloat] = [26, 18, 12]
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach([1, 0, 2].filter { $0 < top.count }, id: \.self) { i in
                let r = top[i]
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(r.isMe ? Color.oreAccent : Color.surf2)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Text(String((r.isMe ? "You" : r.entry.username).prefix(1)).uppercased())
                                .font(.archivo(9, weight: .black))
                                .foregroundStyle(r.isMe ? Color.white : Color.inkSecondary)
                        }
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                        .fill(Color.surf2).frame(width: 22, height: heights[i])
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func endedChallengeRow(_ challenge: SocialChallenge) -> some View {
        let mine = viewModel.boards[challenge.id]?.mine
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.name).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Text("Ended \(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.archivo(12)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            if let mine { Text(Leaderboard.ordinal(mine.rank)).font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary) }
            Text("›").font(.spaceMono(14)).foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

/// Behind the monthly challenge card: the accent, with the member's Stardust drifting over it when they have Stardust buttons on.
struct SocialCardFill: View {
    var body: some View {
        ZStack {
            Color.oreAccent
            if AccentStore.shared.stardustEnabled {
                StardustView(variant: "banner", budget: .more,
                             overrides: StardustParams.Overrides(palette: AccentStore.shared.starPalette))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}
