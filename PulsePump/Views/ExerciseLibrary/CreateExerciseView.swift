import SwiftUI
import SwiftData

struct CreateExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var primaryMuscleGroups: Set<MuscleGroup> = []
    @State private var secondaryMuscleGroups: Set<MuscleGroup> = []
    @State private var equipmentType: EquipmentType = .barbell
    @State private var movementPattern: MovementPattern = .push
    @State private var exerciseType: ExerciseType = .weighted
    @State private var isUnilateral = false
    @State private var submitToCommunity = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !primaryMuscleGroups.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Exercise name", text: $name)
                }

                Section("Primary Muscle Groups") {
                    MuscleGroupPicker(selected: $primaryMuscleGroups)
                }

                Section("Secondary Muscle Groups") {
                    MuscleGroupPicker(selected: $secondaryMuscleGroups)
                }

                Section("Details") {
                    Picker("Equipment", selection: $equipmentType) {
                        ForEach(EquipmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Picker("Movement Pattern", selection: $movementPattern) {
                        ForEach(MovementPattern.allCases) { pattern in
                            Text(pattern.displayName).tag(pattern)
                        }
                    }

                    Picker("Exercise Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Toggle("Unilateral (per side)", isOn: $isUnilateral)
                }

                Section {
                    Toggle("Submit to community library", isOn: $submitToCommunity)
                } footer: {
                    Text("Community submissions require approval before appearing in the public library.")
                }
            }
            .navigationTitle("New Exercise")
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
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
            primaryMuscleGroups: Array(primaryMuscleGroups),
            secondaryMuscleGroups: Array(secondaryMuscleGroups),
            equipmentType: equipmentType,
            movementPattern: movementPattern,
            exerciseType: exerciseType,
            isCustom: true,
            isApproved: !submitToCommunity,
            isUnilateral: isUnilateral
        )
        modelContext.insert(exercise)
    }
}

struct MuscleGroupPicker: View {
    @Binding var selected: Set<MuscleGroup>

    var body: some View {
        ForEach(BodyRegion.allCases) { region in
            let muscles = MuscleGroup.allCases.filter { $0.bodyRegion == region }
            DisclosureGroup(region.displayName) {
                ForEach(muscles) { muscle in
                    Button {
                        if selected.contains(muscle) {
                            selected.remove(muscle)
                        } else {
                            selected.insert(muscle)
                        }
                    } label: {
                        HStack {
                            Text(muscle.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected.contains(muscle) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.pumpPrimary)
                            }
                        }
                    }
                }
            }
        }
    }
}
