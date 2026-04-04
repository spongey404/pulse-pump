import SwiftUI
import SwiftData

struct QuickAnalyticsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    private var thisWeekWorkouts: [Workout] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workouts.filter { $0.date >= start }
    }

    private var lastWeekWorkouts: [Workout] {
        let end = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return workouts.filter { $0.date >= start && $0.date < end }
    }

    private var thisWeekSets: Int {
        thisWeekWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var lastWeekSets: Int {
        lastWeekWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var volumeChange: Double? {
        guard lastWeekSets > 0 else { return nil }
        return (Double(thisWeekSets - lastWeekSets) / Double(lastWeekSets)) * 100
    }

    private var workoutChange: Double? {
        guard !lastWeekWorkouts.isEmpty else { return nil }
        return (Double(thisWeekWorkouts.count - lastWeekWorkouts.count) / Double(lastWeekWorkouts.count)) * 100
    }

    var body: some View {
        HStack(spacing: 12) {
            QuickStatTile(
                title: "Workouts",
                value: "\(thisWeekWorkouts.count)",
                change: workoutChange,
                period: "vs last week"
            )
            QuickStatTile(
                title: "Sets",
                value: "\(thisWeekSets)",
                change: volumeChange,
                period: "vs last week"
            )
        }
    }
}

struct QuickStatTile: View {
    let title: String
    let value: String
    let change: Double?
    let period: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.weight(.bold))

            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.bold))
                    Text(String(format: "%+.0f%%", change))
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(change >= 0 ? .green : .red)

                Text(period)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
