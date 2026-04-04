import SwiftUI

struct ContentView: View {
    @State private var workoutViewModel = WorkoutViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                ProgramsTabView()
            }
            .tabItem {
                Label("Programs", systemImage: "list.bullet.clipboard")
            }

            Text("Social")
                .tabItem {
                    Label("Social", systemImage: "person.2")
                }

            NavigationStack {
                HomeTabView(workoutViewModel: workoutViewModel)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            Text("Body Map")
                .tabItem {
                    Label("Body Map", systemImage: "figure.stand")
                }

            Text("More")
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
}

struct HomeTabView: View {
    @Bindable var workoutViewModel: WorkoutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StartWorkoutView(viewModel: workoutViewModel)
            }
            .padding(.top)
        }
        .navigationTitle("Home")
    }
}

struct ProgramsTabView: View {
    var body: some View {
        List {
            NavigationLink("Exercise Library") {
                ExerciseLibraryView()
            }

            Section("Templates") {
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Programs")
    }
}

#Preview {
    ContentView()
}
