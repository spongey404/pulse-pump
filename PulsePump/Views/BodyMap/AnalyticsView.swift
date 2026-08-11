import SwiftUI
import SwiftData
import Charts

enum AnalyticsDateRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case custom = "Custom"

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .custom: 0
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

struct AnalyticsView: View {
    @State private var dateRange: AnalyticsDateRange = .month
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var selectedExerciseForTrend: Exercise?
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    private var effectiveStartDate: Date {
        dateRange == .custom ? customStartDate : dateRange.startDate
    }

    private var effectiveEndDate: Date {
        dateRange == .custom ? customEndDate : Date()
    }

    private var filteredWorkouts: [Workout] {
        workouts.filter { !$0.isDraft && $0.date >= effectiveStartDate && $0.date <= effectiveEndDate }
            .sorted { $0.date < $1.date }
    }

    /// Exercises that have at least one log in the filtered range
    private var exercisesWithLogs: [Exercise] {
        let exerciseIds = Set(
            filteredWorkouts.flatMap(\.exerciseLogs).compactMap { $0.exercise?.id }
        )
        return exercises.filter { exerciseIds.contains($0.id) && ($0.isApproved || $0.isCustom) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date range picker
                Picker("Range", selection: $dateRange) {
                    ForEach(AnalyticsDateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if dateRange == .custom {
                    VStack(spacing: 4) {
                        DatePicker("From", selection: $customStartDate, in: ...customEndDate, displayedComponents: .date)
                        DatePicker("To", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                    }
                    .padding(.horizontal)
                    .tint(Color.accentInk)
                }

                if filteredWorkouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "chart.bar",
                        description: Text("Complete workouts to see analytics.")
                    )
                    .frame(height: 200)
                } else {
                    // 1. Workout frequency
                    analyticsCard(title: "Workout Frequency") {
                        Chart {
                            ForEach(workoutsPerWeek, id: \.week) { entry in
                                BarMark(
                                    x: .value("Week", entry.week),
                                    y: .value("Workouts", entry.count)
                                )
                                .foregroundStyle(Color.accentInk)
                            }
                        }
                        .frame(height: 180)
                    }

                    // 2. Per-workout improvement score
                    analyticsCard(title: "Exercises Improved Per Workout") {
                        let data = improvementData
                        if data.isEmpty {
                            Text("Log more workouts to see improvement trends.")
                                .font(.mono(11))
                                .foregroundStyle(.secondary)
                                .frame(height: 100)
                        } else {
                            Chart {
                                ForEach(data, id: \.date) { entry in
                                    LineMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Improved", entry.improved)
                                    )
                                    .foregroundStyle(Color.accentInk)
                                    PointMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Improved", entry.improved)
                                    )
                                    .foregroundStyle(Color.accentInk)
                                }
                            }
                            .frame(height: 180)
                            .chartYAxis {
                                AxisMarks(values: .automatic(desiredCount: 4))
                            }
                        }
                    }

                    // 3. Per-muscle-group weekly volume
                    analyticsCard(title: "Weekly Volume by Muscle Group") {
                        let data = muscleVolumeData
                        if data.isEmpty {
                            Text("No muscle group data available.")
                                .font(.mono(11))
                                .foregroundStyle(.secondary)
                                .frame(height: 100)
                        } else {
                            Chart {
                                ForEach(data, id: \.muscle) { entry in
                                    BarMark(
                                        x: .value("Sets", entry.sets),
                                        y: .value("Muscle", entry.muscle)
                                    )
                                    .foregroundStyle(Color.accentInk)
                                }
                            }
                            .frame(height: CGFloat(max(160, data.count * 32)))
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4))
                            }
                        }
                    }

                    // 4. Per-exercise trend
                    analyticsCard(title: "Exercise Progress") {
                        VStack(alignment: .leading, spacing: 12) {
                            if exercisesWithLogs.isEmpty {
                                Text("Complete workouts with tracked exercises to see progress.")
                                    .font(.mono(11))
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("Exercise", selection: $selectedExerciseForTrend) {
                                    Text("Select exercise").tag(Optional<Exercise>.none)
                                    ForEach(exercisesWithLogs) { ex in
                                        Text(ex.name).tag(Optional(ex))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.accentInk)

                                if let exercise = selectedExerciseForTrend {
                                    let trendData = exerciseTrend(for: exercise)
                                    if trendData.isEmpty {
                                        Text("No data for this exercise in range.")
                                            .font(.mono(11))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Chart {
                                            ForEach(trendData, id: \.date) { point in
                                                LineMark(
                                                    x: .value("Date", point.date),
                                                    y: .value("Weight", point.maxWeight)
                                                )
                                                .foregroundStyle(Color.accentInk)
                                                PointMark(
                                                    x: .value("Date", point.date),
                                                    y: .value("Weight", point.maxWeight)
                                                )
                                                .foregroundStyle(Color.accentInk)
                                            }
                                        }
                                        .frame(height: 180)
                                        .chartYScale(domain: .automatic(includesZero: false))
                                    }
                                }
                            }
                        }
                    }

                    // Summary stats
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            AnalyticsStatCard(title: "Total Workouts", value: "\(filteredWorkouts.count)")
                            AnalyticsStatCard(title: "Avg Duration", value: averageDuration)
                        }
                        HStack(spacing: 16) {
                            AnalyticsStatCard(title: "Total Sets", value: "\(totalSets)")
                            AnalyticsStatCard(title: "Streak", value: "\(currentStreak) days")
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
            .padding(.top)
        }
        .onAppear {
            if selectedExerciseForTrend == nil {
                selectedExerciseForTrend = exercisesWithLogs.first
            }
        }
    }

    // MARK: - Chart helper

    @ViewBuilder
    private func analyticsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.mono(14, weight: .medium))
                .padding(.horizontal)
            content()
                .padding(.horizontal)
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

    /// Per-workout: how many exercises improved vs prior session
    private var improvementData: [(date: Date, improved: Int)] {
        filteredWorkouts.map { workout in
            var improved = 0
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                let currentBest = log.sets.map(\.weight).max() ?? 0
                let prevBest = exercise.logs
                    .filter { $0.id != log.id }
                    .flatMap(\.sets)
                    .map(\.weight)
                    .max() ?? 0
                if currentBest > prevBest && prevBest > 0 { improved += 1 }
            }
            return (workout.date, improved)
        }
    }

    /// Per-muscle-group: total sets in the filtered range, top 10
    private var muscleVolumeData: [(muscle: String, sets: Int)] {
        var counts: [String: Int] = [:]
        for workout in filteredWorkouts {
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                for muscle in exercise.primaryMuscleGroups {
                    counts[muscle.displayName, default: 0] += log.sets.count
                }
                for muscle in exercise.secondaryMuscleGroups {
                    counts[muscle.displayName, default: 0] += log.sets.count / 2
                }
            }
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { ($0.key, $0.value) }
    }

    /// Per-exercise: max weight per session in filtered range
    private func exerciseTrend(for exercise: Exercise) -> [(date: Date, maxWeight: Double)] {
        filteredWorkouts.compactMap { workout -> (Date, Double)? in
            let log = workout.exerciseLogs.first { $0.exercise?.id == exercise.id }
            guard let log, let maxWeight = log.sets.map(\.weight).max(), maxWeight > 0 else { return nil }
            return (workout.date, maxWeight)
        }
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
        StreakCalculator.currentStreak(from: workouts.filter { !$0.isDraft }.map(\.date))
    }
}

struct AnalyticsStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.display(20))
            Text(title)
                .font(.mono(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
