import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var workoutViewModel = WorkoutViewModel()
    @State private var tutorialViewModel = TutorialViewModel()
    @State private var selectedTab = 2
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    private var user: User? { users.first }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ProgramsTabView(onStartFromTemplate: startFromTemplate)
                }
                .tabItem {
                    Label("Programs", systemImage: "list.bullet.clipboard")
                }
                .tag(0)

                NavigationStack {
                    SocialTabView()
                }
                .tabItem {
                    Label("Social", systemImage: "person.2")
                }
                .tag(1)

                NavigationStack {
                    HomeTabView(workoutViewModel: workoutViewModel)
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(2)

                NavigationStack {
                    BodyMapTabView()
                }
                .tabItem {
                    Label("Body Map", systemImage: "figure.stand")
                }
                .tag(3)

                NavigationStack {
                    MoreTabView(tutorialViewModel: tutorialViewModel)
                }
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(4)
            }
            .fullScreenCover(isPresented: $workoutViewModel.isActive) {
                ActiveWorkoutView(viewModel: workoutViewModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: .startWorkoutFromWidget)) { _ in
                startBlankWorkout()
            }
            .sheet(isPresented: $workoutViewModel.showCompletionSummary) {
                if let data = workoutViewModel.completionData {
                    WorkoutCompletionView(data: data) {
                        workoutViewModel.reset()
                    }
                }
            }

            if tutorialViewModel.isActive {
                CoachMarkOverlay(viewModel: tutorialViewModel, selectedTab: $selectedTab)
            }
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "wantsTutorial") {
                tutorialViewModel.start()
            }
        }
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        guard let user else { return }
        workoutViewModel.startWorkout(modelContext: modelContext, user: user, template: template)
    }

    private func startBlankWorkout() {
        guard let user else { return }
        workoutViewModel.startWorkout(modelContext: modelContext, user: user)
    }
}

enum HomeWidgetType: String, CaseIterable, Identifiable, Codable {
    case quickAnalytics
    case bodyMapMini
    case recentWorkouts

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quickAnalytics: "Quick Analytics"
        case .bodyMapMini: "Body Map"
        case .recentWorkouts: "Recent Workouts"
        }
    }
}

struct HomeTabView: View {
    @Bindable var workoutViewModel: WorkoutViewModel
    @State private var showWidgetConfig = false
    @State private var widgetOrder: [HomeWidgetType] = {
        if let data = UserDefaults.standard.data(forKey: "homeWidgetOrder"),
           let order = try? JSONDecoder().decode([HomeWidgetType].self, from: data) {
            return order
        }
        return HomeWidgetType.allCases
    }()
    @State private var disabledWidgets: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "homeDisabledWidgets") ?? [])
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Configurable widgets scroll freely
                ForEach(widgetOrder) { widgetType in
                    if !disabledWidgets.contains(widgetType.rawValue) {
                        homeWidget(for: widgetType)
                            .padding(.horizontal)
                    }
                }
                // Bottom padding so content doesn't hide behind start button
                Color.clear.frame(height: 100)
            }
            .padding(.top)
        }
        // Start button docked at bottom for one-handed reach
        .safeAreaInset(edge: .bottom) {
            StartWorkoutDock(viewModel: workoutViewModel)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        showWidgetConfig = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    NavigationLink {
                        GlobalSearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .sheet(isPresented: $showWidgetConfig) {
            HomeWidgetConfigView(
                widgetOrder: $widgetOrder,
                disabledWidgets: $disabledWidgets,
                onSave: saveWidgetConfig
            )
        }
    }

    @ViewBuilder
    private func homeWidget(for type: HomeWidgetType) -> some View {
        switch type {
        case .quickAnalytics:
            QuickAnalyticsView()
        case .bodyMapMini:
            BodyMapMiniWidget()
        case .recentWorkouts:
            RecentWorkoutsWidget()
        }
    }

    private func saveWidgetConfig() {
        if let data = try? JSONEncoder().encode(widgetOrder) {
            UserDefaults.standard.set(data, forKey: "homeWidgetOrder")
        }
        UserDefaults.standard.set(Array(disabledWidgets), forKey: "homeDisabledWidgets")
    }
}

// MARK: - Start Workout Bottom Dock

