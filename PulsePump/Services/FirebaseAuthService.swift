import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

class FirebaseAuthService: AuthServiceProtocol {
    private(set) var isSignedIn: Bool

    private var currentNonce: String?

    nonisolated init() {
        self.isSignedIn = Auth.auth().currentUser != nil
    }

    // MARK: - Apple Sign In

    func signInWithApple() async throws -> AuthResult {
        fatalError("Use signInWithApple(credential:nonce:) instead")
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthResult {
        guard let nonce = currentNonce else {
            throw AuthError.unknown("Missing nonce for Apple Sign In")
        }
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.unknown("Unable to fetch Apple ID token")
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            isSignedIn = true

            let displayName = result.user.displayName

            return AuthResult(
                userId: result.user.uid,
                email: result.user.email ?? credential.email,
                displayName: displayName
            )
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    func prepareAppleSignIn() -> (nonce: String, hashedNonce: String) {
        let nonce = randomNonceString()
        currentNonce = nonce
        return (nonce, sha256(nonce))
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async throws -> AuthResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.unknown("Missing Firebase client ID")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.unknown("Unable to find root view controller")
        }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.unknown("Unable to fetch Google ID token")
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            isSignedIn = true
            return AuthResult(
                userId: authResult.user.uid,
                email: authResult.user.email,
                displayName: authResult.user.displayName
            )
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Email Auth

    func signInWithEmail(email: String, password: String) async throws -> AuthResult {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isSignedIn = true
            return AuthResult(
                userId: result.user.uid,
                email: result.user.email,
                displayName: result.user.displayName
            )
        } catch let error as NSError {
            if error.code == AuthErrorCode.wrongPassword.rawValue ||
               error.code == AuthErrorCode.userNotFound.rawValue {
                throw AuthError.invalidCredentials
            }
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    func signUpWithEmail(email: String, password: String) async throws -> AuthResult {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            isSignedIn = true
            return AuthResult(
                userId: result.user.uid,
                email: result.user.email,
                displayName: result.user.displayName
            )
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        isSignedIn = false
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
