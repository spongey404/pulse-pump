import Testing
@testable import PulsePump

struct TutorialViewModelTests {

    @Test @MainActor func initialState() {
        let vm = TutorialViewModel()
        #expect(vm.currentStep == .welcome)
        #expect(!vm.isActive)
    }

    @Test @MainActor func startActivates() {
        let vm = TutorialViewModel()
        vm.start()
        #expect(vm.isActive)
        #expect(vm.currentStep == .welcome)
    }

    @Test @MainActor func advanceMovesToNextStep() {
        let vm = TutorialViewModel()
        vm.start()
        vm.advance()
        #expect(vm.currentStep == .startWorkout)
    }

    @Test @MainActor func advanceThroughAllSteps() {
        let vm = TutorialViewModel()
        vm.start()
        let totalSteps = TutorialStep.allCases.count
        // Advance through all steps (welcome is step 0, complete is last)
        for _ in 1..<totalSteps {
            vm.advance()
        }
        #expect(vm.currentStep == .complete)
    }

    @Test @MainActor func advancePastCompleteDeactivates() {
        let vm = TutorialViewModel()
        vm.start()
        // Go to complete
        let totalSteps = TutorialStep.allCases.count
        for _ in 1..<totalSteps {
            vm.advance()
        }
        #expect(vm.currentStep == .complete)
        // Advance past complete
        vm.advance()
        #expect(!vm.isActive)
    }

    @Test @MainActor func skipDeactivates() {
        let vm = TutorialViewModel()
        vm.start()
        vm.advance() // move to startWorkout
        vm.skip()
        #expect(!vm.isActive)
    }

    @Test @MainActor func completeDeactivates() {
        let vm = TutorialViewModel()
        vm.start()
        vm.complete()
        #expect(!vm.isActive)
    }

    @Test @MainActor func progressAtWelcome() {
        let vm = TutorialViewModel()
        vm.start()
        #expect(vm.progress == 0.0)
    }

    @Test @MainActor func progressAtComplete() {
        let vm = TutorialViewModel()
        vm.start()
        let totalSteps = TutorialStep.allCases.count
        for _ in 1..<totalSteps {
            vm.advance()
        }
        #expect(vm.progress == 1.0)
    }

    @Test @MainActor func progressMidway() {
        let vm = TutorialViewModel()
        vm.start()
        vm.advance() // step 1 of 9 (0-indexed)
        let expected = 1.0 / Double(TutorialStep.allCases.count - 1)
        #expect(vm.progress == expected)
    }

    // MARK: - TutorialStep Properties

    @Test func allStepsHaveTitles() {
        for step in TutorialStep.allCases {
            #expect(!step.title.isEmpty, "\(step) should have a title")
        }
    }

    @Test func allStepsHaveDescriptions() {
        for step in TutorialStep.allCases {
            #expect(!step.description.isEmpty, "\(step) should have a description")
        }
    }

    @Test func allStepsHaveIcons() {
        for step in TutorialStep.allCases {
            #expect(!step.icon.isEmpty, "\(step) should have an icon")
        }
    }

    @Test func requiredTabMapping() {
        #expect(TutorialStep.welcome.requiredTab == nil)
        #expect(TutorialStep.complete.requiredTab == nil)
        #expect(TutorialStep.startWorkout.requiredTab == 2)
        #expect(TutorialStep.bodyMap.requiredTab == 3)
        #expect(TutorialStep.templates.requiredTab == 0)
        #expect(TutorialStep.warmupGenerator.requiredTab == 4)
    }

    @Test func stepCountIsTen() {
        #expect(TutorialStep.allCases.count == 10)
    }
}