struct StartWorkoutDock: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { $0.isDraft }, sort: \Workout.updatedAt, order: .reverse)
    private var drafts: [Workout]

    private var user: User? { users.first }

    var body: some View {
        VStack(spacing: 0) {
            // Draft pills — compact, above the button
            if !drafts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(drafts.prefix(3)) { draft in
                            Button {
                                if let user {
                                    draft.user = user
                                    viewModel.resumeDraft(workout: draft, modelContext: modelContext)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption2)
                                    Text(draft.date, style: .relative)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }

            // Main start button
            if let user {
                let prediction = viewModel.predictNextWorkout(user: user)
                Button {
                    viewModel.startWorkout(modelContext: modelContext, user: user)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.body.weight(.semibold))
                        Text(prediction.map { "Start \($0)" } ?? "Start Workout")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.pumpPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Widget Config

struct HomeWidgetConfigView: View {
    @Binding var widgetOrder: [HomeWidgetType]
    @Binding var disabledWidgets: Set<String>
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Drag to reorder, toggle to show/hide") {
                    ForEach(widgetOrder) { widget in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            Text(widget.displayName)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !disabledWidgets.contains(widget.rawValue) },
                                set: { enabled in
                                    if enabled {
                                        disabledWidgets.remove(widget.rawValue)
                                    } else {
                                        disabledWidgets.insert(widget.rawValue)
                                    }
                                }
                            ))
                        }
                    }
                    .onMove { source, destination in
                        widgetOrder.move(fromOffsets: source, toOffset: destination)
                    }
                }

                Section {
                    Text("Predicted Workout is always pinned at the top.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Customize Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Body Map Mini Widget

struct BodyMapMiniWidget: View {
    @Query private var exerciseLogs: [ExerciseLog]

    private var recentMuscles: [(MuscleGroup, Double)] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var muscleVolume: [MuscleGroup: Int] = [:]

        for log in exerciseLogs {
            guard let exercise = log.exercise,
                  let workout = log.workout,
                  !workout.isDraft,
                  workout.date >= weekAgo else { continue }

            for muscle in exercise.primaryMuscleGroups {
                muscleVolume[muscle, default: 0] += log.sets.count
            }
        }

        let maxVol = Double(muscleVolume.values.max() ?? 1)
        return muscleVolume
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { ($0.key, Double($0.value) / maxVol) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week's Muscles")
                .font(.subheadline.weight(.semibold))

            if recentMuscles.isEmpty {
                Text("No workouts this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(recentMuscles, id: \.0) { muscle, intensity in
                        Text(muscle.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.pumpPrimary.opacity(0.2 + intensity * 0.5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ProgramsTabView: View {
    let onStartFromTemplate: (WorkoutTemplate) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @State private var showPresetPicker = false
    @State private var showCreateBlank = false
    @State private var selectedTemplate: WorkoutTemplate?

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else {
                templateGrid
            }
        }
        .navigationTitle("Programs")
        .navigationDestination(item: $selectedTemplate) { template in
            TemplateDetailView(template: template, onStartWorkout: onStartFromTemplate)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPresetPicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    Label("Exercise Library", systemImage: "books.vertical")
                }
            }
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetTemplatePicker(onSelectPreset: { preset in
                let copy = WorkoutTemplate(name: preset.name, templateExercises: preset.templateExercises)
                modelContext.insert(copy)
                showPresetPicker = false
                selectedTemplate = copy
            }, onBlank: {
                showPresetPicker = false
                showCreateBlank = true
            })
        }
        .sheet(isPresented: $showCreateBlank) {
            CreateTemplateView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(Color(.systemGray3))
            Text("No programs yet")
                .font(.title3.weight(.semibold))
            Text("Tap + to add a preset or create your own.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var templateGrid: some View {
        List {
            ForEach(templates) { template in
                Button {
                    selectedTemplate = template
                } label: {
                    TemplateCard(template: template, onStart: { onStartFromTemplate(template) })
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        modelContext.delete(template)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    func delete() {
        modelContext.delete(template)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    onStart()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.pumpPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Label("\(template.templateExercises.count) exercises", systemImage: "figure.strengthtraining.traditional")
                let sets = template.templateExercises.reduce(0) { $0 + $1.targetSets }
                Label("\(sets) sets", systemImage: "repeat")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Exercise name chips
            if !template.templateExercises.isEmpty {
                let exercises = template.templateExercises.sorted { $0.order < $1.order }.prefix(4)
                FlowLayout(spacing: 6) {
                    ForEach(Array(exercises)) { ex in
                        Text(ex.exerciseName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                    if template.templateExercises.count > 4 {
                        Text("+\(template.templateExercises.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showEditSheet) {
            EditTemplateView(template: template)
        }
        .confirmationDialog("Delete \"\(template.name)\"?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Preset Template Picker

struct PresetTemplatePicker: View {
    let onSelectPreset: (WorkoutTemplate) -> Void
    let onBlank: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let groups: [(name: String, templates: [WorkoutTemplate])] = [
        ("Push / Pull / Legs", TemplateSeedService.pplTemplates),
        ("Upper / Lower", TemplateSeedService.upperLowerTemplates),
        ("Full Body", TemplateSeedService.fullBodyTemplates),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onBlank()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.tertiarySystemBackground))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "plus")
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Blank template")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("Build your own from scratch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ForEach(groups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.templates) { template in
                            Button {
                                onSelectPreset(template)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.pumpPrimary.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "list.bullet.clipboard")
                                            .foregroundStyle(Color.pumpPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text("\(template.templateExercises.count) exercises · \(template.templateExercises.reduce(0) { $0 + $1.targetSets }) sets")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose a Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
