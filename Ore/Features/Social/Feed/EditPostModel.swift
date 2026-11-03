import Foundation
import SwiftData

/// Edit post (Ore Feed Post Final §2), author only. Pure state + the recalculation that runs on SAVE (stats, PRs, body map), and the
/// write-back to the local History ("Changes also update your History, the stats and the body map. The post shows EDITED.").
@Observable
final class EditPostModel {
    struct EditableSet: Identifiable, Equatable {
        var id = UUID()
        var type: SetType
        var weightKg: Double
        var reps: Int
        /// Added in this edit: drawn with a 2 pt accent bar and accent reps.
        var isNew = false
    }
    struct EditableExercise: Identifiable, Equatable {
        var id: String
        var name: String
        var sets: [EditableSet]
        /// Carried through unchanged until SAVE recalculates them.
        var improvementScore = 0.0, weightDelta = 0.0, repsDelta = 0
    }

    let postId: String
    var exercises: [EditableExercise]
    var caption: String
    var song: PostSong?
    var photoURL: String?
    var newPhotoJPEG: Data?
    var removePhoto = false
    var taggedUids: [String]
    var taggedNames: [String]
    private let original: [FeedExercise]

    init(post: WorkoutFeedItem) {
        postId = post.id
        original = post.exercises
        caption = post.caption
        song = post.song
        photoURL = post.photoURL
        taggedUids = post.taggedFriendUids
        taggedNames = post.taggedNames ?? []
        exercises = post.exercises.map { e in
            EditableExercise(id: e.id, name: e.name, sets: e.sets.map {
                EditableSet(type: SetType(rawValue: $0.setType) ?? .standard, weightKg: $0.weight, reps: $0.reps)
            }, improvementScore: e.improvementScore, weightDelta: e.weightDelta, repsDelta: e.repsDelta)
        }
    }

    // MARK: Editing

