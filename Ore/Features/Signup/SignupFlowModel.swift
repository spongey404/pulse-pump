import SwiftUI
import SwiftData
import Observation

enum SignupStage: Equatable { case landing, console, setup, welcome }
enum SignupMethod: Equatable { case email, apple, google }

/// The speed of the star field's surge: set by the flow when a step is answered, decayed and read by the renderer.
/// A plain reference, so the renderer can read it every frame without observation.
final class SignupSurge {
    var boost: Double = 0
}

/// The state machine of the sign-up console (design "Ore Signup Final"): the opening screen, ten questions asked one at a
/// time (eight after Apple / Google), the setup lines, the welcome. It owns no views. Accounts: email and password
/// create (or sign in to) the Firebase account at the password step; the profile is written when the last answer is in;
/// the local user is created only when the tour choice is made, so the console stays up until then.
@MainActor
@Observable
final class SignupFlowModel {
    struct LogRow: Identifiable, Equatable {
        var id: String
        var label: String
        var value: String
        var editable: Bool
        var delay: Double
    }
    struct SetupLine: Identifiable, Equatable {
        var id: Int
        var text: String
        var right: String
        var delay: Double
    }

    @ObservationIgnored let config: SignupConfig
    @ObservationIgnored let session: AuthSession
    @ObservationIgnored let remote: ProfileRemote
    @ObservationIgnored private let debounce: Duration
    /// Show prompts at once (Reduce Motion, UI tests).
    @ObservationIgnored var instant: Bool
    @ObservationIgnored let surge = SignupSurge()
    @ObservationIgnored private var typing: Task<Void, Never>?
    @ObservationIgnored private var setup: Task<Void, Never>?
    @ObservationIgnored private var namePrefill = ""
    /// Fires with the uid once the local user exists, so the gate leaves onboarding.
    @ObservationIgnored var onCreated: (String) -> Void

    private(set) var stage: SignupStage = .landing
    private(set) var method: SignupMethod = .email
    private(set) var steps: [SignupConfig.Step]
    private(set) var stepIndex = 0
    private(set) var typed = 0
    private(set) var answers: [String: String] = [:]
    private(set) var units = ["weight": "KG", "height": "CM"]
    /// The email has an account: the password question becomes "Enter your password."
    private(set) var signInMode = false
    /// The Firebase account exists, so the email and password rows can no longer be edited.
    private(set) var accountExists = false
    private(set) var isBusy = false
    private(set) var errorHint: String?
    private(set) var resetSent = false
    private(set) var setupLines = 0
    private(set) var setupError: String?
    private(set) var onboarding: OnboardingViewModel?
    /// What the field holds. Set through `typeValue` so it is cleaned; the view binds to `value`.
    var value = "" { didSet { if value != oldValue { valueChanged() } } }

    init(config: SignupConfig, session: AuthSession, remote: ProfileRemote,
         instant: Bool = false, onCreated: @escaping (String) -> Void = { _ in }) {
        self.config = config
        self.session = session
        self.remote = remote
        self.instant = instant
        self.onCreated = onCreated
        debounce = .milliseconds(config.validation.usernameDebounceMs)
        steps = config.steps
        // Already signed in (the app was closed after creating the account, or the account has no profile yet):
        // the questions that need the account are done.
        if let user = session.user { resume(with: user) }
        #if DEBUG
        // `-debugSignupStep password` opens the email path at the password question with a typed password (screenshots).
        if session.user == nil, UserDefaults.standard.string(forKey: "debugSignupStep") == "setup" {
            // The setup lines, as they look when all four are in.
            beginEmail()
            answers = ["email": "casey@ore.app", "password": "••••••••••••", "name": "Casey", "username": "casey.lifts", "weight": "82",
                       "height": "180", "age": "31", "gender": "preferNotToSay", "exp": "intermediate", "split": "ppl"]
            stepIndex = steps.count
            stage = .setup
            setupLines = 4
        }
        if session.user == nil, UserDefaults.standard.string(forKey: "debugSignupStep") == "password" {
            beginEmail()
            answers["email"] = "casey@ore.app"
            stepIndex = 1
            prepareStep()
            typed = prompt.count
            value = "lifts-2026!"
        }
        #endif
    }

