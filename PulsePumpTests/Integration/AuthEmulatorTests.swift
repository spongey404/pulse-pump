import Testing
import Foundation
import FirebaseAuth
import FirebaseCore
@testable import PulsePump

/// Email auth through `FirebaseAuthProvider` / `AuthSession` against the Auth emulator.
@Suite("Auth against the emulator", .emulator, .serialized)
@MainActor
struct AuthEmulatorTests {
    private func provider(_ world: EmulatorWorld) -> FirebaseAuthProvider {
        let client = world.anonymousClient()
        return FirebaseAuthProvider(auth: client.auth, functions: client.functions)
    }

    /// Regression: options of a configured app are locked, so the emulator apps must be built from fresh options,
    /// on the demo project, and never be the host app's default (real-project) Firebase app.
    @Test func emulatorClientsAreSeparateAppsOnTheDemoProject() async throws {
        try await Emulator.isolated { world in
            let first = world.anonymousClient(), second = world.anonymousClient()
            #expect(first.app.name != second.app.name)
            for client in [first, second] {
                #expect(client.app.options.projectID == "demo-pump")
                #expect(client.app.name != FirebaseApp.app()?.name)
                #expect(client.auth.app?.name == client.app.name)
            }
            #expect(FirebaseApp.app()?.options.projectID != "demo-pump", "the host app's default app is left alone")
        }
    }

    @Test func signUpCreatesAnEmailAccountAndSignsIn() async throws {
        try await Emulator.isolated { world in
            let auth = provider(world)
            let user = try await auth.signUp(email: "new.lifter@example.com", password: "secret-pass-1")
            #expect(!user.uid.isEmpty)
            #expect(user.email == "new.lifter@example.com")
            #expect(user.providers == [.password])
            #expect(user.isNewUser)
            #expect(auth.currentUser?.uid == user.uid)
        }
    }

    @Test func signInWithTheRightPasswordReturnsTheSameAccount() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let other = provider(world)
            let signedIn = try await other.signIn(email: a.email, password: a.password)
            #expect(signedIn.uid == a.uid)
            #expect(!signedIn.isNewUser)
        }
    }

    @Test func wrongPasswordMapsToInvalidCredentials() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let other = provider(world)
            await #expect(throws: AuthFailure.invalidCredentials) {
                _ = try await other.signIn(email: a.email, password: "definitely-wrong")
            }
            #expect(other.currentUser == nil)
        }
    }

    @Test func unknownEmailIsRejectedWithoutRevealingWhetherItExists() async throws {
        try await Emulator.isolated { world in
            let auth = provider(world)
            do {
                _ = try await auth.signIn(email: "nobody@example.com", password: "whatever-pass")
                Issue.record("sign-in for an unknown email must fail")
            } catch let failure as AuthFailure {
                #expect(failure == .invalidCredentials || failure == .userNotFound, "got \(failure)")
            }
        }
    }

    @Test func signingUpWithAnExistingEmailMapsToEmailInUse() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let other = provider(world)
            await #expect(throws: AuthFailure.emailInUse) {
                _ = try await other.signUp(email: a.email, password: "another-pass-9")
            }
        }
    }

    @Test func tooShortPasswordMapsToWeakPassword() async throws {
        try await Emulator.isolated { world in
            let auth = provider(world)
            await #expect(throws: AuthFailure.weakPassword) {
                _ = try await auth.signUp(email: "weak@example.com", password: "123")
            }
        }
    }

    @Test func malformedEmailMapsToInvalidEmail() async throws {
        try await Emulator.isolated { world in
            let auth = provider(world)
            await #expect(throws: AuthFailure.invalidEmail) {
                _ = try await auth.signUp(email: "not-an-email", password: "secret-pass-1")
            }
        }
    }

    @Test func signOutClearsTheCurrentUserAndNotifiesListeners() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            var seen: [String?] = []
            let remove = a.authProvider.addStateListener { seen.append($0?.uid) }
            defer { remove() }
            await Emulator.eventually { seen.contains(a.uid) }
            try a.authProvider.signOut()
            let notified = await Emulator.eventually { seen.last == .some(nil) }
            #expect(notified, "listener saw \(seen)")
            #expect(a.authProvider.currentUser == nil)
        }
    }

    @Test func passwordResetForAKnownEmailSucceeds() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            try await a.authProvider.sendPasswordReset(email: a.email)
        }
    }

    @Test func reauthenticationNeedsTheCurrentPassword() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            await #expect(throws: AuthFailure.invalidCredentials) {
                try await a.authProvider.reauthenticate(provider: .password, password: "nope-nope-nope")
            }
            try await a.authProvider.reauthenticate(provider: .password, password: a.password)
            await #expect(throws: AuthFailure.passwordRequired) {
                try await a.authProvider.reauthenticate(provider: .password, password: nil)
            }
        }
    }

    @Test func authSessionSignUpThenSignInThenSignOutDrivesTheAccountState() async throws {
        try await Emulator.isolated { world in
            let client = world.anonymousClient()
            let session = AuthSession(provider: FirebaseAuthProvider(auth: client.auth, functions: client.functions),
                                      lifecycle: NoOpSyncLifecycle())
            session.start()
            #expect(await Emulator.eventually { session.state == .signedOut })

            #expect(await session.signUp(email: "  session@example.com ", password: "secret-pass-1"))
            #expect(session.user?.email == "session@example.com")   // surrounding whitespace is trimmed

            await session.signOut()
            #expect(session.state == .signedOut)

            #expect(await session.signInWithEmail("session@example.com", password: "secret-pass-1"))
            #expect(session.user?.email == "session@example.com")
        }
    }

    @Test func authSessionShowsAFriendlyMessageForAWrongPassword() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let client = world.anonymousClient()
            let session = AuthSession(provider: FirebaseAuthProvider(auth: client.auth, functions: client.functions),
                                      lifecycle: NoOpSyncLifecycle())
            session.start()
            #expect(await session.signInWithEmail(a.email, password: "wrong-wrong") == false)
            #expect(session.errorMessage == AuthFailure.invalidCredentials.message)
            #expect(session.user == nil)
        }
    }
}
