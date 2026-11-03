import SwiftUI
import SwiftData

struct ExerciseAnalytics {
    let prWeight: Double
    let prReps: Int
    let estimated1RM: Double
    let deltaKg: Double?
    let lastNote: String
}

/// One exercise of the logger (Ore Logger 1a "tightened"): `≡ 01 NAME … N/M ···`, a one-line meta, the sunken column strip, 40 pt set
/// rows, then `+ SET` and `+ NOTE`. No ▲/▼ against last time and no per-set PR marks while training: the only live result is a new
/// estimated 1RM, which turns the header's 1RM gold with a star.
struct ExerciseCardView: View {
    @Binding var entry: ExerciseEntry
    let exerciseIndex: Int
    let viewModel: WorkoutViewModel
    /// The set whose field the keypad is editing, if it is in this card.
    var keypad: KeypadTarget?
    /// The one set of the whole workout that is "active" (the next to log), if it is in this card.
    var activeSetIndex: Int?
    var onSetTypeTap: (Int) -> Void
    var onTapField: (Int, LoggerField) -> Void
    var onStartReorder: () -> Void
    var onOpenProgression: () -> Void
    var onOpenRest: () -> Void
    var onOpenReplace: () -> Void
    var onRemove: () -> Void
    var onLogSet: (Int) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var unit
    @State private var analytics: ExerciseAnalytics?
    @State private var menuOpen = false
    @State private var noteOpen = false
    @State private var showProgressionPaywall = false

    private var load: LoggerMath.Load { LoggerMath.load(equipment: entry.equipmentType, exerciseType: entry.exerciseType, name: entry.exerciseName) }
    private var completedSets: Int { entry.sets.filter(\.isCompleted).count }
    private var nextUncompletedSetIdx: Int? { entry.sets.indices.first { !entry.sets[$0].isCompleted } }
    private var isTutorialExercise: Bool { TutorialFocus.shared.exerciseName == entry.exerciseName }
    private var hasPlates: Bool { [EquipmentType.barbell, .ezBar, .trapBar].contains(entry.equipmentType) }
    private var progression: LoggerMath.ProgressionConfig { viewModel.progressionConfig(exerciseIndex: exerciseIndex) }

