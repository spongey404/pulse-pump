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
            ChallengeHeader(label: "STEP 1 OF 2", title: "NEW CHALLENGE", onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(title: "Name").padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
                    TextField("Name your challenge", text: $name)
                        .font(.archivo(15, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal, 16)
                        .accessibilityIdentifier(AX.row("Challenge name"))

                    SectionLabel(title: "Measured By").padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
                    VStack(spacing: 0) {
                        ForEach(metrics) { m in
                            metricRow(m)
                        }
                    }
                    .padding(.top, 1).overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    if allowsExercise {
                        Button { showExercisePicker = true } label: {
                            HStack {
                                Text("EXERCISE").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(exerciseName ?? (needsExercise ? "Choose one" : "Any exercise"))
                                        .font(.archivo(15, weight: .semibold))
                                        .foregroundStyle(exerciseName == nil && needsExercise ? Color.signalDown : Color.inkPrimary)
                                    Text("›").font(.spaceMono(12)).foregroundStyle(Color.inkMuted)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        }
                        .buttonStyle(.plain)
                    }

                    SectionLabel(title: "Runs For").padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
                    FlowLayout(spacing: 8) {
                        ForEach(ChallengeWindow.allCases) { w in
                            SocialSmallAction(title: w.label(), style: window == w ? .filled : .outlined) { window = w }
                        }
                    }
                    .padding(.horizontal, 16)
                    if window == .custom {
                        DatePicker("Ends", selection: $customEnd, in: (Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())..., displayedComponents: .date)
                            .font(.archivo(15, weight: .semibold))
                            .padding(.horizontal, 16).padding(.top, 12)
                    }

                    Text("SCORED FROM LOGGED SESSIONS · NOTHING TO ENTER BY HAND · ONLY PEOPLE YOU INVITE CAN JOIN")
                        .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .padding(16)
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SocialDock {
                SocialCTA(title: isCreating ? "…" : "NEXT · INVITE", disabled: !canCreate, id: AX.row("Next invite")) { createAndAdvance() }
            }
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.displayName).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    Text("\(m.unitLabel(weightUnit)) · \(m.rule)".uppercased()).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if selected {
                    Text("✓").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.accentInk)
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12.65)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.activeRowBg : Color.clear)
            .overlay(alignment: .leading) {
                if selected { Rectangle().fill(Color.accentInk).frame(width: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityAddTraits(selected ? .isSelected : [])
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
