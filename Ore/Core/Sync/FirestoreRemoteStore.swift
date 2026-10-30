import Foundation
import FirebaseFirestore

/// Firestore-backed `RemoteStore` for one signed-in user. Paths: `users/{uid}` (profile) and
/// `users/{uid}/{collection}/{id}`. Writes use `merge: true` so fields owned by other features
/// (e.g. the social `privacy` map on `users/{uid}`) are never overwritten.
final class FirestoreRemoteStore: RemoteStore {
    private let db: Firestore
    private let uid: String

    init(uid: String, db: Firestore = Firestore.firestore()) {
        self.uid = uid
        self.db = db
    }

    private var userDoc: DocumentReference { db.collection("users").document(uid) }

    private func collectionRef(_ c: SyncCollection) -> CollectionReference? {
        c.pathComponent.map { userDoc.collection($0) }
    }

    private func docRef(_ c: SyncCollection, _ id: String) -> DocumentReference {
        collectionRef(c)?.document(id) ?? userDoc
    }

    // MARK: RemoteStore

    func fetchChanged(_ collection: SyncCollection, sinceMs: Int64, limit: Int, after: RemoteCursor?) async throws -> [RemoteDoc] {
        do {
            guard let ref = collectionRef(collection) else {
                // The profile is a single document: return it when it changed.
                let snap = try await userDoc.getDocument()
                guard snap.exists, let data = snap.data() else { return [] }
                let doc = RemoteDoc(id: snap.documentID, fields: Self.fromFirestore(data))
                guard doc.updatedAtMs >= sinceMs else { return [] }
                if let after, (doc.updatedAtMs, doc.id) <= (after.updatedAtMs, after.docId) { return [] }
                return [doc]
            }
            var query: Query = ref
                .whereField("updatedAt", isGreaterThanOrEqualTo: sinceMs)
                .order(by: "updatedAt")
                .order(by: FieldPath.documentID())
                .limit(to: limit)
            if let after { query = query.start(after: [after.updatedAtMs, after.docId]) }
            let snap = try await query.getDocuments()
            return snap.documents.map { RemoteDoc(id: $0.documentID, fields: Self.fromFirestore($0.data())) }
        } catch {
            throw Self.map(error)
        }
    }

    func batchWrite(_ writes: [RemoteWrite]) async throws {
        var index = 0
        while index < writes.count {
            let chunk = writes[index ..< min(index + RemoteLimits.maxBatch, writes.count)]
            let batch = db.batch()
            for w in chunk {
                var fields = w.fields
                for k in w.deleteFields { fields[k] = FieldValue.delete() }
                batch.setData(fields, forDocument: docRef(w.collection, w.id), merge: w.merge)
            }
            do { try await batch.commit() } catch { throw Self.map(error) }
            index += RemoteLimits.maxBatch
        }
    }

    func fetchDoc(_ collection: SyncCollection, id: String) async throws -> RemoteDoc? {
        do {
            let snap = try await docRef(collection, id).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            return RemoteDoc(id: snap.documentID, fields: Self.fromFirestore(data))
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: Conversion

    /// Timestamps become `Date`s so the mappers only deal with Foundation types.
    static func fromFirestore(_ value: [String: Any]) -> SyncFields {
        value.mapValues(convert)
    }

    private static func convert(_ v: Any) -> Any {
        switch v {
        case let t as Timestamp: return t.dateValue()
        case let m as [String: Any]: return m.mapValues(convert)
        case let a as [Any]: return a.map(convert)
        default: return v
        }
    }

    static func map(_ error: Error) -> RemoteError {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            if [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed].contains(ns.code) { return .offline }
            return .transient(ns.localizedDescription)
        }
        if ns.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .unavailable: return .offline
            case .unauthenticated, .deadlineExceeded, .aborted, .resourceExhausted, .internal, .cancelled, .unknown:
                return .transient(ns.localizedDescription)
            case .permissionDenied, .invalidArgument, .failedPrecondition, .outOfRange,
                 .dataLoss, .alreadyExists, .notFound, .unimplemented:
                return .permanent(ns.localizedDescription)
            default:
                return .transient(ns.localizedDescription)
            }
        }
        return .transient(ns.localizedDescription)
    }
}
