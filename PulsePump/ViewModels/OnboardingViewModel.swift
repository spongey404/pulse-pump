import SwiftUI
import SwiftData
import AuthenticationServices
import FirebaseAuth
import Observation

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case name
    case weight
    case height
    case age
    case gender
    case unitPreference  // kept for Codable compat, skipped in flow
    case experienceLevel
    case splitSelection
    case tutorialPrompt

    // Ordered flow — no separate unit-preference step; units collected inline
    static let flow: [OnboardingStep] = [
        .welcome, .name, .weight, .height, .age, .gender, .experienceLevel, .splitSelection, .tutorialPrompt
    ]

    // Steps that show the progress bar (1 of 8 … 8 of 8)
    static let progressSteps: [OnboardingStep] = [
        .name, .weight, .height, .age, .gender, .experienceLevel, .splitSelection, .tutorialPrompt
    ]
}

@MainActor
@Observable
class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var isAuthenticated = false
    var isLoading = false
    var authError: String?

    // Profile
    var name = ""
    var weightText = ""
    var heightText = ""
    var heightFeet = ""
    var heightInches = ""
    var useImperialHeight = false
    var ageText = ""
    var gender: Gender? = nil
    var unitPreference: UnitPreference = .kg
    var experienceLevel: ExperienceLevel? = nil
    var selectedSplitType: SplitType = .none
    var wantsTutorial = false

    // Set to true after sign-in (not sign-up) so container skips profile steps
    var shouldSkipToComplete = false

    // Email auth
    var showEmailAuth = false
    var isSignUp = false
    var email = ""
    var password = ""

    let authService: FirebaseAuthService

    init(authService: FirebaseAuthService = .init()) {
        self.authService = authService
    }

    var canContinue: Bool {
        switch currentStep {
        case .welcome:     return isAuthenticated
        case .name:        return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .weight:
            guard let w = Double(weightText), w > 0 else { return false }
            return true
        case .height:
            if useImperialHeight {
                guard let ft = Int(heightFeet), ft > 0 else { return false }
                return true
            }
            guard let h = Double(heightText), h > 0 else { return false }
            return true
        case .age:
            guard let a = Int(ageText), a > 0, a < 120 else { return false }
            return true
        case .gender, .unitPreference, .experienceLevel, .splitSelection, .tutorialPrompt:
            return true
        }
    }

    var progress: Double {
        guard let idx = OnboardingStep.progressSteps.firstIndex(of: currentStep) else { return 0 }
        return Double(idx + 1) / Double(OnboardingStep.progressSteps.count)
    }

    var stepNumber: Int {
        (OnboardingStep.progressSteps.firstIndex(of: currentStep) ?? -1) + 1
    }

    var totalSteps: Int { OnboardingStep.progressSteps.count }

    func advance() {
        let flow = OnboardingStep.flow
        guard let idx = flow.firstIndex(of: currentStep), idx + 1 < flow.count else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = flow[idx + 1] }
    }

    func goBack() {
        let flow = OnboardingStep.flow
        guard let idx = flow.firstIndex(of: currentStep), idx > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = flow[idx - 1] }
    }

    func completeOnboarding(modelContext: ModelContext) {
        let weightValue = Double(weightText) ?? 0

        var heightCm: Double
        if useImperialHeight {
            let feet = Double(heightFeet) ?? 0
            let inches = Double(heightInches) ?? 0
            heightCm = (feet * 30.48) + (inches * 2.54)
        } else {
            heightCm = Double(heightText) ?? 0
        }

        let user = User(
            name: name.trimmingCharacters(in: .whitespaces),
            weight: weightValue,
            height: heightCm,
            age: Int(ageText) ?? 0,
            gender: gender ?? .preferNotToSay,
            unitPreference: unitPreference,
            experienceLevel: experienceLevel ?? .beginner
        )

        if selectedSplitType != .none {
            let split = Split(type: selectedSplitType)
            modelContext.insert(split)
            user.selectedSplit = split
        }

        modelContext.insert(user)
        UserDefaults.standard.set(wantsTutorial, forKey: "wantsTutorial")

        // Sync user profile to Firestore
        if let uid = Auth.auth().currentUser?.uid {
            let username = name.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: " ", with: "")
            let profile = FirestoreUserProfile(
                uid: uid,
                username: username,
                displayName: name.trimmingCharacters(in: .whitespaces)
            )
            Task {
                try? await FirestoreService().createOrUpdateUserProfile(profile)
            }
        }
    }

    // MARK: - Apple Sign In

    private var appleCoordinator: AppleSignInCoordinator?

    func signInWithApple() {
        let nonceData = authService.prepareAppleSignIn()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonceData.hashedNonce

        let coordinator = AppleSignInCoordinator(viewModel: self)
        appleCoordinator = coordinator

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }

    func processAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let authResult = try await authService.signInWithApple(credential: credential)
                if name.isEmpty, let displayName = authResult.displayName {
                    name = displayName
                }
                isAuthenticated = true
                if authResult.isNewUser {
                    advance()
                } else {
                    shouldSkipToComplete = true
                }
            } catch {
                authError = error.localizedDescription
            }
        }
    }

    // Legacy callbacks kept for any remaining SignInWithAppleButton usage
    func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonceData = authService.prepareAppleSignIn()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonceData.hashedNonce
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            processAppleCredential(credential)
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            authError = error.localizedDescription
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let result = try await authService.signInWithGoogle()
                if name.isEmpty, let displayName = result.displayName {
                    name = displayName
                }
                isAuthenticated = true
                if result.isNewUser {
                    advance()
                } else {
                    shouldSkipToComplete = true
                }
            } catch {
                authError = error.localizedDescription
            }
        }
    }

    // MARK: - Email Auth

    func submitEmailAuth() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                if isSignUp {
                    _ = try await authService.signUpWithEmail(email: email, password: password)
                    isAuthenticated = true
                    showEmailAuth = false
                    advance()
                } else {
                    _ = try await authService.signInWithEmail(email: email, password: password)
                    isAuthenticated = true
                    showEmailAuth = false
                    shouldSkipToComplete = true
                }
            } catch {
                authError = error.localizedDescription
            }
        }
    }
}

// MARK: - Apple Sign In coordinator (programmatic flow, no SignInWithAppleButton required)

final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private weak var viewModel: OnboardingViewModel?

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        Task { @MainActor in self.viewModel?.processAppleCredential(credential) }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        guard (error as NSError).code != ASAuthorizationError.canceled.rawValue else { return }
        Task { @MainActor in self.viewModel?.authError = error.localizedDescription }
    }
}
