import SwiftUI
import SwiftData

/// 9a — a friend's history on one lift, opened by tapping an exercise row in the full
/// session view (`FeedSessionSheet`). NOT `ExerciseLibrary/ExerciseDetailView` — that
/// screen explains how a lift is performed, which is a non sequitur landing from someone's
/// session. This screen answers "how has this person been doing on this lift" instead.
///
/// Their numbers only, deliberately — no side-by-side with the viewer's own lifts. This is
/// reached by tapping into someone's session record; turning that into a scoreboard would
/// change what the whole tab feels like. Comparison lives in challenges/leaderboards, which
/// people opt into. The viewer's own history is this same screen from their own session.
struct LiftHistoryView: View {
    @Environment(\.weightUnit) private var unit
    let exerciseName: String
    let ownerUid: String
    let ownerUsername: String
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sessions: [LiftSession] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var equipmentLabel = "EXERCISE"

    /// Last 6 sessions, oldest first — matches both the chart's left-to-right reading order
    /// and the history table's reverse-chronological one (reversed at the call site).
    private var recentSessions: [LiftSession] { Array(sessions.suffix(6)) }

    private var bestEver: LiftSession? { sessions.max { $0.bestWeight < $1.bestWeight } }

    /// Best Epley estimate across every working set on record (a 1-rep set counts as the weight itself);
    /// nil for bodyweight / timed lifts, which have no external load.
    private var est1RM: Double? { LiftHistory.estimatedOneRepMax(sessions: sessions) }

    /// Best-weight change since the session closest to 12 weeks ago (nil with fewer than two sessions).
    private var twelveWeekDelta: Double? { LiftHistory.weightChange(sessions: sessions) }

    /// Bar heights are baselined 2.5kg below the lightest session in range, not at zero —
    /// measured from zero, sessions inside a tight spread all render 79–100% tall and the
    /// progression the header claims is invisible.
    private var chartBaseline: Double {
        (recentSessions.map(\.bestWeight).min() ?? 0) - 2.5
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button { dismiss() } label: {
                    Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ownerUsername.uppercased()) · \(equipmentLabel)")
                        .font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    Text(exerciseName.uppercased())
                        .font(.display(24)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            if isLoading {
                SkeletonRows(count: 4).padding(.horizontal, 16).padding(.top, 20)
                Spacer()
            } else if loadFailed {
                RetryNotice(message: "Couldn't load their sessions.") { isLoading = true; Task { await loadHistory() } }
                Spacer()
            } else if sessions.isEmpty {
                Text("NO POSTED SESSIONS FOR THIS LIFT YET")
                    .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity).padding(.top, 60)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        threeUpStats

                        VStack(alignment: .leading, spacing: 0) {
                            SectionLabel(title: "Progression", meta: "Best Set · From \(unit.formatTight(max(0, chartBaseline + 2.5)))")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                        chart

                        VStack(alignment: .leading, spacing: 0) {
                            SectionLabel(title: "History", meta: "Last \(recentSessions.count) Of \(sessions.count)")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 22)

                        historyTableHeader

                        ForEach(recentSessions.reversed()) { session in
                            historyRow(session)
                        }

                        Text("FROM POSTED SESSIONS ONLY · \(sessions.count) \(sessions.count == 1 ? "SESSION" : "SESSIONS") ON RECORD")
                            .font(Font.spaceMono(9)).tracking(1.2).lineSpacing(4).foregroundStyle(Color.inkMuted)
                            .padding(16)
                    }
                }
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task { await loadHistory() }
    }

    // MARK: Three-up stats

