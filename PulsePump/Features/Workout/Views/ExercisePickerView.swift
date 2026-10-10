import SwiftUI
import SwiftData

// MARK: - Group Definitions

private let exerciseGroupDefinitions: [(name: String, exerciseNames: [String])] = [
    ("Bench Press",          ["Barbell Bench Press", "Dumbbell Bench Press", "Smith Machine Bench Press", "Machine Chest Press"]),
    ("Incline Bench Press",  ["Incline Barbell Bench Press", "Incline Dumbbell Bench Press", "Smith Machine Incline Press"]),
    ("Decline Bench Press",  ["Decline Barbell Bench Press", "Decline Dumbbell Bench Press"]),
    ("Chest Fly",            ["Dumbbell Fly", "Cable Crossover", "High Cable Fly", "Low Cable Fly", "Pec Deck"]),
    ("Incline Fly",          ["Incline Dumbbell Fly", "Decline Dumbbell Fly"]),
    ("Push Up",              ["Push Up", "Wide Push Up", "Incline Push Up", "Decline Push Up", "Diamond Push Up"]),
    ("Barbell Row",          ["Barbell Row", "Pendlay Row", "T-Bar Row", "Seal Row"]),
    ("Dumbbell Row",         ["Dumbbell Row", "Chest Supported Row", "Meadows Row", "Kroc Row"]),
    ("Cable Row",            ["Seated Cable Row", "Single Arm Cable Row"]),
    ("Lat Pulldown",         ["Lat Pulldown", "Wide Grip Lat Pulldown", "Close Grip Lat Pulldown", "Reverse Grip Lat Pulldown", "Single Arm Lat Pulldown"]),
    ("Pull Up",              ["Pull Up", "Neutral Grip Pull Up", "Weighted Pull Up"]),
    ("Pullover",             ["Dumbbell Pullover", "Machine Pullover"]),
    ("Deadlift",             ["Conventional Deadlift", "Sumo Deadlift", "Trap Bar Deadlift", "Rack Pull"]),
    ("Romanian Deadlift",    ["Romanian Deadlift", "Dumbbell Romanian Deadlift", "Single Leg Romanian Deadlift", "Stiff Leg Deadlift"]),
    ("Overhead Press",       ["Overhead Press", "Seated Overhead Press", "Smith Machine Shoulder Press"]),
    ("Dumbbell Press",       ["Dumbbell Shoulder Press", "Seated Dumbbell Shoulder Press", "Arnold Press"]),
    ("Lateral Raise",        ["Lateral Raise", "Cable Lateral Raise", "Machine Lateral Raise", "Band Lateral Raise"]),
    ("Front Raise",          ["Front Raise", "Cable Front Raise", "Plate Front Raise"]),
    ("Rear Delt Fly",        ["Reverse Fly", "Cable Rear Delt Fly", "Machine Rear Delt Fly"]),
    ("Barbell Curl",         ["Barbell Curl", "EZ Bar Curl", "Drag Curl", "21s"]),
    ("Dumbbell Curl",        ["Dumbbell Curl", "Incline Dumbbell Curl", "Concentration Curl", "Spider Curl", "Zottman Curl"]),
    ("Hammer Curl",          ["Hammer Curl", "Cross Body Hammer Curl", "Cable Hammer Curl"]),
    ("Preacher Curl",        ["Preacher Curl", "Dumbbell Preacher Curl"]),
    ("Tricep Pushdown",      ["Tricep Pushdown", "Rope Pushdown", "Reverse Grip Pushdown", "Single Arm Pushdown"]),
    ("Skull Crusher",        ["Skull Crusher", "Dumbbell Skull Crusher"]),
    ("Overhead Tricep Ext",  ["Overhead Tricep Extension", "Dumbbell Overhead Tricep Extension", "Single Arm Overhead Tricep Extension"]),
    ("Squat",                ["Barbell Squat", "Box Squat", "Pause Squat", "Zercher Squat", "Smith Machine Squat"]),
    ("Lunge",                ["Walking Lunge", "Reverse Lunge", "Side Lunge"]),
    ("Leg Curl",             ["Leg Curl", "Lying Leg Curl", "Seated Leg Curl", "Cable Leg Curl"]),
    ("Leg Extension",        ["Leg Extension", "Single Leg Extension"]),
    ("Hip Thrust",           ["Hip Thrust", "Dumbbell Hip Thrust", "Smith Machine Hip Thrust"]),
    ("Glute Bridge",         ["Glute Bridge", "Single Leg Glute Bridge"]),
    ("Calf Raise",           ["Standing Calf Raise", "Seated Calf Raise", "Leg Press Calf Raise", "Single Leg Calf Raise", "Smith Machine Calf Raise", "Dumbbell Calf Raise"]),
    ("Leg Press",            ["Leg Press", "Single Leg Press"]),
    ("Hip Abduction",        ["Hip Abduction", "Cable Hip Abduction", "Side Lying Hip Abduction", "Band Hip Abduction"]),
    ("Hip Adduction",        ["Hip Adduction", "Cable Hip Adduction"]),
    ("Wrist Curl",           ["Wrist Curl", "Barbell Wrist Curl"]),
    ("Reverse Wrist Curl",   ["Reverse Wrist Curl", "Reverse Barbell Wrist Curl"]),
    ("Shrug",                ["Barbell Shrug", "Dumbbell Shrug", "Shrug", "Behind the Back Shrug", "Cable Shrug"]),
    ("Farmer Carry",         ["Farmer Carry", "Trap Bar Farmer Carry", "Suitcase Carry", "Overhead Carry"]),
    ("Kettlebell Swing",     ["Kettlebell Swing", "Single Arm Kettlebell Swing"]),
]

