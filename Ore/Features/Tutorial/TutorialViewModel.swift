import SwiftUI
import Observation

/// What the user has to do to move past a step.
nonisolated enum TutorialGesture: Equatable {
    /// Tap inside the spotlight; the real control underneath runs, then the tutorial moves on.
    case tap
    /// Swipe left starting inside the spotlight.
    case swipeLeft
    /// Drag down starting inside the spotlight (pulling the list down to search).
    case swipeDown
    /// The tutorial does it for the user (typing values in); touches are blocked meanwhile.
    case auto
    /// Tap the status bar (the clock, the very top edge): iOS scrolls the main list back to its top. The app
    /// reports when the list gets there.
    case statusTap

    var label: String {
        switch self {
        case .tap: "TAP"
        case .swipeLeft: "SWIPE LEFT"
        case .swipeDown: "PULL DOWN"
        case .auto: "WATCH"
        case .statusTap: "TAP THE CLOCK"
        }
    }
}

/// How a step proves the app acted on the user's touch, so a tap that missed the control can't move the tutorial on.
nonisolated enum TutorialSuccess: Equatable {
    /// The next step's target is on screen (the default).
    case nextTarget
    /// This target has appeared (a sheet opened, a column was added).
    case appears(String)
    /// This target has gone (a sheet closed).
    case disappears(String)
}

/// Which side of the spotlight the card prefers. The card always sits right beside the spotlight, so the eye
/// has one place to look; this only picks the side, to keep the card off whatever the tap will open.
nonisolated enum TutorialCardSide: Equatable {
    /// Whichever side of the spotlight has more room.
    case auto
    case above, below
}

/// Things the app reports to the tutorial.
enum TutorialEvent {
    case exerciseAdded
    case setCompleted
    /// The logger's list came back to its top after being scrolled well down.
    case scrolledToTop
}

extension Notification.Name {
    static let tutorialExerciseAdded = Notification.Name("tutorialExerciseAdded")
    static let tutorialSetCompleted = Notification.Name("tutorialSetCompleted")
    /// Posted by the logger when its list returns to the top after being scrolled well down.
    static let loggerScrolledToTop = Notification.Name("loggerScrolledToTop")
    /// Posted (object: String) while the tutorial types a search into the logger's search field.
    static let tutorialFillSearch = Notification.Name("tutorialFillSearch")
    /// Posted (object: target id) when the spotlight target is scrolled out of view, so its screen can scroll to it.
    static let tutorialRevealTarget = Notification.Name("tutorialRevealTarget")
}

/// A guided first workout on the real screens: a six-exercise practice workout, so the next exercise is
/// genuinely far down. Add one with the + and the picker, switch RIR on, log a set with plates and a
/// warm-up tag, swipe it, then use search: jump to an exercise already far down the list and log it
/// without scrolling, and tap the clock to get back to the top. The practice workout is discarded at the
/// end, so nothing from the tutorial reaches History.
enum TutorialStep: Int, CaseIterable {
    case startWorkout = 0
    case addExercise
    case pickExercise
    case pickVariant
    case rir
    case enterSet
    case plates
    case setType
    case pickSetType
    case logSet
    case swipeSet
    case searchPull
    case searchFind
    case searchJump
    case logNext
    case scrollTop
    case leave
    case discard

    var phase: String {
        switch self {
        case .startWorkout: "Start"
        case .addExercise, .pickExercise, .pickVariant: "Add"
        case .enterSet, .logSet, .swipeSet: "Logging"
        case .plates: "Plates"
        case .setType, .pickSetType: "Set types"
        case .rir: "RIR"
        case .searchPull, .searchFind, .searchJump, .logNext: "Search"
        case .scrollTop: "Scroll"
        case .leave, .discard: "Finish"
        }
    }

    var title: String {
        switch self {
        case .startWorkout: "Start a workout"
        case .addExercise: "Add an exercise"
        case .pickExercise: "Pick a lift"
        case .pickVariant: "Choose a variant"
        case .rir: "Reps in reserve"
        case .enterSet: "Enter your numbers"
        case .plates: "Plate calculator"
        case .setType: "Set types"
        case .pickSetType: "Mark a warm-up"
        case .logSet: "Log the set"
        case .swipeSet: "Swipe to delete"
        case .searchPull: "Search your workout"
        case .searchFind: "Type to find it"
        case .searchJump: "Jump to it"
        case .logNext: "Log it, no scrolling"
        case .scrollTop: "Back to the top"
        case .leave: "Leave a workout"
        case .discard: "Discard this practice run"
        }
    }

