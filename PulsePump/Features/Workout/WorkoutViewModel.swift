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
    private var liveModelContext: ModelContext?
    private var liveObservers: [NSObjectProtocol] = []
    private var cachedRestEnd: Date?
    private var lastTimeCache: [UUID: (line: String, date: String)] = [:]

    // Live calorie estimate
    var liveCalories: Double = 0

    // Completion summary data
    var completionData: WorkoutCompletionData?

    // MARK: - Start Workout

    /// Deletes any existing draft then starts a fresh session.
    func discardDraftAndStart(draft: Workout, modelContext: ModelContext, user: User, template: WorkoutTemplate? = nil) {
        modelContext.delete(draft)
        startWorkout(modelContext: modelContext, user: user, template: template)
    }

    func startWorkout(modelContext: ModelContext, user: User, template: WorkoutTemplate? = nil) {
        let newWorkout = Workout(isDraft: true)
        newWorkout.user = user
        newWorkout.template = template
        modelContext.insert(newWorkout)
        workout = newWorkout
        liveModelContext = modelContext
        installLiveActivityObservers()

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
        restTimer.clearCompletion()

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

        // Single lookup reused below instead of a separate fetch per entry per loop.
        let exerciseById: [UUID: Exercise] = Dictionary(
            uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.id, $0) }
        )

        var prCount = 0
        var improvedCount = 0
        var improvementScores: [UUID: Double] = [:]  // entry.id → % 1RM gain
        var weightDeltas: [UUID: Double] = [:]  // entry.id → kg gained on the best set vs last time
        var repsDeltas: [UUID: Int] = [:]       // entry.id → reps gained at the same weight vs last time
        var prDetails: [PRDetail] = []

        for (i, entry) in exerciseEntries.enumerated() {
            let completedSets = entry.sets.filter { $0.isCompleted }
            guard !completedSets.isEmpty else { continue }

            let exerciseLog = ExerciseLog(order: i, notes: entry.notes)
            modelContext.insert(exerciseLog)
            exerciseLog.workout = workout

            // Find exercise by ID
            exerciseLog.exercise = exerciseById[entry.exerciseId]

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

            // Check for PRs and compute improvement score (Epley 1RM comparison)
            if let exercise = exerciseLog.exercise {
                let allPreviousSets = exercise.logs
                    .filter { $0.id != exerciseLog.id }
                    .flatMap(\.sets)
                let previousBestWeight = allPreviousSets.map(\.weight).max() ?? 0
                let bestRepsThisWorkout = completedSets.map { Int($0.reps) ?? 0 }.max() ?? 0
                let previousMaxReps = allPreviousSets.filter { $0.weight <= bestWeight + 0.01 }.map(\.reps).max() ?? 0

                func epley(_ w: Double, _ r: Int) -> Double { w > 0 ? w * (1 + Double(r) / 30) : Double(r) }
                let current1RM = completedSets.map { epley(Double($0.weight) ?? 0, Int($0.reps) ?? 0) }.max() ?? 0
                let previous1RM = allPreviousSets.map { epley($0.weight, $0.reps) }.max() ?? 0
                let oneRMDelta = current1RM - previous1RM

                if bestWeight > previousBestWeight && previousBestWeight > 0 {
                    prCount += 1
                    let score = previousBestWeight > 0 ? (bestWeight - previousBestWeight) / previousBestWeight * 100 : 0
                    prDetails.append(PRDetail(
                        exerciseName: entry.exerciseName,
                        weightDelta: bestWeight - previousBestWeight,
                        repsDelta: 0,
                        isWeightPR: true,
                        impressivenessScore: score
                    ))
                } else if bestRepsThisWorkout > previousMaxReps && previousMaxReps > 0 {
                    prCount += 1
                    let score = previousMaxReps > 0 ? Double(bestRepsThisWorkout - previousMaxReps) / Double(previousMaxReps) * 100 * 0.5 : 0
                    prDetails.append(PRDetail(
                        exerciseName: entry.exerciseName,
                        weightDelta: 0,
                        repsDelta: bestRepsThisWorkout - previousMaxReps,
                        isWeightPR: false,
                        impressivenessScore: score
                    ))
                }
                if bestWeight >= previousBestWeight && previousBestWeight > 0 {
                    improvedCount += 1
                }
                if previous1RM > 0 {
                    improvementScores[entry.id] = max(0, oneRMDelta / previous1RM * 100)
                }
                // Same "what actually got better" comparison as the PR check above, but kept
                // even when it isn't a PR (e.g. matched last time's weight but added reps at
                // it) — the feed's "VS LAST" column shows this raw kg/rep gain, not a %.
                if bestWeight > previousBestWeight && previousBestWeight > 0 {
                    weightDeltas[entry.id] = bestWeight - previousBestWeight
                } else if bestRepsThisWorkout > previousMaxReps && previousMaxReps > 0 {
                    repsDeltas[entry.id] = bestRepsThisWorkout - previousMaxReps
                }
            }
        }

        // Calorie estimate using CalorieEstimationService
        let totalSets = exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
        var compoundSets = 0
        var isolationSets = 0
        for entry in exerciseEntries {
            let completedCount = entry.sets.filter(\.isCompleted).count
            if let exercise = exerciseById[entry.exerciseId], exercise.movementPattern.isCompound {
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

        let feedExercises: [FeedExercise] = exerciseEntries.compactMap { entry in
            let completed = entry.sets.filter(\.isCompleted)
            guard !completed.isEmpty else { return nil }
            let exercise = exerciseById[entry.exerciseId]
            return FeedExercise(
                id: entry.id.uuidString,
                name: entry.exerciseName,
                sets: completed.map { s in
                    FeedSetLog(
                        weight: Double(s.weight) ?? 0,
                        reps: Int(s.reps) ?? 0,
                        duration: Int(s.duration) ?? 0,
                        distance: Double(s.distance) ?? 0,
                        setType: s.setType.rawValue,
                        side: s.side == .both ? nil : s.side.rawValue
                    )
                },
                improvementScore: improvementScores[entry.id] ?? 0,
                weightDelta: weightDeltas[entry.id] ?? 0,
                repsDelta: repsDeltas[entry.id] ?? 0,
                primaryMuscles: exercise?.primaryMuscleGroups.map(\.displayName) ?? [],
                secondaryMuscles: exercise?.secondaryMuscleGroups.map(\.displayName) ?? []
            )
        }

        let allWorkoutDates = (try? modelContext.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { !$0.isDraft }
        )).map(\.date)) ?? []
        let streakCount = max(1, StreakCalculator.currentStreak(from: allWorkoutDates))

        completionData = WorkoutCompletionData(
            duration: workout.duration,
            calories: workout.calorieBurnEstimate,
            exerciseCount: exerciseEntries.filter { !$0.sets.filter(\.isCompleted).isEmpty }.count,
            totalSets: totalSets,
            prCount: prCount,
            improvedCount: improvedCount,
            totalExercises: exerciseEntries.count,
            streakCount: streakCount,
            prDetails: prDetails.sorted { $0.impressivenessScore > $1.impressivenessScore },
            musclesWorked: collectMusclesWorked(modelContext: modelContext),
            exercises: feedExercises,
            workoutName: workout.template?.name
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
                date: workout.date,
                exercises: data.exercises
            )
            Task {
                try? await FirestoreService().shareWorkoutToFeed(feedItem)
            }
        }

        // Update widget data
        WidgetDataService.updateWidgetData(modelContext: modelContext)

        isActive = false
        showCompletionSummary = true
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

