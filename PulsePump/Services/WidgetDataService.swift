import Foundation
import SwiftData
import WidgetKit

struct WidgetDataService {
    private static let appGroupId = "group.com.pulse.PulsePump"

    static func updateWidgetData(modelContext: ModelContext) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isDraft },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let workouts = try? modelContext.fetch(descriptor) else { return }

        // Streak
        let streak = StreakCalculator.currentStreak(from: workouts.map(\.date))
        defaults.set(streak, forKey: "widget_streak")

        // Last workout
        if let last = workouts.first {
            defaults.set(last.template?.name ?? "Workout", forKey: "widget_lastWorkoutName")
            defaults.set(last.date, forKey: "widget_lastWorkoutDate")
            defaults.set(last.exerciseLogs.count, forKey: "widget_exerciseCount")
            defaults.set(Int(last.duration / 60), forKey: "widget_durationMinutes")
        }

        // Recent workouts
        let recent = workouts.prefix(3).map {
            WidgetWorkoutDTO(name: $0.template?.name, date: $0.date, exercises: $0.exerciseLogs.count)
        }
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: "widget_recentWorkouts")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }


}

// DTO for encoding to UserDefaults (shared with widget via same key)
struct WidgetWorkoutDTO: Codable {
    let name: String?
    let date: Date
    let exercises: Int
}
