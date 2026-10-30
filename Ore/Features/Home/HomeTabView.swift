import SwiftUI
import SwiftData
import FirebaseAuth

struct HomeTabView: View {
    @Bindable var workoutViewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthSession.self) private var session
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }, sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @State private var showSearch = false
    @State private var barsAppeared = false
    @State private var showDayPicker = false
    @State private var manualOverrideTemplate: WorkoutTemplate? = nil
    @State private var showProfileMenu = false
    @State private var showDiscardConfirmation = false
    @State private var pendingDiscardDraft: Workout? = nil

    private var user: User? { users.first }

    // MARK: Computed KPIs (the maths lives in HomeStats so tests can drive it)
    private var stats: HomeStats { HomeStats(workouts: workouts) }
    /// The whole-history numbers, worked out once per change to the workouts (see `HomeKPIs`), not per redraw.
    @State private var kpis = HomeKPIs.empty
    private var kpisKey: Int {
        var hasher = Hasher()
        hasher.combine(workouts.count)
        for w in workouts.prefix(6) { hasher.combine(w.id); hasher.combine(w.updatedAt) }
        return hasher.finalize()
    }
    private var currentStreak: Int { kpis.currentStreak }
    private var weekSets: Int { kpis.weekSets }
    private var weekPRs: Int { kpis.weekPRs }
    private var weekImproved: Int { kpis.weekImproved }
    /// Sets per day for the current week (Mon=0 … Sun=6)
    private var weekDayBars: [Int] { kpis.weekDayBars }
    private var todayDayIndex: Int { kpis.todayDayIndex }

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
        return templates.first { $0.name.lowercased() == name.lowercased() }
    }

    /// 0-1 confidence in the prediction — the same successor-frequency formula the Next Workout
    /// widget uses (`WidgetDataService.predictionConfidence`), so the app and widget agree.
    private var predictionConfidence: Double {
        WidgetDataService.predictionConfidence(
            names: workouts.prefix(14).compactMap { $0.template?.name },
            hasSplit: user?.selectedSplit != nil,
            predicted: basePredictedName != nil)
    }
    private var confidenceDots: Int { Int((predictionConfidence * 5).rounded()) }
    private var confidenceLabel: String {
        switch predictionConfidence {
        case 0.75...: "HIGH\nCONF"
        case 0.45...: "MED\nCONF"
        default: "LOW\nCONF"
        }
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
    private var currentWeekNumber: Int { stats.currentWeekNumber(userCreatedAt: user?.createdAt) }

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
        // The numbers on this screen are worked out here, when the workouts change, instead of in the body.
        .task(id: kpisKey) {
            // SwiftData loads a record's fields the first time they are read, one database round trip each, so
            // reading every set of a long history is thousands of them. Load the logs and sets in two bulk fetches
            // first (and keep them alive while the numbers are worked out): the reads then come from memory.
            let logs = (try? modelContext.fetch(FetchDescriptor<ExerciseLog>())) ?? []
            let sets = (try? modelContext.fetch(FetchDescriptor<SetLog>())) ?? []
            kpis = HomeKPIs(onePassOver: stats)
            withExtendedLifetime((logs, sets)) {}
        }
        .fullScreenCover(isPresented: $showSearch) {
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
                .accessibilityIdentifier(AX.home.profileCancel)

                Button {
                    showProfileMenu = false
                    Task { await session.signOut() }
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
                .accessibilityIdentifier(AX.home.signOut)
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
                // Left: accent rect + "ORE" monospaced
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.oreAccent)
                        .frame(width: 14, height: 14)
                    Text("ORE")
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
                    .accessibilityLabel("Search")
                    .accessibilityIdentifier(AX.home.searchButton)
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
                    .accessibilityLabel("Profile")
                    .accessibilityIdentifier(AX.home.profileButton)
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
                            .foregroundStyle(Color.accentInk)
                        Text(name.uppercased())
                            .font(.archivo(28, weight: .black))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                            .accessibilityIdentifier(AX.home.predictedName)
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
                                    .fill(i < confidenceDots ? Color.oreAccent : Color.inkFaint)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        Text(confidenceLabel)
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
                                .foregroundStyle(Color.accentInk.opacity(0.8))
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AX.home.notToday)
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
                    valueColor: Color.accentInk,
                    id: AX.home.kpiStreak
                )
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                kpiCell(
                    label: "IMPROVED",
                    value: "\(weekImproved)",
                    sub: "THIS WK",
                    valueColor: Color.inkPrimary,
                    id: AX.home.kpiImproved
                )
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                kpiCell(
                    label: "PRs",
                    value: "\(weekPRs)",
                    sub: "THIS WK",
                    valueColor: Color.inkPrimary,
                    id: AX.home.kpiPRs
                )
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                kpiCell(
                    label: "SETS",
                    value: "\(weekSets)",
                    sub: "THIS WK",
                    valueColor: Color.inkPrimary,
                    id: AX.home.kpiSets
                )
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    private func kpiCell(label: String, value: String, sub: String, valueColor: Color, id: String) -> some View {
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
                .accessibilityIdentifier(id)
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
                        .foregroundStyle(Color.accentInk)
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
                                    isToday ? Color.oreAccent :
                                    (isPast && v > 0 ? Color.oreAccent.opacity(0.70) :
                                     Color.inkFaint.opacity(0.15))
                                )
                                .frame(height: animH)
                                .frame(maxWidth: .infinity)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(i) * 0.04), value: barsAppeared)
                            Text(labels[i])
                                .font(Font.mono(7))
                                .foregroundStyle(isToday ? Color.accentInk : Color.inkMuted)
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
                    .foregroundStyle(Color.accentInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(AX.home.recent)
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

                        // Worked out with the other KPIs, not here: it compares against the whole history.
                        let row = idx < kpis.recentRows.count ? kpis.recentRows[idx] : nil
                        let sets = row?.sets ?? 0
                        let improvedCount = row?.improved ?? 0
                        let totalExercises = row?.exerciseCount ?? 1

                        Text("\(sets)")
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 56, alignment: .center)

                        Text("\(improvedCount)/\(totalExercises)")
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(Color.accentInk)
                            .frame(width: 56, alignment: .center)

                        let volDelta = row?.volumeDelta ?? "—"
                        Text(volDelta)
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(volDelta.hasPrefix("▲") ? Color.signalUp : (volDelta == "—" ? Color.inkMuted : Color.signalDown))
                            .frame(width: 56, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(AX.home.recentRow(idx))
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

    private func volumeDelta(for workout: Workout) -> String { stats.volumeDelta(for: workout) }

    private func improvedExercises(in workout: Workout) -> Int { stats.improvedExercises(in: workout) }

    // MARK: - Ticker Data

    private func buildTickerItems() -> [TickerItem] {
        kpis.tickerRows.map { TickerItem(label: $0.label, value: $0.value, direction: $0.up ? .up : .down) }
    }
}

// MARK: - Friend Activity Banner
