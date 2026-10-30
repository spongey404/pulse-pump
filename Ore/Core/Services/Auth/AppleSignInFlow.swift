import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

/// What Apple returns, reduced to Sendable values.
struct AppleIDResult: Sendable {
    let idToken: String
    let rawNonce: String
    let authorizationCode: String?
    let fullName: PersonNameComponents?
    let email: String?
}

/// Runs one `ASAuthorizationController` request and returns the result with `async`/`await`.
@MainActor
final class AppleSignInFlow: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleIDResult, Error>?
    private var rawNonce = ""
    private var controller: ASAuthorizationController?

    func run() async throws -> AppleIDResult {
        rawNonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<AppleIDResult, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }

    // MARK: ASAuthorizationControllerDelegate

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            Task { @MainActor in self.finish(.failure(AuthFailure.unknown("Couldn't read the Apple sign-in token."))) }
            return
        }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let name = credential.fullName
        let email = credential.email
        Task { @MainActor in
            self.finish(.success(AppleIDResult(idToken: token, rawNonce: self.rawNonce, authorizationCode: code,
                                               fullName: name, email: email)))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as NSError).code == ASAuthorizationError.canceled.rawValue
        let failure: AuthFailure = cancelled ? .cancelled : .unknown(error.localizedDescription)
        Task { @MainActor in self.finish(.failure(failure)) }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }

    // MARK: Nonce

    static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Unable to generate nonce (OSStatus \(status))")
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
