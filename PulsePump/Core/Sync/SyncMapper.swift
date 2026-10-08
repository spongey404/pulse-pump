import Foundation

/// SwiftData model -> Firestore dictionary. Field names are the contract in docs/sync-architecture.md.
/// Invariants: weights are kg, distances metres, durations seconds; `updatedAt` / `deletedAt` are epoch ms;
/// `deletedAt` is present only when set; ids are lower-case UUID strings; unknown fields are never produced
/// or required. Optional fields are omitted when nil (the service lists them in `RemoteWrite.deleteFields`).
enum SyncMapper {
    static let schemaVersion = 1

    // Rules caps (firebase/firestore.rules): clamp so one oversized note can never poison a batch forever.
    static let maxNotes = 5000
    static let maxName = 200

    static func idString(_ id: UUID) -> String { id.uuidString.lowercased() }

    /// Optional top-level keys per collection (cleared remotely when nil locally).
    static func optionalKeys(_ c: SyncCollection) -> [String] {
        switch c {
        case .workouts: ["templateId", "templateName", "deletedAt"]
        case .profile: ["selectedSplitId"]
        case .templates, .splits, .equipmentProfiles, .customExercises: ["deletedAt"]
        case .bodyweight: []
        }
    }

    private static func header(_ r: some SyncRecord, into f: inout SyncFields) {
        f["schemaVersion"] = max(r.schemaVersion, schemaVersion)
        f["updatedAt"] = r.updatedAt.syncMs
        if let d = r.deletedAt { f["deletedAt"] = d.syncMs }
    }

    private static func clamp(_ s: String, _ n: Int) -> String { s.count > n ? String(s.prefix(n)) : s }

    // MARK: Workout

