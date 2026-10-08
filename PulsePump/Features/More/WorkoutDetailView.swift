import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    @State private var pulsePlusService = PulsePlusService()

    private var totalSets: Int { workout.exerciseLogs.flatMap(\.sets).count }
    private var totalExercises: Int { workout.exerciseLogs.count }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            statsStrip
            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            List {
                if isEditing {
                    Section {
                        DatePicker("Date", selection: $workout.date, displayedComponents: .date)
                            .tint(Color.accentInk)
                    }
                }

                ForEach(workout.exerciseLogs.sorted(by: { $0.order < $1.order })) { log in
                    DetailExerciseSectionView(log: log, isEditing: isEditing)
                }

                Section("Notes") {
                    if isEditing {
                        TextField("Workout notes...", text: $workout.notes, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.archivo(13))
                    } else if !workout.notes.isEmpty {
                        Text(workout.notes)
                            .font(.archivo(13))
                            .foregroundStyle(Color.inkMuted)
                    } else {
                        Text("No notes added.")
                            .font(.archivo(13))
                            .foregroundStyle(Color.inkFaint)
                    }
                }

                if pulsePlusService.isSubscribed || pulsePlusService.isInFreeTrial {
                    Section {
                        Toggle("Deload Week", isOn: $workout.isDeload)
                            .tint(Color.accentInk)
                    }
                }

                Color.clear.frame(height: 20)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.canvasBg)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await pulsePlusService.refreshSubscriptionStatus() }
        .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(workout)
                dismiss()
            }
        } message: {
            Text("This workout will be permanently deleted.")
        }
    }

    // MARK: - Header

    private var detailHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.surf2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(shortDate(workout.date))
                    .font(.spaceMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Color.accentInk)
                Text((workout.template?.name ?? "Workout").uppercased())
                    .font(.archivo(18, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
            }

            Spacer()

            if isEditing {
                Button {
                    workout.updatedAt = Date()
                    isEditing = false
                } label: {
                    Text("DONE")
                        .font(.spaceMono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.accentInk)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.accentInk.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Menu {
                    Button { isEditing = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button { duplicateWorkout() } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(value: formatDuration(workout.duration), label: "DURATION")
            Rectangle().fill(Color.dsHairLine).frame(width: 1)
            statCell(value: "\(totalExercises)", label: "EXERCISES")
            Rectangle().fill(Color.dsHairLine).frame(width: 1)
            statCell(value: "\(totalSets)", label: "SETS")
            Rectangle().fill(Color.dsHairLine).frame(width: 1)
            statCell(value: "\(Int(workout.calorieBurnEstimate))", label: "KCAL")
        }
        .frame(height: 60)
        .background(Color.surf)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.spaceMono(14, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
            Text(label)
                .font(.spaceMono(7))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: date).uppercased()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        if h > 0 { return "\(h)H \(m)M" }
        return "\(m)M"
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
        Section(log.exercise?.name ?? "Exercise") {
            let sorted = log.sets.sorted(by: { $0.order < $1.order })
            ForEach(sorted) { setLog in
                EditableSetRow(setLog: setLog, isEditing: isEditing)
            }
            .onDelete(perform: isEditing ? { offsets in deleteSets(at: offsets) } : nil)

            if isEditing {
                Button { addSet() } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.archivo(14))
                        .foregroundStyle(Color.accentInk)
                }
            }

            if isEditing || !log.notes.isEmpty {
                if isEditing {
                    TextField("Exercise notes...", text: $log.notes, axis: .vertical)
                        .font(.archivo(13))
                        .lineLimit(2...4)
                } else {
                    Text(log.notes)
                        .font(.archivo(13))
                        .foregroundStyle(Color.inkMuted)
                }
            }
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
    @Environment(\.weightUnit) private var unit

    @State private var weightText = ""
    @State private var repsText = ""

    var body: some View {
        HStack(spacing: 12) {
            Text("S\(setLog.order + 1)")
                .font(.spaceMono(9))
                .foregroundStyle(Color.inkMuted)
                .frame(width: 24, alignment: .leading)

            Spacer()

            if isEditing {
                HStack(spacing: 8) {
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.spaceMono(15, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 64)
                        .onChange(of: weightText) { _, v in
                            // Field is in the display unit; SetLog.weight stays kg. Only write on a real edit.
                            if v != unit.inputText(setLog.weight), let kg = unit.parseKg(v) { setLog.weight = kg }
                        }
                    Text("×")
                        .font(.spaceMono(11))
                        .foregroundStyle(Color.inkMuted)
                    TextField("0", text: $repsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.spaceMono(15, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 40)
                        .onChange(of: repsText) { _, v in
                            setLog.reps = Int(v) ?? setLog.reps
                        }
                }
            } else {
                if setLog.weight > 0 || setLog.reps > 0 {
                    Text("\(unit.number(setLog.weight)) \(unit.label) × \(setLog.reps)")
                        .font(.spaceMono(13, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                }
                if let rir = setLog.rir {
                    Text("RIR \(rir)")
                        .font(.spaceMono(10))
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
        .onAppear {
            weightText = setLog.weight > 0 ? unit.inputText(setLog.weight) : ""
            repsText = setLog.reps > 0 ? "\(setLog.reps)" : ""
        }
    }
}
