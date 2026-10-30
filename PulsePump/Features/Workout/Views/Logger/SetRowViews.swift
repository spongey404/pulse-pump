import SwiftUI
import SwiftData

struct NewSetRowView: View {
    @Binding var setEntry: SetEntry
    let setIndex: Int
    var exerciseIndex: Int = 0
    let exerciseType: ExerciseType
    let showRIR: Bool
    let ghostText: (weight: String, reps: String)?
    /// One tinted row per screen — only the next set to log is active. Completion is
    /// carried by the check control, not by a background colour, so completed rows
    /// return to canvas and never tint green (green is deltaUp, and it never fills a
    /// surface). See design_handoff_pulse_color_system/Set Row States.dc.html.
    let isActive: Bool
    let onSetTypeTap: () -> Void
    let onLog: () -> Void
    var onUnlog: () -> Void = {}
    let onDelete: () -> Void
    /// The row the tutorial walks through: its check circle is a spotlight target.
    var isTutorialRow = false
    @Environment(\.weightUnit) private var unit

    /// A previous-session value the user hasn't logged yet this session — dimmer than
    /// a plain pending row, per the Ghost state in the states spec.
    private var isGhost: Bool {
        guard !setEntry.isCompleted, !isActive else { return false }
        let ghostWeight = ghostText?.weight ?? ""
        let ghostReps = ghostText?.reps ?? ""
        return (!ghostWeight.isEmpty && setEntry.weight.isEmpty)
            || (!ghostReps.isEmpty && setEntry.reps.isEmpty)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Row background — only the active row is tinted, always with accentSoft.
            if isActive {
                Color.accentSoft
                    .transition(.opacity)
            }

            // Left accent border for the active set only
            if isActive {
                HStack(spacing: 0) {
                    Color.accentInk.frame(width: 2)
                    Spacer()
                }
                .transition(.opacity)
            }

            // Row content
            HStack(spacing: 0) {
                // TYPE chip — 36px wide
                setTypeChipButton
                    .frame(width: SetTypeChipLabel.column, alignment: .leading)

                // Set number — 22px wide
                Text(String(format: "%02d", setIndex + 1))
                    .font(.spaceMono(10, weight: .bold))
                    .foregroundStyle(isActive ? Color.accentInk : Color.inkMuted)
                    .frame(width: 22, alignment: .leading)
                    .accessibilityIdentifier(AX.workout.setNumber(ex: exerciseIndex, setIndex + 1))

                // WEIGHT field (SetEntry.weight is kg; the field shows/accepts the user's unit)
                Group {
                    switch exerciseType {
                    case .timeBased:
                        weightOrGhostField(
                            entered: $setEntry.duration,
                            ghost: nil,
                            keyboard: .numberPad
                        )
                    case .distanceBased:
                        weightOrGhostField(
                            entered: $setEntry.distance,
                            ghost: nil,
                            keyboard: .decimalPad
                        )
                    default:
                        // No live PR marker here by design — PRs stay a surprise until
                        // the post-workout summary, not spoiled mid-set.
                        weightOrGhostField(
                            entered: $setEntry.weight,
                            ghost: ghostText.map { unit.displayText(kgString: $0.weight) },
                            keyboard: .decimalPad,
                            isKgString: true
                        )
                    }
                }
                .accessibilityIdentifier(AX.workout.setWeight(ex: exerciseIndex, setIndex + 1))
                .frame(maxWidth: .infinity)

                // REPS field (not shown for time/distance-only)
                if exerciseType != .timeBased && exerciseType != .distanceBased {
                    weightOrGhostField(
                        entered: $setEntry.reps,
                        ghost: ghostText?.reps,
                        keyboard: .numberPad
                    )
                    .accessibilityIdentifier(AX.workout.setReps(ex: exerciseIndex, setIndex + 1))
                    .frame(maxWidth: .infinity)
                }

                // RIR field (optional)
                if showRIR {
                    TextField("—", text: $setEntry.rir)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.spaceMono(11, weight: .bold))
                        .foregroundStyle(setEntry.rir.isEmpty ? Color.inkFaint : Color.inkPrimary)
                        .frame(width: 38)
                        .transition(.opacity)
                        .accessibilityIdentifier(AX.workout.setRIR(ex: exerciseIndex, setIndex + 1))
                }

                // Checkmark / log button — 30px wide
                Button {
                    if setEntry.isCompleted {
                        onUnlog()
                    } else {
                        onLog()
                    }
                } label: {
                    checkmarkView
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.8))
                .accessibilityLabel(setEntry.isCompleted ? "Set \(setIndex + 1) done" : "Log set \(setIndex + 1)")
                .accessibilityIdentifier(AX.workout.setCheck(ex: exerciseIndex, setIndex + 1))
                .tutorialTarget("tutorial.set-check", enabled: isTutorialRow)
                .frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: setEntry.isCompleted)
        .opacity(setEntry.setType == .warmup ? 0.65 : 1)
    }

    // MARK: Set Type Chip

    private var setTypeChipButton: some View {
        Button(action: onSetTypeTap) {
            SetTypeChipLabel(type: setEntry.setType)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.workout.setType(ex: exerciseIndex, setIndex + 1))
        .tutorialTarget("tutorial.set-type-chip", enabled: isTutorialRow)
    }

    // MARK: Weight / Ghost field

    @ViewBuilder
    private func weightOrGhostField(
        entered: Binding<String>,
        ghost: String?,
        keyboard: UIKeyboardType,
        isKgString: Bool = false
    ) -> some View {
        ZStack {
            if entered.wrappedValue.isEmpty, let ghost = ghost, !ghost.isEmpty {
                Text(ghost)
                    .font(.spaceMono(18, weight: .bold))
                    .foregroundStyle(Color.inkFaint)
                    .allowsHitTesting(false)
            }
            Group {
                if isKgString {
                    KgTextField(kgString: entered, unit: unit)
                } else {
                    TextField("", text: entered)
                }
            }
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.spaceMono(18, weight: .bold))
            .foregroundStyle(
                entered.wrappedValue.isEmpty ? Color.clear : Color.inkPrimary
            )
        }
        .overlay(alignment: .bottom) {
            let hasGhost = !(ghost ?? "").isEmpty
            if entered.wrappedValue.isEmpty && !setEntry.isCompleted && !hasGhost {
                Rectangle()
                    .fill(Color.inkPrimary.opacity(0.2))
                    .frame(width: 28, height: 1)
                    .offset(y: -2)
            }
        }
    }

    // MARK: Checkmark

    private var checkmarkView: some View {
        Group {
            if setEntry.isCompleted {
                ZStack {
                    Circle().fill(Color.pumpAccent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else if isActive {
                Circle()
                    .strokeBorder(Color.accentInk, lineWidth: 2)
                    .transition(.opacity)
            } else if isGhost {
                Circle()
                    .strokeBorder(Color.inkPrimary.opacity(0.10), lineWidth: 1.5)
            } else {
                Circle()
                    .strokeBorder(Color.inkPrimary.opacity(0.20), lineWidth: 1.5)
            }
        }
        .frame(width: 22, height: 22)
        // A stroked ring is only hit-testable on its stroke; the whole circle must take the tap.
        .contentShape(Circle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: setEntry.isCompleted)
    }
}

// MARK: - Set Type Sheet

struct SetRowView: View {
    @Binding var setEntry: SetEntry
    let setNumber: Int
    var exerciseType: ExerciseType = .weighted
    var isUnilateral: Bool = false
    let ghostText: (weight: String, reps: String)?
    let isCompound: Bool
    let onLog: () -> Void
    var smartSuggestion: String? = nil

    var body: some View {
        NewSetRowView(
            setEntry: $setEntry,
            setIndex: setNumber - 1,
            exerciseType: exerciseType,
            showRIR: !setEntry.rir.isEmpty || setEntry.targetRIR != nil,
            ghostText: ghostText,
            // No sibling-set context in this legacy wrapper — best-effort fallback.
            isActive: !setEntry.isCompleted,
            onSetTypeTap: {},
            onLog: onLog,
            onDelete: {}
        )
    }
}


/// Text field bound to a kg string but edited in the user's unit. Keeps its own text buffer so partial
/// input ("22.") isn't reformatted mid-typing; kg mode is a plain pass-through.
struct KgTextField: View {
    @Binding var kgString: String
    let unit: UnitPreference
    var placeholder: String = ""
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .onAppear { text = unit.displayText(kgString: kgString) }
            .onChange(of: text) { _, new in
                let kg = unit.kgString(displayText: new)
                if kg != kgString { kgString = kg }
            }
            .onChange(of: kgString) { _, new in
                if unit.kgString(displayText: text) != new { text = unit.displayText(kgString: new) }
            }
            .onChange(of: unit) { _, _ in text = unit.displayText(kgString: kgString) }
    }
}

// MARK: - Set type chip

/// What sits in a set row's TYPE column: a dashed "+" while the set is standard, a coloured tag
/// (WU, DROP, AMRAP…) once a type is picked. Both fill the same box, so choosing a type never shifts
/// the row: the tag is never narrower than the placeholder and never wider than the column.
struct SetTypeChipLabel: View {
    let type: SetType

    static let height: CGFloat = 22
    /// The placeholder's width, and the narrowest a tag gets.
    static let minWidth: CGFloat = 28
    /// The TYPE column the row gives it, and the widest a tag gets.
    static let column: CGFloat = 36

    var body: some View {
        if type == .standard {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .foregroundStyle(Color.inkFaint)
                Text("+")
                    .font(.mono(9))
                    .foregroundStyle(Color.inkFaint)
            }
            .frame(width: Self.minWidth, height: Self.height)
        } else {
            let style = setTypeStyles[type] ?? setTypeStyles[.standard]!
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(style.bg)
                Text(style.label)
                    .font(.spaceMono(8, weight: .bold))
                    .foregroundStyle(style.fg)
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 2)
            }
            .frame(minWidth: Self.minWidth, maxWidth: Self.column, minHeight: Self.height, maxHeight: Self.height)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}
