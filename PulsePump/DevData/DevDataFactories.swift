#if DEBUG
import Foundation
import SwiftData

// Factories for the dev dataset. Pure model builders — nothing here touches the context except
// `insert`, so they can be reused by tests and previews.

/// One lift in a template, with how its working weight progresses over the history window.
struct DevLift {
    var name: String
    /// Top working weight in week 0 (oldest week), kg.
    var startKg: Double
    var stepKg: Double
    var stepEveryWeeks: Int
    var sets: Int
    var reps: ClosedRange<Int>
    var compound: Bool
    var warmups = false
}

enum DevDay: String, CaseIterable {
    case push = "Push Day", pull = "Pull Day", legs = "Leg Day"

    var lifts: [DevLift] {
        switch self {
        case .push: [
            DevLift(name: "Barbell Bench Press", startKg: 80, stepKg: 2.5, stepEveryWeeks: 2, sets: 4, reps: 5...8, compound: true, warmups: true),
            DevLift(name: "Overhead Press", startKg: 45, stepKg: 1.25, stepEveryWeeks: 2, sets: 3, reps: 6...10, compound: true),
            DevLift(name: "Incline Dumbbell Bench Press", startKg: 26, stepKg: 2, stepEveryWeeks: 3, sets: 3, reps: 8...12, compound: false),
            DevLift(name: "Lateral Raise", startKg: 10, stepKg: 1, stepEveryWeeks: 4, sets: 3, reps: 12...15, compound: false),
            DevLift(name: "Tricep Pushdown", startKg: 30, stepKg: 2.5, stepEveryWeeks: 3, sets: 3, reps: 10...13, compound: false),
        ]
        case .pull: [
            DevLift(name: "Weighted Pull Up", startKg: 5, stepKg: 2.5, stepEveryWeeks: 3, sets: 4, reps: 6...8, compound: true),
            DevLift(name: "Barbell Row", startKg: 62.5, stepKg: 2.5, stepEveryWeeks: 2, sets: 4, reps: 6...9, compound: true, warmups: true),
            DevLift(name: "Lat Pulldown", startKg: 65, stepKg: 2.5, stepEveryWeeks: 3, sets: 3, reps: 8...12, compound: false),
            DevLift(name: "Face Pull", startKg: 22.5, stepKg: 2.5, stepEveryWeeks: 4, sets: 3, reps: 12...15, compound: false),
            DevLift(name: "Barbell Curl", startKg: 32.5, stepKg: 2.5, stepEveryWeeks: 4, sets: 3, reps: 8...12, compound: false),
        ]
        case .legs: [
            DevLift(name: "Barbell Squat", startKg: 90, stepKg: 5, stepEveryWeeks: 2, sets: 4, reps: 5...7, compound: true, warmups: true),
            DevLift(name: "Romanian Deadlift", startKg: 80, stepKg: 2.5, stepEveryWeeks: 2, sets: 3, reps: 8...10, compound: true),
            DevLift(name: "Leg Press", startKg: 140, stepKg: 5, stepEveryWeeks: 2, sets: 3, reps: 10...12, compound: false),
            DevLift(name: "Leg Curl", startKg: 45, stepKg: 2.5, stepEveryWeeks: 3, sets: 3, reps: 10...14, compound: false),
            DevLift(name: "Standing Calf Raise", startKg: 60, stepKg: 2.5, stepEveryWeeks: 3, sets: 4, reps: 12...16, compound: false),
        ]
        }
    }

    /// Weekday (1 = Sun … 7 = Sat, `Calendar` convention) → day. Push/Pull/Legs twice a week.
    static let schedule: [Int: DevDay] = [2: .push, 3: .pull, 4: .legs, 6: .push, 7: .pull, 1: .legs]
}

enum DevDataFactory {
    // MARK: User

    static func user(units: UnitPreference) -> User {
        User(name: "Dev Lifter", username: "dev_lifter", weight: 82.4, height: 181, age: 28,
             gender: .male, unitPreference: units, experienceLevel: .intermediate)
    }

    // MARK: Split (days populated, so reminders / goals / programs have a schedule)

    static func split() -> Split {
        let days = DevDay.schedule.sorted { ($0.key + 5) % 7 < ($1.key + 5) % 7 }   // Mon-first
            .map { SplitDay(dayOfWeek: $0.key, label: $0.value.rawValue, workoutType: $0.value.rawValue) }
        return Split(type: .ppl, name: "Push Pull Legs", days: days)
    }

    // MARK: Equipment

    static func equipmentProfiles() -> [EquipmentProfile] {
        [
            EquipmentProfile(name: "Home Gym",
                             availableEquipment: [.barbell, .dumbbell, .bodyweight, .band, .ezBar],
                             availablePlates: [1.25, 2.5, 5, 10, 20],
                             barTypes: [.defaultOlympic, .ezCurl]),
            EquipmentProfile(name: "Commercial Gym"),
        ]
    }

    // MARK: Templates (real exercise ids — unlike the preset seeder)

