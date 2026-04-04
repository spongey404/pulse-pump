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

struct HomeTabView: View {
    @Bindable var workoutViewModel: WorkoutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StartWorkoutView(viewModel: workoutViewModel)

                QuickAnalyticsView()
                    .padding(.horizontal)

                RecentWorkoutsWidget()
                    .padding(.horizontal)
            }
            .padding(.top)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    GlobalSearchView()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
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
