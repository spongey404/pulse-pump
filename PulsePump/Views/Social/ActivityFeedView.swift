import SwiftUI
import SwiftData

struct ActivityFeedView: View {
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    var body: some View {
        List {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "person.2",
                    description: Text("Complete workouts to see activity here. Friends' workouts will also appear in your feed.")
                )
            } else {
                ForEach(workouts.prefix(20), id: \.id) { workout in
                    FeedPostView(workout: workout)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct FeedPostView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(workout.user?.name ?? "You")
                        .font(.subheadline.weight(.semibold))
                    Text(workout.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Workout summary
            VStack(alignment: .leading, spacing: 6) {
                if let template = workout.template {
                    Text(template.name)
                        .font(.body.weight(.medium))
                }

                HStack(spacing: 16) {
                    Label("\(workout.exerciseLogs.count) exercises", systemImage: "figure.strengthtraining.traditional")
                    Label(formatDuration(workout.duration), systemImage: "clock")
                    if workout.calorieBurnEstimate > 0 {
                        Label("\(Int(workout.calorieBurnEstimate)) cal", systemImage: "flame")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Muscles worked tags
                let muscles = musclesWorked
                if !muscles.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(muscles.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { muscle in
                            Text(muscle.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Interaction bar placeholder
            HStack(spacing: 20) {
                Button {} label: {
                    Label("Like", systemImage: "heart")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {} label: {
                    Label("Comment", systemImage: "bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var musclesWorked: [MuscleGroup] {
        var muscles = Set<MuscleGroup>()
        for log in workout.exerciseLogs {
            if let exercise = log.exercise {
                muscles.formUnion(exercise.primaryMuscleGroups)
            }
        }
        return Array(muscles)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        return "\(m) min"
    }
}
