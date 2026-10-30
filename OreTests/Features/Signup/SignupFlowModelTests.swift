import Testing
import Foundation
@testable import Ore

/// The sign-up console's state machine against a fake auth provider and profile API, with the typing animation off.
@MainActor
struct SignupFlowModelTests {
    private struct Rig {
        let model: SignupFlowModel
        let provider: FakeAuthProvider
        let remote: FakeProfileRemote
        let session: AuthSession
    }

    private func rig(current: AuthUser? = nil, known: Set<String> = [], reveals: Bool = false) -> Rig {
        let provider = FakeAuthProvider(current: current)
        provider.knownEmails = known
        provider.revealsAccounts = reveals
        let session = AuthSession(provider: provider, lifecycle: RecordingLifecycle())
        session.start()
        let remote = FakeProfileRemote()
        let model = SignupFlowModel(config: .fallback, session: session, remote: remote, instant: true)
        return Rig(model: model, provider: provider, remote: remote, session: session)
    }

    private func settle(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    private func type(_ model: SignupFlowModel, _ text: String) async {
        model.value = text
        model.submit()
    }

    /// Answers every question from the name onward with valid values.
    private func finishQuestions(_ r: Rig, username: String = "casey.lifts") async {
        await type(r.model, "Casey")
        r.model.value = username
        await settle { r.model.check.ok }
        r.model.submit()
        await type(r.model, "82")
        await type(r.model, "180")
        await type(r.model, "31")
        r.model.choose(3)   // Other
        r.model.choose(1)   // Some experience
        r.model.choose(0)   // Push / Pull / Legs
    }

    // MARK: Opening and the account steps

    @Test func startsOnTheOpeningScreenWithNothingAnswered() {
        let r = rig()
        #expect(r.model.stage == .landing)
        #expect(r.model.level == 0)
        #expect(r.model.progressLabel == "SIGN UP")
    }

    @Test func emailPathAsksElevenQuestionsAndSavesNothingUntilTheEnd() async {
        let r = rig()
        r.model.beginEmail()
        #expect(r.model.total == 11)
        #expect(r.model.progressLabel == "STEP 1 OF 11")
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        #expect(r.model.prompt == "Create a password.")
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "confirm" }
        #expect(r.model.prompt == "Confirm your password.")
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "name" }
        #expect(r.session.user == nil, "no account is created before the last answer")
        let rows = r.model.logRows
        #expect(rows.map(\.id) == ["email", "password", "confirm"])
        let editable = rows.map { $0.editable }
        #expect(!editable.contains(false), "so email and password can still be changed")
        #expect(rows[1].value == String(repeating: "•", count: 12))
    }

    @Test func theConfirmationHasToMatch() async {
        let r = rig()
        r.model.beginEmail()
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "confirm" }
        r.model.value = "pw-lifts-20"
        #expect(!r.model.canSubmit && r.model.hint == "DOESN'T MATCH YET" && !r.model.hintIsBad, "still typing: not an error yet")
        r.model.value = "pw-lifts-2027"
        #expect(!r.model.canSubmit && r.model.hintIsBad)
        r.model.value = "pw-lifts-2026"
        #expect(r.model.canSubmit && r.model.hint == "MATCHES")
    }

    @Test func changingThePasswordAsksForItsConfirmationAgain() async {
        let r = rig()
        r.model.beginEmail()
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "confirm" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "name" }
        r.model.edit("password")
        #expect(r.model.current?.key == "password" && r.model.value.isEmpty, "a password reopens empty")
        await type(r.model, "another-pw-1")
        await settle { r.model.current?.key == "confirm" }
        #expect(r.model.current?.key == "confirm", "the confirmation is asked again, then back to where we were")
        await type(r.model, "another-pw-1")
        await settle { r.model.current?.key == "name" }
        #expect(r.model.current?.key == "name")
        // The same password typed again keeps its confirmation.
        r.model.edit("password")
        await type(r.model, "another-pw-1")
        await settle { r.model.current?.key == "name" }
        #expect(r.model.current?.key == "name")
    }

    @Test func theAccountIsCreatedAtTheEndWithTheEmailAndPassword() async {
        let r = rig()
        r.model.beginEmail()
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "confirm" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "name" }
        await finishQuestions(r)
        await settle { r.model.stage == .welcome }
        #expect(r.model.stage == .welcome)
        #expect(r.session.user?.email == "casey@ore.app")
        #expect(r.remote.createdProfiles.count == 1)
        #expect(r.provider.signUpCalls == ["casey@ore.app"])
    }

    @Test func aTakenEmailFoundAtTheEndSendsYouToItsPassword() async {
        let r = rig(known: ["casey@ore.app"], reveals: false)
        r.model.beginEmail()
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "confirm" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "name" }
        await finishQuestions(r)
        await settle { r.model.isSignInMode }
        #expect(r.model.stage == .console && r.model.current?.key == "password")
        #expect(r.model.prompt == "Enter your password.")
        #expect(r.model.hint == "THAT EMAIL ALREADY HAS AN ACCOUNT · ENTER ITS PASSWORD" && !r.model.hintIsBad)
        #expect(r.model.answers["weight"] == "82", "everything typed is kept")
        let hasConfirm = r.model.steps.contains { $0.key == "confirm" }
        #expect(!hasConfirm)
        // Signing in with it goes straight on to the profile.
        r.provider.knownEmails = []   // the fake signs anyone in; the point is the flow
        await type(r.model, "its-real-password")
        await settle { r.model.stage == .welcome }
        #expect(r.model.stage == .welcome)
        #expect(r.remote.createdProfiles.count == 1)
    }

    @Test func aWeakPasswordReopensThePasswordQuestion() async {
        let r = rig()
        r.provider.signUpError = AuthFailure.weakPassword
        r.model.beginEmail()
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "confirm" }
        await type(r.model, "pw-lifts-2026")
        await settle { r.model.current?.key == "name" }
        await finishQuestions(r)
        await settle { r.model.stage == .console && r.model.current?.key == "password" }
        #expect(r.model.current?.key == "password" && r.model.hintIsBad)
        #expect(r.remote.createdProfiles.isEmpty)
    }

    @Test func applePathSkipsEmailAndPasswordAndLogsTheSignIn() async {
        let r = rig()
        await r.model.signIn(with: .apple)
        #expect(r.model.stage == .console)
        #expect(r.model.total == 8)
        #expect(r.model.current?.key == "name")
        #expect(r.model.progressLabel == "STEP 1 OF 8")
        #expect(r.model.logRows.first?.value == "Signed in with Apple")
        #expect(r.model.value == "Alex", "the name is offered from the Apple account")
    }

    @Test func aKnownEmailGetsAPasswordOnlySignIn() async {
        let r = rig(known: ["casey@ore.app"], reveals: true)
        r.model.beginEmail()
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        #expect(r.model.prompt == "Enter your password.")
        #expect(r.model.isSignInMode)
        #expect(!r.model.showsMeter)
        #expect(r.model.total == 10, "no confirmation when signing in")
    }

    @Test func aSessionThatStartsOnTheOpeningScreenContinuesFromTheName() async {
        let r = rig()
        #expect(r.model.stage == .landing)
        await r.session.signInWithEmail("casey@ore.app", password: "pw-lifts-2026")   // e.g. an auto sign-in
        r.model.sessionChanged()
        #expect(r.model.stage == .console && r.model.current?.key == "name")
        #expect(r.model.total == 8)
        r.model.sessionChanged()   // idempotent
        #expect(r.model.current?.key == "name")
    }

    @Test func signedInWithoutAProfileResumesAtTheName() {
        let r = rig(current: Fixtures.user(email: "casey@ore.app", providers: [.password]))
        #expect(r.model.stage == .console)
        #expect(r.model.current?.key == "name")
        #expect(r.model.total == 8)
        #expect(r.model.logRows.first?.value == "casey@ore.app")
    }

    // MARK: Questions

    @Test func eachAnswerRaisesTheLevelAndSurgesTheStars() async {
        let r = rig(current: Fixtures.user())
        #expect(r.model.level == 0)
        await type(r.model, "Casey")
        #expect(r.model.level == 1.0 / 8)
        #expect(r.model.surge.boost == r.model.config.stars.boostAnswer)
        #expect(r.model.current?.key == "username")
    }

    @Test func theQuestionUsesTheFirstName() async {
        let r = rig(current: Fixtures.user())
        await type(r.model, "Casey Jones")
        r.model.value = "casey"
        await settle { r.model.check.ok }
        r.model.submit()
        #expect(r.model.prompt == "How much do you weigh, Casey?")
    }

    @Test func tappingARowReopensItAndLaterAnswersAreKept() async {
        let r = rig(current: Fixtures.user())
        await type(r.model, "Casey")
        r.model.value = "casey.lifts"
        await settle { r.model.check.ok }
        r.model.submit()
        await type(r.model, "82")
        #expect(r.model.current?.key == "height")
        r.model.edit("name")
        #expect(r.model.current?.key == "name")
        #expect(r.model.value == "Casey")
        #expect(r.model.answers["weight"] == "82", "later answers stay")
        await type(r.model, "Casey")
        #expect(r.model.current?.key == "height", "resumes at the first unanswered question, skipping the answered ones")
    }

    @Test func theEmailCanBeReopenedAndKeepsItsText() async {
        let r = rig()
        r.model.beginEmail()
        await type(r.model, "casey@ore.app")
        await settle { r.model.current?.key == "password" }
        r.model.edit("email")
        #expect(r.model.current?.key == "email")
        #expect(r.model.value == "casey@ore.app")
    }

    @Test func unitSwitchClearsTheField() async {
        let r = rig(current: Fixtures.user())
        await type(r.model, "Casey")
        r.model.value = "casey.lifts"
        await settle { r.model.check.ok }
        r.model.submit()
        r.model.value = "180"
        r.model.setUnit("LB")
        #expect(r.model.value.isEmpty)
        #expect(r.model.units["weight"] == "LB")
        #expect(r.model.hint == "USED TO ESTIMATE CALORIE BURN")
    }

    // MARK: Setup, welcome, finishing

    @Test func lastAnswerSavesTheProfileThenShowsTheSetupLinesAndTheWelcome() async {
        let r = rig(current: Fixtures.user())
        await finishQuestions(r)
        await settle { r.model.stage == .welcome }
        #expect(r.model.stage == .welcome)
        #expect(r.model.welcomeTitle == "Welcome, Casey.")
        #expect(r.model.setupRows.map(\.text) == ["PROFILE SAVED", "BODY STATS SET", "PROGRAM SELECTED", "WEEK 1 SCHEDULED"])
        #expect(r.model.setupRows.map(\.right) == ["@casey.lifts", "82 KG · 180 CM", "PUSH / PULL / LEGS", "6 DAYS/WK"])
        #expect(r.remote.createdProfiles.count == 1)
        let p = r.remote.createdProfiles[0]
        #expect(p.handle == "casey.lifts" && p.displayName == "Casey")
        #expect(p.weightKg == 82 && p.heightCm == 180 && p.age == 31)
        #expect(p.gender == "other" && p.experienceLevel == "intermediate")
    }

    @Test func poundsAndFeetAreStoredAsKilosAndCentimetres() async {
        let r = rig(current: Fixtures.user())
        await type(r.model, "Casey")
        r.model.value = "casey.lifts"
        await settle { r.model.check.ok }
        r.model.submit()
        r.model.setUnit("LB"); await type(r.model, "180")
        r.model.setUnit("FT / IN"); await type(r.model, "5'10")
        await type(r.model, "29")
        r.model.choose(0); r.model.choose(2); r.model.choose(5)
        await settle { r.model.stage == .welcome }
        let p = r.remote.createdProfiles[0]
        #expect(abs(p.weightKg - 81.65) < 0.05)
        #expect(abs(p.heightCm - 177.8) < 0.05)
        #expect(p.unit == UnitPreference.lbs.rawValue)
        #expect(r.model.display(key: "height", value: "5'10") == "5'10\"")
    }

    @Test func aHandleTakenMeanwhileSendsYouBackToTheUsername() async {
        let r = rig(current: Fixtures.user())
        r.remote.beforeCreate = { $0.handles["casey.lifts"] = "someone-else" }
        await finishQuestions(r)
        await settle { r.model.stage == .console && r.model.current?.key == "username" }
        #expect(r.model.current?.key == "username")
        #expect(r.model.hint == "ALREADY TAKEN")
        #expect(r.model.hintIsBad)
        #expect(r.model.answers["weight"] == "82", "the other answers are kept")
    }

    @Test func aFailedProfileCallShowsTheErrorAndRetryWorks() async {
        let r = rig(current: Fixtures.user())
        r.remote.createError = ProfileRemoteError.offline
        await finishQuestions(r)
        await settle { r.model.setupError != nil }
        #expect(r.model.stage == .setup)
        #expect(r.model.setupError != nil)
        #expect(r.model.setupRows.isEmpty, "line 1 appears only once the profile is saved")
        r.remote.createError = nil
        r.model.retrySetup()
        await settle { r.model.stage == .welcome }
        #expect(r.model.stage == .welcome)
        #expect(r.model.setupError == nil)
    }
}