    private var threeUpStats: some View {
        HStack(spacing: 10) {
            statCell(label: "BEST EVER") {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(bestEver.map { unit.number($0.bestWeight) } ?? "—")
                        .font(.archivo(26, weight: .black)).lineSpacing(0)
                        .foregroundStyle(Color.prGold)
                    if let reps = bestEver?.bestSet?.reps {
                        Text("×\(reps)").font(.archivo(14, weight: .black)).foregroundStyle(Color.inkMuted)
                    }
                }
            }
            statCell(label: "EST 1RM") {
                Text(est1RM.map { unit.number($0) } ?? "—").font(.archivo(26, weight: .black)).lineSpacing(0).foregroundStyle(Color.inkPrimary)
            }
            statCell(label: "12 WK") {
                Text(twelveWeekDelta.map { "\($0 >= 0 ? "+" : "")\(unit.number($0))" } ?? "—")
                    .font(.archivo(26, weight: .black)).lineSpacing(0).foregroundStyle((twelveWeekDelta ?? 0) < 0 ? Color.signalDown : Color.signalUp)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func statCell(label: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Font.spaceMono(7)).kerning(1.2).textCase(.uppercase).foregroundStyle(Color.inkMuted)
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Progression chart

    private var chart: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(recentSessions) { session in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(session.isPR ? Color.prGold : Color.inkPrimary.opacity(0.42))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(for: session))
                }
            }
            .frame(height: 88, alignment: .bottom)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(recentSessions) { session in
                    Text(session.date, format: .dateTime.day().month(.abbreviated))
                        .font(Font.spaceMono(7)).tracking(0.6).foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    private func barHeight(for session: LiftSession) -> CGFloat {
        let baseline = chartBaseline
        let heaviest = recentSessions.map(\.bestWeight).max() ?? session.bestWeight
        guard heaviest > baseline else { return 4 }
        let ratio = (session.bestWeight - baseline) / (heaviest - baseline)
        return max(4, CGFloat(ratio) * 88)
    }

    // MARK: History table

    private var historyTableHeader: some View {
        HStack(spacing: 8) {
            Text("DATE").frame(maxWidth: .infinity, alignment: .leading)
            Text("BEST").frame(width: 70, alignment: .trailing)
            Text("VOLUME").frame(width: 56, alignment: .trailing)
        }
        .font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 16)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func historyRow(_ session: LiftSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 6) {
                    Text(session.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.archivo(14, weight: .bold)).tracking(0.2).lineLimit(1)
                        .foregroundStyle(Color.inkPrimary)
                    if session.isPR {
                        Text("PR")
                            .font(Font.spaceMono(8, weight: .bold)).tracking(1.2)
                            .foregroundStyle(Color.prGold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(session.bestSet.map { setValueLabel($0) } ?? "—")
                    .font(Font.spaceMono(14, weight: .bold))
                    .foregroundStyle(session.isPR ? Color.prGold : Color.inkPrimary)
                    .frame(width: 70, alignment: .trailing)

                Text(volumeLabel(session))
                    .font(Font.spaceMono(13))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 56, alignment: .trailing)
            }

            // Uniform — no bolding, no gold. The row's own BEST column already says which
            // set was best; emphasising a set here again would state it twice.
            Text(session.sets.map { setValueLabel($0) }.joined(separator: " · "))
                .font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
                .padding(.top, 7)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func volumeLabel(_ session: LiftSession) -> String {
        let total = session.sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return unit.compactVolume(total)   // feed weights are kg
    }

    private func setValueLabel(_ set: FeedSetLog) -> String {
        if set.duration > 0 { return "\(set.duration)s" }
        if set.distance > 0 { return String(format: "%.0fm", set.distance) }
        return set.weight > 0 ? "\(unit.number(set.weight))×\(set.reps)" : "\(set.reps)r"
    }

    // MARK: Data

    /// The person's real posted sessions of this lift. Nothing is invented when there are none.
    private func loadHistory() async {
        let descriptor = FetchDescriptor<Exercise>()
        if let match = (try? modelContext.fetch(descriptor))?.first(where: { $0.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame }) {
            equipmentLabel = match.equipmentType.displayName.uppercased()
        }
        if let found = await viewModel.loadLiftHistory(ownerUid: ownerUid, exerciseName: exerciseName) {
            sessions = found
            loadFailed = false
        } else {
            loadFailed = true
        }
        isLoading = false
    }
}
