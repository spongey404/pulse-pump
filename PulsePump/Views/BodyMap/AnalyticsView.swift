import SwiftUI
import SwiftData
import Charts

enum AnalyticsDateRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

struct AnalyticsView: View {
    @State private var dateRange: AnalyticsDateRange = .month
    @Query private var workouts: [Workout]

    private var filteredWorkouts: [Workout] {
        workouts.filter { !$0.isDraft && $0.date >= dateRange.startDate }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Range", selection: $dateRange) {
                    ForEach(AnalyticsDateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Workout frequency
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout Frequency")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal)

                    if filteredWorkouts.isEmpty {
                        ContentUnavailableView(
                            "No Workouts",
                            systemImage: "chart.bar",
                            description: Text("Complete workouts to see analytics.")
                        )
                        .frame(height: 200)
                    } else {
                        Chart {
                            ForEach(workoutsPerWeek, id: \.week) { entry in
                                BarMark(
                                    x: .value("Week", entry.week),
                                    y: .value("Workouts", entry.count)
                                )
                                .foregroundStyle(Color.pumpPrimary)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                }

                // Per-workout improvement
                if !filteredWorkouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sets Per Workout")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal)

                        Chart {
                            ForEach(filteredWorkouts) { workout in
                                LineMark(
                                    x: .value("Date", workout.date),
                                    y: .value("Sets", workout.exerciseLogs.flatMap(\.sets).count)
                                )
                                .foregroundStyle(Color.pumpPrimary)
                                PointMark(
                                    x: .value("Date", workout.date),
                                    y: .value("Sets", workout.exerciseLogs.flatMap(\.sets).count)
                                )
                                .foregroundStyle(Color.pumpPrimary)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                }

                // Summary stats
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        AnalyticsStatCard(
                            title: "Total Workouts",
                            value: "\(filteredWorkouts.count)"
                        )
                        AnalyticsStatCard(
                            title: "Avg Duration",
                            value: averageDuration
                        )
                    }
                    HStack(spacing: 16) {
                        AnalyticsStatCard(
                            title: "Total Sets",
                            value: "\(totalSets)"
                        )
                        AnalyticsStatCard(
                            title: "Streak",
                            value: "\(currentStreak) days"
                        )
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 32)
            }
            .padding(.top)
        }
    }

    // MARK: - Computed

    private var workoutsPerWeek: [(week: String, count: Int)] {
        let calendar = Calendar.current
        var weekCounts: [String: Int] = [:]

        for workout in filteredWorkouts {
            let weekOfYear = calendar.component(.weekOfYear, from: workout.date)
            let key = "W\(weekOfYear)"
            weekCounts[key, default: 0] += 1
        }

        return weekCounts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var averageDuration: String {
        guard !filteredWorkouts.isEmpty else { return "0m" }
        let avg = filteredWorkouts.map(\.duration).reduce(0, +) / Double(filteredWorkouts.count)
        return "\(Int(avg / 60))m"
    }

    private var totalSets: Int {
        filteredWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let sortedDates = workouts
            .filter { !$0.isDraft }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)

        guard var current = sortedDates.first else { return 0 }
        let today = calendar.startOfDay(for: Date())

        guard calendar.isDate(current, inSameDayAs: today) ||
              calendar.isDate(current, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) else {
            return 0
        }

        var streak = 1
        for date in sortedDates.dropFirst() {
            let expected = calendar.date(byAdding: .day, value: -1, to: current)!
            if calendar.isDate(date, inSameDayAs: expected) {
                streak += 1
                current = date
            } else if !calendar.isDate(date, inSameDayAs: current) {
                break
            }
        }
        return streak
    }
}

struct AnalyticsStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
