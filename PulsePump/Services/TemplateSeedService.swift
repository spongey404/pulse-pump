import Foundation
import SwiftData

struct TemplateSeedService {

    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        if count > 0 { return }

        for template in allTemplates {
            modelContext.insert(template)
        }
    }

    static var allTemplates: [WorkoutTemplate] {
        pplTemplates + upperLowerTemplates + fullBodyTemplates
    }

    // MARK: - PPL

    static var pplTemplates: [WorkoutTemplate] {
        [
            WorkoutTemplate(name: "Push Day", templateExercises: [
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Bench Press", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Overhead Press", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Incline Dumbbell Bench Press", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Lateral Raise", order: 3, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Tricep Pushdown", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Overhead Tricep Extension", order: 5, targetSets: 3, targetReps: 12),
            ]),
            WorkoutTemplate(name: "Pull Day", templateExercises: [
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Row", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Lat Pulldown", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Seated Cable Row", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Face Pull", order: 3, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Curl", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Hammer Curl", order: 5, targetSets: 3, targetReps: 12),
            ]),
            WorkoutTemplate(name: "Leg Day", templateExercises: [
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Squat", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Romanian Deadlift", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Leg Press", order: 2, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Leg Curl", order: 3, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Leg Extension", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Standing Calf Raise", order: 5, targetSets: 4, targetReps: 15),
            ]),
        ]
    }

    // MARK: - Upper/Lower

    static var upperLowerTemplates: [WorkoutTemplate] {
        [
            WorkoutTemplate(name: "Upper Body", templateExercises: [
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Bench Press", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Row", order: 1, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Dumbbell Shoulder Press", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Lat Pulldown", order: 3, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Lateral Raise", order: 4, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Curl", order: 5, targetSets: 2, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Tricep Pushdown", order: 6, targetSets: 2, targetReps: 12),
            ]),
            WorkoutTemplate(name: "Lower Body", templateExercises: [
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Squat", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Romanian Deadlift", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Leg Press", order: 2, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Leg Curl", order: 3, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Hip Thrust", order: 4, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Standing Calf Raise", order: 5, targetSets: 4, targetReps: 15),
            ]),
        ]
    }

    // MARK: - Full Body

    static var fullBodyTemplates: [WorkoutTemplate] {
        [
            WorkoutTemplate(name: "Full Body A", templateExercises: [
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Squat", order: 0, targetSets: 3, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Bench Press", order: 1, targetSets: 3, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Row", order: 2, targetSets: 3, targetReps: 8),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Dumbbell Shoulder Press", order: 3, targetSets: 2, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Curl", order: 4, targetSets: 2, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Tricep Pushdown", order: 5, targetSets: 2, targetReps: 12),
            ]),
            WorkoutTemplate(name: "Full Body B", templateExercises: [
                TemplateExercise(exerciseId: UUID(), exerciseName: "Conventional Deadlift", order: 0, targetSets: 3, targetReps: 6),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Incline Dumbbell Bench Press", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Lat Pulldown", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Lateral Raise", order: 3, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Leg Curl", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: UUID(), exerciseName: "Face Pull", order: 5, targetSets: 3, targetReps: 15),
            ]),
        ]
    }
}