    // MARK: Derived

    var current: SignupConfig.Step? { stage == .console && stepIndex < steps.count ? steps[stepIndex] : nil }
    var total: Int { steps.count }
    var answeredCount: Int { steps.filter { answers[$0.key] != nil }.count }
    var level: Double { stage == .landing ? 0 : stage == .console ? SignupStarEngine.level(answered: answeredCount, total: total) : 1 }
    var progressLabel: String {
        switch stage {
        case .landing: "SIGN UP"
        case .console: "STEP \(min(stepIndex + 1, total)) OF \(total)"
        case .setup, .welcome: "DONE"
        }
    }
    var questionNumber: String {
        guard let s = current else { return "" }
        return String(format: "%02d", stepIndex + 1) + " / " + s.label
    }
    var prompt: String { current.map(promptText) ?? "" }
    var typedPrompt: String { String(prompt.prefix(typed)) }
    var promptDone: Bool { current != nil && typed >= prompt.count }
    var firstName: String { (answers["name"] ?? "").split(separator: " ").first.map(String.init) ?? "" }
    var welcomeTitle: String { "Welcome, \(firstName)." }
    var isSignInMode: Bool { signInMode }
    var heightUnit: String { units["height"] ?? "CM" }

    var check: SignupValidation.Check {
        guard let s = current, s.kind != "choice" else { return .init(ok: false, hint: "") }
        return SignupValidation.check(key: s.key, value: value, units: units,
                                      handleStatus: onboarding?.handleInput.status ?? .idle, config: config)
    }
    var hint: String { errorHint ?? (signInMode && current?.key == "password" && resetSent ? "RESET LINK SENT" : check.hint) }
    var hintIsBad: Bool { errorHint != nil || check.bad }
    var canSubmit: Bool { check.ok && !isBusy }
    var showsMeter: Bool { current?.key == "password" && !signInMode && !value.isEmpty }
    var meterScore: Int { SignupValidation.passwordScore(value, config: config) }

    func promptText(_ s: SignupConfig.Step) -> String {
        if s.key == "password", signInMode { return "Enter your password." }
        return s.prompt.replacingOccurrences(of: "{name}", with: firstName.isEmpty ? "there" : firstName)
    }

    func display(key: String, value v: String) -> String {
        switch key {
        case "username": return "@" + v
        case "email": return v == "Apple" || v == "Google" ? "Signed in with \(v)" : v
        case "weight": return v + " " + (units["weight"] ?? "KG")
        case "height":
            if heightUnit == "CM" { return v + " CM" }
            return SignupValidation.parseFtIn(v).map { "\($0.ft)'\($0.inch)\"" } ?? v
        case "age": return v + " YRS"
        case "gender", "exp", "split": return config.step(key)?.choices.first { $0.value == v }?.label ?? v
        default: return v
        }
    }

    var logRows: [LogRow] {
        var rows: [LogRow] = []
        for (i, s) in config.steps.enumerated() {
            guard let v = answers[s.key], !v.isEmpty else { continue }
            let index = steps.firstIndex { $0.key == s.key }
            let locked = (s.key == "email" || s.key == "password") && (accountExists || index == nil)
            rows.append(LogRow(id: s.key, label: s.label, value: display(key: s.key, value: v),
                               editable: stage == .console && !locked && index != nil,
                               delay: -(Double(i) * config.bullet.logOffset).truncatingRemainder(dividingBy: config.bullet.seconds)))
        }
        return rows
    }

    /// The four lines shown after the last answer; line 1 appears only once the profile is saved.
    var setupRows: [SetupLine] {
        let split = config.step("split")?.choices.first { $0.value == answers["split"] }
        let all: [(String, String)] = [
            ("PROFILE SAVED", "@" + (answers["username"] ?? "")),
            ("BODY STATS SET", [answers["weight"].map { display(key: "weight", value: $0) }, answers["height"].map { display(key: "height", value: $0) }]
                .compactMap { $0 }.joined(separator: " · ")),
            ("PROGRAM SELECTED", (split?.label ?? "").uppercased()),
            ("WEEK 1 SCHEDULED", split?.meta ?? ""),
        ]
        return all.prefix(min(setupLines, 4)).enumerated().map { i, l in
            SetupLine(id: i, text: l.0, right: l.1, delay: -(Double(i) * config.bullet.setupOffset + config.bullet.setupBase))
        }
    }

