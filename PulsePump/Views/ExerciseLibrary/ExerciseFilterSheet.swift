import SwiftUI

struct ExerciseFilterSheet: View {
    @Binding var selectedMuscleGroups: Set<MuscleGroup>
    @Binding var selectedEquipmentType: EquipmentType?
    @Binding var selectedMovementPattern: MovementPattern?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Muscle Group") {
                    ForEach(BodyRegion.allCases) { region in
                        let muscles = MuscleGroup.allCases.filter { $0.bodyRegion == region }
                        DisclosureGroup(region.displayName) {
                            ForEach(muscles) { muscle in
                                Button {
                                    if selectedMuscleGroups.contains(muscle) {
                                        selectedMuscleGroups.remove(muscle)
                                    } else {
                                        selectedMuscleGroups.insert(muscle)
                                    }
                                } label: {
                                    HStack {
                                        Text(muscle.displayName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedMuscleGroups.contains(muscle) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.accentInk)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Equipment") {
                    ForEach(EquipmentType.allCases) { equipment in
                        Button {
                            selectedEquipmentType = selectedEquipmentType == equipment ? nil : equipment
                        } label: {
                            HStack {
                                Text(equipment.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedEquipmentType == equipment {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentInk)
                                }
                            }
                        }
                    }
                }

                Section("Movement Pattern") {
                    ForEach(MovementPattern.allCases) { pattern in
                        Button {
                            selectedMovementPattern = selectedMovementPattern == pattern ? nil : pattern
                        } label: {
                            HStack {
                                Text(pattern.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedMovementPattern == pattern {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentInk)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if hasActiveFilters {
                        Button("Clear") {
                            selectedMuscleGroups.removeAll()
                            selectedEquipmentType = nil
                            selectedMovementPattern = nil
                        }
                    }
                }
            }
        }
    }

    private var hasActiveFilters: Bool {
        !selectedMuscleGroups.isEmpty || selectedEquipmentType != nil || selectedMovementPattern != nil
    }
}
