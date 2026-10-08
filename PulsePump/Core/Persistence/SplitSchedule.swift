import Foundation
import SwiftData

/// Default weekly schedules for each split type, so `Split.days` is never empty for a user who
/// picked a split (reminders, weekly goals, program tiles and next-workout fallback read it).
/// `dayOfWeek` uses the `Calendar` convention: 1 = Sunday … 7 = Saturday. Labels match the
/// preset template names ("Push Day", "Upper Body", …) so they resolve to real templates.
enum SplitSchedule {
    private typealias Slot = (weekday: Int, label: String, type: String)

    static func defaultDays(for type: SplitType) -> [SplitDay] {
        let mon = 2, tue = 3, wed = 4, thu = 5, fri = 6, sat = 7
        let slots: [Slot]
        switch type {
        case .ppl, .pushPullLegs:
            slots = [(mon, "Push Day", "push"), (tue, "Pull Day", "pull"), (wed, "Leg Day", "legs"),
                     (thu, "Push Day", "push"), (fri, "Pull Day", "pull"), (sat, "Leg Day", "legs")]
        case .upperLower:
            slots = [(mon, "Upper Body", "upper"), (tue, "Lower Body", "lower"),
                     (thu, "Upper Body", "upper"), (fri, "Lower Body", "lower")]
        case .fullBody:
            slots = [(mon, "Full Body A", "full"), (wed, "Full Body B", "full"), (fri, "Full Body A", "full")]
        case .broSplit:
            slots = [(mon, "Chest Day", "chest"), (tue, "Back Day", "back"), (wed, "Shoulder Day", "shoulders"),
                     (thu, "Arm Day", "arms"), (fri, "Leg Day", "legs")]
        case .arnoldSplit:
            slots = [(mon, "Chest & Back", "chestBack"), (tue, "Shoulders & Arms", "shouldersArms"), (wed, "Leg Day", "legs"),
                     (thu, "Chest & Back", "chestBack"), (fri, "Shoulders & Arms", "shouldersArms"), (sat, "Leg Day", "legs")]
        case .torsoLimbs:
            slots = [(mon, "Torso", "torso"), (tue, "Limbs", "limbs"), (thu, "Torso", "torso"), (fri, "Limbs", "limbs")]
        case .custom:
            // A starting point the user can reshape: three non-consecutive training days.
            slots = [(mon, "Workout A", "custom"), (wed, "Workout B", "custom"), (fri, "Workout C", "custom")]
        case .none:
            slots = []
        }
        return slots.map { SplitDay(dayOfWeek: $0.weekday, label: $0.label, workoutType: $0.type) }
    }

    /// A new `Split` with its default schedule populated.
    static func makeSplit(type: SplitType) -> Split {
        Split(type: type, name: type.displayName, days: defaultDays(for: type))
    }

    /// Points `user` at `type`'s schedule: updates the existing split in place (no orphan rows)
    /// or creates one. `.none` clears the split.
    @discardableResult
    static func apply(type: SplitType, to user: User, modelContext: ModelContext) -> Split? {
        guard type != .none else {
            if let old = user.selectedSplit { modelContext.delete(old) }
            user.selectedSplit = nil
            return nil
        }
        if let split = user.selectedSplit {
            split.type = type
            split.name = type.displayName
            split.days = defaultDays(for: type)
            split.updatedAt = Date()
            return split
        }
        let split = makeSplit(type: type)
        modelContext.insert(split)
        user.selectedSplit = split
        return split
    }

    /// One-time repair: a user who has a split but no scheduled days gets the defaults.
    /// Idempotent; returns how many splits were filled.
    @discardableResult
    static func repairMissingDays(modelContext: ModelContext) -> Int {
        let splits = (try? modelContext.fetch(FetchDescriptor<Split>())) ?? []
        var repaired = 0
        for split in splits where split.days.isEmpty && split.type != .none {
            split.days = defaultDays(for: split.type)
            split.updatedAt = Date()
            repaired += 1
        }
        return repaired
    }
}
