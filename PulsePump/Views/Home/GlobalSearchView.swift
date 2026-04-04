import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var searchText = ""

    private var matchingExercises: [Exercise] {
        guard !searchText.isEmpty else { return [] }
        return exercises.filter {
            ($0.isApproved || $0.isCustom) &&
            $0.name.localizedCaseInsensitiveContains(searchText)
        }.prefix(5).map { $0 }
    }

    private var matchingWorkouts: [Workout] {
        guard !searchText.isEmpty else { return [] }
        return workouts.filter {
            $0.template?.name.localizedCaseInsensitiveContains(searchText) == true ||
            $0.exerciseLogs.contains { log in
                log.exercise?.name.localizedCaseInsensitiveContains(searchText) == true
            }
        }.prefix(5).map { $0 }
    }

    var body: some View {
        List {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "Search",
                    systemImage: "magnifyingglass",
                    description: Text("Search exercises and workout history.")
                )
            } else if matchingExercises.isEmpty && matchingWorkouts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                if !matchingExercises.isEmpty {
                    Section("Exercises") {
                        ForEach(matchingExercises) { exercise in
                            NavigationLink(value: exercise) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !matchingWorkouts.isEmpty {
                    Section("Workouts") {
                        ForEach(matchingWorkouts) { workout in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.template?.name ?? "Workout")
                                    .font(.body)
                                HStack {
                                    Text(workout.date, style: .date)
                                    Text("·")
                                    Text("\(workout.exerciseLogs.count) exercises")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Exercises, workouts...")
        .navigationTitle("Search")
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }
}
