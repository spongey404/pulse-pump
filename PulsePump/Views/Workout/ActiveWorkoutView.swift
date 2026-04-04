import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showExercisePicker = false
    @State private var searchText = ""

    private var displayedEntries: [(index: Int, entry: ExerciseEntry)] {
        let all = viewModel.exerciseEntries.enumerated().map { (index: $0.offset, entry: $0.element) }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.entry.exerciseName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                workoutHeader

                if viewModel.restTimer.isRunning {
                    RestTimerBanner(restTimer: viewModel.restTimer)
                }

                List {
                    ForEach(displayedEntries, id: \.entry.id) { item in
                        ExerciseCardView(
                            entry: Binding(
                                get: { viewModel.exerciseEntries[item.index] },
                                set: { viewModel.exerciseEntries[item.index] = $0 }
                            ),
                            exerciseIndex: item.index,
                            viewModel: viewModel
                        )
                    }
                    .onMove(perform: searchText.isEmpty ? { source, dest in
                        viewModel.moveExercise(from: source, to: dest)
                    } : nil)
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    WorkoutBottomBar(
                        searchText: $searchText,
                        onAddExercise: { showExercisePicker = true }
                    )
                }
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
    @State private var showNoteEditor = false
    @State private var restOverrideSeconds: Int = 90
    @State private var lastSessionNote: String? = nil
    @State private var pulsePlusService = PulsePlusService()
    @State private var smartSuggestionsEnabled: Bool = UserDefaults.standard.object(forKey: "smartWeightSuggestions") as? Bool ?? true

    var body: some View {
        Section {
            // Exercise title row — swipe left to delete
            HStack {
                Text(entry.exerciseName)
                    .font(.subheadline.weight(.semibold))
                if !entry.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Color.pumpPrimary)
                }
                Spacer()
                Menu {
                    if let lastNote = lastSessionNote {
                        Section("Last session note") {
                            Text(lastNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        showNoteEditor = true
                    } label: {
                        Label(entry.notes.trimmingCharacters(in: .whitespaces).isEmpty ? "Add Note" : "Edit Note",
                              systemImage: "note.text")
                    }
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
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.removeExercise(at: exerciseIndex)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            // Set header — adapts to exercise type
            HStack(spacing: 0) {
                Text("Set")
                    .frame(width: 50, alignment: .leading)
                switch entry.exerciseType {
                case .timeBased:
                    Text("Seconds").frame(maxWidth: .infinity)
                case .distanceBased:
                    Text("Distance").frame(maxWidth: .infinity)
                case .bodyweight:
                    Text("+Weight").frame(maxWidth: .infinity)
                    Text("Reps").frame(maxWidth: .infinity)
                default:
                    Text("Weight").frame(maxWidth: .infinity)
                    Text("Reps").frame(maxWidth: .infinity)
                }
                Text("RIR")
                    .frame(width: 44)
                Text("")
                    .frame(width: 44)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(Array(entry.sets.enumerated()), id: \.element.id) { setIndex, setEntry in
                let suggestion: String? = (pulsePlusService.isSubscribed || pulsePlusService.isInFreeTrial) && smartSuggestionsEnabled
                    ? viewModel.smartWeightSuggestion(for: entry.exerciseId, setIndex: setIndex, modelContext: modelContext)
                    : nil
                SetRowView(
                    setEntry: Binding(
                        get: { entry.sets[setIndex] },
                        set: { entry.sets[setIndex] = $0 }
                    ),
                    setNumber: setIndex + 1,
                    exerciseType: entry.exerciseType,
                    isUnilateral: entry.isUnilateral,
                    ghostText: viewModel.ghostText(for: entry.exerciseId, setIndex: setIndex, modelContext: modelContext),
                    isCompound: true,
                    onLog: {
                        viewModel.logSet(exerciseIndex: exerciseIndex, setIndex: setIndex, isCompound: true)
                    },
                    smartSuggestion: suggestion
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Inline plate calculator — barbell and EZ bar only
            if entry.equipmentType == .barbell || entry.equipmentType == .ezBar {
                InlinePlateView(entry: entry, equipmentType: entry.equipmentType)
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
            }

            // Note preview — shown inline when a note exists
            if !entry.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.notes.trimmingCharacters(in: .whitespaces))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .onTapGesture { showNoteEditor = true }
            }
        }
        .task {
            await pulsePlusService.refreshSubscriptionStatus()
            // Fetch most recent note for this exercise from past logs
            let exId = entry.exerciseId
            let desc = FetchDescriptor<ExerciseLog>(
                predicate: #Predicate<ExerciseLog> { $0.exercise?.id == exId && !$0.notes.isEmpty },
                sortBy: [SortDescriptor(\ExerciseLog.createdAt, order: .reverse)]
            )
            if let log = try? modelContext.fetch(desc).first,
               !log.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                lastSessionNote = log.notes.trimmingCharacters(in: .whitespaces)
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorSheet(notes: $entry.notes, exerciseName: entry.exerciseName)
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

// MARK: - Note Editor Sheet

struct NoteEditorSheet: View {
    @Binding var notes: String
    let exerciseName: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Add a note about this exercise...", text: $notes, axis: .vertical)
                    .lineLimit(4...10)
                    .focused($focused)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top)
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                if !notes.trimmingCharacters(in: .whitespaces).isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear", role: .destructive) {
                            notes = ""
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Workout Bottom Bar

struct WorkoutBottomBar: View {
    @Binding var searchText: String
    let onAddExercise: () -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search exercises...", text: $searchText)
                    .focused($searchFocused)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: onAddExercise) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.pumpPrimary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Inline Plate Calculator

struct InlinePlateView: View {
    let entry: ExerciseEntry
    let equipmentType: EquipmentType

    private var barWeight: Double {
        equipmentType == .ezBar ? 10.0 : 20.0
    }

    private var availablePlates: [Double] {
        if let data = UserDefaults.standard.data(forKey: "customPlates"),
           let plates = try? JSONDecoder().decode([Double].self, from: data) {
            return plates
        }
        return [1.25, 2.5, 5, 10, 15, 20, 25]
    }

    /// Most recently entered weight across all sets, falling back to first with any value.
    private var currentWeight: Double? {
        let weights = entry.sets.compactMap { Double($0.weight) }.filter { $0 > 0 }
        return weights.last
    }

    private var platesPerSide: [(plate: Double, count: Int)] {
        guard let target = currentWeight, target > barWeight else { return [] }
        let perSide = (target - barWeight) / 2.0
        var remaining = perSide
        var counts: [Double: Int] = [:]
        for plate in availablePlates.sorted(by: >) {
            while remaining >= plate - 0.001 {
                counts[plate, default: 0] += 1
                remaining -= plate
            }
        }
        return counts.sorted { $0.key > $1.key }.map { (plate: $0.key, count: $0.value) }
    }

    var body: some View {
        if let weight = currentWeight, weight > barWeight, !platesPerSide.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "scalemass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Per side:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(platesPerSide, id: \.plate) { entry in
                    Text("\(String(format: "%g", entry.plate))×\(entry.count)")
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pumpPrimary.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.vertical, 2)
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
    var exerciseType: ExerciseType = .weighted
    var isUnilateral: Bool = false
    let ghostText: (weight: String, reps: String)?
    let isCompound: Bool
    let onLog: () -> Void
    var smartSuggestion: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                // Set number + type pill
                setNumberAndType

                // Input fields depend on exercise type
                switch exerciseType {
                case .timeBased:
                    TextField("0", text: $setEntry.duration)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.callout.monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(setEntry.isCompleted ? .secondary : .primary)

                case .distanceBased:
                    TextField("0", text: $setEntry.distance)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.callout.monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(setEntry.isCompleted ? .secondary : .primary)

                case .bodyweight:
                    TextField("+kg", text: $setEntry.weight)
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

                default:
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
                }

                TextField("-", text: $setEntry.rir)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.callout.monospacedDigit())
                    .frame(width: 44)
                    .foregroundStyle(setEntry.isCompleted ? .secondary : .primary)

                Button {
                    if !setEntry.isCompleted { onLog() }
                } label: {
                    Image(systemName: setEntry.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(setEntry.isCompleted ? Color.pumpPrimary : .secondary)
                        .font(.title3)
                }
                .frame(width: 44)
                .buttonStyle(.plain)
            }

            // Side picker for unilateral exercises
            if isUnilateral {
                Picker("Side", selection: $setEntry.side) {
                    Text("L").tag(Side.left)
                    Text("R").tag(Side.right)
                    Text("Both").tag(Side.both)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
                .padding(.leading, 50)
                .scaleEffect(0.85, anchor: .leading)
            }

            // Smart suggestion (Pulse+ only)
            if let suggestion = smartSuggestion, setEntry.weight.isEmpty, !setEntry.isCompleted,
               exerciseType == .weighted || exerciseType == .bodyweight {
                Button {
                    setEntry.weight = suggestion
                } label: {
                    Text("Suggested: \(suggestion)")
                        .font(.caption2)
                        .foregroundStyle(Color.pumpPrimary.opacity(0.7))
                        .padding(.leading, 50)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var setNumberAndType: some View {
        Menu {
            ForEach(SetType.allCases) { type in
                Button {
                    setEntry.setType = type
                } label: {
                    HStack {
                        Text(type.displayName)
                        if setEntry.setType == type {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 1) {
                Text("\(setNumber)")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(setEntry.isCompleted ? Color.pumpPrimary : .secondary)
                if setEntry.setType != .standard {
                    Text(setEntry.setType.shortName)
                        .font(.system(size: 8).weight(.semibold))
                        .foregroundStyle(Color.pumpPrimary)
                }
            }
            .frame(width: 50, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
