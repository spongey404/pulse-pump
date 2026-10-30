import XCTest

/// Account creation, onboarding and returning-user sign-in against the Firebase Auth/Firestore emulators.
final class AuthOnboardingUITests: UITestCase {

    func testNewUserSignsUpWithEmailAndCompletesOnboardingToHome() {
        let email = LaunchConfig.uniqueEmail("signup")
        launch(LaunchConfig(email: nil))
        SignInPage(t: self).signUp(email: email, password: LaunchConfig.defaultPassword)
        Self.signedInEmail = email

        let onboarding = OnboardingPage(t: self)
        onboarding.name("Casey")
        onboarding.typeHandle("c" + UUID().uuidString.prefix(6).lowercased(), expecting: "Available")
        onboarding.next()
        onboarding.weight("82")
        onboarding.height(cm: "180")
        onboarding.age("31")
        onboarding.gender("Prefer not to say")
        onboarding.experience("Some experience")
        onboarding.split("Push / Pull / Legs")
        onboarding.finish()

        require(el(AX.tab.home), "Home tab after onboarding", timeout: 30)
        let home = HomePage(t: self)
        require(el(AX.home.profileButton), "Home screen")
        XCTAssertEqual(home.streak, 0, "A brand-new account has no streak")
        XCTAssertFalse(home.hasRecentTable, "A brand-new account has no recent workouts")
    }

    func testThePaywallFollowsOnboardingOnceAndTrainFreeGoesStraightToHome() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("paywall"), autoOnboard: false))
        let onboarding = OnboardingPage(t: self)
        onboarding.name("Paige")
        onboarding.typeHandle("p" + UUID().uuidString.prefix(6).lowercased(), expecting: "Available")
        onboarding.next()
        onboarding.weight("70")
        onboarding.height(cm: "170")
        onboarding.age("28")
        onboarding.gender("Prefer not to say")
        onboarding.experience("Some experience")
        onboarding.split("Push / Pull / Legs")
        onboarding.finish(dismissPaywall: false)

        waitForPaywall()
        XCTAssertTrue(app.staticTexts["ORE · SUPERNOVA MEMBERSHIP"].exists)
        XCTAssertTrue(app.staticTexts["Smart weight suggestions"].exists, "the feature list")
        XCTAssertTrue(app.buttons[AX.supernova.start].label.contains("START 3 MONTHS FREE"))
        XCTAssertTrue(app.staticTexts["Logging, PRs and body map stay free."].exists, "the free strip")
        XCTAssertTrue(app.otherElements["Supernova"].exists || app.staticTexts["Supernova"].exists, "VoiceOver reads the wordmark as Supernova, with no asterisk")

        tapID(AX.supernova.free)
        require(el(AX.tab.home), "Home after TRAIN FREE", timeout: 15)
        XCTAssertFalse(el(AX.supernova.start).exists, "no confirm dialog, no second paywall")

        // Once means once: relaunching does not bring it back.
        relaunchKeepingAccount()
        require(el(AX.tab.home), "Home after relaunch", timeout: 30)
        XCTAssertFalse(el(AX.supernova.start).waitForExistence(timeout: 4), "the paywall is shown once")
    }

    func testHandleStepReportsInvalidTakenAndAvailableUsernames() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("handle"), autoOnboard: false))
        let onboarding = OnboardingPage(t: self)
        onboarding.name("Hana")

        let field = AX.onboarding.handleField
        onboarding.waitForStep(2)
        replaceText(in: field, with: "ab")
        waitForLabel(el(AX.onboarding.handleStatus), matching: "CONTAINS[c]", "3")          // "at least 3 characters"
        XCTAssertFalse(el(AX.onboarding.next).isEnabled, "CONTINUE must stay disabled for an invalid handle")

        replaceText(in: field, with: "frankie")                                                // seeded by firebase/seed
        waitForLabel(el(AX.onboarding.handleStatus), matching: "CONTAINS[c]", "taken")
        XCTAssertFalse(el(AX.onboarding.next).isEnabled, "CONTINUE must stay disabled for a taken handle")

        replaceText(in: field, with: "f" + UUID().uuidString.prefix(6).lowercased())
        waitForLabel(el(AX.onboarding.handleStatus), matching: "CONTAINS[c]", "Available")
        XCTAssertTrue(el(AX.onboarding.next).isEnabled, "CONTINUE enables once the handle is available")
    }

    func testLbsUserOnboardingUsesImperialHeightAndShowsPoundsInSettings() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("lbs"), autoOnboard: false))
        let onboarding = OnboardingPage(t: self)
        onboarding.name("Pat")
        onboarding.typeHandle("l" + UUID().uuidString.prefix(6).lowercased(), expecting: "Available")
        onboarding.next()
        onboarding.weight("180", lbs: true)
        onboarding.height(feet: "5", inches: "10")
        onboarding.age("29")
        onboarding.gender("Male")
        onboarding.experience("Advanced lifter")
        onboarding.split("Full Body")
        onboarding.finish()                                  // advanced lifters get a single START TRAINING button

        require(el(AX.tab.home), "Home tab", timeout: 30)
        TabBar(t: self).more()
        tapID(AX.row("Settings"))
        waitForLabel(el(AX.menu("Weight Unit")), matching: "CONTAINS[c]", "lbs")
    }

    func testReturningUserSignsBackInAndLandsOnHomeWithTheirData() {
        let email = LaunchConfig.uniqueEmail("return")
        launch(LaunchConfig(email: email, scenario: .busy, weeks: 4))
        let streakBefore = HomePage(t: self).streak
        XCTAssertGreaterThan(streakBefore, 0, "Seeded busy user has a streak")

        // Relaunch without the auto sign-in arguments, so signing out lands on the sign-in screen and stays there.
        relaunch(with: LaunchConfig(email: nil))
        require(el(AX.tab.home), "Home after relaunch (login and data persist on disk)")
        signOutFromHome()
        require(el(AX.auth.useEmail), "sign-in screen after sign-out")
        SignInPage(t: self).signIn(email: email, password: LaunchConfig.defaultPassword)
        Self.signedInEmail = email

        // Returning users skip onboarding; their data is pulled from the cloud.
        require(el(AX.tab.home), "Home tab after sign-in", timeout: 60)
        XCTAssertFalse(el(AX.onboarding.next).exists, "A returning user must not see onboarding")
        require(el(AX.home.kpiStreak), "KPI tiles")
    }

    func testWrongPasswordShowsErrorAndStaysOnSignIn() {
        launch(LaunchConfig(email: nil))
        SignInPage(t: self).signIn(email: LaunchConfig.uniqueEmail("nobody"), password: "definitely-wrong-1")
        require(el(AX.auth.emailError), "inline sign-in error")
        XCTAssertFalse(el(AX.tab.home).exists)
    }
}
