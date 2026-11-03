import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.weightUnit) private var unit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showExercisePicker = false
    @State private var showSearch = false
    /// Tells when the list comes back to its top after being scrolled well down (tapping the status bar does it).
    @State private var scrollDepth = ScrollDepthTracker()
    /// Room added under the list once a search has jumped somewhere, so even the last exercise can scroll up
    /// to the top of the screen (a list normally stops when its end reaches the bottom).
    @State private var jumpPad: CGFloat = 0
    /// The card a search just jumped to (outlined briefly).
    @State private var flashEntryId: UUID?
    /// Whether this pull already opened the search (a pull opens it once; letting go re-arms it).
    @State private var pullArmed = true
    @State private var showIncompleteFinishConfirmation = false
    @State private var setTypeTarget: SetTypeTarget? = nil   // which (exerciseIdx, setIdx) is being edited
    @State private var sheet: LoggerSheetKind?
    @State private var reordering = false
    @State private var keypad: KeypadTarget?
    @State private var keypadBuffer: String?
    @State private var keypadHeight: CGFloat = 330
    @State private var progressionDraft = LoggerMath.ProgressionConfig.off

    private struct SetTypeTarget: Identifiable {
        let id = UUID()
        let exerciseIdx: Int
        let setIdx: Int
    }

    /// The sheets that open over the logger.
    private enum LoggerSheetKind: Equatable {
        case rest(Int?)
        case progression(Int)
        case replace(Int)
    }

    private var totalSets: Int { viewModel.totalSetCount }
    private var doneSets: Int { totalSets - viewModel.unloggedSetCount }
    private var incompleteSetsCount: Int { viewModel.unloggedSetCount }
    private var fillFraction: Double { LoggerMath.fill(done: doneSets, total: totalSets) }

    /// The next set to log in the whole workout: the one active row.
    private var activeSet: (exercise: Int, set: Int)? {
        for (i, e) in viewModel.exerciseEntries.enumerated() { if let j = e.sets.firstIndex(where: { !$0.isCompleted }) { return (i, j) } }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.canvasBg.ignoresSafeArea()

            // Scroll area — sits below masthead (96pt) and above bottom bar (108pt)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        Color.clear.frame(height: 0).id("loggerTop")
                        if reordering {
                            reorderHeader
                            ReorderList(entries: viewModel.exerciseEntries) { from, to in
                                withAnimation(.easeOut(duration: 0.2)) { viewModel.moveExercise(from: IndexSet(integer: from), to: to > from ? to + 1 : to) }
                            }
                        } else {
                            ForEach(Array(viewModel.exerciseEntries.enumerated()), id: \.element.id) { idx, shown in
                                if shown.supersetGroup != nil, idx == 0 || viewModel.exerciseEntries[idx - 1].supersetGroup != shown.supersetGroup { supersetLabel(shown.supersetGroup ?? "") }
                                card(idx, shown)
                            }
                            addExerciseButton
                        }
                        Color.clear.frame(height: 4)
                    }
                    // Dragging the list down past its top opens the search.
                    .background(ScrollPullObserver(onChange: { handlePull($0) }, onDepth: { scrollDepth.note($0) }))
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, keypad == nil ? 118 + jumpPad : 10 + jumpPad)
                    // While the tutorial asks for the pull-down only a drag counts: the cards ignore taps (the
                    // scroll view underneath still takes the drag).
                    .allowsHitTesting(!(TutorialMode.isRunning && TutorialFocus.shared.dragOnly))
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                // The pinned masthead (48pt) plus a gap. As an inset rather than padding inside the list, so
                // scrolling a card "to the top" puts its name just below the masthead, not behind it.
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 56) }
                // The keypad covers the bottom: shrink the list's window to what is above it (+10 pt) so a set can sit just over it.
                .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: keypad == nil ? 0 : keypadHeight + 10) }
                .onReceive(NotificationCenter.default.publisher(for: .loggerScrollTo)) { note in
                    // Eases out to a stop (no overshoot), so it lands on the card instead of jolting into it.
                    withAnimation(.timingCurve(0.25, 0.1, 0.2, 1, duration: 0.6)) {
                        if let id = note.object as? UUID { proxy.scrollTo(id, anchor: .top) } else { proxy.scrollTo("loggerTop", anchor: .top) }
                    }
                    if let id = note.object as? UUID {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                            flashEntryId = id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { if flashEntryId == id { flashEntryId = nil } }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .tutorialRevealTarget)) { note in
                    // Slow and eased, so the user can follow where the list is going.
                    withAnimation(.easeInOut(duration: 1.0)) {
                        switch note.object as? String {
                        case "tutorial.add-exercise": proxy.scrollTo("addExerciseButton", anchor: .center)
                        case "tutorial.set-row", "tutorial.set-check", "tutorial.exercise-menu", "tutorial.set-type-chip", "tutorial.plates-toggle":
                            // The exercise the tutorial is working on.
                            if let name = TutorialFocus.shared.exerciseName,
                               let entry = viewModel.exerciseEntries.first(where: { $0.exerciseName == name }) {
                                proxy.scrollTo(entry.id, anchor: .top)
                            }
                        default: break
                        }
                    }
                }
                .onChange(of: viewModel.exerciseEntries.count) { oldCount, newCount in
                    // (The tutorial keeps the list where it is: its next steps are on the first exercise.)
                    guard newCount > oldCount, !TutorialMode.isRunning else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("addExerciseButton", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: keypad) { old, new in
                    // Opening the keypad on another set scrolls that row to ~10 pt above it.
                    guard let new, old?.exerciseIndex != new.exerciseIndex || old?.setIndex != new.setIndex,
                          viewModel.exerciseEntries.indices.contains(new.exerciseIndex),
                          viewModel.exerciseEntries[new.exerciseIndex].sets.indices.contains(new.setIndex) else { return }
                    let id = "row-\(viewModel.exerciseEntries[new.exerciseIndex].sets[new.setIndex].id.uuidString)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            // Masthead — pinned at top
            mastheadView
                .background(Color.canvasBg)

            // Bottom bar — pinned at bottom (the keypad covers it)
            if keypad == nil {
                VStack {
                    Spacer()
                    bottomBarView
                }
                .ignoresSafeArea(edges: .bottom)
            }

            // Tutorial spotlight for "pull down to search": the list from under the header to a little above
            // the middle of the screen, which is where a thumb starts the pull.
            Color.clear
                .frame(height: UIScreen.main.bounds.height * 0.44)
                .padding(.top, 48)
                .allowsHitTesting(false)
                .tutorialTarget("tutorial.pull-zone")

            // Find an exercise already in the workout without scrolling to it (pull the list down)
            if showSearch {
                LoggerSearchOverlay(
                    workoutEntries: viewModel.exerciseEntries.map { ($0.id, $0.exerciseId, $0.exerciseName) },
                    onJump: { entryId in
                        jumpPad = UIScreen.main.bounds.height * 0.6
                        closeSearch()
                        // Let the panel and keyboard clear, then take the list to that exercise.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            NotificationCenter.default.post(name: .loggerScrollTo, object: entryId)
                        }
                    },
                    onClose: { closeSearch() }
                )
                .transition(.opacity)
                .zIndex(30)
            }

            // The keypad
            if let target = keypad, viewModel.exerciseEntries.indices.contains(target.exerciseIndex) {
                keypadView(target)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { keypadHeight = $0 }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
                    .zIndex(8)
            }

            // Set Type Sheet overlay (dimmed, never blurred)
            if let target = setTypeTarget {
                ZStack {
                    LoggerDim.color.ignoresSafeArea().onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { setTypeTarget = nil } }
                    SetTypeSheetView(
                        currentType: viewModel.exerciseEntries[target.exerciseIdx].sets[target.setIdx].setType,
                        onPick: { newType in
                            viewModel.setSetType(newType, exerciseIndex: target.exerciseIdx, setIndex: target.setIdx, modelContext: modelContext, unit: unit)
                            withAnimation(.easeInOut(duration: 0.18)) { setTypeTarget = nil }
                        },
                        onClose: { withAnimation(.easeInOut(duration: 0.18)) { setTypeTarget = nil } }
                    )
                    .ignoresSafeArea()
                }
                .transition(.opacity)
                .zIndex(10)
            }

            // Sheets
            if let sheet { sheetView(sheet).zIndex(20) }
        }
        .animation(.easeInOut(duration: 0.22), value: keypad)
        .animation(.easeInOut(duration: 0.22), value: sheet)
        .workoutModal(isPresented: $showIncompleteFinishConfirmation,
            title: "Finish workout?",
            message: LoggerMath.finishMessage(unlogged: incompleteSetsCount),
            primaryLabel: "FINISH WORKOUT",
            primaryDestructive: false,
            onPrimary: { viewModel.completeWorkout(modelContext: modelContext) },
            secondaryLabel: "KEEP GOING"
        )
        .workoutModal(isPresented: $viewModel.showCancelConfirmation,
            title: "Discard current workout?",
            message: "Your progress will be lost. Drafts auto-save for 7 days.",
            primaryLabel: "DISCARD WORKOUT",
            primaryDestructive: true,
            onPrimary: { viewModel.cancelWorkout(modelContext: modelContext) },
            secondaryLabel: "SAVE AS DRAFT",
            onSecondary: { viewModel.saveDraftAndClose(modelContext: modelContext) }
        )
        .fullScreenCover(isPresented: $showExercisePicker) {
            ExercisePickerView(excludedIds: Set(viewModel.exerciseEntries.map(\.exerciseId))) { exercises in
                exercises.forEach { viewModel.addExercise($0) }
                showExercisePicker = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { viewModel.saveDraft() }
            if newPhase == .active { viewModel.restTimer.refresh() }
        }
    }

    // MARK: - Cards

    private func card(_ idx: Int, _ shown: ExerciseEntry) -> some View {
        let active = activeSet
        let grouped = shown.supersetGroup != nil
        return HStack(spacing: 0) {
            if grouped { Rectangle().fill(Color.accentInk).frame(width: 2).padding(.trailing, 8) }
            ExerciseCardView(
                // Bounds-guarded: while the screen dismisses after Discard / Finish the entries are
                // already cleared and a stale card must not index past the end (was a crash).
                entry: Binding(
                    get: { viewModel.exerciseEntries.indices.contains(idx) ? viewModel.exerciseEntries[idx] : shown },
                    set: { if viewModel.exerciseEntries.indices.contains(idx) { viewModel.exerciseEntries[idx] = $0 } }
                ),
                exerciseIndex: idx,
                viewModel: viewModel,
                keypad: keypad,
                activeSetIndex: active?.exercise == idx ? active?.set : nil,
                onSetTypeTap: { setIdx in
                    closeKeypad()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { setTypeTarget = SetTypeTarget(exerciseIdx: idx, setIdx: setIdx) }
                },
                onTapField: { setIdx, field in openKeypad(idx, setIdx, field) },
                onStartReorder: { closeKeypad(); withAnimation(.easeInOut(duration: 0.2)) { reordering = true } },
                onOpenProgression: { progressionDraft = viewModel.progressionConfig(exerciseIndex: idx); sheet = .progression(idx) },
                onOpenRest: { sheet = .rest(idx) },
                onOpenReplace: { sheet = .replace(idx) },
                onRemove: { withAnimation(nil) { viewModel.removeExercise(at: idx) } },
                onLogSet: { setIdx in logSet(idx, setIdx) }
            )
            .id(shown.id)
        }
        .overlay {
            // A brief outline on the card a search just jumped to.
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentInk, lineWidth: 2)
                .opacity(flashEntryId == shown.id ? 1 : 0)
                .animation(.easeOut(duration: 0.7), value: flashEntryId)
                .allowsHitTesting(false)
        }
    }

    private func supersetLabel(_ group: String) -> some View {
        HStack(spacing: 8) {
            Text("SUPERSET \(group)").font(.spaceMono(8, weight: .bold)).tracking(2).foregroundStyle(Color.accentInk)
            Text("· ALTERNATE SETS").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            Spacer()
        }
        .padding(.horizontal, 2).padding(.top, 2)
    }

    private var addExerciseButton: some View {
        Button { showExercisePicker = true } label: {
            Text("+ ADD EXERCISE").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity).frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.workout.addExercise)
        .tutorialTarget("tutorial.add-exercise")
        .id("addExerciseButton")
    }

    private var reorderHeader: some View {
        HStack {
            Text("REORDER").font(.spaceMono(9, weight: .bold)).tracking(2).foregroundStyle(Color.inkPrimary)
            Spacer()
            Button { withAnimation(.easeInOut(duration: 0.2)) { reordering = false } } label: {
                Text("DONE").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk).padding(.vertical, 6).padding(.leading, 12)
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.workout.reorderDone)
        }
        .padding(.horizontal, 4).padding(.vertical, 6)
    }

    // MARK: - Logging and the keypad

    private func logSet(_ exerciseIdx: Int, _ setIdx: Int) {
        // Save ghost values first (empty fields showing placeholders), then PR-check them.
        viewModel.applyGhostValues(exerciseIndex: exerciseIdx, setIndex: setIdx, modelContext: modelContext)
        viewModel.checkPR(exerciseIndex: exerciseIdx, setIndex: setIdx, modelContext: modelContext)
        viewModel.logSet(exerciseIndex: exerciseIdx, setIndex: setIdx, modelContext: modelContext)
    }

    private func closeKeypad() { keypad = nil; keypadBuffer = nil }

    private func openKeypad(_ e: Int, _ s: Int, _ field: LoggerField) {
        setTypeTarget = nil
        keypad = KeypadTarget(exerciseIndex: e, setIndex: s, field: field)
        keypadBuffer = nil
    }

    /// The fields the keypad walks through for an exercise before it logs: weight, reps, (RIR).
    private func fields(for entry: ExerciseEntry) -> [LoggerField] {
        switch entry.exerciseType {
        case .timeBased: return [.duration]
        case .distanceBased: return [.distance]
        default: return entry.rirOn ? [.weight, .reps, .rir] : [.weight, .reps]
        }
    }

    private func keypadView(_ t: KeypadTarget) -> some View {
        let entry = viewModel.exerciseEntries[t.exerciseIndex]
        let load = LoggerMath.load(equipment: entry.equipmentType, exerciseType: entry.exerciseType, name: entry.exerciseName)
        let fs = fields(for: entry), idx = fs.firstIndex(of: t.field) ?? 0
        let isLast = idx == fs.count - 1
        let title: String = switch t.field {
        case .weight: load.header(unit: unit.label)
        case .reps: "REPS"
        case .rir: "RIR"
        case .duration: "SEC"
        case .distance: "DIST"
        }
        let nextName: String = isLast ? "LOG SET" : "NEXT " + { () -> String in
            switch fs[idx + 1] { case .weight: return "WEIGHT"; case .reps: return "REPS"; case .rir: return "RIR"; case .duration: return "SEC"; case .distance: return "DIST" } }()
        let steps: [(label: String, delta: Double)] = t.field == .weight
            ? { let s = LoggerMath.kgStep(unit), f = LoggerMath.kgStep(unit, fine: true)
                return [("−\(LoggerMath.trim(s))", -s), ("−\(LoggerMath.trim(f))", -f), ("+\(LoggerMath.trim(f))", f), ("+\(LoggerMath.trim(s))", s)] }()
            : [("−2", -2), ("−1", -1), ("+1", 1), ("+2", 2)]
        let setEntry = entry.sets.indices.contains(t.setIndex) ? entry.sets[t.setIndex] : SetEntry(order: 0)
        return LoggerKeypad(
            fieldTitle: title, field: t.field, nextTitle: nextName, nextGlyph: isLast ? "✓" : "›", stepLabels: steps,
            selectedRir: t.field == .rir ? (setEntry.rir.isEmpty ? nil : Int(setEntry.rir)) : nil,
            onKey: { pressKey($0, t) },
            onBackspace: { pressKey("⌫", t) },
            onStep: { delta in
                keypadBuffer = nil
                viewModel.step(t.field, by: delta, exerciseIndex: t.exerciseIndex, setIndex: t.setIndex, modelContext: modelContext, unit: unit)
            },
            onRir: { v in viewModel.setValue(.rir, Double(v), exerciseIndex: t.exerciseIndex, setIndex: t.setIndex) },
            onNext: {
                if isLast { logSet(t.exerciseIndex, t.setIndex); closeKeypad() }
                else { keypad = KeypadTarget(exerciseIndex: t.exerciseIndex, setIndex: t.setIndex, field: fs[idx + 1]); keypadBuffer = nil }
            },
            onDone: { closeKeypad() }
        )
    }

    private func pressKey(_ key: String, _ t: KeypadTarget) {
        guard viewModel.exerciseEntries.indices.contains(t.exerciseIndex),
              viewModel.exerciseEntries[t.exerciseIndex].sets.indices.contains(t.setIndex) else { return }
        let b = KeypadBuffer.apply(key, to: keypadBuffer ?? "", allowsDecimal: t.field != .reps && t.field != .rir)
        keypadBuffer = b
        let text = KeypadBuffer.value(b) == nil ? "" : b
        switch t.field {
        case .weight: viewModel.exerciseEntries[t.exerciseIndex].sets[t.setIndex].weight = text.isEmpty ? "" : unit.kgString(displayText: text)
        case .reps: viewModel.exerciseEntries[t.exerciseIndex].sets[t.setIndex].reps = text
        case .duration: viewModel.exerciseEntries[t.exerciseIndex].sets[t.setIndex].duration = text
        case .distance: viewModel.exerciseEntries[t.exerciseIndex].sets[t.setIndex].distance = text
        case .rir: break
        }
    }

    // MARK: - Sheets

    @ViewBuilder private func sheetView(_ kind: LoggerSheetKind) -> some View {
        switch kind {
        case .rest(let idx):
            let entries = viewModel.exerciseEntries
            let i = idx ?? activeSet?.exercise ?? 0
            let e = entries.indices.contains(i) ? entries[i] : nil
            RestSheet(restTimer: viewModel.restTimer, exerciseId: e?.exerciseId, exerciseName: e?.exerciseName ?? "", isCompound: e?.isCompound ?? true,
                      templateSeconds: e?.restSeconds, onClose: { sheet = nil })
        case .progression(let idx):
            if viewModel.exerciseEntries.indices.contains(idx) {
                ProgressionSheet(exerciseName: viewModel.exerciseEntries[idx].exerciseName,
                                 config: Binding(get: { progressionDraft }, set: { progressionDraft = $0; viewModel.setProgression($0, exerciseIndex: idx, modelContext: modelContext) }),
                                 onClose: { sheet = nil })
            }
        case .replace(let idx):
            if viewModel.exerciseEntries.indices.contains(idx) {
                ReplaceSheet(entry: viewModel.exerciseEntries[idx], currentExerciseIds: Set(viewModel.exerciseEntries.map(\.exerciseId)),
                             onPick: { ex in viewModel.replaceExerciseKeepingData(at: idx, with: ex); sheet = nil },
                             onClose: { sheet = nil })
            }
        }
    }

    // MARK: - Search

    /// `pulled`: how far the list is dragged down past its top, in points.
    private func handlePull(_ pulled: CGFloat) {
        if pulled > 80, pullArmed, !showSearch {
            pullArmed = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.2)) { showSearch = true }
        } else if pulled < 10 {
            pullArmed = true
        }
    }

    private func closeSearch() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeOut(duration: 0.2)) { showSearch = false }
    }

    // MARK: - Masthead

    private var mastheadView: some View {
        HStack(alignment: .center, spacing: 8) {
            // Back / cancel
            Button { viewModel.showCancelConfirmation = true } label: {
                Text("‹")
                    .font(.archivo(26, weight: .light))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 28, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close workout")
            .accessibilityIdentifier(AX.workout.cancel)
            .tutorialTarget("tutorial.logger-back")

            // Session label + name·duration
            VStack(alignment: .leading, spacing: 0) {
                Text("SESSION")
                    .font(.spaceMono(9))
                    .foregroundStyle(Color.accentInk)
                    .tracking(1.5)
                Text(sessionTitle)
                    .font(.archivo(18, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .tracking(0.3)
                    .lineLimit(1)
                    .accessibilityIdentifier(AX.workout.sessionTitle)
            }

            Spacer()

            // Add an exercise from anywhere in the workout, no scrolling to the bottom
            Button { showExercisePicker = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.inkPrimary.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.92))
            .accessibilityLabel("Add exercise")
            .accessibilityIdentifier(AX.workout.addExerciseTop)
            .tutorialTarget("tutorial.add-top")

            // Rest timer pill
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { sheet = .rest(nil) } } label: {
                restPillView
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.93))
            .accessibilityIdentifier(AX.workout.restPill)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    private var sessionTitle: String {
        let name = (viewModel.workout?.template?.name ?? "WORKOUT").uppercased()
        return "\(name) · \(viewModel.formattedDuration)"
    }

    @Environment(\.colorScheme) private var colorScheme

    private var restPillView: some View {
        let running = viewModel.restTimer.isRunning
        let isDark = colorScheme == .dark
        return HStack(spacing: 8) {
            let runningBg: Color = isDark ? Color(hex: "#1f1c19") : Color.surf2
            let runningFg: Color = isDark ? Color.tickerFg : Color.inkPrimary
            let runningFgMuted: Color = isDark ? Color.tickerFg.opacity(0.7) : Color.inkMuted

            // Label + time
            VStack(alignment: .trailing, spacing: 1) {
                Text("REST")
                    .font(.spaceMono(8))
                    .foregroundStyle(running ? runningFgMuted : Color.inkMuted)
                    .tracking(1)
                Text(running ? viewModel.restTimer.formattedTime : "—:—")
                    .font(.archivo(18))
                    .tracking(1)
                    .foregroundStyle(running ? runningFg : Color.inkMuted)
                    .monospacedDigit()
                    .accessibilityIdentifier(AX.workout.restTime)
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(running ? runningFg.opacity(0.18) : Color.dsHairLine, lineWidth: 2)
                if running {
                    Circle()
                        .trim(from: 0, to: viewModel.restTimer.progress)
                        .stroke(Color.accentInk, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: viewModel.restTimer.progress)
                } else {
                    Text("›")
                        .font(.archivo(14))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(running ? (isDark ? Color(hex: "#1f1c19") : Color.surf2) : Color.surf)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(running ? Color.inkPrimary.opacity(isDark ? 0 : 0.14) : Color.inkPrimary.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: - Finish Button (fills left to right as sets are logged; Stardust in the filled part for members)

    private var finishLabel: some View {
        HStack {
            Text("FINISH WORKOUT").font(.archivo(19, weight: .black)).tracking(1)
            Spacer()
            Text(LoggerMath.leftLabel(done: doneSets, total: totalSets)).font(.spaceMono(10, weight: .bold)).tracking(1.5).contentTransition(.numericText())
        }
        .padding(.horizontal, 20)
    }

    private var bottomBarView: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            Button { showIncompleteFinishConfirmation = true } label: {
                GeometryReader { geo in
                    let fillWidth = geo.size.width * fillFraction
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12).fill(Color.surf2)
                        finishFill(width: fillWidth, height: geo.size.height)
                        // Dark text on the unfilled part
                        finishLabel.foregroundStyle(Color.inkPrimary)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                            .mask(alignment: .trailing) { Rectangle().frame(width: max(0, geo.size.width - fillWidth)).animation(.easeInOut(duration: 0.45), value: fillFraction) }
                        // White text on the filled part
                        finishLabel.foregroundStyle(Color.white)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                            .mask(alignment: .leading) { Rectangle().frame(width: fillWidth).animation(.easeInOut(duration: 0.45), value: fillFraction) }
                    }
                }
                .frame(height: 60)
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.98))
            .accessibilityLabel("Finish workout")
            .accessibilityIdentifier(AX.workout.finish)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .background(Color.canvasBg)
    }

    /// The accent fill. With Stardust on, each logged set adds stars and a little more gradient (like the sign-up screens): the field is
    /// remounted at a denser setting as the bar fills, capped at 30 fps and frozen with Reduce Motion.
    @ViewBuilder private func finishFill(width: CGFloat, height: CGFloat) -> some View {
        let store = AccentStore.shared
        let tier = Int((fillFraction * 6).rounded(.up))
        ZStack {
            // Every logged set adds stars (the field is remounted denser as the bar fills) and a little more gradient; the limiter keeps at
            // most four Stardust buttons animating, this docked one first.
            AccentFill(priority: 10, density: store.stardustEnabled && fillFraction > 0 ? 500 + Double(tier) * 450 : 0, gold: 0.35, sparkle: 0.5, fps: 30)
                .id(tier)
            LinearGradient(colors: [.clear, Color.white.opacity(0.18 * fillFraction)], startPoint: .leading, endPoint: .trailing)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.45), value: fillFraction)
    }
}

// MARK: - Exercise Card

extension Notification.Name {
    /// Scroll the logger's list to an exercise card (object: its entry id), or to the top when the object is nil.
    static let loggerScrollTo = Notification.Name("loggerScrollTo")
}

/// Notices the list returning to the top after being scrolled well down, and says so once. A plain reference
/// type, so the per-frame offset updates don't re-render the logger.
final class ScrollDepthTracker {
    private var deepest: CGFloat = 0

    func note(_ depth: CGFloat) {
        deepest = max(deepest, depth)
        if depth < 2, deepest > 300 {
            deepest = 0
            NotificationCenter.default.post(name: .loggerScrolledToTop, object: nil)
        }
    }
}
