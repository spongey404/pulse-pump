import Testing
import Foundation
import FirebaseAuth
import FirebaseFunctions
@testable import Ore

@MainActor
struct AuthSessionTests {
    private func make(current: AuthUser? = nil, owner: String? = nil)
        -> (AuthSession, FakeAuthProvider, RecordingLifecycle, EventLog) {
        let log = EventLog()
        let provider = FakeAuthProvider(current: current, log: log)
        let lifecycle = RecordingLifecycle(owner: owner, log: log)
        return (AuthSession(provider: provider, lifecycle: lifecycle), provider, lifecycle, log)
    }

    // MARK: State machine

    @Test func startsUnknownThenSignedOut() {
        let (session, _, _, _) = make()
        #expect(session.state == .unknown)
        session.start()
        #expect(session.state == .signedOut)
    }

    @Test func cachedUserIsSignedInAtStart() {
        let user = Fixtures.user()
        let (session, _, _, _) = make(current: user)
        session.start()
        #expect(session.state == .signedIn(user))
        #expect(session.user?.uid == "uid-1")
    }

    @Test func startIsIdempotent() {
        let (session, provider, _, _) = make()
        session.start()
        session.start()
        #expect(provider.listenerCount == 1)
    }

    @Test func emailSignInMovesToSignedIn() async {
        let (session, _, _, _) = make()
        session.start()
        let ok = await session.signInWithEmail("  me@x.co ", password: "secret123")
        #expect(ok)
        #expect(session.state.user?.email == "me@x.co")
        #expect(session.errorMessage == nil)
        #expect(!session.isBusy)
    }

    @Test func appleAndGoogleSignInRecordProvider() async {
        let (session, _, _, _) = make()
        session.start()
        await session.signInWithApple()
        #expect(session.state.user?.providers == [.apple])
        await session.signInWithGoogle()
        #expect(session.state.user?.providers == [.google])
    }

    @Test func wrongPasswordShowsFriendlyMessageAndStaysSignedOut() async {
        let (session, provider, _, _) = make()
        session.start()
        provider.signInError = AuthFailure.invalidCredentials
        let ok = await session.signInWithEmail("a@b.co", password: "nope")
        #expect(!ok)
        #expect(session.state == .signedOut)
        #expect(session.errorMessage == AuthFailure.invalidCredentials.message)
    }

    @Test func cancelledAppleSignInIsSilent() async {
        let (session, provider, _, _) = make()
        session.start()
        provider.signInError = AuthFailure.cancelled
        await session.signInWithApple()
        #expect(session.errorMessage == nil)
        #expect(session.state == .signedOut)
    }

    @Test func signUpEmailInUseMessage() async {
        let (session, provider, _, _) = make()
        session.start()
        provider.signInError = AuthFailure.emailInUse
        let ok = await session.signUp(email: "a@b.co", password: "longenough1")
        #expect(!ok)
        #expect(session.errorMessage?.contains("already exists") == true)
    }

