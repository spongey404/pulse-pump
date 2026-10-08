import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    var onSelect: ((Exercise) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []
    @State private var selectedEquipmentType: EquipmentType?
    @State private var selectedMovementPattern: MovementPattern?
    @State private var showFilters = false
    @State private var showCreateExercise = false

    private var isSelectionMode: Bool { onSelect != nil }

    private var filteredExercises: [Exercise] {
        exercises.filter { exercise in
            guard exercise.isApproved || exercise.isCustom else { return false }

            if !searchText.isEmpty {
                guard exercise.name.hasWordPrefix(searchText) else { return false }
            }

            if !selectedMuscleGroups.isEmpty {
                let exerciseMuscles = Set(exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups)
                guard !exerciseMuscles.isDisjoint(with: selectedMuscleGroups) else { return false }
            }

            if let equipment = selectedEquipmentType {
                guard exercise.equipmentType == equipment else { return false }
            }

            if let pattern = selectedMovementPattern {
                guard exercise.movementPattern == pattern else { return false }
            }

            return true
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if !selectedMuscleGroups.isEmpty { count += 1 }
        if selectedEquipmentType != nil { count += 1 }
        if selectedMovementPattern != nil { count += 1 }
        return count
    }

    private var pendingSubmissions: [Exercise] {
        exercises.filter { $0.isCustom && !$0.isApproved }
    }

    var body: some View {
        List {
            if !pendingSubmissions.isEmpty && searchText.isEmpty {
                Section("Pending Submissions") {
                    ForEach(pendingSubmissions) { exercise in
                        NavigationLink(value: exercise) {
                            HStack {
                                ExerciseRowView(exercise: exercise)
                                Spacer()
                                Text("Pending")
                                    .font(.mono(9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            ForEach(filteredExercises) { exercise in
                if isSelectionMode {
                    Button {
                        onSelect?(exercise)
                        dismiss()
                    } label: {
                        ExerciseRowView(exercise: exercise)
                    }
                    .foregroundStyle(Color.inkPrimary)
                } else {
                    NavigationLink(value: exercise) {
                        ExerciseRowView(exercise: exercise)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle(isSelectionMode ? "Replace Exercise" : "Exercises")
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .toolbar {
            if isSelectionMode {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Label("Filter", systemImage: activeFilterCount > 0
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            ExerciseFilterSheet(
                selectedMuscleGroups: $selectedMuscleGroups,
                selectedEquipmentType: $selectedEquipmentType,
                selectedMovementPattern: $selectedMovementPattern
            )
        }
        .sheet(isPresented: $showCreateExercise) {
            CreateExerciseView()
        }
        .onAppear {
            ExerciseSeedService.seedIfNeeded(modelContext: modelContext)
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Movement pattern icon
            ZStack {
                Circle()
                    .fill(Color.pumpAccent.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: exercise.movementPattern.sfSymbol)
                    .font(.mono(16, weight: .medium))
                    .foregroundStyle(Color.accentInk)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.mono(16))
                    if exercise.isCustom {
                        Text("CUSTOM")
                            .font(.spaceMono(8))
                            .tracking(0.5)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pumpAccent.opacity(0.10))
                            .foregroundStyle(Color.accentInk)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.mono(11))
                        .foregroundStyle(.tertiary)
                    Text(exercise.equipmentType.displayName)
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
