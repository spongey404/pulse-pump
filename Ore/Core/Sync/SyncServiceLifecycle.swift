import Foundation
import SwiftData

/// Joins accounts to sync: the local-store owner marker and wipe (`SyncLifecycle`) and the new-device restore
/// wait (`RestoreGate`), both backed by `SyncService`.
@MainActor
final class SyncServiceLifecycle: SyncLifecycle, RestoreGate {
    private let base: SwiftDataSyncLifecycle
    private let sync: SyncService
    private let context: ModelContext

    init(container: ModelContainer, sync: SyncService = .shared) {
        base = SwiftDataSyncLifecycle(container: container)
        self.sync = sync
        context = container.mainContext
    }

    // MARK: SyncLifecycle
    var localOwnerUid: String? { base.localOwnerUid }
    func claimLocalStore(for uid: String) { base.claimLocalStore(for: uid) }

    func wipeLocalData() async {
        _ = await sync.flushPending()      // best effort: push what we can before the data goes
        sync.stop()
        sync.wipeLocalUserData()
        await base.wipeLocalData()
    }

    // MARK: RestoreGate
    var isInitialSyncComplete: Bool { sync.isInitialSyncComplete }

    func beginRestore(uid: String) { ensureRunning(uid: uid) }

    /// Starts syncing for `uid` unless it already is (idempotent; called on every sign-in and from the gate).
    func ensureRunning(uid: String) {
        if sync.isRunning, sync.uid == uid { return }
        sync.start(uid: uid, context: context)
    }
}
