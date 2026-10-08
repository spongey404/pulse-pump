import SwiftUI

/// 6f — admin screen for the monthly global challenge. Gated behind `isAdmin` — this repo
/// has no RBAC/Cloud Functions layer, so this is a simple allowlist stub, not real access
/// control. TODO: back with a real `isAdmin` field on `FirestoreUserProfile` once one exists.
struct AdminChallengeView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var nextName = ""
    @State private var nextMetric: ChallengeMetric = .totalVolume
    @State private var announceOnStart = false
    @State private var leaderboardVisibleToAll = true

    private var runningGlobal: FirestoreChallenge? { viewModel.activeChallenges.first { $0.isGlobal } }
    private var daysLeft: Int {
        guard let end = runningGlobal?.endDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                Text("ADMIN")
                    .font(Font.spaceMono(8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.inkPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let running = runningGlobal {
                        SectionLabel(title: "Running").padding(.top, 16).padding(.bottom, 8)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(running.name.uppercased()).font(.archivo(18, weight: .bold)).foregroundStyle(Color.inkPrimary)
                            Text("\(running.participantIds.count) ENTRIES · \(daysLeft)D LEFT")
                                .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        }
                        .padding(14)
                        .background(Color.surf)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
                    }

                    SectionLabel(title: "Next Up").padding(.top, 24).padding(.bottom, 8)
                    HStack {
                        TextField("September Volume", text: $nextName)
                            .font(.archivo(20, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .frame(minHeight: 44, alignment: .bottom)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleStrong).frame(height: 1) }

                    ForEach(ChallengeMetric.allCases) { m in
                        metricRow(m)
                    }

                    toggleRow(title: "Announce on 1 Sep", note: "PUSH TO EVERYONE ON PUMP", isOn: $announceOnStart)
                        .padding(.top, 20)
                    toggleRow(title: "Show full leaderboard", note: "OFF SHOWS TOP 50 AND YOUR RANK ONLY", isOn: $leaderboardVisibleToAll)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            DockedCTA(leadingText: "STARTS 1 SEP · 00:00 LOCAL", primaryLabel: "SCHEDULE ›", style: .quiet) {
                Task {
                    await viewModel.createChallenge(
                        name: nextName, metric: nextMetric,
                        startDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
                        endDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date(),
                        isGlobal: true
                    )
                    dismiss()
                }
            }
            .disabled(nextName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func metricRow(_ m: ChallengeMetric) -> some View {
        let selected = nextMetric == m
        return Button { nextMetric = m } label: {
            HStack {
                Text(m.displayName).font(.archivo(15, weight: selected ? .bold : .regular)).foregroundStyle(Color.inkPrimary)
                Spacer()
                if selected { Text("✓").font(Font.spaceMono(12, weight: .bold)).foregroundStyle(Color.accentInk) }
            }
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func toggleRow(title: String, note: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                Text(note).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Color.pumpAccent)
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
