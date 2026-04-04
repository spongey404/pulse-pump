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
    case unitPreference
    case experienceLevel
    case splitSelection
    case tutorialPrompt

    static let profileSteps: [OnboardingStep] = [
        .name, .weight, .height, .age, .gender, .unitPreference, .experienceLevel, .splitSelection
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
    var gender: Gender = .preferNotToSay
    var unitPreference: UnitPreference = .kg
    var experienceLevel: ExperienceLevel = .beginner
    var selectedSplitType: SplitType = .none
    var wantsTutorial = false

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
        case .welcome:
            return isAuthenticated
        case .name:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
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
        guard let index = OnboardingStep.profileSteps.firstIndex(of: currentStep) else {
            return currentStep == .tutorialPrompt ? 1.0 : 0
        }
        return Double(index + 1) / Double(OnboardingStep.profileSteps.count)
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }
    }

    func goBack() {
        guard currentStep.rawValue > 1 else { return }
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = prev
        }
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
            gender: gender,
            unitPreference: unitPreference,
            experienceLevel: experienceLevel
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

    func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonceData = authService.prepareAppleSignIn()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonceData.hashedNonce
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Invalid Apple credential"
                return
            }
            Task {
                isLoading = true
                defer { isLoading = false }
                do {
                    let authResult = try await authService.signInWithApple(credential: appleCredential)
                    if name.isEmpty, let displayName = authResult.displayName {
                        name = displayName
                    }
                    isAuthenticated = true
                    advance()
                } catch {
                    authError = error.localizedDescription
                }
            }
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
                advance()
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
                } else {
                    _ = try await authService.signInWithEmail(email: email, password: password)
                }
                isAuthenticated = true
                showEmailAuth = false
                advance()
            } catch {
                authError = error.localizedDescription
            }
        }
    }
}