// MARK: - Picker Item Model

struct ExerciseGroupEntry: Identifiable, Hashable {
    let id = UUID()
    let groupName: String
    let exercises: [Exercise]

    var isSingle: Bool { exercises.count == 1 }
    var displayName: String { isSingle ? exercises[0].name : groupName }
    var primaryMuscles: String { exercises.first.map { $0.primaryMuscleGroups.map(\.displayName).joined(separator: " · ") } ?? "" }
    var movementPattern: MovementPattern { exercises.first?.movementPattern ?? .isolation }

    static func == (lhs: ExerciseGroupEntry, rhs: ExerciseGroupEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Main View

struct ExercisePickerView: View {
    @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var movementFilter: MovementPattern? = nil
    @State private var path = NavigationPath()
    @Environment(\.dismiss) private var dismiss
    var title: String = "ADD EXERCISE"
    var excludedIds: Set<UUID> = []
    let onAdd: ([Exercise]) -> Void
    var standalone: Bool = true

    private var nameToGroup: [String: String] {
        var map: [String: String] = [:]
        for (group, names) in exerciseGroupDefinitions {
            for name in names { map[name] = group }
        }
        return map
    }

    private var approvedExercises: [Exercise] {
        exercises.filter { ($0.isApproved || $0.isCustom) && !excludedIds.contains($0.id) }
    }

    private var filteredExercises: [Exercise] {
        var result = approvedExercises
        if let filter = movementFilter {
            result = result.filter { $0.movementPattern == filter }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    private var displayItems: [ExerciseGroupEntry] {
        let lookup = nameToGroup
        var grouped: [(key: String, exercises: [Exercise])] = []
        var seen: [String: Int] = [:]
        var ungrouped: [Exercise] = []

        for exercise in filteredExercises {
            if let groupName = lookup[exercise.name] {
                if let idx = seen[groupName] {
                    grouped[idx].exercises.append(exercise)
                } else {
                    seen[groupName] = grouped.count
                    grouped.append((key: groupName, exercises: [exercise]))
                }
            } else {
                ungrouped.append(exercise)
            }
        }

        let orderedGroupNames = exerciseGroupDefinitions.map(\.0)
        let sortedGroups = grouped.sorted { a, b in
            let ai = orderedGroupNames.firstIndex(of: a.key) ?? Int.max
            let bi = orderedGroupNames.firstIndex(of: b.key) ?? Int.max
            return ai < bi
        }

        return sortedGroups.map { ExerciseGroupEntry(groupName: $0.key, exercises: $0.exercises) }
            + ungrouped.map { ExerciseGroupEntry(groupName: $0.name, exercises: [$0]) }
    }

    var body: some View {
        if standalone {
            NavigationStack(path: $path) {
                pickerContent
                    .navigationDestination(for: ExerciseGroupEntry.self) { group in
                        VariantsView(group: group) { exercises in
                            onAdd(exercises)
                            dismiss()
                        }
                    }
            }
        } else {
            pickerContent
                .navigationDestination(for: ExerciseGroupEntry.self) { group in
                    VariantsView(group: group) { exercises in
                        onAdd(exercises)
                        dismiss()
                    }
                }
        }
    }

    private var pickerContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Text(title)
                    .font(.archivo(22, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkMuted)
                TextField("Search exercises…", text: $searchText)
                    .font(.archivo(14))
                    .foregroundStyle(Color.inkPrimary)
                    .accessibilityIdentifier(AX.picker.search)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.inkPrimary.opacity(0.12)))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // Movement filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterPill(title: "ALL", isSelected: movementFilter == nil) { movementFilter = nil }
                    ForEach(MovementPattern.allCases) { pattern in
                        FilterPill(
                            title: pattern.displayName.uppercased(),
                            isSelected: movementFilter == pattern
                        ) {
                            movementFilter = movementFilter == pattern ? nil : pattern
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)

            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

            // Exercise list
            if displayItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayItems) { item in
                            ExerciseRow(item: item) { exercises in
                                onAdd(exercises)
                                dismiss()
                            } onShowVariants: {
                                path.append(item)
                            }
                            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                        }
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No exercises found")
                .font(.archivo(14))
                .foregroundStyle(Color.inkMuted)
            Text("TRY A DIFFERENT SEARCH")
                .font(.spaceMono(10)).tracking(0.8)
                .foregroundStyle(Color.inkFaint)
            Spacer()
        }
    }
}

// MARK: - Variants View

private struct VariantsView: View {
    let group: ExerciseGroupEntry
    let onAdd: ([Exercise]) -> Void
    @Environment(\.dismiss) private var dismiss

