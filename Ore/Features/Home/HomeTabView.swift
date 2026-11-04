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

    // MARK: - Redesigned Home (Ore Home Final)

    @Environment(\.weightUnit) private var unit
    @Environment(\.colorScheme) private var scheme
    @State private var snap = HomeSnapshot.empty
    @State private var openedWorkout: Workout?

    private var week: HomeWeekStats { HomeWeekStats(workouts: workouts, templates: templates) }

    /// What is up next: the manual pick, else the program's next workout, else the pattern prediction.
    private var heroTemplate: WorkoutTemplate? {
        if let manualOverrideTemplate { return manualOverrideTemplate }
        let programs = ProgramPlan.programs(from: templates)
        if case .workout(_, _, let t)? = ProgramPlan.upNext(programs) { return t }
        return predictedTemplate
    }

    private var heroName: String? { heroTemplate?.name ?? predictedTemplateName }

    var body: some View {
        let w = week
        VStack(spacing: 0) {
            OreMasthead(markID: AX.home.mark) {
                HStack(spacing: 4) {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .regular)).foregroundStyle(Color.inkPrimary)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Search").accessibilityIdentifier(AX.home.searchButton)
                    Button { showProfileMenu = true } label: {
                        Text(user?.name.prefix(1).uppercased() ?? "?").font(.archivo(15, weight: .black)).foregroundStyle(Color.inkPrimary)
                            .frame(width: 36, height: 36).background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Profile").accessibilityIdentifier(AX.home.profileButton)
                }
                #if DEBUG
                .onLongPressGesture { workoutViewModel.showPreviewCompletion() }
                #endif
            }
            // The ticker shows once there is real data.
            if snap.hasHistory, !snap.ticker.isEmpty { TickerStripView(items: snap.ticker) }

            ScrollView {
                VStack(spacing: 0) {
                    hero(w)
                    if snap.hasHistory { statsStrip } else { newUserNote }
                    weekHeader
                    ledgerHeader
                    ForEach(snap.ledger) { row in ledgerRow(row, w) }
                    if let line = snap.lastWeekLine {
                        HStack {
                            Text("LAST WEEK")
                            Spacer(minLength: 0)
                            Text(line).foregroundStyle(Color.inkSecondary)
                        }
                        .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    FriendActivityBanner()
                    Color.clear.frame(height: 20)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            StartWorkoutDock(
                viewModel: workoutViewModel,
                overrideTemplate: heroTemplate,
                onRequestDiscard: { draft in
                    pendingDiscardDraft = draft
                    showDiscardConfirmation = true
                }
            )
        }
        // The numbers on this screen are worked out here, when the workouts change, instead of in the body.
        .task(id: "\(kpisKey)|\(unit.rawValue)|\(templates.count)") {
            // SwiftData loads a record's fields the first time they are read, one database round trip each, so
            // reading every set of a long history is thousands of them. Load the logs and sets in two bulk fetches
            // first (and keep them alive while the numbers are worked out): the reads then come from memory.
            let logs = (try? modelContext.fetch(FetchDescriptor<ExerciseLog>())) ?? []
            let sets = (try? modelContext.fetch(FetchDescriptor<SetLog>())) ?? []
            kpis = HomeKPIs(onePassOver: stats)
            snap = HomeSnapshot(HomeWeekStats(workouts: workouts, templates: templates), unit: unit)
            withExtendedLifetime((logs, sets)) {}
        }
        .fullScreenCover(isPresented: $showSearch) {
            GlobalSearchView()
        }
        .fullScreenCover(item: $openedWorkout) { w in
            LocalWorkoutFullView(workout: w)
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
                Color(red: 21 / 255, green: 26 / 255, blue: 33 / 255).opacity(0.35)      // dim, never blur
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
    }

    // MARK: Hero

    private func hero(_ w: HomeWeekStats) -> some View {
        let template = heroTemplate
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(w.dateLine).font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary).monoLine(9)
                Spacer(minLength: 0)
                if let line = template.flatMap({ w.programLine(upNext: $0) }) {
                    Text(line).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).monoLine(8)
                }
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(w.heroLabel).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).monoLine(8).accessibilityIdentifier(AX.home.heroLabel)
                    Text((heroName ?? "NO WORKOUT").uppercased()).font(.archivo(40, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary)
                        .lineLimit(2).minimumScaleFactor(0.6).fixedSize(horizontal: false, vertical: true)
                        .cssLineHeight(fontName: "Archivo-Black", size: 40, multiple: 0.95)
                        .accessibilityIdentifier(AX.home.predictedName)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(snap.hasHistory ? "\(snap.weekStreak)" : "—").font(.spaceMono(40, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        .frame(height: 36)
                        .accessibilityIdentifier(AX.home.kpiStreak)
                    Text("WK STREAK").font(.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted).monoLine(7)
                }
            }
            if let template {
                let meta = w.metaLine(for: template)
                if !meta.isEmpty { Text(meta).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).monoLine(9) }
                let ex = w.exerciseLine(for: template)
                if !ex.isEmpty { Text(ex).font(.archivo(13)).foregroundStyle(Color.inkSecondary).fixedSize(horizontal: false, vertical: true)
                    .cssLineHeight(fontName: "Archivo-Regular", size: 13, multiple: 1.45) }
            }
            Button { showDayPicker = true } label: {
                Text("NOT TODAY? ›").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkSecondary).monoLine(9)
                    .frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.home.notToday)
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surf)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: Stats strip + new user

    private var statsStrip: some View {
        let s = snap.strip
        return HStack(spacing: 0) {
            statCell("SETS", "\(s.sets)", DeltaText.count(s.setsDelta), id: AX.home.kpiSets, first: true)
            statCell("VOLUME", unit.compactVolume(s.volumeKg), DeltaText.percent(s.volumeDelta), id: AX.home.kpiVolume, first: false)
            statCell("PRS", "\(s.prs)", "", id: AX.home.kpiPRs, first: false)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func statCell(_ label: String, _ value: String, _ delta: String, id: String, first: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).monoLine(8)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.spaceMono(22, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1).minimumScaleFactor(0.6)
                    .accessibilityIdentifier(id)
                Text(delta).font(.spaceMono(10, weight: .bold)).foregroundStyle(deltaColor(delta)).lineLimit(1).fixedSize()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { if !first { Rectangle().fill(Color.dsHairLine).frame(width: 1) } }
    }

    private func deltaColor(_ text: String) -> Color {
        switch DeltaText.sign(of: text) { case .up: .signalUp; case .down: .signalDown; case .flat: .inkMuted }
    }

    private var newUserNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No workouts yet.").font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
            Text("Streak, sets and PRs start counting after your first session.").font(.archivo(13)).foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityElement(children: .combine).accessibilityIdentifier(AX.home.newUserNote)
    }

    // MARK: Week ledger

    private var weekHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("THIS WEEK · PROGRAM WK \(snap.weekNumber)")
            Spacer(minLength: 0)
            Text("\(snap.doneText) DONE").font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.inkPrimary)
        }
        .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
    }

    private var ledgerHeader: some View {
        HStack(spacing: 10) {
            Text("DAY").frame(width: 40, alignment: .leading)
            Text("WORKOUT").frame(maxWidth: .infinity, alignment: .leading)
            Text("SETS").frame(width: 40, alignment: .trailing)
            Text("VOL").frame(width: 52, alignment: .trailing)
        }
        .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 16).padding(.vertical, 8).background(Color.surf2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(snap.hasHistory ? AX.home.recent : AX.home.ledgerHeader)
    }

    private func ledgerRow(_ r: HomeWeekStats.LedgerRow, _ w: HomeWeekStats) -> some View {
        let done = r.workout != nil
        let nameFont: Font = r.isToday ? .archivo(20, weight: .black) : done ? .archivo(15, weight: .semibold) : .archivo(15)
        let nameColor: Color = r.isToday || done ? .inkPrimary : r.isRest ? Color.inkPrimary.opacity(scheme == .dark ? 0.18 : 0.13) : .inkMuted
        let content = VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(r.day).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(r.isToday ? Color.inkPrimary : done ? Color.inkSecondary : Color.inkMuted).frame(width: 40, alignment: .leading)
                Text(r.name.uppercased()).font(nameFont).foregroundStyle(nameColor).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Text(r.sets.map { "\($0)" } ?? "").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(width: 40, alignment: .trailing)
                Text(r.volumeText).font(.spaceMono(11, weight: .bold)).foregroundStyle(deltaColor(r.volumeText)).frame(width: 52, alignment: .trailing)
            }
            .frame(minHeight: 46)
            if r.isToday, let t = heroTemplate, !done {
                VStack(alignment: .leading, spacing: 6) {
                    let meta = w.metaLine(for: t)
                    if !meta.isEmpty { Text(meta).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted) }
                    let ex = w.exerciseLine(for: t)
                    if !ex.isEmpty { Text(ex).font(.archivo(13)).foregroundStyle(Color.inkSecondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 50).padding(.bottom, 12)
            }
        }
        .padding(.leading, 14).padding(.trailing, 16)
        .background(r.isToday ? Color.oreAccent.opacity(0.08) : Color.clear)
        .overlay(alignment: .leading) { Rectangle().fill(r.isToday ? Color.oreAccent : Color.clear).frame(width: 2) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        return Group {
            if let workout = r.workout {
                Button { openedWorkout = workout } label: { content.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityIdentifier(AX.home.ledgerRow(r.id))
            } else {
                content.accessibilityIdentifier(AX.home.ledgerRow(r.id))
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
    }

}