    @Test func unknownErrorsPassTheirDescriptionThrough() async {
        let (session, provider, _, _) = make()
        session.start()
        provider.signInError = NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "Boom"])
        await session.signInWithGoogle()
        #expect(session.errorMessage == "Boom")
    }

    @Test func passwordReset() async {
        let (session, provider, _, _) = make()
        session.start()
        #expect(await session.sendPasswordReset(email: " me@x.co "))
        #expect(provider.resetEmails == ["me@x.co"])
        #expect(session.resetEmailSentTo == "me@x.co")
        #expect(await session.sendPasswordReset(email: "  ") == false)
        #expect(session.errorMessage == AuthFailure.invalidEmail.message)
    }

    // MARK: Sign out

    @Test func signOutWipesThenSignsOutAndClearsState() async {
        let (session, provider, lifecycle, log) = make(current: Fixtures.user(), owner: "uid-1")
        session.start()
        await session.signOut()
        #expect(lifecycle.wipeCount == 1)
        #expect(provider.signOutCalls == 1)
        #expect(log.events == ["wipe", "provider.signOut"])
        #expect(session.state == .signedOut)
        #expect(!session.isTearingDown)
    }

    @Test func signOutFailureKeepsSessionAndReportsError() async {
        let (session, provider, _, _) = make(current: Fixtures.user())
        session.start()
        provider.signOutError = AuthFailure.unknown("Keychain error")
        await session.signOut()
        #expect(session.state.user != nil)
        #expect(session.errorMessage == "Keychain error")
    }

    // MARK: Delete account

    @Test func deleteAccountCallsFunctionWipesAndReturnsToSignedOut() async throws {
        let (session, provider, lifecycle, log) = make(current: Fixtures.user(), owner: "uid-1")
        session.start()
        try await session.deleteAccount()
        #expect(provider.deleteCalls == 1)
        #expect(lifecycle.wipeCount == 1)
        #expect(provider.reauthCalls.isEmpty)
        #expect(log.events == ["callDeleteAccount", "wipe", "provider.signOut"])
        #expect(session.state == .signedOut)
    }

    @Test func deleteAccountReauthenticatesOnRecentLoginThenRetries() async throws {
        let (session, provider, lifecycle, log) = make(current: Fixtures.user(providers: [.apple]))
        session.start()
        provider.deleteScript = [AuthFailure.requiresRecentLogin, nil]
        try await session.deleteAccount()
        #expect(provider.reauthCalls.count == 1)
        #expect(provider.reauthCalls.first?.0 == .apple)
        #expect(provider.deleteCalls == 2)
        #expect(lifecycle.wipeCount == 1)
        #expect(log.events.prefix(3) == ["callDeleteAccount", "reauth", "callDeleteAccount"])
        #expect(session.state == .signedOut)
    }

    @Test func deleteAccountUsesPasswordForEmailReauth() async throws {
        let (session, provider, _, _) = make(current: Fixtures.user(providers: [.password]))
        session.start()
        provider.deleteScript = [AuthFailure.requiresRecentLogin, nil]
        try await session.deleteAccount(password: "hunter22")
        #expect(provider.reauthCalls.first?.0 == .password)
        #expect(provider.reauthCalls.first?.1 == "hunter22")
    }

    @Test func deleteAccountNeedsPasswordForEmailAccounts() async {
        let (session, provider, lifecycle, _) = make(current: Fixtures.user(providers: [.password]))
        session.start()
        provider.deleteScript = [AuthFailure.requiresRecentLogin]
        provider.reauthError = AuthFailure.passwordRequired
        await #expect(throws: AuthFailure.passwordRequired) { try await session.deleteAccount() }
        #expect(lifecycle.wipeCount == 0)
        #expect(session.state.user != nil)
    }

    @Test func deleteAccountFailureLeavesEverythingIntact() async {
        let (session, provider, lifecycle, _) = make(current: Fixtures.user())
        session.start()
        provider.deleteScript = [AuthFailure.network]
        await #expect(throws: AuthFailure.network) { try await session.deleteAccount() }
        #expect(lifecycle.wipeCount == 0)
        #expect(provider.signOutCalls == 0)
        #expect(session.state.user != nil)
        #expect(!session.isTearingDown)
    }

    @Test func deleteAccountReauthFailureAbortsBeforeRetry() async {
        let (session, provider, lifecycle, _) = make(current: Fixtures.user(providers: [.google]))
        session.start()
        provider.deleteScript = [AuthFailure.requiresRecentLogin]
        provider.reauthError = AuthFailure.cancelled
        await #expect(throws: AuthFailure.cancelled) { try await session.deleteAccount() }
        #expect(provider.deleteCalls == 1)
        #expect(lifecycle.wipeCount == 0)
    }

    @Test func deleteAccountWhenSignedOutThrows() async {
        let (session, provider, _, _) = make()
        session.start()
        await #expect(throws: AuthFailure.notSignedIn) { try await session.deleteAccount() }
        #expect(provider.deleteCalls == 0)
    }

    // MARK: Error mapping (Firebase)

    @Test func firebaseErrorMapping() {
        func ns(_ code: AuthErrorCode) -> NSError { NSError(domain: AuthErrorDomain, code: code.rawValue) }
        #expect(FirebaseAuthProvider.map(ns(.wrongPassword)) == .invalidCredentials)
        #expect(FirebaseAuthProvider.map(ns(.invalidCredential)) == .invalidCredentials)
        #expect(FirebaseAuthProvider.map(ns(.emailAlreadyInUse)) == .emailInUse)
        #expect(FirebaseAuthProvider.map(ns(.weakPassword)) == .weakPassword)
        #expect(FirebaseAuthProvider.map(ns(.networkError)) == .network)
        #expect(FirebaseAuthProvider.map(ns(.requiresRecentLogin)) == .requiresRecentLogin)
        let unauth = NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.unauthenticated.rawValue)
        #expect(FirebaseAuthProvider.map(unauth) == .requiresRecentLogin)
        #expect(FirebaseAuthProvider.map(AuthFailure.cancelled) == .cancelled)
    }

    @Test func userProviderSummary() {
        #expect(Fixtures.user(providers: [.apple, .password]).providerSummary == "Apple · Email")
        #expect(Fixtures.user(providers: []).providerSummary == "Account")
        #expect(Fixtures.user(providers: [.google]).primaryProvider == .google)
    }
}
