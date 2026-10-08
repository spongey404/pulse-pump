import SwiftUI

/// 3b — Challenges tab (global challenge card + friend challenges + create).
struct ChallengesView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var showCreateChallenge = false
    @Environment(\.weightUnit) private var weightUnit

    private var globalChallenge: FirestoreChallenge? {
        viewModel.activeChallenges.first { $0.isGlobal }
    }
    private var friendChallenges: [FirestoreChallenge] {
        (viewModel.myChallenges + viewModel.activeChallenges.filter { !$0.isGlobal })
            .reduce(into: [FirestoreChallenge]()) { acc, c in if !acc.contains(where: { $0.id == c.id }) { acc.append(c) } }
    }

    /// Only appends "K" once the value actually crosses into the thousands — a raw 500-point
    /// gap must read "500", not "500.0K".
    private func formattedScore(_ score: Double, _ metric: ChallengeMetric) -> String {
        metric.formatScoreCompact(score, weightUnit)   // weight-based scores are kg
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoadingChallenges {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    if let global = globalChallenge {
                        globalChallengeCard(global).padding(.horizontal, 16).padding(.top, 14)
                    }

                    SectionLabel(title: "Friend Challenges", meta: "\(friendChallenges.count) Active")
                        .padding(.horizontal, 16)
                        .padding(.top, 22)
                        .padding(.bottom, 8)

                    if friendChallenges.isEmpty {
                        NoChallengesEmptyState(onCreateChallenge: { showCreateChallenge = true })
                    } else {
                        ForEach(friendChallenges) { challenge in
                            NavigationLink {
                                if challenge.endDate < Date() {
                                    ChallengeEndedView(challenge: challenge, viewModel: viewModel)
                                } else {
                                    ChallengeLeaderboardView(challenge: challenge, viewModel: viewModel)
                                }
                            } label: {
                                friendChallengeRow(challenge)
                            }
                            .buttonStyle(.plain)
                        }
                        DashedAdd(title: "Create Challenge") { showCreateChallenge = true }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
                Color.clear.frame(height: 32)
            }
        }
        .background(Color.canvasBg)
        .navigationDestination(isPresented: $showCreateChallenge) {
            CreateChallengeStep1View(viewModel: viewModel)
        }
        .refreshable { await viewModel.loadChallenges() }
        .task { await viewModel.loadChallenges() }
    }

    private func globalChallengeCard(_ challenge: FirestoreChallenge) -> some View {
        let metric = ChallengeMetric(rawValue: challenge.metric) ?? .totalVolume
        let myEntry = challenge.leaderboard.first { $0.userId == viewModel.currentUid }
        let sorted = challenge.leaderboard.sorted { $0.rank < $1.rank }
        let nextAbove = myEntry.flatMap { mine in sorted.last { $0.rank < mine.rank } }

        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "This Month · Global", meta: "Ends \(challenge.endDate.formatted(.dateTime.day().month(.abbreviated)))")
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                // Content block — the only section with its own padding; the KPI row and
                // action row below are full-bleed inside the card per spec.
                VStack(alignment: .leading, spacing: 0) {
                    Text("SET BY PULSE · \(challenge.startDate.formatted(.dateTime.day()))–\(challenge.endDate.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .padding(.bottom, 5)
                    Text(metric.displayName.uppercased())
                        .font(.archivo(26, weight: .black)).tracking(0.5).lineSpacing(0)
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.bottom, 3)
                    Text(metric.globalSubheading(weightUnit))
                        .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)

                HStack(spacing: 0) {
                    kpiCell(label: "Your Total", value: myEntry.map { formattedScore($0.score, metric) } ?? "—", showTrailingBorder: true)
                    kpiCell(label: "Rank", value: myEntry.map { "\($0.rank)" } ?? "—", delta: "OF \(challenge.participantIds.count.formatted())", showTrailingBorder: true)
                    kpiCell(label: "To Next", value: nextAbove.flatMap { above in myEntry.map { formattedScore(max(0, above.score - $0.score), metric) } } ?? "—", showTrailingBorder: false)
                }
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                NavigationLink {
                    GlobalLeaderboardView(challenge: challenge, viewModel: viewModel)
                } label: {
                    HStack {
                        Text("VIEW LEADERBOARD").font(.archivo(14, weight: .black)).tracking(0.5).foregroundStyle(Color.accentInk)
                        Spacer()
                        Text("›").font(Font.spaceMono(14)).foregroundStyle(Color.accentInk)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
        }
    }

    private func kpiCell(label: String, value: String, delta: String? = nil, showTrailingBorder: Bool) -> some View {
        KPIBlock(label: label, value: value, delta: delta, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                if showTrailingBorder { Rectangle().fill(Color.dsHairLine).frame(width: 1) }
            }
    }

    private func friendChallengeRow(_ challenge: FirestoreChallenge) -> some View {
        let myEntry = challenge.leaderboard.first { $0.userId == viewModel.currentUid }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(challenge.name).font(.archivo(17, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Spacer()
                Text(challenge.endDate, style: .relative).font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            Text("\((ChallengeMetric(rawValue: challenge.metric) ?? .totalVolume).displayName.uppercased()) · \(challenge.participantIds.count) PARTICIPANTS")
                .font(Font.spaceMono(9)).tracking(1).foregroundStyle(Color.inkMuted)

            HStack {
                KPIBlock(label: "You", value: myEntry.map { (ChallengeMetric(rawValue: challenge.metric) ?? .totalVolume).formatScore($0.score, weightUnit) } ?? "—")
                Spacer()
                KPIBlock(label: "Position", value: myEntry.map { "\($0.rank)" } ?? "—", alignment: .trailing)
                Text("›").font(.system(size: 14)).foregroundStyle(Color.inkMuted).padding(.leading, 8)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
