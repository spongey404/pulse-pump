import Foundation
import SwiftData

/// Which number of a set row is being edited or stepped.
enum LoggerField: Equatable { case weight, reps, rir, duration, distance }

/// Logger behaviour from Claude Design `Ore Logger 1a.dc.html`: prefill, stepping, set types, auto progression, replace, superset.
extension WorkoutViewModel {

    // MARK: Prefill ("ghost")

    struct LoggerGhost: Equatable {
        var weight: String      // kg string
        var reps: String
        /// Auto progression took this weight up: drawn in accent blue.
        var bumped: Bool
    }

    /// The grey prefill of a row: last time's values at this position, else the previous row's. Typing or stepping makes them solid.
    func ghost(exerciseIndex: Int, setIndex: Int, modelContext: ModelContext) -> LoggerGhost? {
        guard exerciseEntries.indices.contains(exerciseIndex), exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return nil }
        let entry = exerciseEntries[exerciseIndex]
        let previous = previousSessionGhost(for: entry.exerciseId, setIndex: setIndex, modelContext: modelContext)
        var weight = previous?.weight ?? "", reps = previous?.reps ?? ""
        if previous == nil, setIndex > 0 {
            // Past last time's sets: carry the row above.
            let above = entry.sets[setIndex - 1]
            weight = above.weight.isEmpty ? (ghost(exerciseIndex: exerciseIndex, setIndex: setIndex - 1, modelContext: modelContext)?.weight ?? "") : above.weight
            reps = above.reps.isEmpty ? (ghost(exerciseIndex: exerciseIndex, setIndex: setIndex - 1, modelContext: modelContext)?.reps ?? "") : above.reps
        }
        // Within this session the existing rule already says when the next set goes up.
        if let kg = progressionSuggestionKg(exerciseId: entry.exerciseId, setIndex: setIndex) {
            return LoggerGhost(weight: Self.kgText(kg), reps: reps, bumped: true)
        }
        // Nothing logged yet for this exercise: last time's reps at this position reached the target, so go up.
        let cfg = progressionConfig(exerciseIndex: exerciseIndex)
        let loggedBefore = entry.sets[..<setIndex].contains { $0.isCompleted && $0.setType != .warmup }
        if cfg.enabled, !loggedBefore, entry.sets[setIndex].weight.isEmpty, entry.sets[setIndex].setType != .warmup,
           LoggerMath.isBumped(cfg, previousLoggedReps: nil, lastTimeReps: Int(reps)), let last = Double(weight) {
            return LoggerGhost(weight: Self.kgText(last + cfg.incrementKg), reps: reps, bumped: true)
        }
        // No history for this exercise: the workout's target reps show in grey and the weight is "—".
        if reps.isEmpty, let target = entry.sets[setIndex].targetReps { reps = "\(target)" }
        guard !weight.isEmpty || !reps.isEmpty else { return nil }
        return LoggerGhost(weight: weight, reps: reps, bumped: false)
    }

    // MARK: Auto progression (per exercise)

    private func incrementKey(_ name: String) -> String { "progressionIncrementKg.\(Exercise.normalisedName(name))" }

    func progressionIncrementKg(exerciseName: String) -> Double {
        let saved = settings.double(forKey: incrementKey(exerciseName))
        return saved > 0 ? saved : (workout?.user?.effectiveProgressionIncrementKg ?? ProgressionRule.defaultIncrementKgValue)
    }

    func progressionConfig(exerciseIndex: Int) -> LoggerMath.ProgressionConfig {
        guard exerciseEntries.indices.contains(exerciseIndex) else { return .off }
        let name = exerciseEntries[exerciseIndex].exerciseName
        guard hasPlusAccess(), smartSuggestionsEnabled, let reps = workout?.user?.progressionThreshold(forExercise: name) else {
            return LoggerMath.ProgressionConfig(enabled: false, reps: workout?.user?.progressionThreshold(forExercise: name) ?? 8, incrementKg: progressionIncrementKg(exerciseName: name))
        }
        return LoggerMath.ProgressionConfig(enabled: true, reps: reps, incrementKg: progressionIncrementKg(exerciseName: name))
    }

    /// Saves the sheet: the rep target (nil threshold = off) lives with the profile as before; the step is kept per exercise on this device.
    func setProgression(_ cfg: LoggerMath.ProgressionConfig, exerciseIndex: Int, modelContext: ModelContext? = nil) {
        guard exerciseEntries.indices.contains(exerciseIndex) else { return }
        let name = exerciseEntries[exerciseIndex].exerciseName
        settings.set(cfg.incrementKg, forKey: incrementKey(name))
        setProgressionThreshold(cfg.enabled ? cfg.reps : nil, exerciseIndex: exerciseIndex, modelContext: modelContext)
    }

    // MARK: Stepping

    /// The row's current number for a field: what was entered, else the grey prefill.
    func effectiveValue(_ field: LoggerField, exerciseIndex: Int, setIndex: Int, modelContext: ModelContext) -> Double {
        let set = exerciseEntries[exerciseIndex].sets[setIndex]
        let g = ghost(exerciseIndex: exerciseIndex, setIndex: setIndex, modelContext: modelContext)
        switch field {
        case .weight: return parseDecimal(set.weight.isEmpty ? (g?.weight ?? "") : set.weight) ?? 0
        case .reps: return Double(parseWholeNumber(set.reps.isEmpty ? (g?.reps ?? "") : set.reps) ?? 0)
        case .rir: return Double(parseWholeNumber(set.rir) ?? 2)
        case .duration: return parseDecimal(set.duration) ?? 0
        case .distance: return parseDecimal(set.distance) ?? 0
        }
    }

    /// Sets a field to `value` (kg for weight) and makes it solid.
    func setValue(_ field: LoggerField, _ value: Double, exerciseIndex: Int, setIndex: Int) {
        guard exerciseEntries.indices.contains(exerciseIndex), exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }
        let v = max(0, value)
        switch field {
        case .weight: exerciseEntries[exerciseIndex].sets[setIndex].weight = Self.kgText(v)
        case .reps: exerciseEntries[exerciseIndex].sets[setIndex].reps = "\(Int(v.rounded()))"
        case .rir: exerciseEntries[exerciseIndex].sets[setIndex].rir = "\(min(5, Int(v.rounded())))"
        case .duration: exerciseEntries[exerciseIndex].sets[setIndex].duration = Self.kgText(v)
        case .distance: exerciseEntries[exerciseIndex].sets[setIndex].distance = Self.kgText(v)
        }
    }

    /// − / + on the active row and the keypad's step strip. `delta` is in the field's display unit (kg shown in the user's unit).
    func step(_ field: LoggerField, by delta: Double, exerciseIndex: Int, setIndex: Int, modelContext: ModelContext, unit: UnitPreference) {
        let current = effectiveValue(field, exerciseIndex: exerciseIndex, setIndex: setIndex, modelContext: modelContext)
        switch field {
        case .weight:
            let shown = LoggerMath.stepped(unit.display(current), by: delta)
            setValue(.weight, unit.kg(fromDisplay: shown), exerciseIndex: exerciseIndex, setIndex: setIndex)
        default:
            setValue(field, LoggerMath.stepped(current, by: delta), exerciseIndex: exerciseIndex, setIndex: setIndex)
        }
    }

    // MARK: Set types

    /// Picks a set type and lays out what it needs: drop lines, rounds, LEFT / RIGHT, RIR locked at 0 for failure.
    func setSetType(_ type: SetType, exerciseIndex: Int, setIndex: Int, modelContext: ModelContext, unit: UnitPreference = .current) {
        guard exerciseEntries.indices.contains(exerciseIndex), exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }
        let kg = effectiveValue(.weight, exerciseIndex: exerciseIndex, setIndex: setIndex, modelContext: modelContext)
        let reps = Int(effectiveValue(.reps, exerciseIndex: exerciseIndex, setIndex: setIndex, modelContext: modelContext))
        var set = exerciseEntries[exerciseIndex].sets[setIndex]
        let was = set.setType
        set.setType = type
        if was != type { set.subs = [] }
        if set.subs.isEmpty {
            switch type {
            case .dropset:
                let step = unit.stepperIncrement
                set.subs = LoggerMath.dropWeights(from: unit.display(kg), step: step).map {
                    SubLine(ghostWeight: Self.kgText(unit.kg(fromDisplay: $0)), ghostReps: "\(reps)")
                }
            case .restPause:
                set.subs = LoggerMath.restPauseReps(from: reps).map { SubLine(ghostReps: "\($0)") }
            case .leftRight:
                set.subs = [SubLine(ghostReps: "\(reps)"), SubLine(ghostReps: "\(reps)")]
            default: break
            }
        }
        if type == .failureSet, exerciseEntries[exerciseIndex].rirOn { set.rir = "0" }
        exerciseEntries[exerciseIndex].sets[setIndex] = set
        if type == .superset, exerciseEntries[exerciseIndex].supersetGroup == nil { toggleSuperset(exerciseIndex: exerciseIndex) }
        persistDraftIfActive()
    }

    func addSub(exerciseIndex: Int, setIndex: Int, unit: UnitPreference = .current) {
        guard exerciseEntries.indices.contains(exerciseIndex), exerciseEntries[exerciseIndex].sets.indices.contains(setIndex) else { return }
        var set = exerciseEntries[exerciseIndex].sets[setIndex]
        let last = set.subs.last
        switch set.setType {
        case .dropset:
            let lastKg = parseDecimal(last?.shownWeight ?? "") ?? parseDecimal(set.weight) ?? 0
            let next = LoggerMath.roundToStep(unit.display(lastKg) * 0.8, step: unit.stepperIncrement)
            set.subs.append(SubLine(ghostWeight: Self.kgText(unit.kg(fromDisplay: next)), ghostReps: last?.shownReps ?? set.reps))
        case .restPause:
            let r = max(1, (parseWholeNumber(last?.shownReps ?? "") ?? 4) - 1)
            set.subs.append(SubLine(ghostReps: "\(r)"))
        default: return
        }
        exerciseEntries[exerciseIndex].sets[setIndex] = set
    }

    func removeSub(exerciseIndex: Int, setIndex: Int, subIndex: Int) {
        guard exerciseEntries.indices.contains(exerciseIndex), exerciseEntries[exerciseIndex].sets.indices.contains(setIndex),
              exerciseEntries[exerciseIndex].sets[setIndex].subs.indices.contains(subIndex),
              exerciseEntries[exerciseIndex].sets[setIndex].setType != .leftRight,
              exerciseEntries[exerciseIndex].sets[setIndex].subs.count > 1 else { return }
        exerciseEntries[exerciseIndex].sets[setIndex].subs.remove(at: subIndex)
    }

    /// Fills the grey prefill of a set's lines when it is logged (what was shown is what is saved).
    func solidifySubs(exerciseIndex: Int, setIndex: Int) {
        for i in exerciseEntries[exerciseIndex].sets[setIndex].subs.indices {
            var sub = exerciseEntries[exerciseIndex].sets[setIndex].subs[i]
            if sub.weight.isEmpty { sub.weight = sub.ghostWeight }
            if sub.reps.isEmpty { sub.reps = sub.ghostReps }
            exerciseEntries[exerciseIndex].sets[setIndex].subs[i] = sub
        }
    }

    // MARK: Superset

    /// Pairs this exercise with the next, or takes it out of its group.
    func toggleSuperset(exerciseIndex: Int) {
        guard exerciseEntries.indices.contains(exerciseIndex) else { return }
        if let group = exerciseEntries[exerciseIndex].supersetGroup {
            for i in exerciseEntries.indices where exerciseEntries[i].supersetGroup == group { exerciseEntries[i].supersetGroup = nil }
            return
        }
        guard exerciseIndex < exerciseEntries.count - 1 else { return }
        let used = Set(exerciseEntries.compactMap(\.supersetGroup))
        guard let letter = ["A", "B", "C", "D"].first(where: { !used.contains($0) }) else { return }
        exerciseEntries[exerciseIndex].supersetGroup = letter
        exerciseEntries[exerciseIndex + 1].supersetGroup = letter
    }

    // MARK: Replace: SWAP or SWITCH

    enum ReplaceKind: Equatable { case swap, switchUnlogged }

    /// Nothing logged: SWAP (replace in place, keep the set count, fresh prefills). Some logged: SWITCH (logged sets stay on the
    /// original, the unlogged ones move to the new exercise inserted directly below). Logged data is never deleted.
    @discardableResult
    func replaceExerciseKeepingData(at index: Int, with exercise: Exercise) -> ReplaceKind {
        let entry = exerciseEntries[index]
        let logged = entry.sets.filter(\.isCompleted)
        if logged.isEmpty {
            var swapped = entry
            swapped.familyName = entry.familyName ?? entry.exerciseName
            swapped.exerciseId = exercise.id
            swapped.exerciseName = exercise.name
            swapped.apply(exercise)
            swapped.logId = nil
            swapped.sets = entry.sets.enumerated().map { i, _ in SetEntry(order: i) }
            exerciseEntries[index] = swapped
            persistDraftIfActive()
            return .swap
        }
        let unlogged = entry.sets.filter { !$0.isCompleted }
        var next = ExerciseEntry(exerciseId: exercise.id, exerciseName: exercise.name,
                                 sets: (unlogged.isEmpty ? [SetEntry(order: 0)] : unlogged.enumerated().map { i, _ in SetEntry(order: i) }))
        next.apply(exercise)
        next.familyName = entry.familyName ?? entry.exerciseName
        next.restSeconds = entry.restSeconds
        next.rirOn = entry.rirOn
        exerciseEntries[index].sets = logged
        exerciseEntries.insert(next, at: index + 1)
        persistDraftIfActive()
        return .switchUnlogged
    }

    // MARK: Finish

    var unloggedSetCount: Int { exerciseEntries.flatMap(\.sets).filter { !$0.isCompleted }.count }
    var totalSetCount: Int { exerciseEntries.flatMap(\.sets).count }
}
