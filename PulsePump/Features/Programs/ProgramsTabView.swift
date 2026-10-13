import SwiftUI
import SwiftData
import FirebaseAuth

struct ProgramsTabView: View {
    let onStartFromTemplate: (WorkoutTemplate) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }, sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var recentWorkouts: [Workout]
    @State private var showPresetPicker = false
    @State private var showCreateBlank = false
    @State private var selectedNavItem: TemplateNavItem?
    @State private var groupToDelete: ProgramGroup? = nil

    // Group templates by their splitDays; templates with no splitDays stay individual
    private var programGroups: [ProgramGroup] {
        var buckets: [(key: String, templates: [WorkoutTemplate])] = []
        var seen: [String: Int] = [:]
        for t in templates {
            let key = t.splitDays.isEmpty ? "__solo_\(t.id)" : t.splitDays.joined()
            if let idx = seen[key] {
                buckets[idx].templates.append(t)
            } else {
                seen[key] = buckets.count
                buckets.append((key: key, templates: [t]))
            }
        }
        return buckets.map { bucket in
            ProgramGroup(
                id: bucket.key,
                name: derivedName(for: bucket.templates),
                templates: bucket.templates,
                splitDays: bucket.templates.first?.splitDays ?? []
            )
        }
    }

    private func derivedName(for templates: [WorkoutTemplate]) -> String {
        if templates.count == 1 { return templates[0].name }
        let names = templates.map { $0.name.lowercased() }
        let hasPush  = names.contains { $0.contains("push") }
        let hasPull  = names.contains { $0.contains("pull") }
        let hasLegs  = names.contains { $0.contains("leg") }
        let hasUpper = names.contains { $0.contains("upper") }
        let hasLower = names.contains { $0.contains("lower") }
        let hasFull  = names.contains { $0.contains("full") }
        if hasPush && hasPull && hasLegs { return "Push Pull Legs" }
        if hasPush && hasLegs            { return "Push Legs" }
        if hasPull && hasLegs            { return "Pull Legs" }
        if hasPush && hasPull            { return "Push Pull" }
        if hasUpper && hasLower          { return "Upper Lower" }
        if hasFull                       { return "Full Body" }
        return templates.map(\.name).joined(separator: " / ")
    }

    private func setCount(for muscle: MuscleGroup) -> Int {
        recentWorkouts.flatMap(\.exerciseLogs)
            .filter { $0.exercise?.primaryMuscleGroups.contains(muscle) == true }
            .flatMap(\.workingSets).count
    }

    private var programsTickerItems: [TickerItem] {
        guard recentWorkouts.count >= 3 else { return [] }
        let pairs: [(String, Int)] = [
            ("CHEST", setCount(for: .chest)),
            ("BACK",  setCount(for: .back)),
            ("QUADS", setCount(for: .quads)),
            ("HAMS",  setCount(for: .hamstrings)),
            ("SHLDR", setCount(for: .shoulders)),
            ("BICEP", setCount(for: .biceps)),
            ("TRI",   setCount(for: .triceps)),
        ]
        return pairs.filter { $0.1 > 0 }.map { TickerItem(label: $0.0, value: "\($0.1) SETS", direction: nil) }
    }

    var body: some View {
        VStack(spacing: 0) {
            programsHeader

            ScrollView {
                LazyVStack(spacing: 0) {
                    if programGroups.isEmpty {
                        emptyState
                    } else {
                        ForEach(programGroups) { group in
                            SwipeToDeleteRow(onDeleteTapped: { groupToDelete = group }) {
                                ProgramGroupRowView(group: group)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedNavItem = TemplateNavItem(group: group) }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityIdentifier(AX.programs.row(group.name))
                            }
                        }
                    }

                    newProgramButton

                    if !recentWorkouts.isEmpty {
                        quickStartSection
                    }

                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedNavItem) { navItem in
            TemplateDetailView(
                template: navItem.templates.first!,
                groupName: navItem.groupName,
                siblings: navItem.templates,
                onStartWorkout: onStartFromTemplate
            )
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetTemplatePicker(onSelectPresets: { presets in
                var copies: [WorkoutTemplate] = []
                presets.forEach { preset in
                    let copy = WorkoutTemplate(name: preset.name, templateExercises: preset.templateExercises, splitDays: preset.splitDays)
                    modelContext.insert(copy)
                    copies.append(copy)
                }
                showPresetPicker = false
                if let first = copies.first {
                    selectedNavItem = TemplateNavItem(first, groupName: nil, siblings: copies)
                }
            }, onBlank: {
                showPresetPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showCreateBlank = true
                }
            })
        }
        .navigationDestination(isPresented: $showCreateBlank) {
            CreateTemplateView()
        }
        .destructiveModal(
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            ),
            kicker: "DELETE PROGRAM",
            title: "Delete \(groupToDelete?.name ?? "program")?",
            body: "The program template will be removed. Workouts you've already logged using it will be kept in your history.",
            consequences: deleteProgramConsequences,
            onConfirm: {
                groupToDelete?.templates.forEach { modelContext.softDelete($0) }
            }
        )
    }

    private var deleteProgramConsequences: [DestructiveConsequence] {
        guard let group = groupToDelete else { return [] }
        let days = group.templates.count
        let exercises = group.totalExercises
        let sessions = group.templates.flatMap(\.liveWorkouts).count
        return [
            DestructiveConsequence(value: "\(days)", label: "workout days"),
            DestructiveConsequence(value: "\(exercises)", label: "exercises"),
            DestructiveConsequence(value: "\(sessions)", label: "past sessions kept"),
        ]
    }

    // MARK: Custom Programs Header

    private var programsHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("PROGRAMS")
                    .font(.archivo(26, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .accessibilityIdentifier(AX.programs.screen)

                Spacer()

                Button {
                    showPresetPicker = true
                } label: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.pumpAccent)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.mono(16, weight: .medium))
                                .foregroundStyle(.white)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Add program")
                .accessibilityIdentifier(AX.programs.add)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 10)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.canvasBg)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Text("NO PROGRAMS")
                .font(.archivo(32, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.inkFaint)
                .accessibilityIdentifier(AX.programs.empty)
            Text("Tap + to add a preset or build your own.")
                .font(.archivo(13))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 20)
        }
        .padding()
    }

    // MARK: New Program Button (dashed)

    private var newProgramButton: some View {
        Button {
            showCreateBlank = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(Color.inkFaint)
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("NEW PROGRAM")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                }
                .foregroundStyle(Color.inkMuted)
            }
            .frame(height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
        .accessibilityIdentifier(AX.programs.newProgram)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: Quick Start Section

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUICK START")
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)

            ForEach(Array(recentWorkouts.prefix(3).enumerated()), id: \.element.id) { idx, workout in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text((workout.template?.name ?? "Workout").uppercased())
                                .font(.archivo(15, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(relativeDate(workout.date))
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Button {
                            if let template = workout.template {
                                onStartFromTemplate(template)
                            }
                        } label: {
                            Text("START")
                                .font(.archivo(13, weight: .black))
                                .tracking(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 32)
                                .background(Color.pumpAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .disabled(workout.template == nil)
                        .opacity(workout.template == nil ? 0.4 : 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if idx < min(recentWorkouts.count, 3) - 1 {
                        Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    }
                }
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}

// MARK: - Program Group Row
