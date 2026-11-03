import SwiftUI

/// One set row of the logger (Ore Logger 1a): `# / type pill · KG · REPS · [RIR] · ✓`, 40 pt tall. The active row (the next set to
/// log) has the accent bar and tint and − / + beside its numbers. Every number can be tapped (keypad) or held and dragged (up = more).
struct LoggerSetRow: View {
    let set: SetEntry
    let setIndex: Int
    let exerciseIndex: Int
    let ghost: WorkoutViewModel.LoggerGhost?
    let load: LoggerMath.Load
    let exerciseType: ExerciseType
    let rirOn: Bool
    let isActive: Bool
    /// The field of this row the keypad is editing, if any.
    let editing: LoggerField?

    var onTypeTap: () -> Void
    var onCheck: () -> Void
    var onTapField: (LoggerField) -> Void
    /// − / + (direction -1 / 1) on a field.
    var onStep: (LoggerField, Double) -> Void
    /// A drag moved a field to this value (display unit for weight); nil value = the drag ended without moving.
    var onScrubCommit: (LoggerField, Double) -> Void
    var onSubStep: (Int, LoggerField, Double) -> Void
    var onSubRemove: (Int) -> Void
    var onAddSub: () -> Void
    var isTutorialRow = false

    @Environment(\.weightUnit) private var unit
    @Environment(\.colorScheme) private var scheme
    @State private var scrub: Scrub?

    struct Scrub: Equatable { var field: LoggerField; var value: Double; var fine: Bool }

    private var timeBased: Bool { exerciseType == .timeBased }
    private var distanceBased: Bool { exerciseType == .distanceBased }
    private var usesWeightAndReps: Bool { !timeBased && !distanceBased }

    // MARK: Values

    private var weightText: String {
        let kg = Double(set.weight.isEmpty ? (ghost?.weight ?? "") : set.weight)
        return kg.map { load.format(unit.number($0)) } ?? "—"
    }
    private var repsText: String {
        if set.setType == .leftRight { return "L/R" }
        let t = set.reps.isEmpty ? (ghost?.reps ?? "") : set.reps
        if set.setType == .amrap, set.reps.isEmpty, !set.isCompleted { return "MAX" }
        return t.isEmpty ? "—" : t
    }
    private func solid(_ field: LoggerField) -> Bool {
        if set.isCompleted { return true }
        switch field {
        case .weight: return !set.weight.isEmpty
        case .reps: return !set.reps.isEmpty
        case .rir: return !set.rir.isEmpty
        case .duration: return !set.duration.isEmpty
        case .distance: return !set.distance.isEmpty
        }
    }
    private func color(_ field: LoggerField) -> Color {
        if set.setType == .leftRight && field == .reps { return .inkMuted }
        if solid(field) { return .inkPrimary }
        if field == .weight, ghost?.bumped == true { return .accentInk }      // auto progression took it up
        return .inkMuted
    }
    private func underline(_ field: LoggerField) -> Color { editing == field ? .accentInk : .clear }

