import Foundation
import SwiftData

// Shared "what counts" rules so every screen, widget and export agrees:
//  - warm-up sets are saved and shown in the logger/history rows, but never counted in
//    set totals, volume, PRs, muscle heat or exercise stats ("working sets");
//  - a draft workout (in-progress, crash-recoverable) is not history, so its logs are
//    excluded from anything computed across past sessions.

extension SetLog {
    /// False for warm-up sets.
    var isWorking: Bool { setType != .warmup }
}

extension ExerciseLog {
    var workingSets: [SetLog] { sets.filter(\.isWorking) }
    /// Belongs to a finished (non-draft) workout. Orphan logs count as finished.
    var isFinal: Bool { workout?.isDraft != true }
}

extension Workout {
    var workingSets: [SetLog] { exerciseLogs.flatMap(\.workingSets) }
    var workingSetCount: Int { exerciseLogs.reduce(0) { $0 + $1.workingSets.count } }
    /// Working-set volume (weight x reps) in the stored unit.
    var workingVolume: Double { workingSets.reduce(0) { $0 + $1.weight * Double($1.reps) } }
}

extension Exercise {
    /// Logs from finished workouts only (drafts excluded).
    var finalLogs: [ExerciseLog] { logs.filter(\.isFinal) }

    /// Lowercased, punctuation/whitespace-insensitive key for matching names across the
    /// catalogue, presets and imports ("Barbell Bench-Press" == "barbell bench press").
    static func normalisedName(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

extension ModelContext {
    /// Logs of one exercise from finished workouts, newest first (drafts excluded).
    func finalLogs(forExercise exerciseId: UUID, limit: Int? = nil) -> [ExerciseLog] {
        var descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { $0.exercise?.id == exerciseId && $0.workout?.isDraft == false },
            sortBy: [SortDescriptor(\ExerciseLog.createdAt, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return (try? fetch(descriptor)) ?? []
    }
}
