import Foundation
import SwiftData

/// Which Firebase account the local data belongs to, and wiping it when that changes.
enum SyncAccount {
    static let lastUidKey = "sync.lastUid"

    static func lastUid(_ defaults: UserDefaults = .standard) -> String? { defaults.string(forKey: lastUidKey) }
    static func setLastUid(_ uid: String?, _ defaults: UserDefaults = .standard) {
        if let uid { defaults.set(uid, forKey: lastUidKey) } else { defaults.removeObject(forKey: lastUidKey) }
    }

    /// App Group keys that mirror personal data into widgets.
    private static let widgetKeys = [
        "widget_snapshot", "custom_widget_library", "widget_friends", "widget_streak", "widget_lastWorkoutName",
        "widget_lastWorkoutDate", "widget_exerciseCount", "widget_durationMinutes", "widget_recentWorkouts",
    ]

    /// Deletes everything the signed-in user created (workouts incl. drafts, templates, splits, equipment, custom
    /// exercises, profile, local social cache, bodyweight log, widget snapshot) and every sync cursor/flag.
    /// The exercise catalogue stays. Safe to call repeatedly.
    @MainActor
    static func wipe(_ ctx: ModelContext, defaults: UserDefaults = .standard, bodyweightDefaults: UserDefaults? = nil,
                     clearWidgetData: Bool = true) {
        // One by one (not batch `delete(model:)`): batch deletes leave stale instances that crash on access.
        func wipe<T: PersistentModel>(_ type: T.Type, _ predicate: Predicate<T>? = nil) {
            for obj in (try? ctx.fetch(FetchDescriptor<T>(predicate: predicate))) ?? [] { ctx.delete(obj) }
        }
        wipe(Workout.self)             // cascades to ExerciseLog -> SetLog
        wipe(User.self)
        wipe(WorkoutTemplate.self)
        wipe(EquipmentProfile.self)
        wipe(Split.self)
        wipe(Challenge.self)
        wipe(UserProfile.self)
        wipe(Exercise.self, #Predicate<Exercise> { $0.isCustom })
        try? ctx.save()

        BodyweightLog.clear(defaults: bodyweightDefaults)
        if clearWidgetData, let group = PumpWidgetStore.defaults { for k in widgetKeys { group.removeObject(forKey: k) } }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("sync.") { defaults.removeObject(forKey: key) }
    }
}