    private var columns: (type: CGFloat, check: CGFloat, rir: CGFloat) { (40, 28, 30) }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            ForEach(Array(set.subs.enumerated()), id: \.element.id) { i, sub in subRow(i, sub) }
            if set.setType == .dropset || set.setType == .restPause { addSubRow }
        }
        .background(isActive ? Color.accentSoft : Color.clear)
        .overlay(alignment: .leading) { Rectangle().fill(isActive ? Color.accentInk : Color.clear).frame(width: 2) }
        .opacity(set.setType == .warmup && !isActive ? 0.8 : 1)
        .zIndex(scrub == nil ? 0 : 5)
    }

    private var mainRow: some View {
        HStack(spacing: 6) {
            typeCell.frame(width: columns.type, alignment: .leading)
            if usesWeightAndReps {
                numberCell(.weight, text: weightText).frame(maxWidth: .infinity)
                numberCell(.reps, text: repsText, locked: set.setType == .leftRight).frame(maxWidth: .infinity)
            } else if timeBased {
                numberCell(.duration, text: set.duration.isEmpty ? "—" : set.duration).frame(maxWidth: .infinity)
            } else {
                numberCell(.distance, text: set.distance.isEmpty ? "—" : set.distance).frame(maxWidth: .infinity)
            }
            if rirOn { rirCell.frame(width: columns.rir) }
            check.frame(width: columns.check, alignment: .trailing)
        }
        .padding(.leading, 8).padding(.trailing, 12)
        .frame(minHeight: 40)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .contentShape(Rectangle())
    }

    // MARK: Cells

    private var typeCell: some View {
        Button(action: onTypeTap) {
            Group {
                if set.setType == .standard {
                    Text(String(format: "%02d", setIndex + 1)).font(.spaceMono(12, weight: .bold)).foregroundStyle(isActive ? Color.accentInk : Color.inkMuted)
                        .accessibilityIdentifier(AX.workout.setNumber(ex: exerciseIndex, setIndex + 1))
                } else {
                    let st = setTypeStyles[set.setType] ?? setTypeStyles[.standard]!
                    Text(st.label).font(.spaceMono(8, weight: .bold)).tracking(0.3).foregroundStyle(st.fg).lineLimit(1)
                        .padding(.horizontal, 3).frame(minWidth: 34).frame(height: 20)
                        .background(st.bg, in: RoundedRectangle(cornerRadius: 4))
                        .accessibilityIdentifier(AX.workout.setNumber(ex: exerciseIndex, setIndex + 1))
                }
            }
            .frame(minHeight: 32, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set \(setIndex + 1) type")
        .accessibilityIdentifier(AX.workout.setType(ex: exerciseIndex, setIndex + 1))
        .tutorialTarget("tutorial.set-type-chip", enabled: isTutorialRow)
    }

    private func numberCell(_ field: LoggerField, text: String, locked: Bool = false) -> some View {
        HStack(spacing: 0) {
            if isActive && !set.isCompleted && !locked { stepButton("−") { onStep(field, -1) } }
            ScrubbableNumber(text: scrub?.field == field ? "" : text, color: color(field), underline: underline(field),
                             isEnabled: !locked,
                             makeTracker: { LoggerMath.ScrubTracker(base: scrubBase(field), isKg: field == .weight, step: field == .weight ? LoggerMath.kgStep(unit) : 1,
                                                                  fineStep: field == .weight ? LoggerMath.kgStep(unit, fine: true) : 1) },
                             onTap: { onTapField(field) },
                             changed: { v, fine in scrubChanged(field, v, fine) },
                             ended: { moved in scrubEnded(field, moved) })
                .overlay { if scrub?.field == field { bubble(field) } }
                .accessibilityIdentifier(identifier(field))
                .accessibilityValue(text)
            if isActive && !set.isCompleted && !locked { stepButton("+") { onStep(field, 1) } }
        }
    }

    private func identifier(_ field: LoggerField) -> String {
        switch field {
        case .weight, .duration, .distance: AX.workout.setWeight(ex: exerciseIndex, setIndex + 1)
        case .reps: AX.workout.setReps(ex: exerciseIndex, setIndex + 1)
        case .rir: AX.workout.setRIR(ex: exerciseIndex, setIndex + 1)
        }
    }

    private func stepButton(_ glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkSecondary).frame(width: 24, height: 32).contentShape(Rectangle())
        }
        .buttonStyle(PressOpacityButtonStyle())
        .accessibilityLabel(glyph == "−" ? "Less" : "More")
    }

    private var rirCell: some View {
        let locked = set.setType == .failureSet
        let shown = locked ? "0" : (set.rir.isEmpty ? "\(set.targetRIR ?? 2)" : set.rir)
        return Button { if !locked { onTapField(.rir) } } label: {
            Text(shown).font(.spaceMono(14, weight: .bold))
                .foregroundStyle(locked ? (setTypeStyles[.failureSet]?.fg ?? .inkPrimary) : (solid(.rir) ? Color.inkPrimary : Color.inkMuted))
                .padding(.vertical, 2).overlay(alignment: .bottom) { Rectangle().fill(underline(.rir)).frame(height: 2) }
                .frame(minWidth: 28, minHeight: 32).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.workout.setRIR(ex: exerciseIndex, setIndex + 1))
    }

    // MARK: Check (22 pt, the tick draws in)

    private var check: some View {
        Button(action: onCheck) {
            ZStack {
                Circle().fill(set.isCompleted ? Color.oreAccent : Color.clear)
                if !set.isCompleted { Circle().strokeBorder(isActive ? Color.accentInk : Color.ruleStrong, lineWidth: isActive ? 2 : 1.5) }
                if set.isCompleted { DrawnTick().frame(width: 16, height: 16) }
            }
            .frame(width: 22, height: 22)
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.15), value: set.isCompleted)
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.85))
        .accessibilityLabel(set.isCompleted ? "Set \(setIndex + 1) done" : "Log set \(setIndex + 1)")
        .accessibilityIdentifier(AX.workout.setCheck(ex: exerciseIndex, setIndex + 1))
        .tutorialTarget("tutorial.set-check", enabled: isTutorialRow)
    }

    // MARK: Lines under a set

    private func subLabel(_ i: Int) -> String {
        switch set.setType {
        case .dropset: "D\(i + 1)"
        case .restPause: "R\(i + 1) · 15S"
        default: i == 0 ? "LEFT" : "RIGHT"
        }
    }

    private func subRow(_ i: Int, _ sub: SubLine) -> some View {
        HStack(spacing: 6) {
            Text(subLabel(i)).font(.spaceMono(8, weight: .bold)).tracking(0.8)
                .foregroundStyle(setTypeStyles[set.setType]?.fg ?? .inkMuted)
                .padding(.leading, 10).overlay(alignment: .leading) { Rectangle().fill(Color.ruleStrong).frame(width: 1) }
                .padding(.leading, 6).lineLimit(1).fixedSize()
                .frame(width: columns.type, alignment: .leading)
            HStack(spacing: 0) {
                if set.setType == .dropset {
                    subStep("−") { onSubStep(i, .weight, -1) }
                    Text(load.format(Double(sub.shownWeight).map { unit.number($0) } ?? "—")).font(.spaceMono(14, weight: .bold))
                        .foregroundStyle(sub.weight.isEmpty ? Color.inkMuted : Color.inkPrimary).frame(minWidth: 36)
                    subStep("+") { onSubStep(i, .weight, 1) }
                } else {
                    Text("=").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkMuted).frame(minWidth: 36)
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                subStep("−") { onSubStep(i, .reps, -1) }
                Text(sub.shownReps.isEmpty ? "—" : sub.shownReps).font(.spaceMono(14, weight: .bold))
                    .foregroundStyle(sub.reps.isEmpty ? Color.inkMuted : Color.inkPrimary).frame(minWidth: 28)
                    .accessibilityIdentifier(AX.workout.subReps(ex: exerciseIndex, setIndex + 1, i + 1))
                subStep("+") { onSubStep(i, .reps, 1) }
            }
            .frame(maxWidth: .infinity)
            if rirOn { Color.clear.frame(width: columns.rir) }
            Group {
                if set.setType != .leftRight && set.subs.count > 1 {
                    Button { onSubRemove(i) } label: { Text("×").font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkMuted).frame(width: 22, height: 28) }
                        .buttonStyle(.plain).accessibilityLabel("Remove line")
                } else { Color.clear.frame(width: 22, height: 28) }
            }
            .frame(width: columns.check, alignment: .trailing)
        }
        .padding(.leading, 8).padding(.trailing, 12).frame(minHeight: 34)
        .overlay(alignment: .top) { DashedLine() }
    }

    private func subStep(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkMuted).frame(width: 22, height: 28).contentShape(Rectangle())
        }
        .buttonStyle(PressOpacityButtonStyle())
    }

    private var addSubRow: some View {
        Button(action: onAddSub) {
            Text(set.setType == .dropset ? "+ DROP" : "+ ROUND").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity).frame(height: 26)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain)
        .padding(.leading, 40).padding(.trailing, 12).padding(.top, 4).padding(.bottom, 6)
        .accessibilityIdentifier(AX.workout.addSub(ex: exerciseIndex, setIndex + 1))
    }

    // MARK: Hold and drag

    private func scrubBase(_ field: LoggerField) -> Double {
        switch field {
        case .weight: return unit.display(Double(set.weight.isEmpty ? (ghost?.weight ?? "") : set.weight) ?? 0)
        case .reps: return Double(set.reps.isEmpty ? (ghost?.reps ?? "") : set.reps) ?? 0
        case .duration: return Double(set.duration) ?? 0
        case .distance: return Double(set.distance) ?? 0
        case .rir: return Double(set.rir) ?? 2
        }
    }

    private func scrubChanged(_ field: LoggerField, _ value: Double, _ fine: Bool) {
        if scrub?.value != value { UISelectionFeedbackGenerator().selectionChanged() }
        scrub = Scrub(field: field, value: value, fine: fine)
    }

    private func scrubEnded(_ field: LoggerField, _ moved: Bool) {
        if moved, let s = scrub, s.field == field { onScrubCommit(field, s.value) }
        scrub = nil
    }

    private func bubble(_ field: LoggerField) -> some View {
        let s = scrub ?? Scrub(field: field, value: 0, fine: false)
        let shown = field == .weight ? load.format(LoggerMath.trim(s.value)) : LoggerMath.trim(s.value)
        let hint = field == .weight ? (s.fine ? "\(LoggerMath.trim(LoggerMath.kgStep(unit, fine: true))) \(unit.label) STEPS" : "\(LoggerMath.trim(LoggerMath.kgStep(unit))) \(unit.label) · SLIDE → FOR \(LoggerMath.trim(LoggerMath.kgStep(unit, fine: true)))") : "1 REP STEPS"
        return VStack(spacing: 3) {
            Text("▲").font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.accentInk)
            Text(shown).font(.spaceMono(30, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1).minimumScaleFactor(0.6)
            Text("▼").font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.accentInk)
            Text(hint).font(.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted).fixedSize()
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 9).frame(minWidth: 108)
        .background(Color.canvasBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.accentInk, lineWidth: 1))
        .fixedSize()
        .alignmentGuide(VerticalAlignment.center) { $0[.bottom] + 28 }     // sits 10 pt above the number
        .allowsHitTesting(false)
        .accessibilityIdentifier("scrub.bubble")
    }
}

