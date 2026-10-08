import SwiftUI
import Observation

/// The 10-step walkthrough from the Tutorial design (tutorial-engine.jsx), grouped in four phases.
enum TutorialStep: Int, CaseIterable {
    case gymProfile = 0
    case plates
    case restTimerDefaults
    case pickTemplate
    case addExercise
    case pickVariant
    case ghostText
    case logSet
    case plateCalculator
    case summary

    var phase: String {
        switch self {
        case .gymProfile, .plates, .restTimerDefaults: "Equipment"
        case .pickTemplate, .addExercise, .pickVariant: "Programs"
        case .ghostText, .logSet, .plateCalculator: "Workout Logger"
        case .summary: "Post-Workout"
        }
    }

    var title: String {
        switch self {
        case .gymProfile: "Gym Profile"
        case .plates: "Your Plates"
        case .restTimerDefaults: "Rest Timer Defaults"
        case .pickTemplate: "Pick a Template"
        case .addExercise: "Add an Exercise"
        case .pickVariant: "Pick a Variant"
        case .ghostText: "Ghost Text"
        case .logSet: "Log a Set"
        case .plateCalculator: "Plate Calculator"
        case .summary: "Post-Workout Summary"
        }
    }

    var description: String {
        switch self {
        case .gymProfile: "Pick Commercial or Home Gym. Each profile carries its own plate inventory and available bars."
        case .plates: "This is what the active profile owns. The plate calculator only ever suggests these."
        case .restTimerDefaults: "Set defaults by movement type. Compound gets more rest than isolation. Override per exercise on the second tab."
        case .pickTemplate: "Start from a preset or build from scratch. Everything is editable after."
        case .addExercise: "Tap an exercise to open its variants. Bench Press splits by angle first, then by equipment."
        case .pickVariant: "Pick the angle, then the equipment. Flat Barbell and Flat Dumbbell track separately."
        case .ghostText: "Faint values are what you lifted last time. You always enter your own number."
        case .logSet: "Enter weight and reps. Tap the circle to complete. Rest timer starts automatically."
        case .plateCalculator: "Tap the plates row to see exactly what to load. The profile chip shows which gym setup is active."
        case .summary: "Stats, volume by muscle, and any new PRs, generated after every session. Share to the feed or keep it private."
        }
    }

    /// Button label; the design's last step reads "Start Training →".
    var cta: String { self == .summary ? "Start Training →" : "Got it →" }

    /// `.tutorialTarget(_:)` id of the view to spotlight. Steps whose screen isn't reachable
    /// in the live app (or has no anchor yet) dim the screen and show the card alone, as the
    /// design does when the target can't be measured.
    var target: String? {
        switch self {
        case .gymProfile: "profile-toggle"
        case .plates: "plate-grid"
        case .restTimerDefaults: "rest-movement-defaults"
        default: nil
        }
    }

    /// Which tab hosts this step.
    var requiredTab: Int {
        switch self {
        case .gymProfile, .plates, .restTimerDefaults: 4   // More
        case .pickTemplate, .addExercise, .pickVariant: 0   // Programs
        case .ghostText, .logSet, .plateCalculator, .summary: 2 // Home
        }
    }

    /// Sub-screen of the More tab to open (nil = hub).
    var moreScreen: String? {
        switch self {
        case .gymProfile, .plates: "equipment"
        case .restTimerDefaults: "settings"
        default: nil
        }
    }
}

@MainActor
@Observable
class TutorialViewModel {
    var currentStep: TutorialStep = .gymProfile
    var isActive = false
    /// All ten steps seen — show the "YOU'RE ALL SET." screen.
    var isFinished = false

    var progress: Double {
        Double(currentStep.rawValue) / Double(TutorialStep.allCases.count - 1)
    }

    func start() {
        currentStep = .gymProfile
        isFinished = false
        isActive = true
    }

    func advance() {
        let all = TutorialStep.allCases
        guard let i = all.firstIndex(of: currentStep), i + 1 < all.count else {
            withAnimation(.easeInOut(duration: 0.2)) { isFinished = true }
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = all[i + 1] }
    }

    func skip() { complete() }

    func complete() {
        withAnimation {
            isActive = false
            isFinished = false
        }
        UserDefaults.standard.set(false, forKey: "wantsTutorial")
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
    }
}
