import SwiftUI
import SwiftData

struct EditTemplateView: View {
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var exercises: [TemplateExerciseEntry]
    @State private var showExercisePicker = false

    init(template: WorkoutTemplate) {
        self.template = template
        _name = State(initialValue: template.name)
        _exercises = State(initialValue: template.templateExercises.sorted(by: { $0.order < $1.order }).map {
            TemplateExerciseEntry(exerciseId: $0.exerciseId, exerciseName: $0.exerciseName, targetSets: $0.targetSets, targetReps: $0.targetReps)
        })
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack(alignment: .center, spacing: 10) {
                Button { dismiss() } label: {
                    Text("‹")
                        .font(.mono(24, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)

                Text("EDIT PROGRAM")
                    .font(.display(22))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    save()
                    dismiss()
                } label: {
                    Text("SAVE")
                        .font(.display(16))
                        .foregroundStyle(canSave ? Color.canvasBg : Color.inkMuted)
                        .frame(height: 32)
                        .padding(.horizontal, 14)
                        .background(canSave ? Color.oreAccent : Color.surf)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(canSave ? Color.accentInk : Color.inkPrimary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 10)

            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROGRAM NAME")
                            .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted)
                        TextField("Program name", text: $name)
                            .font(.display(20))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(height: 46)
                            .padding(.horizontal, 14)
                            .background(Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(name.isEmpty ? Color.inkPrimary.opacity(0.12) : Color.accentInk)
                            )
                    }
                    .padding(16)

                    // Exercises section
                    VStack(spacing: 0) {
                        HStack {
                            Text("EXERCISES")
                                .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted)
                            Spacer()
                            Text("\(exercises.count) ADDED")
                                .font(Font.mono(9)).foregroundStyle(Color.inkMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        if !exercises.isEmpty {
                            VStack(spacing: 0) {
                                // Column headers
                                HStack {
                                    Text("EXERCISE")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("SETS").frame(width: 50, alignment: .trailing)
                                    Text("REPS").frame(width: 50, alignment: .trailing)
                                    Spacer().frame(width: 36)
                                }
                                .font(Font.mono(9)).tracking(0.5).foregroundStyle(Color.inkMuted)
                                .padding(.horizontal, 16).padding(.vertical, 10)

                                Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

                                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, entry in
                                    HStack(spacing: 8) {
                                        Text(entry.exerciseName.uppercased())
                                            .font(Font.mono(11, weight: .medium))
                                            .foregroundStyle(Color.inkPrimary)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Stepper("", value: $exercises[index].targetSets, in: 1...10)
                                            .labelsHidden()
                                            .frame(width: 1)
                                        Text("\(exercises[index].targetSets)")
                                            .font(Font.mono(13, weight: .bold))
                                            .foregroundStyle(Color.inkPrimary)
                                            .frame(width: 28, alignment: .trailing)

                                        Stepper("", value: Binding(
                                            get: { exercises[index].targetReps ?? 10 },
                                            set: { exercises[index].targetReps = $0 }
                                        ), in: 1...50)
                                        .labelsHidden()
                                        .frame(width: 1)
                                        Text(exercises[index].targetReps.map { "\($0)" } ?? "—")
                                            .font(Font.mono(13))
                                            .foregroundStyle(Color.inkMuted)
                                            .frame(width: 28, alignment: .trailing)

                                        Button {
                                            exercises.remove(at: index)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(Color.signalDown.opacity(0.7))
                                                .font(.mono(16))
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 28)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 10)

                                    if index < exercises.count - 1 {
                                        Rectangle().fill(Color.dsHairLine).frame(height: 0.5).padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.dsHairLine))
                            .padding(.horizontal, 16)
                        }

                        // Add exercise button
                        Button {
                            showExercisePicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus").font(.mono(13))
                                Text("ADD EXERCISE").font(Font.mono(11)).tracking(0.5)
                            }
                            .foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.canvasBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(Color.inkFaint)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { selected in
                selected.forEach { exercise in
                    exercises.append(TemplateExerciseEntry(
                        exerciseId: exercise.id,
                        exerciseName: exercise.name
                    ))
                }
                showExercisePicker = false
            }
        }
    }

    private func save() {
        template.name = name.trimmingCharacters(in: .whitespaces)
        template.templateExercises = exercises.enumerated().map { index, entry in
            TemplateExercise(
                exerciseId: entry.exerciseId,
                exerciseName: entry.exerciseName,
                order: index,
                targetSets: entry.targetSets,
                targetReps: entry.targetReps
            )
        }
        template.markUpdated()
    }
}
