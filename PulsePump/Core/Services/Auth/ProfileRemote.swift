import Foundation
import FirebaseFirestore

/// Account-creation writes. Stats and counters (`streak`, `totalWorkouts`, `friendCount`, `fanCount`) are
/// deliberately absent: they are owned by the sync layer and Cloud Functions, never by onboarding.
struct NewAccountProfile: Equatable {
    var uid: String
    var handle: String
    var displayName: String
    var unit: String                // "kg" | "lbs"
    var experienceLevel: String
    var gender: String
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}

enum ProfileRemoteError: Error, Equatable {
    case handleTaken
    case offline
    case permissionDenied
    case other(String)

    var message: String {
        switch self {
        case .handleTaken: "That username was just taken. Try another."
        case .offline: "Can't reach the server. Check your connection and try again."
        case .permissionDenied: "Couldn't save your profile (permission denied). Sign out and back in, then try again."
        case .other(let text): text.isEmpty ? "Couldn't save your profile. Please try again." : text
        }
    }
}

/// Remote side of account creation and handle ownership. Firestore implementation below; fake in tests.
@MainActor
protocol ProfileRemote: AnyObject {
    /// True when `users/{uid}` already exists (returning user on a new device).
    func cloudProfileExists(uid: String) async throws -> Bool
    /// True when `usernames/{handle}` is free, or already owned by `uid`.
    func isHandleAvailable(_ handle: String, for uid: String) async throws -> Bool
    /// Atomically creates `users/{uid}` (base fields), `profiles/{uid}` and `usernames/{handle}`.
    /// Throws `.handleTaken` if the handle is claimed by someone else.
    func createAccount(_ profile: NewAccountProfile) async throws
    /// Atomically claims `new`, releases `old` and updates the denormalised username/name fields.
    func changeHandle(uid: String, from old: String?, to new: String, displayName: String) async throws
}

@MainActor
final class FirestoreProfileRemote: ProfileRemote {
    private let injectedDb: Firestore?
    private var db: Firestore { injectedDb ?? Firestore.firestore() }

    /// Production uses the default app; integration tests inject the Firestore of an emulator app.
    init(db: Firestore? = nil) { injectedDb = db }

    func cloudProfileExists(uid: String) async throws -> Bool {
        do {
            return try await db.collection("users").document(uid).getDocument().exists
        } catch { throw Self.map(error) }
    }

    func isHandleAvailable(_ handle: String, for uid: String) async throws -> Bool {
        do {
            let snap = try await db.collection("usernames").document(handle).getDocument()
            guard snap.exists else { return true }
            return snap.data()?["uid"] as? String == uid
        } catch { throw Self.map(error) }
    }

    func createAccount(_ p: NewAccountProfile) async throws {
        // Also proves we are online, and makes a retry after a half-applied attempt safe
        // (rules forbid re-creating a handle document, even our own).
        let handleRef = db.collection("usernames").document(p.handle)
        let existing: DocumentSnapshot
        do { existing = try await handleRef.getDocument() } catch { throw Self.map(error) }
        if existing.exists, existing.data()?["uid"] as? String != p.uid { throw ProfileRemoteError.handleTaken }
        let ownsHandleAlready = existing.exists

        let batch = db.batch()
        let created = Timestamp(date: Date(timeIntervalSince1970: Double(p.nowMs) / 1000))

        batch.setData([
            "name": p.displayName, "username": p.handle, "unit": p.unit, "experienceLevel": p.experienceLevel,
            "gender": p.gender, "age": p.age, "heightCm": p.heightCm, "weightKg": p.weightKg,
            "settings": [String: Any](),
            "privacy": ["workoutPosts": "friends", "bodyMap": "friends", "globalLeaderboards": "visible", "profile": "everyone"],
            "schemaVersion": 1, "createdAt": created, "updatedAt": p.nowMs,
        ], forDocument: db.collection("users").document(p.uid), merge: true)

        batch.setData([
            "displayName": p.displayName, "username": p.handle,
            "profileVisibility": "everyone", "globalLeaderboardVisible": true,
            "schemaVersion": 1, "createdAt": created, "updatedAt": p.nowMs,
        ], forDocument: db.collection("profiles").document(p.uid))

        if !ownsHandleAlready {
            batch.setData(["uid": p.uid, "createdAt": created], forDocument: handleRef)
        }

        do { try await batch.commit() } catch { throw await mapWriteError(error, handle: p.handle, uid: p.uid) }
    }

    func changeHandle(uid: String, from old: String?, to new: String, displayName: String) async throws {
        let batch = db.batch()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if old != new {
            batch.setData(["uid": uid, "createdAt": Timestamp(date: Date())], forDocument: db.collection("usernames").document(new))
            if let old, !old.isEmpty { batch.deleteDocument(db.collection("usernames").document(old)) }
        }
        batch.setData(["username": new, "name": displayName, "updatedAt": now], forDocument: db.collection("users").document(uid), merge: true)
        batch.setData(["username": new, "displayName": displayName, "updatedAt": now], forDocument: db.collection("profiles").document(uid), merge: true)
        do { try await batch.commit() } catch { throw await mapWriteError(error, handle: new, uid: uid) }
    }

    /// A denied create on `usernames/{handle}` means somebody else owns it; confirm before blaming the handle.
    private func mapWriteError(_ error: Error, handle: String, uid: String) async -> ProfileRemoteError {
        let mapped = Self.map(error)
        if mapped == .permissionDenied, let free = try? await isHandleAvailable(handle, for: uid), !free {
            return .handleTaken
        }
        return mapped
    }

    nonisolated static func map(_ error: Error) -> ProfileRemoteError {
        if let remote = error as? ProfileRemoteError { return remote }
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain {
            switch FirestoreErrorCode.Code(rawValue: ns.code) {
            case .permissionDenied: return .permissionDenied
            case .unavailable, .deadlineExceeded: return .offline
            case .alreadyExists: return .handleTaken
            default: break
            }
        }
        return .other(ns.localizedDescription)
    }
}
