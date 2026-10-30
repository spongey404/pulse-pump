import Foundation

/// The per-user cloud collections (all under `users/{uid}`; `profile` is the `users/{uid}` document itself).
/// The raw order is the pull order: parents before the records that reference them.
enum SyncCollection: String, CaseIterable, Codable {
    case splits
    case customExercises
    case profile
    case equipmentProfiles
    case templates
    case workouts
    case bodyweight

    /// Path segment under `users/{uid}/` (nil for the profile document).
    var pathComponent: String? { self == .profile ? nil : rawValue }
}

/// Firestore-shaped dictionary. Dates are `Date` (the Firestore store converts to/from `Timestamp`);
/// `updatedAt` / `deletedAt` are epoch milliseconds (numbers), see docs/sync-architecture.md.
typealias SyncFields = [String: Any]

struct RemoteDoc {
    let id: String
    var fields: SyncFields

    /// `updatedAt` is written as epoch ms; documents written by other features may carry a Timestamp (a `Date` here).
    var updatedAtMs: Int64 { SyncValue.int64(fields["updatedAt"]) ?? SyncValue.date(fields["updatedAt"])?.syncMs ?? 0 }
    var deletedAtMs: Int64? { SyncValue.int64(fields["deletedAt"]) ?? SyncValue.date(fields["deletedAt"])?.syncMs }
    var isDeleted: Bool { fields["deletedAt"] != nil && !(fields["deletedAt"] is NSNull) }
}

struct RemoteWrite {
    let collection: SyncCollection
    let id: String
    let fields: SyncFields
    /// `setData(merge: true)`: only the listed top-level fields change, so other writers' fields survive.
    var merge = true
    /// Optional fields that are nil locally; removed remotely (`FieldValue.delete()`), since a merge write cannot clear a field by omission.
    var deleteFields: [String] = []
}

/// Position in the (updatedAt, document id) order of a collection.
struct RemoteCursor: Equatable, Codable {
    var updatedAtMs: Int64
    var docId: String
}

enum RemoteError: Error, Equatable {
    case offline
    /// Retrying later may succeed (unavailable, deadline, aborted...).
    case transient(String)
    /// Retrying the same payload will fail again (permission denied, invalid argument...).
    case permanent(String)

    var isOffline: Bool { self == .offline }
    var isPermanent: Bool { if case .permanent = self { return true }; return false }
    var message: String {
        switch self {
        case .offline: "You're offline"
        case .transient(let m), .permanent(let m): m
        }
    }
}

/// What the sync engine needs from the cloud. `FirestoreRemoteStore` is the real one; tests use `InMemoryRemoteStore`.
protocol RemoteStore: AnyObject {
    /// Documents with `updatedAt >= sinceMs`, ordered by (updatedAt, id), strictly after `after` when given.
    /// A page shorter than `limit` is the last one.
    func fetchChanged(_ collection: SyncCollection, sinceMs: Int64, limit: Int, after: RemoteCursor?) async throws -> [RemoteDoc]
    /// Writes all documents (merge semantics per write). Implementations chunk to <= `RemoteLimits.maxBatch`.
    func batchWrite(_ writes: [RemoteWrite]) async throws
    func fetchDoc(_ collection: SyncCollection, id: String) async throws -> RemoteDoc?
}

enum RemoteLimits {
    /// Firestore allows 500 writes per batch; stay well below.
    static let maxBatch = 400
    static let pageSize = 200
}

/// Loose value coercion for Firestore / JSON / in-memory dictionaries.
enum SyncValue {
    static func int64(_ v: Any?) -> Int64? {
        switch v {
        case let n as Int64: return n
        case let n as Int: return Int64(n)
        case let n as Double: return n.isFinite ? Int64(n.rounded()) : nil
        case let n as NSNumber: return n.int64Value
        default: return nil
        }
    }
    static func double(_ v: Any?) -> Double? {
        switch v {
        case let n as Double: return n.isFinite ? n : nil
        case let n as Int: return Double(n)
        case let n as Int64: return Double(n)
        case let n as NSNumber: return n.doubleValue
        default: return nil
        }
    }
    static func int(_ v: Any?) -> Int? { int64(v).map { Int($0) } }
    static func string(_ v: Any?) -> String? { v as? String }
    static func bool(_ v: Any?) -> Bool? {
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        return nil
    }
    static func date(_ v: Any?) -> Date? {
        switch v {
        case let d as Date: return d
        case let n as NSNumber: return Date(syncMs: n.int64Value)
        default: return nil
        }
    }
    static func array(_ v: Any?) -> [Any] { (v as? [Any]) ?? [] }
    static func maps(_ v: Any?) -> [[String: Any]] { (v as? [[String: Any]]) ?? [] }
}
