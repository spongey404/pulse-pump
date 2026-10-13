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
                if exercise.finalLogs.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete a workout with this exercise to see your progress.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ExerciseStatsSection(exercise: exercise)
                        .accessibilityIdentifier(AX.exercise.detailProgress)
                    ExerciseTrendChart(exercise: exercise)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if !exercise.finalLogs.isEmpty {
                Section("Recent Sessions") {
                    ExerciseRecentSessionsSection(exercise: exercise)
                }
            }

            Section("In Templates") {
                TemplatesContainingExercise(exerciseId: exercise.id)
            }

            if !exercise.finalLogs.isEmpty {
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
    @Environment(\.weightUnit) private var unit
    let exercise: Exercise

    private var progress: ExerciseProgress { ExerciseProgress(exercise: exercise) }
    private var weightPR: Double { progress.weightPR }
    private var repsPR: Int { progress.repsPR }
    private var estimated1RM: Double { progress.estimated1RM }
    private var volumePR: Double { progress.volumePR }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                StatCard(title: "Weight PR (\(unit.lowercaseLabel))", value: unit.number(weightPR))
                StatCard(title: "Rep PR", value: "\(repsPR)")
                StatCard(title: "Est. 1RM (\(unit.lowercaseLabel))", value: unit.number(estimated1RM))
            }
            if volumePR > 0 {
                HStack(spacing: 16) {
                    StatCard(title: "Volume PR (\(unit.lowercaseLabel))", value: unit.volume(volumePR))
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

// MARK: - Trend Chart

struct ExerciseTrendChart: View {
    @Environment(\.weightUnit) private var unit
    let exercise: Exercise

    private var dataPoints: [(date: Date, maxWeight: Double)] { ExerciseProgress(exercise: exercise).trendPoints }

    var body: some View {
        if dataPoints.count >= 2 {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weight Over Time (\(unit.lowercaseLabel))")
                    .font(.mono(11))
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", unit.display(point.maxWeight))
                        )
                        .foregroundStyle(Color.accentInk)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", unit.display(point.maxWeight))
                        )
                        .foregroundStyle(Color.accentInk)
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
    @Environment(\.weightUnit) private var unit
    let exercise: Exercise

    private var recentLogs: [ExerciseLog] { ExerciseProgress(exercise: exercise).recentLogs }

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
                    Text(log.sets.map { "\(unit.number($0.weight))×\($0.reps)" }.joined(separator: "  "))
                        .font(.callout.monospaced())
                }
            }
        }
    }
}

// MARK: - Templates

struct TemplatesContainingExercise: View {
    let exerciseId: UUID
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }) private var templates: [WorkoutTemplate]

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
        exercise.finalLogs
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
