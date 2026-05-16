import SwiftUI
import SwiftData

// MARK: - Set Type Style

private struct SetTypeStyle {
    let bg: Color
    let fg: Color
    let label: String
}

private let setTypeStyles: [SetType: SetTypeStyle] = [
    .standard:   SetTypeStyle(bg: .clear,                              fg: Color.inkMuted,            label: "STD"),
    .warmup:     SetTypeStyle(bg: Color(hex: "#b48c3c").opacity(0.12), fg: Color(hex: "#a17418"),      label: "WU"),
    .superset:   SetTypeStyle(bg: Color(hex: "#7d4a8c").opacity(0.13), fg: Color(hex: "#7d4a8c"),      label: "SS"),
    .dropset:    SetTypeStyle(bg: Color.pumpAccent.opacity(0.13),      fg: Color(hex: "#a8442f"),      label: "DROP"),
    .restPause:  SetTypeStyle(bg: Color.inkPrimary.opacity(0.08),      fg: Color(hex: "#3a342d"),      label: "RP"),
    .amrap:      SetTypeStyle(bg: Color(hex: "#2c6da3").opacity(0.10), fg: Color(hex: "#2c6da3"),      label: "AMRAP"),
    .failureSet: SetTypeStyle(bg: Color.signalDown.opacity(0.10),      fg: Color(hex: "#c0341a"),      label: "FAIL"),
    .leftRight:  SetTypeStyle(bg: Color(hex: "#1f8f5a").opacity(0.10), fg: Color(hex: "#1f8f5a"),      label: "L/R"),
]

// MARK: - Active Workout View