    var description: String {
        switch self {
        case .startWorkout: "Tap START WORKOUT. This practice workout has six exercises, like a real session."
        case .addExercise: "Tap + at the top to add an exercise without scrolling to the bottom. The ADD EXERCISE button at the end of the list does the same."
        case .pickExercise: "Tap the first lift. Lifts with several versions open a list to choose from."
        case .pickVariant: "Tap ADD on the version you're doing today."
        case .rir: "RIR is how many reps you had left in the tank. Tap RIR on the first exercise to add a column for it."
        case .enterSet: "Type the weight and reps, and with RIR on, how many reps you had left. We'll fill these in for you this time."
        case .plates: "On barbell lifts, tap PLATES to see which plates to load on each side for this weight."
        case .setType: "Tap the + chip on a set to change its type: warm-up, drop set, to failure and more."
        case .pickSetType: "Tap Warmup. Warm-ups are saved but left out of your volume and PRs."
        case .logSet: "Tap the circle to log it. The rest timer starts on its own."
        case .swipeSet: "Swipe the set to the left to reveal delete."
        case .searchPull: "Your next exercise is way down the list. Pull down from the top of the list to search it instead of scrolling. (Further down? Tap the clock first; we'll show you.)"
        case .searchFind: "The keyboard stays away here so you can see the results. Any word in the name works; we'll type \"row\" for you."
        case .searchJump: "Tap Barbell Row under IN YOUR WORKOUT to jump straight to it."
        case .logNext: "You're right at it. We've filled in the set, so tap the circle to log it."
        case .scrollTop: "Tap the clock at the very top of the screen to scroll straight back up. Handy before you pull down to search again."
        case .leave: "Tap the back arrow to leave. You can save a draft or discard."
        case .discard: "Tap DISCARD WORKOUT. Nothing from this tutorial is saved."
        }
    }

    var gesture: TutorialGesture {
        switch self {
        case .enterSet, .searchFind: .auto
        case .swipeSet: .swipeLeft
        case .searchPull: .swipeDown
        case .scrollTop: .statusTap
        default: .tap
        }
    }

    /// The tap only counts once the app reports the result (a set logged), not when the touch lands.
    var waitsForEvent: Bool { self == .logSet || self == .logNext || self == .scrollTop }

    /// `.tutorialTarget(_:)` id of the control to spotlight.
    var target: String {
        switch self {
        case .startWorkout: "tutorial.start-workout"
        case .addExercise: "tutorial.add-top"
        case .pickExercise: "tutorial.picker-first-row"
        case .pickVariant: "tutorial.variant-add"
        case .enterSet, .swipeSet: "tutorial.set-row"
        case .plates: "tutorial.plates-toggle"
        case .setType: "tutorial.set-type-chip"
        case .pickSetType: "tutorial.set-type-warmup"
        case .rir: "tutorial.rir-toggle"
        case .logSet, .logNext: "tutorial.set-check"
        case .searchPull: "tutorial.pull-zone"
        case .searchFind: "tutorial.search-panel"
        case .searchJump: "tutorial.search-workout-result"
        case .scrollTop: TutorialTargets.statusBarID
        case .leave: "tutorial.logger-back"
        case .discard: "tutorial.modal-primary"
        }
    }

    /// How the app proves a touch worked. The default is that the next step's target shows up.
    var success: TutorialSuccess {
        switch self {
        case .plates: .appears("tutorial.plates-view")
        case .setType: .appears("tutorial.set-type-warmup")
        case .pickSetType: .disappears("tutorial.set-type-warmup")
        case .rir: .appears("tutorial.rir-header")
        case .searchPull: .appears("tutorial.search-field")
        case .searchJump: .disappears("tutorial.search-field")
        default: .nextTarget
        }
    }

    /// Steps whose result opens right next to the spotlight keep the card out of its way.
    var cardSide: TutorialCardSide {
        switch self {
        case .plates: .above   // the plate diagram opens right under the toggle
        default: .auto
        }
    }

    /// A control inside the spotlight the finger should land on exactly, when the spotlight is bigger
    /// than the thing to touch (the swipe starts on the check circle, the spotlight is the whole row).
    var touchTarget: String? {
        self == .swipeSet ? "tutorial.set-check" : nil
    }

    /// Which exercise's row the walkthrough is on (matched by name), for steps that work on one row.
    var focusExercise: String? {
        switch self {
        case .rir, .enterSet, .plates, .setType, .pickSetType, .logSet, .swipeSet: TutorialMode.firstExercise
        case .searchJump, .logNext: TutorialMode.farExercise
        default: nil
        }
    }

