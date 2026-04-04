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
            Exercise(name: "Barbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .barbell, movementPattern: .push,
                     primarySubRegions: [.upperChest, .lowerChest], secondarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Incline Barbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .barbell, movementPattern: .push,
                     primarySubRegions: [.upperChest], secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Decline Barbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], equipmentType: .barbell, movementPattern: .push,
                     primarySubRegions: [.lowerChest], secondarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Dumbbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .dumbbell, movementPattern: .push,
                     primarySubRegions: [.upperChest, .lowerChest], secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Incline Dumbbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .dumbbell, movementPattern: .push,
                     primarySubRegions: [.upperChest], secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Dumbbell Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.upperChest, .lowerChest]),
            Exercise(name: "Incline Dumbbell Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.upperChest]),
            Exercise(name: "Cable Crossover", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.lowerChest]),
            Exercise(name: "Machine Chest Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .machine, movementPattern: .push,
                     primarySubRegions: [.upperChest, .lowerChest], secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Pec Deck", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.upperChest, .lowerChest]),
            Exercise(name: "Push Up", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.upperChest, .lowerChest], secondarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Dip", primaryMuscleGroups: [.chest, .triceps], secondaryMuscleGroups: [.frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerChest, .tricepsLateralHead, .tricepsMedialHead, .tricepsLongHead]),
        ]
    }

    // MARK: - Back

    private static var backExercises: [Exercise] {
        [
            Exercise(name: "Barbell Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Pendlay Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Dumbbell Row", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .dumbbell, movementPattern: .pull, isUnilateral: true,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Seated Cable Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Lat Pulldown", primaryMuscleGroups: [.lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion], secondarySubRegions: [.bicepsLongHead]),
            Exercise(name: "Pull Up", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids], secondarySubRegions: [.bicepsLongHead]),
            Exercise(name: "Chin Up", primaryMuscleGroups: [.lats, .biceps], secondaryMuscleGroups: [.back], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight,
                     primarySubRegions: [.latsSubRegion, .bicepsShortHead, .bicepsLongHead]),
            Exercise(name: "T-Bar Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Machine Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps], equipmentType: .machine, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Chest Supported Row", primaryMuscleGroups: [.back, .upperBack], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .dumbbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids], secondarySubRegions: [.bicepsShortHead]),
        ]
    }

    // MARK: - Shoulders

    private static var shoulderExercises: [Exercise] {
        [
            Exercise(name: "Overhead Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .barbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Dumbbell Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Arnold Press", primaryMuscleGroups: [.shoulders, .frontDelts, .sideDelts], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [.traps], equipmentType: .dumbbell, movementPattern: .isolation,
                     secondarySubRegions: [.upperTraps]),
            Exercise(name: "Cable Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Front Raise", primaryMuscleGroups: [.frontDelts], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Reverse Fly", primaryMuscleGroups: [.rearDelts], secondaryMuscleGroups: [.upperBack], equipmentType: .dumbbell, movementPattern: .isolation,
                     secondarySubRegions: [.upperBackRhomboids]),
            Exercise(name: "Face Pull", primaryMuscleGroups: [.rearDelts, .upperBack], secondaryMuscleGroups: [.traps], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids], secondarySubRegions: [.lowerTraps]),
            Exercise(name: "Machine Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .machine, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Upright Row", primaryMuscleGroups: [.sideDelts, .traps], secondaryMuscleGroups: [.biceps], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperTraps], secondarySubRegions: [.bicepsShortHead]),
        ]
    }

    // MARK: - Arms

    private static var armExercises: [Exercise] {
        [
            Exercise(name: "Barbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [.forearms], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead], secondarySubRegions: [.wristFlexors]),
            Exercise(name: "Dumbbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [.forearms], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead], secondarySubRegions: [.wristFlexors]),
            Exercise(name: "Hammer Curl", primaryMuscleGroups: [.biceps, .forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.brachialis, .brachioradialis]),
            Exercise(name: "Preacher Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .ezBar, movementPattern: .isolation,
                     primarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Cable Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead]),
            Exercise(name: "Incline Dumbbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead]),
            Exercise(name: "Tricep Pushdown", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Overhead Tricep Extension", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLongHead]),
            Exercise(name: "Skull Crusher", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .ezBar, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLongHead, .tricepsLateralHead]),
            Exercise(name: "Close Grip Bench Press", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest], equipmentType: .barbell, movementPattern: .push,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead, .tricepsLongHead], secondarySubRegions: [.lowerChest]),
            Exercise(name: "Dumbbell Tricep Kickback", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.wristFlexors]),
            Exercise(name: "Reverse Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.wristExtensors]),
        ]
    }

    // MARK: - Legs

    private static var legExercises: [Exercise] {
        [
            Exercise(name: "Barbell Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .lowerBack], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris, .lowerBackErectors]),
            Exercise(name: "Front Squat", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [.glutes, .abs], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis], secondarySubRegions: [.gluteusMaximus, .upperAbs]),
            Exercise(name: "Leg Press", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .machine, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Hack Squat", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [.glutes], equipmentType: .machine, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis], secondarySubRegions: [.gluteusMaximus]),
            Exercise(name: "Bulgarian Split Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat, isUnilateral: true,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus, .gluteusMedius], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Walking Lunge", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Leg Extension", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis, .vastusIntermedius]),
            Exercise(name: "Leg Curl", primaryMuscleGroups: [.hamstrings], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .semimembranosus]),
            Exercise(name: "Romanian Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .gluteusMaximus], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Dumbbell Romanian Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .dumbbell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .gluteusMaximus], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Conventional Deadlift", primaryMuscleGroups: [.hamstrings, .glutes, .back], secondaryMuscleGroups: [.quads, .lowerBack, .traps, .forearms], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .gluteusMaximus, .latsSubRegion], secondarySubRegions: [.rectusFemoris, .lowerBackErectors, .upperTraps, .wristFlexors]),
            Exercise(name: "Sumo Deadlift", primaryMuscleGroups: [.glutes, .quads], secondaryMuscleGroups: [.hamstrings, .adductors, .lowerBack], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius, .rectusFemoris, .vastusMedialis], secondarySubRegions: [.bicepsFemoris, .lowerBackErectors]),
            Exercise(name: "Hip Thrust", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Goblet Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Standing Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.gastrocnemius]),
            Exercise(name: "Seated Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.soleus]),
            Exercise(name: "Hip Adduction", primaryMuscleGroups: [.adductors], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Hip Abduction", primaryMuscleGroups: [.abductors], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
        ]
    }

    // MARK: - Core

    private static var coreExercises: [Exercise] {
        [
            Exercise(name: "Plank", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.obliques], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased,
                     primarySubRegions: [.upperAbs, .lowerAbs]),
            Exercise(name: "Hanging Leg Raise", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Cable Crunch", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.upperAbs]),
            Exercise(name: "Ab Wheel Rollout", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.lowerBack], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs, .lowerAbs], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Russian Twist", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs], equipmentType: .bodyweight, movementPattern: .rotation, exerciseType: .bodyweight,
                     secondarySubRegions: [.upperAbs]),
            Exercise(name: "Side Plank", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased, isUnilateral: true,
                     secondarySubRegions: [.upperAbs]),
            Exercise(name: "Back Extension", primaryMuscleGroups: [.lowerBack], secondaryMuscleGroups: [.glutes, .hamstrings], equipmentType: .bodyweight, movementPattern: .hinge, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerBackErectors], secondarySubRegions: [.gluteusMaximus, .bicepsFemoris]),
        ]
    }

    // MARK: - Carry / Other

    private static var carryExercises: [Exercise] {
        [
            Exercise(name: "Farmer Carry", primaryMuscleGroups: [.forearms, .traps], secondaryMuscleGroups: [.abs, .shoulders], equipmentType: .dumbbell, movementPattern: .carry, exerciseType: .distanceBased,
                     primarySubRegions: [.wristFlexors, .brachioradialis, .upperTraps], secondarySubRegions: [.upperAbs]),
            Exercise(name: "Trap Bar Farmer Carry", primaryMuscleGroups: [.forearms, .traps], secondaryMuscleGroups: [.abs], equipmentType: .trapBar, movementPattern: .carry, exerciseType: .distanceBased,
                     primarySubRegions: [.wristFlexors, .brachioradialis, .upperTraps], secondarySubRegions: [.upperAbs]),
            Exercise(name: "Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.upperTraps]),
            Exercise(name: "Barbell Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.upperTraps]),
        ]
    }

    static var allExercises: [Exercise] {
        chestExercises + backExercises + shoulderExercises + armExercises + legExercises + coreExercises + carryExercises
    }
}
