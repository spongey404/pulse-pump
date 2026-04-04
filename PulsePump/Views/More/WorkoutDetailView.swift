import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Date", value: workout.date, format: .dateTime.month().day().year())
                LabeledContent("Duration", value: formatDuration(workout.duration))
                LabeledContent("Calories", value: "\(Int(workout.calorieBurnEstimate))")
                if let template = workout.template {
                    LabeledContent("Template", value: template.name)
                }
            }

            ForEach(workout.exerciseLogs.sorted(by: { $0.order < $1.order })) { log in
                Section(log.exercise?.name ?? "Exercise") {
                    ForEach(log.sets.sorted(by: { $0.order < $1.order })) { setLog in
                        HStack {
                            Text("Set \(setLog.order + 1)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if setLog.weight > 0 {
                                Text("\(String(format: "%g", setLog.weight)) x \(setLog.reps)")
                                    .font(.callout.monospacedDigit())
                            }
                            if let rir = setLog.rir {
                                Text("RIR \(rir)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !log.notes.isEmpty {
                        Text(log.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !workout.notes.isEmpty {
                Section("Notes") {
                    Text(workout.notes)
                }
            }
        }
        .navigationTitle(workout.template?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        duplicateWorkout()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(workout)
            }
        } message: {
            Text("This workout will be permanently deleted.")
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }

    private func duplicateWorkout() {
        let newWorkout = Workout(isDraft: true)
        newWorkout.user = workout.user
        newWorkout.template = workout.template
        modelContext.insert(newWorkout)

        for log in workout.exerciseLogs {
            let newLog = ExerciseLog(order: log.order, notes: log.notes)
            newLog.exercise = log.exercise
            newLog.workout = newWorkout
            modelContext.insert(newLog)

            for setLog in log.sets {
                let newSet = SetLog(
                    order: setLog.order,
                    weight: setLog.weight,
                    reps: setLog.reps,
                    rir: setLog.rir,
                    setType: setLog.setType,
                    side: setLog.side
                )
                newSet.exerciseLog = newLog
                modelContext.insert(newSet)
            }
        }
    }
}
