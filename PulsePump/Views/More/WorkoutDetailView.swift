import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    @State private var pulsePlusService = PulsePlusService()

    var body: some View {
        List {
            Section("Summary") {
                if isEditing {
                    DatePicker("Date", selection: $workout.date, displayedComponents: .date)
                        .tint(Color.pumpPrimary)
                } else {
                    LabeledContent("Date", value: workout.date, format: .dateTime.month().day().year())
                }
                LabeledContent("Duration", value: formatDuration(workout.duration))
                LabeledContent("Calories", value: "\(Int(workout.calorieBurnEstimate))")
                if let template = workout.template {
                    LabeledContent("Template", value: template.name)
                }
                if pulsePlusService.isSubscribed || pulsePlusService.isInFreeTrial {
                    Toggle("Deload Week", isOn: $workout.isDeload)
                }
            }

            ForEach(workout.exerciseLogs.sorted(by: { $0.order < $1.order })) { log in
                DetailExerciseSectionView(log: log, isEditing: isEditing)
            }

            // Workout notes
            Section("Notes") {
                if isEditing {
                    TextField("Workout notes...", text: $workout.notes, axis: .vertical)
                        .lineLimit(3...6)
                } else if !workout.notes.isEmpty {
                    Text(workout.notes)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No notes")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .navigationTitle(workout.template?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Done") {
                        workout.updatedAt = Date()
                        isEditing = false
                    }
                    .fontWeight(.semibold)
                } else {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

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
        }
        .task {
            await pulsePlusService.refreshSubscriptionStatus()
        }
        .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(workout)
                dismiss()
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

// MARK: - Exercise Detail Section

struct DetailExerciseSectionView: View {
    @Bindable var log: ExerciseLog
    let isEditing: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        detailSection
    }

    private var detailSection: some View {
        Section(log.exercise?.name ?? "Exercise") {
            setsRows
            if isEditing { addSetButton }
            notesRow
        }
    }

    private var setsRows: some View {
        let sorted = log.sets.sorted(by: { $0.order < $1.order })
        return ForEach(sorted) { setLog in
            EditableSetRow(setLog: setLog, isEditing: isEditing)
        }
        .onDelete(perform: isEditing ? { offsets in deleteSets(at: offsets) } : nil)
    }

    private var addSetButton: some View {
        Button { addSet() } label: {
            Label("Add Set", systemImage: "plus")
                .font(.subheadline)
                .foregroundStyle(Color.pumpPrimary)
        }
    }

    @ViewBuilder
    private var notesRow: some View {
        if isEditing {
            TextField("Exercise notes...", text: $log.notes, axis: .vertical)
                .font(.caption)
                .lineLimit(2...4)
        } else if !log.notes.isEmpty {
            Text(log.notes)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func deleteSets(at offsets: IndexSet) {
        let sorted = log.sets.sorted(by: { $0.order < $1.order })
        for index in offsets { modelContext.delete(sorted[index]) }
        for (i, s) in log.sets.sorted(by: { $0.order < $1.order }).enumerated() { s.order = i }
    }

    private func addSet() {
        let lastSet = log.sets.sorted(by: { $0.order < $1.order }).last
        let newSet = SetLog(
            order: (log.sets.map(\.order).max() ?? -1) + 1,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0
        )
        newSet.exerciseLog = log
        modelContext.insert(newSet)
    }
}

// MARK: - Editable Set Row

struct EditableSetRow: View {
    @Bindable var setLog: SetLog
    let isEditing: Bool

    @State private var weightText = ""
    @State private var repsText = ""

    var body: some View {
        HStack {
            Text("Set \(setLog.order + 1)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Spacer()

            if isEditing {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .onChange(of: weightText) { _, v in
                        setLog.weight = Double(v) ?? setLog.weight
                    }

                Text("×")
                    .foregroundStyle(.secondary)

                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                    .onChange(of: repsText) { _, v in
                        setLog.reps = Int(v) ?? setLog.reps
                    }
            } else {
                if setLog.weight > 0 || setLog.reps > 0 {
                    Text("\(String(format: "%g", setLog.weight)) × \(setLog.reps)")
                        .font(.callout.monospacedDigit())
                }
                if let rir = setLog.rir {
                    Text("RIR \(rir)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            weightText = setLog.weight > 0 ? String(format: "%g", setLog.weight) : ""
            repsText = setLog.reps > 0 ? "\(setLog.reps)" : ""
        }
    }
}