    func addSet(to exerciseId: String) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let last = exercises[i].sets.last
        exercises[i].sets.append(EditableSet(type: .standard, weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0, isNew: true))
    }

    func removeSet(_ setId: UUID, from exerciseId: String) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        exercises[i].sets.removeAll { $0.id == setId }
        if exercises[i].sets.isEmpty { exercises.remove(at: i) }
    }

    func addExercise(named name: String) {
        exercises.append(EditableExercise(id: UUID().uuidString, name: name, sets: [EditableSet(type: .standard, weightKg: 0, reps: 0, isNew: true)]))
    }

    func tag(uid: String, name: String) {
        guard !taggedUids.contains(uid), taggedUids.count < 20 else { return }
        taggedUids.append(uid); taggedNames.append(name)
    }

    func untag(uid: String) {
        guard let i = taggedUids.firstIndex(of: uid) else { return }
        taggedUids.remove(at: i)
        if i < taggedNames.count { taggedNames.remove(at: i) }
    }

    var workingSetCount: Int { exercises.reduce(0) { $0 + $1.sets.filter { $0.type != .warmup }.count } }
    var volumeKg: Double { exercises.flatMap(\.sets).filter { $0.type != .warmup }.reduce(0) { $0 + $1.weightKg * Double($1.reps) } }
    var isValid: Bool { !exercises.isEmpty && exercises.allSatisfy { !$0.sets.isEmpty } }

    /// Header line of an exercise card: "4 SETS · TOP 120 KG" (kg shown in the user's unit by the caller).
    func summary(of e: EditableExercise) -> (sets: Int, topKg: Double) {
        let w = e.sets.filter { $0.type != .warmup }
        return (w.count, w.map(\.weightKg).max() ?? 0)
    }

    // MARK: Recalculation on SAVE

    /// A person's earlier working sets on one exercise (before the post's workout). The same rules the logger uses at finish.
    struct History { var sets: [(weight: Double, reps: Int)] }

    struct Recalc: Equatable {
        var exercises: [FeedExercise]
        var prCount: Int
        var improved: Int
        var sets: Int
        var volumeKg: Double
    }

    static func epley(_ w: Double, _ r: Int) -> Double { w > 0 ? w * (1 + Double(r) / 30) : Double(r) }

    /// Rebuilds the post's exercises with fresh deltas and counts the PRs. A weight PR needs an earlier best to beat; with no history it
    /// is a baseline, not a PR.
    func recalculate(history: (String) -> History) -> Recalc {
        var pr = 0, improved = 0
        let out: [FeedExercise] = exercises.map { e in
            let working = e.sets.filter { $0.type != .warmup }
            let prev = history(e.name).sets
            let bestW = working.map(\.weightKg).max() ?? 0
            let prevBestW = prev.map(\.weight).max() ?? 0
            let bestR = working.map(\.reps).max() ?? 0
            let prevMaxR = prev.filter { $0.weight <= bestW + 0.01 }.map(\.reps).max() ?? 0
            let cur1 = working.map { Self.epley($0.weightKg, $0.reps) }.max() ?? 0
            let prev1 = prev.map { Self.epley($0.weight, $0.reps) }.max() ?? 0
            var dW = 0.0, dR = 0
            if bestW > prevBestW && prevBestW > 0 { pr += 1; dW = bestW - prevBestW }
            else if bestR > prevMaxR && prevMaxR > 0 { pr += 1; dR = bestR - prevMaxR }
            var score = 0.0
            if prev1 > 0 {
                if cur1 > prev1 + 0.01 { improved += 1 }
                score = max(0, (cur1 - prev1) / prev1 * 100)
            }
            let old = original.first { $0.id == e.id }
            return FeedExercise(id: e.id, name: e.name, sets: e.sets.map {
                FeedSetLog(weight: $0.weightKg, reps: $0.reps, duration: 0, distance: 0, setType: $0.type.rawValue, side: nil)
            }, improvementScore: score, weightDelta: dW, repsDelta: dR,
               primaryMuscles: old?.primaryMuscles ?? [], secondaryMuscles: old?.secondaryMuscles ?? [])
        }
        let sets = out.reduce(0) { $0 + $1.workingSets.count }
        let volume = out.flatMap(\.workingSets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return Recalc(exercises: out, prCount: pr, improved: improved, sets: sets, volumeKg: volume)
    }

    // MARK: Local data

    /// Earlier working sets of `name` from this device's History, before the workout being edited.
    static func localHistory(context: ModelContext, workoutId: UUID, name: String) -> History {
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard let ex = all.first(where: { $0.name.lowercased() == name.lowercased() }) else { return History(sets: []) }
        let sets = ex.finalLogs.filter { $0.workout?.id != workoutId }.flatMap(\.workingSets).map { (weight: $0.weight, reps: $0.reps) }
        return History(sets: sets)
    }

    /// Muscle tags for new exercises, taken from the library (a post never stores them).
    static func withMuscles(_ exercises: [FeedExercise], context: ModelContext) -> [FeedExercise] {
        let lib = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let byName = Dictionary(lib.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        return exercises.map { e in
            guard e.primaryMuscles.isEmpty, let l = byName[e.name.lowercased()] else { return e }
            var c = e
            c.primaryMuscles = l.primaryMuscleGroups.map(\.displayName)
            c.secondaryMuscles = l.secondaryMuscleGroups.map(\.displayName)
            return c
        }
    }

    /// Writes the edited sets into the local workout so History, Home stats and the Body tab follow ("Changes also update your History").
    /// Sets are matched by position within the exercise (by library name); extra sets are added, missing ones removed, new exercises appended.
    @discardableResult
    func applyToHistory(context: ModelContext, workoutId: UUID) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.id == workoutId }))) ?? []
        guard let workout = all.first else { return false }
        let library = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var logs = workout.exerciseLogs.sorted { $0.order < $1.order }
        let keep = Set(exercises.map { $0.name.lowercased() })
        for log in logs where !keep.contains((log.exercise?.name ?? "").lowercased()) { context.delete(log) }
        logs = logs.filter { keep.contains(($0.exercise?.name ?? "").lowercased()) }
        let now = Date()
        for (order, e) in exercises.enumerated() {
            let log: ExerciseLog
            if let existing = logs.first(where: { ($0.exercise?.name ?? "").lowercased() == e.name.lowercased() }) {
                log = existing
            } else if let lib = library.first(where: { $0.name.lowercased() == e.name.lowercased() }) {
                log = ExerciseLog(order: order)
                log.exercise = lib
                log.workout = workout
                context.insert(log)
            } else { continue }
            log.order = order
            log.updatedAt = now
            var sets = log.sets.sorted { $0.order < $1.order }
            for (i, s) in e.sets.enumerated() {
                if i < sets.count {
                    sets[i].weight = s.weightKg; sets[i].reps = s.reps; sets[i].setType = s.type; sets[i].order = i
                } else {
                    let new = SetLog(order: i, weight: s.weightKg, reps: s.reps, setType: s.type)
                    new.exerciseLog = log
                    context.insert(new)
                }
            }
            if sets.count > e.sets.count { for extra in sets[e.sets.count...] { context.delete(extra) } }
        }
        try? context.save()
        return true
    }
}
