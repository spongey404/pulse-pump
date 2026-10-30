import XCTest

/// Sign-in screen + the email sheet.
struct SignInPage {
    let t: UITestCase

    func openEmailSheet() {
        t.tapID(AX.auth.useEmail)
        t.require(t.el(AX.auth.emailField), "email field")
    }

    func signUp(email: String, password: String) {
        openEmailSheet()
        t.tapID(AX.auth.modeSignUp)
        submit(email: email, password: password)
    }

    func signIn(email: String, password: String) {
        openEmailSheet()
        t.tapID(AX.auth.modeSignIn)
        submit(email: email, password: password)
    }

    private func submit(email: String, password: String) {
        t.type(email, into: AX.auth.emailField)
        t.dismissKeyboard()          // the password field sits behind the keyboard while the email field is focused
        // A revealed password is a plain text field: no "Use Strong Password?" sheet covering the form.
        t.tapID(AX.auth.togglePassword)
        t.type(password, into: AX.auth.passwordField)
        t.tapID(AX.auth.submit)
    }
}

/// The nine onboarding steps. Each helper fills the step and presses CONTINUE.
struct OnboardingPage {
    let t: UITestCase

    func waitForStep(_ n: Int, of total: Int = 9) {
        t.waitForLabel(t.el(AX.onboarding.stepCounter), matching: "==", "STEP \(n) OF \(total)")
    }

    func next() { t.tapID(AX.onboarding.next) }

    func name(_ name: String) {
        waitForStep(1)
        t.type(name, into: AX.onboarding.nameField)
        next()
    }

    /// Types the handle and returns the availability line (uppercased by the UI).
    @discardableResult
    func typeHandle(_ handle: String, expecting message: String) -> String {
        waitForStep(2)
        t.replaceText(in: AX.onboarding.handleField, with: handle)   // the field is pre-filled from the name
        let status = t.el(AX.onboarding.handleStatus)
        t.waitForLabel(status, matching: "CONTAINS[c]", message)
        return status.label
    }

    func weight(_ text: String, lbs: Bool = false) {
        waitForStep(3)
        if lbs { t.tapID(AX.onboarding.unitLbs) }
        t.type(text, into: AX.onboarding.weightField)
        next()
    }

    func height(cm: String? = nil, feet: String? = nil, inches: String? = nil) {
        waitForStep(4)
        if let cm { t.type(cm, into: AX.onboarding.heightField) }
        if let feet { t.type(feet, into: AX.onboarding.heightImperial("FT")) }
        if let inches { t.type(inches, into: AX.onboarding.heightImperial("IN")) }
        next()
    }

    func age(_ text: String) {
        waitForStep(5)
        t.type(text, into: AX.onboarding.ageField)
        next()
    }

    func gender(_ displayName: String) {
        waitForStep(6)
        t.tapID(AX.onboarding.gender(displayName))
        next()
    }

    func experience(_ displayName: String) {
        waitForStep(7)
        t.tapID(AX.onboarding.experience(displayName))
        next()
    }

    func split(_ label: String) {
        waitForStep(8)
        t.tapID(AX.onboarding.split(label))
        next()
    }

    /// Last step: `showTutorial` picks "YES, SHOW ME AROUND" over skipping (experienced users get a single START button).
    /// The Supernova paywall follows onboarding (once): without the tutorial it appears straight after the last step, and
    /// `dismissPaywall` (the default) takes "TRAIN FREE →" so the test carries on from Home.
    func finish(showTutorial: Bool = false, dismissPaywall: Bool = true) {
        waitForStep(9)
        let yes = t.el(AX.onboarding.tutorialYes)
        if yes.waitForExistence(timeout: 2) {
            t.tap(showTutorial ? yes : t.el(AX.onboarding.tutorialSkip))
        } else {
            t.tapID(AX.onboarding.tutorialStart)
        }
        if dismissPaywall && !showTutorial { trainFree() }
    }

    func trainFree() {
        t.waitForPaywall()
        t.tapID(AX.supernova.free)
    }
}
