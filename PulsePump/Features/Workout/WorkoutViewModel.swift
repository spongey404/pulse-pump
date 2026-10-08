import SwiftUI
import SwiftData
import Observation

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
    var durationTimer: Timer?

    // Rest timer
    let restTimer: RestTimerService

    init(restTimer: RestTimerService? = nil) {
        self.restTimer = restTimer ?? RestTimerService()
    }

    // Live Activity
    let liveActivity = LiveActivityService()
    /// Context used for draft persistence + live-activity lookups while a session is active.
    var liveModelContext: ModelContext?
    var liveObservers: [NSObjectProtocol] = []
    var lastTimeCache: [UUID: (line: String, date: String)] = [:]

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
        exerciseEntries = []
        workoutNotes = ""
        elapsedSeconds = 0
        lastTimeCache = [:]

        let newWorkout = Workout(isDraft: true)
        newWorkout.user = user
        newWorkout.template = template
        modelContext.insert(newWorkout)
        workout = newWorkout
        liveModelContext = modelContext
        installLiveActivityObservers()

        if let template {
            for templateExercise in template.templateExercises.sorted(by: { $0.order < $1.order }) {
                // Link by id; fall back to the (normalised) name so presets and imported templates
                // whose ids don't match the catalogue still log against the real exercise.
                let exercise = Self.findExercise(id: templateExercise.exerciseId, name: templateExercise.exerciseName,
                                                 modelContext: modelContext)
                var entry = ExerciseEntry(
                    exerciseId: exercise?.id ?? templateExercise.exerciseId,
                    exerciseName: exercise?.name ?? templateExercise.exerciseName,
                    sets: (0..<max(templateExercise.targetSets, 0)).map { i in
                        SetEntry(order: i, targetReps: templateExercise.targetReps, targetRIR: templateExercise.targetRIR)
                    }
                )
                entry.apply(exercise)
                entry.restSeconds = templateExercise.restSeconds
                exerciseEntries.append(entry)
            }
        }

        isActive = true
        startTime = Date()
        startDurationTimer()
        liveActivity.startLiveActivity(workoutName: workout?.template?.name ?? "Workout")
        persistDraft(modelContext: modelContext)
    }

    /// Exercise by id, else by normalised name (case/whitespace/punctuation-insensitive).
    static func findExercise(id: UUID, name: String, modelContext: ModelContext) -> Exercise? {
        let byId = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })
        if let hit = try? modelContext.fetch(byId).first { return hit }
        let key = Exercise.normalisedName(name)
        guard !key.isEmpty else { return nil }
        let all = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        return all.first { Exercise.normalisedName($0.name) == key }
    }

    // MARK: - Exercise Management

    func addExercise(_ exercise: Exercise) {
        var entry = ExerciseEntry(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            sets: [SetEntry(order: 0)]
        )
        entry.apply(exercise)
        exerciseEntries.append(entry)
        persistDraftIfActive()
    }

    func removeExercise(at index: Int) {
        guard exerciseEntries.indices.contains(index) else { return }
        exerciseEntries.remove(at: index)
        persistDraftIfActive()
    }

    func replaceExercise(at index: Int, with exercise: Exercise) {
        guard exerciseEntries.indices.contains(index) else { return }
        exerciseEntries[index].exerciseId = exercise.id
        exerciseEntries[index].exerciseName = exercise.name
        exerciseEntries[index].apply(exercise)
        persistDraftIfActive()
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        exerciseEntries.move(fromOffsets: source, toOffset: destination)
        persistDraftIfActive()
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
        let wasCompleted = exerciseEntries[exerciseIndex].sets[setIndex].isCompleted
        exerciseEntries[exerciseIndex].sets.remove(at: setIndex)
        if wasCompleted { persistDraftIfActive() }
    }

    /// Marks a set done. When the weight/reps fields are empty but the row shows the previous
    /// session's ghost placeholders, those ghost values are saved (and only then).
    func logSet(exerciseIndex: Int, setIndex: Int, modelContext: ModelContext? = nil) {
        guard exerciseEntries.indices.contains(exerciseIndex),
              exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }
        if let ctx = modelContext ?? liveModelContext {
            applyGhostValues(exerciseIndex: exerciseIndex, setIndex: setIndex, modelContext: ctx)
        }
        exerciseEntries[exerciseIndex].sets[setIndex].isCompleted = true
        restTimer.clearCompletion()

        updateLiveCalories()
        persistDraftIfActive()

        if restTimer.mode == .autoStart || restTimer.mode == .autoStartWithDismiss {
            let entry = exerciseEntries[exerciseIndex]
            let duration = restTimer.restDuration(isCompound: entry.isCompound, exerciseId: entry.exerciseId,
                                                  templateSeconds: entry.restSeconds)
            restTimer.start(seconds: duration)
        }
    }

    /// The user un-ticked a completed set: it leaves the persisted draft too.
    func unlogSet(exerciseIndex: Int, setIndex: Int) {
        guard exerciseEntries.indices.contains(exerciseIndex),
              exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exerciseEntries[exerciseIndex].sets[setIndex].isCompleted = false
        updateLiveCalories()
        persistDraftIfActive()
    }

    /// Fills empty weight/reps from the previous session's same-position set.
    func applyGhostValues(exerciseIndex: Int, setIndex: Int, modelContext: ModelContext) {
        let entry = exerciseEntries[exerciseIndex]
        // Time/distance exercises show no weight/reps ghost, so there is nothing to save.
        guard entry.exerciseType != .timeBased, entry.exerciseType != .distanceBased else { return }
        guard let ghost = ghostText(for: entry.exerciseId, setIndex: setIndex, modelContext: modelContext) else { return }
        if exerciseEntries[exerciseIndex].sets[setIndex].weight.trimmingCharacters(in: .whitespaces).isEmpty, !ghost.weight.isEmpty {
            exerciseEntries[exerciseIndex].sets[setIndex].weight = ghost.weight
        }
        if exerciseEntries[exerciseIndex].sets[setIndex].reps.trimmingCharacters(in: .whitespaces).isEmpty, !ghost.reps.isEmpty {
            exerciseEntries[exerciseIndex].sets[setIndex].reps = ghost.reps
        }
    }

    func updateLiveCalories() {
        var compoundSets = 0
        var isolationSets = 0
        var totalCompleted = 0
        for entry in exerciseEntries {
            let completed = entry.sets.filter { $0.isCompleted && $0.setType != .warmup }.count
            totalCompleted += completed
            if entry.isCompound { compoundSets += completed } else { isolationSets += completed }
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

    /// Previous finished session's value for the same set position (draft sessions excluded).
    func ghostText(for exerciseId: UUID, setIndex: Int, modelContext: ModelContext) -> (weight: String, reps: String)? {
        guard let previousLog = modelContext.finalLogs(forExercise: exerciseId, limit: 1).first else { return nil }
        let sorted = previousLog.sets.sorted(by: { $0.order < $1.order })
        guard setIndex < sorted.count else { return nil }
        let previousSet = sorted[setIndex]
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
        workout.updatedAt = Date()

        // Convert the draft in place: reconcile the already-persisted logs, drop empty exercises.
        persistDraft(modelContext: modelContext, final: true)
        workout.isDraft = false
        try? modelContext.save()

        let exerciseById = Self.exerciseLookup(modelContext)

        var prCount = 0
        var improvedCount = 0
        var improvementScores: [UUID: Double] = [:]  // entry.id → % 1RM gain
        var weightDeltas: [UUID: Double] = [:]  // entry.id → kg gained on the best set vs last time
        var repsDeltas: [UUID: Int] = [:]       // entry.id → reps gained at the same weight vs last time
        var prDetails: [PRDetail] = []
        var totalWorkingSets = 0
        var compoundSets = 0
        var isolationSets = 0
        var countedExercises = 0

        for entry in exerciseEntries {
            // Warm-ups are saved, but never count toward sets, volume, PRs or calories.
            let working = entry.sets.filter { $0.isCompleted && $0.setType != .warmup }
            guard !working.isEmpty else { continue }
            countedExercises += 1
            totalWorkingSets += working.count
            if entry.isCompound { compoundSets += working.count } else { isolationSets += working.count }

            guard let exercise = exerciseById[entry.exerciseId] else { continue }
            let weights = working.map { parseDecimal($0.weight) ?? 0 }
            let reps = working.map { parseWholeNumber($0.reps) ?? 0 }
            let bestWeight = weights.max() ?? 0

            let previousSets = exercise.finalLogs
                .filter { $0.workout?.id != workout.id }
                .flatMap(\.workingSets)
            let previousBestWeight = previousSets.map(\.weight).max() ?? 0
            let bestRepsThisWorkout = reps.max() ?? 0
            let previousMaxReps = previousSets.filter { $0.weight <= bestWeight + 0.01 }.map(\.reps).max() ?? 0

            let current1RM = zip(weights, reps).map { Self.epley($0, $1) }.max() ?? 0
            let previous1RM = previousSets.map { Self.epley($0.weight, $0.reps) }.max() ?? 0

            if bestWeight > previousBestWeight && previousBestWeight > 0 {
                prCount += 1
                let score = (bestWeight - previousBestWeight) / previousBestWeight * 100
                prDetails.append(PRDetail(
                    exerciseName: entry.exerciseName,
                    weightDelta: bestWeight - previousBestWeight,
                    repsDelta: 0,
                    isWeightPR: true,
                    impressivenessScore: score
                ))
                weightDeltas[entry.id] = bestWeight - previousBestWeight
            } else if bestRepsThisWorkout > previousMaxReps && previousMaxReps > 0 {
                prCount += 1
                let score = Double(bestRepsThisWorkout - previousMaxReps) / Double(previousMaxReps) * 100 * 0.5
                prDetails.append(PRDetail(
                    exerciseName: entry.exerciseName,
                    weightDelta: 0,
                    repsDelta: bestRepsThisWorkout - previousMaxReps,
                    isWeightPR: false,
                    impressivenessScore: score
                ))
                // The feed's "VS LAST" column shows this raw kg/rep gain, not a %.
                repsDeltas[entry.id] = bestRepsThisWorkout - previousMaxReps
            }
            if previous1RM > 0 {
                // "Improved" means a better estimated 1RM than last time, not merely matching it.
                if current1RM > previous1RM + 0.01 { improvedCount += 1 }
                improvementScores[entry.id] = max(0, (current1RM - previous1RM) / previous1RM * 100)
            }
        }

        // Calorie estimate using CalorieEstimationService
        let userWeight = workout.user?.weight ?? 0
        let durationMinutes = workout.duration / 60.0
        let formula = CalorieFormula(rawValue: UserDefaults.standard.string(forKey: "calorieFormula") ?? "") ?? .basic
        workout.calorieBurnEstimate = CalorieEstimationService.estimate(
            formula: formula,
            totalSets: totalWorkingSets,
            compoundSets: compoundSets,
            isolationSets: isolationSets,
            bodyWeightKg: userWeight,
            durationMinutes: durationMinutes,
            intensity: .moderate
        )

        let feedExercises: [FeedExercise] = exerciseEntries.compactMap { entry in
            let completed = entry.sets.filter(\.isCompleted)
            guard completed.contains(where: { $0.setType != .warmup }) else { return nil }
            let exercise = exerciseById[entry.exerciseId]
            return FeedExercise(
                id: entry.id.uuidString,
                name: entry.exerciseName,
                sets: completed.map { s in
                    FeedSetLog(
                        weight: parseDecimal(s.weight) ?? 0,
                        reps: parseWholeNumber(s.reps) ?? 0,
                        duration: Int(parseDecimal(s.duration) ?? 0),
                        distance: parseDecimal(s.distance) ?? 0,
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
            exerciseCount: countedExercises,
            totalSets: totalWorkingSets,
            prCount: prCount,
            improvedCount: improvedCount,
            totalExercises: countedExercises,
            streakCount: streakCount,
            prDetails: prDetails.sorted { $0.impressivenessScore > $1.impressivenessScore },
            musclesWorked: collectMusclesWorked(exerciseById: exerciseById),
            exercises: feedExercises,
            workoutName: workout.template?.name,
            workoutId: workout.id
        )

        // Posting to the feed is NOT done here: the completion composer owns that decision
        // (Post / Don't post / auto-share), so a workout is posted at most once.

        // Update widget data
        WidgetDataService.updateWidgetData(modelContext: modelContext)

        isActive = false
        showCompletionSummary = true
    }

    /// Epley estimated 1RM; reps-only sets fall back to the rep count.
    static func epley(_ weight: Double, _ reps: Int) -> Double {
        weight > 0 ? weight * (1 + Double(reps) / 30) : Double(reps)
    }

    static func exerciseLookup(_ modelContext: ModelContext) -> [UUID: Exercise] {
        Dictionary(((try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.id, $0) },
                   uniquingKeysWith: { first, _ in first })
    }

    func cancelWorkout(modelContext: ModelContext) {
        stopDurationTimer()
        restTimer.stop()

        if let workout {
            modelContext.delete(workout)
        }

        reset()
    }

    func reset() {
        removeLiveActivityObservers()
        workout = nil
        exerciseEntries = []
        workoutNotes = ""
        isActive = false
        elapsedSeconds = 0
        startTime = nil
        completionData = nil
        showCompletionSummary = false
        liveModelContext = nil
        lastTimeCache = [:]
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
        let recentLogs = modelContext.finalLogs(forExercise: exerciseId)
        guard recentLogs.count >= 2 else { return nil }

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
        guard set.setType != .warmup else { return }
        let weight = parseDecimal(set.weight) ?? 0
        let reps = parseWholeNumber(set.reps) ?? 0

        guard weight > 0 || reps > 0 else { return }

        let previousLogs = modelContext.finalLogs(forExercise: entry.exerciseId)
        let allPreviousSets = previousLogs.flatMap(\.workingSets)
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

    /// Next workout name. Pattern-detected names are only used when they match a real template;
    /// otherwise the split's next day (resolved to a template when possible) is used.
    func predictNextWorkout(user: User, modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { !$0.isDraft },
            sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
        )
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        let history = recent.prefix(14).compactMap { $0.template?.name }
        let templateNames = ((try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []).map(\.name)
        return WorkoutPredictor.predict(
            history: Array(history),
            templateNames: templateNames,
            split: user.selectedSplit,
            todayWeekday: Calendar.current.component(.weekday, from: Date())
        )
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        durationTimer?.invalidate()
        let timerInstance = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let start = self.startTime else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
                let state = self.makeLiveActivityState()
                Task { await self.liveActivity.updateLiveActivity(state) }
            }
        }
        RunLoop.main.add(timerInstance, forMode: .common)
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

    /// Display unit for Live Activity text. All VM values (SetEntry.weight, SetLog.weight) stay kg.
    private var displayUnit: UnitPreference { workout?.user?.unitPreference ?? UnitPreference.current }

    private func lastTime(for entry: ExerciseEntry) -> (line: String, date: String) {
        if let cached = lastTimeCache[entry.exerciseId] { return cached }
        var result = (line: "", date: "")
        if let ctx = liveModelContext, let log = ctx.finalLogs(forExercise: entry.exerciseId, limit: 1).first {
            let sets = log.workingSets.sorted { $0.order < $1.order }.prefix(4)
            result.line = sets.map { displayUnit.number($0.weight) + " × " + String($0.reps) }.joined(separator: " · ")
            var parts: [String] = []
            if let name = log.workout?.template?.name { parts.append(name.uppercased()) }
            if let d = log.workout?.duration, d > 0 {
                parts.append(String(format: "%d:%02d", Int(d) / 60, Int(d) % 60))
            }
            result.date = parts.joined(separator: " · ")
        }
        lastTimeCache[entry.exerciseId] = result
        return result
    }

    private func makeLiveActivityState() -> WorkoutActivityAttributes.ContentState {
        let completed = exerciseEntries.flatMap(\.sets).filter(\.isCompleted).count
        let total = exerciseEntries.flatMap(\.sets).count

        // The rest timer is end-date based, so the Live Activity gets its exact (stable) end date.
        var restStart: Date?
        var restEnd: Date?
        if restTimer.isRunning, let end = restTimer.endDate {
            restEnd = end
            restStart = end.addingTimeInterval(-TimeInterval(max(restTimer.totalSeconds, restTimer.remainingSeconds)))
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
            state.nextWeight = displayUnit.displayText(kgString: planned.weight)   // planned.weight is kg
            state.weightUnit = displayUnit.label
            state.nextReps = planned.reps
            state.lastTime = last.line
            state.lastTimeDate = last.date
        }
        return state
    }

    func installLiveActivityObservers() {
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

    func removeLiveActivityObservers() {
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
        logSet(exerciseIndex: pos.exercise, setIndex: pos.set)
        pushLiveActivityNow()
    }

    func stopDurationTimer() {
        removeLiveActivityObservers()
        durationTimer?.invalidate()
        durationTimer = nil
        Task { await liveActivity.endLiveActivity() }
    }

    func beginDurationTimer() { startDurationTimer() }

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

    private func collectMusclesWorked(exerciseById: [UUID: Exercise]) -> Set<MuscleGroup> {
        var muscles = Set<MuscleGroup>()
        for entry in exerciseEntries where entry.sets.contains(where: { $0.isCompleted && $0.setType != .warmup }) {
            guard let exercise = exerciseById[entry.exerciseId] else { continue }
            muscles.formUnion(exercise.primaryMuscleGroups)
            muscles.formUnion(exercise.secondaryMuscleGroups)
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
    /// Compound lifts rest longer than isolation (global compound/isolation rest settings).
    var isCompound: Bool = true
    /// Template-specified rest for this exercise, if any.
    var restSeconds: Int?
    var sets: [SetEntry]
    var notes: String = ""
    /// The persisted `ExerciseLog` this entry maps to (draft persistence / resume).
    var logId: UUID?

    /// Copies the catalogue traits (type, unilateral, equipment, compound) from `exercise`.
    mutating func apply(_ exercise: Exercise?) {
        guard let exercise else { return }
        exerciseType = exercise.exerciseType
        isUnilateral = exercise.isUnilateral
        equipmentType = exercise.equipmentType
        isCompound = exercise.movementPattern.isCompound
    }
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
    /// The persisted `SetLog` this completed set maps to (draft persistence / resume).
    var logId: UUID?

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
    /// The finished `Workout`'s id — also the idempotent feed-post id, so a workout posts at most once.
    var workoutId: UUID?

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
