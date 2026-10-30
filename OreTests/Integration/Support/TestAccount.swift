import Testing
import Foundation
import FirebaseAuth
import FirebaseFirestore
@testable import Ore

/// A freshly registered emulator user plus the app's real remotes wired to that user's Firebase app.
@MainActor
struct TestAccount {
    let client: EmulatorClient
    let uid: String
    let email: String
    let password: String
    let handle: String
    let displayName: String
    let authProvider: FirebaseAuthProvider
    let profileRemote: FirestoreProfileRemote
    let social: FirestoreSocialRemote
    /// The sync store for this user's own `users/{uid}/...` data.
    let store: FirestoreRemoteStore

    var db: Firestore { client.db }

    static func signUp(client: EmulatorClient, label: String, tag: String) async throws -> TestAccount {
        let provider = FirebaseAuthProvider(auth: client.auth, functions: client.functions)
        let email = "\(label)-\(tag)@example.com"
        let password = "correct-horse-\(tag)"
        let user = try await provider.signUp(email: email, password: password)
        let clean = label.lowercased().filter { $0.isLetter || $0.isNumber }
        return TestAccount(
            client: client, uid: user.uid, email: email, password: password,
            handle: String((clean.prefix(8) + tag).prefix(20)), displayName: label.capitalized,
            authProvider: provider,
            profileRemote: FirestoreProfileRemote(db: client.db),
            social: FirestoreSocialRemote(user: FirebaseCurrentUser(auth: client.auth), db: client.db),
            store: FirestoreRemoteStore(uid: user.uid, db: client.db))
    }

    /// Onboarding's atomic creation of `users/{uid}`, `profiles/{uid}` and `usernames/{handle}`.
    func createProfile(unit: String = "kg", handle override: String? = nil) async throws {
        try await profileRemote.createAccount(NewAccountProfile(
            uid: uid, handle: override ?? handle, displayName: displayName, unit: unit,
            experienceLevel: "intermediate", gender: "female", age: 29, heightCm: 172, weightKg: 68))
    }

    /// Raw document access for assertions (reads as this user, so the rules apply).
    func document(_ path: String) async throws -> [String: Any]? {
        let snap = try await db.document(path).getDocument()
        return snap.exists ? snap.data() : nil
    }

    func exists(_ path: String) async -> Bool {
        ((try? await db.document(path).getDocument())?.exists) ?? false
    }

    /// This user follows `other` (and optionally the reverse is done by `other`), i.e. the app's `follow`.
    func follow(_ other: TestAccount) async throws { try await social.follow(uid: other.uid) }

    /// Both directions: the pair become friends.
    func befriend(_ other: TestAccount) async throws {
        try await social.follow(uid: other.uid)
        try await other.social.follow(uid: uid)
    }

    /// A counter on `profiles/{uid}` (absent until a function first touches it, which reads as 0). Nil when the profile is unreadable.
    func profileCount(_ field: String, of uid: String? = nil) async -> Int? {
        guard let data = try? await document("profiles/\(uid ?? self.uid)") else { return nil }
        return (data[field] as? NSNumber)?.intValue ?? 0
    }
}