    /// Where the finger lands, as a fraction of the spotlight, always on the control itself. The rule: dead
    /// centre on a small button (the finger is see-through, so the label stays readable), and in the blank
    /// space beside the text on a big button that has some (START WORKOUT, a picker row). Any tap inside the
    /// spotlight still counts.
    var touchAnchor: UnitPoint {
        switch self {
        case .startWorkout: UnitPoint(x: 0.42, y: 0.5)    // gap between "LEG DAY" and "START WORKOUT"
        case .addExercise: .center                        // the + at the top
        case .pickExercise: UnitPoint(x: 0.58, y: 0.5)    // between the lift name and "3 VARIANTS"
        case .pickVariant: .center                        // right on the ADD button (the finger is see-through)
        case .enterSet: .center
        case .plates: .center                             // between "PLATES · 60KG" and "SHOW"
        case .setType: .center                            // the small + chip
        case .pickSetType: UnitPoint(x: 0.78, y: 0.5)     // right of "Warmup / Excluded from volume"
        case .rir: .center
        case .logSet, .logNext: .center                   // the circle has no text
        case .swipeSet: UnitPoint(x: 0.9, y: 0.5)         // over the check, with room to slide left
        case .searchPull: UnitPoint(x: 0.5, y: 0.08)      // the top of the list: the pull starts here and slides down the whole zone
        case .searchFind: .center
        case .searchJump: UnitPoint(x: 0.55, y: 0.5)      // between the name and "JUMP"
        case .scrollTop: UnitPoint(x: 0.17, y: 0.55)      // on the clock
        case .leave: .center                              // on the back arrow
        case .discard: .center                            // the middle of the button
        }
    }
}

/// While the tutorial runs: the Home button starts a fixed six-exercise practice workout (not the
/// weekday's program, so every step finds what it expects), and the steps know which exercise's row
/// they are working on.
@MainActor
enum TutorialMode {
    static var isRunning = false

    /// The practice workout, in order. The first is where the logging steps happen; the one far down
    /// is what search jumps to.
    static let presetExercises = ["Barbell Bench Press", "Overhead Press", "Lat Pulldown", "Leg Press", "Barbell Row", "Lateral Raise"]
    nonisolated static let firstExercise = "Barbell Bench Press"
    nonisolated static let farExercise = "Barbell Row"
}

/// The exercise (by name) whose set row the tutorial's targets are attached to right now. Observed, so the
/// cards re-tag when it changes.
@MainActor
@Observable
final class TutorialFocus {
    static let shared = TutorialFocus()
    var exerciseName: String?
    /// The current step is a drag (the pull down): taps on the screen's controls are switched off so only a drag counts.
    var dragOnly = false
}

@MainActor
@Observable
class TutorialViewModel {
    var currentStep: TutorialStep = .startWorkout
    var isActive = false
    /// All steps done: show the "YOU'RE ALL SET." screen.
    var isFinished = false
    /// The tutorial opened a practice workout that must not outlive it.
    private(set) var startedPracticeWorkout = false
    /// True from the moment the user acts until the next step shows: the overlay fades the card out.
    private(set) var isTransitioning = false
    /// Pacing, slow enough to read each card: how long the old card stays gone before the next step
    /// shows, and how the practice set is typed.
    private enum Pace {
        static let handOver: Duration = .milliseconds(750)
        static let afterLog: Duration = .milliseconds(700)
        static let readBeforeTyping: Duration = .milliseconds(1800)
        static let readBeforeSearch: Duration = .milliseconds(900)
        static let perCharacter: Duration = .milliseconds(140)
        static let beforeReps: Duration = .milliseconds(180)
        static let holdAfterTyping: Duration = .milliseconds(1000)
    }
    /// An `advance(after:)` is pending; it clears `isTransitioning` itself.
    private var advancing = false
    /// Whether the app did what a finished step asked for (see `TutorialStep.success`). Replaced in tests,
    /// which have no screen.
    @ObservationIgnored var didSucceed: (TutorialStep) -> Bool = TutorialViewModel.screenShowsResult
    @ObservationIgnored var readyTimeout: Duration = .seconds(3)
    /// Fills the weight (kg string), reps and/or RIR of the first set of the named exercise; set by the screen
    /// that owns the workout.
    @ObservationIgnored var fillSet: ((_ exercise: String?, _ weight: String?, _ reps: String?, _ rir: String?) -> Void)?
    @ObservationIgnored private var typingTask: Task<Void, Never>?

