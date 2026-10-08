import Foundation
import SwiftData
import Observation
import UIKit

/// Offline-first cloud sync for personal data (docs/sync-architecture.md).
///
/// SwiftData stays the source of truth. A cycle is: pull (per-collection cursors, apply when the remote is
/// strictly newer) then push (dirty records, batched <= 400, `syncedAt` set only after success). Everything is
/// idempotent by document id, never blocks the UI, and a failed cycle leaves records dirty for the next one.
///
/// Integration (Auth agent): `start(uid:context:)` after sign-in, `stop()` on sign-out together with
/// `flushPending()` / `wipeLocalUserData()`. Gate the main UI on `isInitialSyncComplete`.
@MainActor
@Observable
final class SyncService {
    static let shared = SyncService()

    enum Status: Equatable {
        case idle, syncing, offline
        case error(String)
    }

    struct Config {
        var batchSize = RemoteLimits.maxBatch
        var pageSize = RemoteLimits.pageSize
        /// Quiet period after a local save before pushing.
        var debounce: TimeInterval = 5
        /// Retry delays after consecutive failures (the last one repeats).
        var backoff: [TimeInterval] = [5, 15, 45, 120, 300]
        /// Minimum gap between foreground-triggered full syncs.
        var foregroundThrottle: TimeInterval = 30
    }

    // MARK: Observable state
    private(set) var status: Status = .idle
    private(set) var lastSyncedAt: Date?
    private(set) var isInitialSyncComplete = false
    /// 0...1 while the first full pull runs.
    private(set) var initialSyncProgress: Double = 0
    /// Records waiting to be pushed (refreshed after every cycle and local save).
    private(set) var pendingCount = 0
    private(set) var isRunning = false

    // MARK: Dependencies / config
    @ObservationIgnored var config = Config()
    /// Tests turn this off so they do not touch the shared App Group.
    @ObservationIgnored var clearsWidgetData = true
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bodyweightDefaults: UserDefaults?
    @ObservationIgnored private let remoteFactory: (String) -> RemoteStore
    /// Test hook: replaces `Task.sleep`.
    @ObservationIgnored var sleep: (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }

    @ObservationIgnored private(set) var uid: String?
    @ObservationIgnored private(set) var context: ModelContext?
    @ObservationIgnored private var remote: RemoteStore?
    @ObservationIgnored private var tracker: SyncChangeTracker?
    @ObservationIgnored private var foregroundObserver: NSObjectProtocol?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var cycleInFlight = false
    @ObservationIgnored private var rerunRequested: Cycle?
    @ObservationIgnored private var failures = 0
    /// Delay before the next automatic retry after a failed cycle (nil when the last cycle succeeded).
    @ObservationIgnored private(set) var scheduledRetryDelay: TimeInterval?
    @ObservationIgnored private var lastFullAttempt: Date?
    /// True while the engine itself mutates SwiftData (applying remote data, stamping `syncedAt`), so the
    /// change tracker does not mistake those saves for user edits.
    @ObservationIgnored private(set) var isApplying = false

    enum Cycle { case full, pushOnly }

    init(defaults: UserDefaults = .standard,
         bodyweightDefaults: UserDefaults? = nil,
         remoteFactory: @escaping (String) -> RemoteStore = { FirestoreRemoteStore(uid: $0) }) {
        self.defaults = defaults
        self.bodyweightDefaults = bodyweightDefaults
        self.remoteFactory = remoteFactory
    }

    // MARK: - Lifecycle

