import SwiftUI
import SwiftData

struct EquipmentProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EquipmentProfile.name) private var profiles: [EquipmentProfile]
    @State private var showCreate = false
    @State private var selectedId: UUID? = nil
    @State private var showEditEquipment = false

    private var selectedProfile: EquipmentProfile? {
        if let id = selectedId { return profiles.first { $0.id == id } }
        return profiles.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if profiles.isEmpty {
                emptyState
            } else {
                profileTabs
                Rectangle().fill(Color.dsHairLine).frame(height: 1)

                if let profile = selectedProfile {
                    ScrollView {
                        VStack(spacing: 0) {
                            activeProfileBadge
                            equipmentSection(profile)
                            platesSection(profile)
                            addEquipmentButton
                            Color.clear.frame(height: 40)
                        }
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreate) {
            CreateEquipmentProfileView()
        }
        .onAppear {
            if selectedId == nil { selectedId = profiles.first?.id }
        }
        .onChange(of: profiles.count) { _, _ in
            if selectedId == nil { selectedId = profiles.first?.id }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("EQUIPMENT PROFILES")
                .font(.archivo(22, weight: .black))
                .tracking(0.5)
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { showCreate = true } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.pumpAccent)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Profile tabs

    private var profileTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(profiles) { profile in
                    let isActive = profile.id == (selectedId ?? profiles.first?.id)
                    Button { selectedId = profile.id } label: {
                        Text(profile.name.uppercased())
                            .font(.spaceMono(9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(isActive ? .white : Color.inkMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(isActive ? Color.pumpAccent : Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isActive ? Color.accentInk : Color.dsHairLine, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Active badge

    private var activeProfileBadge: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.pumpAccent).frame(width: 6, height: 6)
            Text("ACTIVE PROFILE")
                .font(.spaceMono(9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.accentInk)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.pumpAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentInk.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Equipment section

    private func equipmentSection(_ profile: EquipmentProfile) -> some View {
        VStack(spacing: 0) {
            Text("AVAILABLE EQUIPMENT")
                .font(.spaceMono(9))
                .tracking(1.3)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)

            ForEach(profile.availableEquipment.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { eq in
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.signalUp)
                            .frame(width: 6, height: 6)
                        Text(eq.displayName)
                            .font(.archivo(13, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.inkFaint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                }
            }
        }
    }

    // MARK: - Plates section

    private func platesSection(_ profile: EquipmentProfile) -> some View {
        let plates = profile.availablePlates.sorted()  // ascending: 1.25 → 25

        return VStack(spacing: 0) {
            Text("AVAILABLE PLATES")
                .font(.spaceMono(9))
                .tracking(1.3)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            // Barbell visualization
            // Left side: smallest outermost → ascending order rendered left to right
            // Right side: largest innermost → descending order rendered left to right
            HStack(spacing: 0) {
                Spacer()
                // Left plates (outer→inner = ascending, so 1.25 at far left)
                HStack(spacing: 2) {
                    ForEach(plates, id: \.self) { plate in
                        plateRect(plate)
                    }
                }
                // Bar
                HStack(spacing: 0) {
                    // Left collar stub
                    Rectangle()
                        .fill(Color(hex: "#8a857c"))
                        .frame(width: 8, height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                    // Main bar rod
                    Rectangle()
                        .fill(Color(hex: "#8a857c"))
                        .frame(width: 40, height: 5)
                    // Right collar stub
                    Rectangle()
                        .fill(Color(hex: "#8a857c"))
                        .frame(width: 8, height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                }
                // Right plates (inner→outer = descending, so 25 at left/inner, 1.25 at far right)
                HStack(spacing: 2) {
                    ForEach(plates.reversed(), id: \.self) { plate in
                        plateRect(plate)
                    }
                }
                Spacer()
            }
            .frame(height: 50)
            .padding(.bottom, 12)

            // Plate chips
            HStack(spacing: 5) {
                ForEach(plates, id: \.self) { plate in
                    Text("\(formatPlate(plate))KG")
                        .font(.spaceMono(9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(plateColor(plate))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    private func plateRect(_ plate: Double) -> some View {
        let h: CGFloat = 20 + min(plate, 25) * 0.7
        let w: CGFloat = plate >= 20 ? 9 : plate >= 10 ? 7 : plate >= 5 ? 6 : 5
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(plateColor(plate))
            .overlay(RoundedRectangle(cornerRadius: 1.5).strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5))
            .frame(width: w, height: h)
    }

    private func plateColor(_ plate: Double) -> Color {
        switch plate {
        case 25:   return Color(hex: "#e51b1b")
        case 20:   return Color(hex: "#1f4ea3")
        case 15:   return Color(hex: "#c98a17")
        case 10:   return Color(hex: "#1f8f5a")
        case 5:    return Color(hex: "#1f1c19")
        case 2.5:  return Color(hex: "#a3a39a")
        case 1.25: return Color(hex: "#b8b4a6")
        default:   return Color.inkMuted
        }
    }

    private func formatPlate(_ plate: Double) -> String {
        plate == floor(plate) ? "\(Int(plate))" : "\(plate)"
    }

    // MARK: - Add equipment button

    private var addEquipmentButton: some View {
        Button { } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                Text("ADD EQUIPMENT").font(.spaceMono(10)).tracking(0.8)
            }
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.inkFaint)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("NO PROFILES YET")
                .font(.archivo(24, weight: .black))
                .foregroundStyle(Color.inkFaint)
            Text("Create a profile for your gym to track available equipment.")
                .font(.archivo(13))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Button { showCreate = true } label: {
                Text("CREATE PROFILE")
                    .font(.archivo(14, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .background(Color.pumpAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 32)
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
                                        .foregroundStyle(Color.accentInk)
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
