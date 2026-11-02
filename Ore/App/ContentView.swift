import SwiftUI
import SwiftData
import FirebaseAuth

struct ContentView: View {
    @State private var workoutViewModel = WorkoutViewModel()
    @State private var tutorialViewModel = TutorialViewModel()
    @State private var showSupernovaPaywall = false
    /// `onAppear` can run again (a full-screen cover coming and going); the first-run tutorial starts once.
    @State private var autoStartedTutorial = false
    #if DEBUG
    // `-debugStartTab <n>` launch argument jumps straight to a tab for visual checks.
    @State private var selectedTab = Int(UserDefaults.standard.string(forKey: "debugStartTab") ?? "") ?? 2
    #else
    @State private var selectedTab = 2
    #endif
    @Environment(\.modelContext) private var modelContext
    @State private var sharedTemplateMessage: String?
    @Query private var users: [User]
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }) private var templates: [WorkoutTemplate]

    private var user: User? { users.first }

    var body: some View {
        // The More tab's Supernova paywall grows out of the banner above the whole shell (tab bar included).
        SupernovaTransitionHost(onSubscribed: { selectedTab = 2 }) { shell }
    }

    private var shell: some View {
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
                CustomTabBar(selectedTab: $selectedTab, workoutActive: workoutViewModel.isActive)
            }
            .fullScreenCover(isPresented: $workoutViewModel.isActive) {
                ActiveWorkoutView(viewModel: workoutViewModel)
            }
            .fullScreenCover(isPresented: $showSupernovaPaywall) {
                SupernovaPaywallView(
                    onSubscribed: { showSupernovaPaywall = false; selectedTab = 2 },
                    onTrainFree: { showSupernovaPaywall = false; selectedTab = 2 })
            }
            .onChange(of: showSupernovaPaywall) { _, isShowing in
                guard !isShowing else { return }
                SupernovaPaywallGate.markShown()
                // Notifications are asked for after the paywall, never over it.
                Task { _ = await NotificationService.shared.requestPermission() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showSupernovaPaywall)) { note in
                presentSupernovaPaywall(after: .milliseconds(600), force: (note.object as? Bool) == true)   // after the tutorial's overlay and practice workout are gone
            }
            .fullScreenCover(isPresented: $workoutViewModel.showCompletionSummary) {
                if let data = workoutViewModel.completionData {
                    WorkoutCompletionView(data: data, userName: user?.name ?? "") {
                        workoutViewModel.reset()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startWorkoutFromWidget)) { note in
                if let name = note.object as? String, let t = templates.first(where: { $0.name == name }) {
                    startFromTemplate(t)
                } else {
                    startBlankWorkout()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .importTemplate)) { note in
                if let raw = note.object as? String, let payload = TemplateShareService.decode(base64: raw) {
                    let t = TemplateShareService.importTemplate(payload, modelContext: modelContext)
                    sharedTemplateMessage = "Added \"\(t.name)\" (\(t.templateExercises.count) exercises) to your programs."
                } else {
                    sharedTemplateMessage = "That template link couldn't be read."
                }
            }
            .alert("Shared template", isPresented: Binding(
                get: { sharedTemplateMessage != nil },
                set: { if !$0 { sharedTemplateMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sharedTemplateMessage ?? "")
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSupernova)) { _ in
                MoreRouter.shared.pendingSupernova = true
                selectedTab = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: .tutorialExerciseAdded)) { _ in
                tutorialViewModel.handle(.exerciseAdded)
            }
            .onReceive(NotificationCenter.default.publisher(for: .loggerScrolledToTop)) { _ in
                tutorialViewModel.handle(.scrolledToTop)
            }
            .onReceive(NotificationCenter.default.publisher(for: .tutorialSetCompleted)) { _ in
                tutorialViewModel.handle(.setCompleted)
            }
            .onChange(of: tutorialViewModel.isActive) { _, active in
                if active {
                    selectedTab = 2   // the walkthrough starts on Home
                } else if tutorialViewModel.startedPracticeWorkout, workoutViewModel.isActive {
                    // Skipped mid-way: the practice workout must not linger as a draft.
                    workoutViewModel.cancelWorkout(modelContext: modelContext)
                }
                tutorialViewModel.presenter.sync()
            }
        }
        .onAppear {
            // The tutorial types into the practice set so the user only has to tap log.
            tutorialViewModel.fillSet = { exercise, weight, reps, rir in
                guard let i = workoutViewModel.exerciseEntries.firstIndex(where: { $0.exerciseName == exercise })
                        ?? workoutViewModel.exerciseEntries.indices.last,
                      !workoutViewModel.exerciseEntries[i].sets.isEmpty else { return }
                if let weight { workoutViewModel.exerciseEntries[i].sets[0].weight = weight }
                if let reps { workoutViewModel.exerciseEntries[i].sets[0].reps = reps }
                if let rir { workoutViewModel.exerciseEntries[i].sets[0].rir = rir }
            }
            ExerciseSeedService.seedIfNeeded(modelContext: modelContext)
            TemplateSeedService.seedIfNeeded(modelContext: modelContext)   // links presets to the catalogue by name
            // Onboarding without the tutorial: the paywall comes straight after onboarding.
            if !UserDefaults.standard.bool(forKey: "wantsTutorial") { presentSupernovaPaywall(after: .milliseconds(900)) }
            if UserDefaults.standard.bool(forKey: "wantsTutorial"), !autoStartedTutorial {
                autoStartedTutorial = true
                tutorialViewModel.start(firstRun: true)
                #if DEBUG
                // `-debugTutorialStep <n>` starts the walkthrough on step n (0-based).
                if let n = Int(UserDefaults.standard.string(forKey: "debugTutorialStep") ?? ""),
                   let step = TutorialStep(rawValue: n) { tutorialViewModel.currentStep = step }
                #endif
            }
        }
    }

    /// Shows the Supernova paywall if it is due (once, never for a member). A subscription bought on another device is
    /// picked up first, so a returning member isn't shown it.
    private func presentSupernovaPaywall(after delay: Duration, force: Bool = false) {
        // `force`: the end of the tutorial, which always leads here for someone without Supernova (even a replay).
        func due() -> Bool { force ? !SupernovaPaywallGate.isMember() : SupernovaPaywallGate.shouldShowNow() }
        Task {
            try? await Task.sleep(for: delay)
            guard due() else { return }
            await SupernovaService().refreshSubscriptionStatus()
            guard due(), !showSupernovaPaywall,
                  !workoutViewModel.isActive, !workoutViewModel.showCompletionSummary else { return }
            showSupernovaPaywall = true   // used up when it is dismissed (below), so a rebuilt ContentView shows it again
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
