import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []
    @State private var selectedEquipmentType: EquipmentType?
    @State private var selectedMovementPattern: MovementPattern?
    @State private var showFilters = false
    @State private var showCreateExercise = false

    private var filteredExercises: [Exercise] {
        exercises.filter { exercise in
            guard exercise.isApproved || exercise.isCustom else { return false }

            if !searchText.isEmpty {
                guard exercise.name.localizedCaseInsensitiveContains(searchText) else { return false }
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

    var body: some View {
        List {
            ForEach(filteredExercises) { exercise in
                NavigationLink(value: exercise) {
                    ExerciseRowView(exercise: exercise)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercises")
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .toolbar {
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.body)
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pumpPrimary.opacity(0.15))
                        .foregroundStyle(Color.pumpPrimary)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 4) {
                Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(exercise.equipmentType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
