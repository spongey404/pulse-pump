import Foundation
import SwiftData

/// Safety net for dirty tracking.
///
/// Mutation points call `markUpdated` explicitly (that is the primary mechanism). This tracker catches anything
/// that was missed, event-driven and cheap: SwiftData posts `ModelContext.didSave` with the identifiers of
/// inserted/updated objects (iOS 17+). For each touched synced record (child logs/sets resolve to their workout)
/// that is currently clean, the tracker re-maps it and compares the payload digest with the one stored at the last
/// sync. A real content change that nobody stamped gets `markUpdated()`; relationship-inverse noise (a new workout
/// "updates" its template and user, for instance) leaves the digest equal and is ignored. A full pass
/// (`reconcileAll`) runs at start and on every manual sync to cover deletions of child rows and edits made while
/// no tracker was installed.
///
/// Why not a pre-push scan only: that is O(history) on every push. Why not `hasChanges`/`changedModelsArray`:
/// autosave clears them before we can look. The engine's own saves are skipped via `service.isApplying`.
@MainActor
final class SyncChangeTracker {
    private unowned let service: SyncService
    private var observer: NSObjectProtocol?

    init(service: SyncService) { self.service = service }

    func install() {
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { [weak self] note in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.handle(note) }
            } else {
                let name = note.name, object = note.object, info = note.userInfo
                Task { @MainActor in self?.handle(Notification(name: name, object: object, userInfo: info)) }
            }
        }
    }

    func remove() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    // MARK: Event path

    func handle(_ note: Notification) {
        guard !service.isApplying, let ctx = note.object as? ModelContext,
              ctx.container === service.context?.container else { return }
        let keys = ModelContext.NotificationKey.self
        let inserted = note.userInfo?[keys.insertedIdentifiers.rawValue] as? [PersistentIdentifier] ?? []
        let updated = note.userInfo?[keys.updatedIdentifiers.rawValue] as? [PersistentIdentifier] ?? []
        guard !inserted.isEmpty || !updated.isEmpty else { return }

        var seen = Set<ObjectIdentifier>()
        var touched = false
        for id in inserted + updated {
            for record in Self.syncRoots(of: ctx.model(for: id)) where seen.insert(ObjectIdentifier(record)).inserted {
                touched = true
                _ = reconcile(record)
            }
        }
        if touched { service.localDataChanged() }
    }

    /// The synced record a changed model belongs to (children map to their workout); empty for unsynced models.
    static func syncRoots(of model: any PersistentModel) -> [any SyncRecord] {
        switch model {
        case let log as ExerciseLog: return log.workout.map { [$0] } ?? []
        case let set as SetLog: return set.exerciseLog?.workout.map { [$0] } ?? []
        case let w as Workout: return [w]
        case let x as Exercise: return x.isCustom ? [x] : []
        case let r as any SyncRecord: return [r]
        default: return []
        }
    }

    /// Stamps the record when its content differs from what was last synced. Returns true when it did.
    @discardableResult
    func reconcile(_ record: any SyncRecord) -> Bool {
        if let w = record as? Workout, w.isDraft { return false }
        guard record.syncedAt != nil, !record.isDirty, let fields = SyncMapper.fields(for: record) else { return false }
        let digest = SyncMapper.digest(fields)
        guard let old = record.syncDigest else { record.syncDigest = digest; return false }   // adopt (e.g. placeholders)
        guard old != digest else { return false }
        record.markUpdated()
        return true
    }

    // MARK: Full pass

    @discardableResult
    func reconcileAll(_ ctx: ModelContext) -> Int {
        var changed = 0
        func pass<T: SyncRecord>(_ d: FetchDescriptor<T>) {
            for r in (try? ctx.fetch(d)) ?? [] where reconcile(r) { changed += 1 }
        }
        pass(FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft }))
        pass(FetchDescriptor<WorkoutTemplate>())
        pass(FetchDescriptor<Split>())
        pass(FetchDescriptor<EquipmentProfile>())
        pass(FetchDescriptor<User>())
        pass(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
        return changed
    }
}
