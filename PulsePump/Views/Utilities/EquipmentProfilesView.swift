import SwiftUI
import SwiftData

struct EquipmentProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EquipmentProfile.name) private var profiles: [EquipmentProfile]
    @State private var showCreate = false

    var body: some View {
        List {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Equipment Profiles",
                    systemImage: "dumbbell",
                    description: Text("Create profiles for different gyms to track available equipment.")
                )
            } else {
                ForEach(profiles) { profile in
                    NavigationLink(value: profile) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.body.weight(.medium))
                            Text("\(profile.availableEquipment.count) equipment types")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(profile)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Equipment Profiles")
        .navigationDestination(for: EquipmentProfile.self) { profile in
            EquipmentProfileDetailView(profile: profile)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateEquipmentProfileView()
        }
    }
}

struct EquipmentProfileDetailView: View {
    let profile: EquipmentProfile

    var body: some View {
        List {
            Section("Equipment") {
                ForEach(profile.availableEquipment, id: \.self) { equipment in
                    Text(equipment.displayName)
                }
            }

            Section("Plates") {
                ForEach(profile.availablePlates.sorted(), id: \.self) { plate in
                    Text("\(String(format: "%g", plate)) kg")
                }
            }

            Section("Bars") {
                ForEach(profile.barTypes) { bar in
                    HStack {
                        Text(bar.name)
                        Spacer()
                        Text("\(String(format: "%g", bar.weightKg)) kg")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(profile.name)
    }
}

struct CreateEquipmentProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedEquipment: Set<EquipmentType> = Set(EquipmentType.allCases)

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Home Gym", text: $name)
                }

                Section("Available Equipment") {
                    ForEach(EquipmentType.allCases) { equipment in
                        Button {
                            if selectedEquipment.contains(equipment) {
                                selectedEquipment.remove(equipment)
                            } else {
                                selectedEquipment.insert(equipment)
                            }
                        } label: {
                            HStack {
                                Text(equipment.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedEquipment.contains(equipment) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.pumpPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let profile = EquipmentProfile(
                            name: name.trimmingCharacters(in: .whitespaces),
                            availableEquipment: Array(selectedEquipment)
                        )
                        modelContext.insert(profile)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
