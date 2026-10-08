import Foundation

/// A fake cloud for unit tests and previews. Behaves like Firestore for what sync relies on: merge writes,
/// (updatedAt, id) ordering with strict-after paging, and injectable failures. It does not enforce
/// last-write-wins itself (that is the client's job); tests play "another device" by calling `put`.
final class InMemoryRemoteStore: RemoteStore {
    private(set) var docs: [SyncCollection: [String: SyncFields]] = [:]

    // Instrumentation
    private(set) var batchSizes: [Int] = []
    private(set) var fetchPageSizes: [Int] = []
    private(set) var writeCount = 0
    private(set) var fetchCalls = 0

    // Failure injection
    var isOffline = false
    /// The next N calls (fetch or write) throw `failureError`, then it recovers.
    var failNextCalls = 0
    var failureError: RemoteError = .transient("simulated outage")
    /// Document ids whose writes are rejected permanently (simulates a rules violation).
    var rejectedIds: Set<String> = []
    /// Max documents per batch before the store rejects the batch (Firestore: 500).
    var maxBatch = 500

    init() {}

    // MARK: Test helpers ("another device")

    func put(_ collection: SyncCollection, id: String, _ fields: SyncFields) {
        var d = docs[collection] ?? [:]
        var merged = d[id] ?? [:]
        for (k, v) in fields { merged[k] = v }
        d[id] = merged
        docs[collection] = d
    }

    func doc(_ collection: SyncCollection, id: String) -> SyncFields? { docs[collection]?[id] }
    func count(_ collection: SyncCollection) -> Int { docs[collection]?.count ?? 0 }
    func ids(_ collection: SyncCollection) -> [String] { (docs[collection] ?? [:]).keys.sorted() }
    func removeAll() { docs = [:] }

    private func checkFailure() throws {
        if isOffline { throw RemoteError.offline }
        if failNextCalls > 0 { failNextCalls -= 1; throw failureError }
    }

    // MARK: RemoteStore

    func fetchChanged(_ collection: SyncCollection, sinceMs: Int64, limit: Int, after: RemoteCursor?) async throws -> [RemoteDoc] {
        fetchCalls += 1
        try checkFailure()
        let all = (docs[collection] ?? [:]).map { RemoteDoc(id: $0.key, fields: $0.value) }
        let sorted = all
            .filter { $0.updatedAtMs >= sinceMs && $0.fields["updatedAt"] != nil }
            .sorted { ($0.updatedAtMs, $0.id) < ($1.updatedAtMs, $1.id) }
        let page = sorted.filter { doc in
            guard let after else { return true }
            return (doc.updatedAtMs, doc.id) > (after.updatedAtMs, after.docId)
        }.prefix(limit)
        fetchPageSizes.append(page.count)
        return Array(page)
    }

    func batchWrite(_ writes: [RemoteWrite]) async throws {
        try checkFailure()
        guard writes.count <= maxBatch else { throw RemoteError.permanent("batch too large (\(writes.count))") }
        if let bad = writes.first(where: { rejectedIds.contains($0.id) }) {
            throw RemoteError.permanent("rejected \(bad.id)")
        }
        batchSizes.append(writes.count)
        for w in writes {
            writeCount += 1
            var d = docs[w.collection] ?? [:]
            if w.merge {
                var merged = d[w.id] ?? [:]
                for (k, v) in w.fields { merged[k] = v }
                for k in w.deleteFields { merged.removeValue(forKey: k) }
                d[w.id] = merged
            } else {
                d[w.id] = w.fields
            }
            docs[w.collection] = d
        }
    }

    func fetchDoc(_ collection: SyncCollection, id: String) async throws -> RemoteDoc? {
        try checkFailure()
        return docs[collection]?[id].map { RemoteDoc(id: id, fields: $0) }
    }
}
