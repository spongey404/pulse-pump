import Foundation

/// The numbers on the Exercise detail screen (stat cards, trend chart, recent sessions), from the
/// exercise's finished-workout logs. Pure so journey tests can read exactly what the screen shows.
struct ExerciseProgress {
    let exercise: Exercise

    var allSets: [SetLog] {
        exercise.finalLogs.flatMap(\.workingSets)
    }

    var weightPR: Double {
        allSets.map(\.weight).max() ?? 0
    }

    var repsPR: Int {
        allSets.map(\.reps).max() ?? 0
    }

    var estimated1RM: Double {
        guard let bestSet = allSets.max(by: {
            Self.epley(weight: $0.weight, reps: $0.reps) < Self.epley(weight: $1.weight, reps: $1.reps)
        }) else { return 0 }
        return Self.epley(weight: bestSet.weight, reps: bestSet.reps)
    }

    static func epley(weight: Double, reps: Int) -> Double {
        guard reps > 1 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    var volumePR: Double {
        exercise.finalLogs.map { log in
            log.workingSets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }.max() ?? 0
    }

    /// "Weight over time": the heaviest working set of each session, oldest first (sessions with no load are skipped).
    var trendPoints: [(date: Date, maxWeight: Double)] {
        exercise.finalLogs
            .compactMap { log -> (Date, Double)? in
                guard let date = log.workout?.date else { return nil }
                let maxW = log.workingSets.map(\.weight).max() ?? 0
                guard maxW > 0 else { return nil }
                return (date, maxW)
            }
            .sorted { $0.0 < $1.0 }
    }

    /// The five latest sessions, newest first.
    var recentLogs: [ExerciseLog] {
        exercise.finalLogs
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }
}
