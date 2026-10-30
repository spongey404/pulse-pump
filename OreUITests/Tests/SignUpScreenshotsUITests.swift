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
        try shot("01-opening")

        let page = SignInPage(t: self)
        page.openEmail()
        try shot("02-email")
        let email = LaunchConfig.uniqueEmail("shots")
        type(email, into: AX.signup.input); try shot("03-email-filled")
        tapID(AX.signup.next)
        waitForLabel(el(AX.signup.number), matching: "CONTAINS[c]", "PASSWORD")
        type("pw", into: AX.signup.input); try shot("04-password-too-short")
        replaceText(in: AX.signup.input, with: LaunchConfig.defaultPassword); try shot("05-password-ok")
        tapID(AX.signup.next)
        Self.signedInEmail = email

        let o = OnboardingPage(t: self)
        o.waitFor("NAME"); try shot("06-name")
        type("Casey", into: AX.signup.input); try shot("07-name-filled")
        o.next()

        o.waitFor("USERNAME")
        replaceText(in: AX.signup.input, with: "ab"); try shot("08-username-too-short")
        replaceText(in: AX.signup.input, with: "frankie")
        waitForLabel(el(AX.signup.hint), matching: "CONTAINS[c]", "taken"); try shot("09-username-taken")
        replaceText(in: AX.signup.input, with: "c" + UUID().uuidString.prefix(6).lowercased())
        waitForLabel(el(AX.signup.hint), matching: "CONTAINS[c]", "Available"); try shot("10-username-available")
        o.next()

        o.waitFor("WEIGHT"); try shot("11-weight")
        type("82", into: AX.signup.input); try shot("12-weight-filled")
        o.next()
        o.waitFor("HEIGHT"); try shot("13-height")
        tapID(AX.signup.unit("FT / IN")); try shot("14-height-ft-in")
        tapID(AX.signup.unit("CM"))
        type("180", into: AX.signup.input); try shot("15-height-filled")
        o.next()
        o.waitFor("AGE"); try shot("16-age")
        type("31", into: AX.signup.input); try shot("17-age-filled")
        o.next()
        o.waitFor("GENDER"); try shot("18-gender")
        tapID(AX.signup.choice("Prefer not to say"))
        o.waitFor("EXPERIENCE"); try shot("19-experience")
        tapID(AX.signup.choice("Some experience"))
        o.waitFor("PROGRAM"); try shot("20-program")
        tapID(AX.signup.choice("Push / Pull / Legs"))
        try shot("21-setup", settle: 0.4)
        require(el(AX.signup.welcome), "welcome", timeout: 60)
        try shot("22-welcome", settle: 1)
        tap(el(AX.onboarding.tutorialSkip))
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        try shot("23-after-paywall-closes-notification-prompt", settle: 0.5)
        waitForPaywall()
        try shot("24-supernova-paywall", settle: 2)
        tapID(AX.supernova.free)
        require(el(AX.tab.home), "Home", timeout: 15)
        try shot("25-home-after-sign-up")
    }
}
