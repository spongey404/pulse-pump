import Foundation
import SwiftData

// Draft persistence / crash recovery.
//
// While a session is active its `Workout` is a draft (`isDraft == true`). Every completed set,
// exercise add/remove/reorder/replace, app-backgrounding and "Save as draft" reconciles the
// in-memory entries into `ExerciseLog` / `SetLog` records (keyed by stable ids, so nothing is
// duplicated). Only completed sets are persisted; un-ticked rows are re-created from the
// template on resume. Finishing the workout runs the same reconcile with `final: true`, flips
// `isDraft` and drops empty exercises: the draft *becomes* the final workout.
// Nothing here runs per keystroke.

extension WorkoutViewModel {

    /// Persist when a session is active and a context is known (no-op otherwise).
    func persistDraftIfActive() {
        guard isActive, workout != nil, let ctx = liveModelContext else { return }
        persistDraft(modelContext: ctx)
    }

    /// App went to the background: persist everything needed to recover the session.
    func saveDraft() { persistDraftIfActive() }

    /// "Save as draft": persist, stop the clocks/Live Activity and leave the session. The draft
    /// stays in SwiftData; the Continue card on Home resumes it.
    func saveDraftAndClose(modelContext: ModelContext) {
        persistDraft(modelContext: modelContext)
        stopDurationTimer()
        restTimer.stop()
        reset()
    }

    /// Reconciles `exerciseEntries` into the workout's `ExerciseLog`/`SetLog` records.
    func persistDraft(modelContext: ModelContext, final: Bool = false) {
        guard let workout else { return }
        workout.duration = TimeInterval(elapsedSeconds)
        workout.notes = workoutNotes
        workout.markUpdated()

        let exerciseById = Self.exerciseLookup(modelContext)
        let existingLogs = Dictionary(workout.exerciseLogs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var keptLogIds = Set<UUID>()
        var order = 0

        for i in exerciseEntries.indices {
            let completed = exerciseEntries[i].sets.indices.filter { exerciseEntries[i].sets[$0].isCompleted }
            if final && completed.isEmpty { continue }

            let log: ExerciseLog
            if let id = exerciseEntries[i].logId, let existing = existingLogs[id] {
                log = existing
            } else {
                log = ExerciseLog(order: order, notes: exerciseEntries[i].notes)
                modelContext.insert(log)
                log.workout = workout
                exerciseEntries[i].logId = log.id
            }
            keptLogIds.insert(log.id)
            log.order = order
            order += 1
            log.notes = exerciseEntries[i].notes
            log.exercise = exerciseById[exerciseEntries[i].exerciseId]
            log.updatedAt = Date()

            let existingSets = Dictionary(log.sets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var keptSetIds = Set<UUID>()
            for (j, si) in completed.enumerated() {
                let entry = exerciseEntries[i].sets[si]
                let setLog: SetLog
                if let id = entry.logId, let existing = existingSets[id] {
                    setLog = existing
                } else {
                    setLog = SetLog(order: j)
                    modelContext.insert(setLog)
                    setLog.exerciseLog = log
                    exerciseEntries[i].sets[si].logId = setLog.id
                }
                keptSetIds.insert(setLog.id)
                setLog.order = j
                setLog.weight = parseDecimal(entry.weight) ?? 0
                setLog.reps = parseWholeNumber(entry.reps) ?? 0
                setLog.rir = parseWholeNumber(entry.rir)
                setLog.duration = parseDecimal(entry.duration).map { TimeInterval($0) }
                setLog.distance = parseDecimal(entry.distance)
                setLog.setType = entry.setType
                setLog.side = entry.side
            }
            for setLog in log.sets where !keptSetIds.contains(setLog.id) { modelContext.delete(setLog) }
        }
        for log in workout.exerciseLogs where !keptLogIds.contains(log.id) { modelContext.delete(log) }
        try? modelContext.save()
    }

    /// Restores an interrupted session (crash, background kill or "Save as draft") exactly as
    /// persisted: exercises, completed sets with their types/sides, notes and elapsed time. Rows
    /// that were not yet logged are rebuilt from the template's targets.
    func resumeDraft(workout: Workout, modelContext: ModelContext) {
        // Never stack a resumed draft on top of leftover in-memory state.
        durationTimer?.invalidate()
        exerciseEntries = []
        lastTimeCache = [:]

        self.workout = workout
        self.workoutNotes = workout.notes
        self.liveModelContext = modelContext
        installLiveActivityObservers()

        let templateByExercise: [UUID: TemplateExercise] = Dictionary(
            (workout.template?.templateExercises ?? []).map { ($0.exerciseId, $0) }, uniquingKeysWith: { first, _ in first })
        let templateByName: [String: TemplateExercise] = Dictionary(
            (workout.template?.templateExercises ?? []).map { (Exercise.normalisedName($0.exerciseName), $0) },
            uniquingKeysWith: { first, _ in first })

        for log in workout.exerciseLogs.sorted(by: { $0.order < $1.order }) {
            guard let exercise = log.exercise else { continue }
            let target = templateByExercise[exercise.id] ?? templateByName[Exercise.normalisedName(exercise.name)]

            var sets: [SetEntry] = log.sets.sorted(by: { $0.order < $1.order }).map { setLog in
                var set = SetEntry(
                    order: setLog.order,
                    weight: setLog.weight > 0 ? String(format: "%g", setLog.weight) : "",
                    reps: setLog.reps > 0 ? "\(setLog.reps)" : "",
                    rir: setLog.rir.map { "\($0)" } ?? "",
                    duration: setLog.duration.map { String(format: "%g", $0) } ?? "",
                    distance: setLog.distance.map { String(format: "%g", $0) } ?? "",
                    setType: setLog.setType,
                    side: setLog.side,
                    targetReps: target?.targetReps,
                    targetRIR: target?.targetRIR
                )
                set.isCompleted = true
                set.logId = setLog.id
                return set
            }
            // Pad back up to the template's planned number of rows (and never leave an exercise with none).
            let planned = max(target?.targetSets ?? 0, sets.count, 1)
            while sets.count < planned {
                sets.append(SetEntry(order: sets.count, targetReps: target?.targetReps, targetRIR: target?.targetRIR))
            }

            var entry = ExerciseEntry(exerciseId: exercise.id, exerciseName: exercise.name, sets: sets, notes: log.notes)
            entry.apply(exercise)
            entry.restSeconds = target?.restSeconds
            entry.logId = log.id
            exerciseEntries.append(entry)
        }

        elapsedSeconds = Int(workout.duration)
        startTime = Date().addingTimeInterval(-workout.duration)
        isActive = true
        beginDurationTimer()
        liveActivity.startLiveActivity(workoutName: workout.template?.name ?? "Workout")
        updateLiveCalories()
    }
}
