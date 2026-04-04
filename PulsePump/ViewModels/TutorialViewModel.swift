import SwiftUI
import Observation

enum TutorialStep: Int, CaseIterable {
    case welcome = 0
    case startWorkout
    case addExercise
    case logSet
    case ghostText
    case restTimer
    case bodyMap
    case templates
    case warmupGenerator
    case complete

    var title: String {
        switch self {
        case .welcome: "Welcome to Pump"
        case .startWorkout: "Start a Workout"
        case .addExercise: "Add Exercises"
        case .logSet: "Log Your Sets"
        case .ghostText: "Ghost Text"
        case .restTimer: "Rest Timer"
        case .bodyMap: "Body Map"
        case .templates: "Templates"
        case .warmupGenerator: "Warmup Generator"
        case .complete: "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome: "Let's walk through the key features so you can get the most out of your training."
        case .startWorkout: "Tap here to begin logging. Start blank or pick a template."
        case .addExercise: "Search from 84+ exercises or create your own custom ones."
        case .logSet: "Enter weight and reps for each set, then tap the checkmark to complete it."
        case .ghostText: "Previous workout values appear as placeholders to guide your next session."
        case .restTimer: "A rest timer auto-starts between sets. Customize it in Settings."
        case .bodyMap: "See which muscles you've trained with a visual heatmap of your volume."
        case .templates: "Save your favorite workouts as templates for quick starts."
        case .warmupGenerator: "Get smart warmup sets calculated from your working weight."
        case .complete: "Start training! You can re-access this tutorial anytime from More > Tutorial."
        }
    }

    var icon: String {
        switch self {
        case .welcome: "hand.wave"
        case .startWorkout: "play.circle"
        case .addExercise: "plus.circle"
        case .logSet: "checkmark.circle"
        case .ghostText: "text.badge.star"
        case .restTimer: "timer"
        case .bodyMap: "figure.stand"
        case .templates: "list.bullet.clipboard"
        case .warmupGenerator: "flame"
        case .complete: "trophy"
        }
    }

    /// Which tab to navigate to for this step (nil = stay on current)
    var requiredTab: Int? {
        switch self {
        case .welcome, .complete: nil
        case .startWorkout, .ghostText, .restTimer: 2 // Home
        case .addExercise, .logSet: 2 // Home
        case .bodyMap: 3 // Body Map
        case .templates: 0 // Programs
        case .warmupGenerator: 4 // More
        }
    }
}

@MainActor
@Observable
class TutorialViewModel {
    var currentStep: TutorialStep = .welcome
    var isActive = false

    var progress: Double {
        let total = TutorialStep.allCases.count
        return Double(currentStep.rawValue) / Double(total - 1)
    }

    func start() {
        currentStep = .welcome
        isActive = true
    }

    func advance() {
        let allSteps = TutorialStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else {
            complete()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = allSteps[currentIndex + 1]
        }
    }

    func skip() {
        complete()
    }

    func complete() {
        withAnimation {
            isActive = false
        }
        UserDefaults.standard.set(false, forKey: "wantsTutorial")
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
    }
}
