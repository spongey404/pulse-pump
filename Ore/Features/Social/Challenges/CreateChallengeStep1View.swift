import SwiftUI

/// 5a — Create challenge, step 1: name + metric + window. Tapping NEXT creates the challenge (per
/// spec it already exists by step 2 — invites are added, not "created"). Challenges created here
/// are private to the people invited; scoring is done by the backend from logged sessions, so the
/// "Custom" metric (which would need hand-entered scores) is not offered.
struct CreateChallengeStep1View: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit

    @State private var name = ""
    @State private var metric: ChallengeMetric = .totalVolume
    @State private var window: ChallengeWindow = .fourWeeks
    @State private var customEnd = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var exerciseName: String?
    @State private var isCreating = false
    @State private var created: SocialChallenge?
    @State private var showInvite = false
    @State private var showExercisePicker = false

    private var metrics: [ChallengeMetric] { ChallengeMetric.allCases.filter { $0 != .custom } }
    private var needsExercise: Bool { metric == .heaviestLift }
    private var allowsExercise: Bool { metric == .heaviestLift || metric == .mostReps || metric == .longestHold }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canCreate: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 100 && !isCreating && (!needsExercise || exerciseName != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: "NEW CHALLENGE", onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField("Name your challenge", text: $name)
                            .font(.archivo(20, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .padding(.top, 16)
                    .frame(minHeight: 44, alignment: .bottom)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleStrong).frame(height: 1) }

                    SectionLabel(title: "Measured By").padding(.top, 24).padding(.bottom, 8)
                    ForEach(metrics) { m in
                        metricRow(m)
                    }

                    if allowsExercise {
                        Button { showExercisePicker = true } label: {
                            HStack {
                                Text("EXERCISE").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(exerciseName ?? (needsExercise ? "Choose one" : "Any exercise"))
                                        .font(.archivo(15, weight: .semibold))
                                        .foregroundStyle(exerciseName == nil && needsExercise ? Color.signalDown : Color.inkPrimary)
                                    Text("›").font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
                                }
                            }
                            .frame(minHeight: 44)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }

                    SectionLabel(title: "Runs For").padding(.top, 24).padding(.bottom, 10)
                    FlowLayout(spacing: 8) {
                        ForEach(ChallengeWindow.allCases) { w in
                            FilterChip(title: w.label(), isSelected: window == w) { window = w }
                        }
                    }
                    if window == .custom {
                        DatePicker("Ends", selection: $customEnd, in: (Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())..., displayedComponents: .date)
                            .font(.archivo(15, weight: .semibold))
                            .padding(.top, 12)
                    }

                    Text("SCORED FROM LOGGED SESSIONS · NOTHING TO ENTER BY HAND · ONLY PEOPLE YOU INVITE CAN JOIN")
                        .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            DockedCTA(leadingText: "STEP 2 · INVITE FRIENDS", primaryLabel: isCreating ? "…" : "NEXT ›", style: .quiet) {
                createAndAdvance()
            }
            .disabled(!canCreate)
            .opacity(canCreate ? 1 : 0.5)
        }
        .navigationDestination(isPresented: $showInvite) {
            if let created { InviteFriendsView(viewModel: viewModel, challenge: created) }
        }
        // Same presentation the logging screen uses for its exercise picker — a full screen, not a sheet.
        .fullScreenCover(isPresented: $showExercisePicker) {
            ExercisePickerView(title: "SELECT EXERCISE") { exercises in
                if let first = exercises.first { exerciseName = first.name }
                showExercisePicker = false
            }
        }
        .onChange(of: metric) { _, _ in
            if !allowsExercise { exerciseName = nil }
        }
    }

    private func metricRow(_ m: ChallengeMetric) -> some View {
        let selected = metric == m
        return Button { metric = m } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.displayName).font(.archivo(16, weight: selected ? .bold : .regular)).foregroundStyle(Color.inkPrimary)
                    Text("\(m.unitLabel(weightUnit)) · \(m.rule)").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                Spacer()
                if selected {
                    Text("✓").font(Font.spaceMono(13, weight: .bold)).foregroundStyle(Color.accentInk)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 56)
            .background(selected ? Color.activeRowBg : Color.clear)
            .overlay(alignment: .leading) {
                if selected { Rectangle().fill(Color.oreAccent).frame(width: 2) }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func createAndAdvance() {
        isCreating = true
        let start = Date()
        let draft = ChallengeDraft(
            name: trimmedName, metric: metric, exerciseName: allowsExercise ? exerciseName : nil,
            startAt: start, endAt: window.endDate(from: start, customEnd: customEnd),
            visibility: .invite, winCondition: .highest)
        Task {
            let id = await viewModel.createChallenge(draft)
            isCreating = false
            guard let id else { return }
            created = viewModel.myChallenges.first { $0.id == id } ?? SocialChallenge(
                id: id, creatorUid: viewModel.currentUid ?? "", name: draft.name, metric: draft.metric,
                exerciseName: draft.exerciseName, startAt: draft.startAt, endAt: draft.endAt, isGlobal: false,
                visibility: draft.visibility, status: .active, memberCount: 1, winCondition: draft.winCondition)
            showInvite = true
        }
    }
}
