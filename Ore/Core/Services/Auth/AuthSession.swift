import Foundation
import Observation

/// App-wide view of the signed-in account. Observes the auth backend, performs sign-in / sign-up /
/// sign-out / account deletion, and maps failures to user-facing text.
@MainActor
@Observable
final class AuthSession {
    private(set) var state: AuthState = .unknown
    /// A sign-in / sign-up / reset request is running.
    private(set) var isBusy = false
    /// Sign-out or account deletion is tearing down local data (the gate shows the splash meanwhile).
    private(set) var isTearingDown = false
    /// Last user-facing error from sign-in / sign-up / reset (nil = none). Cleared by the next attempt.
    var errorMessage: String?
    /// What the last failed attempt was, for callers that react to a kind of failure (e.g. "email already in use").
    private(set) var lastFailure: AuthFailure?
    /// Set after `sendPasswordReset` succeeds, for the email sheet's confirmation.
    private(set) var resetEmailSentTo: String?

    @ObservationIgnored private let provider: AuthProviding
    @ObservationIgnored private let lifecycle: SyncLifecycle
    @ObservationIgnored private var removeListener: AuthListenerRemoval?

    init(provider: AuthProviding, lifecycle: SyncLifecycle) {
        self.provider = provider
        self.lifecycle = lifecycle
    }

    var user: AuthUser? { state.user }

    /// Starts observing the backend. Idempotent. The cached user (offline launch) is delivered by the listener.
    func start() {
        guard removeListener == nil else { return }
        removeListener = provider.addStateListener { [weak self] user in
            self?.apply(user)
        }
    }

    private func apply(_ user: AuthUser?) {
        let next: AuthState = user.map { .signedIn($0) } ?? .signedOut
        if next != state { state = next }
    }

    // MARK: Sign in

    func signInWithApple() async { await attempt { try await self.provider.signInWithApple() } }
    func signInWithGoogle() async { await attempt { try await self.provider.signInWithGoogle() } }

    @discardableResult
    func signInWithEmail(_ email: String, password: String) async -> Bool {
        await attempt { try await self.provider.signIn(email: Self.clean(email), password: password) }
    }

    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        await attempt { try await self.provider.signUp(email: Self.clean(email), password: password) }
    }

    /// True when the email already has an account, false when it is free (never known for sure: nil when unsure).
    func emailHasAccount(_ email: String) async -> Bool? {
        await provider.emailHasAccount(Self.clean(email))
    }

    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        let address = Self.clean(email)
        guard !address.isEmpty else { errorMessage = AuthFailure.invalidEmail.message; return false }
        errorMessage = nil
        resetEmailSentTo = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await provider.sendPasswordReset(email: address)
            resetEmailSentTo = address
            return true
        } catch {
            errorMessage = AuthErrorMapper.message(for: error)
            return false
        }
    }

    func clearMessages() {
        errorMessage = nil
        resetEmailSentTo = nil
    }

    @discardableResult
    private func attempt(_ work: () async throws -> AuthUser) async -> Bool {
        errorMessage = nil
        lastFailure = nil
        resetEmailSentTo = nil
        isBusy = true
        defer { isBusy = false }
        do {
            let user = try await work()
            // The listener normally fires first; make the state correct even if it has not yet.
            if state.user?.uid != user.uid { apply(user) }
            return true
        } catch {
            lastFailure = AuthErrorMapper.failure(from: error)
            errorMessage = AuthErrorMapper.message(for: error)
            return false
        }
    }

    // MARK: Sign out

    /// Wipes local user data, then signs out. State becomes `.signedOut` via the listener.
    func signOut() async {
        await beginTearDown()
        defer { isTearingDown = false }
        await lifecycle.wipeLocalData()
        do {
            try provider.signOut()
        } catch {
            errorMessage = AuthErrorMapper.message(for: error)
            return
        }
        apply(nil)
    }

    // MARK: Delete account

    /// Deletes the account: `deleteAccount` Cloud Function, then local wipe, then back to sign-in.
    /// If the backend wants a fresh sign-in, re-authenticates with the linked provider and retries once.
    /// Email accounts must pass `password`; without it this throws `AuthFailure.passwordRequired`.
    func deleteAccount(password: String? = nil) async throws {
        guard let user = state.user else { throw AuthFailure.notSignedIn }
        do {
            do {
                try await provider.callDeleteAccount()
            } catch AuthFailure.requiresRecentLogin {
                try await provider.reauthenticate(provider: user.primaryProvider, password: password)
                try await provider.callDeleteAccount()
            }
        } catch {
            throw AuthErrorMapper.failure(from: error)
        }
        await beginTearDown()
        defer { isTearingDown = false }
        await lifecycle.wipeLocalData()
        try? provider.signOut()   // the Auth user is already gone server-side; this clears the local session
        apply(nil)
    }

    // MARK: Helpers

    /// Lets the UI swap to the splash before local models are deleted underneath live views.
    private func beginTearDown() async {
        isTearingDown = true
        try? await Task.sleep(for: .milliseconds(60))
    }

    private static func clean(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
