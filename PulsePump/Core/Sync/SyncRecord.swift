import Foundation
import SwiftData

// Local bookkeeping shared by every model that syncs to Firestore (docs/sync-architecture.md).
//
//   dirty  = syncedAt == nil || updatedAt > syncedAt      (millisecond precision, like the wire format)
//   live   = deletedAt == nil                              (soft deletes: tombstones stay until the account is wiped)
//
// `syncedAt` always stores the `updatedAt` value that was pushed/applied (never "now"), so an edit made while
// a push is in flight is still seen as newer afterwards. `syncDigest` fingerprints the mapped payload at that
// moment; the change tracker compares against it to catch mutations nobody remembered to mark.

protocol SyncRecord: PersistentModel {
    var id: UUID { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var syncedAt: Date? { get set }
    var syncDigest: String? { get set }
    var schemaVersion: Int { get set }
}

extension Date {
    /// Wire precision: milliseconds since the Unix epoch.
    var syncMs: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }
    init(syncMs: Int64) { self.init(timeIntervalSince1970: Double(syncMs) / 1000) }
}

extension SyncRecord {
    var isLive: Bool { deletedAt == nil }

    var isDirty: Bool {
        guard let syncedAt else { return true }
        return updatedAt.syncMs > syncedAt.syncMs
    }

    /// Stamps a local edit. Always strictly newer (>= 1 ms) than the last stamp, even under clock skew.
    func markUpdated(now: Date = Date()) {
        updatedAt = max(now, updatedAt.addingTimeInterval(0.001))
    }

    /// Soft delete: the record stays (as a tombstone) so the deletion can propagate to other devices.
    func softDelete(now: Date = Date()) {
        deletedAt = now
        markUpdated(now: now)
    }

    /// Records that `updatedAt` is now identical to the remote copy.
    func markSynced(digest: String?) {
        syncedAt = updatedAt
        syncDigest = digest
    }
}

extension Workout {
    /// Finished (not a draft) and not deleted: the only workouts that count as history, stats or sync payload.
    var isHistory: Bool { !isDraft && deletedAt == nil }
}

extension WorkoutTemplate {
    /// Finished sessions of this template, ignoring soft-deleted ones and drafts.
    var liveWorkouts: [Workout] { workouts.filter(\.isHistory) }
}

extension User {
    var liveEquipmentProfiles: [EquipmentProfile] { equipmentProfiles.filter { $0.deletedAt == nil } }
}

extension ModelContext {
    /// Marks a synced record as edited. Call at every mutation point (the change tracker is only a safety net).
    func markUpdated(_ record: some SyncRecord) { record.markUpdated() }
    /// An edit to a workout's logs/sets dirties the workout (the sync unit embeds them).
    func markUpdated(_ log: ExerciseLog) { log.workout?.markUpdated() }
    func markUpdated(_ set: SetLog) { set.exerciseLog?.workout?.markUpdated() }

    /// Soft-deletes (sets `deletedAt` + `updatedAt`) instead of `delete`, so the deletion syncs.
    func softDelete(_ record: some SyncRecord) { record.softDelete() }
}