    /// The real check: look for the step's result among the registered targets.
    static func screenShowsResult(_ step: TutorialStep) -> Bool {
        let targets = TutorialTargets.shared
        switch step.success {
        case .appears(let id): return targets.frame(id) != nil
        case .disappears(let id): return targets.frame(id) == nil
        case .nextTarget:
            let all = TutorialStep.allCases
            guard let i = all.firstIndex(of: step), i + 1 < all.count else { return true }
            return targets.frame(all[i + 1].target) != nil
        }
    }
    /// Owns the overlay window; created on first use.
    @ObservationIgnored lazy var presenter = TutorialPresenter(viewModel: self)

    var progress: Double {
        Double(currentStep.rawValue) / Double(TutorialStep.allCases.count - 1)
    }

    /// This run is the first-run tutorial (started by onboarding), whose end leads to the Supernova paywall. A
    /// replay from More › Tutorial ends on the normal done screen instead.
    private(set) var isFirstRun = false

    func start(firstRun: Bool = false) {
        isFirstRun = firstRun
        typingTask?.cancel()
        isTransitioning = false
        currentStep = .startWorkout
        isFinished = false
        startedPracticeWorkout = false
        TutorialFocus.shared.exerciseName = nil
        TutorialFocus.shared.dragOnly = false
        isActive = true
        TutorialMode.isRunning = true
    }

    func advance() {
        let all = TutorialStep.allCases
        if currentStep == .startWorkout { startedPracticeWorkout = true }
        guard let i = all.firstIndex(of: currentStep), i + 1 < all.count else {
            if isFirstRun, SupernovaPaywallGate.shouldShowNow() {
                // The old "You're all set" screen is replaced by the paywall, presented by ContentView.
                complete()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { isFinished = true }
            }
            return
        }
        go(to: all[i + 1])
    }

    func skip() { complete() }

    func complete() {
        typingTask?.cancel()
        isTransitioning = false
        TutorialMode.isRunning = false
        TutorialFocus.shared.exerciseName = nil
        withAnimation {
            isActive = false
            isFinished = false
        }
        UserDefaults.standard.set(false, forKey: "wantsTutorial")
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
        // The end of the first-run tutorial (finished or skipped) leads to the Supernova paywall, once.
        if isFirstRun {
            isFirstRun = false
            if SupernovaPaywallGate.shouldShowNow() {
                NotificationCenter.default.post(name: .showSupernovaPaywall, object: nil)
            }
        }
    }

    // MARK: Input from the overlay window

    /// The user tapped inside the spotlight. The tap already reached the real control; give the
    /// screen a moment to react, then move on if the step is still the one that was tapped.
    func targetTapped() {
        guard isActive, !isFinished, currentStep.gesture == .tap else { return }
        if currentStep.waitsForEvent {
            // The tap only counts once the app reports it (a set logged). If nothing happens, bring the card back.
            releaseIfStill(currentStep, after: .milliseconds(900))
        } else {
            advance(after: currentStep)
        }
    }

    /// A finger landed in the spotlight of a tap step. Start handing over now, so the old card is
    /// already gone when the next screen starts moving.
    func touchBegan() {
        guard isActive, !isFinished, currentStep.gesture == .tap else { return }
        isTransitioning = true
    }

    /// The touch turned out not to be the tap (it moved, was cancelled, or ended elsewhere).
    func touchAbandoned() {
        guard isActive, !isFinished else { return }
        releaseIfStill(currentStep, after: .milliseconds(150))
    }

