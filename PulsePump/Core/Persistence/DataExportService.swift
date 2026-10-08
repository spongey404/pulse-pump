import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Exports are ALWAYS in kg, whatever the user's display unit (the stored unit; see docs/sync-architecture.md).
/// `weightUnit` in the JSON and the `Unit` CSV column make that explicit for whoever reads the file.
struct WorkoutExportData: Codable {
    let exportDate: Date
    let version: String
    /// Unit of every `weight` in this file. Always "kg".
    var weightUnit: String = DataExportService.exportUnit
    let workouts: [ExportedWorkout]
}

struct ExportedWorkout: Codable {
    let date: Date
    let duration: TimeInterval
    let calories: Double
    let notes: String
    let exercises: [ExportedExercise]
}

struct ExportedExercise: Codable {
    let name: String
    let order: Int
    let notes: String
    let sets: [ExportedSet]
}

struct ExportedSet: Codable {
    let order: Int
    let weight: Double
    let reps: Int
    let rir: Int?
    let setType: String
}

struct DataExportService {
    /// Unit of all exported weights.
    static let exportUnit = "kg"

    static func exportWorkouts(from context: ModelContext) throws -> Data {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        let workouts = try context.fetch(descriptor)

        let exported = WorkoutExportData(
            exportDate: Date(),
            version: "1.1",
            workouts: workouts.map { workout in
                ExportedWorkout(
                    date: workout.date,
                    duration: workout.duration,
                    calories: workout.calorieBurnEstimate,
                    notes: workout.notes,
                    exercises: workout.exerciseLogs.sorted(by: { $0.order < $1.order }).map { log in
                        ExportedExercise(
                            name: log.exercise?.name ?? "Unknown",
                            order: log.order,
                            notes: log.notes,
                            sets: log.sets.sorted(by: { $0.order < $1.order }).map { set in
                                ExportedSet(
                                    order: set.order,
                                    weight: set.weight,
                                    reps: set.reps,
                                    rir: set.rir,
                                    setType: set.setType.rawValue
                                )
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exported)
    }

    static func generateCSV(from context: ModelContext) throws -> String {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        let workouts = try context.fetch(descriptor)

        var csv = "Date,Exercise,Set,Weight,Unit,Reps,RIR,Type,Duration(min),Calories\n"   // Weight is always kg

        for workout in workouts {
            let dateStr = ISO8601DateFormatter().string(from: workout.date)
            let durationMin = Int(workout.duration / 60)

            for log in workout.exerciseLogs.sorted(by: { $0.order < $1.order }) {
                let exerciseName = log.exercise?.name ?? "Unknown"
                for set in log.sets.sorted(by: { $0.order < $1.order }) {
                    let rirStr = set.rir.map { "\($0)" } ?? ""
                    csv += "\(dateStr),\"\(exerciseName)\",\(set.order + 1),\(set.weight),\(exportUnit),\(set.reps),\(rirStr),\(set.setType.rawValue),\(durationMin),\(Int(workout.calorieBurnEstimate))\n"
                }
            }
        }

        return csv
    }
}
