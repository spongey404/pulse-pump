import SwiftUI
import SwiftData
import Observation

/// Onboarding is only for a brand-new account (signed in, nothing in the cloud, nothing local).
/// Sign-in itself lives in `Features/Auth`; returning users never reach this flow.
enum OnboardingStep: Int, CaseIterable {
    case name = 0
    case handle
    case weight
    case height
    case age
    case gender
    case experienceLevel
    case splitSelection
    case tutorialPrompt

    static let flow: [OnboardingStep] = allCases
    /// Steps that show the progress bar.
    static let progressSteps: [OnboardingStep] = allCases
}

@MainActor
@Observable
class OnboardingViewModel {
    var currentStep: OnboardingStep = .name
    var isSubmitting = false
    var submitError: String?

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

    /// Username entry + live availability.
    let handleInput: HandleInput
    let uid: String

    @ObservationIgnored private let remote: ProfileRemote
    /// Called after the cloud profile and local user both exist (the gate claims the local store).
    @ObservationIgnored var onAccountCreated: ((String) -> Void)?

    init(uid: String, prefilledName: String = "", remote: ProfileRemote, debounce: Duration = .milliseconds(350)) {
        self.uid = uid
        self.remote = remote
        self.name = prefilledName
        self.handleInput = HandleInput(remote: remote, uid: uid, debounce: debounce)
    }

    /// Switch the weight unit, re-expressing any weight already typed so the same body weight is kept.
    /// Height defaults to the matching system (ft/in for lbs, cm for kg).
    func setUnit(_ unit: UnitPreference) {
        guard unit != unitPreference else { return }
        if let kg = unitPreference.parseKg(weightText), kg > 0 {
            weightText = unit.number(kg)
        }
        unitPreference = unit
        useImperialHeight = (unit == .lbs)
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var canContinue: Bool {
        switch currentStep {
        case .name:        return !trimmedName.isEmpty
        case .handle:      return handleInput.isAvailable
        case .weight:
            guard let kg = unitPreference.parseKg(weightText), kg > 0 else { return false }
            return true
        case .height:
            if useImperialHeight {
                guard let ft = parseWholeNumber(heightFeet), ft > 0 else { return false }
                return true
            }
            guard let h = parseDecimal(heightText), h > 0 else { return false }
            return true
        case .age:
            guard let a = parseWholeNumber(ageText), a > 0, a < 120 else { return false }
            return true
        case .gender, .experienceLevel, .splitSelection, .tutorialPrompt:
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
        let next = flow[idx + 1]
        if next == .handle { Task { await suggestHandleIfEmpty() } }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = next }
    }

    func goBack() {
        let flow = OnboardingStep.flow
        guard let idx = flow.firstIndex(of: currentStep), idx > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = flow[idx - 1] }
    }

    /// First suggestion from the name ("Alex Smith" -> "alex_smith"), checked right away.
    func suggestHandleIfEmpty() async {
        guard handleInput.handle.isEmpty else { return }
        let suggestion = HandleValidator.suggestion(from: trimmedName)
        guard !suggestion.isEmpty else { return }
        await handleInput.prefill(suggestion)
    }

    // MARK: - Building the account

    /// Height in cm from whichever input system is active.
    var heightCm: Double {
        if useImperialHeight {
            return UnitPreference.cm(feet: parseDecimal(heightFeet) ?? 0, inches: parseDecimal(heightInches) ?? 0)
        }
        return parseDecimal(heightText) ?? 0
    }

    /// weightText is typed in `unitPreference`; stored weight is always kg.
    var weightKg: Double { unitPreference.parseKg(weightText) ?? 0 }

    /// The cloud-side base fields. Contains no stats or counters.
    func makeNewAccountProfile() -> NewAccountProfile {
        NewAccountProfile(
            uid: uid,
            handle: handleInput.handle,
            displayName: trimmedName,
            unit: unitPreference.rawValue,
            experienceLevel: (experienceLevel ?? .beginner).rawValue,
            gender: (gender ?? .preferNotToSay).rawValue,
            age: parseWholeNumber(ageText) ?? 0,
            heightCm: heightCm,
            weightKg: weightKg
        )
    }

    /// Creates `users/{uid}`, `profiles/{uid}` and `usernames/{handle}` atomically, then the local `User`.
    /// Nothing local is created if the remote write fails. Returns true on success.
    @discardableResult
    func submit(modelContext: ModelContext) async -> Bool {
        guard await submitRemote() else { return false }
        completeLocal(modelContext: modelContext)
        return true
    }

    /// The cloud half: the profile API call. Fails (and returns false) with `submitError` set; a taken handle also
    /// marks the handle taken and returns to the handle step. The sign-up console shows the setup lines in between.
    @discardableResult
    func submitRemote() async -> Bool {
        guard !isSubmitting else { return false }
        if let problem = HandleValidator.validate(handleInput.handle) {
            submitError = problem.message
            currentStep = .handle
            return false
        }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            try await remote.createAccount(makeNewAccountProfile())
        } catch let error as ProfileRemoteError {
            if error == .handleTaken {
                handleInput.markTaken()
                withAnimation(.easeInOut(duration: 0.25)) { currentStep = .handle }
            }
            submitError = error.message
            return false
        } catch {
            submitError = "Couldn't create your account. Please try again."
            return false
        }
        // From here the account exists: even if the app is closed before the tour choice, the paywall is still due.
        SupernovaPaywallGate.markPending()
        return true
    }

    /// The local half: the `User`, and the gate claims the store.
    func completeLocal(modelContext: ModelContext) {
        createLocalUser(modelContext: modelContext)
        onAccountCreated?(uid)
    }

    /// Local half of onboarding: `User` (+ split, bodyweight entry, tutorial flag).
    @discardableResult
    func createLocalUser(modelContext: ModelContext) -> User {
        let user = User(
            name: trimmedName,
            username: handleInput.handle,
            weight: weightKg,
            height: heightCm,
            age: parseWholeNumber(ageText) ?? 0,
            gender: gender ?? .preferNotToSay,
            unitPreference: unitPreference,
            experienceLevel: experienceLevel ?? .beginner
        )

        if selectedSplitType != .none {
            let split = SplitSchedule.makeSplit(type: selectedSplitType)
            modelContext.insert(split)
            user.selectedSplit = split
        }

        modelContext.insert(user)
        BodyweightLog.record(kg: user.weight)
        UserDefaults.standard.set(wantsTutorial, forKey: "wantsTutorial")
        SupernovaPaywallGate.markPending()   // the paywall follows the tutorial, or onboarding if it was declined
        return user
    }
}
