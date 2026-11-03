import SwiftUI
import SwiftData

/// A workout of a program (Ore Programs 06, 11, 12). Read view: the exercises with their targets and a docked START WORKOUT. Edit view: grips
/// (drag to reorder), a tap expands SETS / REPS LOW / REPS HIGH / TARGET RIR / REST (±15 s) / REMOVE, + ADD EXERCISE, and a docked DONE. An
/// empty workout opens straight into edit mode.
struct ProgramWorkoutView: View {
    let template: WorkoutTemplate
    let program: ProgramSummary?
    let onBack: () -> Void
    let onAddExercises: () -> Void
    let onStart: (WorkoutTemplate) -> Void
    @State private var editing: Bool
    @State private var open: UUID?
    @State private var dragFrom: Int?
    @State private var dragDY: CGFloat = 0
    @Environment(\.modelContext) private var modelContext
    @Query private var library: [Exercise]
    private let rowHeight: CGFloat = 56

    init(template: WorkoutTemplate, program: ProgramSummary?, startsEditing: Bool, onBack: @escaping () -> Void,
         onAddExercises: @escaping () -> Void, onStart: @escaping (WorkoutTemplate) -> Void) {
        self.template = template; self.program = program; self.onBack = onBack; self.onAddExercises = onAddExercises; self.onStart = onStart
        _editing = State(initialValue: startsEditing)
    }

    private var exercises: [TemplateExercise] { template.templateExercises.sorted { $0.order < $1.order } }
    private var dayIndex: Int { (program?.workouts.firstIndex { $0.id == template.id } ?? 0) + 1 }
    private var kicker: String { "\((program?.name ?? "WORKOUT").uppercased()) · DAY \(dayIndex)" }
    private var equipmentById: [UUID: String] { Dictionary(library.map { ($0.id, $0.equipmentType.displayName) }, uniquingKeysWith: { a, _ in a }) }

