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

    private var thisMonthWorkouts: [Workout] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return workouts.filter { $0.date >= start }
    }

    private var lastMonthWorkouts: [Workout] {
        let end = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let start = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        return workouts.filter { $0.date >= start && $0.date < end }
    }

    private var thisWeekSets: Int {
        thisWeekWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var lastWeekSets: Int {
        lastWeekWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var thisMonthSets: Int {
        thisMonthWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var lastMonthSets: Int {
        lastMonthWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var volumeChange: Double? {
        guard lastWeekSets > 0 else { return nil }
        return (Double(thisWeekSets - lastWeekSets) / Double(lastWeekSets)) * 100
    }

    private var workoutChange: Double? {
        guard !lastWeekWorkouts.isEmpty else { return nil }
        return (Double(thisWeekWorkouts.count - lastWeekWorkouts.count) / Double(lastWeekWorkouts.count)) * 100
    }

    private var monthlyVolumeChange: Double? {
        guard lastMonthSets > 0 else { return nil }
        return (Double(thisMonthSets - lastMonthSets) / Double(lastMonthSets)) * 100
    }

    private var monthlyWorkoutChange: Double? {
        guard !lastMonthWorkouts.isEmpty else { return nil }
        return (Double(thisMonthWorkouts.count - lastMonthWorkouts.count) / Double(lastMonthWorkouts.count)) * 100
    }

    var body: some View {
        VStack(spacing: 12) {
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
            HStack(spacing: 12) {
                QuickStatTile(
                    title: "Workouts",
                    value: "\(thisMonthWorkouts.count)",
                    change: monthlyWorkoutChange,
                    period: "vs last 30 days"
                )
                QuickStatTile(
                    title: "Sets",
                    value: "\(thisMonthSets)",
                    change: monthlyVolumeChange,
                    period: "vs last 30 days"
                )
            }
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
                .font(.mono(11))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.display(22))

            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.mono(9, weight: .bold))
                    Text(String(format: "%+.0f%%", change))
                        .font(.mono(9, weight: .medium))
                }
                .foregroundStyle(change >= 0 ? .green : .red)

                Text(period)
                    .font(.mono(9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
