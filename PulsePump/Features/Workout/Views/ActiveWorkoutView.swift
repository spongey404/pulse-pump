import SwiftUI
import SwiftData

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
                        viewModel.replaceExercise(at: idx, with: first)
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
                    .foregroundStyle(Color.accentInk)
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