    static func fields(_ w: Workout) -> SyncFields {
        var f: SyncFields = [
            "date": w.date,
            "durationSec": w.duration,
            "notes": clamp(w.notes, maxNotes),
            "calories": w.calorieBurnEstimate,
            "isDeload": w.isDeload,
        ]
        if let t = w.template {
            f["templateId"] = idString(t.id)
            f["templateName"] = clamp(t.name, maxName)
        }
        let logs = w.exerciseLogs.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
        f["exercises"] = logs.map { log -> [String: Any] in
            var e: [String: Any] = [
                "exerciseId": idString(log.exercise?.id ?? log.id),
                "exerciseName": clamp(log.exercise?.name ?? "", maxName),
                "order": log.order,
                "notes": clamp(log.notes, maxNotes),
            ]
            e["sets"] = log.sets.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }.map(setFields)
            return e
        }
        header(w, into: &f)
        return f
    }

    private static func setFields(_ s: SetLog) -> [String: Any] {
        var d: [String: Any] = [
            "order": s.order,
            "weightKg": s.weight,
            "reps": s.reps,
            "setType": s.setType.rawValue,
            "side": s.side.rawValue,
        ]
        if let rir = s.rir { d["rir"] = rir }
        if let t = s.duration { d["durationSec"] = t }
        if let m = s.distance { d["distanceM"] = m }
        return d
    }

    // MARK: Template

    static func fields(_ t: WorkoutTemplate) -> SyncFields {
        var f: SyncFields = [
            "name": clamp(t.name, maxName),
            "splitDays": t.splitDays,
            "notes": clamp(t.notes, maxNotes),
        ]
        f["exercises"] = t.templateExercises.sorted { $0.order < $1.order }.map { e -> [String: Any] in
            var d: [String: Any] = [
                "exerciseId": idString(e.exerciseId),
                "exerciseName": clamp(e.exerciseName, maxName),
                "order": e.order,
                "targetSets": e.targetSets,
            ]
            if let v = e.targetReps { d["targetReps"] = v }
            if let v = e.targetRIR { d["targetRIR"] = v }
            if let v = e.restSeconds { d["restSeconds"] = v }
            if let v = e.notes { d["notes"] = v }
            return d
        }
        header(t, into: &f)
        return f
    }

    // MARK: Split

    static func fields(_ s: Split) -> SyncFields {
        var f: SyncFields = [
            "type": s.type.rawValue,
            "name": clamp(s.name, maxName),
            "days": s.days.map { ["dayOfWeek": $0.dayOfWeek, "label": $0.label, "workoutType": $0.workoutType] as [String: Any] },
        ]
        header(s, into: &f)
        return f
    }

    // MARK: Equipment profile

    static func fields(_ e: EquipmentProfile) -> SyncFields {
        var f: SyncFields = [
            "name": clamp(e.name, maxName),
            "equipment": e.availableEquipment.map(\.rawValue),
            "platesKg": e.availablePlates,
            "bars": e.barTypes.map { ["name": $0.name, "weightKg": $0.weightKg] as [String: Any] },
        ]
        header(e, into: &f)
        return f
    }

    // MARK: Custom exercise

    static func fields(_ x: Exercise) -> SyncFields {
        var f: SyncFields = [
            "name": clamp(x.name, maxName),
            "primaryMuscles": x.primaryMuscleGroups.map(\.rawValue),
            "secondaryMuscles": x.secondaryMuscleGroups.map(\.rawValue),
            "primarySubRegions": x.primarySubRegions.map(\.rawValue),
            "secondarySubRegions": x.secondarySubRegions.map(\.rawValue),
            "equipmentType": x.equipmentType.rawValue,
            "movementPattern": x.movementPattern.rawValue,
            "exerciseType": x.exerciseType.rawValue,
            "isUnilateral": x.isUnilateral,
            "isApproved": x.isApproved,
            "createdAt": x.createdAt,
        ]
        header(x, into: &f)
        return f
    }

    // MARK: Profile (users/{uid}) — only the fields this engine owns; `privacy` and social fields are never written.

    static func fields(_ u: User) -> SyncFields {
        var f: SyncFields = [
            "name": clamp(u.name, 100),
            "username": clamp(u.username, 40),
            "unit": u.unitPreference.rawValue,
            "experienceLevel": u.experienceLevel.rawValue,
            "gender": u.gender.rawValue,
            "age": u.age,
            "heightCm": u.height,
            "weightKg": u.weight,
            "createdAt": u.createdAt,
        ]
        if let s = u.selectedSplit, s.deletedAt == nil { f["selectedSplitId"] = idString(s.id) }
        header(u, into: &f)
        return f
    }

    // MARK: Bodyweight (users/{uid}/bodyweight/{yyyyMMdd})

    static func bodyweightId(day: String) -> String { day.replacingOccurrences(of: "-", with: "") }
    static func bodyweightDay(id: String) -> String? {
        guard id.count == 8, id.allSatisfy(\.isNumber) else { return nil }
        let c = Array(id)
        return String(c[0..<4]) + "-" + String(c[4..<6]) + "-" + String(c[6..<8])
    }
    static func bodyweightFields(kg: Double, updatedAt: Date) -> SyncFields {
        ["kg": kg, "updatedAt": updatedAt.syncMs]
    }

    // MARK: Digest

    /// Stable fingerprint of a payload's content (ignores `updatedAt`). FNV-1a 64 over a canonical string
    /// (`hashValue` is randomised per launch, so it cannot be persisted).
    static func digest(_ fields: SyncFields) -> String {
        var copy = fields
        copy.removeValue(forKey: "updatedAt")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in canonical(copy).utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return String(hash, radix: 16)
    }

    private static func canonical(_ v: Any) -> String {
        switch v {
        case let d as [String: Any]:
            return "{" + d.keys.sorted().map { "\($0):\(canonical(d[$0]!))" }.joined(separator: ",") + "}"
        case let a as [Any]:
            return "[" + a.map(canonical).joined(separator: ",") + "]"
        case let s as String: return "\"\(s)\""
        case let b as Bool: return b ? "T" : "F"
        case let d as Date: return "d\(d.syncMs)"
        case let n as Int: return "n\(n)"
        case let n as Int64: return "n\(n)"
        case let n as Double: return n == n.rounded() && abs(n) < 1e15 ? "n\(Int64(n))" : "n\(n)"
        case is NSNull: return "null"
        default: return "?\(v)"
        }
    }

    /// Payload for the record, by type (used by the service, tracker and tests).
    static func fields(for record: any SyncRecord) -> SyncFields? {
        switch record {
        case let w as Workout: return fields(w)
        case let t as WorkoutTemplate: return fields(t)
        case let s as Split: return fields(s)
        case let e as EquipmentProfile: return fields(e)
        case let x as Exercise: return fields(x)
        case let u as User: return fields(u)
        default: return nil
        }
    }
}
