import Foundation
@testable import Ore

/// Shared ordered log so tests can assert that the wipe happens before sign-out, etc.
@MainActor
final class EventLog {
    var events: [String] = []
}

@MainActor
final class FakeAuthProvider: AuthProviding {
    var current: AuthUser?
    var log: EventLog

    var signInError: Error?
    var signOutError: Error?
    var reauthError: Error?
    var resetError: Error?
    /// One entry per `callDeleteAccount` call: nil = succeed, otherwise throw. Empty = succeed.
    var deleteScript: [Error?] = []
    /// Emails that already have an account: creating one fails with `emailInUse`.
    var knownEmails: Set<String> = []
    /// Whether `emailHasAccount` can tell (a project with email enumeration protection can't).
    var revealsAccounts = false
    /// Makes `signUp` fail with this.
    var signUpError: Error?
    private(set) var signUpCalls: [String] = []

    private(set) var reauthCalls: [(AuthProviderKind, String?)] = []
    private(set) var deleteCalls = 0
    private(set) var signOutCalls = 0
    private(set) var resetEmails: [String] = []
    private var listeners: [Int: (AuthUser?) -> Void] = [:]
    private var nextId = 0

    init(current: AuthUser? = nil, log: EventLog? = nil) {
        self.current = current
        self.log = log ?? EventLog()
    }

    var currentUser: AuthUser? { current }
    var listenerCount: Int { listeners.count }

    func addStateListener(_ handler: @escaping (AuthUser?) -> Void) -> AuthListenerRemoval {
        let id = nextId; nextId += 1
        listeners[id] = handler
        handler(current)
        return { [weak self] in self?.listeners[id] = nil }
    }

    private func set(_ user: AuthUser?) {
        current = user
        for handler in listeners.values { handler(user) }
    }

    private func signIn(as user: AuthUser) throws -> AuthUser {
        if let signInError { throw signInError }
        set(user)
        return user
    }

    func signInWithApple() async throws -> AuthUser { try signIn(as: Fixtures.user(providers: [.apple])) }
    func signInWithGoogle() async throws -> AuthUser { try signIn(as: Fixtures.user(providers: [.google])) }
    func signIn(email: String, password: String) async throws -> AuthUser {
        try signIn(as: Fixtures.user(email: email, providers: [.password]))
    }
    func emailHasAccount(_ email: String) async -> Bool? { revealsAccounts && knownEmails.contains(email) ? true : nil }
    func signUp(email: String, password: String) async throws -> AuthUser {
        signUpCalls.append(email)
        if let signUpError { throw signUpError }
        if knownEmails.contains(email) { throw AuthFailure.emailInUse }
        return try signIn(as: Fixtures.user(email: email, providers: [.password], isNew: true))
    }

    func sendPasswordReset(email: String) async throws {
        if let resetError { throw resetError }
        resetEmails.append(email)
    }

    func signOut() throws {
        signOutCalls += 1
        log.events.append("provider.signOut")
        if let signOutError { throw signOutError }
        set(nil)
    }

    func reauthenticate(provider: AuthProviderKind, password: String?) async throws {
        reauthCalls.append((provider, password))
        log.events.append("reauth")
        if let reauthError { throw reauthError }
    }

    var revokeCalls = 0
    func revokeAppleToken() async throws {
        revokeCalls += 1
        log.events.append("revokeAppleToken")
    }

    func callDeleteAccount() async throws {
        deleteCalls += 1
        log.events.append("callDeleteAccount")
        if !deleteScript.isEmpty, let error = deleteScript.removeFirst() { throw error }
    }
}

@MainActor
final class RecordingLifecycle: SyncLifecycle {
    var owner: String?
    var log: EventLog
    private(set) var wipeCount = 0
    private(set) var claims: [String] = []

    init(owner: String? = nil, log: EventLog? = nil) {
        self.owner = owner
        self.log = log ?? EventLog()
    }

    var localOwnerUid: String? { owner }
    func claimLocalStore(for uid: String) { owner = uid; claims.append(uid) }
    func wipeLocalData() async {
        wipeCount += 1
        owner = nil
        log.events.append("wipe")
    }
}

@MainActor
final class FakeRestoreGate: RestoreGate {
    var complete: Bool
    private(set) var began: [String] = []
    init(complete: Bool = false) { self.complete = complete }
    var isInitialSyncComplete: Bool { complete }
    func beginRestore(uid: String) { began.append(uid) }
}

@MainActor
final class FakeProfileRemote: ProfileRemote {
    var existingProfiles: Set<String> = []
    /// handle -> owner uid
    var handles: [String: String] = [:]
    private(set) var createdProfiles: [NewAccountProfile] = []
    private(set) var renames: [(uid: String, old: String?, new: String)] = []
    private(set) var availabilityChecks: [String] = []

    var existsError: Error?
    var availabilityError: Error?
    var createError: Error?
    /// Runs inside `createAccount` before the claim, e.g. to simulate someone taking the handle first.
    var beforeCreate: ((FakeProfileRemote) -> Void)?
    /// Artificial latency per handle for race tests.
    var delays: [String: Duration] = [:]

    func cloudProfileExists(uid: String) async throws -> Bool {
        if let existsError { throw existsError }
        return existingProfiles.contains(uid)
    }

    func isHandleAvailable(_ handle: String, for uid: String) async throws -> Bool {
        availabilityChecks.append(handle)
        if let delay = delays[handle] { try? await Task.sleep(for: delay) }
        if let availabilityError { throw availabilityError }
        guard let owner = handles[handle] else { return true }
        return owner == uid
    }

    func createAccount(_ profile: NewAccountProfile) async throws {
        beforeCreate?(self)
        if let createError { throw createError }
        if let owner = handles[profile.handle], owner != profile.uid { throw ProfileRemoteError.handleTaken }
        // atomic: all three or nothing
        handles[profile.handle] = profile.uid
        existingProfiles.insert(profile.uid)
        createdProfiles.append(profile)
    }

    func changeHandle(uid: String, from old: String?, to new: String, displayName: String) async throws {
        if let owner = handles[new], owner != uid { throw ProfileRemoteError.handleTaken }
        handles[new] = uid
        if let old, old != new { handles[old] = nil }
        renames.append((uid, old, new))
    }
}

enum Fixtures {
    static func user(uid: String = "uid-1", email: String? = "a@b.co", name: String? = "Alex Smith",
                     providers: [AuthProviderKind] = [.password], isNew: Bool = false) -> AuthUser {
        AuthUser(uid: uid, email: email, displayName: name, providers: providers, isNewUser: isNew)
    }
}
