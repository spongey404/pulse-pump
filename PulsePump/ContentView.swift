import SwiftUI
import SwiftData
import FirebaseAuth

struct ContentView: View {
    @State private var workoutViewModel = WorkoutViewModel()
    @State private var tutorialViewModel = TutorialViewModel()
    @State private var selectedTab = 2
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    private var user: User? { users.first }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ProgramsTabView(onStartFromTemplate: startFromTemplate)
                }
                .tag(0)

                SocialTabView()
                .tag(1)

                HomeTabView(workoutViewModel: workoutViewModel)
                .tag(2)

                BodyMapTabView()
                .tag(3)

                NavigationStack {
                    MoreTabView(tutorialViewModel: tutorialViewModel)
                }
                .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selectedTab: $selectedTab)
            }
            .fullScreenCover(isPresented: $workoutViewModel.isActive) {
                ActiveWorkoutView(viewModel: workoutViewModel)
            }
            .fullScreenCover(isPresented: $workoutViewModel.showCompletionSummary) {
                if let data = workoutViewModel.completionData {
                    WorkoutCompletionView(data: data, userName: user?.name ?? "") {
                        workoutViewModel.reset()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startWorkoutFromWidget)) { _ in
                startBlankWorkout()
            }
            if tutorialViewModel.isActive {
                CoachMarkOverlay(viewModel: tutorialViewModel, selectedTab: $selectedTab)
            }
        }
        .onAppear {
            ExerciseSeedService.seedIfNeeded(modelContext: modelContext)
            TemplateSeedService.seedIfNeeded(modelContext: modelContext)
            if UserDefaults.standard.bool(forKey: "wantsTutorial") {
                tutorialViewModel.start()
            }
        }
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        guard let user else { return }
        workoutViewModel.startWorkout(modelContext: modelContext, user: user, template: template)
    }

    private func startBlankWorkout() {
        guard let user else { return }
        workoutViewModel.startWorkout(modelContext: modelContext, user: user)
    }
}

// MARK: - Home Tab (Dense)

struct HomeTabView: View {
    @Bindable var workoutViewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @State private var showSearch = false
    @State private var barsAppeared = false
    @State private var showDayPicker = false
    @State private var manualOverrideTemplate: WorkoutTemplate? = nil
    @State private var showProfileMenu = false
    @State private var showDiscardConfirmation = false
    @State private var pendingDiscardDraft: Workout? = nil

    private var user: User? { users.first }

