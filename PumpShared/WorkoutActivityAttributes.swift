import Foundation
import ActivityKit

/// Single definition shared by the app and the widget extension (PumpShared is compiled into both).
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var currentExercise: String
        var completedSets: Int
        var totalSets: Int
        /// Seconds left at push time (0 when not resting).
        var restSecondsRemaining: Int
        /// Short uppercase name for the compact island ("BENCH").
        var exerciseShort: String = ""
        /// 1-based index of the next/current set within its exercise, and that exercise's set count.
        var setIndex: Int = 0
        var setCount: Int = 0
        /// Planned weight / reps for the next set ("82.5", "6"); empty when unknown.
        var nextWeight: String = ""
        var nextReps: String = ""
        var weightUnit: String = "KG"
        /// Live rest countdown: rest runs restStartDate...restEndDate.
        var restStartDate: Date? = nil
        var restEndDate: Date? = nil
        /// Set when rest finished and the user has not logged yet; counts up from here.
        var restOverSince: Date? = nil
        /// "80 × 6 · 80 × 6 · 80 × 5" from the previous session of this lift.
        var lastTime: String = ""
        var lastTimeDate: String = ""
    }

    var workoutName: String
    var startTime: Date
}
