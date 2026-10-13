import SwiftUI
import SwiftData
import FirebaseAuth

struct StartWorkoutDock: View {
    @Bindable var viewModel: WorkoutViewModel
    var overrideName: String? = nil
    var onRequestDiscard: ((Workout) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { $0.isDraft }, sort: \Workout.updatedAt, order: .reverse)
    private var drafts: [Workout]

    private var user: User? { users.first }
    private var draft: Workout? { drafts.first }

    private var draftSetsDone: Int {
        draft?.exerciseLogs.flatMap(\.sets).count ?? 0
    }

    private var draftProgress: Double {
        guard let draft else { return 0 }
        let target = draft.template?.templateExercises.reduce(0) { $0 + $1.targetSets } ?? 0
        let done = draft.exerciseLogs.flatMap(\.sets).count
        guard target > 0 else { return 0 }
        return min(1.0, Double(done) / Double(target))
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.inkPrimary.opacity(0.08)).frame(height: 1)

            if let user {
                if let draft {
                    draftDock(draft: draft, user: user)
                } else {
                    startDock(user: user)
                }
            }
        }
        .background(Color.canvasBg)
    }

    // MARK: Draft state

    private func draftDock(draft: Workout, user: User) -> some View {
        VStack(spacing: 0) {
            // "START NEW WORKOUT" link
            Button("START NEW WORKOUT") {
                onRequestDiscard?(draft)
            }
            .font(Font.mono(10, weight: .medium))
            .tracking(1)
            .foregroundStyle(Color.inkMuted)
            .padding(.top, 10)
            .accessibilityIdentifier(AX.home.startNew)

            // Continue bar
            Button {
                viewModel.resumeDraft(workout: draft, modelContext: modelContext)
            } label: {
                ZStack(alignment: .leading) {
                    // Base
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surf)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.accentInk.opacity(0.33), lineWidth: 1)
                        )

                    // Progress fill
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pumpAccent.opacity(0.18))
                            .frame(width: geo.size.width * draftProgress)
                    }

                    // Content
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("CONTINUE")
                                .font(.spaceMono(8))
                                .tracking(1.5)
                                .foregroundStyle(Color.inkMuted)
                            Text((draft.template?.name ?? "WORKOUT").uppercased())
                                .font(.archivo(20, weight: .black))
                                .foregroundStyle(Color.accentInk)
                            Text("\(draftSetsDone) SETS DONE")
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Text("TAP TO RESUME ›")
                            .font(.spaceMono(9))
                            .tracking(0.5)
                            .foregroundStyle(Color.accentInk)
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
            .accessibilityIdentifier(AX.home.continueDraft)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
    }

    // MARK: Start state

    private func startDock(user: User) -> some View {
        let predictionName = overrideName ?? viewModel.predictNextWorkout(user: user, modelContext: modelContext)
        let allTemplates: [WorkoutTemplate] = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        let predictedTemplate = predictionName.flatMap { name in
            allTemplates.first { $0.name.lowercased() == name.lowercased() }
        }
        let splitLbl = detectSplitLabel(modelContext: modelContext)
        let estMins = predictedTemplate.flatMap { t -> Int? in
            let workoutDescriptor = FetchDescriptor<Workout>(
                predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
            )
            let recentWorkouts = (try? modelContext.fetch(workoutDescriptor)) ?? []
            guard let last = recentWorkouts.first(where: { $0.template?.name == t.name }),
                  last.duration > 60 else { return nil }
            return Int(last.duration / 60)
        } ?? 55

        return Button {
            viewModel.startWorkout(modelContext: modelContext, user: user, template: predictedTemplate)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pumpAccent)
                    .shadow(color: Color.pumpAccent.opacity(0.35), radius: 8, y: 3)

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TODAY · \(splitLbl)")
                            .font(.spaceMono(8))
                            .tracking(1.5)
                            .foregroundStyle(Color.white.opacity(0.60))
                        Text((predictionName ?? "WORKOUT").uppercased())
                            .font(.archivo(20, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("~\(estMins) MIN")
                            .font(.spaceMono(8))
                            .foregroundStyle(Color.white.opacity(0.60))
                        Text("START WORKOUT ›")
                            .font(.archivo(16, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 54)
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
        .accessibilityIdentifier(AX.home.startWorkout)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    private func detectSplitLabel(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
        )
        let recent = (try? modelContext.fetch(descriptor))?.prefix(9) ?? []
        let names = recent.compactMap { $0.template?.name.lowercased() }
        let hasPush = names.contains { $0.contains("push") }
        let hasPull = names.contains { $0.contains("pull") }
        let hasLegs = names.contains { $0.contains("leg") }
        if hasPush && hasPull && hasLegs { return "PPL" }
        let hasUpper = names.contains { $0.contains("upper") }
        let hasLower = names.contains { $0.contains("lower") }
        if hasUpper && hasLower { return "U/L" }
        if names.contains(where: { $0.contains("full") }) { return "FULL BODY" }
        return "PROGRAM"
    }
}

// MARK: - Programs Tab
