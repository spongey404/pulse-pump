import SwiftUI
import SwiftData

/// New program / Edit program (Ore Programs 03, 04, 13): NAME, TRAINING DAYS PER WEEK (1–7, picking a count picks a spread), WHICH DAYS,
/// WORKOUTS (editable names, the weekdays each lands on, ×), + ADD WORKOUT. Docked CREATE PROGRAM (grey until it has a name, days and a workout)
/// or SAVE CHANGES; edit mode adds a red DELETE PROGRAM.
struct ProgramFormView: View {
    @State var draft: ProgramDraft
    /// "PUSH PULL LEGS" or "BLANK" under NEW PROGRAM; EDIT PROGRAM when editing.
    var title = "NEW PROGRAM"
    let onBack: () -> Void
    let onSaved: (UUID) -> Void
    let onDeleted: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }) private var templates: [WorkoutTemplate]
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ProgramPageHeader(kicker: draft.isEditing ? "PROGRAM" : "NEW PROGRAM", title: draft.isEditing ? "EDIT PROGRAM" : title, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ProgramSectionRow(left: "NAME")
                    TextField("", text: $draft.name, prompt: Text("Name your program").foregroundStyle(Color.inkMuted))
                        .font(.archivo(18, weight: .bold)).foregroundStyle(Color.inkPrimary).focused($nameFocused)
                        .padding(.horizontal, 14).frame(height: 52)
                        .background(Color.surf, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(nameFocused ? Color.accentInk : Color.ruleStrong, lineWidth: 1))
                        .padding(.horizontal, 16).accessibilityIdentifier(AX.programs.createName)

                    ProgramSectionRow(left: "TRAINING DAYS PER WEEK", right: draft.daysText)
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { n in tile("\(n)", on: draft.daysPerWeek == n, id: AX.programs.createDays(n)) { draft.setDaysPerWeek(n) } }
                    }
                    .padding(.horizontal, 16)

                    ProgramSectionRow(left: "WHICH DAYS", right: draft.pickedText)
                    HStack(spacing: 6) {
                        ForEach(Array(ProgramPlan.weekOrder.enumerated()), id: \.offset) { i, wd in
                            tile(ProgramPlan.weekLetters[i], on: draft.days.contains(wd), id: AX.programs.day(wd)) { draft.toggle(wd) }
                        }
                    }
                    .padding(.horizontal, 16)

                    ProgramSectionRow(left: "WORKOUTS", right: "ROTATE ON YOUR DAYS")
                    VStack(spacing: 0) {
                        ForEach(Array(draft.workouts.enumerated()), id: \.element.id) { i, w in workoutRow(i, w) }
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    ProgramDashedAdd(title: "+ ADD WORKOUT", height: 40, id: AX.programs.createAddWorkout) { withAnimation(.easeInOut(duration: 0.2)) { draft.addWorkout() } }
                        .padding(.horizontal, 16).padding(.top, 12)
                    Text("Workouts take turns on your training days. Add exercises to each one after saving.")
                        .font(.archivo(13)).foregroundStyle(Color.inkSecondary).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
                    if draft.isEditing {
                        Button { confirmDelete = true } label: {
                            Text("DELETE PROGRAM").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.signalDown).padding(.vertical, 10).padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier(AX.programs.deleteProgram).padding(.bottom, 20)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProgramDock {
                ProgramDockedButton(title: draft.isEditing ? "SAVE CHANGES" : "CREATE PROGRAM", enabled: draft.canSave, id: AX.programs.createSave) { save() }
            }
        }
        .destructiveModal(isPresented: $confirmDelete, kicker: "DELETE PROGRAM", title: "Delete \(draft.name.isEmpty ? "this program" : draft.name)?",
                          body: "Its workouts are removed. Sessions you already logged stay in your History.", consequences: deleteConsequences) {
            if let id = draft.programId { ProgramStore.delete(programId: id, modelContext: modelContext) }
            onDeleted()
        }
    }

    private var deleteConsequences: [DestructiveConsequence] {
        guard let id = draft.programId else { return [] }
        let mine = templates.filter { $0.programId == id }
        return [DestructiveConsequence(value: "\(mine.count)", label: "workouts"),
                DestructiveConsequence(value: "\(mine.reduce(0) { $0 + $1.templateExercises.count })", label: "exercises"),
                DestructiveConsequence(value: "\(mine.reduce(0) { $0 + $1.liveWorkouts.count })", label: "past sessions kept")]
    }

    private func save() {
        if draft.isEditing { ProgramStore.save(draft, modelContext: modelContext); onSaved(draft.programId!) }
        else { onSaved(ProgramStore.create(draft, modelContext: modelContext)) }
    }

    /// A count or day tile: 44 pt, radius 8, accent when picked (a selection, not an action).
    private func tile(_ label: String, on: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.spaceMono(15, weight: .bold)).foregroundStyle(on ? Color.white : Color.inkPrimary)
                .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
                .background(on ? Color.oreAccent : Color.surf, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(on ? Color.oreAccent : Color.ruleStrong, lineWidth: 1))
        }
        .buttonStyle(.plain).accessibilityIdentifier(id).accessibilityAddTraits(on ? .isSelected : [])
    }

    private func workoutRow(_ i: Int, _ w: ProgramDraft.Workout) -> some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", i + 1)).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            TextField("", text: Binding(get: { draft.workouts.first { $0.id == w.id }?.name ?? "" },
                                        set: { v in if let k = draft.workouts.firstIndex(where: { $0.id == w.id }) { draft.workouts[k].name = v } }))
                .font(.archivo(15, weight: .bold)).textCase(.uppercase).foregroundStyle(Color.inkPrimary).autocorrectionDisabled()
                .accessibilityIdentifier(AX.programs.workoutName(i))
            Text(draft.weekdayText(forWorkout: i)).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
            if draft.workouts.count > 1 {
                Button { withAnimation(.easeInOut(duration: 0.2)) { draft.remove(w.id) } } label: {
                    Text("×").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkMuted).padding(.vertical, 8).padding(.leading, 6)
                }
                .buttonStyle(.plain).accessibilityLabel("Remove workout").accessibilityIdentifier(AX.programs.workoutRemove(i))
            }
        }
        .padding(.horizontal, 16).frame(minHeight: 48)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
