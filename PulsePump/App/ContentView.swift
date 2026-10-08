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
    @Query private var users: [User]
    @Query private var templates: [WorkoutTemplate]

    private var user: User? { users.first }

    private static var windowSafeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets.top ?? 47
    }

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
            .onReceive(NotificationCenter.default.publisher(for: .openPulsePlus)) { _ in
                MoreRouter.shared.pendingPulsePlus = true
                selectedTab = 4
            }
            .overlayPreferenceValue(TutorialTargetKey.self) { anchors in
                GeometryReader { proxy in
                    if tutorialViewModel.isActive {
                        CoachMarkOverlay(
                            viewModel: tutorialViewModel,
                            selectedTab: $selectedTab,
                            targetRect: tutorialViewModel.currentStep.target
                                .flatMap { anchors[$0] }.map { proxy[$0] },
                            size: proxy.size,
                            safeTop: Self.windowSafeTop
                        )
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            ExerciseSeedService.seedIfNeeded(modelContext: modelContext)
            TemplateSeedService.seedIfNeeded(modelContext: modelContext)
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
