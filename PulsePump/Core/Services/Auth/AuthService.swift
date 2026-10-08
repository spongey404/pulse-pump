import Foundation

struct AuthResult {
    let userId: String
    let email: String?
    let displayName: String?
    var isNewUser: Bool = true
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Invalid email or password."
        case .networkError: "Network error. Please try again."
        case .unknown(let message): message
        }
    }
}

protocol AuthServiceProtocol {
    func signInWithApple() async throws -> AuthResult
    func signInWithGoogle() async throws -> AuthResult
    func signInWithEmail(email: String, password: String) async throws -> AuthResult
    func signUpWithEmail(email: String, password: String) async throws -> AuthResult
    func signOut() throws
    var isSignedIn: Bool { get }
}

// TODO: Replace with FirebaseAuthService once Firebase is configured
class LocalAuthService: AuthServiceProtocol {
    private(set) var isSignedIn = false

    func signInWithApple() async throws -> AuthResult {
        isSignedIn = true
        return AuthResult(userId: UUID().uuidString, email: nil, displayName: nil)
    }

    func signInWithGoogle() async throws -> AuthResult {
        isSignedIn = true
        return AuthResult(userId: UUID().uuidString, email: nil, displayName: nil)
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthResult {
        isSignedIn = true
        return AuthResult(userId: UUID().uuidString, email: email, displayName: nil)
    }

    func signUpWithEmail(email: String, password: String) async throws -> AuthResult {
        isSignedIn = true
        return AuthResult(userId: UUID().uuidString, email: email, displayName: nil)
    }

    func signOut() throws {
        isSignedIn = false
    }
}