    var body: some View {
        VStack(spacing: 0) {
            header
            columnStrip
            ForEach(Array(entry.sets.enumerated()), id: \.element.id) { i, set in
                setBlock(i, set)
                    .id("row-\(set.id.uuidString)")
            }
            footer
            if noteOpen { noteBox }
        }
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .task(id: entry.exerciseId) { loadAnalytics() }
        .sheet(isPresented: $showProgressionPaywall) { SupernovaView(onBack: { showProgressionPaywall = false }) }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onStartReorder) {
                VStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 1).fill(Color.inkMuted).frame(width: 18, height: 2) } }
                    .frame(width: 28, height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("Reorder exercises").accessibilityIdentifier(AX.workout.grip(exerciseIndex))
            Text(String(format: "%02d", exerciseIndex + 1)).font(.spaceMono(10)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.top, 4)
                .accessibilityIdentifier(AX.workout.exerciseNumber(exerciseIndex))
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.exerciseName.uppercased()).font(.archivo(17, weight: .bold)).tracking(0.3).foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(AX.workout.exerciseName(exerciseIndex))
                meta.padding(.top, 4)
                if progression.enabled {
                    Text("AUTO · \(progression.reps)+ REPS → +\(unit.formatTight(progression.incrementKg))").font(.spaceMono(8, weight: .bold)).tracking(1.5)
                        .foregroundStyle(Color.accentInk).padding(.top, 4)
                }
                if let note = analytics?.lastNote, !note.isEmpty {
                    Text("\u{201C}\(note)\u{201D}").font(.archivo(12).italic()).foregroundStyle(Color.inkSecondary).padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(completedSets)/\(entry.sets.count)").font(.spaceMono(11, weight: .bold))
                .foregroundStyle(completedSets == entry.sets.count && completedSets > 0 ? Color.signalUp : Color.inkSecondary).padding(.top, 4)
            Button { menuOpen = true } label: {
                Text("···").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkSecondary).frame(width: 36, height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("Exercise options").accessibilityIdentifier(AX.workout.exerciseMenu(exerciseIndex))
            .tutorialTarget("tutorial.exercise-menu", enabled: isTutorialExercise)
            .popover(isPresented: $menuOpen, attachmentAnchor: .point(.bottom), arrowEdge: .top) { menu }
        }
        .padding(.leading, 4).padding(.trailing, 4).padding(.top, 9).padding(.bottom, 7)
    }

    /// `<EQUIPMENT> · PR <best> · 1RM <best>` on one line.
    private var meta: some View {
        let loggedSets = entry.sets.filter { $0.isCompleted && $0.setType != .warmup }.map { (kg: $0.loggedWeightKg, reps: $0.loggedReps) }
        let history = analytics?.estimated1RM ?? 0
        let live = LoggerMath.liveBest(history: history, logged: loggedSets, assisted: load == .assisted)
        var t = Text(entry.equipmentType.displayName.uppercased()).foregroundStyle(Color.inkMuted)
        t = t + Text(" · PR ").foregroundStyle(Color.inkMuted)
        t = t + Text(analytics.map { "\(unit.number($0.prWeight))×\($0.prReps)" } ?? "—").fontWeight(.bold).foregroundStyle(Color.inkPrimary)
        t = t + Text(" · 1RM ").foregroundStyle(Color.inkMuted)
        t = t + Text(live.value > 0 ? "\(Int(unit.display(live.value).rounded()))" : "—").fontWeight(.bold).foregroundStyle(live.beat ? Color.prGold : Color.inkPrimary)
        return HStack(spacing: 4) {
            t.font(.spaceMono(9)).tracking(1.5).lineLimit(1)
            if live.beat { StarBullet(size: 10) }
        }
    }

    private var menu: some View {
        PostMenuPopover {
            LoggerMenuRow(title: "RIR column", value: entry.rirOn ? "ON" : "OFF", valueColor: entry.rirOn ? .accentInk : .inkMuted,
                          tutorialID: isTutorialExercise ? "tutorial.rir-row" : nil) {
                menuOpen = false
                withAnimation(.easeInOut(duration: 0.28)) { entry.rirOn.toggle() }
            }
            LoggerMenuRow(title: "Auto progression", value: progression.enabled ? "\(progression.reps) → +\(LoggerMath.trim(unit.display(progression.incrementKg)))" : "OFF",
                          valueColor: progression.enabled ? .accentInk : .inkMuted) {
                menuOpen = false
                if viewModel.hasPlusAccess() { onOpenProgression() } else { showProgressionPaywall = true }
            }
            LoggerMenuRow(title: "Rest timer", value: "\(Self.clock(restDefault)) ›", valueColor: .inkSecondary) { menuOpen = false; onOpenRest() }
            LoggerMenuRow(title: entry.supersetGroup == nil ? "Superset with next" : "Remove superset",
                          value: entry.supersetGroup.map { "GROUP \($0)" } ?? (exerciseIndex < viewModel.exerciseEntries.count - 1 ? "+ \(viewModel.exerciseEntries[exerciseIndex + 1].exerciseName.uppercased().prefix(12))" : "LAST EXERCISE"),
                          bold: false) {
                menuOpen = false
                viewModel.toggleSuperset(exerciseIndex: exerciseIndex)
            }
            LoggerMenuRow(title: "Replace exercise", value: "›", valueColor: .inkGhost) { menuOpen = false; onOpenReplace() }
            LoggerMenuRow(title: "Remove exercise", destructive: true, divider: false) { menuOpen = false; onRemove() }
        }
    }

    private var restDefault: Int {
        RestTimerService.perExerciseOverride(exerciseId: entry.exerciseId)
            ?? viewModel.restTimer.restDuration(isCompound: entry.isCompound, exerciseId: entry.exerciseId, templateSeconds: entry.restSeconds)
    }

    static func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    // MARK: Columns

    private var columnStrip: some View {
        HStack(spacing: 6) {
            Text("#").frame(width: 40, alignment: .leading)
            switch entry.exerciseType {
            case .timeBased: Text("SEC").frame(maxWidth: .infinity)
            case .distanceBased: Text("DIST").frame(maxWidth: .infinity)
            default:
                Text(load.header(unit: unit.label)).frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
            }
            if entry.rirOn { Text("RIR").frame(width: 30).tutorialTarget("tutorial.rir-header", enabled: isTutorialExercise) }
            Text("✓").frame(width: 28, alignment: .trailing)
        }
        .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.leading, 10).padding(.trailing, 12).padding(.vertical, 5)
        .background(Color.surf2)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: Rows (+ the plate calculator under the next set of a barbell exercise)

    @ViewBuilder private func setBlock(_ i: Int, _ set: SetEntry) -> some View {
        let ghost = viewModel.ghost(exerciseIndex: exerciseIndex, setIndex: i, modelContext: modelContext)
        let isActive = i == activeSetIndex
        VStack(spacing: 0) {
            LoggerSetRow(
                set: set, setIndex: i, exerciseIndex: exerciseIndex, ghost: ghost, load: load, exerciseType: entry.exerciseType, rirOn: entry.rirOn,
                isActive: isActive,
                editing: keypad.flatMap { $0.exerciseIndex == exerciseIndex && $0.setIndex == i ? $0.field : nil },
                onTypeTap: { onSetTypeTap(i) },
                onCheck: { if set.isCompleted { viewModel.unlogSet(exerciseIndex: exerciseIndex, setIndex: i) } else { onLogSet(i) } },
                onTapField: { onTapField(i, $0) },
                onStep: { field, dir in
                    viewModel.step(field, by: dir * Self.stepSize(field, unit: unit), exerciseIndex: exerciseIndex, setIndex: i, modelContext: modelContext, unit: unit)
                },
                onScrubCommit: { field, value in
                    if field == .weight { viewModel.setValue(.weight, unit.kg(fromDisplay: value), exerciseIndex: exerciseIndex, setIndex: i) }
                    else { viewModel.setValue(field, value, exerciseIndex: exerciseIndex, setIndex: i) }
                },
                onSubStep: { sub, field, dir in stepSub(i, sub, field, dir) },
                onSubRemove: { viewModel.removeSub(exerciseIndex: exerciseIndex, setIndex: i, subIndex: $0) },
                onAddSub: { viewModel.addSub(exerciseIndex: exerciseIndex, setIndex: i, unit: unit) },
                isTutorialRow: i == 0 && isTutorialExercise
            )
            .tutorialTarget("tutorial.set-row", enabled: i == 0 && isTutorialExercise)
            if hasPlates && i == nextUncompletedSetIdx { plateSection(i, ghostKg: ghost) }
        }
    }

    static func stepSize(_ field: LoggerField, unit: UnitPreference) -> Double { field == .weight ? LoggerMath.kgStep(unit) : 1 }

    private func stepSub(_ i: Int, _ sub: Int, _ field: LoggerField, _ dir: Double) {
        guard entry.sets[i].subs.indices.contains(sub) else { return }
        var line = entry.sets[i].subs[sub]
        switch field {
        case .weight:
            let shown = unit.display(Double(line.shownWeight) ?? 0)
            line.weight = WorkoutViewModel.kgText(unit.kg(fromDisplay: LoggerMath.stepped(shown, by: dir * LoggerMath.kgStep(unit))))
        default:
            line.reps = "\(Int(LoggerMath.stepped(Double(line.shownReps) ?? 0, by: dir)))"
        }
        entry.sets[i].subs[sub] = line
    }

    @State private var plateOpen = false
    @State private var barKg = 20.0

    @ViewBuilder private func plateSection(_ i: Int, ghostKg: WorkoutViewModel.LoggerGhost?) -> some View {
        let shownKg = Double(entry.sets[i].weight.isEmpty ? (ghostKg?.weight ?? "") : entry.sets[i].weight) ?? 0
        let previousKg: Double? = i > 0 ? Double(entry.sets[i - 1].weight.isEmpty ? (viewModel.ghost(exerciseIndex: exerciseIndex, setIndex: i - 1, modelContext: modelContext)?.weight ?? "") : entry.sets[i - 1].weight) : nil
        if shownKg > 0 {
            LoggerPlateSection(setNumber: i + 1, kg: shownKg, previousKg: previousKg, isOpen: $plateOpen, barKg: $barKg, exerciseIndex: exerciseIndex,
                               tutorial: i == 0 && isTutorialExercise)
                .onAppear { barKg = entry.equipmentType == .ezBar ? 7.5 : (entry.equipmentType == .trapBar ? 25 : unit.olympicBarKg) }
        }
    }

    // MARK: Footer: + SET and + NOTE

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { viewModel.addSet(to: exerciseIndex) }
            } label: {
                Text("+ SET").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity).frame(height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.workout.addSet(exerciseIndex))
            Button { withAnimation(.easeInOut(duration: 0.2)) { noteOpen.toggle() } } label: {
                Text(entry.notes.isEmpty ? "+ NOTE" : "NOTE ✓").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 12).frame(height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1)).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.workout.noteButton(exerciseIndex))
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    /// The existing exercise note box (note icon + a text row), opened from + NOTE, with the "NOTE for next time…" hint.
    private var noteBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text.badge.plus").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.inkMuted).padding(.top, 2)
            ZStack(alignment: .topLeading) {
                if entry.notes.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("NOTE").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        Text("for next time…").font(.archivo(14).italic()).foregroundStyle(Color.inkFaint)
                    }
                    .allowsHitTesting(false)
                }
                TextField("", text: $entry.notes, axis: .vertical).font(.archivo(14)).foregroundStyle(Color.inkPrimary).lineLimit(1...5)
                    .accessibilityIdentifier("workout.exercise.\(exerciseIndex).noteField")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: Analytics

    private func loadAnalytics() {
        let logs = modelContext.finalLogs(forExercise: entry.exerciseId)
        guard !logs.isEmpty else { analytics = nil; return }
        let allSets = logs.flatMap(\.workingSets).filter { $0.weight > 0 && $0.reps > 0 }
        guard let prSet = allSets.max(by: { LoggerMath.epley(kg: $0.weight, reps: $0.reps) < LoggerMath.epley(kg: $1.weight, reps: $1.reps) }) else { return }
        analytics = ExerciseAnalytics(prWeight: prSet.weight, prReps: prSet.reps, estimated1RM: LoggerMath.epley(kg: prSet.weight, reps: prSet.reps),
                                      deltaKg: nil, lastNote: logs.first?.notes ?? "")
    }
}
