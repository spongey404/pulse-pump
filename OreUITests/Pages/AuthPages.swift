import XCTest

/// The opening screen of the sign-up console and its email questions.
struct SignInPage {
    let t: UITestCase

    func openEmail() {
        t.tapID(AX.auth.useEmail)
        t.require(t.el(AX.signup.input), "email question")
    }

    /// Types into the open question and presses CONTINUE.
    func answer(_ text: String) {
        t.type(text, into: AX.signup.input)
        t.tapID(AX.signup.next)
    }

    /// New account: email, then a password (the account is created there). The caller carries on with the name question.
    func signUp(email: String, password: String) {
        openEmail()
        answer(email)
        t.waitForLabel(t.el(AX.signup.number), matching: "CONTAINS[c]", "PASSWORD")
        answer(password)
    }

    /// Existing account: email, then its password. The console learns the email has an account either at the email step
    /// or when creating it fails, in which case it asks again, so the password is typed a second time if needed.
    func signIn(email: String, password: String) {
        openEmail()
        answer(email)
        t.waitForLabel(t.el(AX.signup.number), matching: "CONTAINS[c]", "PASSWORD")
        let knew = t.el(AX.signup.forgot).waitForExistence(timeout: 3)
        answer(password)
        if !knew, t.el(AX.signup.forgot).waitForExistence(timeout: 5), !t.el(AX.auth.emailError).exists { answer(password) }
    }
}

/// The sign-up console's questions. Each helper waits for its question, fills it and presses CONTINUE (choices advance on tap).
struct OnboardingPage {
    let t: UITestCase

    /// Waits for the question whose number line ends with `label` ("NAME", "USERNAME", …).
    func waitFor(_ label: String) {
        t.waitForLabel(t.el(AX.signup.number), matching: "CONTAINS[c]", "/ \(label)")
    }

    func next() { t.tapID(AX.signup.next) }

    func name(_ name: String) {
        waitFor("NAME")
        t.replaceText(in: AX.signup.input, with: name)   // pre-filled from Apple / Google
        next()
    }

    /// Types the handle and returns the availability line (uppercased by the UI).
    @discardableResult
    func typeHandle(_ handle: String, expecting message: String) -> String {
        waitFor("USERNAME")
        t.replaceText(in: AX.signup.input, with: handle)
        let status = t.el(AX.signup.hint)
        t.waitForLabel(status, matching: "CONTAINS[c]", message)
        return status.label
    }

    func weight(_ text: String, lbs: Bool = false) {
        waitFor("WEIGHT")
        if lbs { t.tapID(AX.signup.unit("LB")) }
        t.type(text, into: AX.signup.input)
        next()
    }

    func height(cm: String? = nil, feet: String? = nil, inches: String? = nil) {
        waitFor("HEIGHT")
        if let cm {
            t.type(cm, into: AX.signup.input)
        } else if let feet {
            t.tapID(AX.signup.unit("FT / IN"))
            t.type("\(feet)'\(inches ?? "0")", into: AX.signup.input)
        }
        next()
    }

    func age(_ text: String) {
        waitFor("AGE")
        t.type(text, into: AX.signup.input)
        next()
    }

    func gender(_ displayName: String) { waitFor("GENDER"); t.tapID(AX.signup.choice(displayName)) }
    func experience(_ displayName: String) { waitFor("EXPERIENCE"); t.tapID(AX.signup.choice(displayName)) }
    func split(_ label: String) { waitFor("PROGRAM"); t.tapID(AX.signup.choice(label)) }

    /// The welcome: `showTutorial` picks "YES, SHOW ME AROUND" over skipping. The Supernova paywall follows (once):
    /// without the tutorial it appears straight after, and `dismissPaywall` (the default) takes "TRAIN FREE →" so the
    /// test carries on from Home.
    func finish(showTutorial: Bool = false, dismissPaywall: Bool = true) {
        t.require(t.el(AX.signup.welcome), "welcome", timeout: 60)
        t.tap(t.el(showTutorial ? AX.onboarding.tutorialYes : AX.onboarding.tutorialSkip))
        if dismissPaywall && !showTutorial { trainFree() }
    }

    func trainFree() {
        t.waitForPaywall()
        t.tapID(AX.supernova.free)
    }
}
