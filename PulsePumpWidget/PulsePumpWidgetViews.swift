import SwiftUI
import WidgetKit

struct PulsePumpWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(entry.currentStreak > 0 ? .orange : .gray)

            Text("\(entry.currentStreak)")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("day streak")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "pulsepump://home"))
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Streak
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(entry.currentStreak > 0 ? .orange : .gray)
                Text("\(entry.currentStreak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Last workout
            VStack(alignment: .leading, spacing: 6) {
                if let name = entry.lastWorkoutName {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                } else if entry.lastWorkoutDate != nil {
                    Text("Last Workout")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let date = entry.lastWorkoutDate {
                    HStack(spacing: 12) {
                        Label("\(entry.exerciseCount)", systemImage: "figure.strengthtraining.traditional")
                        Label("\(entry.durationMinutes)m", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .widgetURL(URL(string: "pulsepump://home"))
    }

    // MARK: - Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with streak
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(entry.currentStreak > 0 ? .orange : .gray)
                Text("\(entry.currentStreak) day streak")
                    .font(.headline)
                Spacer()

                Link(destination: URL(string: "pulsepump://start-workout")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            // Recent workouts
            if entry.recentWorkouts.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No recent workouts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(entry.recentWorkouts.enumerated()), id: \.offset) { _, workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name ?? "Workout")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(workout.date, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text("\(workout.exercises) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "pulsepump://home"))
    }
}
