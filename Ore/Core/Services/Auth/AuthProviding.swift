import Foundation

/// Removes an auth-state listener when called.
typealias AuthListenerRemoval = () -> Void

/// Everything `AuthSession` needs from an identity backend. Implemented by `FirebaseAuthProvider`
/// (production) and a fake in the tests.
@MainActor
protocol AuthProviding: AnyObject {
    /// Cached user (works offline). nil when signed out.
    var currentUser: AuthUser? { get }

    /// Registers a listener that is called promptly with the current user and again on every change.
    func addStateListener(_ handler: @escaping (AuthUser?) -> Void) -> AuthListenerRemoval

    func signInWithApple() async throws -> AuthUser
    func signInWithGoogle() async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(email: String, password: String) async throws -> AuthUser
    func sendPasswordReset(email: String) async throws

    /// Whether this email already has an account. nil = can't tell (the project hides it, or offline): the sign-up
    /// screen then finds out when the account is created.
    func emailHasAccount(_ email: String) async -> Bool?
    func signOut() throws

    /// Fresh credential for sensitive operations. `password` is only used for the email provider.
    func reauthenticate(provider: AuthProviderKind, password: String?) async throws

    /// Calls the `deleteAccount` Cloud Function (deletes the user's cloud data and the Auth user).
    /// Throws `AuthFailure.requiresRecentLogin` when a fresh sign-in is needed first.
    func callDeleteAccount() async throws

    /// Revokes the Sign in with Apple token for the signed-in user (a fresh Apple sign-in supplies the code). Run before
    /// `callDeleteAccount` for Apple accounts: App Review guideline 5.1.1(v).
    func revokeAppleToken() async throws
}

extension AuthProviding {
    func emailHasAccount(_ email: String) async -> Bool? { nil }

    func revokeAppleToken() async throws {}   // a provider with no Apple token has nothing to revoke
}
