import Foundation
import SwiftData

struct ExerciseSeedService {

    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom })
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        if count > 0 { return }

        for exercise in allExercises {
            modelContext.insert(exercise)
        }
    }

    // MARK: - Chest

    private static var chestExercises: [Exercise] {
        [
            Exercise(name: "Barbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .barbell, movementPattern: .push),
            Exercise(name: "Incline Barbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .barbell, movementPattern: .push),
            Exercise(name: "Decline Barbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], equipmentType: .barbell, movementPattern: .push),
            Exercise(name: "Dumbbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .dumbbell, movementPattern: .push),
            Exercise(name: "Incline Dumbbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .dumbbell, movementPattern: .push),
            Exercise(name: "Dumbbell Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Incline Dumbbell Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Cable Crossover", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Machine Chest Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .machine, movementPattern: .push),
            Exercise(name: "Pec Deck", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Push Up", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight),
            Exercise(name: "Dip", primaryMuscleGroups: [.chest, .triceps], secondaryMuscleGroups: [.frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight),
        ]
    }

    // MARK: - Back

    private static var backExercises: [Exercise] {
        [
            Exercise(name: "Barbell Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull),
            Exercise(name: "Pendlay Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull),
            Exercise(name: "Dumbbell Row", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .dumbbell, movementPattern: .pull, isUnilateral: true),
            Exercise(name: "Seated Cable Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .cable, movementPattern: .pull),
            Exercise(name: "Lat Pulldown", primaryMuscleGroups: [.lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .cable, movementPattern: .pull),
            Exercise(name: "Pull Up", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight),
            Exercise(name: "Chin Up", primaryMuscleGroups: [.lats, .biceps], secondaryMuscleGroups: [.back], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight),
            Exercise(name: "T-Bar Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull),
            Exercise(name: "Machine Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps], equipmentType: .machine, movementPattern: .pull),
            Exercise(name: "Chest Supported Row", primaryMuscleGroups: [.back, .upperBack], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .dumbbell, movementPattern: .pull),
        ]
    }

    // MARK: - Shoulders

    private static var shoulderExercises: [Exercise] {
        [
            Exercise(name: "Overhead Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .barbell, movementPattern: .push),
            Exercise(name: "Dumbbell Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push),
            Exercise(name: "Arnold Press", primaryMuscleGroups: [.shoulders, .frontDelts, .sideDelts], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push),
            Exercise(name: "Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [.traps], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Cable Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Front Raise", primaryMuscleGroups: [.frontDelts], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Reverse Fly", primaryMuscleGroups: [.rearDelts], secondaryMuscleGroups: [.upperBack], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Face Pull", primaryMuscleGroups: [.rearDelts, .upperBack], secondaryMuscleGroups: [.traps], equipmentType: .cable, movementPattern: .pull),
            Exercise(name: "Machine Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .machine, movementPattern: .push),
            Exercise(name: "Upright Row", primaryMuscleGroups: [.sideDelts, .traps], secondaryMuscleGroups: [.biceps], equipmentType: .barbell, movementPattern: .pull),
        ]
    }

    // MARK: - Arms

    private static var armExercises: [Exercise] {
        [
            Exercise(name: "Barbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [.forearms], equipmentType: .barbell, movementPattern: .isolation),
            Exercise(name: "Dumbbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [.forearms], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Hammer Curl", primaryMuscleGroups: [.biceps, .forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Preacher Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .ezBar, movementPattern: .isolation),
            Exercise(name: "Cable Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Incline Dumbbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Tricep Pushdown", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Overhead Tricep Extension", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Skull Crusher", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .ezBar, movementPattern: .isolation),
            Exercise(name: "Close Grip Bench Press", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest], equipmentType: .barbell, movementPattern: .push),
            Exercise(name: "Dumbbell Tricep Kickback", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Reverse Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
        ]
    }

    // MARK: - Legs

    private static var legExercises: [Exercise] {
        [
            Exercise(name: "Barbell Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .lowerBack], equipmentType: .barbell, movementPattern: .squat),
            Exercise(name: "Front Squat", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [.glutes, .abs], equipmentType: .barbell, movementPattern: .squat),
            Exercise(name: "Leg Press", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .machine, movementPattern: .squat),
            Exercise(name: "Hack Squat", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [.glutes], equipmentType: .machine, movementPattern: .squat),
            Exercise(name: "Bulgarian Split Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat, isUnilateral: true),
            Exercise(name: "Walking Lunge", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat),
            Exercise(name: "Leg Extension", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Leg Curl", primaryMuscleGroups: [.hamstrings], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Romanian Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .barbell, movementPattern: .hinge),
            Exercise(name: "Dumbbell Romanian Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .dumbbell, movementPattern: .hinge),
            Exercise(name: "Conventional Deadlift", primaryMuscleGroups: [.hamstrings, .glutes, .back], secondaryMuscleGroups: [.quads, .lowerBack, .traps, .forearms], equipmentType: .barbell, movementPattern: .hinge),
            Exercise(name: "Sumo Deadlift", primaryMuscleGroups: [.glutes, .quads], secondaryMuscleGroups: [.hamstrings, .adductors, .lowerBack], equipmentType: .barbell, movementPattern: .hinge),
            Exercise(name: "Hip Thrust", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .barbell, movementPattern: .hinge),
            Exercise(name: "Goblet Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .squat),
            Exercise(name: "Standing Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Seated Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Hip Adduction", primaryMuscleGroups: [.adductors], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Hip Abduction", primaryMuscleGroups: [.abductors], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
        ]
    }

    // MARK: - Core

    private static var coreExercises: [Exercise] {
        [
            Exercise(name: "Plank", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.obliques], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased),
            Exercise(name: "Hanging Leg Raise", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight),
            Exercise(name: "Cable Crunch", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Ab Wheel Rollout", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.lowerBack], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight),
            Exercise(name: "Russian Twist", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs], equipmentType: .bodyweight, movementPattern: .rotation, exerciseType: .bodyweight),
            Exercise(name: "Side Plank", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased, isUnilateral: true),
            Exercise(name: "Back Extension", primaryMuscleGroups: [.lowerBack], secondaryMuscleGroups: [.glutes, .hamstrings], equipmentType: .bodyweight, movementPattern: .hinge, exerciseType: .bodyweight),
        ]
    }

    // MARK: - Carry / Other

    private static var carryExercises: [Exercise] {
        [
            Exercise(name: "Farmer Carry", primaryMuscleGroups: [.forearms, .traps], secondaryMuscleGroups: [.abs, .shoulders], equipmentType: .dumbbell, movementPattern: .carry, exerciseType: .distanceBased),
            Exercise(name: "Trap Bar Farmer Carry", primaryMuscleGroups: [.forearms, .traps], secondaryMuscleGroups: [.abs], equipmentType: .trapBar, movementPattern: .carry, exerciseType: .distanceBased),
            Exercise(name: "Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Barbell Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation),
        ]
    }

    static var allExercises: [Exercise] {
        chestExercises + backExercises + shoulderExercises + armExercises + legExercises + coreExercises + carryExercises
    }
}
