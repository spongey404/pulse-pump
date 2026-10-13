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
        guard !Self.isVisiblyUnchanged(state, from: lastState) else { return }
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

    /// `elapsedSeconds` and `restSecondsRemaining` change every second but nothing renders them (the
    /// island and lock screen run their own clocks from the start/end dates), so they are ignored when
    /// deciding whether a push is needed; otherwise the dedupe never matched and ActivityKit was hit every second.
    static func isVisiblyUnchanged(_ new: WorkoutActivityAttributes.ContentState,
                                   from old: WorkoutActivityAttributes.ContentState?) -> Bool {
        guard let old else { return false }
        func normalised(_ s: WorkoutActivityAttributes.ContentState) -> WorkoutActivityAttributes.ContentState {
            var c = s
            c.elapsedSeconds = 0
            c.restSecondsRemaining = 0
            return c
        }
        return normalised(new) == normalised(old)
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
