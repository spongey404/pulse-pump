import Foundation
import ActivityKit

// WorkoutActivityAttributes is defined once in PumpShared/WorkoutActivityAttributes.swift.

@MainActor
class LiveActivityService {
    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private var lastState: WorkoutActivityAttributes.ContentState?
    private var lastRestOver = false

    func startLiveActivity(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutActivityAttributes(workoutName: workoutName, startTime: Date())
        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: 0,
            currentExercise: "Starting...",
            completedSets: 0,
            totalSets: 0,
            restSecondsRemaining: 0
        )
        lastState = initialState
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Live Activity not available — silently fail
        }
    }

    /// Pushes a new state. Skips the push when nothing visible changed (the live clocks tick on their own),
    /// and raises an alert (island auto-expands) the first time a state flips to rest-over.
    func updateLiveActivity(_ state: WorkoutActivityAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        guard state != lastState else { return }
        lastState = state

        let content = ActivityContent(state: state, staleDate: state.restEndDate)
        let nowOver = state.restOverSince != nil
        if nowOver && !lastRestOver {
            await activity.update(content, alertConfiguration: AlertConfiguration(
                title: "Rest done", body: "Log your next set", sound: .default))
        } else {
            await activity.update(content)
        }
        lastRestOver = nowOver
    }

    func endLiveActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: 0,
            currentExercise: "Complete",
            completedSets: 0,
            totalSets: 0,
            restSecondsRemaining: 0
        )
        await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .default)
        currentActivity = nil
        lastState = nil
        lastRestOver = false
    }
}