    // MARK: Opening screen

    func beginEmail() {
        method = .email
        steps = config.steps
        enterConsole(startAt: 0, boost: config.stars.boostEmail)
    }

    /// Apple or Google: native sign-in, then straight to the name question (no email or password questions).
    func signIn(with provider: SignupMethod) async {
        guard stage == .landing, !isBusy, provider != .email else { return }
        isBusy = true
        session.clearMessages()
        if provider == .apple { await session.signInWithApple() } else { await session.signInWithGoogle() }
        isBusy = false
        guard let user = session.user else { return }
        method = provider
        resume(with: user, boost: config.stars.boostApple)
    }

    /// The account exists already: the questions that need it are answered, start at the name.
    private func resume(with user: AuthUser, boost: Double = 0) {
        accountExists = true
        let provider = user.primaryProvider
        method = provider == .apple ? .apple : provider == .google ? .google : .email
        steps = config.steps.filter { $0.key != "email" && $0.key != "password" }
        answers["email"] = provider == .apple ? "Apple" : provider == .google ? "Google" : (user.email ?? "")
        makeOnboarding(user)
        enterConsole(startAt: 0, boost: boost)
    }

    private func makeOnboarding(_ user: AuthUser) {
        namePrefill = (user.displayName ?? "").split(separator: " ").first.map(String.init) ?? ""
        onboarding = OnboardingViewModel(uid: user.uid, prefilledName: "", remote: remote, debounce: debounce)
    }

    private func enterConsole(startAt index: Int, boost: Double) {
        stage = .console
        stepIndex = index
        surge.boost = max(surge.boost, boost)
        prepareStep()
    }

    // MARK: Answering

    /// CONTINUE or Return.
    func submit() {
        guard let s = current, s.kind != "choice", check.ok, !isBusy else { return }
        let v = s.key == "name" ? value.trimmingCharacters(in: .whitespaces) : value
        switch s.key {
        case "email": Task { await answerEmail(v) }
        case "password": Task { await answerPassword(v) }
        default: answer(v)
        }
    }

    func choose(_ index: Int) {
        guard let s = current, s.kind == "choice", promptDone, s.choices.indices.contains(index) else { return }
        answer(s.choices[index].value)
    }

    func setUnit(_ unit: String) {
        guard let s = current, s.units.contains(unit), units[s.key] != unit else { return }
        units[s.key] = unit
        value = ""
    }

    private func answerEmail(_ email: String) async {
        isBusy = true
        let exists = await session.emailHasAccount(email)
        isBusy = false
        signInMode = exists == true
        answer(email)
    }

    private func answerPassword(_ password: String) async {
        guard let email = answers["email"] else { return }
        isBusy = true
        errorHint = nil
        let ok = signInMode ? await session.signInWithEmail(email, password: password) : await session.signUp(email: email, password: password)
        isBusy = false
        if ok, let user = session.user {
            accountExists = true
            makeOnboarding(user)
            answer(String(repeating: "•", count: min(12, password.count)))
        } else if !signInMode, session.lastFailure == .emailInUse {
            // The email has an account after all: ask for its password instead.
            signInMode = true
            value = ""
            prepareStep()
        } else {
            errorHint = (session.errorMessage ?? "SOMETHING WENT WRONG").uppercased()
        }
    }

    /// Forgotten password, while signing in.
    func sendReset() async {
        guard signInMode, let email = answers["email"] else { return }
        resetSent = await session.sendPasswordReset(email: email)
        if !resetSent { errorHint = (session.errorMessage ?? "").uppercased() }
    }

    private func answer(_ val: String) {
        guard let s = current else { return }
        answers[s.key] = val
        surge.boost = config.stars.boostAnswer
        var next = stepIndex + 1
        while next < steps.count, answers[steps[next].key] != nil { next += 1 }
        stepIndex = next
        value = ""
        errorHint = nil
        if next < steps.count { prepareStep() } else { beginSetup() }
    }