#if DEBUG
    func showPreviewCompletion() {
        completionData = WorkoutCompletionData.preview
        showCompletionSummary = true
    }
#endif

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

    // MARK: - PR Detection (live, during workout)

    func checkPR(exerciseIndex: Int, setIndex: Int, modelContext: ModelContext) {
        guard exerciseEntries.indices.contains(exerciseIndex),
              exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }

        let entry = exerciseEntries[exerciseIndex]
        let set = entry.sets[setIndex]
        let weight = Double(set.weight) ?? 0
        let reps = Int(set.reps) ?? 0

        guard weight > 0 || reps > 0 else { return }

        let exId = entry.exerciseId
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in
                log.exercise?.id == exId
            },
            sortBy: [SortDescriptor(\ExerciseLog.createdAt, order: .reverse)]
        )

        guard let previousLogs = try? modelContext.fetch(descriptor),
              !previousLogs.isEmpty else { return }

        let allPreviousSets = previousLogs.flatMap(\.sets)
        guard !allPreviousSets.isEmpty else { return }

        // Weight PR
        let previousMaxWeight = allPreviousSets.map(\.weight).max() ?? 0
        if weight > previousMaxWeight {
            exerciseEntries[exerciseIndex].sets[setIndex].isPR = true
            return
        }

        // Rep PR: more reps than ever done at this weight or lighter
        if weight > 0 && reps > 0 {
            let previousMaxReps = allPreviousSets.filter { $0.weight <= weight + 0.01 }.map(\.reps).max() ?? 0
            if reps > previousMaxReps && previousMaxReps > 0 {
                exerciseEntries[exerciseIndex].sets[setIndex].isPR = true
            }
        }
    }

    // MARK: - Smart Prediction

    func predictNextWorkout(user: User, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { !$0.isDraft },
            sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
        )
        if let recent = try? modelContext.fetch(descriptor), !recent.isEmpty {
            let names = recent.prefix(14).compactMap { $0.template?.name }
            if let detected = detectNextByPattern(from: names) {
                return detected
            }
        }

        // Fall back to split schedule (no history)
        guard let split = user.selectedSplit else { return nil }
        let days = split.days.sorted(by: { $0.dayOfWeek < $1.dayOfWeek })
        guard !days.isEmpty else { return split.type.displayName }
        return days.first?.label
    }

    /// Frequency-based pattern detection: builds a map of "what workout
    /// most often followed each workout" from history, then returns
    /// the most common successor of the last session done.
    /// Works for PPL, U/L, Full Body every-other-day, Bro splits, etc.
    /// — no day-of-week assumptions.
    private func detectNextByPattern(from names: [String]) -> String? {
        guard names.count >= 2, let last = names.first else { return nil }
        let lastKey = last.lowercased()

        // Build frequency map: predecessor (lowercased) → [successor (actual case): count]
        // names is newest-first; names[i] came AFTER names[i+1] in real time
        var followMap: [String: [String: Int]] = [:]
        for i in 1..<names.count {
            let predecessor = names[i].lowercased()
            let successor   = names[i - 1]          // keep actual casing
            followMap[predecessor, default: [:]][successor, default: 0] += 1
        }

        // If we have a clear winner successor for the last workout, return it
        if let candidates = followMap[lastKey], !candidates.isEmpty {
            let best = candidates.max(by: { $0.value < $1.value })!
            // Only trust it if seen at least once (or it's the only option)
            return best.key
        }

        // Fuzzy keyword fallback for named splits
        let lower = lastKey
        if lower.contains("push") { return names.first(where: { $0.lowercased().contains("pull") }) ?? "Pull Day" }
        if lower.contains("pull") { return names.first(where: { $0.lowercased().contains("leg") })  ?? "Leg Day" }
        if lower.contains("leg")  { return names.first(where: { $0.lowercased().contains("push") }) ?? "Push Day" }
        if lower.contains("upper") { return names.first(where: { $0.lowercased().contains("lower") }) ?? "Lower" }
        if lower.contains("lower") { return names.first(where: { $0.lowercased().contains("upper") }) ?? "Upper" }
        if lower.contains("full")  { return last }

        return nil
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        let timerInstance = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let start = self.startTime else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
                let state = self.makeLiveActivityState()
                Task { await self.liveActivity.updateLiveActivity(state) }
            }
        }
        durationTimer = timerInstance
    }

    // MARK: - Live Activity state + intents

    /// Position of the next set to perform.
    private var nextSetPosition: (exercise: Int, set: Int)? {
        for (i, entry) in exerciseEntries.enumerated() {
            if let j = entry.sets.firstIndex(where: { !$0.isCompleted }) { return (i, j) }
        }
        return nil
    }

    private func plannedValues(exercise ei: Int, set si: Int) -> (weight: String, reps: String) {
        let entry = exerciseEntries[ei]
        let set = entry.sets[si]
        var weight = set.weight
        var reps = set.reps
        if (weight.isEmpty || reps.isEmpty), let ctx = liveModelContext,
           let ghost = ghostText(for: entry.exerciseId, setIndex: si, modelContext: ctx) {
            if weight.isEmpty { weight = ghost.weight }
            if reps.isEmpty { reps = ghost.reps }
        }
        // Fall back to the previous set of this lift, then the template target
        if weight.isEmpty, si > 0 { weight = entry.sets[si - 1].weight }
        if reps.isEmpty { reps = set.targetReps.map(String.init) ?? (si > 0 ? entry.sets[si - 1].reps : "") }
        return (weight, reps)
    }

    private func lastTime(for entry: ExerciseEntry) -> (line: String, date: String) {
        if let cached = lastTimeCache[entry.exerciseId] { return cached }
        var result = (line: "", date: "")
        if let ctx = liveModelContext {
            let id = entry.exerciseId
            let descriptor = FetchDescriptor<ExerciseLog>(
                predicate: #Predicate<ExerciseLog> { $0.exercise?.id == id },
                sortBy: [SortDescriptor(\ExerciseLog.createdAt, order: .reverse)]
            )
            if let log = try? ctx.fetch(descriptor).first {
                let sets = log.sets.sorted { $0.order < $1.order }.prefix(4)
                result.line = sets.map { String(format: "%g", $0.weight) + " × " + String($0.reps) }.joined(separator: " · ")
                var parts: [String] = []
                if let name = log.workout?.template?.name { parts.append(name.uppercased()) }
                if let d = log.workout?.duration, d > 0 {
                    parts.append(String(format: "%d:%02d", Int(d) / 60, Int(d) % 60))
                }
                result.date = parts.joined(separator: " · ")
            }
        }
        lastTimeCache[entry.exerciseId] = result
        return result
    }

    private func makeLiveActivityState() -> WorkoutActivityAttributes.ContentState {
        let completed = exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
        let total = exerciseEntries.flatMap(\.sets).count

        // Stable rest end date (avoid sub-second jitter so unchanged states dedupe)
        var restStart: Date?
        var restEnd: Date?
        if restTimer.isRunning {
            let candidate = Date().addingTimeInterval(TimeInterval(restTimer.remainingSeconds))
            if let cached = cachedRestEnd, abs(cached.timeIntervalSince(candidate)) < 1.5 {
                restEnd = cached
            } else {
                restEnd = candidate
                cachedRestEnd = candidate
            }
            restStart = restEnd!.addingTimeInterval(-TimeInterval(max(restTimer.totalSeconds, restTimer.remainingSeconds)))
        } else {
            cachedRestEnd = nil
        }

        var state = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            currentExercise: "Rest",
            completedSets: completed,
            totalSets: total,
            restSecondsRemaining: restTimer.isRunning ? restTimer.remainingSeconds : 0
        )
        state.restStartDate = restStart
        state.restEndDate = restEnd
        state.restOverSince = restTimer.isRunning ? nil : restTimer.completedAt
        if let pos = nextSetPosition {
            let entry = exerciseEntries[pos.exercise]
            let planned = plannedValues(exercise: pos.exercise, set: pos.set)
            let last = lastTime(for: entry)
            state.currentExercise = entry.exerciseName
            state.exerciseShort = String((entry.exerciseName.uppercased().split(separator: " ").first ?? "").prefix(8))
            state.setIndex = pos.set + 1
            state.setCount = entry.sets.count
            state.nextWeight = planned.weight
            state.nextReps = planned.reps
            state.lastTime = last.line
            state.lastTimeDate = last.date
        }
        return state
    }

    private func installLiveActivityObservers() {
        guard liveObservers.isEmpty else { return }
        let nc = NotificationCenter.default
        liveObservers.append(nc.addObserver(forName: .pumpLiveActivityAdjustRest, object: nil, queue: .main) { [weak self] note in
            let delta = note.userInfo?["delta"] as? Int ?? 0
            MainActor.assumeIsolated { self?.restTimer.adjust(by: delta); self?.pushLiveActivityNow() }
        })
        liveObservers.append(nc.addObserver(forName: .pumpLiveActivitySkipRest, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restTimer.skip(); self?.pushLiveActivityNow() }
        })
        liveObservers.append(nc.addObserver(forName: .pumpLiveActivityLogSet, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.logNextSetFromLiveActivity() }
        })
    }

    private func removeLiveActivityObservers() {
        liveObservers.forEach(NotificationCenter.default.removeObserver)
        liveObservers = []
    }

    private func pushLiveActivityNow() {
        let state = makeLiveActivityState()
        Task { await liveActivity.updateLiveActivity(state) }
    }

    /// Marks the next set done with its planned weight/reps (Live Activity LOG SET).
    func logNextSetFromLiveActivity() {
        guard isActive, let pos = nextSetPosition else { return }
        let planned = plannedValues(exercise: pos.exercise, set: pos.set)
        if exerciseEntries[pos.exercise].sets[pos.set].weight.isEmpty { exerciseEntries[pos.exercise].sets[pos.set].weight = planned.weight }
        if exerciseEntries[pos.exercise].sets[pos.set].reps.isEmpty { exerciseEntries[pos.exercise].sets[pos.set].reps = planned.reps }
        logSet(exerciseIndex: pos.exercise, setIndex: pos.set, isCompound: true)
        pushLiveActivityNow()
    }

    private func stopDurationTimer() {
        removeLiveActivityObservers()
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
    var isPR: Bool = false
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

struct PRDetail {
    let exerciseName: String
    let weightDelta: Double  // kg gained (0 for rep PRs)
    let repsDelta: Int       // reps gained (0 for weight PRs)
    let isWeightPR: Bool
    let impressivenessScore: Double  // for sorting
}

struct WorkoutCompletionData {
    let duration: TimeInterval
    let calories: Double
    let exerciseCount: Int
    let totalSets: Int
    let prCount: Int
    let improvedCount: Int
    let totalExercises: Int
    let streakCount: Int
    let prDetails: [PRDetail]
    let musclesWorked: Set<MuscleGroup>
    let exercises: [FeedExercise]
    let workoutName: String?

    var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m) min"
    }

    static var preview: WorkoutCompletionData {
        func sets(_ pairs: [(Double, Int)]) -> [FeedSetLog] {
            pairs.map { FeedSetLog(weight: $0.0, reps: $0.1, duration: 0, distance: 0, setType: "working", side: nil) }
        }
        // 5 PRs (weight), 1 improvement (no PR), 4 same/worse. Muscle tags match the real
        // seeded catalog's primary/secondary convention (ExerciseSeedService) so the
        // preview's body map shows the same weighted-not-even heat a real session would.
        func mg(_ names: MuscleGroup...) -> [String] { names.map(\.displayName) }
        let exercises: [FeedExercise] = [
            FeedExercise(id: "1",  name: "Bench Press",      sets: sets([(100,5),(105,4),(110,3)]),  improvementScore: 14, weightDelta: 5,   primaryMuscles: mg(.chest), secondaryMuscles: mg(.triceps, .frontDelts)),  // PR ★
            FeedExercise(id: "2",  name: "Overhead Press",   sets: sets([(60,8),(62.5,7),(65,5)]),   improvementScore: 11, weightDelta: 2.5, primaryMuscles: mg(.frontDelts, .shoulders), secondaryMuscles: mg(.triceps)),  // PR ★
            FeedExercise(id: "3",  name: "Incline DB Press", sets: sets([(36,10),(38,8),(38,7)]),    improvementScore: 9,  weightDelta: 2,   primaryMuscles: mg(.chest), secondaryMuscles: mg(.triceps, .frontDelts)),   // PR ★
            FeedExercise(id: "4",  name: "Skull Crusher",    sets: sets([(32.5,10),(35,8),(35,7)]),  improvementScore: 7,  weightDelta: 2.5, primaryMuscles: mg(.triceps), secondaryMuscles: []),   // PR ★
            FeedExercise(id: "5",  name: "Tricep Pushdown",  sets: sets([(42.5,12),(45,10),(45,9)]), improvementScore: 5,  weightDelta: 2.5, primaryMuscles: mg(.triceps), secondaryMuscles: []),   // PR ★
            FeedExercise(id: "6",  name: "Cable Fly",        sets: sets([(20,12),(20,12),(22,10)]),  improvementScore: 4,  weightDelta: 2,   primaryMuscles: mg(.chest), secondaryMuscles: []),  // improved, no PR
            FeedExercise(id: "7",  name: "Lateral Raise",    sets: sets([(12,15),(12,12),(12,12)]),  improvementScore: 0,  primaryMuscles: mg(.sideDelts, .shoulders), secondaryMuscles: []),  // same
            FeedExercise(id: "8",  name: "Face Pull",        sets: sets([(25,15),(25,15),(25,12)]),  improvementScore: 0,  primaryMuscles: mg(.rearDelts), secondaryMuscles: mg(.traps)),  // same
            FeedExercise(id: "9",  name: "Chest Dip",        sets: sets([(0,12),(0,10),(0,8)]),      improvementScore: -3, primaryMuscles: mg(.chest), secondaryMuscles: mg(.triceps)),  // worse
            FeedExercise(id: "10", name: "Pec Deck",         sets: sets([(55,10),(55,8),(50,8)]),    improvementScore: -5, primaryMuscles: mg(.chest), secondaryMuscles: []),  // worse
        ]
        let prs: [PRDetail] = [
            PRDetail(exerciseName: "Bench Press",      weightDelta: 5,   repsDelta: 0, isWeightPR: true,  impressivenessScore: 4.5),
            PRDetail(exerciseName: "Overhead Press",   weightDelta: 2.5, repsDelta: 0, isWeightPR: true,  impressivenessScore: 4.0),
            PRDetail(exerciseName: "Incline DB Press", weightDelta: 2,   repsDelta: 0, isWeightPR: true,  impressivenessScore: 3.1),
            PRDetail(exerciseName: "Skull Crusher",    weightDelta: 2.5, repsDelta: 0, isWeightPR: true,  impressivenessScore: 2.8),
            PRDetail(exerciseName: "Tricep Pushdown",  weightDelta: 2.5, repsDelta: 0, isWeightPR: true,  impressivenessScore: 2.4),
        ]
        return WorkoutCompletionData(
            duration: 4680,
            calories: 412,
            exerciseCount: 10,
            totalSets: 30,
            prCount: 5,
            improvedCount: 6,
            totalExercises: 10,
            streakCount: 5,
            prDetails: prs,
            musclesWorked: [.chest, .shoulders, .triceps],
            exercises: exercises,
            workoutName: "Push Day A"
        )
    }
}
