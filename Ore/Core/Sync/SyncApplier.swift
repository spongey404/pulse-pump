import Foundation
import SwiftData

/// Firestore dictionary -> SwiftData, applying last-write-wins by `updatedAt` (remote must be strictly newer).
/// Missing optional fields get defaults and unknown fields are ignored (forward compatibility).
/// Relationships are linked by id: `templateId`, `selectedSplitId`, and exercises by local id (custom exercises)
/// or by normalised name (catalogue ids differ per install).
@MainActor
final class SyncApplier {
    enum Outcome: Equatable { case created, updated, deleted, skipped }

    let ctx: ModelContext
    private(set) var user: User?
    private var splits: [UUID: Split] = [:]
    private var templates: [UUID: WorkoutTemplate] = [:]
    private var workouts: [UUID: Workout] = [:]
    private var equipment: [UUID: EquipmentProfile] = [:]
    private var exById: [UUID: Exercise] = [:]
    private var exByName: [String: Exercise] = [:]
    private var prepared: Set<SyncCollection> = []

    init(ctx: ModelContext) {
        self.ctx = ctx
        self.user = (try? ctx.fetch(FetchDescriptor<User>()))?.first
        indexExercises()
    }

    private func indexExercises() {
        let all = (try? ctx.fetch(FetchDescriptor<Exercise>())) ?? []
        exById = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        exByName = [:]
        for e in all {
            let key = Exercise.normalisedName(e.name)
            guard !key.isEmpty else { continue }
            if let cur = exByName[key] {
                // Prefer live over deleted, then catalogue over custom.
                let better = (cur.deletedAt != nil && e.deletedAt == nil) || (cur.deletedAt == e.deletedAt && cur.isCustom && !e.isCustom)
                if better { exByName[key] = e }
            } else { exByName[key] = e }
        }
    }

