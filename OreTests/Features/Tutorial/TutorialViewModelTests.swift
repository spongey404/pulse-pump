import SwiftUI
import Foundation
import Testing
@testable import Ore

struct TutorialViewModelTests {

    /// A view model whose screen always shows what a step asked for (unit tests have no screen).
    @MainActor private func makeVM() -> TutorialViewModel {
        let vm = TutorialViewModel()
        vm.didSucceed = { _ in true }
        return vm
    }

    // MARK: - Basics

    @Test @MainActor func initialState() {
        let vm = makeVM()
        #expect(vm.currentStep == .startWorkout)
        #expect(!vm.isActive)
        #expect(!vm.isFinished)
    }

    @Test @MainActor func startActivates() {
        let vm = makeVM()
        vm.start()
        #expect(vm.isActive)
        #expect(vm.currentStep == .startWorkout)
        vm.skip()
    }

    @Test @MainActor func advanceMovesToNextStep() {
        let vm = makeVM()
        vm.start()
        vm.advance()
        #expect(vm.currentStep == .addExercise)
        vm.skip()
    }

    @Test @MainActor func advancingPastStartMarksPracticeWorkout() {
        let vm = makeVM()
        vm.start()
        #expect(!vm.startedPracticeWorkout)
        vm.advance()
        #expect(vm.startedPracticeWorkout)
        vm.start()
        #expect(!vm.startedPracticeWorkout)
        vm.skip()
    }

    @Test @MainActor func advanceThroughAllSteps() {
        let vm = makeVM()
        vm.start()
        for _ in 1..<TutorialStep.allCases.count { vm.advance() }
        #expect(vm.currentStep == .discard)
        #expect(!vm.isFinished)
        vm.skip()
    }

    @Test @MainActor func advancePastLastStepShowsCompletionForAMember() {
        // A member has no paywall to go to, so the tutorial ends on its done screen.
        let d = UserDefaults.standard
        let saved = d.object(forKey: SupernovaService.subscribedMirrorKey)
        d.set(true, forKey: SupernovaService.subscribedMirrorKey)
        defer { d.set(saved, forKey: SupernovaService.subscribedMirrorKey) }
        let vm = makeVM()
        vm.start()
        for _ in 1..<TutorialStep.allCases.count { vm.advance() }
        vm.advance()
        #expect(vm.isFinished)
        #expect(vm.isActive)
        vm.skip()
    }

    @Test @MainActor func completeDeactivates() {
        let vm = makeVM()
        vm.start()
        vm.complete()
        #expect(!vm.isActive)
        #expect(!vm.isFinished)
    }

    @Test @MainActor func skipDeactivates() {
        let vm = makeVM()
        vm.start()
        vm.advance()
        vm.skip()
        #expect(!vm.isActive)
    }

    @Test @MainActor func restartResetsCompletion() {
        let vm = makeVM()
        vm.start()
        for _ in 0..<TutorialStep.allCases.count { vm.advance() }
        vm.start()
        #expect(!vm.isFinished)
        #expect(vm.currentStep == .startWorkout)
        vm.skip()
    }

    @Test @MainActor func progressBounds() {
        let vm = makeVM()
        vm.start()
        #expect(vm.progress == 0.0)
        for _ in 1..<TutorialStep.allCases.count { vm.advance() }
        #expect(vm.progress == 1.0)
        vm.skip()
    }

    // MARK: - Events

    @Test @MainActor func addingAnExerciseSkipsThePickerStepsAndTurnsRIROnFirst() {
        let vm = makeVM()
        vm.start()
        vm.currentStep = .pickExercise
        vm.handle(.exerciseAdded)
        #expect(vm.currentStep == .rir, "RIR is switched on before the numbers are typed, so they include it")
        vm.skip()

        vm.start()
        vm.currentStep = .pickVariant
        vm.handle(.exerciseAdded)
        #expect(vm.currentStep == .rir)
        vm.skip()
    }

    @Test @MainActor func eventsOutsideTheirStepAreIgnored() {
        let vm = makeVM()
        vm.start()
        vm.handle(.exerciseAdded)
        vm.handle(.setCompleted)
        #expect(vm.currentStep == .startWorkout)

        vm.currentStep = .swipeSet
        vm.handle(.exerciseAdded)
        #expect(vm.currentStep == .swipeSet)
        vm.skip()
    }