    /// Tap a log row: that question reopens (a password reopens empty); later answers are kept and skipped over.
    func edit(_ key: String) {
        guard stage == .console, let i = steps.firstIndex(where: { $0.key == key }) else { return }
        guard !(accountExists && (key == "email" || key == "password")) else { return }
        let old = answers[key]
        answers[key] = nil
        stepIndex = i
        errorHint = nil
        let reopened = steps[i].key == "password" || steps[i].kind == "choice" ? "" : (old ?? "")
        prepareStep(prefill: reopened)
    }

    // MARK: Typing

    private func prepareStep(prefill: String? = nil) {
        typing?.cancel()
        typed = 0
        errorHint = nil
        let s = steps[stepIndex]
        var start = prefill ?? ""
        if prefill == nil, s.key == "name" { start = namePrefill }
        value = start
        if instant { typed = prompt.count; return }
        typing = Task { [weak self] in
            while let self, !Task.isCancelled, self.current != nil, self.typed < self.prompt.count {
                try? await Task.sleep(for: .milliseconds(self.config.typing.msPerChar))
                if Task.isCancelled { return }
                self.typed += 1
            }
        }
    }

    private func valueChanged() {
        guard let s = current else { return }
        let clean = SignupValidation.sanitize(key: s.key, text: value, heightUnit: heightUnit)
        if clean != value { value = clean; return }
        errorHint = nil
        if s.key == "username", let ob = onboarding {
            ob.handleInput.text = value
            ob.handleInput.textChanged()
        }
    }

    // MARK: Setup and welcome

    private func beginSetup() {
        stage = .setup
        setupLines = 0
        setupError = nil
        apply(to: onboarding)
        runSetup()
    }

    func retrySetup() { guard stage == .setup else { return }; setupError = nil; runSetup() }

    private func runSetup() {
        setup?.cancel()
        setup = Task { [weak self] in
            guard let self, let ob = self.onboarding else { return }
            guard await ob.submitRemote() else {
                if ob.handleInput.status == .taken {
                    self.stage = .console
                    self.edit("username")
                    self.errorHint = "ALREADY TAKEN"
                } else {
                    self.setupError = ob.submitError ?? "Couldn't create your account. Please try again."
                }
                return
            }
            let t = self.config.typing
            for line in 1...4 {
                if !self.instant { try? await Task.sleep(for: .milliseconds(line == 1 ? t.setupStartMs : t.setupLineMs)) }
                if Task.isCancelled { return }
                self.setupLines = line
            }
            if !self.instant { try? await Task.sleep(for: .milliseconds(t.setupLineMs)) }
            if Task.isCancelled { return }
            self.stage = .welcome
            self.surge.boost = self.config.stars.boostDone
        }
    }

    /// The tour choice: creates the local user and hands over to the app (tutorial, then paywall, or paywall).
    func finish(tutorial: Bool, modelContext: ModelContext) {
        guard stage == .welcome, let ob = onboarding else { return }
        ob.wantsTutorial = tutorial
        ob.completeLocal(modelContext: modelContext)
    }

    /// The answers, in the form `OnboardingViewModel` and the profile API take (weight and height are stored metric).
    func apply(to ob: OnboardingViewModel?) {
        guard let ob else { return }
        ob.name = answers["name"] ?? ""
        ob.handleInput.text = answers["username"] ?? ""
        ob.unitPreference = units["weight"] == "LB" ? .lbs : .kg
        ob.weightText = answers["weight"] ?? ""
        ob.useImperialHeight = heightUnit != "CM"
        if ob.useImperialHeight, let p = SignupValidation.parseFtIn(answers["height"] ?? "") {
            ob.heightFeet = String(p.ft); ob.heightInches = String(p.inch)
        } else {
            ob.heightText = answers["height"] ?? ""
        }
        ob.ageText = answers["age"] ?? ""
        ob.gender = answers["gender"].flatMap(Gender.init(rawValue:))
        ob.experienceLevel = answers["exp"].flatMap(ExperienceLevel.init(rawValue:))
        ob.selectedSplitType = answers["split"].flatMap(SplitType.init(rawValue:)) ?? .none
    }

    func cancelTasks() { typing?.cancel(); setup?.cancel(); onboarding?.handleInput.cancel() }
}
