import Foundation

/// Sign-in providers an account can have linked.
enum AuthProviderKind: String, Codable, Equatable, Sendable {
    case apple, google, password, other

    var displayName: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        case .password: "Email"
        case .other: "Other"
        }
    }
}

/// The signed-in identity, independent of the Firebase SDK types.
struct AuthUser: Equatable, Sendable {
    var uid: String
    var email: String?
    var displayName: String?
    var providers: [AuthProviderKind]
    /// True right after the account was created (first sign-in with this provider).
    var isNewUser: Bool = false

    /// The provider to re-authenticate with (first linked provider wins).
    var primaryProvider: AuthProviderKind { providers.first ?? .other }
    var providerSummary: String {
        let names = providers.filter { $0 != .other }.map(\.displayName)
        return names.isEmpty ? "Account" : names.joined(separator: " · ")
    }
}

enum AuthState: Equatable {
    /// Auth has not reported yet (cold launch).
    case unknown
    case signedOut
    case signedIn(AuthUser)

    var user: AuthUser? {
        if case .signedIn(let user) = self { return user }
        return nil
    }
}

/// Provider-independent failures with user-facing text.
enum AuthFailure: Error, Equatable {
    case cancelled
    case invalidCredentials
    case invalidEmail
    case emailInUse
    case weakPassword
    case userNotFound
    case userDisabled
    case tooManyRequests
    case network
    case requiresRecentLogin
    case passwordRequired
    case notSignedIn
    case unknown(String)

    var message: String {
        switch self {
        case .cancelled: "Sign in was cancelled."
        case .invalidCredentials: "That email or password isn't right."
        case .invalidEmail: "Enter a valid email address."
        case .emailInUse: "An account with this email already exists. Try signing in instead."
        case .weakPassword: "Choose a stronger password (at least 8 characters)."
        case .userNotFound: "No account found for that email."
        case .userDisabled: "This account has been disabled. Contact support."
        case .tooManyRequests: "Too many attempts. Wait a moment and try again."
        case .network: "Can't reach the server. Check your connection and try again."
        case .requiresRecentLogin: "For your security, please sign in again to continue."
        case .passwordRequired: "Enter your password to confirm."
        case .notSignedIn: "You're not signed in."
        case .unknown(let text): text.isEmpty ? "Something went wrong. Please try again." : text
        }
    }
}

extension AuthFailure: LocalizedError {
    var errorDescription: String? { message }
}

/// Converts any thrown error to a user-facing message (silent for cancellation).
enum AuthErrorMapper {
    static func failure(from error: Error) -> AuthFailure {
        (error as? AuthFailure) ?? .unknown(error.localizedDescription)
    }

    /// nil when the user cancelled and no message should be shown.
    static func message(for error: Error) -> String? {
        let failure = failure(from: error)
        return failure == .cancelled ? nil : failure.message
    }
}
