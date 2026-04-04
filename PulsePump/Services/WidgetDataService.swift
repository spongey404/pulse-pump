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
        let streak = calculateStreak(from: workouts)
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

    private static func calculateStreak(from workouts: [Workout]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })

        if !workoutDays.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            if !workoutDays.contains(checkDate) { return 0 }
        }

        while workoutDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }
}

// DTO for encoding to UserDefaults (shared with widget via same key)
struct WidgetWorkoutDTO: Codable {
    let name: String?
    let date: Date
    let exercises: Int
}
