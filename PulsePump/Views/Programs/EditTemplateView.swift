import SwiftUI
import SwiftData

struct EditTemplateView: View {
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var exercises: [TemplateExerciseEntry]
    @State private var showExercisePicker = false

    init(template: WorkoutTemplate) {
        self.template = template
        _name = State(initialValue: template.name)
        _exercises = State(initialValue: template.templateExercises.sorted(by: { $0.order < $1.order }).map {
            TemplateExerciseEntry(exerciseId: $0.exerciseId, exerciseName: $0.exerciseName, targetSets: $0.targetSets, targetReps: $0.targetReps)
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("Template name", text: $name)
                }

                Section("Exercises") {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.exerciseName)
                                .font(.body.weight(.medium))

                            Stepper("Sets: \(exercises[index].targetSets)", value: $exercises[index].targetSets, in: 1...10)
                                .font(.caption)

                            if let reps = exercises[index].targetReps {
                                HStack {
                                    Stepper("Reps: \(reps)", value: Binding(
                                        get: { exercises[index].targetReps ?? 10 },
                                        set: { exercises[index].targetReps = $0 }
                                    ), in: 1...50)
                                    .font(.caption)
                                    Button {
                                        exercises[index].targetReps = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Button {
                                    exercises[index].targetReps = 10
                                } label: {
                                    Label("Add target reps", systemImage: "plus")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onDelete { exercises.remove(atOffsets: $0) }
                    .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .foregroundStyle(Color.pumpPrimary)
                    }
                }
            }
            .navigationTitle("Edit Template")
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
        template.name = name.trimmingCharacters(in: .whitespaces)
        template.templateExercises = exercises.enumerated().map { index, entry in
            TemplateExercise(
                exerciseId: entry.exerciseId,
                exerciseName: entry.exerciseName,
                order: index,
                targetSets: entry.targetSets,
                targetReps: entry.targetReps
            )
        }
        template.updatedAt = Date()
    }
}
