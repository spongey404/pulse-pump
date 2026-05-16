import SwiftUI
import SwiftData

// MARK: - Card-based exercise creation flow

struct CreateExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var name = ""
    @State private var primaryMuscleGroups: Set<MuscleGroup> = []
    @State private var secondaryMuscleGroups: Set<MuscleGroup> = []
    @State private var primarySubRegions: Set<MuscleSubRegion> = []
    @State private var secondarySubRegions: Set<MuscleSubRegion> = []
    @State private var equipmentType: EquipmentType = .barbell
    @State private var movementPattern: MovementPattern = .push
    @State private var exerciseType: ExerciseType = .weighted
    @State private var isUnilateral = false
    @State private var submitToCommunity = false

    private let totalSteps = 5

    private var canAdvance: Bool {
        switch step {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !primaryMuscleGroups.isEmpty
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step progress dots
                StepProgressIndicator(current: step, total: totalSteps)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Card content
                TabView(selection: $step) {
                    NameStepCard(name: $name)
                        .tag(0)
                    MuscleSelectCard(
                        title: "Primary muscles",
                        subtitle: "What does this exercise mainly target?",
                        selected: $primaryMuscleGroups,
                        selectedSubRegions: $primarySubRegions,
                        excluded: []
                    )
                    .tag(1)
                    MuscleSelectCard(
                        title: "Secondary muscles",
                        subtitle: "Any muscles worked as a bonus? (optional)",
                        selected: $secondaryMuscleGroups,
                        selectedSubRegions: $secondarySubRegions,
                        excluded: primaryMuscleGroups
                    )
                    .tag(2)
                    DetailsStepCard(
                        equipmentType: $equipmentType,
                        movementPattern: $movementPattern,
                        exerciseType: $exerciseType,
                        isUnilateral: $isUnilateral
                    )
                    .tag(3)
                    ReviewStepCard(
                        name: name,
                        primaryMuscles: primaryMuscleGroups,
                        secondaryMuscles: secondaryMuscleGroups,
                        equipment: equipmentType,
                        pattern: movementPattern,
                        type: exerciseType,
                        isUnilateral: isUnilateral,
                        submitToCommunity: $submitToCommunity
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: step)

                // Navigation buttons
                HStack(spacing: 16) {
                    if step > 0 {
                        Button {
                            withAnimation { step -= 1 }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.surf)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    if step < totalSteps - 1 {
                        Button {
                            withAnimation { step += 1 }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(canAdvance ? Color.pumpAccent : Color.inkFaint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdvance)
                    } else {
                        Button {
                            save()
                            dismiss()
                        } label: {
                            Text("Save Exercise")
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.pumpAccent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            isUnilateral: isUnilateral,
            primarySubRegions: Array(primarySubRegions),
            secondarySubRegions: Array(secondarySubRegions)
        )
        modelContext.insert(exercise)
    }
}

// MARK: - Step Progress Dots

struct StepProgressIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.pumpAccent : Color.inkFaint)
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}

// MARK: - Step 1: Name

struct NameStepCard: View {
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("What's the exercise called?")
                    .font(.display(22))
                    .multilineTextAlignment(.center)
                Text("Give it a clear, recognisable name.")
                    .font(.mono(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("e.g. Barbell Bench Press", text: $name)
                .font(.display(20))
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .focused($focused)
                .submitLabel(.next)
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .onAppear { focused = true }
    }
}

// MARK: - Step 2 & 3: Muscle Selection

struct MuscleSelectCard: View {
    let title: String
    let subtitle: String
    @Binding var selected: Set<MuscleGroup>
    @Binding var selectedSubRegions: Set<MuscleSubRegion>
    let excluded: Set<MuscleGroup>
    @State private var search = ""

    private var available: [MuscleGroup] {
        let all = MuscleGroup.allCases.filter { !excluded.contains($0) }
        guard !search.isEmpty else { return all }
        return all.filter { $0.displayName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.display(22))
                Text(subtitle)
                    .font(.mono(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Selected chips
            if !selected.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selected).sorted { $0.displayName < $1.displayName }) { muscle in
                            HStack(spacing: 4) {
                                Text(muscle.displayName)
                                    .font(.mono(11, weight: .medium))
                                Button {
                                    selected.remove(muscle)
                                    for sub in MuscleSubRegion.subRegions(for: muscle) {
                                        selectedSubRegions.remove(sub)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.mono(9, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.pumpAccent.opacity(0.15))
                            .foregroundStyle(Color.pumpAccent)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search muscles...", text: $search)
                    .autocorrectionDisabled()
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Muscle list
            List(available) { muscle in
                let subRegions = MuscleSubRegion.subRegions(for: muscle)
                let isSelected = selected.contains(muscle)
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        if isSelected {
                            selected.remove(muscle)
                            for sub in subRegions { selectedSubRegions.remove(sub) }
                        } else {
                            selected.insert(muscle)
                        }
                    } label: {
                        HStack {
                            Text(muscle.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.pumpAccent)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(Color.inkFaint)
                            }
                        }
                    }

                    // Sub-regions inline when selected
                    if isSelected && !subRegions.isEmpty {
                        ForEach(subRegions) { sub in
                            Button {
                                if selectedSubRegions.contains(sub) {
                                    selectedSubRegions.remove(sub)
                                } else {
                                    selectedSubRegions.insert(sub)
                                }
                            } label: {
                                HStack {
                                    Text(sub.displayName)
                                        .font(.mono(14))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: selectedSubRegions.contains(sub) ? "checkmark.circle.fill" : "circle")
                                        .font(.mono(14))
                                        .foregroundStyle(selectedSubRegions.contains(sub) ? Color.pumpAccent : Color.inkFaint)
                                }
                                .padding(.leading, 16)
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Step 4: Details

struct DetailsStepCard: View {
    @Binding var equipmentType: EquipmentType
    @Binding var movementPattern: MovementPattern
    @Binding var exerciseType: ExerciseType
    @Binding var isUnilateral: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 8) {
                    Text("Exercise details")
                        .font(.display(22))
                    Text("Tell us more about how it's performed.")
                        .font(.mono(14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

                // Equipment
                VStack(alignment: .leading, spacing: 10) {
                    Text("Equipment")
                        .font(.mono(14, weight: .medium))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(EquipmentType.allCases) { type in
                                ChipButton(
                                    label: type.displayName,
                                    icon: type.sfSymbol,
                                    isSelected: equipmentType == type
                                ) { equipmentType = type }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Movement pattern
                VStack(alignment: .leading, spacing: 10) {
                    Text("Movement pattern")
                        .font(.mono(14, weight: .medium))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(MovementPattern.allCases) { pattern in
                                ChipButton(
                                    label: pattern.displayName,
                                    icon: pattern.sfSymbol,
                                    isSelected: movementPattern == pattern
                                ) { movementPattern = pattern }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Exercise type
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tracking type")
                        .font(.mono(14, weight: .medium))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ExerciseType.allCases) { type in
                                ChipButton(
                                    label: type.displayName,
                                    icon: nil,
                                    isSelected: exerciseType == type
                                ) { exerciseType = type }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Unilateral toggle
                Toggle("Unilateral (log each side separately)", isOn: $isUnilateral)
                    .padding()
                    .background(Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
    }
}

// MARK: - Chip Button

struct ChipButton: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.mono(11, weight: .medium))
                }
                Text(label)
                    .font(.mono(11, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.pumpAccent : Color.surf)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 5: Review & Save

struct ReviewStepCard: View {
    let name: String
    let primaryMuscles: Set<MuscleGroup>
    let secondaryMuscles: Set<MuscleGroup>
    let equipment: EquipmentType
    let pattern: MovementPattern
    let type: ExerciseType
    let isUnilateral: Bool
    @Binding var submitToCommunity: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Looks good?")
                        .font(.display(22))
                    Text("Review your exercise before saving.")
                        .font(.mono(14))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                // Summary card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.pumpAccent.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: pattern.sfSymbol)
                                .font(.mono(20, weight: .medium))
                                .foregroundStyle(Color.pumpAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.mono(16, weight: .medium))
                            Text(pattern.displayName + " · " + equipment.displayName)
                                .font(.mono(11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    ReviewRow(label: "Primary", value: primaryMuscles.map(\.displayName).sorted().joined(separator: ", "))
                    if !secondaryMuscles.isEmpty {
                        ReviewRow(label: "Secondary", value: secondaryMuscles.map(\.displayName).sorted().joined(separator: ", "))
                    }
                    ReviewRow(label: "Type", value: type.displayName)
                    if isUnilateral {
                        ReviewRow(label: "Unilateral", value: "Yes — each side logged separately")
                    }
                }
                .padding()
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Community toggle
                Toggle("Submit to community library", isOn: $submitToCommunity)
                    .padding()
                    .background(Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("Community submissions require approval before appearing in the public library.")
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
}

struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.mono(11))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.mono(11))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

// MARK: - MuscleGroupPicker (kept for active workout substitution)

struct MuscleGroupPicker: View {
    @Binding var selected: Set<MuscleGroup>
    @Binding var selectedSubRegions: Set<MuscleSubRegion>
    @State private var expandedGroups: Set<MuscleGroup> = []

    var body: some View {
        ForEach(BodyRegion.allCases) { region in
            let muscles = MuscleGroup.allCases.filter { $0.bodyRegion == region }
            DisclosureGroup(region.displayName) {
                ForEach(muscles) { muscle in
                    let subRegions = MuscleSubRegion.subRegions(for: muscle)
                    Button {
                        if selected.contains(muscle) {
                            selected.remove(muscle)
                            for sub in subRegions { selectedSubRegions.remove(sub) }
                            expandedGroups.remove(muscle)
                        } else {
                            selected.insert(muscle)
                            if !subRegions.isEmpty { expandedGroups.insert(muscle) }
                        }
                    } label: {
                        HStack {
                            Text(muscle.displayName).foregroundStyle(.primary)
                            Spacer()
                            if !subRegions.isEmpty && selected.contains(muscle) {
                                Image(systemName: expandedGroups.contains(muscle) ? "chevron.down" : "chevron.right")
                                    .font(.mono(11)).foregroundStyle(.secondary)
                            }
                            if selected.contains(muscle) {
                                Image(systemName: "checkmark").foregroundStyle(Color.pumpAccent)
                            }
                        }
                    }
                    if selected.contains(muscle) && expandedGroups.contains(muscle) {
                        ForEach(subRegions) { sub in
                            Button {
                                if selectedSubRegions.contains(sub) { selectedSubRegions.remove(sub) }
                                else { selectedSubRegions.insert(sub) }
                            } label: {
                                HStack {
                                    Text(sub.displayName).font(.mono(14)).foregroundStyle(.primary)
                                    Spacer()
                                    if selectedSubRegions.contains(sub) {
                                        Image(systemName: "checkmark").font(.mono(11)).foregroundStyle(Color.pumpAccent)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                }
            }
        }
    }
}