extension LoggerMath {
    /// "82.5", "60", "7".
    static func trim(_ v: Double) -> String { UnitPreference.trim(v) }
}

/// A number that taps (keypad) or, when held for 0.22 s, drags: up = more, down = less, 18 pt a step.
struct ScrubbableNumber: View {
    let text: String
    let color: Color
    let underline: Color
    var isEnabled = true
    let makeTracker: () -> LoggerMath.ScrubTracker
    let onTap: () -> Void
    let changed: (Double, Bool) -> Void
    let ended: (Bool) -> Void

    @State private var tracker: LoggerMath.ScrubTracker?
    @State private var origin: CGPoint?

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.spaceMono(17, weight: .bold)).foregroundStyle(color)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 2).padding(.vertical, 2).frame(minWidth: 40)
            .overlay(alignment: .bottom) { Rectangle().fill(underline).frame(height: 2) }
            .frame(minHeight: 32).contentShape(Rectangle())
            .onTapGesture { if isEnabled { onTap() } }
            .gesture(isEnabled ? hold : nil)
    }

    private var hold: some Gesture {
        LongPressGesture(minimumDuration: LoggerMath.holdSeconds)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if tracker == nil {
                    let t = makeTracker()
                    tracker = t; origin = drag?.startLocation
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    changed(t.value, false)
                }
                guard var t = tracker, let drag else { return }
                let o = origin ?? drag.startLocation
                t.update(dragUp: -(drag.location.y - o.y), slideRight: drag.location.x - o.x)
                tracker = t
                changed(t.value, t.fine)
            }
            .onEnded { _ in
                let did = tracker != nil
                tracker = nil; origin = nil
                ended(did)
            }
    }
}

/// The white tick that draws itself in (stroke-dashoffset, 320 ms ease, 60 ms in).
struct DrawnTick: View {
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TickPath().trim(from: 0, to: progress)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2.6 * 16 / 24, lineCap: .round, lineJoin: .round))
            .onAppear {
                if reduceMotion { progress = 1; return }
                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32).delay(0.06)) { progress = 1 }
            }
    }
}

struct TickPath: Shape {
    func path(in r: CGRect) -> Path {
        let s = r.width / 24
        var p = Path()
        p.move(to: CGPoint(x: 5 * s, y: 12.5 * s)); p.addLine(to: CGPoint(x: 9.5 * s, y: 17 * s)); p.addLine(to: CGPoint(x: 19 * s, y: 7.5 * s))
        return p
    }
}

struct DashedLine: View {
    var body: some View {
        Rectangle().fill(Color.clear).frame(height: 1)
            .overlay { GeometryReader { g in Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: g.size.width, y: 0)) }.stroke(Color.dsHairLine, style: StrokeStyle(lineWidth: 1, dash: [3, 3])) } }
    }
}
