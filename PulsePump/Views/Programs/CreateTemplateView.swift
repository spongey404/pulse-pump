import SwiftUI
import SwiftData

struct CreateTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var daysPerWeek: Int? = nil
    @State private var selectedSplitType: String? = nil
    @State private var exercises: [TemplateExerciseEntry] = []
    @State private var notes = ""
    @State private var showExercisePicker = false

    private let splitTypes = ["PPL", "UPPER / LOWER", "FULL BODY", "BRO SPLIT", "CUSTOM"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && daysPerWeek != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            customHeader
            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    nameSection
                    daysSection
                    splitTypeSection
                    exercisesSection
                    notesSection
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showExercisePicker) {
            ExercisePickerView(standalone: false) { selected in
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

    private var customHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Text("‹")
                    .font(.mono(24, weight: .light))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)

            Text("NEW PROGRAM")
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
                    .background(canSave ? Color.pumpAccent : Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(canSave ? Color.pumpAccent : Color.inkPrimary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROGRAM NAME")
                .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted)
            TextField("E.G. MY PPL PROGRAM", text: $name)
                .font(.display(20))
                .foregroundStyle(Color.inkPrimary)
                .frame(height: 46)
                .padding(.horizontal, 14)
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(name.isEmpty ? Color.inkPrimary.opacity(0.12) : Color.pumpAccent)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DAYS PER WEEK")
                .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted)
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { d in
                    Button {
                        daysPerWeek = daysPerWeek == d ? nil : d
                    } label: {
                        Text("\(d)")
                            .font(.display(20))
                            .foregroundStyle(daysPerWeek == d ? Color.canvasBg : Color.inkMuted)
                            .frame(width: 38, height: 38)
                            .background(daysPerWeek == d ? Color.pumpAccent : Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(daysPerWeek == d ? Color.pumpAccent : Color.inkPrimary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var splitTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("SPLIT TYPE")
                    .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted)
                Text("(OPTIONAL)")
                    .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted.opacity(0.5))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(splitTypes, id: \.self) { split in
                        Button {
                            selectedSplitType = selectedSplitType == split ? nil : split
                        } label: {
                            Text(split)
                                .font(Font.mono(9, weight: .bold)).tracking(0.8)
                                .foregroundStyle(selectedSplitType == split ? Color.pumpAccent : Color.inkMuted)
                                .frame(height: 30)
                                .padding(.horizontal, 12)
                                .background(Color.surf)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(selectedSplitType == split ? Color.pumpAccent : Color.inkPrimary.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var exercisesSection: some View {
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

            if exercises.isEmpty {
                emptyExerciseState
            } else {
                exerciseList
            }
        }
        .padding(.bottom, 16)
    }

    private var emptyExerciseState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.mono(28))
                .foregroundStyle(Color.inkFaint)

            VStack(spacing: 4) {
                Text("No exercises yet")
                    .font(.mono(14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Text("Add exercises to build your program.\nYou can configure sets, reps and RIR for each.")
                    .font(.mono(12))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button {
                showExercisePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.mono(13, weight: .medium))
                    Text("ADD EXERCISE")
                        .font(.display(16))
                }
                .foregroundStyle(.white)
                .frame(height: 40)
                .padding(.horizontal, 20)
                .background(Color.pumpAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.pumpAccent.opacity(0.4), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(Color.inkFaint)
        )
        .padding(.horizontal, 16)
    }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 10) {
                        Text(entry.exerciseName.uppercased())
                            .font(.display(16))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            exercises.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color.signalDown.opacity(0.7))
                                .font(.mono(16))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if index < exercises.count - 1 {
                        Rectangle().fill(Color.dsHairLine).frame(height: 0.5).padding(.leading, 16)
                    }
                }
            }
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.dsHairLine))
            .padding(.horizontal, 16)

            Button {
                showExercisePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.mono(12, weight: .medium))
                    Text("ADD EXERCISE").font(Font.mono(10)).tracking(1)
                }
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Color.inkFaint)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("NOTES")
                    .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted)
                Text("(OPTIONAL)")
                    .font(Font.mono(9)).tracking(1.3).foregroundStyle(Color.inkMuted.opacity(0.5))
            }
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add program notes…")
                        .font(.mono(13))
                        .italic()
                        .foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(.mono(13))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(height: 70)
                    .padding(.horizontal, 10)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.inkPrimary.opacity(0.12))
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func save() {
        let templateExercises = exercises.enumerated().map { index, entry in
            TemplateExercise(
                exerciseId: entry.exerciseId,
                exerciseName: entry.exerciseName,
                order: index,
                targetSets: entry.targetSets,
                targetReps: entry.targetReps
            )
        }
        let template = WorkoutTemplate(
            name: name.trimmingCharacters(in: .whitespaces),
            templateExercises: templateExercises,
            splitDays: generateSplitDays()
        )
        modelContext.insert(template)
    }

    private func generateSplitDays() -> [String] {
        guard let days = daysPerWeek, days > 0 else { return [] }
        let cycle: [String]
        switch selectedSplitType {
        case "PPL":             cycle = ["P", "P", "L"]
        case "UPPER / LOWER":   cycle = ["U", "L"]
        case "FULL BODY":       cycle = ["F"]
        case "BRO SPLIT":       cycle = ["C", "B", "L", "S", "A"]
        default:                cycle = [String(name.prefix(1).uppercased())]
        }
        return (0..<days).map { cycle[$0 % cycle.count] }
    }
}

struct TemplateExerciseEntry: Identifiable {
    let id = UUID()
    var exerciseId: UUID
    var exerciseName: String
    var targetSets: Int = 3
    var targetReps: Int? = nil
}
