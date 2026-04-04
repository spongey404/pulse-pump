import SwiftUI
import SwiftData

struct RecentWorkoutsWidget: View {
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    private var recentWorkouts: [Workout] {
        Array(workouts.prefix(3))
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: workouts.map(\.date))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(currentStreak) day streak")
                            .font(.caption.weight(.medium))
                    }
                }
            }

            if recentWorkouts.isEmpty {
                Text("No workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentWorkouts) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.template?.name ?? "Workout")
                                .font(.subheadline.weight(.medium))
                            Text(workout.date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(workout.exerciseLogs.count) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
