import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var currentExercise: String
        var completedSets: Int
        var totalSets: Int
    }

    var workoutName: String
    var startTime: Date
}

@MainActor
class LiveActivityService {
    private var currentActivity: Activity<WorkoutActivityAttributes>?

    func startLiveActivity(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutActivityAttributes(
            workoutName: workoutName,
            startTime: Date()
        )
        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: 0,
            currentExercise: "Starting...",
            completedSets: 0,
            totalSets: 0
        )
        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activity not available — silently fail
        }
    }

    func updateLiveActivity(elapsedSeconds: Int, currentExercise: String, completedSets: Int, totalSets: Int) async {
        guard let activity = currentActivity else { return }

        let updatedState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            currentExercise: currentExercise,
            completedSets: completedSets,
            totalSets: totalSets
        )
        let content = ActivityContent(state: updatedState, staleDate: nil)
        await activity.update(content)
    }

    func endLiveActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: 0,
            currentExercise: "Complete",
            completedSets: 0,
            totalSets: 0
        )
        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .default)
        currentActivity = nil
    }
}
