import XCTest

extension UITestCase {
    /// Launches the app for `config` and returns once the app is in the state the config implies:
    ///   * email + autoOnboard  -> the main tab shell (Home) is showing
    ///   * email, no autoOnboard -> whatever screen the account leads to (onboarding or Home); the caller drives it
    ///   * no email              -> the sign-in screen
    /// A session left behind by an earlier test (the simulator keeps the Firebase login in its keychain) is signed
    /// out through the UI first when it belongs to another account.
    @discardableResult
    func launch(_ config: LaunchConfig, file: StaticString = #filePath, line: UInt = #line) -> LaunchConfig {
        currentConfig = config
        app.launchArguments = config.arguments
        app.launch()
        settle(config, file: file, line: line)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "State after launch"
        shot.lifetime = .keepAlways
        add(shot)
        return config
    }

    /// Kill the app (like a swipe-up in the app switcher) and start it again with the same account but without
    /// re-seeding. Used by the draft / persistence tests.
    func relaunchKeepingAccount(file: StaticString = #filePath, line: UInt = #line) {
        app.terminate()
        let again = currentConfig.relaunch
        currentConfig = again
        app.launchArguments = again.arguments
        app.launch()
        settle(again, file: file, line: line)
    }

    /// Terminate and launch again with a different argument set but the same on-disk login and data
    /// (e.g. without the auto sign-in arguments, so the test can drive the sign-in screen by hand).
    func relaunch(with config: LaunchConfig, file: StaticString = #filePath, line: UInt = #line) {
        app.terminate()
        var c = config
        c.freshSession = false
        currentConfig = c
        app.launchArguments = c.arguments
        app.launch()
    }

    // MARK: -

    /// Which screen the launch settled on.
    private enum Landing { case main, signIn, onboarding, none }

    private func landing(timeout: TimeInterval) -> Landing {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if el(AX.tab.home).exists { return .main }
            if el(AX.auth.useEmail).exists { return .signIn }
            if el(AX.onboarding.next).exists { return .onboarding }
            // Cheap poll granularity; XCUITest queries already block until the app is idle.
            _ = el(AX.tab.home).waitForExistence(timeout: 0.5)
        }
        return .none
    }

    private func settle(_ config: LaunchConfig, file: StaticString, line: UInt) {
        let state = landing(timeout: 45)
        // Stale sessions are signed out by the app itself (-debugFreshSession), so no UI clean-up is needed here.
        _ = state
        switch (config.email, state) {
        case (nil, .signIn):
            Self.signedInEmail = nil
        case (nil, _):
            XCTFail("Expected the sign-in screen after sign-out, got \(state)", file: file, line: line)
        case (.some(let email), .main):
            Self.signedInEmail = email
            if config.scenario != nil { waitForSeed(config, file: file, line: line) }
        case (.some(let email), .onboarding):
            Self.signedInEmail = email      // the account exists now; the test drives (or finishes) onboarding
        case (.some, .signIn):
            // Auto sign-in did not run (or failed): surface it instead of letting later steps time out confusingly.
            XCTFail("Auto sign-in against the emulator did not complete — are the Firebase emulators running (bin/test-ui.sh)?",
                    file: file, line: line)
        case (.some, .none):
            XCTFail("App did not reach sign-in, onboarding or Home within 45s", file: file, line: line)
        }
    }

    /// The dev-data seeder runs after Home first renders; wait for what the scenario promises so tests start on data.
    private func waitForSeed(_ config: LaunchConfig, file: StaticString, line: UInt) {
        switch config.scenario {
        case .busy?, .lapsed?:
            // The 'recent workouts' table only exists once workouts do.
            require(el(AX.home.recent), "seeded recent-workouts table", timeout: 60, file: file, line: line)
        case .newUser?:
            // New-user data has a split but no workouts: the prediction card appears once templates exist.
            require(el(AX.home.predictedName), "seeded prediction card", timeout: 60, file: file, line: line)
        case nil:
            break
        }
    }

    /// Home profile menu → SIGN OUT.
    func signOutFromHome(file: StaticString = #filePath, line: UInt = #line) {
        tap(el(AX.tab.home), "Home tab", file: file, line: line)
        tap(el(AX.home.profileButton), "profile button", file: file, line: line)
        tap(el(AX.home.signOut), "SIGN OUT", file: file, line: line)
        Self.signedInEmail = nil
    }
}
