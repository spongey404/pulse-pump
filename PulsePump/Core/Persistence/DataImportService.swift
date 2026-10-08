import Foundation
import SwiftData

struct DataImportService {

    enum ImportSource: String, CaseIterable, Identifiable {
        case strong
        case hevy

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .strong: "Strong"
            case .hevy: "Hevy"
            }
        }

        var fileType: String {
            "csv"
        }
    }

    // MARK: - Units
    //
    // Everything is stored in kg. Hevy writes `weight_kg` or `weight_lbs` in the header; Strong writes a bare
    // "Weight" column in whatever unit the exporting account used (newer files say "Weight (kg)"/"Weight (lbs)").
    // `sourceUnit` is what the user says the file is in; an explicit unit in the header wins; otherwise `sourceUnit` (the UI asks), then the importing user's preference.

    /// Unit named by a weight column header, if any.
    static func detectUnit(headers: [String]) -> UnitPreference? {
        for h in headers.map({ $0.lowercased().trimmingCharacters(in: .whitespaces) }) {
            if h == "weight_kg" || h == "weight (kg)" || h == "weight(kg)" { return .kg }
            if h == "weight_lbs" || h == "weight_lb" || h == "weight (lbs)" || h == "weight (lb)" || h == "weight(lbs)" { return .lbs }
        }
        return nil
    }

    /// Index of the weight column (unit-suffixed variants included).
    static func weightColumn(headers: [String]) -> Int? {
        headers.firstIndex { ["weight", "weight_kg", "weight_lbs", "weight_lb", "weight (kg)", "weight (lbs)", "weight (lb)", "weight(kg)", "weight(lbs)"].contains($0.lowercased()) }
    }

    // MARK: - Strong CSV Import
    // Strong CSV columns: Date,Workout Name,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE

    static func importStrongCSV(_ csvString: String, modelContext: ModelContext, user: User, sourceUnit: UnitPreference? = nil) throws -> Int {
        let rows = parseCSV(csvString)
        guard rows.count > 1 else { return 0 }

        let headers = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        let dateIdx = headers.firstIndex(of: "Date") ?? 0
        let workoutNameIdx = headers.firstIndex(of: "Workout Name")
        let exerciseNameIdx = headers.firstIndex(of: "Exercise Name") ?? 2
        let weightIdx = weightColumn(headers: headers) ?? 4
        let repsIdx = headers.firstIndex(of: "Reps") ?? 5
        let unit = detectUnit(headers: headers) ?? sourceUnit ?? user.unitPreference   // file's unit -> kg below
        let notesIdx = headers.firstIndex(of: "Notes")

        var workoutsByDate: [String: (name: String?, exercises: [(name: String, sets: [(weight: Double, reps: Int, notes: String)])])] = [:]

        for row in rows.dropFirst() {
            guard row.count > max(exerciseNameIdx, weightIdx, repsIdx) else { continue }

            let dateStr = row[dateIdx]
            let exerciseName = row[exerciseNameIdx]
            let weight = unit.kg(fromDisplay: Double(row[weightIdx]) ?? 0)
            let reps = Int(row[repsIdx]) ?? 0
            let notes = notesIdx.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let workoutName = workoutNameIdx.flatMap { row.indices.contains($0) ? row[$0] : nil }

            if workoutsByDate[dateStr] == nil {
                workoutsByDate[dateStr] = (name: workoutName, exercises: [])
            }

            // Find or create exercise group
            if let lastIdx = workoutsByDate[dateStr]?.exercises.lastIndex(where: { $0.name == exerciseName }) {
                workoutsByDate[dateStr]?.exercises[lastIdx].sets.append((weight, reps, notes))
            } else {
                workoutsByDate[dateStr]?.exercises.append((name: exerciseName, sets: [(weight, reps, notes)]))
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let altFormatter = DateFormatter()
        altFormatter.dateFormat = "yyyy-MM-dd"

        var importedCount = 0

        for (dateStr, workoutData) in workoutsByDate {
            let date = dateFormatter.date(from: dateStr) ?? altFormatter.date(from: dateStr) ?? Date()

            let workout = Workout(isDraft: false)
            workout.date = date
            workout.user = user
            workout.notes = workoutData.name ?? ""
            modelContext.insert(workout)

            for (i, exerciseData) in workoutData.exercises.enumerated() {
                let exerciseLog = ExerciseLog(order: i, notes: "")
                modelContext.insert(exerciseLog)
                exerciseLog.workout = workout

                // Try to find matching exercise in library
                let name = exerciseData.name
                let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
                exerciseLog.exercise = try? modelContext.fetch(descriptor).first

                for (j, setData) in exerciseData.sets.enumerated() {
                    let setLog = SetLog(order: j, weight: setData.weight, reps: setData.reps)
                    modelContext.insert(setLog)
                    setLog.exerciseLog = exerciseLog
                }
            }

            importedCount += 1
        }

        return importedCount
    }

    // MARK: - Hevy CSV Import
    // Hevy CSV columns: title,start_time,end_time,description,exercise_title,superset_id,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe

    static func importHevyCSV(_ csvString: String, modelContext: ModelContext, user: User, sourceUnit: UnitPreference? = nil) throws -> Int {
        let rows = parseCSV(csvString)
        guard rows.count > 1 else { return 0 }

        let headers = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        let titleIdx = headers.firstIndex(of: "title") ?? 0
        let startTimeIdx = headers.firstIndex(of: "start_time") ?? 1
        let exerciseTitleIdx = headers.firstIndex(of: "exercise_title") ?? 4
        let weightIdx = weightColumn(headers: headers) ?? 8
        let repsIdx = headers.firstIndex(of: "reps") ?? 9
        let unit = detectUnit(headers: headers) ?? sourceUnit ?? .kg   // Hevy's default header is weight_kg

        var workoutsByTitle: [String: (date: String, exercises: [(name: String, sets: [(weight: Double, reps: Int)])])] = [:]

        for row in rows.dropFirst() {
            guard row.count > max(exerciseTitleIdx, weightIdx, repsIdx) else { continue }

            let title = row[titleIdx]
            let dateStr = row[startTimeIdx]
            let exerciseName = row[exerciseTitleIdx]
            let weight = unit.kg(fromDisplay: Double(row[weightIdx]) ?? 0)
            let reps = Int(row[repsIdx]) ?? 0

            let key = "\(title)_\(dateStr)"
            if workoutsByTitle[key] == nil {
                workoutsByTitle[key] = (date: dateStr, exercises: [])
            }

            if let lastIdx = workoutsByTitle[key]?.exercises.lastIndex(where: { $0.name == exerciseName }) {
                workoutsByTitle[key]?.exercises[lastIdx].sets.append((weight, reps))
            } else {
                workoutsByTitle[key]?.exercises.append((name: exerciseName, sets: [(weight, reps)]))
            }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var importedCount = 0

        for (_, workoutData) in workoutsByTitle {
            let date = isoFormatter.date(from: workoutData.date) ?? fallbackFormatter.date(from: workoutData.date) ?? Date()

            let workout = Workout(isDraft: false)
            workout.date = date
            workout.user = user
            modelContext.insert(workout)

            for (i, exerciseData) in workoutData.exercises.enumerated() {
                let exerciseLog = ExerciseLog(order: i, notes: "")
                modelContext.insert(exerciseLog)
                exerciseLog.workout = workout

                let name = exerciseData.name
                let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
                exerciseLog.exercise = try? modelContext.fetch(descriptor).first

                for (j, setData) in exerciseData.sets.enumerated() {
                    let setLog = SetLog(order: j, weight: setData.weight, reps: setData.reps)
                    modelContext.insert(setLog)
                    setLog.exerciseLog = exerciseLog
                }
            }

            importedCount += 1
        }

        return importedCount
    }

    // MARK: - CSV Parser

    private static func parseCSV(_ string: String) -> [[String]] {
        let lines = string.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.map { line in
            var fields: [String] = []
            var current = ""
            var inQuotes = false
            for char in line {
                if char == "\"" {
                    inQuotes.toggle()
                } else if char == "," && !inQuotes {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
            fields.append(current)
            return fields
        }
    }
}
