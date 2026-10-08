import Foundation
import SwiftData

/// Imports workout history from Strong / Hevy CSV exports.
///
/// - Exercises are linked to the catalogue by normalised name; a custom exercise is created only
///   when a name is truly unknown (and reported as "unmatched").
/// - Re-importing the same file is a no-op: every set has a stable key (date + exercise + set
///   order) that is checked against what is already stored.
/// - Rows with an unreadable date are skipped and reported, never dated "now".
/// - Warm-up sets are kept but typed `.warmup`, so they are excluded from stats.
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

    /// What an import did, reported back to the caller.
    struct ImportResult: Equatable {
        /// Workouts created.
        var imported = 0
        /// Whole workouts skipped because every set was already imported.
        var duplicateWorkouts = 0
        var importedSets = 0
        /// Sets skipped because they were already imported.
        var duplicateSets = 0
        /// Rows skipped as unusable (bad date, missing exercise, empty set).
        var skippedRows = 0
        var warmupSets = 0
        /// Exercise names not found in the catalogue (created as custom exercises).
        var unmatchedExercises: [String] = []
        /// Human-readable reasons for skipped rows (capped).
        var errors: [String] = []

        var summary: String {
            var parts = ["Imported \(imported) workout\(imported == 1 ? "" : "s") (\(importedSets) sets)"]
            if duplicateWorkouts > 0 || duplicateSets > 0 { parts.append("\(duplicateWorkouts) already imported") }
            if skippedRows > 0 { parts.append("\(skippedRows) row\(skippedRows == 1 ? "" : "s") skipped") }
            if !unmatchedExercises.isEmpty { parts.append("\(unmatchedExercises.count) new custom exercise\(unmatchedExercises.count == 1 ? "" : "s")") }
            return parts.joined(separator: " · ")
        }
    }

    /// One parsed CSV set row, source-independent.
    struct ParsedRow {
        var date: Date
        var workoutName: String
        var exerciseName: String
        var weight: Double
        var reps: Int
        var rir: Int?
        var distance: Double?
        var seconds: Double?
        var setType: SetType
        var duration: TimeInterval?
    }

    private static let maxReportedErrors = 20

    // MARK: - Strong CSV Import
    // Strong CSV columns: Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
    // "Set Order" is the set number, or W (warm-up) / D (drop) / F (failure).

    // MARK: Units
    // Everything is stored in kg. Hevy writes `weight_kg` / `weight_lbs`; Strong writes a bare "Weight" column in the
    // exporting account's unit (newer files say "Weight (kg)"/"Weight (lbs)"). An explicit header unit wins; otherwise
    // `sourceUnit` (the UI asks), then the importing user's preference.
    static let weightColumns = ["Weight", "weight", "Weight (kg)", "Weight (lbs)", "Weight (lb)", "weight_kg", "weight_lbs", "weight_lb"]

    /// Unit named by a weight column header, if any.
    static func detectUnit(headers: [String]) -> UnitPreference? {
        for h in headers.map({ $0.lowercased().trimmingCharacters(in: .whitespaces) }) {
            if h == "weight_kg" || h == "weight (kg)" || h == "weight(kg)" { return .kg }
            if ["weight_lbs", "weight_lb", "weight (lbs)", "weight (lb)", "weight(lbs)"].contains(h) { return .lbs }
        }
        return nil
    }

    @discardableResult
    static func importStrongCSV(_ csvString: String, modelContext: ModelContext, user: User, sourceUnit: UnitPreference? = nil) throws -> ImportResult {
        var result = ImportResult()
        let rows = parseCSV(csvString)
        guard rows.count > 1 else { return result }
        let h = Header(rows[0])
        let unit = detectUnit(headers: rows[0]) ?? sourceUnit ?? user.unitPreference   // file's unit; stored as kg

        var parsed: [ParsedRow] = []
        for (n, row) in rows.enumerated().dropFirst() {
            let dateStr = h.value(row, "Date")
            guard let date = parseStrongDate(dateStr) else {
                result.skip("Row \(n + 1): unreadable date '\(dateStr)'")
                continue
            }
            let exercise = h.value(row, "Exercise Name").trimmingCharacters(in: .whitespaces)
            guard !exercise.isEmpty else { result.skip("Row \(n + 1): missing exercise name"); continue }
            let marker = h.value(row, "Set Order").trimmingCharacters(in: .whitespaces).uppercased()
            parsed.append(ParsedRow(
                date: date,
                workoutName: h.value(row, "Workout Name"),
                exerciseName: exercise,
                weight: unit.kg(fromDisplay: parseDecimal(h.firstValue(row, Self.weightColumns)) ?? 0),
                reps: parseWholeNumber(h.value(row, "Reps")) ?? 0,
                rir: parseDecimal(h.value(row, "RPE")).map { max(0, min(10, 10 - Int($0.rounded()))) },
                distance: parseDecimal(h.value(row, "Distance")).flatMap { $0 > 0 ? $0 : nil },
                seconds: parseDecimal(h.value(row, "Seconds")).flatMap { $0 > 0 ? $0 : nil },
                setType: marker == "W" ? .warmup : marker == "D" ? .dropset : marker == "F" ? .failureSet : .standard,
                duration: nil
            ))
        }
        commit(parsed, modelContext: modelContext, user: user, into: &result)
        return result
    }

    // MARK: - Hevy CSV Import
    // Hevy CSV columns: title,start_time,end_time,description,exercise_title,superset_id,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe

    @discardableResult
    static func importHevyCSV(_ csvString: String, modelContext: ModelContext, user: User, sourceUnit: UnitPreference? = nil) throws -> ImportResult {
        var result = ImportResult()
        let rows = parseCSV(csvString)
        guard rows.count > 1 else { return result }
        let h = Header(rows[0])
        let unit = detectUnit(headers: rows[0]) ?? sourceUnit ?? .kg   // Hevy's default header is weight_kg

        var parsed: [ParsedRow] = []
        for (n, row) in rows.enumerated().dropFirst() {
            let startStr = h.value(row, "start_time")
            guard let start = parseHevyDate(startStr) else {
                result.skip("Row \(n + 1): unreadable date '\(startStr)'")
                continue
            }
            let exercise = h.value(row, "exercise_title").trimmingCharacters(in: .whitespaces)
            guard !exercise.isEmpty else { result.skip("Row \(n + 1): missing exercise name"); continue }
            let type = h.value(row, "set_type").lowercased()
            let end = parseHevyDate(h.value(row, "end_time"))
            parsed.append(ParsedRow(
                date: start,
                workoutName: h.value(row, "title"),
                exerciseName: exercise,
                weight: unit.kg(fromDisplay: parseDecimal(h.firstValue(row, Self.weightColumns)) ?? 0),
                reps: parseWholeNumber(h.value(row, "reps")) ?? 0,
                rir: parseDecimal(h.value(row, "rpe")).map { max(0, min(10, 10 - Int($0.rounded()))) },
                distance: parseDecimal(h.value(row, "distance_km")).flatMap { $0 > 0 ? $0 * 1000 : nil },
                seconds: parseDecimal(h.value(row, "duration_seconds")).flatMap { $0 > 0 ? $0 : nil },
                setType: type.contains("warm") ? .warmup : type.contains("drop") ? .dropset : type.contains("fail") ? .failureSet : .standard,
                duration: end.map { max(0, $0.timeIntervalSince(start)) }
            ))
        }
        commit(parsed, modelContext: modelContext, user: user, into: &result)
        return result
    }

    // MARK: - Commit

    /// Stable per-set key: second-precision date + normalised exercise + set order.
    static func setKey(date: Date, exerciseName: String, order: Int) -> String {
        "\(Int(date.timeIntervalSince1970))|\(Exercise.normalisedName(exerciseName))|\(order)"
    }

    static func commit(_ rows: [ParsedRow], modelContext: ModelContext, user: User, into result: inout ImportResult) {
        // Existing keys, so re-imports are no-ops.
        var existingKeys = Set<String>()
        let existing = (try? modelContext.fetch(FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft }))) ?? []
        for w in existing {
            for log in w.exerciseLogs {
                guard let name = log.exercise?.name else { continue }
                for s in log.sets { existingKeys.insert(setKey(date: w.date, exerciseName: name, order: s.order)) }
            }
        }

        var catalogue = CatalogueIndex(modelContext: modelContext)

        // Group rows into workouts (date + name), keeping file order for exercises and sets.
        var order: [String] = []
        var groups: [String: [ParsedRow]] = [:]
        for row in rows {
            let key = "\(Int(row.date.timeIntervalSince1970))|\(row.workoutName)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(row)
        }

        for key in order {
            let group = groups[key] ?? []
            guard let first = group.first else { continue }

            // Exercise blocks in first-appearance order; set order counts within the exercise.
            var exerciseOrder: [String] = []
            var setsByExercise: [String: [ParsedRow]] = [:]
            for row in group {
                let norm = Exercise.normalisedName(row.exerciseName)
                if setsByExercise[norm] == nil { exerciseOrder.append(norm) }
                setsByExercise[norm, default: []].append(row)
            }

            struct NewSet { let row: ParsedRow; let order: Int }
            var newBlocks: [(name: String, sets: [NewSet])] = []
            var duplicates = 0
            for norm in exerciseOrder {
                let rowsForExercise = setsByExercise[norm] ?? []
                var fresh: [NewSet] = []
                for (j, row) in rowsForExercise.enumerated() {
                    // Empty sets (no weight, reps, time or distance) carry no information.
                    if row.weight == 0 && row.reps == 0 && row.seconds == nil && row.distance == nil {
                        result.skip("\(row.exerciseName): empty set skipped")
                        continue
                    }
                    let canonicalName = catalogue.exercise(for: row.exerciseName)?.name ?? row.exerciseName
                    if existingKeys.contains(setKey(date: first.date, exerciseName: canonicalName, order: j)) {
                        duplicates += 1
                        continue
                    }
                    fresh.append(NewSet(row: row, order: j))
                }
                if !fresh.isEmpty { newBlocks.append((rowsForExercise[0].exerciseName, fresh)) }
            }
            result.duplicateSets += duplicates
            guard !newBlocks.isEmpty else {
                if duplicates > 0 { result.duplicateWorkouts += 1 }
                continue
            }

            let workout = Workout(isDraft: false)
            workout.date = first.date
            workout.user = user
            workout.notes = first.workoutName
            workout.duration = first.duration ?? 0
            modelContext.insert(workout)

            for (i, block) in newBlocks.enumerated() {
                let log = ExerciseLog(order: i, notes: "")
                modelContext.insert(log)
                log.workout = workout
                let exercise = catalogue.exerciseOrCreate(named: block.name, result: &result)
                log.exercise = exercise
                for s in block.sets {
                    let set = SetLog(order: s.order, weight: s.row.weight, reps: s.row.reps, rir: s.row.rir,
                                     duration: s.row.seconds.map { TimeInterval($0) }, distance: s.row.distance,
                                     setType: s.row.setType)
                    modelContext.insert(set)
                    set.exerciseLog = log
                    result.importedSets += 1
                    if s.row.setType == .warmup { result.warmupSets += 1 }
                    existingKeys.insert(setKey(date: first.date, exerciseName: exercise.name, order: s.order))
                }
            }
            result.imported += 1
        }
        try? modelContext.save()
    }

    // MARK: - Exercise matching

    /// Normalised-name index over the catalogue; creates custom exercises for unknown names.
    struct CatalogueIndex {
        private let modelContext: ModelContext
        private var byName: [String: Exercise] = [:]

        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            let all = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
            // Built-ins win over custom exercises with the same name.
            for e in all.sorted(by: { !$0.isCustom && $1.isCustom }) {
                let key = Exercise.normalisedName(e.name)
                if byName[key] == nil { byName[key] = e }
            }
        }

        func exercise(for name: String) -> Exercise? {
            for key in DataImportService.candidateKeys(for: name) {
                if let hit = byName[key] { return hit }
            }
            return nil
        }

        mutating func exerciseOrCreate(named name: String, result: inout ImportResult) -> Exercise {
            if let hit = exercise(for: name) { return hit }
            let created = Exercise(
                name: name,
                primaryMuscleGroups: [],
                equipmentType: DataImportService.equipment(in: name),
                movementPattern: .isolation,
                isCustom: true,
                isApproved: false
            )
            modelContext.insert(created)
            byName[Exercise.normalisedName(name)] = created
            result.unmatchedExercises.append(name)
            return created
        }
    }

    /// Normalised lookup keys for an imported name. "Bench Press (Barbell)" also tries
    /// "Barbell Bench Press" (Strong's naming); "Pull Up" also tries "Pull-Up" via normalisation.
    static func candidateKeys(for name: String) -> [String] {
        var keys = [Exercise.normalisedName(name)]
        if let open = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"), open < close {
            let base = name[..<open].trimmingCharacters(in: .whitespaces)
            let equipment = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            keys.append(Exercise.normalisedName("\(equipment) \(base)"))
            keys.append(Exercise.normalisedName(base))
        }
        return keys
    }

    static func equipment(in name: String) -> EquipmentType {
        let n = name.lowercased()
        if n.contains("dumbbell") { return .dumbbell }
        if n.contains("barbell") { return .barbell }
        if n.contains("cable") { return .cable }
        if n.contains("machine") { return .machine }
        if n.contains("kettlebell") { return .kettlebell }
        if n.contains("band") { return .band }
        if n.contains("smith") { return .smithMachine }
        if n.contains("bodyweight") { return .bodyweight }
        return .other
    }

    // MARK: - Dates

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    static func parseStrongDate(_ s: String) -> Date? {
        let text = s.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            if let d = formatter(format).date(from: text) { return d }
        }
        return nil
    }

    static func parseHevyDate(_ s: String) -> Date? {
        let text = s.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: text) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: text) { return d }
        for format in ["d MMM yyyy, HH:mm", "dd MMM yyyy, HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            if let d = formatter(format).date(from: text) { return d }
        }
        return nil
    }

    // MARK: - CSV Parser

    /// Column lookup by header name (falls back to "" when the column is absent).
    struct Header {
        private let index: [String: Int]
        init(_ names: [String]) {
            var map: [String: Int] = [:]
            for (i, n) in names.enumerated() {
                let key = n.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
                if map[key] == nil { map[key] = i }
            }
            index = map
        }
        /// First non-empty value among several candidate column names.
        func firstValue(_ row: [String], _ columns: [String]) -> String {
            for c in columns { let v = value(row, c); if !v.isEmpty { return v } }
            return ""
        }
        func value(_ row: [String], _ column: String) -> String {
            guard let i = index[column], row.indices.contains(i) else { return "" }
            return row[i]
        }
    }

    /// RFC 4180: quoted fields may contain commas, newlines and doubled quotes.
    static func parseCSV(_ string: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(string.replacingOccurrences(of: "\r\n", with: "\n")).makeIterator()
        var pending: Character? = nil
        func next() -> Character? { if let p = pending { pending = nil; return p }; return chars.next() }
        while let c = next() {
            if inQuotes {
                if c == "\"" {
                    if let n = next() {
                        if n == "\"" { field.append("\"") } else { inQuotes = false; pending = n }
                    } else { inQuotes = false }
                } else { field.append(c) }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r" {
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            } else {
                field.append(c)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
        }
        return rows
    }
}

private extension DataImportService.ImportResult {
    mutating func skip(_ reason: String) {
        skippedRows += 1
        if errors.count < 20 { errors.append(reason) }
    }
}
