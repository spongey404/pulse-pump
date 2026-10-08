import SwiftUI
import SwiftData

struct ExerciseSubstitutionView: View {
    let currentExerciseId: UUID
    let onSelect: (Exercise) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]
    @State private var searchText = ""

    private var currentExercise: Exercise? { allExercises.first { $0.id == currentExerciseId } }

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return allExercises.filter { $0.id != currentExerciseId } }
        return allExercises.filter { $0.id != currentExerciseId && $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("All Exercises") {
                    ForEach(filteredExercises) { exercise in
                        Button { onSelect(exercise) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                                    .font(.mono(11)).foregroundStyle(.secondary)
                            }
                        }.foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// MARK: - Legacy stubs (keep build-compatibility with other files that reference these)