    private var movementColor: Color {
        switch group.movementPattern {
        case .push:      return Color.pumpAccent
        case .pull:      return Color.signalUp
        case .hinge:     return Color(hex: "#5f8fcc")
        case .squat:     return Color(hex: "#c9892e")
        case .carry:     return Color.inkMuted
        case .rotation:  return Color(hex: "#9b59b6")
        case .isolation: return Color.inkMuted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(group.groupName.uppercased())
                        .font(.archivo(20, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                    Text("\(group.exercises.count) VARIANTS")
                        .font(.spaceMono(9))
                        .tracking(1.2)
                        .foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)

            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(group.exercises) { exercise in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(movementColor)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.archivo(16, weight: .medium))
                                    .foregroundStyle(Color.inkPrimary)
                                Text(exercise.equipmentType.displayName.uppercased())
                                    .font(.spaceMono(9)).tracking(0.5)
                                    .foregroundStyle(Color.inkMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button { onAdd([exercise]) } label: {
                                Text("ADD")
                                    .font(.archivo(13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(height: 32)
                                    .padding(.horizontal, 14)
                                    .background(Color.pumpAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.93))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                    }
                    Color.clear.frame(height: 30)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.spaceMono(9, weight: .bold)).tracking(0.8)
                .foregroundStyle(isSelected ? Color.canvasBg : Color.inkMuted)
                .frame(height: 28)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.pumpAccent : Color.surf)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.accentInk : Color.inkPrimary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Row

private struct ExerciseRow: View {
    let item: ExerciseGroupEntry
    let onAdd: ([Exercise]) -> Void
    let onShowVariants: () -> Void

    private var movementColor: Color {
        switch item.movementPattern {
        case .push:      return Color.pumpAccent
        case .pull:      return Color.signalUp
        case .hinge:     return Color(hex: "#5f8fcc")
        case .squat:     return Color(hex: "#c9892e")
        case .carry:     return Color.inkMuted
        case .rotation:  return Color(hex: "#9b59b6")
        case .isolation: return Color.inkMuted
        }
    }

    var body: some View {
        Button {
            if item.isSingle {
                onAdd(item.exercises)
            } else {
                onShowVariants()
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(movementColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName.uppercased())
                        .font(.archivo(16, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.primaryMuscles.uppercased())
                        .font(.spaceMono(9)).tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if item.isSingle {
                    Text("ADD")
                        .font(.archivo(13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(height: 30)
                        .padding(.horizontal, 14)
                        .background(Color.pumpAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack(spacing: 4) {
                        Text("\(item.exercises.count) VARIANTS")
                            .font(.spaceMono(8, weight: .bold)).tracking(0.8)
                            .foregroundStyle(Color.inkMuted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.picker.row(item.displayName))
    }
}
