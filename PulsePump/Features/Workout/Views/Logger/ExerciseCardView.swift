import SwiftUI
import SwiftData

struct ExerciseAnalytics {
    let prWeight: Double
    let prReps: Int
    let estimated1RM: Double
    let deltaKg: Double?
    let lastNote: String
}

struct ExerciseCardView: View {
    @Binding var entry: ExerciseEntry
    let exerciseIndex: Int
    let viewModel: WorkoutViewModel
    let onSetTypeTap: (Int) -> Void
    let onMenuTap: (CGRect) -> Void
    var onDragChanged: ((CGFloat) -> Void)? = nil
    var onDragEnded: ((CGFloat) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var unit
    @State private var isCollapsed = false
    @State private var openPlateForSetIdx: Int? = nil
    @State private var plateBarWeight: Double = 20
    @State private var analytics: ExerciseAnalytics? = nil
    @State private var menuButtonFrame: CGRect = .zero

    private var completedSets: Int { entry.sets.filter(\.isCompleted).count }
    private var showRIR: Bool { entry.sets.contains { !$0.rir.isEmpty } || entry.sets.contains { $0.targetRIR != nil } }
    private var isBarbellType: Bool {
        [EquipmentType.barbell, .ezBar, .trapBar, .smithMachine].contains(entry.equipmentType)
    }
    private var nextUncompletedSetIdx: Int? {
        entry.sets.indices.first { !entry.sets[$0].isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Card header
            cardHeader
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if !isCollapsed {
                Rectangle().fill(Color.dsHairLine).frame(height: 1)

                // Column header row
                columnHeaderRow

                Rectangle().fill(Color.dsHairLine).frame(height: 1)

                // Set rows
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { setIdx, set in
                    let ghost = viewModel.ghostText(for: entry.exerciseId, setIndex: setIdx, modelContext: modelContext)
                    let weightStr = set.weight.isEmpty ? (ghost?.weight ?? "") : set.weight
                    let weightVal = parseDecimal(weightStr) ?? 0

                    VStack(spacing: 0) {
                        SwipeToDeleteRow(
                            onDeleteTapped: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: setIdx)
                                }
                            },
                            resetReveal: isCollapsed
                        ) {
                            setRowView(setIdx: setIdx, set: set, ghost: ghost)
                        }

                        // Plate calculator — only for the next uncompleted set
                        if isBarbellType && setIdx == nextUncompletedSetIdx && weightVal > plateBarWeight {
                            let isOpen = openPlateForSetIdx == setIdx
                            VStack(spacing: 0) {
                                Button {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                        openPlateForSetIdx = isOpen ? nil : setIdx
                                    }
                                } label: {
                                    HStack {
                                        Text("PLATES · \(unit.formatTight(weightVal))")
                                            .font(.spaceMono(9))
                                            .tracking(1.2)
                                            .foregroundStyle(Color.inkMuted)
                                        Spacer()
                                        Text(isOpen ? "▴ CLOSE" : "▾ SHOW")
                                            .font(.spaceMono(9))
                                            .tracking(0.8)
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.surf2)
                                }
                                .buttonStyle(.plain)

                                InlinePlateCalculatorView(
                                    targetWeight: weightVal,
                                    barWeight: $plateBarWeight
                                )
                                .frame(maxHeight: isOpen ? .infinity : 0, alignment: .top)
                                .clipped()
                                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isOpen)
                            }
                            .background(Color.surf2)
                        }

                        Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                // Add set row
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            viewModel.addSet(to: exerciseIndex)
                        }
                    } label: {
                        Text("+ ADD SET")
                            .font(.spaceMono(10))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(Color.inkFaint)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        if showRIR {
                            for i in entry.sets.indices {
                                entry.sets[i].rir = ""
                                entry.sets[i].targetRIR = nil
                            }
                        } else {
                            for i in entry.sets.indices {
                                entry.sets[i].targetRIR = 3
                            }
                        }
                    } label: {
                        Text("RIR \(showRIR ? "ON" : "OFF")")
                            .font(.spaceMono(9))
                            .tracking(0.5)
                            .foregroundStyle(showRIR ? Color.inkPrimary : Color.inkMuted)
                            .frame(height: 30)
                            .padding(.horizontal, 10)
                            .background(Color.surf2)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.dsHairLine, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Exercise notes row
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                ExerciseNotesRow(notes: $entry.notes, lastSessionNote: analytics?.lastNote ?? "")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.dsHairLine, lineWidth: 1)
        )
        .task(id: entry.exerciseId) { loadAnalytics() }
        .onAppear { if PlateMath.sameBar(plateBarWeight, 20) { plateBarWeight = unit.olympicBarKg } }
        .onChange(of: unit) { _, u in plateBarWeight = u.olympicBarKg }
    }

    private func loadAnalytics() {
        let logs = modelContext.finalLogs(forExercise: entry.exerciseId)
        guard !logs.isEmpty else { return }

        // All-time best set by estimated 1RM (Epley formula)
        let allSets = logs.flatMap(\.workingSets).filter { $0.weight > 0 && $0.reps > 0 }
        guard let prSet = allSets.max(by: {
            ($0.weight * (1 + Double($0.reps) / 30)) < ($1.weight * (1 + Double($1.reps) / 30))
        }) else { return }
        let estimated1RM = prSet.weight * (1 + Double(prSet.reps) / 30)

        // Delta: most recent session best weight vs session before
        var deltaKg: Double? = nil
        if logs.count >= 2 {
            let lastBest = logs[0].workingSets.map(\.weight).max() ?? 0
            let prevBest = logs[1].workingSets.map(\.weight).max() ?? 0
            if prevBest > 0 { deltaKg = lastBest - prevBest }
        }

        // Last session note for ghost text
        let lastNote = logs.first?.notes ?? ""

        analytics = ExerciseAnalytics(
            prWeight: prSet.weight,
            prReps: prSet.reps,
            estimated1RM: estimated1RM,
            deltaKg: deltaKg,
            lastNote: lastNote
        )
    }

    // MARK: Card Header

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            // Drag handle — hold to reorder, tap propagates to outer onTapGesture
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.inkPrimary)
                        .frame(width: 12, height: 1.5)
                }
            }
            .opacity(0.4)
            .padding(.trailing, 10)
            .highPriorityGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in onDragChanged?(value.translation.height) }
                    .onEnded { value in onDragEnded?(value.translation.height) }
            )

            // Exercise info — fills remaining space, tappable via outer gesture
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%02d", exerciseIndex + 1))
                        .font(.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                        .tracking(1)
                        .fixedSize()
                    Text(entry.exerciseName.uppercased())
                        .font(.archivo(18, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                        .tracking(0.3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 5) {
                    Text(entry.equipmentType.rawValue.uppercased())
                        .font(.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                    if let a = analytics {
                        Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        Text("PR").font(.spaceMono(8)).foregroundStyle(Color.inkMuted)
                        Text("\(unit.number(a.prWeight))×\(a.prReps)")
                            .font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        Text("1RM").font(.spaceMono(8)).foregroundStyle(Color.inkMuted)
                        Text("~\(Int(unit.display(a.estimated1RM).rounded()))")
                            .font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        if let delta = a.deltaKg, abs(delta) > 0.01 {
                            Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                            Text("\(delta > 0 ? "▲" : "▼") \(unit.formatTight(abs(delta)))")
                                .font(.spaceMono(9, weight: .bold))
                                .foregroundStyle(delta > 0 ? Color.signalUp : Color.signalDown)
                        }
                    } else {
                        Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        Text("PR —").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        Text("1RM —").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right side: sets count | menu | collapse — equal 8pt gaps
            HStack(spacing: 8) {
                Text("\(completedSets)/\(entry.sets.count)")
                    .font(.spaceMono(9, weight: .bold))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 28, alignment: .center)

                // ··· menu — Button prevents tap from bubbling to collapse gesture
                Button {
                    onMenuTap(menuButtonFrame)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(GeometryReader { geo in
                    Color.clear.task(id: geo.frame(in: .global).minY) {
                        menuButtonFrame = geo.frame(in: .global)
                    }
                })

                // Collapse arrow — decorative; entire header collapses via outer gesture
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.inkMuted)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isCollapsed)
                    .frame(width: 20, height: 28)
                    .contentShape(Rectangle())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { isCollapsed.toggle() }
        }
    }

    // MARK: Set Row Helper (extracted to avoid type-check timeout)

    @ViewBuilder
    private func setRowView(setIdx: Int, set: SetEntry, ghost: (weight: String, reps: String)?) -> some View {
        NewSetRowView(
            setEntry: Binding(
                get: { entry.sets[setIdx] },
                set: { entry.sets[setIdx] = $0 }
            ),
            setIndex: setIdx,
            exerciseType: entry.exerciseType,
            showRIR: showRIR,
            ghostText: ghost,
            // One tinted row per screen: only the next set to log is "active".
            isActive: setIdx == nextUncompletedSetIdx,
            onSetTypeTap: { onSetTypeTap(setIdx) },
            onLog: {
                // Save ghost values first (empty fields showing placeholders), then PR-check them.
                viewModel.applyGhostValues(exerciseIndex: exerciseIndex, setIndex: setIdx, modelContext: modelContext)
                viewModel.checkPR(exerciseIndex: exerciseIndex, setIndex: setIdx, modelContext: modelContext)
                viewModel.logSet(exerciseIndex: exerciseIndex, setIndex: setIdx, modelContext: modelContext)
            },
            onUnlog: {
                viewModel.unlogSet(exerciseIndex: exerciseIndex, setIndex: setIdx)
            },
            onDelete: {}
        )
    }

    // MARK: Column Header Row

    private var columnHeaderRow: some View {
        let cols: [GridItem] = showRIR
            ? [GridItem(.fixed(36)), GridItem(.fixed(22)), GridItem(.flexible()), GridItem(.flexible()), GridItem(.fixed(38)), GridItem(.fixed(30))]
            : [GridItem(.fixed(36)), GridItem(.fixed(22)), GridItem(.flexible()), GridItem(.flexible()), GridItem(.fixed(30))]

        return HStack(spacing: 0) {
            Text("TYPE")
                .frame(width: 36, alignment: .leading)
            Text("#")
                .frame(width: 22, alignment: .leading)
            Text(unit.label)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("REPS")
                .frame(maxWidth: .infinity, alignment: .center)
            if showRIR {
                Text("RIR")
                    .frame(width: 38, alignment: .center)
            }
            Text("✓")
                .frame(width: 30, alignment: .trailing)
        }
        .font(.spaceMono(8))
        .textCase(.uppercase)
        .tracking(1.5)
        .foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.surf2)
    }
}

// MARK: - New Set Row
