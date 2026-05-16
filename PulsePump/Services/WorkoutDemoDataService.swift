import Foundation
import SwiftData

struct WorkoutDemoDataService {
    static let seedKey = "demoWorkoutDataSeeded_v4"

    static func seedIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

        // Need exercises to exist first
        let exDescriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.isApproved })
        guard let exercises = try? modelContext.fetch(exDescriptor), !exercises.isEmpty else { return }

        let exLookup = Dictionary(grouping: exercises, by: \.name).compactMapValues(\.first)

        // Fetch or create templates
        let tmDescriptor = FetchDescriptor<WorkoutTemplate>()
        let existingTemplates = (try? modelContext.fetch(tmDescriptor)) ?? []
        let tmLookup = Dictionary(grouping: existingTemplates, by: \.name).compactMapValues(\.first)

        let push = tmLookup["Push Day"] ?? makePushTemplate(lookup: exLookup, modelContext: modelContext)
        let pull = tmLookup["Pull Day"] ?? makePullTemplate(lookup: exLookup, modelContext: modelContext)
        let legs = tmLookup["Leg Day"] ?? makeLegsTemplate(lookup: exLookup, modelContext: modelContext)

        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now) ?? now }

        // 4-week PPL schedule with progressive overload
        // (daysAgo, template, duration, calories, [(exerciseName, [(weight, reps)])])
        let schedule: [(Int, WorkoutTemplate, TimeInterval, Double, [(String, [(Double, Int)])])] = [

            // ── This week ──
            (1, push, 3900, 418, [
                ("Barbell Bench Press",        [(102.5, 5), (100,  5), (95,   7)]),
                ("Incline Dumbbell Bench Press",[(36,   10), (36,  10), (32,  12)]),
                ("Lateral Raise",               [(14,   15), (14,  13), (12,  15)]),
                ("Tricep Pushdown",             [(42,   12), (40,  12), (38,  12)]),
                ("Overhead Tricep Extension",   [(34,   10), (32,  11), (30,  12)]),
            ]),
            (2, pull, 4200, 452, [
                ("Weighted Pull Up",  [(12,   8), (10,  8), (10,   7)]),
                ("Barbell Row",       [(72.5,  8), (72.5, 8), (67.5, 10)]),
                ("Lat Pulldown",      [(74,   10), (74,  10), (70,  12)]),
                ("Barbell Curl",      [(44,   10), (44,  10), (40,  12)]),
                ("Hammer Curl",       [(16,   12), (16,  12), (14,  15)]),
            ]),
            (4, legs, 4500, 541, [
                ("Barbell Squat",      [(102.5,  5), (100,  5), (95,   7)]),
                ("Romanian Deadlift",  [(82.5,   8), (82.5, 8), (77.5, 10)]),
                ("Leg Press",          [(145,   10), (145, 10), (125,  12)]),
                ("Leg Curl",           [(52,    12), (52,  12), (48,   15)]),
                ("Standing Calf Raise",[(65,    15), (65,  15), (60,   18)]),
            ]),

            // ── Last week ──
            (8,  push, 3750, 401, [
                ("Barbell Bench Press",        [(100,  5), (97.5, 5), (92.5, 7)]),
                ("Incline Dumbbell Bench Press",[(34,  10), (34,  10), (30,  12)]),
                ("Lateral Raise",               [(12,  15), (12,  14), (10,  15)]),
                ("Tricep Pushdown",             [(40,  12), (38,  12), (36,  12)]),
                ("Overhead Tricep Extension",   [(32,  10), (30,  11), (28,  12)]),
            ]),
            (10, pull, 4050, 436, [
                ("Weighted Pull Up",  [(10,   8), (10,  7), (7.5,  8)]),
                ("Barbell Row",       [(70,   8), (70,  8), (65,   10)]),
                ("Lat Pulldown",      [(72,  10), (72, 10), (68,   12)]),
                ("Barbell Curl",      [(42,  10), (42, 10), (38,   12)]),
                ("Hammer Curl",       [(14,  12), (14, 12), (12,   15)]),
            ]),
            (12, legs, 4350, 519, [
                ("Barbell Squat",      [(100,  5), (97.5, 5), (92.5, 7)]),
                ("Romanian Deadlift",  [(80,   8), (80,   8), (75,  10)]),
                ("Leg Press",          [(140, 10), (140, 10), (120, 12)]),
                ("Leg Curl",           [(50,  12), (50,  12), (46,  15)]),
                ("Standing Calf Raise",[(62,  15), (62,  15), (58,  18)]),
            ]),
            (14, push, 3600, 385, [
                ("Barbell Bench Press",        [(97.5, 5), (95, 6), (90,  8)]),
                ("Incline Dumbbell Bench Press",[(32,  10), (32, 9), (28, 12)]),
                ("Lateral Raise",               [(12,  15), (10, 14),(10,  15)]),
                ("Tricep Pushdown",             [(38,  12), (36, 11),(34,  12)]),
            ]),

            // ── Two weeks ago ──
            (15, pull, 3900, 421, [
                ("Weighted Pull Up",  [(7.5, 8),  (7.5, 7), (5,   8)]),
                ("Barbell Row",       [(67.5, 8), (67.5, 8),(62.5, 10)]),
                ("Lat Pulldown",      [(70,  10), (70,  10),(66,   12)]),
                ("Barbell Curl",      [(40,  10), (40,  10),(36,   12)]),
            ]),
            (17, legs, 4200, 505, [
                ("Barbell Squat",      [(97.5, 5), (95, 5), (90,  7)]),
                ("Romanian Deadlift",  [(77.5, 8), (77.5, 8),(72.5, 10)]),
                ("Leg Press",          [(135, 10), (135, 10),(115, 12)]),
                ("Leg Curl",           [(48,  12), (48,  12),(44,  15)]),
            ]),
            (19, push, 3480, 370, [
                ("Barbell Bench Press",        [(95, 5),  (92.5, 6),(87.5, 8)]),
                ("Incline Dumbbell Bench Press",[(30, 10), (30,  10),(26,  12)]),
                ("Lateral Raise",               [(10, 15), (10,  14),(10,  14)]),
                ("Tricep Pushdown",             [(36, 12), (34,  12),(32,  12)]),
            ]),
            (21, pull, 3780, 408, [
                ("Weighted Pull Up",  [(5,   8),  (5,   7), (0,   8)]),
                ("Barbell Row",       [(65,  8),  (65,  8), (60,  10)]),
                ("Lat Pulldown",      [(68,  10), (68,  10),(64,  12)]),
                ("Barbell Curl",      [(38,  10), (38,  10),(34,  12)]),
            ]),

            // ── Three weeks ago ──
            (22, legs, 4100, 492, [
                ("Barbell Squat",      [(95,  5), (92.5, 5),(87.5, 7)]),
                ("Romanian Deadlift",  [(75,  8), (75,   8),(70,  10)]),
                ("Leg Press",          [(130, 10),(130,  10),(110, 12)]),
                ("Leg Curl",           [(46,  12),(46,   12),(42,  15)]),
            ]),
            (24, push, 3360, 355, [
                ("Barbell Bench Press",        [(92.5, 5),(90,  6),(85,  8)]),
                ("Incline Dumbbell Bench Press",[(28,  10),(28,  9),(24, 12)]),
                ("Lateral Raise",               [(10,  14),(10, 13),(8,  15)]),
            ]),
            (26, pull, 3600, 393, [
                ("Barbell Row",   [(62.5, 8), (62.5, 8),(57.5, 10)]),
                ("Lat Pulldown",  [(66,  10), (66,  10),(62,   12)]),
                ("Barbell Curl",  [(36,  10), (36,  10),(32,   12)]),
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
            template.workouts.append(workout)
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
                        rir: max(0, 3 - setIdx),
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
            TemplateExercise(exerciseId: lookup["Barbell Bench Press"]?.id ?? UUID(),         exerciseName: "Barbell Bench Press",         order: 0, targetSets: 4, targetReps: 6),
            TemplateExercise(exerciseId: lookup["Incline Dumbbell Bench Press"]?.id ?? UUID(),exerciseName: "Incline Dumbbell Bench Press", order: 1, targetSets: 3, targetReps: 10),
            TemplateExercise(exerciseId: lookup["Lateral Raise"]?.id ?? UUID(),               exerciseName: "Lateral Raise",               order: 2, targetSets: 3, targetReps: 15),
            TemplateExercise(exerciseId: lookup["Tricep Pushdown"]?.id ?? UUID(),             exerciseName: "Tricep Pushdown",             order: 3, targetSets: 3, targetReps: 12),
            TemplateExercise(exerciseId: lookup["Overhead Tricep Extension"]?.id ?? UUID(),   exerciseName: "Overhead Tricep Extension",   order: 4, targetSets: 3, targetReps: 12),
        ], splitDays: ["P", "P", "L", "P", "P", "L"])
        modelContext.insert(t)
        return t
    }

    private static func makePullTemplate(lookup: [String: Exercise], modelContext: ModelContext) -> WorkoutTemplate {
        let t = WorkoutTemplate(name: "Pull Day", templateExercises: [
            TemplateExercise(exerciseId: lookup["Weighted Pull Up"]?.id ?? UUID(),exerciseName: "Weighted Pull Up", order: 0, targetSets: 4, targetReps: 8),
            TemplateExercise(exerciseId: lookup["Barbell Row"]?.id ?? UUID(),     exerciseName: "Barbell Row",      order: 1, targetSets: 4, targetReps: 8),
            TemplateExercise(exerciseId: lookup["Lat Pulldown"]?.id ?? UUID(),    exerciseName: "Lat Pulldown",     order: 2, targetSets: 3, targetReps: 10),
            TemplateExercise(exerciseId: lookup["Barbell Curl"]?.id ?? UUID(),    exerciseName: "Barbell Curl",     order: 3, targetSets: 3, targetReps: 12),
            TemplateExercise(exerciseId: lookup["Hammer Curl"]?.id ?? UUID(),     exerciseName: "Hammer Curl",      order: 4, targetSets: 3, targetReps: 12),
        ], splitDays: ["P", "P", "L", "P", "P", "L"])
        modelContext.insert(t)
        return t
    }

    private static func makeLegsTemplate(lookup: [String: Exercise], modelContext: ModelContext) -> WorkoutTemplate {
        let t = WorkoutTemplate(name: "Leg Day", templateExercises: [
            TemplateExercise(exerciseId: lookup["Barbell Squat"]?.id ?? UUID(),       exerciseName: "Barbell Squat",       order: 0, targetSets: 4, targetReps: 6),
            TemplateExercise(exerciseId: lookup["Romanian Deadlift"]?.id ?? UUID(),   exerciseName: "Romanian Deadlift",   order: 1, targetSets: 3, targetReps: 8),
            TemplateExercise(exerciseId: lookup["Leg Press"]?.id ?? UUID(),           exerciseName: "Leg Press",           order: 2, targetSets: 3, targetReps: 12),
            TemplateExercise(exerciseId: lookup["Leg Curl"]?.id ?? UUID(),            exerciseName: "Leg Curl",            order: 3, targetSets: 3, targetReps: 12),
            TemplateExercise(exerciseId: lookup["Standing Calf Raise"]?.id ?? UUID(), exerciseName: "Standing Calf Raise", order: 4, targetSets: 4, targetReps: 15),
        ], splitDays: ["P", "P", "L", "P", "P", "L"])
        modelContext.insert(t)
        return t
    }
}