    private func releaseIfStill(_ step: TutorialStep, after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, self.currentStep == step, self.isActive else { return }
            // A real advance is already on its way when its own task still owns the flag.
            if !self.advancing { self.isTransitioning = false }
        }
    }

    /// The user swiped inside the spotlight in `direction` (`.swipeLeft` or `.swipeDown`).
    func targetSwiped(_ direction: TutorialGesture = .swipeLeft) {
        guard isActive, !isFinished, currentStep.gesture == direction else { return }
        advance(after: currentStep)
    }

    func handle(_ event: TutorialEvent) {
        guard isActive, !isFinished else { return }
        switch (event, currentStep) {
        case (.exerciseAdded, .pickExercise), (.exerciseAdded, .pickVariant), (.exerciseAdded, .addExercise):
            // A lift with no variants is added by the first tap, so the variant step is skipped.
            go(to: .rir)
        case (.scrolledToTop, .scrollTop):
            advance(after: .scrollTop, delay: Pace.afterLog)
        case (.setCompleted, .logSet):
            // Put the number pad away so the remaining steps have the whole screen.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            advance(after: .logSet, delay: Pace.afterLog)
        case (.setCompleted, .logNext):
            advance(after: .logNext, delay: Pace.afterLog)
        default:
            break
        }
    }

    private func go(to step: TutorialStep) {
        // New step first, then end the hand-over: the other way round shows the old step for a frame.
        TutorialFocus.shared.exerciseName = step.focusExercise
        TutorialFocus.shared.dragOnly = step.gesture == .swipeDown
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = step }
        isTransitioning = false
        // The keyboard is out of bounds (only the spotlight is touchable), so put it away once the tutorial
        // has finished typing and it is the user's turn.
        if step.gesture != .auto {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        runAutomation(for: step)
    }

    private func advance(after step: TutorialStep, delay: Duration = Pace.handOver) {
        isTransitioning = true
        advancing = true
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            // A touch near the target is not proof the app acted on it. Move on only once the screen shows
            // the result; otherwise it was a miss, and the same card comes back.
            if self.isActive, self.currentStep == step, await self.screenShowsResult(of: step) { self.advance() }
            self.advancing = false
            self.isTransitioning = false
        }
    }

    /// True once the app shows what `step` asked for (polled for `readyTimeout`).
    private func screenShowsResult(of step: TutorialStep) async -> Bool {
        let deadline = ContinuousClock.now + readyTimeout
        while ContinuousClock.now < deadline {
            if didSucceed(step) { return true }
            try? await Task.sleep(for: .milliseconds(100))
            if !isActive || currentStep != step { return false }
        }
        return didSucceed(step)
    }

    /// Steps the tutorial performs for the user.
    private func runAutomation(for step: TutorialStep) {
        switch step {
        case .enterSet: typeIntoSet()
        case .searchFind: typeSearch("row", during: .searchFind)
        case .logNext: prefillNextSet()
        default: break
        }
    }

    /// The exercise jumped to gets its set filled in at once (40 × 10), so the user only has to tap the circle.
    private func prefillNextSet() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, self.currentStep == .logNext else { return }
            let unit = UnitPreference.current
            let weight = unit == .kg ? "40" : "85"
            self.fillSet?(TutorialMode.farExercise, unit.kgString(displayText: weight), "10", nil)
        }
    }

    /// Types `text` into the logger's search field, one character at a time, then moves on.
    private func typeSearch(_ text: String, during step: TutorialStep) {
        typingTask?.cancel()
        typingTask = Task { [weak self] in
            func pause(_ d: Duration) async { try? await Task.sleep(for: d) }
            await pause(Pace.readBeforeSearch)
            for n in 1...text.count {
                guard let self, !Task.isCancelled, self.currentStep == step else { return }
                NotificationCenter.default.post(name: .tutorialFillSearch, object: String(text.prefix(n)))
                await pause(Pace.perCharacter)
            }
            await pause(Pace.holdAfterTyping)   // let the user see the results
            guard let self, !Task.isCancelled, self.currentStep == step else { return }
            self.advance(after: step, delay: .milliseconds(0))
        }
    }

    /// Types "60 × 8" (135 in lb) and RIR 2 into the practice set one character at a time, so the user
    /// watches the values appear and only has to tap the circle.
    private func typeIntoSet() {
        typingTask?.cancel()
        typingTask = Task { [weak self] in
            func pause(_ d: Duration) async { try? await Task.sleep(for: d) }
            await pause(Pace.readBeforeTyping)   // time to read the card before anything moves
            let unit = UnitPreference.current
            let weightText = unit == .kg ? "60" : "135"
            for n in 1...weightText.count {
                guard let self, !Task.isCancelled, self.currentStep == .enterSet else { return }
                self.fillSet?(TutorialMode.firstExercise, unit.kgString(displayText: String(weightText.prefix(n))), nil, nil)
                await pause(Pace.perCharacter)
            }
            await pause(Pace.beforeReps)
            guard let self, !Task.isCancelled, self.currentStep == .enterSet else { return }
            self.fillSet?(TutorialMode.firstExercise, nil, "8", nil)
            await pause(Pace.beforeReps)
            guard !Task.isCancelled, self.currentStep == .enterSet else { return }
            self.fillSet?(TutorialMode.firstExercise, nil, nil, "2")   // RIR is on by now, so it gets a value too
            await pause(Pace.holdAfterTyping)   // let the user see the finished row
            guard !Task.isCancelled, self.currentStep == .enterSet else { return }
            self.advance(after: .enterSet, delay: .milliseconds(0))
        }
    }
}
