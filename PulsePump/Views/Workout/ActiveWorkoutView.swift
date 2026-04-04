import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showExercisePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                workoutHeader

                if viewModel.restTimer.isRunning {
                    RestTimerBanner(restTimer: viewModel.restTimer)
                }

                List {
                    ForEach(Array(viewModel.exerciseEntries.enumerated()), id: \.element.id) { index, entry in
                        ExerciseCardView(
                            entry: Binding(
                                get: { viewModel.exerciseEntries[index] },
                                set: { viewModel.exerciseEntries[index] = $0 }
                            ),
                            exerciseIndex: index,
                            viewModel: viewModel
                        )
                    }
                    .onMove { source, destination in
                        viewModel.moveExercise(from: source, to: destination)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .foregroundStyle(Color.pumpPrimary)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showCancelConfirmation = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        viewModel.completeWorkout(modelContext: modelContext)
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Cancel Workout?", isPresented: $viewModel.showCancelConfirmation) {
                Button("Discard Workout", role: .destructive) {
                    viewModel.cancelWorkout(modelContext: modelContext)
                }
                Button("Save as Draft") {
                    viewModel.saveDraft()
                    viewModel.isActive = false
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Your workout data will be lost if you discard.")
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addExercise(exercise)
                    showExercisePicker = false
                }
            }
        }
    }

    private var workoutHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.formattedDuration)
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !viewModel.exerciseEntries.isEmpty {
                let totalSets = viewModel.exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
                VStack(alignment: .center, spacing: 2) {
                    Text("\(totalSets)")
                        .font(.title3.weight(.semibold))
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.liveCalories > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(viewModel.liveCalories))")
                            .font(.title3.weight(.semibold))
                        Text("cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Rest Timer Banner

struct RestTimerBanner: View {
    let restTimer: RestTimerService

    var body: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(Color.pumpPrimary)
            Text("Rest: \(restTimer.formattedTime)")
                .font(.callout.monospacedDigit().weight(.medium))
            Spacer()
            ProgressView(value: restTimer.progress)
                .tint(Color.pumpPrimary)
                .frame(width: 60)
            Button("Skip") {
                restTimer.dismiss()
            }
            .font(.caption.weight(.medium))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.pumpPrimary.opacity(0.1))
    }
}

// MARK: - Exercise Card

struct ExerciseCardView: View {
    @Binding var entry: ExerciseEntry
    let exerciseIndex: Int
    let viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showSubstitutionSheet = false
    @State private var showRestOverride = false
    @State private var restOverrideSeconds: Int = 90