    /// Loads the id index for a collection before its documents are applied.
    func prepare(_ c: SyncCollection) {
        guard !prepared.contains(c) else { return }
        prepared.insert(c)
        func index<T: SyncRecord>(_ type: T.Type) -> [UUID: T] {
            Dictionary(((try? ctx.fetch(FetchDescriptor<T>())) ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        }
        switch c {
        case .splits: splits = index(Split.self)
        case .templates: templates = index(WorkoutTemplate.self)
        case .workouts: workouts = index(Workout.self); templates = index(WorkoutTemplate.self)
        case .equipmentProfiles: equipment = index(EquipmentProfile.self)
        case .profile: splits = index(Split.self)
        case .customExercises, .bodyweight: break
        }
    }

    // MARK: Dispatch

    @discardableResult
    func apply(_ doc: RemoteDoc, in c: SyncCollection) -> Outcome {
        prepare(c)
        switch c {
        case .workouts: return applyWorkout(doc)
        case .templates: return applyTemplate(doc)
        case .splits: return applySplit(doc)
        case .equipmentProfiles: return applyEquipment(doc)
        case .customExercises: return applyCustomExercise(doc)
        case .profile: return applyProfile(doc)
        case .bodyweight: return .skipped   // handled by the service (App Group store, not SwiftData)
        }
    }

    private func isNewer(_ doc: RemoteDoc, than local: some SyncRecord) -> Bool { doc.updatedAtMs > local.updatedAt.syncMs }

    private func stamp(_ r: some SyncRecord, _ doc: RemoteDoc, digest: () -> SyncFields) {
        r.updatedAt = Date(syncMs: doc.updatedAtMs)
        r.deletedAt = doc.isDeleted ? Date(syncMs: doc.deletedAtMs ?? doc.updatedAtMs) : nil
        r.schemaVersion = max(SyncValue.int(doc.fields["schemaVersion"]) ?? 1, 1)
        r.markSynced(digest: SyncMapper.digest(digest()))
    }

    // MARK: Workouts

    private func applyWorkout(_ doc: RemoteDoc) -> Outcome {
        guard let id = UUID(uuidString: doc.id) else { return .skipped }
        let existing = workouts[id]
        if let existing {
            if existing.isDraft || !isNewer(doc, than: existing) { return .skipped }
        }
        if doc.isDeleted && existing == nil { return .skipped }

        let f = doc.fields
        let w: Workout
        let created = existing == nil
        if let existing { w = existing } else {
            w = Workout(isDraft: false)
            w.id = id
            ctx.insert(w)
            workouts[id] = w
        }
        let date = SyncValue.date(f["date"]) ?? Date(syncMs: doc.updatedAtMs)
        w.date = date
        if created { w.createdAt = date }
        w.duration = SyncValue.double(f["durationSec"]) ?? 0
        w.notes = SyncValue.string(f["notes"]) ?? ""
        w.calorieBurnEstimate = SyncValue.double(f["calories"]) ?? 0
        w.isDeload = SyncValue.bool(f["isDeload"]) ?? false
        w.isDraft = false
        w.user = user
        w.template = SyncValue.string(f["templateId"]).flatMap { UUID(uuidString: $0) }.flatMap { templates[$0] }

        let oldLogs = w.exerciseLogs
        w.exerciseLogs = []
        for log in oldLogs { ctx.delete(log) }
        for (i, e) in SyncValue.maps(f["exercises"]).sorted(by: { (SyncValue.int($0["order"]) ?? 0) < (SyncValue.int($1["order"]) ?? 0) }).enumerated() {
            let log = ExerciseLog(order: SyncValue.int(e["order"]) ?? i, notes: SyncValue.string(e["notes"]) ?? "")
            log.createdAt = date.addingTimeInterval(Double(i))
            log.updatedAt = date
            ctx.insert(log)
            log.exercise = resolveExercise(id: SyncValue.string(e["exerciseId"]), name: SyncValue.string(e["exerciseName"]) ?? "")
            log.workout = w
            for (j, s) in SyncValue.maps(e["sets"]).sorted(by: { (SyncValue.int($0["order"]) ?? 0) < (SyncValue.int($1["order"]) ?? 0) }).enumerated() {
                let set = SetLog(
                    order: SyncValue.int(s["order"]) ?? j,
                    weight: SyncValue.double(s["weightKg"]) ?? 0,
                    reps: SyncValue.int(s["reps"]) ?? 0,
                    rir: SyncValue.int(s["rir"]),
                    duration: SyncValue.double(s["durationSec"]),
                    distance: SyncValue.double(s["distanceM"]),
                    setType: SetType(rawValue: SyncValue.string(s["setType"]) ?? "") ?? .standard,
                    side: Side(rawValue: SyncValue.string(s["side"]) ?? "") ?? .both
                )
                set.timestamp = date
                set.createdAt = date
                ctx.insert(set)
                set.exerciseLog = log
            }
        }
        stamp(w, doc) { SyncMapper.fields(w) }
        return doc.isDeleted ? .deleted : (created ? .created : .updated)
    }

    /// Local exercise for a remote reference: by id (custom exercises, same-install catalogue), else by name.
    /// An unknown exercise becomes a local-only placeholder so history is never dropped.
    private func resolveExercise(id: String?, name: String) -> Exercise? {
        let uuid = id.flatMap { UUID(uuidString: $0) }
        if let uuid, let e = exById[uuid] { return e }
        let key = Exercise.normalisedName(name)
        if !key.isEmpty, let e = exByName[key] { return e }
        guard !key.isEmpty else { return nil }
        let e = Exercise(name: name, primaryMuscleGroups: [], equipmentType: .other, movementPattern: .isolation, isCustom: true)
        if let uuid { e.id = uuid }
        ctx.insert(e)
        e.updatedAt = Date(syncMs: 0)
        e.syncedAt = e.updatedAt          // local-only: never pushed
        exById[e.id] = e
        exByName[key] = e
        return e
    }

    // MARK: Templates

    private func applyTemplate(_ doc: RemoteDoc) -> Outcome {
        guard let id = UUID(uuidString: doc.id) else { return .skipped }
        let existing = templates[id]
        if let existing, !isNewer(doc, than: existing) { return .skipped }
        if doc.isDeleted && existing == nil { return .skipped }
        let f = doc.fields
        let t: WorkoutTemplate
        let created = existing == nil
        if let existing { t = existing } else {
            t = WorkoutTemplate(name: "")
            t.id = id
            ctx.insert(t)
            templates[id] = t
        }
        t.name = SyncValue.string(f["name"]) ?? ""
        t.notes = SyncValue.string(f["notes"]) ?? ""
        t.splitDays = SyncValue.array(f["splitDays"]).compactMap { $0 as? String }
        t.templateExercises = SyncValue.maps(f["exercises"]).enumerated().map { i, e in
            let name = SyncValue.string(e["exerciseName"]) ?? ""
            let ex = resolveExerciseNoCreate(id: SyncValue.string(e["exerciseId"]), name: name)
            return TemplateExercise(
                exerciseId: ex?.id ?? SyncValue.string(e["exerciseId"]).flatMap { UUID(uuidString: $0) } ?? UUID(),
                exerciseName: name,
                order: SyncValue.int(e["order"]) ?? i,
                targetSets: SyncValue.int(e["targetSets"]) ?? 3,
                targetReps: SyncValue.int(e["targetReps"]),
                targetRIR: SyncValue.int(e["targetRIR"]),
                restSeconds: SyncValue.int(e["restSeconds"]),
                notes: SyncValue.string(e["notes"])
            )
        }
        stamp(t, doc) { SyncMapper.fields(t) }
        return doc.isDeleted ? .deleted : (created ? .created : .updated)
    }

    private func resolveExerciseNoCreate(id: String?, name: String) -> Exercise? {
        if let uuid = id.flatMap({ UUID(uuidString: $0) }), let e = exById[uuid] { return e }
        let key = Exercise.normalisedName(name)
        return key.isEmpty ? nil : exByName[key]
    }

    // MARK: Splits

    private func applySplit(_ doc: RemoteDoc) -> Outcome {
        guard let id = UUID(uuidString: doc.id) else { return .skipped }
        let existing = splits[id]
        if let existing, !isNewer(doc, than: existing) { return .skipped }
        if doc.isDeleted && existing == nil { return .skipped }
        let f = doc.fields
        let s: Split
        let created = existing == nil
        if let existing { s = existing } else {
            s = Split(type: .custom, name: "x")
            s.id = id
            ctx.insert(s)
            splits[id] = s
        }
        s.type = SplitType(rawValue: SyncValue.string(f["type"]) ?? "") ?? .custom
        s.name = SyncValue.string(f["name"]) ?? s.type.displayName
        s.days = SyncValue.maps(f["days"]).map {
            SplitDay(dayOfWeek: SyncValue.int($0["dayOfWeek"]) ?? 2,
                     label: SyncValue.string($0["label"]) ?? "",
                     workoutType: SyncValue.string($0["workoutType"]) ?? "")
        }
        if doc.isDeleted, user?.selectedSplit === s { user?.selectedSplit = nil }
        stamp(s, doc) { SyncMapper.fields(s) }
        return doc.isDeleted ? .deleted : (created ? .created : .updated)
    }

    // MARK: Equipment profiles

    private func applyEquipment(_ doc: RemoteDoc) -> Outcome {
        guard let id = UUID(uuidString: doc.id) else { return .skipped }
        let existing = equipment[id]
        if let existing, !isNewer(doc, than: existing) { return .skipped }
        if doc.isDeleted && existing == nil { return .skipped }
        let f = doc.fields
        let e: EquipmentProfile
        let created = existing == nil
        if let existing { e = existing } else {
            e = EquipmentProfile(name: "")
            e.id = id
            ctx.insert(e)
            equipment[id] = e
        }
        e.name = SyncValue.string(f["name"]) ?? ""
        e.availableEquipment = SyncValue.array(f["equipment"]).compactMap { ($0 as? String).flatMap(EquipmentType.init(rawValue:)) }
        e.availablePlates = SyncValue.array(f["platesKg"]).compactMap { SyncValue.double($0) }
        e.barTypes = SyncValue.maps(f["bars"]).map { BarConfig(name: SyncValue.string($0["name"]) ?? "Bar", weightKg: SyncValue.double($0["weightKg"]) ?? 0) }
        e.user = user
        stamp(e, doc) { SyncMapper.fields(e) }
        return doc.isDeleted ? .deleted : (created ? .created : .updated)
    }

    // MARK: Custom exercises

    private func applyCustomExercise(_ doc: RemoteDoc) -> Outcome {
        guard let id = UUID(uuidString: doc.id) else { return .skipped }
        let existing = exById[id]
        if let existing {
            if !existing.isCustom || !isNewer(doc, than: existing) { return .skipped }
        }
        if doc.isDeleted && existing == nil { return .skipped }
        let f = doc.fields
        let x: Exercise
        let created = existing == nil
        if let existing { x = existing } else {
            x = Exercise(name: "", primaryMuscleGroups: [], equipmentType: .other, movementPattern: .isolation, isCustom: true)
            x.id = id
            ctx.insert(x)
            exById[id] = x
        }
        x.name = SyncValue.string(f["name"]) ?? ""
        x.isCustom = true
        x.primaryMuscleGroups = SyncValue.array(f["primaryMuscles"]).compactMap { ($0 as? String).flatMap(MuscleGroup.init(rawValue:)) }
        x.secondaryMuscleGroups = SyncValue.array(f["secondaryMuscles"]).compactMap { ($0 as? String).flatMap(MuscleGroup.init(rawValue:)) }
        x.primarySubRegions = SyncValue.array(f["primarySubRegions"]).compactMap { ($0 as? String).flatMap(MuscleSubRegion.init(rawValue:)) }
        x.secondarySubRegions = SyncValue.array(f["secondarySubRegions"]).compactMap { ($0 as? String).flatMap(MuscleSubRegion.init(rawValue:)) }
        x.equipmentType = EquipmentType(rawValue: SyncValue.string(f["equipmentType"]) ?? "") ?? .other
        x.movementPattern = MovementPattern(rawValue: SyncValue.string(f["movementPattern"]) ?? "") ?? .isolation
        x.exerciseType = ExerciseType(rawValue: SyncValue.string(f["exerciseType"]) ?? "") ?? .weighted
        x.isUnilateral = SyncValue.bool(f["isUnilateral"]) ?? false
        x.isApproved = SyncValue.bool(f["isApproved"]) ?? true
        if let c = SyncValue.date(f["createdAt"]) { x.createdAt = c }
        stamp(x, doc) { SyncMapper.fields(x) }
        let key = Exercise.normalisedName(x.name)
        if !key.isEmpty, exByName[key] == nil || exByName[key]?.isCustom == true { exByName[key] = x }
        return doc.isDeleted ? .deleted : (created ? .created : .updated)
    }

    // MARK: Profile

    private func applyProfile(_ doc: RemoteDoc) -> Outcome {
        let f = doc.fields
        let u: User
        let created: Bool
        if let user {
            guard isNewer(doc, than: user) else { return .skipped }
            u = user; created = false
        } else {
            // Only a document this engine wrote (it carries `unit`) can recreate the user and skip onboarding.
            guard f["unit"] != nil else { return .skipped }
            u = User(name: "")
            ctx.insert(u)
            user = u; created = true
        }
        if let v = SyncValue.string(f["name"]) { u.name = v }
        if let v = SyncValue.string(f["username"]) { u.username = v }
        if let v = SyncValue.string(f["unit"]).flatMap(UnitPreference.init(rawValue:)) { u.unitPreference = v }
        if let v = SyncValue.string(f["experienceLevel"]).flatMap(ExperienceLevel.init(rawValue:)) { u.experienceLevel = v }
        if let v = SyncValue.string(f["gender"]).flatMap(Gender.init(rawValue:)) { u.gender = v }
        if let v = SyncValue.int(f["age"]) { u.age = v }
        if let v = SyncValue.double(f["heightCm"]) { u.height = v }
        if let v = SyncValue.double(f["weightKg"]) { u.weight = v }
        if let v = SyncValue.date(f["createdAt"]) { u.createdAt = v }
        u.selectedSplit = SyncValue.string(f["selectedSplitId"]).flatMap { UUID(uuidString: $0) }.flatMap { splits[$0] }
        if u.selectedSplit?.deletedAt != nil { u.selectedSplit = nil }
        // Whole-document LWW: a newer document without `progression` means it was cleared on the other device.
        let prog = f["progression"] as? [String: Any]
        var thresholds: [String: Int] = [:]
        for row in (prog?["thresholds"] as? [[String: Any]]) ?? [] {
            if let k = SyncValue.string(row["name"]), !k.isEmpty, let n = SyncValue.int(row["reps"]),
               ProgressionRule.thresholdRange.contains(n), thresholds.count < User.maxProgressionThresholds { thresholds[k] = n }
        }
        u.progressionThresholds = thresholds
        u.progressionIncrementKg = SyncValue.double(prog?["incrementKg"]).flatMap { $0 > 0 && $0 <= 50 ? $0 : nil }
        u.updatedAt = Date(syncMs: doc.updatedAtMs)
        u.schemaVersion = max(SyncValue.int(f["schemaVersion"]) ?? 1, 1)
        u.markSynced(digest: SyncMapper.digest(SyncMapper.fields(u)))
        return created ? .created : .updated
    }
}
