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
    let exerciseName: String
    let ownerUid: String
    let ownerUsername: String
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sessions: [LiftHistorySession] = []
    @State private var isLoading = true

    private var equipmentLabel: String {
        let descriptor = FetchDescriptor<Exercise>()
        let match = (try? modelContext.fetch(descriptor))?.first { $0.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame }
        return match?.equipmentType.displayName.uppercased() ?? "EXERCISE"
    }

    /// Last 6 sessions, oldest first — matches both the chart's left-to-right reading order
    /// and the history table's reverse-chronological one (reversed at the call site).
    private var recentSessions: [LiftHistorySession] { Array(sessions.suffix(6)) }

    private var bestEver: LiftHistorySession? { sessions.max { $0.bestWeight < $1.bestWeight } }

    private var est1RM: Int {
        guard let best = bestEver, let set = best.bestSet else { return 0 }
        let epley = set.weight > 0 ? set.weight * (1 + Double(set.reps) / 30) : Double(set.reps)
        return Int(epley)
    }

    /// Change vs. the session closest to 12 weeks ago — the oldest session on file if the
    /// full history doesn't stretch back that far.
    private var twelveWeekDelta: Double {
        guard let mostRecent = sessions.last else { return 0 }
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? Date()
        let baseline = sessions.first { $0.date >= cutoff } ?? sessions.first
        guard let baseline else { return 0 }
        return mostRecent.bestWeight - baseline.bestWeight
    }

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
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                Spacer()
            } else if sessions.isEmpty {
                Text("NO LOGGED SESSIONS FOR THIS LIFT YET")
                    .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity).padding(.top, 60)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        threeUpStats

                        VStack(alignment: .leading, spacing: 0) {
                            SectionLabel(title: "Progression", meta: "Best Set · From \(Int(max(0, chartBaseline + 2.5)))KG")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                        chart

                        VStack(alignment: .leading, spacing: 0) {
                            SectionLabel(title: "History", meta: "\(sessions.count) Sessions")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 22)

                        historyTableHeader

                        ForEach(recentSessions.reversed()) { session in
                            historyRow(session)
                        }

                        Text("SHOWING THIS YEAR · \(sessions.count) SESSIONS")
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
                    Text(bestEver.map { String(format: "%g", $0.bestWeight) } ?? "—")
                        .font(.archivo(26, weight: .black)).lineSpacing(0)
                        .foregroundStyle(Color.prGold)
                        .shadow(color: Color.prGold.opacity(0.45), radius: 5)
                    if let reps = bestEver?.bestSet?.reps {
                        Text("×\(reps)").font(.archivo(14, weight: .black)).foregroundStyle(Color.inkMuted)
                    }
                }
            }
            statCell(label: "EST 1RM") {
                Text("\(est1RM)").font(.archivo(26, weight: .black)).lineSpacing(0).foregroundStyle(Color.inkPrimary)
            }
            statCell(label: "12 WK") {
                Text("\(twelveWeekDelta >= 0 ? "+" : "")\(String(format: "%g", twelveWeekDelta))")
                    .font(.archivo(26, weight: .black)).lineSpacing(0).foregroundStyle(Color.signalUp)
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

    private func barHeight(for session: LiftHistorySession) -> CGFloat {
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

    private func historyRow(_ session: LiftHistorySession) -> some View {
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
                            .shadow(color: Color.prGold.opacity(0.5), radius: 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(session.bestSet.map { setValueLabel($0) } ?? "—")
                    .font(Font.spaceMono(14, weight: .bold))
                    .foregroundStyle(session.isPR ? Color.prGold : Color.inkPrimary)
                    .shadow(color: session.isPR ? Color.prGold.opacity(0.5) : .clear, radius: 4)
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

    private func volumeLabel(_ session: LiftHistorySession) -> String {
        let total = session.sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return total >= 1000 ? String(format: "%.1fK", total / 1000) : "\(Int(total))"
    }

    private func setValueLabel(_ set: FeedSetLog) -> String {
        if set.duration > 0 { return "\(set.duration)s" }
        if set.distance > 0 { return String(format: "%.0fm", set.distance) }
        return set.weight > 0 ? "\(String(format: "%g", set.weight))×\(set.reps)" : "\(set.reps)r"
    }

    // MARK: Data

    private func loadHistory() async {
        let items = (try? await viewModel.firestoreService.fetchFeed(friendUids: [ownerUid])) ?? []
        let matches = items.compactMap { item -> (Date, FeedExercise)? in
            guard let ex = item.exercises.first(where: { $0.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame }) else { return nil }
            return (item.date, ex)
        }
        .sorted { $0.0 < $1.0 }

        sessions = matches.isEmpty ? (DevFlags.socialFixtures ? demoSessions() : []) : buildSessions(from: matches)
        isLoading = false
    }

    private func buildSessions(from matches: [(Date, FeedExercise)]) -> [LiftHistorySession] {
        var runningBest = 0.0
        var built: [LiftHistorySession] = []
        for (date, ex) in matches {
            let bestWeight = ex.workingSets.map(\.weight).max() ?? 0
            let isPR = bestWeight > runningBest
            runningBest = max(runningBest, bestWeight)
            built.append(LiftHistorySession(date: date, sets: ex.sets, isPR: isPR))
        }
        return built
    }

    /// No real Firestore session data matched this lift — shown for demo accounts and for
    /// anyone genuinely new to a lift, same fallback convention as `demoFeedItems`/
    /// `demoFriends`/`demoChallenges` elsewhere in Social.
    private func demoSessions() -> [LiftHistorySession] {
        let cal = Calendar.current
        let now = Date()
        func sets(_ pairs: [(Double, Int)]) -> [FeedSetLog] {
            pairs.map { FeedSetLog(weight: $0.0, reps: $0.1, duration: 0, distance: 0, setType: "working", side: nil) }
        }
        let weeksAgo: [Int] = [10, 8, 6, 4, 2, 0]
        let weights: [[(Double, Int)]] = [
            [(90, 5), (85, 6), (80, 8)],
            [(92.5, 5), (87.5, 6), (82.5, 8)],
            [(95, 5), (90, 6), (85, 8)],
            [(95, 5), (92.5, 6), (87.5, 8)],
            [(100, 4), (95, 6), (90, 8)],
            [(105, 3), (100, 5), (95, 6)],
        ]
        var runningBest = 0.0
        return zip(weeksAgo, weights).map { weeks, pairs in
            let date = cal.date(byAdding: .weekOfYear, value: -weeks, to: now) ?? now
            let bestWeight = pairs.map(\.0).max() ?? 0
            let isPR = bestWeight > runningBest
            runningBest = max(runningBest, bestWeight)
            return LiftHistorySession(date: date, sets: sets(pairs), isPR: isPR)
        }
    }
}

private struct LiftHistorySession: Identifiable {
    let id = UUID()
    let date: Date
    let sets: [FeedSetLog]
    let isPR: Bool

    // Heaviest weight lifted, reps as tiebreak — a strength-progression screen's "best set"
    // means the heaviest load, not the highest weight×reps volume (that's the definition
    // the full session view's BEST column uses; this screen needs a different one, or
    // "BEST EVER" would show a light high-rep set outweighing a heavier low-rep single).
    var bestSet: FeedSetLog? {
        sets.max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }
    var bestWeight: Double { bestSet?.weight ?? 0 }
}