struct ActiveWorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var showExercisePicker = false
    @State private var showIncompleteFinishConfirmation = false
    @State private var showRestModal = false
    @State private var draggingIdx: Int? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var setTypeTarget: SetTypeTarget? = nil   // which (exerciseIdx, setIdx) is being edited
    @State private var exerciseMenuIdx: Int? = nil
    @State private var exerciseMenuAnchor: CGRect = .zero
    @State private var restOverrideIdx: Int? = nil
    @State private var globalRestOverrideSeconds: Int = 90
    @State private var replaceExerciseIdx: Int? = nil

    private struct SetTypeTarget: Identifiable {
        let id = UUID()
        let exerciseIdx: Int
        let setIdx: Int
    }

    private var totalSets: Int {
        viewModel.exerciseEntries.flatMap(\.sets).count
    }
    private var doneSets: Int {
        viewModel.exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
    }
    private var incompleteSetsCount: Int {
        totalSets - doneSets
    }
    private var incompleteExercisesCount: Int {
        viewModel.exerciseEntries.filter { $0.sets.contains { !$0.isCompleted } }.count
    }
    private var fillFraction: Double {
        guard totalSets > 0 else { return 0 }
        return Double(doneSets) / Double(totalSets)
    }

    private var dragTargetIdx: Int? {
        guard let d = draggingIdx else { return nil }
        return max(0, min(viewModel.exerciseEntries.count - 1, d + Int(round(dragOffset / 190))))
    }

    private func cardVisualOffset(for idx: Int) -> CGFloat {
        guard let d = draggingIdx else { return 0 }
        if idx == d { return dragOffset }
        let target = max(0, min(viewModel.exerciseEntries.count - 1, d + Int(round(dragOffset / 190))))
        if d < target && idx > d && idx <= target { return -190 }
        if d > target && idx >= target && idx < d { return 190 }
        return 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.canvasBg.ignoresSafeArea()

            // Scroll area — sits below masthead (96pt) and above bottom bar (108pt)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.exerciseEntries.enumerated()), id: \.element.id) { idx, _ in
                            ExerciseCardView(
                                entry: Binding(
                                    get: { viewModel.exerciseEntries[idx] },
                                    set: { viewModel.exerciseEntries[idx] = $0 }
                                ),
                                exerciseIndex: idx,
                                viewModel: viewModel,
                                onSetTypeTap: { setIdx in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        setTypeTarget = SetTypeTarget(exerciseIdx: idx, setIdx: setIdx)
                                    }
                                },
                                onMenuTap: { frame in
                                    exerciseMenuAnchor = frame
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { exerciseMenuIdx = idx }
                                },
                                onDragChanged: { delta in
                                    draggingIdx = idx
                                    dragOffset = delta
                                },
                                onDragEnded: { delta in
                                    let estimatedCardHeight: CGFloat = 190
                                    let steps = Int(round(delta / estimatedCardHeight))
                                    let newIdx = max(0, min(viewModel.exerciseEntries.count - 1, idx + steps))
                                    if newIdx != idx {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            viewModel.moveExercise(from: IndexSet(integer: idx), to: newIdx > idx ? newIdx + 1 : newIdx)
                                        }
                                    }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        draggingIdx = nil
                                        dragOffset = 0
                                    }
                                }
                            )
                            .offset(y: cardVisualOffset(for: idx))
                            .scaleEffect(draggingIdx == idx ? 1.02 : 1.0)
                            .zIndex(draggingIdx == idx ? 10 : 0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dragTargetIdx)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: draggingIdx == idx)
                        }

                        // Add Exercise button
                        Button { showExercisePicker = true } label: {
                            HStack(spacing: 8) {
                                Text("+")
                                    .font(.spaceMono(14))
                                    .foregroundStyle(Color.inkMuted)
                                Text("ADD EXERCISE")
                                    .font(.spaceMono(10))
                                    .foregroundStyle(Color.inkMuted)
                                    .tracking(1.5)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(Color.inkFaint)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .id("addExerciseButton")

                        Color.clear.frame(height: 4)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 58)    // 48pt masthead + 10pt gap
                    .padding(.bottom, 118)
                }
                .onChange(of: viewModel.exerciseEntries.count) { oldCount, newCount in
                    guard newCount > oldCount else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("addExerciseButton", anchor: .bottom)
                        }
                    }
                }
            }

            // Masthead — pinned at top
            mastheadView
                .background(Color.canvasBg)

            // Bottom bar — pinned at bottom
            VStack {
                Spacer()
                bottomBarView
            }
            .ignoresSafeArea(edges: .bottom)

            // Set Type Sheet overlay
            if let target = setTypeTarget {
                SetTypeSheetView(
                    currentType: viewModel.exerciseEntries[target.exerciseIdx].sets[target.setIdx].setType,
                    onPick: { newType in
                        viewModel.exerciseEntries[target.exerciseIdx].sets[target.setIdx].setType = newType
                        withAnimation(.easeInOut(duration: 0.18)) { setTypeTarget = nil }
                    },
                    onClose: { withAnimation(.easeInOut(duration: 0.18)) { setTypeTarget = nil } }
                )
                .transition(.opacity)
                .ignoresSafeArea()
                .zIndex(10)
            }

            // Rest Timer Modal overlay
            if showRestModal {
                RestTimerModalView(restTimer: viewModel.restTimer, onClose: {
                    withAnimation(.easeInOut(duration: 0.18)) { showRestModal = false }
                })
                .transition(.opacity)
                .ignoresSafeArea()
                .zIndex(10)
            }

            // Global exercise menu overlay
            if let menuIdx = exerciseMenuIdx, menuIdx < viewModel.exerciseEntries.count {
                globalExerciseMenuOverlay(for: menuIdx)
                    .transition(.opacity)
                    .zIndex(20)
            }

            // Global rest override modal overlay
            if let overrideIdx = restOverrideIdx, overrideIdx < viewModel.exerciseEntries.count {
                globalRestOverrideModalOverlay(for: overrideIdx)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { replaceExerciseIdx != nil }, set: { if !$0 { replaceExerciseIdx = nil } })) {
            if let idx = replaceExerciseIdx, idx < viewModel.exerciseEntries.count {
                let otherIds = Set(viewModel.exerciseEntries.enumerated()
                    .filter { $0.offset != idx }
                    .map { $0.element.exerciseId })
                ExercisePickerView(title: "REPLACE EXERCISE", excludedIds: otherIds) { exercises in
                    if let first = exercises.first {
                        viewModel.exerciseEntries[idx].exerciseId = first.id
                        viewModel.exerciseEntries[idx].exerciseName = first.name
                    }
                    replaceExerciseIdx = nil
                }
            }
        }
        .workoutModal(isPresented: $showIncompleteFinishConfirmation,
            title: "Finish with unlogged sets?",
            message: "\(incompleteSetsCount) unlogged \(incompleteSetsCount == 1 ? "set" : "sets") across \(incompleteExercisesCount) \(incompleteExercisesCount == 1 ? "exercise" : "exercises") will be removed.",
            primaryLabel: "REMOVE + FINISH",
            primaryDestructive: false,
            onPrimary: { viewModel.completeWorkout(modelContext: modelContext) }
        )
        .workoutModal(isPresented: $viewModel.showCancelConfirmation,
            title: "Discard current workout?",
            message: "Your progress will be lost. Drafts auto-save for 7 days.",
            primaryLabel: "DISCARD WORKOUT",
            primaryDestructive: true,
            onPrimary: { viewModel.cancelWorkout(modelContext: modelContext) },
            secondaryLabel: "SAVE AS DRAFT",
            onSecondary: { viewModel.saveDraft(); viewModel.isActive = false }
        )
        .fullScreenCover(isPresented: $showExercisePicker) {
            ExercisePickerView(excludedIds: Set(viewModel.exerciseEntries.map(\.exerciseId))) { exercises in
                exercises.forEach { viewModel.addExercise($0) }
                showExercisePicker = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { viewModel.saveDraft() }
        }
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

            // Session label + name·duration
            VStack(alignment: .leading, spacing: 0) {
                Text("SESSION")
                    .font(.spaceMono(9))
                    .foregroundStyle(Color.pumpAccent)
                    .tracking(1.5)
                Text(sessionTitle)
                    .font(.archivo(18, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .tracking(0.3)
                    .lineLimit(1)
            }

            Spacer()

            // Rest timer pill
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showRestModal = true } } label: {
                restPillView
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.93))
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
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(running ? runningFg.opacity(0.18) : Color.dsHairLine, lineWidth: 2)
                if running {
                    Circle()
                        .trim(from: 0, to: viewModel.restTimer.progress)
                        .stroke(Color.pumpAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
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

    // MARK: - Finish Button Label (shared between two masked layers)

    private var finishButtonLabel: some View {
        HStack {
            Text("FINISH WORKOUT")
                .font(.archivo(17, weight: .black))
                .tracking(1.5)
            Spacer()
            if incompleteSetsCount > 0 {
                Text("\(incompleteSetsCount) LEFT")
                    .font(.spaceMono(9, weight: .bold))
                    .tracking(0.8)
                    .contentTransition(.numericText())
            } else {
                Text("DONE ›")
                    .font(.spaceMono(9, weight: .bold))
                    .tracking(0.8)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Bottom Bar

    private var bottomBarView: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.inkPrimary.opacity(0.14)).frame(height: 1)

            Button {
                if incompleteSetsCount > 0 {
                    showIncompleteFinishConfirmation = true
                } else {
                    viewModel.completeWorkout(modelContext: modelContext)
                }
            } label: {
                GeometryReader { geo in
                    let fillWidth = geo.size.width * fillFraction
                    ZStack(alignment: .leading) {
                        // Cream base
                        RoundedRectangle(cornerRadius: 12).fill(Color.surf2)

                        // Orange fill from left
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pumpAccent)
                            .frame(width: fillWidth)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: fillFraction)

                        // Dark text — masked to unfilled (right) portion
                        finishButtonLabel
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                            .mask(alignment: .trailing) {
                                Rectangle()
                                    .frame(width: max(0, geo.size.width - fillWidth))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: fillFraction)
                            }

                        // White text — masked to filled (left) portion
                        finishButtonLabel
                            .foregroundStyle(Color.white)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: fillWidth)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: fillFraction)
                            }
                    }
                }
                .frame(height: 56)
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.98))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color.canvasBg)
    }

    // MARK: - Global Exercise Menu Overlay

    private var windowSafeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 0
    }

    private func globalExerciseMenuOverlay(for idx: Int) -> some View {
        let screenHeight = UIScreen.main.bounds.height
        let menuHeight: CGFloat = 156  // 3 rows × 52
        let safeTop = windowSafeAreaTop
        // Convert button frame from screen coords to ZStack-relative coords
        let buttonBottomY = exerciseMenuAnchor.maxY - safeTop
        let buttonTopY = exerciseMenuAnchor.minY - safeTop
        // Open below if it fits, otherwise flip above
        let fitsBelow = buttonBottomY + 6 + menuHeight <= screenHeight - 40
        let topPadding = fitsBelow
            ? buttonBottomY + 6
            : max(safeTop, buttonTopY - menuHeight - 6)
        let scaleAnchor: UnitPoint = fitsBelow ? .top : .bottom
        return ZStack(alignment: .top) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { exerciseMenuIdx = nil }
                }

            VStack(spacing: 0) {
                menuActionRow(icon: "arrow.triangle.2.circlepath", label: "Replace Exercise", destructive: false) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { exerciseMenuIdx = nil }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { replaceExerciseIdx = idx }
                }
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                menuActionRow(icon: "timer", label: "Rest Timer Override", destructive: false) {
                    globalRestOverrideSeconds = RestTimerService.perExerciseOverride(exerciseId: viewModel.exerciseEntries[idx].exerciseId) ?? 90
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { exerciseMenuIdx = nil }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { restOverrideIdx = idx }
                    }
                }
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                menuActionRow(icon: "trash", label: "Remove Exercise", destructive: true) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { exerciseMenuIdx = nil }
                    withAnimation(nil) { viewModel.removeExercise(at: idx) }
                }
            }
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.dsHairLine, lineWidth: 1))
            .frame(width: UIScreen.main.bounds.width - 48)
            .padding(.top, topPadding)
            .padding(.horizontal, 24)
            .transition(.scale(scale: 0.88, anchor: scaleAnchor).combined(with: .opacity))
        }
    }

    private func menuActionRow(icon: String, label: String, destructive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 24)
                    .foregroundStyle(destructive ? Color.signalDown : Color.inkPrimary)
                Text(label)
                    .font(.archivo(16))
                    .foregroundStyle(destructive ? Color.signalDown : Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressOpacityButtonStyle())
    }

    private func globalRestOverrideModalOverlay(for idx: Int) -> some View {
        let exerciseName = viewModel.exerciseEntries[idx].exerciseName
        let exerciseId = viewModel.exerciseEntries[idx].exerciseId
        return ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { restOverrideIdx = nil }
                }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REST TIMER OVERRIDE")
                        .font(.spaceMono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.inkMuted)
                    Text("Custom rest for \(exerciseName)")
                        .font(.archivo(15, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                }

                HStack(spacing: 0) {
                    Button {
                        globalRestOverrideSeconds = max(15, globalRestOverrideSeconds - 15)
                    } label: {
                        Text("−15")
                            .font(.spaceMono(12, weight: .bold))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 48, height: 44)
                            .background(Color.surf2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.93))

                    Spacer()

                    VStack(spacing: 2) {
                        Text("\(globalRestOverrideSeconds)")
                            .font(.spaceMono(36, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                            .contentTransition(.numericText())
                        Text("SECONDS")
                            .font(.spaceMono(9))
                            .tracking(1.2)
                            .foregroundStyle(Color.inkMuted)
                    }

                    Spacer()

                    Button {
                        globalRestOverrideSeconds += 15
                    } label: {
                        Text("+15")
                            .font(.spaceMono(12, weight: .bold))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 48, height: 44)
                            .background(Color.surf2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.93))
                }
                .padding(.vertical, 4)

                VStack(spacing: 8) {
                    Button {
                        RestTimerService.setPerExerciseOverride(exerciseId: exerciseId, seconds: globalRestOverrideSeconds)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { restOverrideIdx = nil }
                    } label: {
                        Text("SAVE")
                            .font(.archivo(15, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.pumpAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))

                    HStack(spacing: 8) {
                        Button {
                            RestTimerService.setPerExerciseOverride(exerciseId: exerciseId, seconds: nil)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { restOverrideIdx = nil }
                        } label: {
                            Text("RESET")
                                .font(.archivo(13, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(Color.signalDown)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.signalDown.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.signalDown.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { restOverrideIdx = nil }
                        } label: {
                            Text("CANCEL")
                                .font(.archivo(13, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.surf2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.dsHairLine, lineWidth: 1))
                        }
                        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
                    }
                }
            }
            .padding(20)
            .frame(width: UIScreen.main.bounds.width - 40)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.dsHairLine, lineWidth: 1))
            .transition(.scale(scale: 0.88).combined(with: .opacity))
        }
    }
}

