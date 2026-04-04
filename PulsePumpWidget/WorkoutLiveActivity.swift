import ActivityKit
import WidgetKit
import SwiftUI

// Mirrors WorkoutActivityAttributes in the main app — must stay in sync.
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var currentExercise: String
        var completedSets: Int
        var totalSets: Int
        var restSecondsRemaining: Int
    }

    var workoutName: String
    var startTime: Date
}

// MARK: - Formatted helpers

private func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%d:%02d", m, s)
}

// MARK: - Live Activity Widget

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen / StandBy banner
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.workoutName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if context.state.restSecondsRemaining > 0 {
                        Text(formatDuration(context.state.restSecondsRemaining))
                            .font(.title2.monospacedDigit().weight(.bold))
                            .foregroundStyle(.red)
                    } else {
                        Text(formatDuration(context.state.elapsedSeconds))
                            .font(.title2.monospacedDigit().weight(.bold))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if context.state.restSecondsRemaining > 0 {
                        Text("Rest")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    } else {
                        Text(context.state.currentExercise)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    if context.state.totalSets > 0 {
                        Text("\(context.state.completedSets)/\(context.state.totalSets) sets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(.systemBackground))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long press)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.workoutName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if context.state.restSecondsRemaining > 0 {
                            Text(formatDuration(context.state.restSecondsRemaining))
                                .font(.title3.monospacedDigit().weight(.bold))
                                .foregroundStyle(.red)
                        } else {
                            Text(formatDuration(context.state.elapsedSeconds))
                                .font(.title3.monospacedDigit().weight(.bold))
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.totalSets > 0 {
                            Text("\(context.state.completedSets)/\(context.state.totalSets)")
                                .font(.title3.weight(.bold))
                            Text("sets done")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(context.state.currentExercise)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.restSecondsRemaining > 0 ? "timer" : "dumbbell.fill")
                    .font(.caption2)
                    .foregroundStyle(context.state.restSecondsRemaining > 0 ? .red : .white)
            } compactTrailing: {
                if context.state.restSecondsRemaining > 0 {
                    Text(formatDuration(context.state.restSecondsRemaining))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.red)
                } else {
                    Text(formatDuration(context.state.elapsedSeconds))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                }
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .font(.caption2)
            }
            .keylineTint(.orange)
        }
    }
}
