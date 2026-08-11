import SwiftUI

enum AppHint: String, CaseIterable, Identifiable {
    case startWorkout
    case addExercise
    case ghostText
    case restTimer
    case bodyMap
    case templates
    case plateCalculator
    case warmupGenerator
    case socialFeed
    case globalSearch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startWorkout: "Starting a Workout"
        case .addExercise: "Adding Exercises"
        case .ghostText: "Ghost Text"
        case .restTimer: "Rest Timer"
        case .bodyMap: "Body Map"
        case .templates: "Templates"
        case .plateCalculator: "Plate Calculator"
        case .warmupGenerator: "Warmup Generator"
        case .socialFeed: "Activity Feed"
        case .globalSearch: "Search"
        }
    }

    var message: String {
        switch self {
        case .startWorkout: "Tap the Start button to begin logging. The app predicts your next workout based on your training split."
        case .addExercise: "Tap the + button during a workout to add exercises on the fly. You can also drag to reorder them."
        case .ghostText: "Grey numbers next to empty fields show what you did last time. Just type over them with your new numbers."
        case .restTimer: "The rest timer starts automatically after you log a set. You can change this behavior in Settings."
        case .bodyMap: "Tap any muscle group to see exercises and trends. The heatmap shows your weekly training volume or recency."
        case .templates: "Create workout templates to quickly start your favorite routines. All templates are free."
        case .plateCalculator: "Enter your target weight and the calculator shows which plates to load per side."
        case .warmupGenerator: "Enter your working set weight to auto-generate a warmup ramp from the bar up."
        case .socialFeed: "Your workouts are automatically shared to the feed after completion. You can turn this off in Settings."
        case .globalSearch: "Search across exercises, workout history, and friends from the Home tab search icon."
        }
    }

    var icon: String {
        switch self {
        case .startWorkout: "play.circle"
        case .addExercise: "plus.circle"
        case .ghostText: "text.cursor"
        case .restTimer: "timer"
        case .bodyMap: "figure.stand"
        case .templates: "list.bullet.clipboard"
        case .plateCalculator: "scalemass"
        case .warmupGenerator: "flame"
        case .socialFeed: "person.2"
        case .globalSearch: "magnifyingglass"
        }
    }
}

struct HintButton: View {
    let hint: AppHint
    @State private var showHint = false

    var body: some View {
        Button {
            showHint = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.mono(11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showHint) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: hint.icon)
                        .foregroundStyle(Color.accentInk)
                    Text(hint.title)
                        .font(.mono(14, weight: .medium))
                }
                Text(hint.message)
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: 280)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// Inline hint label (tap to reveal/hide)
struct InlineHint: View {
    let hint: AppHint
    @State private var isRevealed = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isRevealed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.mono(11))
                    .foregroundStyle(.orange)
                Text(isRevealed ? hint.message : "Tap for a hint")
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(isRevealed ? nil : 1)
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
