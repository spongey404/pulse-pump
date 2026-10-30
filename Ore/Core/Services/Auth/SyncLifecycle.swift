import Foundation
import SwiftData

// Seams between accounts (this module) and the sync layer (SYNC agent). The lead wires the real
// implementations; the defaults here keep the app working standalone.

/// Owns the on-device store from the account's point of view.
@MainActor
protocol SyncLifecycle: AnyObject {
    /// The uid whose data is in the local store (nil for a store created before accounts / an empty store).
    var localOwnerUid: String? { get }
    /// Record that the local store now belongs to `uid` (called once a user is signed in and the store is theirs).
    func claimLocalStore(for uid: String)
    /// Stop syncing and delete every local user record (workouts, templates, splits, equipment, custom exercises,
    /// profile, sync cursors, widget snapshot). Must NOT write tombstones to the cloud.
    func wipeLocalData() async
}

/// Tells the gate when the first pull for a signed-in user (new device / reinstall) has finished.
/// The sync pull creates the local `User` from `users/{uid}`. Back it with `SyncService.isInitialSyncComplete`.
@MainActor
protocol RestoreGate: AnyObject {
    var isInitialSyncComplete: Bool { get }
    /// Called when the gate starts waiting for `uid` (kick off / retry the initial pull).
    func beginRestore(uid: String)
}

/// Default: nothing to wait for.
@MainActor
final class ImmediateRestoreGate: RestoreGate {
    var isInitialSyncComplete: Bool { true }
    func beginRestore(uid: String) {}
}

/// Default no-op adapter (tests, previews).
@MainActor
final class NoOpSyncLifecycle: SyncLifecycle {
    private(set) var localOwnerUid: String?
    private(set) var wipeCount = 0
    init(owner: String? = nil) { localOwnerUid = owner }
    func claimLocalStore(for uid: String) { localOwnerUid = uid }
    func wipeLocalData() async {
        wipeCount += 1
        localOwnerUid = nil
    }
}

/// Real local wipe over SwiftData plus the owner marker in UserDefaults. Used until the lead swaps in
/// a `SyncService`-backed lifecycle (which should do the same plus stop its listeners).
@MainActor
final class SwiftDataSyncLifecycle: SyncLifecycle {
    static let ownerKey = "localStoreOwnerUid"
    /// Per-user preferences that must not leak to the next account on the device.
    static let userDefaultsKeysToClear = ["wantsTutorial"]

    private let container: ModelContainer
    private let defaults: UserDefaults

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
    }

    var localOwnerUid: String? { defaults.string(forKey: Self.ownerKey) }

    func claimLocalStore(for uid: String) { defaults.set(uid, forKey: Self.ownerKey) }

    func wipeLocalData() async {
        let context = container.mainContext
        // Children first; relationship delete rules would also cascade, this is just explicit.
        try? context.delete(model: SetLog.self)
        try? context.delete(model: ExerciseLog.self)
        try? context.delete(model: Workout.self)
        try? context.delete(model: WorkoutTemplate.self)
        try? context.delete(model: EquipmentProfile.self)
        try? context.delete(model: Split.self)
        try? context.delete(model: Challenge.self)
        try? context.delete(model: UserProfile.self)
        try? context.delete(model: User.self)
        // The seeded catalogue stays; custom exercises belong to the account.
        try? context.delete(model: Exercise.self, where: #Predicate<Exercise> { $0.isCustom })
        try? context.save()
        defaults.removeObject(forKey: Self.ownerKey)
        for key in Self.userDefaultsKeysToClear { defaults.removeObject(forKey: key) }
    }
}
