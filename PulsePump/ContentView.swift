import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var workoutViewModel = WorkoutViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    private var user: User? { users.first }

    var body: some View {
        TabView {
            NavigationStack {
                ProgramsTabView(onStartFromTemplate: startFromTemplate)
            }
            .tabItem {
                Label("Programs", systemImage: "list.bullet.clipboard")
            }

            NavigationStack {
                SocialTabView()
            }
            .tabItem {
                Label("Social", systemImage: "person.2")
            }

            NavigationStack {
                HomeTabView(workoutViewModel: workoutViewModel)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                BodyMapTabView()
            }
            .tabItem {
                Label("Body Map", systemImage: "figure.stand")
            }

            NavigationStack {
                MoreTabView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
        }
        .fullScreenCover(isPresented: $workoutViewModel.isActive) {
            ActiveWorkoutView(viewModel: workoutViewModel)
        }
        .sheet(isPresented: $workoutViewModel.showCompletionSummary) {
            if let data = workoutViewModel.completionData {
                WorkoutCompletionView(data: data) {
                    workoutViewModel.reset()
                }
            }
        }
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        guard let user else { return }
        workoutViewModel.startWorkout(modelContext: modelContext, user: user, template: template)
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