// MARK: - Exercise Card

private struct ExerciseAnalytics {
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
                    let weightVal = Double(weightStr) ?? 0

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
                                        Text("PLATES · \(weightStr)KG")
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
    }

    private func loadAnalytics() {
        let exId = entry.exerciseId
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in log.exercise?.id == exId },
            sortBy: [SortDescriptor(\ExerciseLog.createdAt, order: .reverse)]
        )
        guard let logs = try? modelContext.fetch(descriptor), !logs.isEmpty else { return }

        // All-time best set by estimated 1RM (Epley formula)
        let allSets = logs.flatMap(\.sets).filter { $0.weight > 0 && $0.reps > 0 }
        guard let prSet = allSets.max(by: {
            ($0.weight * (1 + Double($0.reps) / 30)) < ($1.weight * (1 + Double($1.reps) / 30))
        }) else { return }
        let estimated1RM = prSet.weight * (1 + Double(prSet.reps) / 30)

        // Delta: most recent session best weight vs session before
        var deltaKg: Double? = nil
        if logs.count >= 2 {
            let lastBest = logs[0].sets.map(\.weight).max() ?? 0
            let prevBest = logs[1].sets.map(\.weight).max() ?? 0
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
                        Text(String(format: "%g×%d", a.prWeight, a.prReps))
                            .font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        Text("1RM").font(.spaceMono(8)).foregroundStyle(Color.inkMuted)
                        Text("~\(Int(a.estimated1RM))")
                            .font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        if let delta = a.deltaKg, abs(delta) > 0.01 {
                            Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                            Text("\(delta > 0 ? "▲" : "▼")\(delta > 0 ? "+" : "")\(String(format: "%g", abs(delta)))KG")
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
            onSetTypeTap: { onSetTypeTap(setIdx) },
            onLog: {
                viewModel.checkPR(exerciseIndex: exerciseIndex, setIndex: setIdx, modelContext: modelContext)
                viewModel.logSet(exerciseIndex: exerciseIndex, setIndex: setIdx, isCompound: true)
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
            Text("KG")
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

struct NewSetRowView: View {
    @Binding var setEntry: SetEntry
    let setIndex: Int
    let exerciseType: ExerciseType
    let showRIR: Bool
    let ghostText: (weight: String, reps: String)?
    let onSetTypeTap: () -> Void
    let onLog: () -> Void
    let onDelete: () -> Void

    private var isActive: Bool { !setEntry.isCompleted }

    var body: some View {
        ZStack(alignment: .leading) {
            // Row background
            if isActive {
                Color.pumpAccent.opacity(0.07)
                    .transition(.opacity)
            } else {
                Color.signalUp.opacity(0.07)
                    .transition(.opacity)
            }

            // Left accent border for active set
            if isActive {
                HStack(spacing: 0) {
                    Color.pumpAccent.frame(width: 2)
                    Spacer()
                }
                .transition(.opacity)
            }

            // Row content
            HStack(spacing: 0) {
                // TYPE chip — 36px wide
                setTypeChipButton
                    .frame(width: 36, alignment: .leading)

                // Set number — 22px wide
                Text(String(format: "%02d", setIndex + 1))
                    .font(.spaceMono(10, weight: .bold))
                    .foregroundStyle(isActive ? Color.pumpAccent : Color.inkMuted)
                    .frame(width: 22, alignment: .leading)

                // KG field
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
                        weightOrGhostField(
                            entered: $setEntry.weight,
                            ghost: ghostText?.weight,
                            keyboard: .decimalPad
                        )
                        .overlay(alignment: .topTrailing) {
                            if setEntry.isPR {
                                Circle()
                                    .fill(Color(hex: "#c98a17"))
                                    .frame(width: 5, height: 5)
                                    .offset(x: -2, y: 2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // REPS field (not shown for time/distance-only)
                if exerciseType != .timeBased && exerciseType != .distanceBased {
                    weightOrGhostField(
                        entered: $setEntry.reps,
                        ghost: ghostText?.reps,
                        keyboard: .numberPad
                    )
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
                }

                // Checkmark / log button — 30px wide
                Button {
                    if setEntry.isCompleted {
                        setEntry.isCompleted = false
                    } else {
                        onLog()
                    }
                } label: {
                    checkmarkView
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.8))
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
            if setEntry.setType == .standard {
                // Dashed "+" placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .foregroundStyle(Color.inkFaint)
                    Text("+")
                        .font(.mono(9))
                        .foregroundStyle(Color.inkFaint)
                }
                .frame(width: 28, height: 22)
            } else {
                let style = setTypeStyles[setEntry.setType] ?? setTypeStyles[.standard]!
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(style.bg)
                    Text(style.label)
                        .font(.spaceMono(8, weight: .bold))
                        .foregroundStyle(style.fg)
                        .tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: 22)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Weight / Ghost field

    @ViewBuilder
    private func weightOrGhostField(
        entered: Binding<String>,
        ghost: String?,
        keyboard: UIKeyboardType
    ) -> some View {
        ZStack {
            if entered.wrappedValue.isEmpty, let ghost = ghost, !ghost.isEmpty {
                Text(ghost)
                    .font(.spaceMono(18, weight: .bold))
                    .foregroundStyle(Color.inkFaint)
                    .allowsHitTesting(false)
            }
            TextField("", text: entered)
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
                    Circle().fill(Color.signalUp)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else if isActive {
                Circle()
                    .strokeBorder(Color.pumpAccent, lineWidth: 2)
                    .transition(.opacity)
            } else {
                Circle()
                    .strokeBorder(Color.inkFaint, lineWidth: 1.5)
            }
        }
        .frame(width: 22, height: 22)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: setEntry.isCompleted)
    }
}

// MARK: - Set Type Sheet

struct SetTypeSheetView: View {
    let currentType: SetType
    let onPick: (SetType) -> Void
    let onClose: () -> Void

    @State private var cardOffset: CGFloat = 500

    private struct TypeRow {
        let type: SetType
        let name: String
        let desc: String
    }

    private let rows: [TypeRow] = [
        TypeRow(type: .standard,   name: "Standard",    desc: "Normal working set"),
        TypeRow(type: .warmup,     name: "Warmup",      desc: "Excluded from volume"),
        TypeRow(type: .superset,   name: "Superset",    desc: "Paired with next exercise, no rest"),
        TypeRow(type: .dropset,    name: "Dropset",     desc: "Multiple weight drops in one set"),
        TypeRow(type: .restPause,  name: "Rest-Pause",  desc: "Short rest, continue same set"),
        TypeRow(type: .amrap,      name: "AMRAP",       desc: "As many reps as possible"),
        TypeRow(type: .failureSet, name: "To Failure",  desc: "Last possible rep"),
        TypeRow(type: .leftRight,  name: "Unilateral",  desc: "Log left and right sides separately"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Invisible tap-to-close area
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            // Sheet card — slides up independently
            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.inkFaint)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // Label
                Text("SET TYPE")
                    .font(.spaceMono(9))
                    .foregroundStyle(Color.pumpAccent)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                // Type rows
                ForEach(rows, id: \.type) { row in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { onPick(row.type) }
                    } label: {
                        HStack(spacing: 10) {
                            let style = setTypeStyles[row.type] ?? setTypeStyles[.standard]!
                            ZStack {
                                if row.type == .standard {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
                                        .foregroundStyle(Color.inkFaint)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(style.bg)
                                }
                                Text(style.label)
                                    .font(.spaceMono(9, weight: .bold))
                                    .foregroundStyle(style.fg)
                                    .tracking(0.6)
                            }
                            .frame(width: 42, height: 22)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.name)
                                    .font(.archivo(14, weight: .semibold))
                                    .foregroundStyle(Color.inkPrimary)
                                Text(row.desc)
                                    .font(.archivo(13))
                                    .foregroundStyle(Color.inkMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if currentType == row.type {
                                Circle()
                                    .fill(Color.pumpAccent)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.dsHairLine).frame(height: 1)
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }

                Color.clear.frame(height: 28)
            }
            .background(Color.canvasBg)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.inkPrimary.opacity(0.14), lineWidth: 1)
                    .padding(.bottom, -28)
            )
            .offset(y: cardOffset)
            .onAppear {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    cardOffset = 0
                }
            }
        }
    }
}

// MARK: - Rest Timer Modal

struct RestTimerModalView: View {
    let restTimer: RestTimerService
    let onClose: () -> Void

    @State private var cardScale: CGFloat = 0.88
    @State private var cardOpacity: Double = 0

    private let ringRadius: CGFloat = 96
    private var ringCircumference: CGFloat { 2 * .pi * ringRadius }
    private var ringSize: CGFloat { ringRadius * 2 + 20 }

    private let targetSeconds: Int = 150 // 2:30 default display

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Card — pushed below the masthead bar
            VStack(spacing: 0) {
                // Ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.inkPrimary.opacity(0.14), lineWidth: 7)
                        .frame(width: ringSize, height: ringSize)
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: restTimer.progress)
                        .stroke(Color.pumpAccent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: restTimer.progress)

                    // Center content
                    VStack(spacing: 6) {
                        Text(restTimer.formattedTime)
                            .font(.spaceMono(64, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("REST · TGT \(formattedTarget)")
                            .font(.spaceMono(9))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(1.5)
                    }
                }
                .padding(.bottom, 20)

                // Adjust buttons
                HStack(spacing: 6) {
                    ForEach([("−15s", -15), ("+15s", 15), ("+30s", 30), ("+1m", 60)], id: \.0) { label, delta in
                        Button {
                            if restTimer.isRunning {
                                restTimer.remainingSeconds = max(0, restTimer.remainingSeconds + delta)
                            } else {
                                // Start timer with the tapped duration
                                let secs = max(15, delta)
                                restTimer.start(seconds: secs)
                            }
                        } label: {
                            Text(label)
                                .font(.spaceMono(11, weight: .bold))
                                .foregroundStyle(Color.inkPrimary)
                                .tracking(0.5)
                                .frame(height: 34)
                                .frame(maxWidth: .infinity)
                                .background(Color.surf2)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.dsHairLine, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.bottom, 12)

                // Start / Skip button — label depends on running state
                Button {
                    if restTimer.isRunning {
                        restTimer.dismiss()
                        onClose()
                    } else {
                        restTimer.start(seconds: 90)
                    }
                } label: {
                    Text(restTimer.isRunning ? "SKIP REST" : "START TIMER")
                        .font(.archivo(17, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.pumpAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.inkPrimary.opacity(0.14), lineWidth: 1)
            )
            .frame(width: 300)
            .padding(.horizontal, 24)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            // Stay below masthead — offset down from center
            .offset(y: 30)
            .onAppear {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    cardScale = 1.0
                    cardOpacity = 1.0
                }
            }
        }
    }

    private var formattedTarget: String {
        let t = restTimer.totalSeconds > 0 ? restTimer.totalSeconds : targetSeconds
        let m = t / 60
        let s = t % 60
        return s == 0 ? "\(m):00" : "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Exercise Substitution (retained from original)

struct ExerciseSubstitutionView: View {
    let currentExerciseId: UUID
    let onSelect: (Exercise) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]
    @State private var searchText = ""

    private var currentExercise: Exercise? { allExercises.first { $0.id == currentExerciseId } }

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return allExercises.filter { $0.id != currentExerciseId } }
        return allExercises.filter { $0.id != currentExerciseId && $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("All Exercises") {
                    ForEach(filteredExercises) { exercise in
                        Button { onSelect(exercise) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                                    .font(.mono(11)).foregroundStyle(.secondary)
                            }
                        }.foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// MARK: - Legacy stubs (keep build-compatibility with other files that reference these)

struct RestTimerExpandedView: View {
    let restTimer: RestTimerService
    var body: some View {
        RestTimerModalView(restTimer: restTimer, onClose: { restTimer.dismiss() })
    }
}

struct RestTimerBanner: View {
    let restTimer: RestTimerService
    var body: some View { EmptyView() }
}

struct WorkoutBottomBar: View {
    @Binding var searchText: String
    let onAddExercise: () -> Void
    var body: some View { EmptyView() }
}

struct WorkoutNotesRow: View {
    @Binding var notes: String
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add a note for this workout...", text: $notes, axis: .vertical)
                    .lineLimit(2...6).focused($isFocused).font(.mono(15))
                Button("Done") { isExpanded = false; isFocused = false }
                    .font(Font.mono(11)).foregroundStyle(Color.pumpAccent)
            }
            .padding()
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onAppear { isFocused = true }
        } else {
            Button { isExpanded = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: notes.isEmpty ? "note.text.badge.plus" : "note.text")
                        .foregroundStyle(Color.inkMuted)
                    Text(notes.isEmpty ? "Add workout note" : notes)
                        .font(Font.mono(12)).foregroundStyle(Color.inkMuted).lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ExerciseNotesRow: View {
    @Binding var notes: String
    var lastSessionNote: String = ""
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    private var placeholder: String {
        lastSessionNote.isEmpty ? "Add exercise note..." : "Last: \(lastSessionNote)"
    }

    var body: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 6) {
                TextField(placeholder, text: $notes, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($isFocused)
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkPrimary)
                Button("DONE") { isExpanded = false; isFocused = false }
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.pumpAccent)
            }
            .padding(.vertical, 2)
            .onAppear { isFocused = true }
        } else {
            Button { isExpanded = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: notes.isEmpty ? "note.text.badge.plus" : "note.text")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(notes.isEmpty ? Color.inkFaint : Color.inkMuted)
                    Text(notes.isEmpty ? placeholder : notes)
                        .font(.archivo(12))
                        .foregroundStyle(notes.isEmpty ? Color.inkFaint : Color.inkMuted)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct InlinePlateView: View {
    let entry: ExerciseEntry
    let equipmentType: EquipmentType

    private var barWeight: Double { equipmentType == .ezBar ? 10.0 : 20.0 }

    private var availablePlates: [Double] {
        if let data = UserDefaults.standard.data(forKey: "customPlates"),
           let plates = try? JSONDecoder().decode([Double].self, from: data) { return plates }
        return [1.25, 2.5, 5, 10, 15, 20, 25]
    }

    private var currentWeight: Double? {
        let weights = entry.sets.compactMap { Double($0.weight) }.filter { $0 > 0 }
        return weights.last
    }

    private var platesPerSide: [(plate: Double, count: Int)] {
        guard let target = currentWeight, target > barWeight else { return [] }
        let perSide = (target - barWeight) / 2.0
        var remaining = perSide
        var counts: [Double: Int] = [:]
        for plate in availablePlates.sorted(by: >) {
            while remaining >= plate - 0.001 { counts[plate, default: 0] += 1; remaining -= plate }
        }
        return counts.sorted { $0.key > $1.key }.map { (plate: $0.key, count: $0.value) }
    }

    var body: some View {
        if let weight = currentWeight, weight > barWeight, !platesPerSide.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "scalemass").font(.mono(9)).foregroundStyle(Color.inkMuted)
                Text("PER SIDE:")
                    .font(Font.mono(9)).foregroundStyle(Color.inkMuted).tracking(0.5)
                ForEach(platesPerSide, id: \.plate) { plate, count in
                    plateChip(plate: plate, count: count)
                }
                Spacer()
            }
        }
    }

    private func plateChip(plate: Double, count: Int) -> some View {
        let col = plateColor(plate)
        return Text("\(String(format: "%g", plate))×\(count)")
            .font(Font.mono(10))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(col)
            .clipShape(Capsule())
    }

    private func plateColor(_ kg: Double) -> Color {
        switch kg {
        case 25:   return Color(hex: "#c0341a")
        case 20:   return Color(hex: "#1a5ca8")
        case 15:   return Color(hex: "#b8a200")
        case 10:   return Color(hex: "#1a7a1a")
        case 5:    return Color(hex: "#2a2a2a")
        case 2.5:  return Color(hex: "#888888")
        default:   return Color(hex: "#bbbbbb")
        }
    }
}

// MARK: - Inline Plate Calculator

struct InlinePlateCalculatorView: View {
    let targetWeight: Double
    @Binding var barWeight: Double

    private let plateSizes: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    private let barTypes: [(name: String, sub: String, kg: Double)] = [
        ("BARBELL", "20KG", 20),
        ("OLY 15",  "15KG", 15),
        ("EZ",      "7.5KG", 7.5),
        ("TRAP",    "25KG", 25),
        ("SAFETY",  "32KG", 32),
    ]

    private var perSideStack: [Double] {
        let perSide = (targetWeight - barWeight) / 2
        guard perSide > 0 else { return [] }
        var remaining = perSide
        var stack: [Double] = []
        for p in plateSizes {
            while remaining >= p - 0.001 {
                stack.append(p)
                remaining = (remaining - p).rounded(toPlaces: 3)
            }
        }
        return stack
    }

    private var remainder: Double {
        let perSide = (targetWeight - barWeight) / 2
        guard perSide > 0 else { return 0 }
        var remaining = perSide
        for p in plateSizes {
            while remaining >= p - 0.001 { remaining = (remaining - p).rounded(toPlaces: 3) }
        }
        return remaining
    }

    private func plateColor(_ p: Double) -> (bg: Color, fg: Color) {
        switch p {
        case 25:   return (Color(hex: "#e51b1b"), .white)
        case 20:   return (Color(hex: "#1f4ea3"), .white)
        case 15:   return (Color(hex: "#c98a17"), .white)
        case 10:   return (Color(hex: "#1f8f5a"), .white)
        case 5:    return (Color(hex: "#1f1c19"), Color(hex: "#f4f0e6"))
        case 2.5:  return (Color(hex: "#a3a39a"), Color(hex: "#1f1c19"))
        default:   return (Color(hex: "#d6d2c4"), Color(hex: "#1f1c19"))
        }
    }

    private func plateHeight(_ p: Double) -> CGFloat {
        32 + min(p, 25) * 0.9
    }

    private func plateWidth(_ p: Double) -> CGFloat {
        p >= 20 ? 9 : p >= 10 ? 7 : p >= 5 ? 6 : 5
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PLATE CALCULATOR")
                            .font(.spaceMono(9))
                            .tracking(1.2)
                            .foregroundStyle(Color.inkMuted)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(targetWeight.clean)
                                .font(.archivo(30, weight: .black))
                                .foregroundStyle(Color.inkPrimary)
                                .monospacedDigit()
                            Text("KG · BAR \(barWeight.clean)")
                                .font(.spaceMono(10))
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }

                // Visual plate bar
                plateBarView

                // Plate chips
                if perSideStack.isEmpty {
                    Text("BAR ONLY")
                        .font(.spaceMono(10))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 6) {
                        Spacer()
                        ForEach(Array(perSideStack.enumerated()), id: \.offset) { _, p in
                            let c = plateColor(p)
                            Text(p.clean)
                                .font(.spaceMono(9, weight: .bold))
                                .foregroundStyle(c.fg)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(c.bg)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        if remainder > 0.01 {
                            Text("+\(String(format: "%.2f", remainder))KG OFF")
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.pumpAccent)
                        }
                        Spacer()
                    }
                }

                // Bar type selector
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                HStack(spacing: 4) {
                    ForEach(barTypes, id: \.name) { bt in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { barWeight = bt.kg }
                        } label: {
                            VStack(spacing: 2) {
                                Text(bt.name)
                                    .font(.spaceMono(8, weight: .bold))
                                    .tracking(0.5)
                                Text(bt.sub)
                                    .font(.spaceMono(7))
                                    .opacity(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(barWeight == bt.kg ? Color.pumpAccent : Color.clear)
                            .foregroundStyle(barWeight == bt.kg ? Color.white : Color.inkMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(barWeight == bt.kg ? Color.clear : Color.dsHairLine, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.95))
                    }
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
    }

    private var plateBarView: some View {
        HStack(spacing: 0) {
            Spacer()
            // Left plates (reversed)
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(perSideStack.reversed().enumerated()), id: \.offset) { _, p in
                    let c = plateColor(p)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(c.bg)
                        .frame(width: plateWidth(p), height: plateHeight(p))
                }
            }
            // Bar sleeve
            Rectangle()
                .fill(Color(hex: "#8a857c"))
                .frame(width: 60, height: 4)
            // Right plates
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(perSideStack.enumerated()), id: \.offset) { _, p in
                    let c = plateColor(p)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(c.bg)
                        .frame(width: plateWidth(p), height: plateHeight(p))
                }
            }
            Spacer()
        }
        .frame(height: 64)
    }
}

private extension Double {
    var clean: String { truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self) }
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - SetRowView (legacy alias kept for build compatibility)

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
            onSetTypeTap: {},
            onLog: onLog,
            onDelete: {}
        )
    }
}
