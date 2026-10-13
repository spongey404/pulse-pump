import Testing
@testable import PulsePump

struct TutorialViewModelTests {

    @Test @MainActor func initialState() {
        let vm = TutorialViewModel()
        #expect(vm.currentStep == .gymProfile)
        #expect(!vm.isActive)
        #expect(!vm.isFinished)
    }

    @Test @MainActor func startActivates() {
        let vm = TutorialViewModel()
        vm.start()
        #expect(vm.isActive)
        #expect(vm.currentStep == .gymProfile)
    }

    @Test @MainActor func advanceMovesToNextStep() {
        let vm = TutorialViewModel()
        vm.start()
        vm.advance()
        #expect(vm.currentStep == .plates)
    }

    @Test @MainActor func advanceThroughAllSteps() {
        let vm = TutorialViewModel()
        vm.start()
        for _ in 1..<TutorialStep.allCases.count { vm.advance() }
        #expect(vm.currentStep == .summary)
        #expect(!vm.isFinished)
    }

    @Test @MainActor func advancePastLastStepShowsCompletion() {
        let vm = TutorialViewModel()
        vm.start()
        for _ in 1..<TutorialStep.allCases.count { vm.advance() }
        vm.advance()
        #expect(vm.isFinished)
        #expect(vm.isActive)
    }

    @Test @MainActor func completeDeactivates() {
        let vm = TutorialViewModel()
        vm.start()
        vm.complete()
        #expect(!vm.isActive)
        #expect(!vm.isFinished)
    }

    @Test @MainActor func skipDeactivates() {
        let vm = TutorialViewModel()
        vm.start()
        vm.advance()
        vm.skip()
        #expect(!vm.isActive)
    }

    @Test @MainActor func restartResetsCompletion() {
        let vm = TutorialViewModel()
        vm.start()
        for _ in 0..<TutorialStep.allCases.count { vm.advance() }
        vm.start()
        #expect(!vm.isFinished)
        #expect(vm.currentStep == .gymProfile)
    }

    @Test @MainActor func progressBounds() {
        let vm = TutorialViewModel()
        vm.start()
        #expect(vm.progress == 0.0)
        for _ in 1..<TutorialStep.allCases.count { vm.advance() }
        #expect(vm.progress == 1.0)
    }

    // MARK: - TutorialStep properties

    @Test func allStepsHaveCopy() {
        for step in TutorialStep.allCases {
            #expect(!step.title.isEmpty, "\(step) should have a title")
            #expect(!step.description.isEmpty, "\(step) should have a description")
            #expect(!step.phase.isEmpty, "\(step) should have a phase")
        }
    }

    @Test func stepCountIsTen() {
        #expect(TutorialStep.allCases.count == 10)
    }

    @Test func phasesMatchDesign() {
        #expect(TutorialStep.gymProfile.phase == "Equipment")
        #expect(TutorialStep.pickTemplate.phase == "Programs")
        #expect(TutorialStep.ghostText.phase == "Workout Logger")
        #expect(TutorialStep.summary.phase == "Post-Workout")
        #expect(TutorialStep.summary.cta == "Start Training →")
    }
}
