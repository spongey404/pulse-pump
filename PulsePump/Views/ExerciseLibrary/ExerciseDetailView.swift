import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section("Info") {
                LabeledContent("Equipment", value: exercise.equipmentType.displayName)
                LabeledContent("Movement", value: exercise.movementPattern.displayName)
                LabeledContent("Type", value: exercise.exerciseType.displayName)
                if exercise.isUnilateral {
                    LabeledContent("Unilateral", value: "Yes")
                }
            }

            Section("Primary Muscles") {
                ForEach(exercise.primaryMuscleGroups, id: \.self) { muscle in
                    Text(muscle.displayName)
                }
            }

            if !exercise.secondaryMuscleGroups.isEmpty {
                Section("Secondary Muscles") {
                    ForEach(exercise.secondaryMuscleGroups, id: \.self) { muscle in
                        Text(muscle.displayName)
                    }
                }
            }

            Section("Progress") {
                if exercise.logs.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete a workout with this exercise to see your progress.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ExerciseStatsSection(exercise: exercise)
                    ExerciseTrendChart(exercise: exercise)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if !exercise.logs.isEmpty {
                Section("Recent Sessions") {
                    ExerciseRecentSessionsSection(exercise: exercise)
                }
            }

            Section("In Templates") {
                TemplatesContainingExercise(exerciseId: exercise.id)
            }

            if !exercise.logs.isEmpty {
                Section("Notes") {
                    ExerciseNotesSection(exercise: exercise)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stats

struct ExerciseStatsSection: View {
    let exercise: Exercise

    private var allSets: [SetLog] {
        exercise.logs.flatMap(\.sets)
    }

    private var weightPR: Double {
        allSets.map(\.weight).max() ?? 0
    }

    private var repsPR: Int {
        allSets.map(\.reps).max() ?? 0
    }

    private var estimated1RM: Double {
        guard let bestSet = allSets.max(by: {
            epley(weight: $0.weight, reps: $0.reps) < epley(weight: $1.weight, reps: $1.reps)
        }) else { return 0 }
        return epley(weight: bestSet.weight, reps: bestSet.reps)
    }

    private func epley(weight: Double, reps: Int) -> Double {
        guard reps > 1 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    private var volumePR: Double {
        exercise.logs.map { log in
            log.sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }.max() ?? 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                StatCard(title: "Weight PR", value: String(format: "%.1f", weightPR))
                StatCard(title: "Rep PR", value: "\(repsPR)")
                StatCard(title: "Est. 1RM", value: String(format: "%.1f", estimated1RM))
            }
            if volumePR > 0 {
                HStack(spacing: 16) {
                    StatCard(title: "Volume PR", value: String(format: "%.0f", volumePR))
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

// MARK: - Trend Chart

struct ExerciseTrendChart: View {
    let exercise: Exercise

    private var dataPoints: [(date: Date, maxWeight: Double)] {
        exercise.logs
            .compactMap { log -> (Date, Double)? in
                guard let date = log.workout?.date else { return nil }
                let maxW = log.sets.map(\.weight).max() ?? 0
                guard maxW > 0 else { return nil }
                return (date, maxW)
            }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        if dataPoints.count >= 2 {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weight Over Time")
                    .font(.mono(11))
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.maxWeight)
                        )
                        .foregroundStyle(Color.pumpAccent)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.maxWeight)
                        )
                        .foregroundStyle(Color.pumpAccent)
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: .automatic(includesZero: false))
            }
        }
    }
}

struct StatCard: View {
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
        .padding(.vertical, 12)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Recent Sessions

struct ExerciseRecentSessionsSection: View {
    let exercise: Exercise

    private var recentLogs: [ExerciseLog] {
        exercise.logs
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        if recentLogs.isEmpty {
            Text("No sessions recorded")
                .foregroundStyle(.secondary)
        } else {
            ForEach(recentLogs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    if let date = log.workout?.date {
                        Text(date, style: .date)
                            .font(.mono(11))
                            .foregroundStyle(.secondary)
                    }
                    Text(log.sets.map { "\($0.weight)×\($0.reps)" }.joined(separator: "  "))
                        .font(.callout.monospaced())
                }
            }
        }
    }
}

// MARK: - Templates

struct TemplatesContainingExercise: View {
    let exerciseId: UUID
    @Query private var templates: [WorkoutTemplate]

    init(exerciseId: UUID) {
        self.exerciseId = exerciseId
    }

    private var matchingTemplates: [WorkoutTemplate] {
        templates.filter { template in
            template.templateExercises.contains { $0.exerciseId == exerciseId }
        }
    }

    var body: some View {
        if matchingTemplates.isEmpty {
            Text("Not used in any templates")
                .foregroundStyle(.secondary)
        } else {
            ForEach(matchingTemplates) { template in
                Text(template.name)
            }
        }
    }
}

// MARK: - Notes

struct ExerciseNotesSection: View {
    let exercise: Exercise

    private var notesFromLogs: [(date: Date, note: String)] {
        exercise.logs
            .filter { !$0.notes.isEmpty }
            .compactMap { log in
                guard let date = log.workout?.date else { return nil }
                return (date, log.notes)
            }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        if notesFromLogs.isEmpty {
            Text("No notes yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(notesFromLogs, id: \.date) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date, style: .date)
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                    Text(entry.note)
                        .font(.mono(15))
                }
            }
        }
    }
}
