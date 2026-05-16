import Foundation
import SwiftData

struct ExerciseSeedService {

    private static let currentSeedVersion = 2

    static func seedIfNeeded(modelContext: ModelContext) {
        let seededVersion = UserDefaults.standard.integer(forKey: "exerciseSeedVersion")
        guard seededVersion < currentSeedVersion else { return }

        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map { $0.name })

        for exercise in allExercises where !existingNames.contains(exercise.name) {
            modelContext.insert(exercise)
        }

        UserDefaults.standard.set(currentSeedVersion, forKey: "exerciseSeedVersion")
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
            Exercise(name: "Decline Dumbbell Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push,
                     primarySubRegions: [.lowerChest], secondarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Dumbbell Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.upperChest, .lowerChest]),
            Exercise(name: "Incline Dumbbell Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.upperChest]),
            Exercise(name: "Decline Dumbbell Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.lowerChest]),
            Exercise(name: "Cable Crossover", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.lowerChest]),
            Exercise(name: "High Cable Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.lowerChest]),
            Exercise(name: "Low Cable Fly", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.frontDelts], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.upperChest]),
            Exercise(name: "Machine Chest Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .machine, movementPattern: .push,
                     primarySubRegions: [.upperChest, .lowerChest], secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Pec Deck", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.upperChest, .lowerChest]),
            Exercise(name: "Push Up", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.upperChest, .lowerChest], secondarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Wide Push Up", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.upperChest, .lowerChest]),
            Exercise(name: "Incline Push Up", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerChest]),
            Exercise(name: "Decline Push Up", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.upperChest]),
            Exercise(name: "Dip", primaryMuscleGroups: [.chest, .triceps], secondaryMuscleGroups: [.frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerChest, .tricepsLateralHead, .tricepsMedialHead, .tricepsLongHead]),
            Exercise(name: "Smith Machine Bench Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .smithMachine, movementPattern: .push,
                     primarySubRegions: [.upperChest, .lowerChest], secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Smith Machine Incline Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps, .frontDelts], equipmentType: .smithMachine, movementPattern: .push,
                     primarySubRegions: [.upperChest], secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Landmine Press", primaryMuscleGroups: [.chest, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .barbell, movementPattern: .push,
                     primarySubRegions: [.upperChest]),
            Exercise(name: "Svend Press", primaryMuscleGroups: [.chest], secondaryMuscleGroups: [], equipmentType: .plate, movementPattern: .isolation,
                     primarySubRegions: [.upperChest, .lowerChest]),
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
            Exercise(name: "Wide Grip Lat Pulldown", primaryMuscleGroups: [.lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion], secondarySubRegions: [.bicepsLongHead]),
            Exercise(name: "Close Grip Lat Pulldown", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Reverse Grip Lat Pulldown", primaryMuscleGroups: [.lats], secondaryMuscleGroups: [.biceps], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion], secondarySubRegions: [.bicepsLongHead, .bicepsShortHead]),
            Exercise(name: "Single Arm Lat Pulldown", primaryMuscleGroups: [.lats], secondaryMuscleGroups: [.biceps], equipmentType: .cable, movementPattern: .pull, isUnilateral: true,
                     primarySubRegions: [.latsSubRegion], secondarySubRegions: [.bicepsLongHead]),
            Exercise(name: "Straight Arm Pulldown", primaryMuscleGroups: [.lats], secondaryMuscleGroups: [.triceps], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion], secondarySubRegions: [.tricepsLongHead]),
            Exercise(name: "Pull Up", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids], secondarySubRegions: [.bicepsLongHead]),
            Exercise(name: "Chin Up", primaryMuscleGroups: [.lats, .biceps], secondaryMuscleGroups: [.back], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight,
                     primarySubRegions: [.latsSubRegion, .bicepsShortHead, .bicepsLongHead]),
            Exercise(name: "Neutral Grip Pull Up", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps, .forearms], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids], secondarySubRegions: [.brachialis]),
            Exercise(name: "Weighted Pull Up", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps], equipmentType: .bodyweight, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids], secondarySubRegions: [.bicepsLongHead]),
            Exercise(name: "T-Bar Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Machine Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps], equipmentType: .machine, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Chest Supported Row", primaryMuscleGroups: [.back, .upperBack], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .dumbbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Seal Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Meadows Row", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps], equipmentType: .barbell, movementPattern: .pull, isUnilateral: true,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids]),
            Exercise(name: "Single Arm Cable Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps], equipmentType: .cable, movementPattern: .pull, isUnilateral: true,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Inverted Row", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .rearDelts], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion]),
            Exercise(name: "Dumbbell Pullover", primaryMuscleGroups: [.lats, .chest], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion], secondarySubRegions: [.tricepsLongHead]),
            Exercise(name: "Machine Pullover", primaryMuscleGroups: [.lats], secondaryMuscleGroups: [.triceps], equipmentType: .machine, movementPattern: .pull,
                     primarySubRegions: [.latsSubRegion], secondarySubRegions: [.tricepsLongHead]),
            Exercise(name: "Rack Pull", primaryMuscleGroups: [.back, .traps], secondaryMuscleGroups: [.glutes, .hamstrings, .forearms], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.upperBackRhomboids, .lowerBackErectors, .upperTraps]),
            Exercise(name: "Good Morning", primaryMuscleGroups: [.lowerBack, .hamstrings], secondaryMuscleGroups: [.glutes], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.lowerBackErectors], secondarySubRegions: [.bicepsFemoris, .gluteusMaximus]),
            Exercise(name: "Trap Bar Deadlift", primaryMuscleGroups: [.back, .quads, .glutes], secondaryMuscleGroups: [.hamstrings, .lowerBack, .traps], equipmentType: .trapBar, movementPattern: .hinge,
                     primarySubRegions: [.latsSubRegion, .rectusFemoris, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris, .lowerBackErectors]),
            Exercise(name: "Band Pull Apart", primaryMuscleGroups: [.rearDelts, .upperBack], secondaryMuscleGroups: [.traps], equipmentType: .band, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids]),
            Exercise(name: "Kroc Row", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps, .forearms], equipmentType: .dumbbell, movementPattern: .pull, isUnilateral: true,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids], secondarySubRegions: [.bicepsShortHead, .wristFlexors]),
        ]
    }

    // MARK: - Shoulders

    private static var shoulderExercises: [Exercise] {
        [
            Exercise(name: "Overhead Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .barbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Seated Overhead Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .barbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Dumbbell Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Seated Dumbbell Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Arnold Press", primaryMuscleGroups: [.shoulders, .frontDelts, .sideDelts], secondaryMuscleGroups: [.triceps], equipmentType: .dumbbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Push Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps, .quads], equipmentType: .barbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead, .rectusFemoris]),
            Exercise(name: "Machine Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .machine, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Smith Machine Shoulder Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .smithMachine, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [.traps], equipmentType: .dumbbell, movementPattern: .isolation,
                     secondarySubRegions: [.upperTraps]),
            Exercise(name: "Cable Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Machine Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Band Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [], equipmentType: .band, movementPattern: .isolation),
            Exercise(name: "Front Raise", primaryMuscleGroups: [.frontDelts], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation),
            Exercise(name: "Cable Front Raise", primaryMuscleGroups: [.frontDelts], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation),
            Exercise(name: "Plate Front Raise", primaryMuscleGroups: [.frontDelts], secondaryMuscleGroups: [], equipmentType: .plate, movementPattern: .isolation),
            Exercise(name: "Reverse Fly", primaryMuscleGroups: [.rearDelts], secondaryMuscleGroups: [.upperBack], equipmentType: .dumbbell, movementPattern: .isolation,
                     secondarySubRegions: [.upperBackRhomboids]),
            Exercise(name: "Cable Rear Delt Fly", primaryMuscleGroups: [.rearDelts], secondaryMuscleGroups: [.upperBack], equipmentType: .cable, movementPattern: .isolation,
                     secondarySubRegions: [.upperBackRhomboids]),
            Exercise(name: "Machine Rear Delt Fly", primaryMuscleGroups: [.rearDelts], secondaryMuscleGroups: [.upperBack], equipmentType: .machine, movementPattern: .isolation,
                     secondarySubRegions: [.upperBackRhomboids]),
            Exercise(name: "Face Pull", primaryMuscleGroups: [.rearDelts, .upperBack], secondaryMuscleGroups: [.traps], equipmentType: .cable, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids], secondarySubRegions: [.lowerTraps]),
            Exercise(name: "Upright Row", primaryMuscleGroups: [.sideDelts, .traps], secondaryMuscleGroups: [.biceps], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperTraps], secondarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Dumbbell Upright Row", primaryMuscleGroups: [.sideDelts, .traps], secondaryMuscleGroups: [.biceps], equipmentType: .dumbbell, movementPattern: .pull,
                     primarySubRegions: [.upperTraps]),
            Exercise(name: "Landmine Lateral Raise", primaryMuscleGroups: [.sideDelts], secondaryMuscleGroups: [.traps], equipmentType: .barbell, movementPattern: .isolation, isUnilateral: true),
            Exercise(name: "Handstand Push Up", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight),
        ]
    }

    // MARK: - Biceps

    private static var bicepsExercises: [Exercise] {
        [
            Exercise(name: "Barbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [.forearms], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead], secondarySubRegions: [.wristFlexors]),
            Exercise(name: "EZ Bar Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [.forearms], equipmentType: .ezBar, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead], secondarySubRegions: [.brachioradialis]),
            Exercise(name: "Dumbbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [.forearms], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead], secondarySubRegions: [.wristFlexors]),
            Exercise(name: "Hammer Curl", primaryMuscleGroups: [.biceps, .forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.brachialis, .brachioradialis]),
            Exercise(name: "Cross Body Hammer Curl", primaryMuscleGroups: [.biceps, .forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.brachialis, .brachioradialis]),
            Exercise(name: "Preacher Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .ezBar, movementPattern: .isolation,
                     primarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Dumbbell Preacher Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Cable Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead]),
            Exercise(name: "Cable Hammer Curl", primaryMuscleGroups: [.biceps, .forearms], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.brachialis, .brachioradialis]),
            Exercise(name: "Incline Dumbbell Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead]),
            Exercise(name: "Spider Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Concentration Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.bicepsShortHead]),
            Exercise(name: "Machine Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead]),
            Exercise(name: "Zottman Curl", primaryMuscleGroups: [.biceps, .forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .brachioradialis]),
            Exercise(name: "Reverse Curl", primaryMuscleGroups: [.forearms, .biceps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.wristExtensors, .brachioradialis]),
            Exercise(name: "Drag Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead]),
            Exercise(name: "21s", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead]),
            Exercise(name: "Band Curl", primaryMuscleGroups: [.biceps], secondaryMuscleGroups: [], equipmentType: .band, movementPattern: .isolation,
                     primarySubRegions: [.bicepsLongHead, .bicepsShortHead]),
        ]
    }

    // MARK: - Triceps

    private static var tricepsExercises: [Exercise] {
        [
            Exercise(name: "Tricep Pushdown", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Rope Pushdown", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Reverse Grip Pushdown", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.tricepsMedialHead]),
            Exercise(name: "Single Arm Pushdown", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Overhead Tricep Extension", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLongHead]),
            Exercise(name: "Dumbbell Overhead Tricep Extension", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLongHead]),
            Exercise(name: "Single Arm Overhead Tricep Extension", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.tricepsLongHead]),
            Exercise(name: "Skull Crusher", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .ezBar, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLongHead, .tricepsLateralHead]),
            Exercise(name: "Dumbbell Skull Crusher", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLongHead, .tricepsLateralHead]),
            Exercise(name: "Close Grip Bench Press", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest], equipmentType: .barbell, movementPattern: .push,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead, .tricepsLongHead], secondarySubRegions: [.lowerChest]),
            Exercise(name: "Dumbbell Tricep Kickback", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Diamond Push Up", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
            Exercise(name: "Tricep Dip", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest, .frontDelts], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead, .tricepsLongHead]),
            Exercise(name: "Machine Tricep Extension", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLongHead, .tricepsLateralHead]),
            Exercise(name: "Tate Press", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.tricepsMedialHead, .tricepsLateralHead]),
            Exercise(name: "JM Press", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest], equipmentType: .barbell, movementPattern: .push,
                     primarySubRegions: [.tricepsLongHead, .tricepsMedialHead]),
            Exercise(name: "Band Tricep Pushdown", primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [], equipmentType: .band, movementPattern: .isolation,
                     primarySubRegions: [.tricepsLateralHead, .tricepsMedialHead]),
        ]
    }

    // MARK: - Forearms

    private static var forearmExercises: [Exercise] {
        [
            Exercise(name: "Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.wristFlexors]),
            Exercise(name: "Reverse Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.wristExtensors]),
            Exercise(name: "Barbell Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.wristFlexors]),
            Exercise(name: "Reverse Barbell Wrist Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.wristExtensors]),
            Exercise(name: "Dead Hang", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [.lats], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased,
                     primarySubRegions: [.wristFlexors, .brachioradialis]),
            Exercise(name: "Plate Pinch", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .plate, movementPattern: .isolation, exerciseType: .timeBased,
                     primarySubRegions: [.wristFlexors]),
            Exercise(name: "Finger Curl", primaryMuscleGroups: [.forearms], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.wristFlexors]),
        ]
    }

    // MARK: - Legs

    private static var legExercises: [Exercise] {
        [
            // Quads / Compound
            Exercise(name: "Barbell Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .lowerBack], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris, .lowerBackErectors]),
            Exercise(name: "Front Squat", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [.glutes, .abs], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis], secondarySubRegions: [.gluteusMaximus, .upperAbs]),
            Exercise(name: "Box Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .lowerBack], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Pause Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Zercher Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .lowerBack, .abs], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Smith Machine Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .smithMachine, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Goblet Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Leg Press", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .machine, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Single Leg Press", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .machine, movementPattern: .squat, isUnilateral: true,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Hack Squat", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [.glutes], equipmentType: .machine, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis], secondarySubRegions: [.gluteusMaximus]),
            Exercise(name: "Bulgarian Split Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat, isUnilateral: true,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus, .gluteusMedius], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Walking Lunge", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Reverse Lunge", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat, isUnilateral: true,
                     primarySubRegions: [.rectusFemoris, .gluteusMaximus], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Side Lunge", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.adductors], equipmentType: .bodyweight, movementPattern: .squat, exerciseType: .bodyweight, isUnilateral: true,
                     primarySubRegions: [.vastusMedialis, .gluteusMedius]),
            Exercise(name: "Step Up", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .squat, isUnilateral: true,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Pistol Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .abs], equipmentType: .bodyweight, movementPattern: .squat, exerciseType: .bodyweight, isUnilateral: true,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Sissy Squat", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .squat, exerciseType: .bodyweight,
                     primarySubRegions: [.rectusFemoris, .vastusIntermedius]),
            Exercise(name: "Leg Extension", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis, .vastusIntermedius]),
            Exercise(name: "Single Leg Extension", primaryMuscleGroups: [.quads], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .vastusMedialis]),

            // Hamstrings
            Exercise(name: "Conventional Deadlift", primaryMuscleGroups: [.hamstrings, .glutes, .back], secondaryMuscleGroups: [.quads, .lowerBack, .traps, .forearms], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .gluteusMaximus, .latsSubRegion], secondarySubRegions: [.rectusFemoris, .lowerBackErectors, .upperTraps, .wristFlexors]),
            Exercise(name: "Romanian Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .gluteusMaximus], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Dumbbell Romanian Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .dumbbell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .gluteusMaximus], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Single Leg Romanian Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .dumbbell, movementPattern: .hinge, isUnilateral: true,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .gluteusMaximus]),
            Exercise(name: "Stiff Leg Deadlift", primaryMuscleGroups: [.hamstrings, .glutes], secondaryMuscleGroups: [.lowerBack], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .semimembranosus], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Sumo Deadlift", primaryMuscleGroups: [.glutes, .quads], secondaryMuscleGroups: [.hamstrings, .adductors, .lowerBack], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius, .rectusFemoris, .vastusMedialis], secondarySubRegions: [.bicepsFemoris, .lowerBackErectors]),
            Exercise(name: "Leg Curl", primaryMuscleGroups: [.hamstrings], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .semimembranosus]),
            Exercise(name: "Lying Leg Curl", primaryMuscleGroups: [.hamstrings], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .semimembranosus]),
            Exercise(name: "Seated Leg Curl", primaryMuscleGroups: [.hamstrings], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .semimembranosus]),
            Exercise(name: "Nordic Curl", primaryMuscleGroups: [.hamstrings], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus, .semimembranosus]),
            Exercise(name: "Cable Leg Curl", primaryMuscleGroups: [.hamstrings], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.bicepsFemoris, .semitendinosus]),

            // Glutes
            Exercise(name: "Hip Thrust", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .barbell, movementPattern: .hinge,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius], secondarySubRegions: [.bicepsFemoris]),
            Exercise(name: "Dumbbell Hip Thrust", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .dumbbell, movementPattern: .hinge,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius]),
            Exercise(name: "Smith Machine Hip Thrust", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .smithMachine, movementPattern: .hinge,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius]),
            Exercise(name: "Glute Bridge", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .bodyweight, movementPattern: .hinge, exerciseType: .bodyweight,
                     primarySubRegions: [.gluteusMaximus]),
            Exercise(name: "Single Leg Glute Bridge", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .bodyweight, movementPattern: .hinge, exerciseType: .bodyweight, isUnilateral: true,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius]),
            Exercise(name: "Cable Kickback", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .cable, movementPattern: .isolation, isUnilateral: true,
                     primarySubRegions: [.gluteusMaximus]),
            Exercise(name: "Donkey Kick", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight, isUnilateral: true,
                     primarySubRegions: [.gluteusMaximus]),
            Exercise(name: "Hip Extension Machine", primaryMuscleGroups: [.glutes], secondaryMuscleGroups: [.hamstrings], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.gluteusMaximus, .gluteusMedius]),

            // Calves
            Exercise(name: "Standing Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.gastrocnemius]),
            Exercise(name: "Seated Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.soleus]),
            Exercise(name: "Leg Press Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.gastrocnemius, .soleus]),
            Exercise(name: "Single Leg Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight, isUnilateral: true,
                     primarySubRegions: [.gastrocnemius]),
            Exercise(name: "Smith Machine Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .smithMachine, movementPattern: .isolation,
                     primarySubRegions: [.gastrocnemius]),
            Exercise(name: "Dumbbell Calf Raise", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.gastrocnemius]),

            // Adductors / Abductors
            Exercise(name: "Hip Adduction", primaryMuscleGroups: [.adductors], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Hip Abduction", primaryMuscleGroups: [.abductors], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation),
            Exercise(name: "Cable Hip Abduction", primaryMuscleGroups: [.abductors], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation, isUnilateral: true),
            Exercise(name: "Cable Hip Adduction", primaryMuscleGroups: [.adductors], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation, isUnilateral: true),
            Exercise(name: "Side Lying Hip Abduction", primaryMuscleGroups: [.abductors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight, isUnilateral: true),
            Exercise(name: "Band Hip Abduction", primaryMuscleGroups: [.abductors, .glutes], secondaryMuscleGroups: [], equipmentType: .band, movementPattern: .isolation,
                     primarySubRegions: [.gluteusMedius, .gluteusMinimus]),
        ]
    }

    // MARK: - Core

    private static var coreExercises: [Exercise] {
        [
            Exercise(name: "Plank", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.obliques], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased,
                     primarySubRegions: [.upperAbs, .lowerAbs]),
            Exercise(name: "Side Plank", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased, isUnilateral: true,
                     secondarySubRegions: [.upperAbs]),
            Exercise(name: "Hollow Hold", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.hipFlexors], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased,
                     primarySubRegions: [.upperAbs, .lowerAbs]),
            Exercise(name: "L-Sit", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [.triceps], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .timeBased,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Hanging Leg Raise", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Hanging Knee Raise", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Toes to Bar", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [.lats], equipmentType: .bodyweight, movementPattern: .pull, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Leg Raise", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Knee Raise", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Cable Crunch", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.upperAbs]),
            Exercise(name: "Crunch", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs]),
            Exercise(name: "Decline Crunch", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs]),
            Exercise(name: "Weighted Crunch", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [], equipmentType: .plate, movementPattern: .isolation,
                     primarySubRegions: [.upperAbs]),
            Exercise(name: "Sit Up", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs, .lowerAbs]),
            Exercise(name: "V-Up", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.hipFlexors], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs, .lowerAbs]),
            Exercise(name: "Bicycle Crunch", primaryMuscleGroups: [.obliques, .abs], secondaryMuscleGroups: [], equipmentType: .bodyweight, movementPattern: .rotation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs]),
            Exercise(name: "Russian Twist", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs], equipmentType: .bodyweight, movementPattern: .rotation, exerciseType: .bodyweight,
                     secondarySubRegions: [.upperAbs]),
            Exercise(name: "Weighted Russian Twist", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs], equipmentType: .plate, movementPattern: .rotation,
                     secondarySubRegions: [.upperAbs]),
            Exercise(name: "Ab Wheel Rollout", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.lowerBack], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs, .lowerAbs], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Dead Bug", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.hipFlexors], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Bird Dog", primaryMuscleGroups: [.abs, .lowerBack], secondaryMuscleGroups: [.glutes], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Mountain Climber", primaryMuscleGroups: [.abs, .hipFlexors], secondaryMuscleGroups: [.chest, .shoulders], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerAbs]),
            Exercise(name: "Dragon Flag", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.lowerBack, .hipFlexors], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight,
                     primarySubRegions: [.upperAbs, .lowerAbs]),
            Exercise(name: "Pallof Press", primaryMuscleGroups: [.obliques, .abs], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.upperAbs]),
            Exercise(name: "Cable Woodchop", primaryMuscleGroups: [.obliques], secondaryMuscleGroups: [.abs, .shoulders], equipmentType: .cable, movementPattern: .rotation),
            Exercise(name: "Back Extension", primaryMuscleGroups: [.lowerBack], secondaryMuscleGroups: [.glutes, .hamstrings], equipmentType: .bodyweight, movementPattern: .hinge, exerciseType: .bodyweight,
                     primarySubRegions: [.lowerBackErectors], secondarySubRegions: [.gluteusMaximus, .bicepsFemoris]),
            Exercise(name: "Weighted Back Extension", primaryMuscleGroups: [.lowerBack], secondaryMuscleGroups: [.glutes, .hamstrings], equipmentType: .machine, movementPattern: .hinge,
                     primarySubRegions: [.lowerBackErectors], secondarySubRegions: [.gluteusMaximus, .bicepsFemoris]),
            Exercise(name: "Ab Machine Crunch", primaryMuscleGroups: [.abs], secondaryMuscleGroups: [], equipmentType: .machine, movementPattern: .isolation,
                     primarySubRegions: [.upperAbs]),
        ]
    }

    // MARK: - Cardio / Conditioning

    private static var cardioExercises: [Exercise] {
        [
            Exercise(name: "Box Jump", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.calves, .hamstrings], equipmentType: .bodyweight, movementPattern: .squat, exerciseType: .bodyweight,
                     primarySubRegions: [.rectusFemoris, .gluteusMaximus]),
            Exercise(name: "Jump Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.calves], equipmentType: .bodyweight, movementPattern: .squat, exerciseType: .bodyweight,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .gluteusMaximus]),
            Exercise(name: "Burpee", primaryMuscleGroups: [.chest, .quads], secondaryMuscleGroups: [.triceps, .glutes, .abs], equipmentType: .bodyweight, movementPattern: .push, exerciseType: .bodyweight),
            Exercise(name: "Jump Rope", primaryMuscleGroups: [.calves], secondaryMuscleGroups: [.shoulders, .abs], equipmentType: .other, movementPattern: .carry, exerciseType: .timeBased,
                     primarySubRegions: [.gastrocnemius]),
            Exercise(name: "Rowing Machine", primaryMuscleGroups: [.back, .lats], secondaryMuscleGroups: [.biceps, .quads, .glutes], equipmentType: .machine, movementPattern: .pull, exerciseType: .distanceBased,
                     primarySubRegions: [.upperBackRhomboids, .latsSubRegion]),
            Exercise(name: "Stationary Bike", primaryMuscleGroups: [.quads, .calves], secondaryMuscleGroups: [.glutes, .hamstrings], equipmentType: .machine, movementPattern: .squat, exerciseType: .timeBased),
            Exercise(name: "Treadmill", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .calves], equipmentType: .machine, movementPattern: .carry, exerciseType: .distanceBased),
            Exercise(name: "Elliptical", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.hamstrings, .calves], equipmentType: .machine, movementPattern: .carry, exerciseType: .timeBased),
            Exercise(name: "Stair Climber", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.calves], equipmentType: .machine, movementPattern: .squat, exerciseType: .timeBased,
                     primarySubRegions: [.rectusFemoris, .gluteusMaximus]),
            Exercise(name: "Sled Push", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.calves, .chest], equipmentType: .other, movementPattern: .push, exerciseType: .distanceBased,
                     primarySubRegions: [.rectusFemoris, .gluteusMaximus]),
            Exercise(name: "Sled Pull", primaryMuscleGroups: [.back, .hamstrings, .glutes], secondaryMuscleGroups: [.biceps], equipmentType: .other, movementPattern: .pull, exerciseType: .distanceBased),
            Exercise(name: "Battle Ropes", primaryMuscleGroups: [.shoulders, .forearms], secondaryMuscleGroups: [.abs, .back], equipmentType: .other, movementPattern: .push, exerciseType: .timeBased),
            Exercise(name: "Assault Bike", primaryMuscleGroups: [.quads, .shoulders], secondaryMuscleGroups: [.glutes, .hamstrings, .chest], equipmentType: .machine, movementPattern: .push, exerciseType: .timeBased),
        ]
    }

    // MARK: - Olympic / Power Lifts

    private static var olympicExercises: [Exercise] {
        [
            Exercise(name: "Power Clean", primaryMuscleGroups: [.back, .quads, .glutes], secondaryMuscleGroups: [.hamstrings, .traps, .shoulders], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .rectusFemoris, .gluteusMaximus], secondarySubRegions: [.upperTraps]),
            Exercise(name: "Hang Clean", primaryMuscleGroups: [.back, .quads, .glutes], secondaryMuscleGroups: [.hamstrings, .traps], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .rectusFemoris, .gluteusMaximus]),
            Exercise(name: "Clean and Jerk", primaryMuscleGroups: [.back, .quads, .glutes, .shoulders], secondaryMuscleGroups: [.hamstrings, .triceps, .traps], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .rectusFemoris, .gluteusMaximus]),
            Exercise(name: "Power Snatch", primaryMuscleGroups: [.back, .quads, .glutes, .shoulders], secondaryMuscleGroups: [.hamstrings, .traps], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .rectusFemoris, .gluteusMaximus], secondarySubRegions: [.upperTraps]),
            Exercise(name: "Hang Snatch", primaryMuscleGroups: [.back, .quads, .glutes], secondaryMuscleGroups: [.hamstrings, .traps, .shoulders], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .rectusFemoris, .gluteusMaximus]),
            Exercise(name: "Clean Pull", primaryMuscleGroups: [.back, .quads, .glutes, .traps], secondaryMuscleGroups: [.hamstrings], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .rectusFemoris], secondarySubRegions: [.upperTraps]),
            Exercise(name: "Snatch Pull", primaryMuscleGroups: [.back, .quads, .glutes, .traps], secondaryMuscleGroups: [.hamstrings], equipmentType: .barbell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .rectusFemoris], secondarySubRegions: [.upperTraps]),
            Exercise(name: "Push Jerk", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps, .quads], equipmentType: .barbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead, .rectusFemoris]),
            Exercise(name: "Split Jerk", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps, .quads, .glutes], equipmentType: .barbell, movementPattern: .push,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Overhead Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.shoulders, .abs, .upperBack], equipmentType: .barbell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .gluteusMaximus]),
        ]
    }

    // MARK: - Kettlebell

    private static var kettlebellExercises: [Exercise] {
        [
            Exercise(name: "Kettlebell Swing", primaryMuscleGroups: [.glutes, .hamstrings], secondaryMuscleGroups: [.lowerBack, .shoulders, .abs], equipmentType: .kettlebell, movementPattern: .hinge,
                     primarySubRegions: [.gluteusMaximus, .bicepsFemoris], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Single Arm Kettlebell Swing", primaryMuscleGroups: [.glutes, .hamstrings], secondaryMuscleGroups: [.lowerBack, .shoulders], equipmentType: .kettlebell, movementPattern: .hinge, isUnilateral: true,
                     primarySubRegions: [.gluteusMaximus, .bicepsFemoris]),
            Exercise(name: "Kettlebell Clean", primaryMuscleGroups: [.back, .glutes, .quads], secondaryMuscleGroups: [.traps, .forearms], equipmentType: .kettlebell, movementPattern: .pull,
                     primarySubRegions: [.upperBackRhomboids, .gluteusMaximus]),
            Exercise(name: "Kettlebell Press", primaryMuscleGroups: [.shoulders, .frontDelts], secondaryMuscleGroups: [.triceps], equipmentType: .kettlebell, movementPattern: .push, isUnilateral: true,
                     secondarySubRegions: [.tricepsLateralHead]),
            Exercise(name: "Kettlebell Snatch", primaryMuscleGroups: [.back, .glutes, .shoulders], secondaryMuscleGroups: [.hamstrings, .traps, .forearms], equipmentType: .kettlebell, movementPattern: .pull, isUnilateral: true,
                     primarySubRegions: [.upperBackRhomboids, .gluteusMaximus]),
            Exercise(name: "Turkish Get Up", primaryMuscleGroups: [.shoulders, .abs], secondaryMuscleGroups: [.glutes, .quads, .triceps], equipmentType: .kettlebell, movementPattern: .push, isUnilateral: true),
            Exercise(name: "Kettlebell Row", primaryMuscleGroups: [.lats, .back], secondaryMuscleGroups: [.biceps], equipmentType: .kettlebell, movementPattern: .pull, isUnilateral: true,
                     primarySubRegions: [.latsSubRegion, .upperBackRhomboids]),
            Exercise(name: "Kettlebell Deadlift", primaryMuscleGroups: [.hamstrings, .glutes, .back], secondaryMuscleGroups: [.quads, .lowerBack], equipmentType: .kettlebell, movementPattern: .hinge,
                     primarySubRegions: [.bicepsFemoris, .gluteusMaximus], secondarySubRegions: [.lowerBackErectors]),
            Exercise(name: "Kettlebell Goblet Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.abs], equipmentType: .kettlebell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusMedialis, .gluteusMaximus]),
            Exercise(name: "Kettlebell Front Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.abs, .shoulders], equipmentType: .kettlebell, movementPattern: .squat,
                     primarySubRegions: [.rectusFemoris, .vastusLateralis, .gluteusMaximus]),
            Exercise(name: "Kettlebell Windmill", primaryMuscleGroups: [.obliques, .abs], secondaryMuscleGroups: [.shoulders, .glutes, .hamstrings], equipmentType: .kettlebell, movementPattern: .rotation, isUnilateral: true),
            Exercise(name: "Kettlebell Figure 8", primaryMuscleGroups: [.abs, .obliques], secondaryMuscleGroups: [.glutes, .forearms], equipmentType: .kettlebell, movementPattern: .rotation),
        ]
    }

    // MARK: - Carries / Traps

    private static var carryExercises: [Exercise] {
        [
            Exercise(name: "Farmer Carry", primaryMuscleGroups: [.forearms, .traps], secondaryMuscleGroups: [.abs, .shoulders], equipmentType: .dumbbell, movementPattern: .carry, exerciseType: .distanceBased,
                     primarySubRegions: [.wristFlexors, .brachioradialis, .upperTraps], secondarySubRegions: [.upperAbs]),
            Exercise(name: "Trap Bar Farmer Carry", primaryMuscleGroups: [.forearms, .traps], secondaryMuscleGroups: [.abs], equipmentType: .trapBar, movementPattern: .carry, exerciseType: .distanceBased,
                     primarySubRegions: [.wristFlexors, .brachioradialis, .upperTraps], secondarySubRegions: [.upperAbs]),
            Exercise(name: "Suitcase Carry", primaryMuscleGroups: [.forearms, .obliques], secondaryMuscleGroups: [.traps, .abs], equipmentType: .dumbbell, movementPattern: .carry, exerciseType: .distanceBased, isUnilateral: true,
                     primarySubRegions: [.wristFlexors, .upperTraps]),
            Exercise(name: "Overhead Carry", primaryMuscleGroups: [.shoulders, .traps], secondaryMuscleGroups: [.abs, .forearms], equipmentType: .dumbbell, movementPattern: .carry, exerciseType: .distanceBased,
                     primarySubRegions: [.upperTraps]),
            Exercise(name: "Barbell Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.upperTraps]),
            Exercise(name: "Dumbbell Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.upperTraps]),
            Exercise(name: "Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .dumbbell, movementPattern: .isolation,
                     primarySubRegions: [.upperTraps]),
            Exercise(name: "Behind the Back Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .barbell, movementPattern: .isolation,
                     primarySubRegions: [.upperTraps]),
            Exercise(name: "Cable Shrug", primaryMuscleGroups: [.traps], secondaryMuscleGroups: [], equipmentType: .cable, movementPattern: .isolation,
                     primarySubRegions: [.upperTraps]),
        ]
    }

    // MARK: - Neck

    private static var neckExercises: [Exercise] {
        [
            Exercise(name: "Neck Flexion", primaryMuscleGroups: [.neck], secondaryMuscleGroups: [], equipmentType: .plate, movementPattern: .isolation),
            Exercise(name: "Neck Extension", primaryMuscleGroups: [.neck], secondaryMuscleGroups: [], equipmentType: .plate, movementPattern: .isolation),
            Exercise(name: "Neck Lateral Flexion", primaryMuscleGroups: [.neck], secondaryMuscleGroups: [], equipmentType: .plate, movementPattern: .isolation, isUnilateral: true),
            Exercise(name: "Neck Bridge", primaryMuscleGroups: [.neck], secondaryMuscleGroups: [.upperBack], equipmentType: .bodyweight, movementPattern: .isolation, exerciseType: .bodyweight),
        ]
    }

    static var allExercises: [Exercise] {
        chestExercises +
        backExercises +
        shoulderExercises +
        bicepsExercises +
        tricepsExercises +
        forearmExercises +
        legExercises +
        coreExercises +
        cardioExercises +
        olympicExercises +
        kettlebellExercises +
        carryExercises +
        neckExercises
    }
}
