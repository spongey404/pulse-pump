import SwiftUI
import SwiftData

struct CreateTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var exercises: [TemplateExerciseEntry] = []
    @State private var showExercisePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g. Push Day", text: $name)
                }

                Section("Exercises") {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.exerciseName)
                                .font(.body.weight(.medium))

                            HStack(spacing: 16) {
                                Stepper("Sets: \(exercises[index].targetSets)", value: $exercises[index].targetSets, in: 1...10)
                                    .font(.caption)
                            }
                            HStack(spacing: 16) {
                                Stepper("Reps: \(exercises[index].targetReps)", value: $exercises[index].targetReps, in: 1...50)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        exercises.remove(atOffsets: indexSet)
                    }
                    .onMove { source, destination in
                        exercises.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .foregroundStyle(Color.pumpPrimary)
                    }
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    exercises.append(TemplateExerciseEntry(
                        exerciseId: exercise.id,
                        exerciseName: exercise.name
                    ))
                    showExercisePicker = false
                }
            }
        }
    }

    private func save() {
        let templateExercises = exercises.enumerated().map { index, entry in
            TemplateExercise(
                exerciseId: entry.exerciseId,
                exerciseName: entry.exerciseName,
                order: index,
                targetSets: entry.targetSets,
                targetReps: entry.targetReps
            )
        }

        let template = WorkoutTemplate(
            name: name.trimmingCharacters(in: .whitespaces),
            templateExercises: templateExercises
        )
        modelContext.insert(template)
    }
}

struct TemplateExerciseEntry: Identifiable {
    let id = UUID()
    var exerciseId: UUID
    var exerciseName: String
    var targetSets: Int = 3
    var targetReps: Int = 10
}