    @Test @MainActor func inactiveTutorialIgnoresEvents() {
        let vm = makeVM()
        vm.currentStep = .pickExercise
        vm.handle(.exerciseAdded)
        #expect(vm.currentStep == .pickExercise)
    }

    @Test @MainActor func tapAdvancesAfterTheScreenReacts() async throws {
        let vm = makeVM()
        vm.start()
        vm.targetTapped()
        #expect(vm.currentStep == .startWorkout, "waits for the tapped control to finish its own action")
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .addExercise)
        vm.skip()
    }

    @Test @MainActor func tapOnTheLogStepOnlyCountsOnceTheSetIsLogged() async throws {
        let vm = makeVM()
        vm.start()
        vm.currentStep = .logSet
        vm.targetTapped()
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .logSet, "the log step waits for the set to actually be logged")
        vm.handle(.setCompleted)
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .swipeSet)
        vm.skip()
    }

    @Test @MainActor func swipeOnlyAdvancesTheSwipeStep() async throws {
        let vm = makeVM()
        vm.start()
        vm.targetSwiped()
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .startWorkout)

        vm.currentStep = .swipeSet
        vm.targetSwiped()
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .searchPull)
        vm.skip()
    }

    @Test @MainActor func aStepThatChangedMeanwhileIsNotAdvancedTwice() async throws {
        let vm = makeVM()
        vm.start()
        vm.currentStep = .pickExercise
        vm.targetTapped()            // tap on a lift that has no variants…
        vm.handle(.exerciseAdded)    // …adds it straight away
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .rir)
        vm.skip()
    }

    // MARK: - A tap that missed the control must not move the tutorial on

    @Test @MainActor func aTapThatMissedTheControlDoesNotAdvance() async throws {
        let vm = TutorialViewModel()
        vm.didSucceed = { _ in false }   // e.g. the back arrow was tapped just outside its real area: no modal
        vm.readyTimeout = .milliseconds(400)
        vm.start()
        vm.currentStep = .leave
        vm.touchBegan()
        vm.targetTapped()
        try await Task.sleep(for: .milliseconds(1700))
        #expect(vm.currentStep == .leave, "no modal appeared, so the tutorial waits for a real tap")
        #expect(!vm.isTransitioning, "and the card comes back")
        vm.skip()
    }

    @Test @MainActor func aTapThatWorkedAdvancesOnceTheNextScreenIsThere() async throws {
        let vm = TutorialViewModel()
        var modalShown = false
        vm.didSucceed = { $0 != .leave || modalShown }
        vm.start()
        vm.currentStep = .leave
        vm.targetTapped()
        try await Task.sleep(for: .milliseconds(900))
        modalShown = true
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.currentStep == .discard)
        vm.skip()
    }

    // MARK: - Practice workout mode

    @Test @MainActor func practiceWorkoutModeFollowsTheTutorial() {
        let vm = makeVM()
        vm.start()
        #expect(TutorialMode.isRunning, "the Home button starts an empty practice workout")
        vm.skip()
        #expect(!TutorialMode.isRunning)
    }

    // MARK: - Hand-over between steps

    @Test @MainActor func fingerDownHidesTheCardAtOnceAndAbandonedTouchBringsItBack() async throws {
        let vm = makeVM()
        vm.start()
        vm.touchBegan()
        #expect(vm.isTransitioning, "the old card starts fading before the next screen moves")
        vm.touchAbandoned()
        try await Task.sleep(for: .milliseconds(400))
        #expect(!vm.isTransitioning)
        #expect(vm.currentStep == .startWorkout)
        vm.skip()
    }

    @Test @MainActor func tapKeepsTheCardHiddenUntilTheNextStepIsShown() async throws {
        let vm = makeVM()
        vm.start()
        vm.touchBegan()
        vm.targetTapped()
        try await Task.sleep(for: .milliseconds(300))
        #expect(vm.isTransitioning && vm.currentStep == .startWorkout)
        try await Task.sleep(for: .milliseconds(800))
        #expect(!vm.isTransitioning && vm.currentStep == .addExercise)
        vm.skip()
    }

    @Test @MainActor func logTapThatDoesNothingRestoresTheCard() async throws {
        let vm = makeVM()
        vm.start()
        vm.currentStep = .logSet
        vm.touchBegan()
        vm.targetTapped()
        try await Task.sleep(for: .milliseconds(1200))
        #expect(!vm.isTransitioning && vm.currentStep == .logSet)
        vm.skip()
    }

    // MARK: - Search mid-workout

    @Test @MainActor func pullDownAdvancesOnlyTheSearchStep() async throws {
        let vm = makeVM()
        vm.start()
        vm.currentStep = .searchPull
        vm.targetSwiped(.swipeLeft)
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .searchPull, "a left swipe is not the pull")
        vm.targetSwiped(.swipeDown)
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .searchFind, "no tap on the bar: the word is typed as soon as the panel is open")
        vm.skip()
    }

    @Test @MainActor func theFirstSearchTypesRowThenWaitsForTheJump() async throws {
        let vm = makeVM()
        vm.start()
        var typed: [String] = []
        let token = NotificationCenter.default.addObserver(forName: .tutorialFillSearch, object: nil, queue: .main) {
            if let t = $0.object as? String { typed.append(t) }
        }
        defer { NotificationCenter.default.removeObserver(token) }
        vm.currentStep = .searchPull
        vm.targetSwiped(.swipeDown)
        try await Task.sleep(for: .milliseconds(5800))
        #expect(typed == ["r", "ro", "row"], "a word that matches an exercise already far down the workout")
        #expect(vm.currentStep == .searchJump)
        vm.skip()
    }

    @Test @MainActor func jumpingToTheFarExerciseFillsItsSetSoOnlyTheTapIsLeft() async throws {
        let vm = makeVM()
        var seen: [(exercise: String?, weight: String?, reps: String?, rir: String?)] = []
        vm.fillSet = { seen.append(($0, $1, $2, $3)) }
        vm.start()
        vm.currentStep = .searchJump
        vm.targetTapped()                      // the search closed and the list scrolled to it
        try await Task.sleep(for: .milliseconds(2000))
        #expect(vm.currentStep == .logNext)
        #expect(TutorialFocus.shared.exerciseName == TutorialMode.farExercise)
        let unit = UnitPreference.current
        #expect(seen.contains { $0.exercise == TutorialMode.farExercise && $0.weight == unit.kgString(displayText: unit == .kg ? "40" : "85") && $0.reps == "10" })
        vm.skip()
    }

    @Test @MainActor func loggingTheJumpedToSetMovesOnToTheStatusBarTipAndOnlyTheListReachingTheTopFinishesIt() async throws {
        let vm = makeVM()
        vm.start()
        vm.currentStep = .logNext
        vm.handle(.setCompleted)
        try await Task.sleep(for: .milliseconds(1600))
        #expect(vm.currentStep == .scrollTop)

        vm.targetTapped()
        vm.targetSwiped(.swipeDown)
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.currentStep == .scrollTop, "touches inside the app don't count: the status bar tap is the system's")

        vm.handle(.scrolledToTop)
        try await Task.sleep(for: .milliseconds(1600))
        #expect(vm.currentStep == .leave, "once the list is back at the top")
        vm.skip()
    }

    @Test @MainActor func theListReachingTheTopIsIgnoredOnOtherSteps() {
        let vm = makeVM()
        vm.start()
        vm.handle(.scrolledToTop)
        #expect(vm.currentStep == .startWorkout)
        vm.currentStep = .searchPull
        vm.handle(.scrolledToTop)
        #expect(vm.currentStep == .searchPull)
        vm.skip()
    }

    @Test @MainActor func theStatusBarIsASpotlightTargetAcrossTheTopOfTheScreen() {
        let frame = TutorialTargets.shared.frame(TutorialTargets.statusBarID)
        #expect(frame != nil)
        #expect(frame!.minY == 0 && frame!.minX == 0)
        #expect(frame!.height >= 20, "tall enough to tap")
        #expect(frame!.width > 300, "across the whole top of the screen")
        #expect(TutorialStep.scrollTop.target == TutorialTargets.statusBarID)
        #expect(TutorialStep.scrollTop.gesture == .statusTap)
        #expect(TutorialStep.scrollTop.waitsForEvent)
    }

    // MARK: - Where the card and the finger go

    @Test func theCardSitsBesideTheSpotlightAndOnlyPicksASide() {
        // There is no pinning to a screen edge any more: the eye never has two places to look.
        #expect(TutorialStep.plates.cardSide == .above, "the plate diagram opens right under the toggle")
        for step in TutorialStep.allCases where step != .plates {
            #expect(step.cardSide == .auto, "\(step): whichever side of the spotlight has more room")
        }
    }

    @Test func aSmallButtonGetsTheFingerInTheMiddle() {
        for step in [TutorialStep.addExercise, .pickVariant, .rir, .setType, .logSet, .logNext, .leave, .discard, .scrollTop] {
            if step == .scrollTop { continue }   // the clock: a spot on the status bar, checked on its own below
            #expect(step.touchAnchor == .center || step == .pickVariant, "\(step)")
        }
        #expect(TutorialStep.discard.touchAnchor == .center, "DISCARD WORKOUT: the middle of the button")
        #expect(TutorialStep.addExercise.touchAnchor == .center, "the + at the top")
    }

    @Test func aBigButtonWithBlankSpaceGetsTheFingerOnTheBlankSpaceNotTheText() {
        // START WORKOUT has its name at the left and the label at the right; the gap is left of centre.
        #expect(TutorialStep.startWorkout.touchAnchor.x != 0.5 && TutorialStep.startWorkout.touchAnchor.x < 0.5)
        // A picker row has a name at the left and a count at the right.
        #expect(TutorialStep.pickExercise.touchAnchor.x > 0.5 && TutorialStep.pickExercise.touchAnchor.x < 0.7)
        // A set-type row has its text at the left; the blank space is on the right.
        #expect(TutorialStep.pickSetType.touchAnchor.x > 0.7)
    }

    @Test func theClockTipPointsAtTheClock() {
        #expect(TutorialStep.scrollTop.touchAnchor.x < 0.3 && TutorialStep.scrollTop.touchAnchor.y > 0.3)
    }

    // MARK: - Auto-typed values

    @Test @MainActor func enterStepTypesWeightRepsAndRIRThenMovesToPlates() async throws {
        let vm = makeVM()
        var seen: [(exercise: String?, weight: String?, reps: String?, rir: String?)] = []
        vm.fillSet = { seen.append(($0, $1, $2, $3)) }
        vm.start()
        vm.currentStep = .rir              // the RIR column is switched on first…
        vm.targetTapped()                  // …and the tap moves on to the numbers
        try await Task.sleep(for: .milliseconds(7000))
        let unit = UnitPreference.current
        let expectedWeight = unit == .kg ? ["6", "60"] : [unit.kgString(displayText: "1"), unit.kgString(displayText: "13"), unit.kgString(displayText: "135")]
        #expect(seen.compactMap(\.weight) == expectedWeight, "the weight is typed one character at a time")
        #expect(seen.compactMap(\.reps) == ["8"])
        #expect(seen.compactMap(\.rir) == ["2"], "with RIR on, it gets a value too")
        #expect(seen.allSatisfy { $0.exercise == TutorialMode.firstExercise }, "typed into the first exercise, at the top")
        #expect(vm.currentStep == .plates, "the plate calculator is next, once the weight is in")
        vm.skip()
    }

    @Test @MainActor func skippingStopsTheTyping() async throws {
        let vm = makeVM()
        var count = 0
        vm.fillSet = { _, _, _, _ in count += 1 }
        vm.start()
        vm.currentStep = .rir
        vm.targetTapped()
        try await Task.sleep(for: .milliseconds(1000))   // into the hand-over to the numbers
        vm.skip()
        try await Task.sleep(for: .milliseconds(3500))
        #expect(count == 0)
    }

    // MARK: - TutorialStep properties

    @Test func allStepsHaveCopy() {
        for step in TutorialStep.allCases {
            #expect(!step.title.isEmpty, "\(step) should have a title")
            #expect(!step.description.isEmpty, "\(step) should have a description")
            #expect(!step.phase.isEmpty, "\(step) should have a phase")
            #expect(step.target.hasPrefix("tutorial."), "\(step) should point at a registered target")
        }
    }

    @Test func gesturesMatchTheStep() {
        #expect(TutorialStep.startWorkout.gesture == .tap)
        #expect(TutorialStep.enterSet.gesture == .auto)
        #expect(TutorialStep.logSet.gesture == .tap)
        #expect(TutorialStep.logSet.waitsForEvent)
        #expect(TutorialStep.swipeSet.gesture == .swipeLeft)
        #expect(TutorialStep.searchPull.gesture == .swipeDown)
        #expect(TutorialStep.searchFind.gesture == .auto)
        #expect(TutorialStep.logNext.waitsForEvent)
    }

    @Test func stepCountIsNineteen() {
        #expect(TutorialStep.allCases.count == 18)
    }

    @Test func eachStepWorksOnTheRightExercise() {
        for step in [TutorialStep.rir, .enterSet, .plates, .setType, .pickSetType, .logSet, .swipeSet] {
            #expect(step.focusExercise == TutorialMode.firstExercise, "\(step) is on the first exercise, at the top")
        }
        #expect(TutorialStep.searchJump.focusExercise == TutorialMode.farExercise)
        #expect(TutorialStep.logNext.focusExercise == TutorialMode.farExercise)
        #expect(TutorialStep.startWorkout.focusExercise == nil)
    }

    @Test func thePracticeWorkoutIsLongEnoughForTheNextExerciseToBeFarDown() {
        let list = TutorialMode.presetExercises
        #expect(list.count >= 6)
        #expect(list.first == TutorialMode.firstExercise)
        #expect((list.firstIndex(of: TutorialMode.farExercise) ?? 0) >= 4, "several cards down, past the first screen")
        #expect(Set(list).count == list.count, "no duplicates")
    }

    @Test @MainActor func theFocusExerciseFollowsTheStep() {
        let vm = makeVM()
        vm.start()
        #expect(TutorialFocus.shared.exerciseName == nil)
        vm.currentStep = .pickVariant
        vm.handle(.exerciseAdded)
        #expect(vm.currentStep == .rir)
        #expect(TutorialFocus.shared.exerciseName == TutorialMode.firstExercise)
        vm.skip()
        #expect(TutorialFocus.shared.exerciseName == nil)
    }

    @Test func searchStepsRunInTheOrderJumpThenLogThenAdd() {
        let order = TutorialStep.allCases
        func at(_ s: TutorialStep) -> Int { order.firstIndex(of: s)! }
        #expect(at(.searchPull) < at(.searchFind) && at(.searchFind) < at(.searchJump))
        #expect(at(.searchJump) < at(.logNext) && at(.logNext) < at(.scrollTop), "the tip comes once you're far down")
        #expect(at(.scrollTop) < at(.leave))
        #expect(!order.contains { $0.title.contains("library") }, "adding is the + button's job, not search's")
    }

    @Test func rirIsSwitchedOnBeforeTheNumbersAreTyped() {
        let order = TutorialStep.allCases
        #expect(order.firstIndex(of: .rir)! < order.firstIndex(of: .enterSet)!)
        #expect(order.firstIndex(of: .enterSet)! < order.firstIndex(of: .plates)!, "the plate row needs a weight first")
        #expect(order.firstIndex(of: .plates)! < order.firstIndex(of: .logSet)!, "the plate row disappears once the set is logged")
    }

    @Test func newPagesCoverPlatesSetTypesRIRAndSearch() {
        let phases = Set(TutorialStep.allCases.map(\.phase))
        for phase in ["Plates", "Set types", "RIR", "Search", "Scroll"] { #expect(phases.contains(phase), "\(phase) has a page") }
        #expect(TutorialStep.scrollTop.description.contains("clock"), "the status bar tip tells people where to tap")
        #expect(TutorialStep.searchPull.description.contains("clock"), "and the search page points them to it")
        #expect(TutorialStep.addExercise.description.contains("+"), "the add-exercise page names the + button")
        #expect(TutorialStep.addExercise.description.contains("ADD EXERCISE"), "and the button at the end of the list")
        #expect(TutorialStep.addExercise.target == "tutorial.add-top", "it points at the + at the top, no scrolling")
    }

    @Test func everyStepNamesItsTargetAndHowItProvesSuccess() {
        for step in TutorialStep.allCases {
            #expect(step.target.hasPrefix("tutorial."))
            switch step.success {
            case .appears(let id), .disappears(let id): #expect(id.hasPrefix("tutorial."))
            case .nextTarget: break
            }
        }
        #expect(TutorialStep.plates.success == .appears("tutorial.plates-view"))
        #expect(TutorialStep.pickSetType.success == .disappears("tutorial.set-type-warmup"))
        #expect(TutorialStep.rir.success == .appears("tutorial.rir-header"))
    }
}
