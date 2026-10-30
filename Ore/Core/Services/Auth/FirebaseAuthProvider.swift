import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseFunctions
import GoogleSignIn

/// Firebase Auth implementation of `AuthProviding`.
/// Touches `Auth.auth()` lazily, so `FirebaseBootstrap.configure()` must have run first.
@MainActor
final class FirebaseAuthProvider: AuthProviding {
    private var appleFlow: AppleSignInFlow?

    private let injectedAuth: Auth?
    private let injectedFunctions: Functions?

    /// Production uses the default app; integration tests inject the Auth / Functions of an emulator app.
    init(auth: Auth? = nil, functions: Functions? = nil) {
        injectedAuth = auth
        injectedFunctions = functions
    }

    private var auth: Auth { injectedAuth ?? Auth.auth() }

    var currentUser: AuthUser? { auth.currentUser.map { Self.map($0) } }

    func addStateListener(_ handler: @escaping (AuthUser?) -> Void) -> AuthListenerRemoval {
        let handle = auth.addStateDidChangeListener { _, user in
            let mapped = user.map { Self.map($0) }
            Task { @MainActor in handler(mapped) }
        }
        return { [auth] in auth.removeStateDidChangeListener(handle) }
    }

    // MARK: Sign in

    func signInWithApple() async throws -> AuthUser {
        let apple = try await runAppleFlow()
        let credential = Self.appleCredential(apple)
        let result: AuthDataResult
        do { result = try await auth.signIn(with: credential) } catch { throw Self.map(error) }
        await Self.fillDisplayNameIfNeeded(result.user, from: apple.fullName)
        var user = Self.map(result.user)
        user.isNewUser = result.additionalUserInfo?.isNewUser ?? false
        return user
    }

    func signInWithGoogle() async throws -> AuthUser {
        let credential = try await googleCredential()
        do {
            let result = try await auth.signIn(with: credential)
            var user = Self.map(result.user)
            user.isNewUser = result.additionalUserInfo?.isNewUser ?? false
            return user
        } catch { throw Self.map(error) }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            return Self.map(result.user)
        } catch { throw Self.map(error) }
    }

    func signUp(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            var user = Self.map(result.user)
            user.isNewUser = true
            return user
        } catch { throw Self.map(error) }
    }

    func sendPasswordReset(email: String) async throws {
        do { try await auth.sendPasswordReset(withEmail: email) } catch { throw Self.map(error) }
    }

    func signOut() throws {
        do { try auth.signOut() } catch { throw Self.map(error) }
    }

    // MARK: Re-authentication and deletion

    func reauthenticate(provider: AuthProviderKind, password: String?) async throws {
        guard let user = auth.currentUser else { throw AuthFailure.notSignedIn }
        let credential: AuthCredential
        switch provider {
        case .apple:
            credential = Self.appleCredential(try await runAppleFlow())
        case .google:
            credential = try await googleCredential()
        case .password:
            guard let password, !password.isEmpty else { throw AuthFailure.passwordRequired }
            guard let email = user.email else { throw AuthFailure.invalidEmail }
            credential = EmailAuthProvider.credential(withEmail: email, password: password)
        case .other:
            throw AuthFailure.unknown("Sign out and back in, then try again.")
        }
        do { try await user.reauthenticate(with: credential) } catch { throw Self.map(error) }
    }

    func callDeleteAccount() async throws {
        guard auth.currentUser != nil else { throw AuthFailure.notSignedIn }
        do {
            _ = try await (injectedFunctions ?? FirebaseBootstrap.functions).httpsCallable("deleteAccount").call()
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: Credentials

    private func runAppleFlow() async throws -> AppleIDResult {
        let flow = AppleSignInFlow()
        appleFlow = flow
        defer { appleFlow = nil }
        return try await flow.run()
    }

    private static func appleCredential(_ apple: AppleIDResult) -> AuthCredential {
        OAuthProvider.appleCredential(withIDToken: apple.idToken, rawNonce: apple.rawNonce, fullName: apple.fullName)
    }

    private func googleCredential() async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthFailure.unknown("Missing Firebase client ID.")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let presenter = Self.topViewController() else {
            throw AuthFailure.unknown("Couldn't present Google sign-in.")
        }
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue { throw AuthFailure.cancelled }
            throw Self.map(error)
        }
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthFailure.unknown("Couldn't read the Google sign-in token.")
        }
        return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// Apple only sends the name on the first authorisation; keep it on the Firebase user so it can prefill onboarding.
    private static func fillDisplayNameIfNeeded(_ user: FirebaseAuth.User, from name: PersonNameComponents?) async {
        guard (user.displayName ?? "").isEmpty, let name else { return }
        let formatted = PersonNameComponentsFormatter().string(from: name).trimmingCharacters(in: .whitespaces)
        guard !formatted.isEmpty else { return }
        let change = user.createProfileChangeRequest()
        change.displayName = formatted
        try? await change.commitChanges()
    }

    // MARK: Mapping

    nonisolated static func map(_ user: FirebaseAuth.User) -> AuthUser {
        let providers: [AuthProviderKind] = user.providerData.map { info in
            switch info.providerID {
            case "apple.com": .apple
            case "google.com": .google
            case "password": .password
            default: .other
            }
        }
        return AuthUser(uid: user.uid, email: user.email, displayName: user.displayName, providers: providers)
    }

    nonisolated static func map(_ error: Error) -> AuthFailure {
        if let failure = error as? AuthFailure { return failure }
        let ns = error as NSError
        if ns.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: ns.code) {
            case .unauthenticated: return .requiresRecentLogin
            case .unavailable, .deadlineExceeded: return .network
            default: return .unknown(ns.localizedDescription)
            }
        }
        if ns.domain == NSURLErrorDomain { return .network }
        guard let code = AuthErrorCode(rawValue: ns.code) else { return .unknown(ns.localizedDescription) }
        switch code {
        case .wrongPassword, .invalidCredential: return .invalidCredentials
        case .userNotFound: return .userNotFound
        case .invalidEmail: return .invalidEmail
        case .emailAlreadyInUse: return .emailInUse
        case .weakPassword: return .weakPassword
        case .userDisabled: return .userDisabled
        case .tooManyRequests: return .tooManyRequests
        case .networkError: return .network
        case .requiresRecentLogin, .userTokenExpired: return .requiresRecentLogin
        case .webContextCancelled: return .cancelled
        default: return .unknown(ns.localizedDescription)
        }
    }
}
