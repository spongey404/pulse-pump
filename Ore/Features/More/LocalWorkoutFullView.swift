import SwiftUI
import SwiftData

/// A finished local workout as a `WorkoutFeedItem`, so History, Home and the calendar open the same full workout view a feed post opens.
/// "VS LAST" compares each exercise with the previous session of it in `history` (best set by estimated 1RM, like the finish screen).
enum LocalWorkoutFeedItem {
    static func epley(_ w: Double, _ r: Int) -> Double { w > 0 ? w * (1 + Double(r) / 30) : Double(r) }

    static func make(from workout: Workout, history: [Workout], userId: String = "local") -> WorkoutFeedItem {
        let earlier = history.filter { $0.id != workout.id && $0.date < workout.date && !$0.isDraft && $0.deletedAt == nil }
        let logs = workout.exerciseLogs.sorted { $0.order < $1.order }
        var improved = 0, prs = 0
        var muscleSets: [String: Int] = [:]
        var exercises: [FeedExercise] = []
        for log in logs {
            let working = log.workingSets
            guard !working.isEmpty, let exercise = log.exercise else { continue }
            let best = working.max { epley($0.weight, $0.reps) < epley($1.weight, $1.reps) }
            var prevBest: SetLog?
            for w in earlier.sorted(by: { $0.date > $1.date }) {
                guard let l = w.exerciseLogs.first(where: { $0.exercise?.id == exercise.id }), !l.workingSets.isEmpty else { continue }
                prevBest = l.workingSets.max { epley($0.weight, $0.reps) < epley($1.weight, $1.reps) }
                break
            }
            var weightDelta = 0.0, repsDelta = 0, score = 0.0
            if let best, let prev = prevBest {
                weightDelta = best.weight - prev.weight
                if weightDelta == 0 { repsDelta = best.reps - prev.reps }
                let now = epley(best.weight, best.reps), before = epley(prev.weight, prev.reps)
                if before > 0, now > before + 0.01 { improved += 1; score = (now - before) / before * 100 }
                if weightDelta > 0 { prs += 1 }
            }
            for m in exercise.primaryMuscleGroups { muscleSets[m.displayName, default: 0] += working.count }
            exercises.append(FeedExercise(
                id: log.id.uuidString, name: exercise.name,
                sets: log.sets.sorted { $0.order < $1.order }.map {
                    FeedSetLog(weight: $0.weight, reps: $0.reps, duration: Int($0.duration ?? 0), distance: $0.distance ?? 0,
                               setType: $0.setType.rawValue, side: $0.side == .both ? nil : $0.side.rawValue)
                },
                improvementScore: score, weightDelta: weightDelta, repsDelta: repsDelta,
                primaryMuscles: exercise.primaryMuscleGroups.map(\.displayName), secondaryMuscles: exercise.secondaryMuscleGroups.map(\.displayName)))
        }
        return WorkoutFeedItem(id: workout.id.uuidString, userId: userId, username: "You", templateName: workout.template?.name,
                               exerciseCount: exercises.count, durationSeconds: Int(workout.duration), caloriesBurned: Int(workout.calorieBurnEstimate),
                               musclesWorked: Array(muscleSets.keys), prCount: prs, improvedCount: improved, totalExercises: exercises.count,
                               date: workout.date, exercises: exercises, muscleSets: muscleSets)
    }
}

/// The full workout view for a local workout: the feed post's session view without the post-only parts (reactions, edit/delete post).
/// With `editable` its ··· menu edits, duplicates or deletes the workout (History); Home and the calendar open it read-only.
struct LocalWorkoutFullView: View {
    let workout: Workout
    var editable = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse) private var history: [Workout]
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        FeedSessionSheet(item: LocalWorkoutFeedItem.make(from: workout, history: history), viewModel: SocialViewModel.shared, local: true,
                         localMenu: editable ? [
                            LocalWorkoutMenuItem(title: "Edit") { editing = true },
                            LocalWorkoutMenuItem(title: "Duplicate") { modelContext.duplicate(workout) },
                            LocalWorkoutMenuItem(title: "Delete", destructive: true) { confirmDelete = true },
                         ] : [])
            .fullScreenCover(isPresented: $editing) { EditWorkoutCover(workout: workout) }
            .confirmationDialog("Delete Workout?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    modelContext.softDelete(workout)   // tombstone, so the deletion syncs
                    dismiss()
                }
            } message: { Text("This workout will be permanently deleted.") }
    }
}

/// The workout's editor (sets, weights, reps) over the full view; its back arrow returns to the full view.
private struct EditWorkoutCover: View {
    let workout: Workout
    var body: some View { WorkoutDetailView(workout: workout, startEditing: true) }
}
