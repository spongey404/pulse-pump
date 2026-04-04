import SwiftUI
import SwiftData
import Observation
import FirebaseAuth

@MainActor
@Observable
class WorkoutViewModel {
    // Workout state
    var workout: Workout?
    var exerciseEntries: [ExerciseEntry] = []
    var workoutNotes = ""
    var isActive = false
    var showCancelConfirmation = false
    var showCompletionSummary = false

    // Timer
    var startTime: Date?
    var elapsedSeconds: Int = 0
    private var durationTimer: Timer?

    // Rest timer
    let restTimer = RestTimerService()

    // Live Activity
    private let liveActivity = LiveActivityService()

    // Live calorie estimate
    var liveCalories: Double = 0

    // Completion summary data
    var completionData: WorkoutCompletionData?

    // MARK: - Start Workout

    func startWorkout(modelContext: ModelContext, user: User, template: WorkoutTemplate? = nil) {
        let newWorkout = Workout(isDraft: true)
        newWorkout.user = user
        newWorkout.template = template
        modelContext.insert(newWorkout)
        workout = newWorkout

        if let template {
            for templateExercise in template.templateExercises.sorted(by: { $0.order < $1.order }) {
                // Look up exercise to get type + unilateral flag
                let exId = templateExercise.exerciseId
                let exDesc = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exId })
                let exercise = try? modelContext.fetch(exDesc).first

                var entry = ExerciseEntry(
                    exerciseId: templateExercise.exerciseId,
                    exerciseName: templateExercise.exerciseName,
                    sets: (0..<templateExercise.targetSets).map { i in
                        SetEntry(order: i, targetReps: templateExercise.targetReps, targetRIR: templateExercise.targetRIR)
                    }
                )
                entry.exerciseType = exercise?.exerciseType ?? .weighted
                entry.isUnilateral = exercise?.isUnilateral ?? false
                entry.equipmentType = exercise?.equipmentType ?? .barbell
                exerciseEntries.append(entry)
            }
        }

        isActive = true
        startTime = Date()
        startDurationTimer()
        liveActivity.startLiveActivity(workoutName: workout?.template?.name ?? "Workout")
    }

    func resumeDraft(workout: Workout, modelContext: ModelContext) {
        self.workout = workout
        self.workoutNotes = workout.notes
        self.isActive = true

        for log in workout.exerciseLogs.sorted(by: { $0.order < $1.order }) {
            guard let exercise = log.exercise else { continue }
            var entry = ExerciseEntry(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                sets: log.sets.sorted(by: { $0.order < $1.order }).map { setLog in
                    SetEntry(
                        order: setLog.order,
                        weight: setLog.weight > 0 ? String(format: "%g", setLog.weight) : "",
                        reps: setLog.reps > 0 ? "\(setLog.reps)" : "",
                        rir: setLog.rir.map { "\($0)" } ?? "",
                        duration: setLog.duration.map { "\(Int($0))" } ?? "",
                        distance: setLog.distance.map { String(format: "%g", $0) } ?? "",
                        setType: setLog.setType,
                        side: setLog.side
                    )
                },
                notes: log.notes
            )
            entry.exerciseType = exercise.exerciseType
            entry.isUnilateral = exercise.isUnilateral
            entry.equipmentType = exercise.equipmentType
            exerciseEntries.append(entry)
        }

        startTime = Date().addingTimeInterval(-workout.duration)
        startDurationTimer()
    }

    // MARK: - Exercise Management

    func addExercise(_ exercise: Exercise) {
        var entry = ExerciseEntry(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            sets: [SetEntry(order: 0)]
        )
        entry.exerciseType = exercise.exerciseType
        entry.isUnilateral = exercise.isUnilateral
        entry.equipmentType = exercise.equipmentType
        exerciseEntries.append(entry)
    }

    func removeExercise(at index: Int) {
        guard exerciseEntries.indices.contains(index) else { return }
        exerciseEntries.remove(at: index)
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        exerciseEntries.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Set Management

    func addSet(to exerciseIndex: Int) {
        guard exerciseEntries.indices.contains(exerciseIndex) else { return }
        let order = exerciseEntries[exerciseIndex].sets.count
        exerciseEntries[exerciseIndex].sets.append(SetEntry(order: order))
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        guard exerciseEntries.indices.contains(exerciseIndex),
              exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exerciseEntries[exerciseIndex].sets.remove(at: setIndex)
    }

    func logSet(exerciseIndex: Int, setIndex: Int, isCompound: Bool) {
        guard exerciseEntries.indices.contains(exerciseIndex),
              exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exerciseEntries[exerciseIndex].sets[setIndex].isCompleted = true

        updateLiveCalories()

        if restTimer.mode == .autoStart || restTimer.mode == .autoStartWithDismiss {
            let exerciseId = exerciseEntries[exerciseIndex].exerciseId
            let duration = restTimer.restDuration(isCompound: isCompound, exerciseId: exerciseId)
            restTimer.start(seconds: duration)
        }
    }

    func updateLiveCalories() {
        var compoundSets = 0
        var isolationSets = 0
        let totalCompleted = exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
        // Approximate: treat sets as compound if exercise name contains common compound keywords
        for entry in exerciseEntries {
            let completed = entry.sets.filter(\.isCompleted).count
            let name = entry.exerciseName.lowercased()
            let isCompound = name.contains("squat") || name.contains("bench") || name.contains("deadlift") ||
                name.contains("press") || name.contains("row") || name.contains("pull-up") || name.contains("chin-up")
            if isCompound {
                compoundSets += completed
            } else {
                isolationSets += completed
            }
        }
        let formula = CalorieFormula(rawValue: UserDefaults.standard.string(forKey: "calorieFormula") ?? "") ?? .basic
        let durationMinutes = Double(elapsedSeconds) / 60.0
        let bodyWeight = workout?.user?.weight ?? 0
        liveCalories = CalorieEstimationService.estimate(
            formula: formula,
            totalSets: totalCompleted,
            compoundSets: compoundSets,
            isolationSets: isolationSets,
            bodyWeightKg: bodyWeight,
            durationMinutes: durationMinutes,
            intensity: .moderate
        )
    }

    // MARK: - Ghost Text

    func ghostText(for exerciseId: UUID, setIndex: Int, modelContext: ModelContext) -> (weight: String, reps: String)? {
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in
                log.exercise?.id == exerciseId
            },
            sortBy: [SortDescriptor(\ExerciseLog.createdAt, order: .reverse)]
        )
        guard let previousLog = try? modelContext.fetch(descriptor).first,
              setIndex < previousLog.sets.count else { return nil }

        let previousSet = previousLog.sets.sorted(by: { $0.order < $1.order })[setIndex]
        return (
            weight: previousSet.weight > 0 ? String(format: "%g", previousSet.weight) : "",
            reps: previousSet.reps > 0 ? "\(previousSet.reps)" : ""
        )
    }

    // MARK: - Complete / Cancel

    func completeWorkout(modelContext: ModelContext) {
        guard let workout else { return }

        stopDurationTimer()
        restTimer.stop()

        workout.duration = TimeInterval(elapsedSeconds)
        workout.notes = workoutNotes
        workout.isDraft = false
        workout.updatedAt = Date()

        // Remove old exercise logs and recreate
        for log in workout.exerciseLogs {
            modelContext.delete(log)
        }

        var prCount = 0
        var improvedCount = 0

        for (i, entry) in exerciseEntries.enumerated() {
            let completedSets = entry.sets.filter { $0.isCompleted }
            guard !completedSets.isEmpty else { continue }

            let exerciseLog = ExerciseLog(order: i, notes: entry.notes)
            modelContext.insert(exerciseLog)
            exerciseLog.workout = workout

            // Find exercise by ID
            let exerciseId = entry.exerciseId
            let exDesc = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseId })
            exerciseLog.exercise = try? modelContext.fetch(exDesc).first

            var bestWeight: Double = 0
            for (j, setEntry) in completedSets.enumerated() {
                let weight = Double(setEntry.weight) ?? 0
                let reps = Int(setEntry.reps) ?? 0
                let rir = Int(setEntry.rir)
                let duration: TimeInterval? = Double(setEntry.duration).map { TimeInterval($0) }
                let distance: Double? = Double(setEntry.distance)

                let setLog = SetLog(
                    order: j,
                    weight: weight,
                    reps: reps,
                    rir: rir,
                    duration: duration,
                    distance: distance,
                    setType: setEntry.setType,
                    side: setEntry.side
                )
                modelContext.insert(setLog)
                setLog.exerciseLog = exerciseLog
                bestWeight = max(bestWeight, weight)
            }

            // Check for PRs (simplified: compare max weight)
            if let exercise = exerciseLog.exercise {
                let allPreviousSets = exercise.logs
                    .filter { $0.id != exerciseLog.id }
                    .flatMap(\.sets)
                let previousBest = allPreviousSets.map(\.weight).max() ?? 0
                if bestWeight > previousBest && previousBest > 0 {
                    prCount += 1
                }
                if bestWeight >= previousBest && previousBest > 0 {
                    improvedCount += 1
                }
            }
        }

        // Calorie estimate using CalorieEstimationService
        let totalSets = exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
        var compoundSets = 0
        var isolationSets = 0
        for entry in exerciseEntries {
            let completedCount = entry.sets.filter(\.isCompleted).count
            let eid = entry.exerciseId
            let desc = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == eid })
            if let exercise = try? modelContext.fetch(desc).first, exercise.movementPattern.isCompound {
                compoundSets += completedCount
            } else {
                isolationSets += completedCount
            }
        }
        let userWeight = workout.user?.weight ?? 0
        let durationMinutes = workout.duration / 60.0
        let formula = CalorieFormula(rawValue: UserDefaults.standard.string(forKey: "calorieFormula") ?? "") ?? .basic
        workout.calorieBurnEstimate = CalorieEstimationService.estimate(
            formula: formula,
            totalSets: totalSets,
            compoundSets: compoundSets,
            isolationSets: isolationSets,
            bodyWeightKg: userWeight,
            durationMinutes: durationMinutes,
            intensity: .moderate
        )

        completionData = WorkoutCompletionData(
            duration: workout.duration,
            calories: workout.calorieBurnEstimate,
            exerciseCount: exerciseEntries.filter { !$0.sets.filter(\.isCompleted).isEmpty }.count,
            totalSets: totalSets,
            prCount: prCount,
            improvedCount: improvedCount,
            totalExercises: exerciseEntries.count,
            musclesWorked: collectMusclesWorked(modelContext: modelContext)
        )

        // Post to social feed (fire-and-forget) if auto-share is enabled
        let autoShare = UserDefaults.standard.object(forKey: "autoShareToFeed") as? Bool ?? true
        if autoShare, let data = completionData, let user = workout.user {
            let feedItem = WorkoutFeedItem(
                userId: Auth.auth().currentUser?.uid ?? "",
                username: user.name,
                templateName: workout.template?.name,
                exerciseCount: data.exerciseCount,
                durationSeconds: Int(workout.duration),
                caloriesBurned: Int(data.calories),
                musclesWorked: data.musclesWorked.map(\.displayName),
                prCount: data.prCount,
                improvedCount: data.improvedCount,
                totalExercises: data.totalExercises,
                date: workout.date
            )
            Task {
                try? await FirestoreService().shareWorkoutToFeed(feedItem)
            }
        }

        // Update widget data
        WidgetDataService.updateWidgetData(modelContext: modelContext)

        showCompletionSummary = true
        isActive = false
    }

    func cancelWorkout(modelContext: ModelContext) {
        stopDurationTimer()
        restTimer.stop()

        if let workout {
            modelContext.delete(workout)
        }

        reset()
    }

    func saveDraft() {
        guard let workout else { return }
        workout.duration = TimeInterval(elapsedSeconds)
        workout.notes = workoutNotes
        workout.updatedAt = Date()
    }

    func reset() {
        workout = nil
        exerciseEntries = []
        workoutNotes = ""
        isActive = false
        elapsedSeconds = 0
        startTime = nil
        completionData = nil
        showCompletionSummary = false
    }

    // MARK: - Smart Weight Suggestion (Pulse+)

    func smartWeightSuggestion(for exerciseId: UUID, setIndex: Int, modelContext: ModelContext) -> String? {
        // Look at last 3 sessions, if weight increased consistently, suggest next increment
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in
                log.exercise?.id == exerciseId
            },
            sortBy: [SortDescriptor(\ExerciseLog.createdAt, order: .reverse)]
        )
        guard let recentLogs = try? modelContext.fetch(descriptor),
              recentLogs.count >= 2 else { return nil }

        let lastWeights = recentLogs.prefix(3).compactMap { log -> Double? in
            let sorted = log.sets.sorted { $0.order < $1.order }
            guard setIndex < sorted.count else { return nil }
            return sorted[setIndex].weight
        }

        guard let lastWeight = lastWeights.first, lastWeight > 0 else { return nil }

        // If user has been increasing weight, suggest next increment
        if lastWeights.count >= 2 {
            let prevWeight = lastWeights[1]
            if lastWeight > prevWeight {
                let increment = lastWeight - prevWeight
                let suggested = lastWeight + increment
                return String(format: "%g", suggested)
            }
        }

        // Otherwise suggest same weight
        return String(format: "%g", lastWeight)
    }

    // MARK: - Smart Prediction

    func predictNextWorkout(user: User) -> String? {
        guard let split = user.selectedSplit else { return nil }
        let days = split.days.sorted(by: { $0.dayOfWeek < $1.dayOfWeek })
        guard !days.isEmpty else { return split.type.displayName }

        let weekday = Calendar.current.component(.weekday, from: Date())
        if let todaySession = days.first(where: { $0.dayOfWeek == weekday }) {
            return todaySession.label
        }

        return days.first?.label
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        let timerInstance = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let start = self.startTime else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
                let currentExercise = self.exerciseEntries.first(where: {
                    $0.sets.contains { !$0.isCompleted }
                })?.exerciseName ?? "Rest"
                let completed = self.exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
                let total = self.exerciseEntries.flatMap(\.sets).count
                Task { await self.liveActivity.updateLiveActivity(
                    elapsedSeconds: self.elapsedSeconds,
                    currentExercise: currentExercise,
                    completedSets: completed,
                    totalSets: total
                )}
            }
        }
        durationTimer = timerInstance
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        Task { await liveActivity.endLiveActivity() }
    }

    var formattedDuration: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Helpers

    private func collectMusclesWorked(modelContext: ModelContext) -> Set<MuscleGroup> {
        var muscles = Set<MuscleGroup>()
        for entry in exerciseEntries {
            let id = entry.exerciseId
            let desc = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })
            if let exercise = try? modelContext.fetch(desc).first {
                muscles.formUnion(exercise.primaryMuscleGroups)
                muscles.formUnion(exercise.secondaryMuscleGroups)
            }
        }
        return muscles
    }
}

