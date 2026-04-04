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
                // Predicted workout + start button always pinned at top
                StartWorkoutView(viewModel: workoutViewModel)

                // Configurable widgets
                ForEach(widgetOrder) { widgetType in
                    if !disabledWidgets.contains(widgetType.rawValue) {
                        homeWidget(for: widgetType)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
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

    var body: some View {
        List {
            NavigationLink("Exercise Library") {
                ExerciseLibraryView()
            }

            NavigationLink("Templates") {
                TemplateListView(onStartWorkout: onStartFromTemplate)
            }
        }
        .navigationTitle("Programs")
    }
}

#Preview {
    ContentView()
}
