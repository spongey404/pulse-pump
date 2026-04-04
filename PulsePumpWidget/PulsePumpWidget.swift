import WidgetKit
import SwiftUI

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let lastWorkoutName: String?
    let lastWorkoutDate: Date?
    let exerciseCount: Int
    let durationMinutes: Int
    let recentWorkouts: [RecentWorkoutInfo]
}

struct RecentWorkoutInfo {
    let name: String?
    let date: Date
    let exercises: Int
}

struct Provider: TimelineProvider {
    private let appGroupId = "group.com.pulse.PulsePump"

    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(
            date: Date(),
            currentStreak: 3,
            lastWorkoutName: "Push Day",
            lastWorkoutDate: Date(),
            exerciseCount: 6,
            durationMinutes: 45,
            recentWorkouts: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchEntry() -> WorkoutEntry {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return WorkoutEntry(date: Date(), currentStreak: 0, lastWorkoutName: nil, lastWorkoutDate: nil, exerciseCount: 0, durationMinutes: 0, recentWorkouts: [])
        }

        let streak = defaults.integer(forKey: "widget_streak")
        let lastWorkoutName = defaults.string(forKey: "widget_lastWorkoutName")
        let lastWorkoutDate = defaults.object(forKey: "widget_lastWorkoutDate") as? Date
        let exerciseCount = defaults.integer(forKey: "widget_exerciseCount")
        let durationMinutes = defaults.integer(forKey: "widget_durationMinutes")

        // Decode recent workouts
        var recentWorkouts: [RecentWorkoutInfo] = []
        if let data = defaults.data(forKey: "widget_recentWorkouts"),
           let decoded = try? JSONDecoder().decode([WidgetWorkoutData].self, from: data) {
            recentWorkouts = decoded.map {
                RecentWorkoutInfo(name: $0.name, date: $0.date, exercises: $0.exercises)
            }
        }

        return WorkoutEntry(
            date: Date(),
            currentStreak: streak,
            lastWorkoutName: lastWorkoutName,
            lastWorkoutDate: lastWorkoutDate,
            exerciseCount: exerciseCount,
            durationMinutes: durationMinutes,
            recentWorkouts: recentWorkouts
        )
    }
}

// Shared Codable struct for passing workout data via UserDefaults
struct WidgetWorkoutData: Codable {
    let name: String?
    let date: Date
    let exercises: Int
}

struct PulsePumpWidget: Widget {
    let kind: String = "PulsePumpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PulsePumpWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Pump")
        .description("Track your workout streak and recent sessions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