// MARK: - Supporting Types

struct ExerciseEntry: Identifiable {
    let id = UUID()
    var exerciseId: UUID
    var exerciseName: String
    var exerciseType: ExerciseType = .weighted
    var isUnilateral: Bool = false
    var equipmentType: EquipmentType = .barbell
    var sets: [SetEntry]
    var notes: String = ""
}

struct SetEntry: Identifiable {
    let id = UUID()
    var order: Int
    var weight: String = ""
    var reps: String = ""
    var rir: String = ""
    var duration: String = ""   // seconds, for time-based exercises
    var distance: String = ""   // meters/feet, for distance-based exercises
    var setType: SetType = .standard
    var side: Side = .both
    var isCompleted: Bool = false
    var targetReps: Int?
    var targetRIR: Int?

    init(order: Int, weight: String = "", reps: String = "", rir: String = "",
         duration: String = "", distance: String = "",
         setType: SetType = .standard, side: Side = .both,
         targetReps: Int? = nil, targetRIR: Int? = nil) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.duration = duration
        self.distance = distance
        self.setType = setType
        self.side = side
        self.targetReps = targetReps
        self.targetRIR = targetRIR
    }
}

struct WorkoutCompletionData {
    let duration: TimeInterval
    let calories: Double
    let exerciseCount: Int
    let totalSets: Int
    let prCount: Int
    let improvedCount: Int
    let totalExercises: Int
    let musclesWorked: Set<MuscleGroup>

    var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m) min"
    }
}
