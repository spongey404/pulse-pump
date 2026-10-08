import Foundation
import SwiftData

struct TemplateSeedService {

    /// Placeholder id in the preset definitions below; replaced by the catalogue exercise's real
    /// id (matched by name) when the templates are seeded.
    static let unresolvedId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Seeds the preset templates once, linked to the seeded catalogue by exercise NAME. Run
    /// `ExerciseSeedService.seedIfNeeded` first. Also repairs templates seeded before this fix.
    static func seedIfNeeded(modelContext: ModelContext) {
        let exercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let count = (try? modelContext.fetchCount(FetchDescriptor<WorkoutTemplate>())) ?? 0
        if count == 0 {
            let templates = allTemplates
            resolveExerciseLinks(in: templates, exercises: exercises)
            for template in templates { modelContext.insert(template) }
        } else {
            repairExerciseLinks(modelContext: modelContext)
        }
    }

    /// Points every template exercise at the catalogue exercise with the same (normalised) name.
    /// Entries whose id already matches a real exercise are left alone. Returns the names that
    /// matched nothing.
    @discardableResult
    static func resolveExerciseLinks(in templates: [WorkoutTemplate], exercises: [Exercise]) -> [String] {
        let ids = Set(exercises.map(\.id))
        var byName: [String: UUID] = [:]
        // Prefer built-in catalogue entries over same-named custom ones.
        for e in exercises.sorted(by: { !$0.isCustom && $1.isCustom }) {
            byName[Exercise.normalisedName(e.name)] = byName[Exercise.normalisedName(e.name)] ?? e.id
        }
        var unmatched: [String] = []
        for template in templates {
            var items = template.templateExercises
            var changed = false
            for i in items.indices where !ids.contains(items[i].exerciseId) {
                if let id = byName[Exercise.normalisedName(items[i].exerciseName)] {
                    items[i].exerciseId = id
                    changed = true
                } else {
                    unmatched.append(items[i].exerciseName)
                }
            }
            if changed { template.templateExercises = items; template.markUpdated() }
        }
        return unmatched
    }

    /// One-time repair for existing installs: relink templates whose exercise ids dangle.
    static func repairExerciseLinks(modelContext: ModelContext) {
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let exercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        resolveExerciseLinks(in: templates, exercises: exercises)
    }

    static var allTemplates: [WorkoutTemplate] {
        pplTemplates + upperLowerTemplates + fullBodyTemplates
    }

    // MARK: - PPL

    static var pplTemplates: [WorkoutTemplate] {
        let rotation = ["P", "P", "L", "P", "P", "L"]
        return [
            WorkoutTemplate(name: "Push Day", templateExercises: [
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Bench Press", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Overhead Press", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Incline Dumbbell Bench Press", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Lateral Raise", order: 3, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Tricep Pushdown", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Overhead Tricep Extension", order: 5, targetSets: 3, targetReps: 12),
            ], splitDays: rotation),
            WorkoutTemplate(name: "Pull Day", templateExercises: [
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Row", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Lat Pulldown", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Seated Cable Row", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Face Pull", order: 3, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Curl", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Hammer Curl", order: 5, targetSets: 3, targetReps: 12),
            ], splitDays: rotation),
            WorkoutTemplate(name: "Leg Day", templateExercises: [
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Squat", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Romanian Deadlift", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Leg Press", order: 2, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Leg Curl", order: 3, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Leg Extension", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Standing Calf Raise", order: 5, targetSets: 4, targetReps: 15),
            ], splitDays: rotation),
        ]
    }

    // MARK: - Upper/Lower

    static var upperLowerTemplates: [WorkoutTemplate] {
        let rotation = ["U", "L", "U", "L"]
        return [
            WorkoutTemplate(name: "Upper Body", templateExercises: [
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Bench Press", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Row", order: 1, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Dumbbell Shoulder Press", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Lat Pulldown", order: 3, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Lateral Raise", order: 4, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Curl", order: 5, targetSets: 2, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Tricep Pushdown", order: 6, targetSets: 2, targetReps: 12),
            ], splitDays: rotation),
            WorkoutTemplate(name: "Lower Body", templateExercises: [
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Squat", order: 0, targetSets: 4, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Romanian Deadlift", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Leg Press", order: 2, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Leg Curl", order: 3, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Hip Thrust", order: 4, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Standing Calf Raise", order: 5, targetSets: 4, targetReps: 15),
            ], splitDays: rotation),
        ]
    }

    // MARK: - Full Body

    static var fullBodyTemplates: [WorkoutTemplate] {
        let rotation = ["F", "F", "F"]
        return [
            WorkoutTemplate(name: "Full Body A", templateExercises: [
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Squat", order: 0, targetSets: 3, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Bench Press", order: 1, targetSets: 3, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Row", order: 2, targetSets: 3, targetReps: 8),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Dumbbell Shoulder Press", order: 3, targetSets: 2, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Barbell Curl", order: 4, targetSets: 2, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Tricep Pushdown", order: 5, targetSets: 2, targetReps: 12),
            ], splitDays: rotation),
            WorkoutTemplate(name: "Full Body B", templateExercises: [
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Conventional Deadlift", order: 0, targetSets: 3, targetReps: 6),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Incline Dumbbell Bench Press", order: 1, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Lat Pulldown", order: 2, targetSets: 3, targetReps: 10),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Lateral Raise", order: 3, targetSets: 3, targetReps: 15),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Leg Curl", order: 4, targetSets: 3, targetReps: 12),
                TemplateExercise(exerciseId: unresolvedId, exerciseName: "Face Pull", order: 5, targetSets: 3, targetReps: 15),
            ], splitDays: rotation),
        ]
    }
}
