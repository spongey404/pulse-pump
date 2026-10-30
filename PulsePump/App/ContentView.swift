import SwiftUI
import SwiftData
import FirebaseAuth

struct ContentView: View {
    @State private var workoutViewModel = WorkoutViewModel()
    @State private var tutorialViewModel = TutorialViewModel()
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
            .onReceive(NotificationCenter.default.publisher(for: .openPulsePlus)) { _ in
                MoreRouter.shared.pendingPulsePlus = true
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
            if UserDefaults.standard.bool(forKey: "wantsTutorial") {
                tutorialViewModel.start()
                #if DEBUG
                // `-debugTutorialStep <n>` starts the walkthrough on step n (0-based).
                if let n = Int(UserDefaults.standard.string(forKey: "debugTutorialStep") ?? ""),
                   let step = TutorialStep(rawValue: n) { tutorialViewModel.currentStep = step }
                #endif
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
