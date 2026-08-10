import Foundation
import SwiftData

struct WorkoutDemoDataService {
    static let seedKey = "demoWorkoutDataSeeded_v5"

    static func seedIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

        ExerciseSeedService.seedIfNeeded(modelContext: modelContext)

        let exDescriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.isApproved })
        guard let exercises = try? modelContext.fetch(exDescriptor), !exercises.isEmpty else { return }
        let exLookup = Dictionary(grouping: exercises, by: \.name).compactMapValues(\.first)

        // Create demo user if none exists
        let userDescriptor = FetchDescriptor<User>()
        let existingUsers = (try? modelContext.fetch(userDescriptor)) ?? []
        if existingUsers.isEmpty {
            let user = User(
                name: "Jordan",
                username: "jordan_lifts",
                weight: 81,
                height: 181,
                age: 27,
                gender: .male,
                unitPreference: .kg,
                experienceLevel: .intermediate
            )
            modelContext.insert(user)
        }

        // Fetch or create PPL templates
        let tmDescriptor = FetchDescriptor<WorkoutTemplate>()
        let existingTemplates = (try? modelContext.fetch(tmDescriptor)) ?? []
        let tmLookup = Dictionary(grouping: existingTemplates, by: \.name).compactMapValues(\.first)

        let push = tmLookup["Push Day"] ?? makePushTemplate(lookup: exLookup, modelContext: modelContext)
        let pull = tmLookup["Pull Day"] ?? makePullTemplate(lookup: exLookup, modelContext: modelContext)
        let legs = tmLookup["Leg Day"]  ?? makeLegsTemplate(lookup: exLookup, modelContext: modelContext)

        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int, hour: Int = 10) -> Date {
            let base = cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: now)) ?? now
            return cal.date(byAdding: .hour, value: hour, to: base) ?? base
        }

        // ── Schedule ──────────────────────────────────────────────────────────
        // Streak = 13: workouts every 2 days, 7 workouts, then a 5-day break.
        //   Streak calc: each gap adds to streak. 1 + 2+2+2+2+2+2 = 13.
        //   (daysBack, template, durationSecs, calories, [(name, [(kg, reps)])])
        typealias SetPair = (Double, Int)
        typealias ExData = (String, [SetPair])
        typealias Entry = (Int, WorkoutTemplate, TimeInterval, Double, [ExData])

        let schedule: [Entry] = [

            // ── Current streak: 7 workouts every 2 days ─────────────────────

            // daysAgo(0)  – today – Push Day
            (0, push, 4140, 442, [
                ("Barbell Bench Press",         [(102.5,5),(100,5),(97.5,6),(92.5,8)]),
                ("Incline Dumbbell Bench Press", [(34,10),(34,10),(30,12),(28,12)]),
                ("Overhead Tricep Extension",    [(36,10),(34,10),(32,11)]),
                ("Lateral Raise",               [(13,14),(12,15),(12,14)]),
                ("Tricep Pushdown",             [(42,12),(40,12),(38,13)]),
            ]),

            // daysAgo(2)  – Mon – Pull Day
            (2, pull, 4320, 461, [
                ("Weighted Pull Up",  [(12,8),(10,8),(10,7),(7.5,8)]),
                ("Barbell Row",       [(75,8),(75,8),(70,9),(67.5,10)]),
                ("Lat Pulldown",      [(76,10),(76,10),(72,12)]),
                ("Barbell Curl",      [(46,10),(44,10),(42,11)]),
                ("Hammer Curl",       [(18,12),(18,12),(16,14)]),
            ]),

            // daysAgo(4)  – Sat – Legs
            (4, legs, 4680, 562, [
                ("Barbell Squat",       [(105,5),(102.5,5),(100,6),(95,8)]),
                ("Romanian Deadlift",   [(85,8),(85,8),(80,9)]),
                ("Leg Press",           [(150,10),(150,10),(130,12)]),
                ("Leg Curl",            [(54,12),(52,12),(50,14)]),
                ("Standing Calf Raise", [(68,15),(68,15),(62,18)]),
            ]),

            // daysAgo(6)  – Thu – Push Day
            (6, push, 3960, 421, [
                ("Barbell Bench Press",         [(100,5),(97.5,5),(95,7),(90,8)]),
                ("Incline Dumbbell Bench Press", [(32,10),(32,10),(28,12),(26,12)]),
                ("Overhead Tricep Extension",    [(34,10),(32,10),(30,12)]),
                ("Lateral Raise",               [(12,15),(12,14),(10,15)]),
                ("Tricep Pushdown",             [(40,12),(38,12),(36,13)]),
            ]),

            // daysAgo(8)  – Tue – Pull Day
            (8, pull, 4080, 439, [
                ("Weighted Pull Up",  [(10,8),(10,7),(7.5,8),(5,8)]),
                ("Barbell Row",       [(72.5,8),(72.5,8),(67.5,9),(65,10)]),
                ("Lat Pulldown",      [(74,10),(74,10),(70,12)]),
                ("Barbell Curl",      [(44,10),(42,10),(40,12)]),
                ("Hammer Curl",       [(16,12),(16,12),(14,14)]),
            ]),

            // daysAgo(10) – Sun – Legs
            (10, legs, 4440, 533, [
                ("Barbell Squat",       [(102.5,5),(100,5),(97.5,6),(92.5,8)]),
                ("Romanian Deadlift",   [(82.5,8),(82.5,8),(77.5,9)]),
                ("Leg Press",           [(145,10),(145,10),(125,12)]),
                ("Leg Curl",            [(52,12),(50,12),(48,14)]),
                ("Standing Calf Raise", [(65,15),(65,15),(60,18)]),
            ]),

            // daysAgo(12) – Fri – Push Day  [oldest in streak]
            (12, push, 3780, 404, [
                ("Barbell Bench Press",         [(97.5,5),(95,6),(92.5,7),(87.5,8)]),
                ("Incline Dumbbell Bench Press", [(30,10),(30,10),(26,12)]),
                ("Overhead Tricep Extension",    [(32,10),(30,11),(28,12)]),
                ("Lateral Raise",               [(11,15),(10,15),(10,14)]),
                ("Tricep Pushdown",             [(38,12),(36,12),(34,13)]),
            ]),

            // ── 5-day break after daysAgo(12) ── streak resets here ─────────

            // daysAgo(18) – Sat – Pull Day  [comparison baseline]
            (18, pull, 3900, 419, [
                ("Weighted Pull Up",  [(7.5,8),(7.5,7),(5,8)]),
                ("Barbell Row",       [(67.5,8),(67.5,8),(62.5,10)]),
                ("Lat Pulldown",      [(70,10),(70,10),(66,12)]),
                ("Barbell Curl",      [(40,10),(40,10),(36,12)]),
                ("Hammer Curl",       [(14,12),(14,12),(12,15)]),
            ]),

            // daysAgo(20) – Thu – Legs
            (20, legs, 4200, 504, [
                ("Barbell Squat",       [(97.5,5),(95,5),(90,7),(85,8)]),
                ("Romanian Deadlift",   [(77.5,8),(77.5,8),(72.5,10)]),
                ("Leg Press",           [(135,10),(135,10),(115,12)]),
                ("Leg Curl",            [(48,12),(48,12),(44,15)]),
                ("Standing Calf Raise", [(60,15),(60,15),(55,18)]),
            ]),

            // daysAgo(22) – Tue – Push Day
            (22, push, 3600, 385, [
                ("Barbell Bench Press",         [(95,5),(92.5,6),(87.5,8)]),
                ("Incline Dumbbell Bench Press", [(28,10),(28,10),(24,12)]),
                ("Overhead Tricep Extension",    [(30,10),(28,11),(26,12)]),
                ("Lateral Raise",               [(10,15),(10,14),(8,15)]),
                ("Tricep Pushdown",             [(35,12),(33,12),(31,13)]),
            ]),

            // daysAgo(24) – Sun – Pull Day
            (24, pull, 3720, 400, [
                ("Weighted Pull Up",  [(5,8),(5,7),(0,8)]),
                ("Barbell Row",       [(65,8),(65,8),(60,10)]),
                ("Lat Pulldown",      [(68,10),(68,10),(64,12)]),
                ("Barbell Curl",      [(38,10),(38,10),(34,12)]),
            ]),

            // daysAgo(26) – Fri – Legs
            (26, legs, 4020, 483, [
                ("Barbell Squat",       [(92.5,5),(90,6),(85,7)]),
                ("Romanian Deadlift",   [(75,8),(75,8),(70,10)]),
                ("Leg Press",           [(125,10),(125,10),(110,12)]),
                ("Leg Curl",            [(45,12),(45,12),(42,15)]),
                ("Standing Calf Raise", [(57,15),(57,15),(52,18)]),
            ]),

            // daysAgo(28) – Wed – Push Day  [earliest baseline]
            (28, push, 3480, 368, [
                ("Barbell Bench Press",         [(92.5,5),(90,6),(85,8)]),
                ("Incline Dumbbell Bench Press", [(26,10),(26,9),(22,12)]),
                ("Lateral Raise",               [(10,14),(10,13),(8,14)]),
                ("Tricep Pushdown",             [(33,12),(31,12),(29,13)]),
            ]),
        ]

        for (daysBack, template, duration, calories, exerciseData) in schedule {
            let workout = Workout(
                date: daysAgo(daysBack),
                duration: duration,
                calorieBurnEstimate: calories,
                isDraft: false
            )
            workout.template = template
            modelContext.insert(workout)

            for (order, (exerciseName, sets)) in exerciseData.enumerated() {
                let log = ExerciseLog(order: order)
                log.exercise = exLookup[exerciseName]
                log.workout = workout
                modelContext.insert(log)

                for (setIdx, (weight, reps)) in sets.enumerated() {
                    let setLog = SetLog(
                        order: setIdx,
                        weight: weight,
                        reps: reps,
                        rir: max(0, 2 - setIdx),
                        setType: setIdx == 0 ? .warmup : .standard
                    )
                    setLog.exerciseLog = log
                    modelContext.insert(setLog)
                }

                workout.exerciseLogs.append(log)
            }
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: seedKey)
    }

    // MARK: - Template factories

    private static func makePushTemplate(lookup: [String: Exercise], modelContext: ModelContext) -> WorkoutTemplate {
        let t = WorkoutTemplate(name: "Push Day", templateExercises: [
            TemplateExercise(exerciseId: lookup["Barbell Bench Press"]?.id ?? UUID(),          exerciseName: "Barbell Bench Press",         order: 0, targetSets: 4, targetReps: 6),
            TemplateExercise(exerciseId: lookup["Incline Dumbbell Bench Press"]?.id ?? UUID(), exerciseName: "Incline Dumbbell Bench Press", order: 1, targetSets: 4, targetReps: 10),
            TemplateExercise(exerciseId: lookup["Overhead Tricep Extension"]?.id ?? UUID(),    exerciseName: "Overhead Tricep Extension",    order: 2, targetSets: 3, targetReps: 10),
            TemplateExercise(exerciseId: lookup["Lateral Raise"]?.id ?? UUID(),                exerciseName: "Lateral Raise",               order: 3, targetSets: 3, targetReps: 15),
            TemplateExercise(exerciseId: lookup["Tricep Pushdown"]?.id ?? UUID(),              exerciseName: "Tricep Pushdown",             order: 4, targetSets: 3, targetReps: 12),
        ], splitDays: ["Push", "Pull", "Legs", "Push", "Pull", "Legs"])
        modelContext.insert(t)
        return t
    }

    private static func makePullTemplate(lookup: [String: Exercise], modelContext: ModelContext) -> WorkoutTemplate {
        let t = WorkoutTemplate(name: "Pull Day", templateExercises: [
            TemplateExercise(exerciseId: lookup["Weighted Pull Up"]?.id ?? UUID(),  exerciseName: "Weighted Pull Up", order: 0, targetSets: 4, targetReps: 8),
            TemplateExercise(exerciseId: lookup["Barbell Row"]?.id ?? UUID(),       exerciseName: "Barbell Row",      order: 1, targetSets: 4, targetReps: 8),
            TemplateExercise(exerciseId: lookup["Lat Pulldown"]?.id ?? UUID(),      exerciseName: "Lat Pulldown",     order: 2, targetSets: 3, targetReps: 10),
            TemplateExercise(exerciseId: lookup["Barbell Curl"]?.id ?? UUID(),      exerciseName: "Barbell Curl",     order: 3, targetSets: 3, targetReps: 10),
            TemplateExercise(exerciseId: lookup["Hammer Curl"]?.id ?? UUID(),       exerciseName: "Hammer Curl",      order: 4, targetSets: 3, targetReps: 12),
        ], splitDays: ["Push", "Pull", "Legs", "Push", "Pull", "Legs"])
        modelContext.insert(t)
        return t
    }

    private static func makeLegsTemplate(lookup: [String: Exercise], modelContext: ModelContext) -> WorkoutTemplate {
        let t = WorkoutTemplate(name: "Leg Day", templateExercises: [
            TemplateExercise(exerciseId: lookup["Barbell Squat"]?.id ?? UUID(),        exerciseName: "Barbell Squat",       order: 0, targetSets: 4, targetReps: 5),
            TemplateExercise(exerciseId: lookup["Romanian Deadlift"]?.id ?? UUID(),    exerciseName: "Romanian Deadlift",   order: 1, targetSets: 3, targetReps: 8),
            TemplateExercise(exerciseId: lookup["Leg Press"]?.id ?? UUID(),            exerciseName: "Leg Press",           order: 2, targetSets: 3, targetReps: 10),
            TemplateExercise(exerciseId: lookup["Leg Curl"]?.id ?? UUID(),             exerciseName: "Leg Curl",            order: 3, targetSets: 3, targetReps: 12),
            TemplateExercise(exerciseId: lookup["Standing Calf Raise"]?.id ?? UUID(),  exerciseName: "Standing Calf Raise", order: 4, targetSets: 4, targetReps: 15),
        ], splitDays: ["Push", "Pull", "Legs", "Push", "Pull", "Legs"])
        modelContext.insert(t)
        return t
    }
}