    static func template(_ day: DevDay, exercises: [String: Exercise]) -> WorkoutTemplate {
        let items = day.lifts.enumerated().map { i, l in
            TemplateExercise(exerciseId: exercises[l.name]?.id ?? UUID(), exerciseName: l.name, order: i,
                             targetSets: l.sets, targetReps: l.reps.upperBound, targetRIR: 2, restSeconds: l.compound ? 150 : 90)
        }
        let days = DevDay.schedule.filter { $0.value == day }.keys.sorted()
            .map { ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][$0] }
        return WorkoutTemplate(name: day.rawValue, templateExercises: items, splitDays: days)
    }

    // MARK: Working weights

    /// Top working weight for `lift` in `week` (0 = oldest). `deloadWeek` runs at 60%.
    static func topWeight(_ lift: DevLift, week: Int, deloadWeek: Int?) -> Double {
        var kg = lift.startKg + Double(week / max(lift.stepEveryWeeks, 1)) * lift.stepKg
        if week == deloadWeek { kg *= 0.6 }
        return roundToPlate(kg)
    }

    static func roundToPlate(_ kg: Double) -> Double {
        let grid = kg >= 20 ? 1.25 : 0.5
        return (kg / grid).rounded() * grid
    }

    // MARK: Workout

    /// A finished session: warm-ups on flagged compounds, reverse-pyramid working sets with a little
    /// seeded noise (reps ±1, the odd grinder on the last set), RIR trailing down.
    @discardableResult
    static func workout(day: DevDay, date: Date, week: Int, deloadWeek: Int?, template: WorkoutTemplate?,
                        exercises: [String: Exercise], user: User, bodyKg: Double,
                        rng: inout SeededRandom, context: ModelContext) -> Workout {
        let minutes = Double(rng.int(48...74)) + (week == deloadWeek ? -12 : 0)
        let w = Workout(date: date, duration: minutes * 60, notes: rng.chance(0.12) ? "Felt strong today" : "",
                        calorieBurnEstimate: 0, isDraft: false, isDeload: week == deloadWeek)
        w.createdAt = date; w.updatedAt = date
        w.template = template
        w.user = user
        context.insert(w)

        var totalSets = 0, compoundSets = 0, isolationSets = 0
        for (order, lift) in day.lifts.enumerated() {
            let log = ExerciseLog(order: order)
            log.exercise = exercises[lift.name]
            log.workout = w
            log.createdAt = date; log.updatedAt = date
            context.insert(log)

            let top = topWeight(lift, week: week, deloadWeek: deloadWeek)
            var setOrder = 0
            func add(_ weight: Double, _ reps: Int, _ type: SetType, rir: Int?) {
                let s = SetLog(order: setOrder, weight: weight, reps: reps, rir: rir, setType: type)
                s.timestamp = date.addingTimeInterval(Double(totalSets) * 150)
                s.createdAt = date
                s.exerciseLog = log
                context.insert(s)
                setOrder += 1
            }
            if lift.warmups {
                add(roundToPlate(top * 0.5), 8, .warmup, rir: nil)
                add(roundToPlate(top * 0.7), 5, .warmup, rir: nil)
            }
            for i in 0..<lift.sets {
                let weight = roundToPlate(top * (1 - 0.04 * Double(i)))
                var reps = min(max(lift.reps.lowerBound + i + rng.int(-1...1), lift.reps.lowerBound), lift.reps.upperBound)
                var rir = max(0, 2 - i)
                if i == lift.sets - 1, rng.chance(0.15) { reps = max(lift.reps.lowerBound - 1, 3); rir = 0 }
                add(weight, reps, .standard, rir: rir)
                totalSets += 1
                if lift.compound { compoundSets += 1 } else { isolationSets += 1 }
            }
        }
        w.calorieBurnEstimate = CalorieEstimationService.estimate(
            formula: .basic, totalSets: totalSets, compoundSets: compoundSets, isolationSets: isolationSets,
            bodyWeightKg: bodyKg, durationMinutes: minutes, intensity: .moderate)
        return w
    }

    /// An in-progress workout (exercise logs with a few completed sets) for the Continue card.
    static func draftWorkout(now: Date, template: WorkoutTemplate?, exercises: [String: Exercise],
                             user: User, context: ModelContext) -> Workout {
        let w = Workout(date: now, duration: 18 * 60, isDraft: true)
        w.template = template; w.user = user
        context.insert(w)
        for (order, lift) in DevDay.push.lifts.prefix(2).enumerated() {
            let log = ExerciseLog(order: order)
            log.exercise = exercises[lift.name]; log.workout = w
            context.insert(log)
            for i in 0..<(order == 0 ? 3 : 1) {
                let s = SetLog(order: i, weight: roundToPlate(lift.startKg + 12), reps: lift.reps.lowerBound + i, rir: 2, setType: .standard)
                s.exerciseLog = log
                context.insert(s)
            }
        }
        return w
    }
}
#endif