    // MARK: Computed KPIs
    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: workouts.map(\.date))
    }

    private var weekWorkouts: [Workout] {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return workouts.filter { $0.date >= start }
    }

    private var weekSets: Int {
        weekWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count
    }

    private var weekPRs: Int {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        var weekMaxByExercise: [UUID: Double] = [:]
        var prevMaxByExercise: [UUID: Double] = [:]
        for workout in workouts {
            let isThisWeek = workout.date >= weekStart
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                let maxWeight = log.sets.map(\.weight).max() ?? 0
                if isThisWeek {
                    weekMaxByExercise[exercise.id] = max(weekMaxByExercise[exercise.id] ?? 0, maxWeight)
                } else {
                    prevMaxByExercise[exercise.id] = max(prevMaxByExercise[exercise.id] ?? 0, maxWeight)
                }
            }
        }
        return weekMaxByExercise.filter { id, weekMax in
            weekMax > (prevMaxByExercise[id] ?? 0) && weekMax > 0
        }.count
    }

    private var weekImproved: Int {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let prevWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? Date()
        var thisWeekBest: [UUID: Double] = [:]
        var prevWeekBest: [UUID: Double] = [:]
        for workout in workouts {
            let isThisWeek = workout.date >= weekStart
            let isPrevWeek = workout.date >= prevWeekStart && workout.date < weekStart
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                let bestVol = log.sets.map { $0.weight * Double($0.reps) }.max() ?? 0
                if isThisWeek { thisWeekBest[exercise.id] = max(thisWeekBest[exercise.id] ?? 0, bestVol) }
                else if isPrevWeek { prevWeekBest[exercise.id] = max(prevWeekBest[exercise.id] ?? 0, bestVol) }
            }
        }
        return thisWeekBest.filter { id, vol in vol > (prevWeekBest[id] ?? 0) && vol > 0 }.count
    }

    /// Sets per day for the current week (Mon=0 … Sun=6)
    private var weekDayBars: [Int] {
        var bars = [Int](repeating: 0, count: 7)
        let cal = Calendar.current
        for workout in weekWorkouts {
            let weekday = cal.component(.weekday, from: workout.date) // 1=Sun…7=Sat
            let idx = (weekday + 5) % 7  // Mon=0…Sun=6
            bars[idx] += workout.exerciseLogs.flatMap(\.sets).count
        }
        return bars
    }

    private var todayDayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var basePredictedName: String? {
        guard let user else { return nil }
        return workoutViewModel.predictNextWorkout(user: user, modelContext: modelContext)
    }

    private var predictedTemplateName: String? {
        manualOverrideTemplate?.name ?? basePredictedName
    }

    private var predictedTemplate: WorkoutTemplate? {
        if let override = manualOverrideTemplate { return override }
        guard let name = basePredictedName else { return nil }
        return workouts.compactMap(\.template).first { $0.name.lowercased() == name.lowercased() }
    }

    /// Detects split type from recent workout template names (PPL, U/L, etc.)
    private var splitLabel: String {
        let recentNames = workouts.prefix(9).compactMap { $0.template?.name.lowercased() }
        let hasPush = recentNames.contains { $0.contains("push") }
        let hasPull = recentNames.contains { $0.contains("pull") }
        let hasLegs = recentNames.contains { $0.contains("leg") }
        if hasPush && hasPull && hasLegs { return "PPL" }
        let hasUpper = recentNames.contains { $0.contains("upper") }
        let hasLower = recentNames.contains { $0.contains("lower") }
        if hasUpper && hasLower { return "U/L" }
        let hasFull = recentNames.contains { $0.contains("full") }
        if hasFull { return "FULL BODY" }
        return user?.selectedSplit?.type.displayName ?? "PROGRAM"
    }

    private var lastDoneLabel: String {
        guard let name = predictedTemplateName,
              let last = workouts.first(where: { $0.template?.name.lowercased() == name.lowercased() }) else { return "" }
        let days = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
        if days == 0 { return "TODAY" }
        if days == 1 { return "YESTERDAY" }
        return "\(days) DAYS AGO"
    }

    private var estDuration: String {
        guard let name = predictedTemplateName,
              let last = workouts.first(where: { $0.template?.name.lowercased() == name.lowercased() }),
              last.duration > 60 else { return "~55 MIN" }
        let mins = Int(last.duration / 60)
        return "~\(mins) MIN"
    }

    private var recentWorkouts: [Workout] { Array(workouts.prefix(3)) }

    // MARK: - Week number helper (relative to user's join date, so week 1 = first week)
    private var currentWeekNumber: Int {
        let origin = user?.createdAt ?? workouts.last?.date ?? Date()
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: origin, to: Date()).weekOfYear ?? 0
        return max(1, weeks + 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Only show ticker when there is real volume data
            let tickerItems = buildTickerItems()
            if !tickerItems.isEmpty {
                TickerStripView(items: tickerItems)
            }

            ScrollView {
                VStack(spacing: 0) {
                    // 1. Masthead row — full-width with bottom hairline
                    mastheadRow

                    // 2. Prediction block — surf background, bottom hairline
                    if let name = predictedTemplateName {
                        predictionBlock(name: name)
                    }

                    // 3. KPI 4-up grid — bottom hairline, no outer card
                    kpiGrid

                    // 4. Week volume bars — bottom hairline
                    weekBarsSection

                    // 5. Friends trained today banner
                    FriendActivityBanner()

                    // 6. Recent workouts table
                    if !recentWorkouts.isEmpty {
                        recentWorkoutsTable
                    }

                    Color.clear.frame(height: 80)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            StartWorkoutDock(
                viewModel: workoutViewModel,
                overrideName: predictedTemplateName,
                onRequestDiscard: { draft in
                    pendingDiscardDraft = draft
                    showDiscardConfirmation = true
                }
            )
        }
        .sheet(isPresented: $showSearch) {
            GlobalSearchView()
        }
        .sheet(isPresented: $showDayPicker) {
            WorkoutDayPickerSheet(templates: templates) { selected in
                manualOverrideTemplate = selected
                showDayPicker = false
            }
        }
        .workoutModal(
            isPresented: $showDiscardConfirmation,
            title: "Discard current workout?",
            message: "Your progress on \(pendingDiscardDraft?.template?.name ?? "this workout") will be lost. Drafts auto-save for 7 days.",
            primaryLabel: "DISCARD + START NEW",
            primaryDestructive: true,
            onPrimary: {
                if let draft = pendingDiscardDraft, let user {
                    workoutViewModel.discardDraftAndStart(draft: draft, modelContext: modelContext, user: user)
                }
                pendingDiscardDraft = nil
            }
        )
        .overlay {
            if showProfileMenu {
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            showProfileMenu = false
                        }
                    }
                profileModal
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showProfileMenu)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.15)) {
                barsAppeared = true
            }
        }
    }

    private var profileModal: some View {
        VStack(alignment: .leading, spacing: 10) {
            // User info header
            VStack(alignment: .leading, spacing: 3) {
                Text((user?.name ?? "ATHLETE").uppercased())
                    .font(.archivo(13, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                if let username = user?.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.archivo(12))
                        .foregroundStyle(Color.inkMuted)
                } else {
                    Text("Tap sign out to switch accounts")
                        .font(.archivo(12))
                        .foregroundStyle(Color.inkMuted)
                }
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        showProfileMenu = false
                    }
                } label: {
                    Text("CANCEL")
                        .font(.archivo(11, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.inkPrimary.opacity(0.13), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    try? FirebaseAuthService().signOut()
                    showProfileMenu = false
                } label: {
                    Text("SIGN OUT")
                        .font(.archivo(11, weight: .black))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.signalDown)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.signalDown.opacity(0.33), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: UIScreen.main.bounds.width - 40)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.inkPrimary.opacity(0.13), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.10), radius: 20, y: 6)
    }

    // MARK: - 1. Masthead Row

    private var mastheadRow: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                // Left: accent rect + "PULSE/PUMP" monospaced
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.pumpAccent)
                        .frame(width: 14, height: 14)
                    Text("PULSE/PUMP")
                        .font(.spaceMono(10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.inkPrimary)
                }
                #if DEBUG
                .onLongPressGesture { workoutViewModel.showPreviewCompletion() }
                #endif
                Spacer()
                // Right: search icon + avatar
                HStack(spacing: 10) {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    Button { showProfileMenu = true } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.surf2)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text(user?.name.prefix(1).uppercased() ?? "?")
                                    .font(.archivo(13, weight: .black))
                                    .foregroundStyle(Color.inkPrimary)
                            )
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.92))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    // MARK: - 2. Prediction Block

    private func predictionBlock(name: String) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PREDICTED TODAY · \(splitLabel)")
                            .font(.spaceMono(9))
                            .tracking(1.5)
                            .foregroundStyle(Color.pumpAccent)
                        Text(name.uppercased())
                            .font(.archivo(28, weight: .black))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            if !lastDoneLabel.isEmpty {
                                Text(lastDoneLabel)
                                    .font(.spaceMono(9)).tracking(0.5).foregroundStyle(Color.inkMuted)
                            }
                            Text(estDuration)
                                .font(.spaceMono(9)).tracking(0.5).foregroundStyle(Color.inkMuted)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(i < 4 ? Color.pumpAccent : Color.inkFaint)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        Text("HIGH\nCONF")
                            .font(Font.mono(8))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.inkMuted)
                            .tracking(0.5)
                    }
                    .padding(.top, 20)
                }

                // Exercise chips — wrapping flow layout
                if let template = predictedTemplate {
                    ChipFlowLayout(spacing: 6) {
                        ForEach(template.templateExercises.sorted(by: { $0.order < $1.order })) { ex in
                            Text(ex.exerciseName.uppercased())
                                .font(.spaceMono(8))
                                .foregroundStyle(Color.inkMuted)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.surf2)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        Button {
                            showDayPicker = true
                        } label: {
                            Text("NOT TODAY? ›")
                                .font(.spaceMono(9))
                                .tracking(0.5)
                                .foregroundStyle(Color.pumpAccent.opacity(0.8))
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.surf)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    // MARK: - 3. KPI 4-up Grid

    private var kpiGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                kpiCell(
                    label: "STREAK",
                    value: "\(currentStreak)",
                    sub: "DAYS",
                    valueColor: Color.pumpAccent
                )
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                kpiCell(
                    label: "IMPROVED",
                    value: "\(weekImproved)",
                    sub: "THIS WK",
                    valueColor: Color.inkPrimary
                )
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                kpiCell(
                    label: "PRs",
                    value: "\(weekPRs)",
                    sub: "THIS WK",
                    valueColor: Color.inkPrimary
                )
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                kpiCell(
                    label: "SETS",
                    value: "\(weekSets)",
                    sub: "THIS WK",
                    valueColor: Color.inkPrimary
                )
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    private func kpiCell(label: String, value: String, sub: String, valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.spaceMono(8))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
            Text(value)
                .font(.spaceMono(24, weight: .bold))
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
            Text(sub)
                .font(.spaceMono(7))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
    }

    // MARK: - 4. Week Volume Bars

    private var weekBarsSection: some View {
        let bars = weekDayBars
        let maxVal = max(bars.max() ?? 1, 1)
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let today = todayDayIndex
        let totalSets = bars.reduce(0, +)

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack {
                    Text("WEEKLY VOLUME · SETS")
                        .font(.spaceMono(9))
                        .tracking(1.5)
                        .foregroundStyle(Color.pumpAccent)
                    Spacer()
                    Text("WK \(currentWeekNumber) · \(totalSets) TOTAL")
                        .font(.spaceMono(9))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                }

                // 7 bars
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        let v = bars[i]
                        let isPast = i < today
                        let isToday = i == today
                        let pct = v > 0 ? Double(v) / Double(maxVal) : 0
                        let barH = max(pct * 40, v > 0 ? 4 : 3)
                        let animH = barsAppeared ? max(barH, 3) : 3

                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    isToday ? Color.pumpAccent :
                                    (isPast && v > 0 ? Color.pumpAccent.opacity(0.70) :
                                     Color.inkFaint.opacity(0.15))
                                )
                                .frame(height: animH)
                                .frame(maxWidth: .infinity)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(i) * 0.04), value: barsAppeared)
                            Text(labels[i])
                                .font(Font.mono(7))
                                .foregroundStyle(isToday ? Color.pumpAccent : Color.inkMuted)
                                .fontWeight(isToday ? .bold : .regular)
                        }
                    }
                }
                .frame(height: 50)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    // MARK: - 5. Recent Workouts Table

    private var recentWorkoutsTable: some View {
        VStack(spacing: 0) {
            // Header row — surf2 background
            HStack(spacing: 0) {
                Text("RECENT")
                    .font(.spaceMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Color.pumpAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("SETS")
                    .font(.spaceMono(8))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 56, alignment: .center)
                Text("IMPR")
                    .font(.spaceMono(8))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 56, alignment: .center)
                Text("VOL▲")
                    .font(.spaceMono(8))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(Color.surf2)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            // Workout rows
            ForEach(Array(recentWorkouts.enumerated()), id: \.element.id) { idx, workout in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Name + date column
                        VStack(alignment: .leading, spacing: 1) {
                            Text((workout.template?.name ?? "Workout").uppercased())
                                .font(.archivo(15, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                            Text(relativeDate(workout.date))
                                .font(.spaceMono(8))
                                .foregroundStyle(Color.inkMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        let sets = workout.exerciseLogs.flatMap(\.sets).count
                        let improvedCount = improvedExercises(in: workout)
                        let totalExercises = max(workout.exerciseLogs.count, 1)

                        Text("\(sets)")
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 56, alignment: .center)

                        Text("\(improvedCount)/\(totalExercises)")
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(Color.pumpAccent)
                            .frame(width: 56, alignment: .center)

                        let volDelta = volumeDelta(for: workout)
                        Text(volDelta)
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(volDelta.hasPrefix("▲") ? Color.signalUp : (volDelta == "—" ? Color.inkMuted : Color.signalDown))
                            .frame(width: 56, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if idx < recentWorkouts.count - 1 {
                        Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    }
                }
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date()).uppercased()
    }

    private func volumeDelta(for workout: Workout) -> String {
        let curVol = workout.exerciseLogs.flatMap(\.sets).reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        guard curVol > 0, let templateName = workout.template?.name else { return "—" }
        let prev = workouts.first { $0.id != workout.id && $0.template?.name.lowercased() == templateName.lowercased() && $0.date < workout.date }
        guard let prevWorkout = prev else { return "—" }
        let prevVol = prevWorkout.exerciseLogs.flatMap(\.sets).reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        guard prevVol > 0 else { return "—" }
        let pct = Int(((curVol - prevVol) / prevVol) * 100)
        if pct > 0 { return "▲+\(pct)%" }
        if pct < 0 { return "▼\(abs(pct))%" }
        return "▲0%"
    }

    private func improvedExercises(in workout: Workout) -> Int {
        workout.exerciseLogs.filter { log in
            guard let exercise = log.exercise else { return false }
            let thisVol = log.sets.map { $0.weight * Double($0.reps) }.max() ?? 0
            let prevBest = workouts
                .filter { $0.date < workout.date }
                .flatMap(\.exerciseLogs)
                .filter { $0.exercise?.id == exercise.id }
                .flatMap(\.sets)
                .map { $0.weight * Double($0.reps) }
                .max() ?? 0
            return thisVol > prevBest && thisVol > 0
        }.count
    }

    // MARK: - Ticker Data

    private func buildTickerItems() -> [TickerItem] {
        var muscleVolume: [MuscleGroup: Int] = [:]
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let prevWeekStart = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        var prevVolume: [MuscleGroup: Int] = [:]
        for workout in workouts {
            let isThisWeek = workout.date >= weekAgo
            let isPrevWeek = workout.date >= prevWeekStart && workout.date < weekAgo
            for log in workout.exerciseLogs {
                guard let exercise = log.exercise else { continue }
                for muscle in exercise.primaryMuscleGroups {
                    if isThisWeek { muscleVolume[muscle, default: 0] += log.sets.count }
                    if isPrevWeek { prevVolume[muscle, default: 0] += log.sets.count }
                }
            }
        }

        let all = MuscleGroup.allCases
        return all.compactMap { muscle -> TickerItem? in
            let cur = muscleVolume[muscle] ?? 0
            let prev = prevVolume[muscle] ?? 0
            guard cur > 0 || prev > 0 else { return nil }
            let label = String(muscle.displayName.uppercased().prefix(6))
            if prev == 0 {
                return TickerItem(label: label, value: "+\(cur)", direction: .up)
            } else {
                let pct = Int(((Double(cur) - Double(prev)) / Double(prev)) * 100)
                let dir: TickerItem.Direction = pct >= 0 ? .up : .down
                let sign = pct >= 0 ? "▲" : "▼"
                return TickerItem(label: label, value: "\(sign)\(abs(pct))%", direction: dir)
            }
        }
    }
}

// MARK: - Friend Activity Banner

private struct FriendActivityBanner: View {
    @State private var trainedToday: [WorkoutFeedItem] = []
    @State private var loaded = false

    private static let demoItems: [WorkoutFeedItem] = [
        WorkoutFeedItem(id: "d1", userId: "u1", username: "Marcus", templateName: "Push Day",  exerciseCount: 5, durationSeconds: 3600, caloriesBurned: 418, musclesWorked: ["Chest"], date: Date()),
        WorkoutFeedItem(id: "d2", userId: "u2", username: "Priya",  templateName: "Leg Day",   exerciseCount: 5, durationSeconds: 3300, caloriesBurned: 390, musclesWorked: ["Quads"], date: Date()),
        WorkoutFeedItem(id: "d3", userId: "u3", username: "Jake",   templateName: "Pull Day",  exerciseCount: 5, durationSeconds: 3480, caloriesBurned: 452, musclesWorked: ["Back"],  date: Date()),
    ]

    var body: some View {
        Group {
            if !trainedToday.isEmpty {
                banner
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            guard let uid = Auth.auth().currentUser?.uid else {
                trainedToday = Self.demoItems
                return
            }
            let uids = (try? await FirestoreService().fetchFriendUids(for: uid)) ?? []
            if uids.isEmpty {
                trainedToday = Self.demoItems
                return
            }
            let posts = (try? await FirestoreService().fetchFeed(friendUids: uids)) ?? []
            let real = posts.filter { Calendar.current.isDateInToday($0.date) }
            trainedToday = real.isEmpty ? Self.demoItems : real
        }
    }

    private var banner: some View {
        let names = uniqueNames(from: trainedToday)
        let first = names.first ?? ""
        let others = max(0, trainedToday.count - 1)
        let label = others > 0
            ? "\(first) +\(others) other\(others == 1 ? "" : "s") trained today"
            : "\(first) trained today"

        return Button(action: {}) {
            HStack(spacing: 10) {
                // Overlapping initials
                initialsStack

                Text(label)
                    .font(.archivo(14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.inkFaint, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var initialsStack: some View {
        let names = uniqueNames(from: trainedToday)
        let shown = Array(names.prefix(3))
        let size: CGFloat = 26
        let overlap: CGFloat = 8

        return ZStack(alignment: .leading) {
            ForEach(shown.indices, id: \.self) { i in
                Circle()
                    .fill(Color.surf2)
                    .overlay(Circle().strokeBorder(Color.canvasBg, lineWidth: 1.5))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(shown[i].prefix(1)).uppercased())
                            .font(.spaceMono(9, weight: .bold))
                            .foregroundStyle(Color.inkMuted)
                    )
                    .offset(x: CGFloat(i) * (size - overlap))
            }
        }
        .frame(width: CGFloat(shown.count) * (size - overlap) + overlap, height: size)
    }

    private func uniqueNames(from items: [WorkoutFeedItem]) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item -> String? in
            guard seen.insert(item.userId).inserted else { return nil }
            return item.username
        }
    }
}

// MARK: - Start Workout Bottom Dock

struct StartWorkoutDock: View {
    @Bindable var viewModel: WorkoutViewModel
    var overrideName: String? = nil
    var onRequestDiscard: ((Workout) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { $0.isDraft }, sort: \Workout.updatedAt, order: .reverse)
    private var drafts: [Workout]

    private var user: User? { users.first }
    private var draft: Workout? { drafts.first }

    private var draftSetsDone: Int {
        draft?.exerciseLogs.flatMap(\.sets).count ?? 0
    }

    private var draftProgress: Double {
        guard let draft else { return 0 }
        let target = draft.template?.templateExercises.reduce(0) { $0 + $1.targetSets } ?? 0
        let done = draft.exerciseLogs.flatMap(\.sets).count
        guard target > 0 else { return 0 }
        return min(1.0, Double(done) / Double(target))
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.inkPrimary.opacity(0.08)).frame(height: 1)

            if let user {
                if let draft {
                    draftDock(draft: draft, user: user)
                } else {
                    startDock(user: user)
                }
            }
        }
        .background(Color.canvasBg)
    }

    // MARK: Draft state

    private func draftDock(draft: Workout, user: User) -> some View {
        VStack(spacing: 0) {
            // "START NEW WORKOUT" link
            Button("START NEW WORKOUT") {
                onRequestDiscard?(draft)
            }
            .font(Font.mono(10, weight: .medium))
            .tracking(1)
            .foregroundStyle(Color.inkMuted)
            .padding(.top, 10)

            // Continue bar
            Button {
                viewModel.resumeDraft(workout: draft, modelContext: modelContext)
            } label: {
                ZStack(alignment: .leading) {
                    // Base
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surf)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.pumpAccent.opacity(0.33), lineWidth: 1)
                        )

                    // Progress fill
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pumpAccent.opacity(0.18))
                            .frame(width: geo.size.width * draftProgress)
                    }

                    // Content
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("CONTINUE")
                                .font(.spaceMono(8))
                                .tracking(1.5)
                                .foregroundStyle(Color.inkMuted)
                            Text((draft.template?.name ?? "WORKOUT").uppercased())
                                .font(.archivo(20, weight: .black))
                                .foregroundStyle(Color.pumpAccent)
                            Text("\(draftSetsDone) SETS DONE")
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Text("TAP TO RESUME ›")
                            .font(.spaceMono(9))
                            .tracking(0.5)
                            .foregroundStyle(Color.pumpAccent)
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
    }

    // MARK: Start state

    private func startDock(user: User) -> some View {
        let predictionName = overrideName ?? viewModel.predictNextWorkout(user: user, modelContext: modelContext)
        let allTemplates: [WorkoutTemplate] = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let predictedTemplate = predictionName.flatMap { name in
            allTemplates.first { $0.name.lowercased() == name.lowercased() }
        }
        let splitLbl = detectSplitLabel(modelContext: modelContext)
        let estMins = predictedTemplate.flatMap { t -> Int? in
            let workoutDescriptor = FetchDescriptor<Workout>(
                predicate: #Predicate { !$0.isDraft },
                sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
            )
            let recentWorkouts = (try? modelContext.fetch(workoutDescriptor)) ?? []
            guard let last = recentWorkouts.first(where: { $0.template?.name == t.name }),
                  last.duration > 60 else { return nil }
            return Int(last.duration / 60)
        } ?? 55

        return Button {
            viewModel.startWorkout(modelContext: modelContext, user: user, template: predictedTemplate)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pumpAccent)
                    .shadow(color: Color.pumpAccent.opacity(0.35), radius: 8, y: 3)

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TODAY · \(splitLbl)")
                            .font(.spaceMono(8))
                            .tracking(1.5)
                            .foregroundStyle(Color.white.opacity(0.60))
                        Text((predictionName ?? "WORKOUT").uppercased())
                            .font(.archivo(20, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("~\(estMins) MIN")
                            .font(.spaceMono(8))
                            .foregroundStyle(Color.white.opacity(0.60))
                        Text("START WORKOUT ›")
                            .font(.archivo(16, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 54)
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    private func detectSplitLabel(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isDraft },
            sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
        )
        let recent = (try? modelContext.fetch(descriptor))?.prefix(9) ?? []
        let names = recent.compactMap { $0.template?.name.lowercased() }
        let hasPush = names.contains { $0.contains("push") }
        let hasPull = names.contains { $0.contains("pull") }
        let hasLegs = names.contains { $0.contains("leg") }
        if hasPush && hasPull && hasLegs { return "PPL" }
        let hasUpper = names.contains { $0.contains("upper") }
        let hasLower = names.contains { $0.contains("lower") }
        if hasUpper && hasLower { return "U/L" }
        if names.contains(where: { $0.contains("full") }) { return "FULL BODY" }
        return "PROGRAM"
    }
}

// MARK: - Programs Tab

// Groups templates with the same splitDays into one program row
struct ProgramGroup: Identifiable {
    let id: String
    let name: String
    let templates: [WorkoutTemplate]
    let splitDays: [String]

    var totalExercises: Int { templates.flatMap(\.templateExercises).count }
    var daysPerWeek: Int { splitDays.isEmpty ? max(1, templates.count) : splitDays.count }
    var lastUsedDate: Date? { templates.flatMap(\.workouts).map(\.date).max() }

    var lastUsedText: String {
        guard let date = lastUsedDate else { return "NEVER" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}

// Wraps navigation context for TemplateDetailView (single day or full multi-day group)
struct TemplateNavItem: Identifiable, Hashable {
    let id: UUID
    let templates: [WorkoutTemplate]
    let groupName: String?

    init(_ template: WorkoutTemplate, groupName: String? = nil, siblings: [WorkoutTemplate] = []) {
        self.id = template.id
        self.templates = siblings.isEmpty ? [template] : siblings
        self.groupName = groupName
    }

    init(group: ProgramGroup) {
        self.id = group.templates.first?.id ?? UUID()
        self.templates = group.templates
        self.groupName = group.name
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ProgramsTabView: View {
    let onStartFromTemplate: (WorkoutTemplate) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var recentWorkouts: [Workout]
    @State private var showPresetPicker = false
    @State private var showCreateBlank = false
    @State private var selectedNavItem: TemplateNavItem?
    @State private var groupToDelete: ProgramGroup? = nil

    // Group templates by their splitDays; templates with no splitDays stay individual
    private var programGroups: [ProgramGroup] {
        var buckets: [(key: String, templates: [WorkoutTemplate])] = []
        var seen: [String: Int] = [:]
        for t in templates {
            let key = t.splitDays.isEmpty ? "__solo_\(t.id)" : t.splitDays.joined()
            if let idx = seen[key] {
                buckets[idx].templates.append(t)
            } else {
                seen[key] = buckets.count
                buckets.append((key: key, templates: [t]))
            }
        }
        return buckets.map { bucket in
            ProgramGroup(
                id: bucket.key,
                name: derivedName(for: bucket.templates),
                templates: bucket.templates,
                splitDays: bucket.templates.first?.splitDays ?? []
            )
        }
    }

    private func derivedName(for templates: [WorkoutTemplate]) -> String {
        if templates.count == 1 { return templates[0].name }
        let names = templates.map { $0.name.lowercased() }
        let hasPush  = names.contains { $0.contains("push") }
        let hasPull  = names.contains { $0.contains("pull") }
        let hasLegs  = names.contains { $0.contains("leg") }
        let hasUpper = names.contains { $0.contains("upper") }
        let hasLower = names.contains { $0.contains("lower") }
        let hasFull  = names.contains { $0.contains("full") }
        if hasPush && hasPull && hasLegs { return "Push Pull Legs" }
        if hasPush && hasLegs            { return "Push Legs" }
        if hasPull && hasLegs            { return "Pull Legs" }
        if hasPush && hasPull            { return "Push Pull" }
        if hasUpper && hasLower          { return "Upper Lower" }
        if hasFull                       { return "Full Body" }
        return templates.map(\.name).joined(separator: " / ")
    }

    private func setCount(for muscle: MuscleGroup) -> Int {
        recentWorkouts.flatMap(\.exerciseLogs)
            .filter { $0.exercise?.primaryMuscleGroups.contains(muscle) == true }
            .flatMap(\.sets).count
    }

    private var programsTickerItems: [TickerItem] {
        guard recentWorkouts.count >= 3 else { return [] }
        let pairs: [(String, Int)] = [
            ("CHEST", setCount(for: .chest)),
            ("BACK",  setCount(for: .back)),
            ("QUADS", setCount(for: .quads)),
            ("HAMS",  setCount(for: .hamstrings)),
            ("SHLDR", setCount(for: .shoulders)),
            ("BICEP", setCount(for: .biceps)),
            ("TRI",   setCount(for: .triceps)),
        ]
        return pairs.filter { $0.1 > 0 }.map { TickerItem(label: $0.0, value: "\($0.1) SETS", direction: nil) }
    }

    var body: some View {
        VStack(spacing: 0) {
            programsHeader

            ScrollView {
                LazyVStack(spacing: 0) {
                    if programGroups.isEmpty {
                        emptyState
                    } else {
                        ForEach(programGroups) { group in
                            SwipeToDeleteRow(onDeleteTapped: { groupToDelete = group }) {
                                ProgramGroupRowView(group: group)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedNavItem = TemplateNavItem(group: group) }
                            }
                        }
                    }

                    newProgramButton

                    if !recentWorkouts.isEmpty {
                        quickStartSection
                    }

                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedNavItem) { navItem in
            TemplateDetailView(
                template: navItem.templates.first!,
                groupName: navItem.groupName,
                siblings: navItem.templates,
                onStartWorkout: onStartFromTemplate
            )
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetTemplatePicker(onSelectPresets: { presets in
                var copies: [WorkoutTemplate] = []
                presets.forEach { preset in
                    let copy = WorkoutTemplate(name: preset.name, templateExercises: preset.templateExercises, splitDays: preset.splitDays)
                    modelContext.insert(copy)
                    copies.append(copy)
                }
                showPresetPicker = false
                if let first = copies.first {
                    selectedNavItem = TemplateNavItem(first, groupName: nil, siblings: copies)
                }
            }, onBlank: {
                showPresetPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showCreateBlank = true
                }
            })
        }
        .navigationDestination(isPresented: $showCreateBlank) {
            CreateTemplateView()
        }
        .destructiveModal(
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            ),
            kicker: "DELETE PROGRAM",
            title: "Delete \(groupToDelete?.name ?? "program")?",
            body: "The program template will be removed. Workouts you've already logged using it will be kept in your history.",
            consequences: deleteProgramConsequences,
            onConfirm: {
                groupToDelete?.templates.forEach { modelContext.delete($0) }
            }
        )
    }

    private var deleteProgramConsequences: [DestructiveConsequence] {
        guard let group = groupToDelete else { return [] }
        let days = group.templates.count
        let exercises = group.totalExercises
        let sessions = group.templates.flatMap(\.workouts).count
        return [
            DestructiveConsequence(value: "\(days)", label: "workout days"),
            DestructiveConsequence(value: "\(exercises)", label: "exercises"),
            DestructiveConsequence(value: "\(sessions)", label: "past sessions kept"),
        ]
    }

    // MARK: Custom Programs Header

    private var programsHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("PROGRAMS")
                    .font(.archivo(26, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)

                Spacer()

                Button {
                    showPresetPicker = true
                } label: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.pumpAccent)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.mono(16, weight: .medium))
                                .foregroundStyle(.white)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 10)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.canvasBg)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Text("NO PROGRAMS")
                .font(.archivo(32, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.inkFaint)
            Text("Tap + to add a preset or build your own.")
                .font(.archivo(13))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 20)
        }
        .padding()
    }

    // MARK: New Program Button (dashed)

    private var newProgramButton: some View {
        Button {
            showCreateBlank = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(Color.inkFaint)
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("NEW PROGRAM")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                }
                .foregroundStyle(Color.inkMuted)
            }
            .frame(height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: Quick Start Section

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUICK START")
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)

            ForEach(Array(recentWorkouts.prefix(3).enumerated()), id: \.element.id) { idx, workout in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text((workout.template?.name ?? "Workout").uppercased())
                                .font(.archivo(15, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(relativeDate(workout.date))
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Button {
                            if let template = workout.template {
                                onStartFromTemplate(template)
                            }
                        } label: {
                            Text("START")
                                .font(.archivo(13, weight: .black))
                                .tracking(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 32)
                                .background(Color.pumpAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .disabled(workout.template == nil)
                        .opacity(workout.template == nil ? 0.4 : 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if idx < min(recentWorkouts.count, 3) - 1 {
                        Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    }
                }
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}

// MARK: - Program Group Row

struct ProgramGroupRowView: View {
    let group: ProgramGroup

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name.uppercased())
                        .font(.archivo(18, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Text("\(group.daysPerWeek) DAYS/WK · \(group.totalExercises) EXERCISES · \(group.lastUsedText)")
                        .font(.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !group.splitDays.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(group.splitDays.enumerated()), id: \.offset) { _, label in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.pumpAccent.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.pumpAccent.opacity(0.33), lineWidth: 1)
                                )
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Text(label)
                                        .font(.spaceMono(7, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(Color.pumpAccent)
                                )
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.mono(12))
                    .foregroundStyle(Color.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surf)
            .contentShape(Rectangle())

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }
}

// Keep legacy aliases so existing call sites compile
typealias ProgramRowView = ProgramGroupRowView
typealias TemplateCard = ProgramGroupRowView

// MARK: - Program Day Picker Sheet

struct ProgramDayPickerSheet: View {
    let group: ProgramGroup
    let onSelectTemplate: (WorkoutTemplate) -> Void
    let onStartTemplate: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("‹")
                        .font(.archivo(26, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(PressScaleButtonStyle())
                Text(group.name.uppercased())
                    .font(.archivo(20, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(group.templates.enumerated()), id: \.element.id) { idx, template in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name.uppercased())
                                        .font(.archivo(16, weight: .bold))
                                        .foregroundStyle(Color.inkPrimary)
                                    Text("\(template.templateExercises.count) EXERCISES · \(template.templateExercises.reduce(0) { $0 + $1.targetSets }) SETS")
                                        .font(.spaceMono(9))
                                        .foregroundStyle(Color.inkMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    onStartTemplate(template)
                                } label: {
                                    Text("START")
                                        .font(.spaceMono(9, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.pumpAccent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.pumpAccent.opacity(0.5))
                                        )
                                }
                                .buttonStyle(PressScaleButtonStyle())

                                Button {
                                    onSelectTemplate(template)
                                } label: {
                                    Text("EDIT")
                                        .font(.spaceMono(9, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.inkMuted)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.dsHairLine.opacity(1.5))
                                        )
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preset Template Picker

struct PresetTemplatePicker: View {
    let onSelectPresets: ([WorkoutTemplate]) -> Void
    let onBlank: () -> Void
    @Environment(\.dismiss) private var dismiss

    private struct PresetGroup {
        let name: String
        let desc: String
        let days: Int
        let templates: [WorkoutTemplate]
    }

    private let presets: [PresetGroup] = [
        PresetGroup(name: "Push Pull Legs",
                    desc: "6-day split. Push (chest/shoulders/triceps), Pull (back/biceps), Legs. High frequency.",
                    days: 6, templates: TemplateSeedService.pplTemplates),
        PresetGroup(name: "Upper Lower",
                    desc: "4-day split. Two upper and two lower sessions per week. Balanced frequency.",
                    days: 4, templates: TemplateSeedService.upperLowerTemplates),
        PresetGroup(name: "Full Body",
                    desc: "3-day split. Hit every major muscle group each session. Great for beginners.",
                    days: 3, templates: TemplateSeedService.fullBodyTemplates),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.inkFaint)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CHOOSE A TEMPLATE")
                        .font(.archivo(22, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                    Text("All exercises are editable after selecting")
                        .font(.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("×")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    Button {
                        dismiss()
                        onBlank()
                    } label: {
                        presetRow(name: "Blank Program",
                                  desc: "Start from scratch — add your own exercises and structure",
                                  days: nil)
                    }
                    .buttonStyle(.plain)

                    ForEach(presets, id: \.name) { p in
                        Rectangle().fill(Color.dsHairLine).frame(height: 1)
                        Button {
                            dismiss()
                            onSelectPresets(p.templates)
                        } label: {
                            presetRow(name: p.name, desc: p.desc, days: p.days)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color.canvasBg)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func presetRow(name: String, desc: String, days: Int?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(days == nil ? Color.surf2 : Color.pumpAccent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(days == nil ? Color.dsHairLine : Color.pumpAccent.opacity(0.2), lineWidth: 1)
                    )
                if let d = days {
                    Text("\(d)D")
                        .font(.archivo(14, weight: .semibold))
                        .foregroundStyle(Color.pumpAccent)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.archivo(14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(desc)
                    .font(.archivo(12))
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.inkFaint)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Workout Day Picker Sheet

struct WorkoutDayPickerSheet: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.surf)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("WHAT'S TODAY?")
                        .font(.archivo(22, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                    Text("PICK YOUR WORKOUT FOR TODAY")
                        .font(.spaceMono(9))
                        .tracking(1.2)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            if templates.isEmpty {
                Spacer()
                Text("NO PROGRAMS YET")
                    .font(.archivo(20, weight: .black))
                    .foregroundStyle(Color.inkFaint)
                Text("Create a program first")
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(templates.enumerated()), id: \.element.id) { idx, template in
                            Button {
                                onSelect(template)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.pumpAccent.opacity(0.10))
                                            .frame(width: 40, height: 40)
                                        Text(String(template.name.prefix(1)).uppercased())
                                            .font(.archivo(16, weight: .black))
                                            .foregroundStyle(Color.pumpAccent)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(template.name.uppercased())
                                            .font(.archivo(16, weight: .semibold))
                                            .foregroundStyle(Color.inkPrimary)
                                        Text("\(template.templateExercises.count) EXERCISES")
                                            .font(.spaceMono(9))
                                            .tracking(0.8)
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.inkFaint)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.98))

                            if idx < templates.count - 1 {
                                Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.leading, 70)
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}

// MARK: - Profile Menu Sheet

struct ProfileMenuSheet: View {
    let user: User?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.pumpAccent.opacity(0.10))
                        .frame(width: 44, height: 44)
                    Text(user?.name.prefix(1).uppercased() ?? "?")
                        .font(.archivo(20, weight: .black))
                        .foregroundStyle(Color.pumpAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text((user?.name ?? "ATHLETE").uppercased())
                        .font(.archivo(18, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                    if let username = user?.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.spaceMono(9))
                            .tracking(0.8)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.surf)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.inkMuted)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            // Menu rows
            VStack(spacing: 0) {
                menuRow(icon: "arrow.right.square", label: "SIGN OUT", destructive: true) {
                    try? FirebaseAuthService().signOut()
                    dismiss()
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }

    private func menuRow(icon: String, label: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(destructive ? Color.signalDown.opacity(0.10) : Color.surf2)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(destructive ? Color.signalDown : Color.inkMuted)
                }
                Text(label)
                    .font(.archivo(15, weight: .medium))
                    .foregroundStyle(destructive ? Color.signalDown : Color.inkPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.98))
    }
}

// MARK: - Chip Flow Layout

struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

#Preview {
    ContentView()
}