    var body: some View {
        VStack(spacing: 0) {
            ProgramPageHeader(kicker: kicker, title: template.name.uppercased(), onBack: onBack) {
                ProgramOutlineButton(title: editing ? "DONE" : "EDIT", id: AX.programs.workoutEdit) { withAnimation(.easeInOut(duration: 0.2)) { editing.toggle(); open = nil } }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ProgramSectionRow(left: "\(exercises.count) EXERCISE\(exercises.count == 1 ? "" : "S")", right: timeText)
                    if exercises.isEmpty {
                        Text("No exercises yet. Add some and set their targets.").font(.archivo(14)).foregroundStyle(Color.inkSecondary).padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { i, e in row(i, e) }
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    if editing {
                        ProgramDashedAdd(title: "+ ADD EXERCISE", id: AX.programs.workoutAddExercise, action: onAddExercises).padding(.horizontal, 16).padding(.top, 12)
                    }
                    noteBox
                    Color.clear.frame(height: 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProgramDock {
                if editing {
                    ProgramDockedButton(title: "DONE", id: AX.programs.workoutDone) { withAnimation(.easeInOut(duration: 0.2)) { editing = false; open = nil } }
                } else {
                    ProgramDockedButton(title: "START WORKOUT", enabled: !exercises.isEmpty, id: AX.programs.workoutStartDock) { onStart(template) }
                }
            }
        }
    }

    /// "AVG 52 MIN · LAST 5": only from history; nothing at all with no history or after an edit.
    private var timeText: String {
        guard let m = ProgramPlan.averageMinutes(for: template) else { return "" }
        return "AVG \(m) MIN · LAST \(min(5, template.liveWorkouts.count))"
    }

    // MARK: Rows

    private func shift(_ i: Int) -> CGFloat {
        guard let from = dragFrom else { return 0 }
        let to = max(0, min(exercises.count - 1, from + Int((dragDY / rowHeight).rounded())))
        if i == from { return dragDY }
        if from < to, i > from, i <= to { return -rowHeight }
        if from > to, i < from, i >= to { return rowHeight }
        return 0
    }

    private func row(_ i: Int, _ e: TemplateExercise) -> some View {
        let isOpen = open == e.id && editing
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                if editing {
                    VStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 1).fill(Color.inkMuted).frame(width: 18, height: 2) } }
                        .frame(width: 32, height: 44).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 2)
                            .onChanged { v in open = nil; dragFrom = i; dragDY = v.translation.height }
                            .onEnded { _ in
                                let to = max(0, min(exercises.count - 1, i + Int((dragDY / rowHeight).rounded())))
                                if to != i { move(from: i, to: to) }
                                withAnimation(.easeOut(duration: 0.2)) { dragFrom = nil; dragDY = 0 }
                            })
                        .accessibilityLabel("Reorder")
                } else { Color.clear.frame(width: 12) }
                Text(String(format: "%02d", i + 1)).font(.spaceMono(10)).tracking(1.5).foregroundStyle(Color.inkMuted)
                Button { if editing { withAnimation(.easeInOut(duration: 0.2)) { open = isOpen ? nil : e.id } } } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.exerciseName.uppercased()).font(.archivo(15, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        Text(ProgramTargets.metaLine(e, equipment: equipmentById[e.exerciseId])).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if editing { Text(isOpen ? "▴" : "▾").font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkSecondary).padding(8) }
            }
            .padding(.leading, 4).padding(.trailing, 12).frame(minHeight: rowHeight)
            if isOpen { editor(i, e) }
        }
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .offset(y: shift(i)).zIndex(dragFrom == i ? 5 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AX.programs.exerciseRow(i))
    }

    private func editor(_ i: Int, _ e: TemplateExercise) -> some View {
        VStack(spacing: 0) {
            stepper(i, e, "SETS", .sets, "\(ProgramTargets.sets(e))")
            stepper(i, e, "REPS LOW", .repsLow, "\(ProgramTargets.low(e))")
            stepper(i, e, "REPS HIGH", .repsHigh, "\(ProgramTargets.high(e))")
            stepper(i, e, "TARGET RIR", .rir, ProgramTargets.rir(e).map(String.init) ?? "—")
            stepper(i, e, "REST", .rest, ProgramPlan.clock(ProgramTargets.rest(e)))
            Button { remove(e) } label: {
                Text("REMOVE").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.signalDown).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).padding(.top, 6).accessibilityIdentifier(AX.programs.exerciseRemove(i))
        }
        .padding(.leading, 52).padding(.trailing, 16).padding(.bottom, 12)
    }

    private func stepper(_ i: Int, _ e: TemplateExercise, _ label: String, _ field: ProgramTargets.Field, _ value: String) -> some View {
        ProgramStepperRow(label: label, value: value,
                          minusID: AX.programs.exerciseField(i, field.rawValue, plus: false), plusID: AX.programs.exerciseField(i, field.rawValue, plus: true),
                          onMinus: { change(e.id, field, -1) }, onPlus: { change(e.id, field, 1) })
    }

    // MARK: Note (the logger's note style)

    private var noteBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text.badge.plus").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.inkMuted).padding(.top, 2)
            ZStack(alignment: .topLeading) {
                if template.notes.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("NOTE").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        Text("focus cues, reminders…").font(.archivo(14).italic()).foregroundStyle(Color.inkMuted)
                    }
                    .allowsHitTesting(false)
                }
                TextField("", text: Binding(get: { template.notes }, set: { template.notes = $0; template.markUpdated() }), axis: .vertical)
                    .font(.archivo(14)).foregroundStyle(Color.inkPrimary).lineLimit(1...5).accessibilityIdentifier(AX.programs.workoutNote)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14).padding(.top, 0)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .padding(.top, 12)
    }

    // MARK: Changes (every one marks the workout updated, so it syncs)

    private func change(_ id: UUID, _ field: ProgramTargets.Field, _ dir: Int) {
        var items = template.templateExercises
        guard let k = items.firstIndex(where: { $0.id == id }) else { return }
        ProgramTargets.adjust(&items[k], field, dir)
        template.templateExercises = items
        template.markUpdated()
        try? modelContext.save()
    }

    private func remove(_ e: TemplateExercise) {
        var items = template.templateExercises.filter { $0.id != e.id }.sorted { $0.order < $1.order }
        for k in items.indices { items[k].order = k }
        template.templateExercises = items
        template.markUpdated()
        open = nil
    }

    private func move(from: Int, to: Int) {
        var items = exercises
        let m = items.remove(at: from)
        items.insert(m, at: to)
        for k in items.indices { items[k].order = k }
        template.templateExercises = items
        template.markUpdated()
    }
}
