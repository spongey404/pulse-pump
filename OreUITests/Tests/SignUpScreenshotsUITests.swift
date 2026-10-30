import XCTest

/// Not a regression test: walks the sign-up and onboarding screens and saves a PNG of each into the folder named by
/// `SIGNUP_SHOTS` (`TEST_RUNNER_SIGNUP_SHOTS` for xcodebuild), for design review. Skipped when the variable is unset.
final class SignUpScreenshotsUITests: UITestCase {
    private func shot(_ name: String, settle: TimeInterval = 0.8) throws {
        let dir = try XCTUnwrap(ProcessInfo.processInfo.environment["SIGNUP_SHOTS"])
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func testCaptureSignUpAndOnboardingScreens() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["SIGNUP_SHOTS"] == nil, "set SIGNUP_SHOTS to a folder to capture screens")
        launch(LaunchConfig(email: nil))
        try shot("01-sign-in")

        let signIn = SignInPage(t: self)
        signIn.openEmailSheet()
        try shot("02-email-sheet-sign-in")
        tapID(AX.auth.modeSignUp)
        try shot("03-email-sheet-sign-up")
        let email = LaunchConfig.uniqueEmail("shots")
        type(email, into: AX.auth.emailField)
        dismissKeyboard()
        tapID(AX.auth.togglePassword)
        type(LaunchConfig.defaultPassword, into: AX.auth.passwordField)
        try shot("04-email-sheet-filled")
        tapID(AX.auth.submit)
        Self.signedInEmail = email

        let o = OnboardingPage(t: self)
        o.waitForStep(1); try shot("05-onboarding-1-name")
        type("Casey", into: AX.onboarding.nameField)
        try shot("06-onboarding-1-name-filled")
        o.next()

        o.waitForStep(2)
        replaceText(in: AX.onboarding.handleField, with: "ab")
        try shot("07-onboarding-2-handle-too-short")
        replaceText(in: AX.onboarding.handleField, with: "frankie")
        try shot("08-onboarding-2-handle-taken")
        replaceText(in: AX.onboarding.handleField, with: "c" + UUID().uuidString.prefix(6).lowercased())
        waitForLabel(el(AX.onboarding.handleStatus), matching: "CONTAINS[c]", "Available")
        try shot("09-onboarding-2-handle-available")
        o.next()

        o.waitForStep(3); try shot("10-onboarding-3-weight")
        type("82", into: AX.onboarding.weightField); try shot("11-onboarding-3-weight-filled")
        o.next()
        o.waitForStep(4); try shot("12-onboarding-4-height")
        type("180", into: AX.onboarding.heightField); try shot("13-onboarding-4-height-filled")
        o.next()
        o.waitForStep(5); try shot("14-onboarding-5-age")
        type("31", into: AX.onboarding.ageField); try shot("15-onboarding-5-age-filled")
        o.next()
        o.waitForStep(6); try shot("16-onboarding-6-gender")
        tapID(AX.onboarding.gender("Prefer not to say")); try shot("17-onboarding-6-gender-picked")
        o.next()
        o.waitForStep(7); try shot("18-onboarding-7-experience")
        tapID(AX.onboarding.experience("Some experience")); try shot("19-onboarding-7-experience-picked")
        o.next()
        o.waitForStep(8); try shot("20-onboarding-8-split")
        tapID(AX.onboarding.split("Push / Pull / Legs")); try shot("21-onboarding-8-split-picked")
        o.next()
        o.waitForStep(9); try shot("22-onboarding-9-tutorial-prompt")
        tap(el(AX.onboarding.tutorialSkip))
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        try shot("23-notification-prompt-over-paywall", settle: 0.5)
        waitForPaywall()
        try shot("24-supernova-paywall", settle: 2)
        tapID(AX.supernova.free)
        require(el(AX.tab.home), "Home", timeout: 15)
        try shot("25-home-after-sign-up")
    }
}