    /// Call after sign-in (and on every launch with a restored session). Wipes local data first when a
    /// different account than last time signs in, installs the change tracker and kicks off a full sync.
    func start(uid: String, context: ModelContext, remote: RemoteStore? = nil, triggerSync: Bool = true) {
        stop()
        self.uid = uid
        self.context = context
        self.remote = remote ?? remoteFactory(uid)

        if let last = SyncAccount.lastUid(defaults), last != uid {
            wipeLocalUserData()                                    // different account: never mix data
        }
        SyncAccount.setLastUid(uid, defaults)

        isInitialSyncComplete = defaults.bool(forKey: Self.initialKey(uid))
        initialSyncProgress = isInitialSyncComplete ? 1 : 0
        lastSyncedAt = (defaults.object(forKey: Self.lastKey(uid)) as? Double).map(Date.init(timeIntervalSince1970:))
        status = .idle
        isRunning = true
        failures = 0

        let tracker = SyncChangeTracker(service: self)
        tracker.install()
        self.tracker = tracker
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.appDidBecomeActive() }
        }
        refreshPendingCount()
        if triggerSync { Task { await self.run(.full) } }
    }

    /// Stops all triggers and in-flight retries. Local data is untouched.
    func stop() {
        debounceTask?.cancel(); debounceTask = nil
        retryTask?.cancel(); retryTask = nil
        tracker?.remove(); tracker = nil
        if let o = foregroundObserver { NotificationCenter.default.removeObserver(o) }
        foregroundObserver = nil
        isRunning = false
        rerunRequested = nil
    }

    /// Manual "Sync now" (also the public entry point for tests). Pull then push.
    func syncNow() async { await run(.full, manual: true) }

    func appDidBecomeActive() {
        guard isRunning else { return }
        if let last = lastFullAttempt, Date().timeIntervalSince(last) < config.foregroundThrottle { return }
        Task { await self.run(.full) }
    }

    /// Debounced push after local saves (called by the change tracker).
    func localDataChanged() {
        guard isRunning else { return }
        refreshPendingCount()
        guard pendingCount > 0 else { return }
        debounceTask?.cancel()
        let delay = config.debounce
        debounceTask = Task { [weak self] in
            guard let self else { return }
            await self.sleep(delay)
            guard !Task.isCancelled else { return }
            await self.run(.pushOnly)
        }
    }

    /// Best effort push of everything dirty (before sign-out). True when nothing is left unsynced.
    func flushPending() async -> Bool {
        await run(.pushOnly, manual: true)
        refreshPendingCount()
        return pendingCount == 0
    }

    // MARK: - Cycle

    private func run(_ cycle: Cycle, manual: Bool = false) async {
        guard let remote, let ctx = context, let uid else { return }
        if cycleInFlight {
            rerunRequested = (rerunRequested == .full || cycle == .full) ? .full : .pushOnly
            return
        }
        cycleInFlight = true
        retryTask?.cancel(); retryTask = nil
        status = .syncing
        if cycle == .full { lastFullAttempt = Date() }
        let initial = !isInitialSyncComplete
        if initial { initialSyncProgress = 0 }
        var failed = false
        do {
            tracker?.reconcileAll(ctx)
            if cycle == .full || initial { try await pull(remote: remote, ctx: ctx, uid: uid, reportProgress: initial) }
            try await push(remote: remote, ctx: ctx, uid: uid)
            failures = 0
            scheduledRetryDelay = nil
            lastSyncedAt = Date()
            defaults.set(lastSyncedAt!.timeIntervalSince1970, forKey: Self.lastKey(uid))
            if initial {
                isInitialSyncComplete = true
                initialSyncProgress = 1
                defaults.set(true, forKey: Self.initialKey(uid))
            }
            status = .idle
        } catch {
            failed = true
            failures += 1
            let remoteError = (error as? RemoteError) ?? .transient(error.localizedDescription)
            status = remoteError.isOffline ? .offline : .error(remoteError.message)
        }
        refreshPendingCount()
        cycleInFlight = false

        if failed {
            scheduleRetry()
        } else if let again = rerunRequested {
            rerunRequested = nil
            await run(again)
        }
    }

    private func scheduleRetry() {
        guard isRunning else { return }
        let delay = config.backoff[min(max(failures - 1, 0), config.backoff.count - 1)]
        scheduledRetryDelay = delay
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self else { return }
            await self.sleep(delay)
            guard !Task.isCancelled else { return }
            await self.run(.full)
        }
    }

    // MARK: - Pull

    private func pull(remote: RemoteStore, ctx: ModelContext, uid: String, reportProgress: Bool) async throws {
        let applier = SyncApplier(ctx: ctx)
        let collections = SyncCollection.allCases
        for (index, c) in collections.enumerated() {
            var sinceMs = Int64(defaults.integer(forKey: Self.cursorKey(uid, c)))
            var after: RemoteCursor?
            while true {
                let docs = try await remote.fetchChanged(c, sinceMs: sinceMs, limit: config.pageSize, after: after)
                isApplying = true
                for doc in docs {
                    if c == .bodyweight { applyBodyweight(doc) } else { applier.apply(doc, in: c) }
                }
                try? ctx.save()
                isApplying = false
                if let last = docs.last {
                    after = RemoteCursor(updatedAtMs: last.updatedAtMs, docId: last.id)
                    sinceMs = max(sinceMs, last.updatedAtMs)
                    defaults.set(Int(sinceMs), forKey: Self.cursorKey(uid, c))   // resumable after a crash/offline
                }
                if reportProgress {
                    initialSyncProgress = (Double(index) + (docs.count < config.pageSize ? 1 : 0.5)) / Double(collections.count + 1)
                }
                if docs.count < config.pageSize { break }
            }
        }
    }

    private func applyBodyweight(_ doc: RemoteDoc) {
        guard let day = SyncMapper.bodyweightDay(id: doc.id), let kg = SyncValue.double(doc.fields["kg"]) else { return }
        BodyweightLog.applyRemote(day: day, kg: kg, updatedAt: Date(syncMs: doc.updatedAtMs), defaults: bodyweightDefaults)
    }

    // MARK: - Push

    private struct Pending {
        let write: RemoteWrite
        let markSynced: () -> Void
    }

    private func collectPending(ctx: ModelContext, uid: String) -> [Pending] {
        var out: [Pending] = []

        func add<T: SyncRecord>(_ records: [T], _ c: SyncCollection, id: (T) -> String, fields: (T) -> SyncFields) {
            for r in records where r.isDirty {
                let f = fields(r)
                let sent = r.updatedAt
                let digest = SyncMapper.digest(f)
                let write = RemoteWrite(collection: c, id: id(r), fields: f,
                                        deleteFields: SyncMapper.optionalKeys(c).filter { f[$0] == nil })
                out.append(Pending(write: write, markSynced: { r.syncedAt = sent; r.syncDigest = digest }))
            }
        }
        func fetch<T: PersistentModel>(_ d: FetchDescriptor<T> = FetchDescriptor<T>()) -> [T] { (try? ctx.fetch(d)) ?? [] }

        if let user = fetch(FetchDescriptor<User>()).first {
            add([user], .profile, id: { _ in uid }, fields: { SyncMapper.fields($0) })
        }
        add(fetch(FetchDescriptor<Split>()), .splits, id: { SyncMapper.idString($0.id) }, fields: { SyncMapper.fields($0) })
        add(fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom })), .customExercises,
            id: { SyncMapper.idString($0.id) }, fields: { SyncMapper.fields($0) })
        add(fetch(FetchDescriptor<EquipmentProfile>()), .equipmentProfiles, id: { SyncMapper.idString($0.id) }, fields: { SyncMapper.fields($0) })
        add(fetch(FetchDescriptor<WorkoutTemplate>()), .templates, id: { SyncMapper.idString($0.id) }, fields: { SyncMapper.fields($0) })
        add(fetch(FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft })), .workouts,
            id: { SyncMapper.idString($0.id) }, fields: { SyncMapper.fields($0) })

        for entry in BodyweightLog.dirtyEntries(defaults: bodyweightDefaults) {
            let updated = entry.updatedAt ?? Self.dayDate(entry.day)
            let write = RemoteWrite(collection: .bodyweight, id: SyncMapper.bodyweightId(day: entry.day),
                                    fields: SyncMapper.bodyweightFields(kg: entry.kg, updatedAt: updated))
            var sent = entry
            sent.updatedAt = entry.updatedAt ?? updated
            let store = bodyweightDefaults
            out.append(Pending(write: write, markSynced: { BodyweightLog.markSynced([sent], defaults: store) }))
        }
        return out
    }

    private static func dayDate(_ day: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return (f.date(from: day) ?? Date()).addingTimeInterval(12 * 3600)
    }

    private func push(remote: RemoteStore, ctx: ModelContext, uid: String) async throws {
        let pending = collectPending(ctx: ctx, uid: uid)
        guard !pending.isEmpty else { return }
        var permanentFailures = 0
        var index = 0
        while index < pending.count {
            let chunk = Array(pending[index ..< min(index + config.batchSize, pending.count)])
            index += config.batchSize
            do {
                try await remote.batchWrite(chunk.map(\.write))
                markSynced(chunk, ctx: ctx)
            } catch let e as RemoteError where e.isPermanent {
                // One bad document (rules rejection) must not block the rest: retry one by one.
                for p in chunk {
                    do { try await remote.batchWrite([p.write]); markSynced([p], ctx: ctx) }
                    catch let e as RemoteError where e.isPermanent { permanentFailures += 1 }
                }
            }
        }
        if permanentFailures > 0 {
            throw RemoteError.permanent("\(permanentFailures) item\(permanentFailures == 1 ? "" : "s") could not be synced")
        }
    }

    private func markSynced(_ chunk: [Pending], ctx: ModelContext) {
        isApplying = true
        for p in chunk { p.markSynced() }
        try? ctx.save()
        isApplying = false
    }

    // MARK: - Pending count

    func refreshPendingCount() {
        guard let ctx = context else { pendingCount = 0; return }
        pendingCount = Self.dirtyCount(ctx, bodyweight: bodyweightDefaults)
    }

    static func dirtyCount(_ ctx: ModelContext, bodyweight: UserDefaults? = nil) -> Int {
        func n<T: SyncRecord>(_ d: FetchDescriptor<T>) -> Int { ((try? ctx.fetch(d)) ?? []).filter(\.isDirty).count }
        return n(FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft }))
            + n(FetchDescriptor<WorkoutTemplate>()) + n(FetchDescriptor<Split>())
            + n(FetchDescriptor<EquipmentProfile>()) + n(FetchDescriptor<User>())
            + n(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
            + BodyweightLog.dirtyEntries(defaults: bodyweight).count
    }

    // MARK: - Account

    /// Removes all personal data from this device (sign-out, account switch). The exercise catalogue stays.
    func wipeLocalUserData() {
        guard let ctx = context else { return }
        SyncAccount.wipe(ctx, defaults: defaults, bodyweightDefaults: bodyweightDefaults, clearWidgetData: clearsWidgetData)
        isInitialSyncComplete = false
        initialSyncProgress = 0
        lastSyncedAt = nil
        pendingCount = 0
    }

    // MARK: - Keys

    static func cursorKey(_ uid: String, _ c: SyncCollection) -> String { "sync.cursor.\(uid).\(c.rawValue)" }
    static func initialKey(_ uid: String) -> String { "sync.initial.\(uid)" }
    static func lastKey(_ uid: String) -> String { "sync.last.\(uid)" }

    // MARK: - Display

    var statusText: String {
        switch status {
        case .syncing: return isInitialSyncComplete ? "Syncing…" : "Restoring your data…"
        case .offline: return "Offline — will sync when connected"
        case .error(let m): return "Sync problem: \(m)"
        case .idle:
            if !isRunning { return "Sign in to sync" }
            return pendingCount > 0 ? "\(pendingCount) change\(pendingCount == 1 ? "" : "s") waiting" : "Up to date"
        }
    }
}