    var body: some View {
        Section {
            // Set header
            HStack(spacing: 0) {
                Text("Set")
                    .frame(width: 36, alignment: .leading)
                Text("Weight")
                    .frame(maxWidth: .infinity)
                Text("Reps")
                    .frame(maxWidth: .infinity)
                Text("RIR")
                    .frame(width: 50)
                Text("")
                    .frame(width: 44)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(Array(entry.sets.enumerated()), id: \.element.id) { setIndex, setEntry in
                SetRowView(
                    setEntry: Binding(
                        get: { entry.sets[setIndex] },
                        set: { entry.sets[setIndex] = $0 }
                    ),
                    setNumber: setIndex + 1,
                    ghostText: viewModel.ghostText(for: entry.exerciseId, setIndex: setIndex, modelContext: modelContext),
                    isCompound: true,
                    onLog: {
                        viewModel.logSet(exerciseIndex: exerciseIndex, setIndex: setIndex, isCompound: true)
                    }
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            HStack {
                Button {
                    viewModel.addSet(to: exerciseIndex)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(Color.pumpPrimary)
                }

                Spacer()

                if entry.notes.isEmpty {
                    Button {
                        entry.notes = " "
                    } label: {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !entry.notes.isEmpty {
                TextField("Exercise notes...", text: $entry.notes, axis: .vertical)
                    .font(.caption)
                    .lineLimit(1...3)
            }
        } header: {
            HStack {
                Text(entry.exerciseName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    Button {
                        showSubstitutionSheet = true
                    } label: {
                        Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        restOverrideSeconds = RestTimerService.perExerciseOverride(exerciseId: entry.exerciseId) ?? 90
                        showRestOverride = true
                    } label: {
                        Label("Rest Timer Override", systemImage: "timer")
                    }
                    Button(role: .destructive) {
                        viewModel.removeExercise(at: exerciseIndex)
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showSubstitutionSheet) {
            ExerciseSubstitutionView(
                currentExerciseId: entry.exerciseId,
                onSelect: { newExercise in
                    entry.exerciseId = newExercise.id
                    entry.exerciseName = newExercise.name
                    showSubstitutionSheet = false
                }
            )
        }
        .alert("Rest Timer Override", isPresented: $showRestOverride) {
            TextField("Seconds", value: $restOverrideSeconds, format: .number)
                .keyboardType(.numberPad)
            Button("Save") {
                RestTimerService.setPerExerciseOverride(exerciseId: entry.exerciseId, seconds: restOverrideSeconds)
            }
            Button("Reset to Default", role: .destructive) {
                RestTimerService.setPerExerciseOverride(exerciseId: entry.exerciseId, seconds: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Set custom rest duration in seconds for \(entry.exerciseName)")
        }
    }
}

// MARK: - Exercise Substitution

struct ExerciseSubstitutionView: View {
    let currentExerciseId: UUID
    let onSelect: (Exercise) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]
    @State private var searchText = ""
    @State private var pulsePlusService = PulsePlusService()

    private var currentExercise: Exercise? {
        allExercises.first { $0.id == currentExerciseId }
    }

    private var smartSuggestions: [Exercise] {
        guard let current = currentExercise else { return [] }
        return allExercises.filter { exercise in
            exercise.id != currentExerciseId &&
            !Set(exercise.primaryMuscleGroups).intersection(current.primaryMuscleGroups).isEmpty
        }
        .sorted { a, b in
            let aMatch = Set(a.primaryMuscleGroups).intersection(currentExercise?.primaryMuscleGroups ?? []).count
            let bMatch = Set(b.primaryMuscleGroups).intersection(currentExercise?.primaryMuscleGroups ?? []).count
            return aMatch > bMatch
        }
    }

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return allExercises.filter { $0.id != currentExerciseId } }
        return allExercises.filter {
            $0.id != currentExerciseId &&
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if pulsePlusService.isSubscribed && !smartSuggestions.isEmpty && searchText.isEmpty {
                    Section("Smart Suggestions") {
                        ForEach(smartSuggestions.prefix(5)) { exercise in
                            Button {
                                onSelect(exercise)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.body)
                                    Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                Section("All Exercises") {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            onSelect(exercise)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.body)
                                Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await pulsePlusService.refreshSubscriptionStatus()
            }
        }
    }
}

// MARK: - Set Row

struct SetRowView: View {
    @Binding var setEntry: SetEntry
    let setNumber: Int
    let ghostText: (weight: String, reps: String)?
    let isCompound: Bool
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("\(setNumber)")
                .font(.callout.weight(.medium))
                .foregroundStyle(setEntry.isCompleted ? Color.pumpPrimary : .secondary)
                .frame(width: 36, alignment: .leading)

            TextField(ghostText?.weight ?? "0", text: $setEntry.weight)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.callout.monospacedDigit())
                .frame(maxWidth: .infinity)
                .foregroundStyle(setEntry.isCompleted ? .secondary : .primary)

            TextField(ghostText?.reps ?? "0", text: $setEntry.reps)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.callout.monospacedDigit())
                .frame(maxWidth: .infinity)
                .foregroundStyle(setEntry.isCompleted ? .secondary : .primary)

            TextField("-", text: $setEntry.rir)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.callout.monospacedDigit())
                .frame(width: 50)
                .foregroundStyle(setEntry.isCompleted ? .secondary : .primary)

            Button {
                if !setEntry.isCompleted {
                    onLog()
                }
            } label: {
                Image(systemName: setEntry.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(setEntry.isCompleted ? Color.pumpPrimary : .secondary)
                    .font(.title3)
            }
            .frame(width: 44)
            .buttonStyle(.plain)
        }
    }
}
