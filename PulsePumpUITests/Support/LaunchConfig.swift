import Foundation

/// What a test wants the app to look like at launch. Everything maps onto the DEBUG launch arguments the app already
/// understands (`-useFirebaseEmulator`, `-debugEmail/-debugPassword/-debugAutoOnboard`, `-createDevData …`,
/// `-debugStartTab`, see CLAUDE.md "Dev data"), so the suite never needs a test-only code path in the app.
struct LaunchConfig {
    enum Scenario: String { case busy, lapsed, newUser = "new-user" }

    /// nil = launch signed out (manual sign-in tests): any session left by an earlier test is signed out first.
    var email: String?
    var password = LaunchConfig.defaultPassword
    /// Fill the onboarding form from launch arguments (name "Smoke Tester", PPL split).
    var autoOnboard = true
    /// Seed the dev dataset after onboarding (replaces the onboarding user with "Dev Lifter").
    var scenario: Scenario?
    var weeks = 8
    var seed = 42
    var lbs = false
    var plus = false
    var draft = false
    var startTab: Int?
    /// Launch with the tutorial coach marks enabled (-wantsTutorial).
    var tutorial = false
    var extraArguments: [String] = []
    /// Sign out a login left in the simulator keychain by an earlier test before anything else (`-debugFreshSession`).
    var freshSession = true

    static let defaultPassword = "pw123456"      // short on purpose: XCUITest types about one character per second

    /// A throw-away account name; the emulator keeps everything for the whole run, so every test gets its own.
    static func uniqueEmail(_ tag: String = "ui") -> String {
        "\(tag.prefix(1))\(UUID().uuidString.prefix(6).lowercased())@t.io"
    }

    var arguments: [String] {
        var a = ["-useFirebaseEmulator", "1", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let email { a += ["-debugEmail", email, "-debugPassword", password] }
        if email != nil, autoOnboard { a += ["-debugAutoOnboard", "1"] }
        if let scenario {
            a += ["-createDevData", "1", "-devDataReset", "1", "-devDataScenario", scenario.rawValue,
                  "-devDataWeeks", "\(weeks)", "-devDataSeed", "\(seed)", "-devDataUnits", lbs ? "lb" : "kg"]
            if plus { a += ["-devDataPlus", "1"] }
            if draft { a += ["-devDataDraft", "1"] }
        }
        if freshSession { a += ["-debugFreshSession", "1"] }
        if let startTab { a += ["-debugStartTab", "\(startTab)"] }
        if tutorial { a += ["-wantsTutorial", "1"] }
        return a + extraArguments
    }

    /// The same launch after the seed already ran: keeps the identity, drops the seeding flags so a relaunch
    /// (terminate + launch) resumes what is on disk instead of rebuilding it.
    var relaunch: LaunchConfig {
        var c = self
        c.scenario = nil
        c.autoOnboard = false
        c.freshSession = false
        return c
    }
}
