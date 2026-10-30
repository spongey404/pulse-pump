import XCTest

/// Base class for tests that need an app with the dev dataset (by default "new-user": presets, no history) and no
/// emulators. It seeds in one launch and relaunches, because killing the app right after seeding can cut the
/// save short and leave Home without its user (and so without the START WORKOUT dock); then it seeds once more.
class SeededUITestCase: XCTestCase {
    let app = XCUIApplication()
    /// Where `shot(_:)` writes screenshots when TUTORIAL_SHOTS is set (manual visual review).
    let shotDir = ProcessInfo.processInfo.environment["TUTORIAL_SHOTS"]

    /// Launch the second time with the tutorial switched on.
    var tutorialOn: Bool { false }
    /// The dev dataset to seed: "new-user" (presets, no history) or "busy" (months of sessions).
    var scenario: String { "new-user" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow", "OK", "Not Now", "Don’t Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        for attempt in 1...2 {
            seedDevData()
            var config = seedConfig.relaunch
            config.tutorial = tutorialOn
            app.launchArguments = config.arguments + (tutorialOn ? [] : ["-wantsTutorial", "0"])
            app.launch()
            // The notification prompt appears on first launch and would swallow the first taps.
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
            if allow.waitForExistence(timeout: 4) { allow.tap() }
            if app.descendants(matching: .any)[AX.home.startWorkout].waitForExistence(timeout: 15) { return }
            if attempt == 2 { XCTFail("Home has no START WORKOUT dock after seeding") }
            app.terminate()
        }
    }

    /// Every test gets its own account on the Firebase emulator (run through bin/test-ui.sh), so a test never
    /// touches, or signs out, whatever login the developer has in this simulator.
    private lazy var seedConfig = LaunchConfig(
        email: LaunchConfig.uniqueEmail("s"),
        scenario: LaunchConfig.Scenario(rawValue: scenario),
        weeks: scenario == "busy" ? 16 : 8)

    private func seedDevData() {
        app.launchArguments = seedConfig.arguments
        app.launch()
        XCTAssertTrue(app.buttons[AX.tab.home].waitForExistence(timeout: 30), "seeded app reaches Home")
        // The seeded programs show up as the predicted workout: the seeder is done. (Which day is predicted
        // depends on the weekday.)
        let predicted = app.staticTexts.matching(NSPredicate(format: "label MATCHES '(PUSH|PULL|LEG) DAY'")).firstMatch
        XCTAssertTrue(predicted.waitForExistence(timeout: 30), "seeded programs")
        RunLoop.current.run(until: Date().addingTimeInterval(3))   // let the store save before the app is killed
        app.terminate()
    }

    // MARK: Helpers

    /// Lets animations reach a stable frame before a screenshot.
    func shot(_ name: String, settle: TimeInterval = 0.8) {
        guard let dir = shotDir else { return }
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func tap(_ id: String, at v: CGVector = CGVector(dx: 0.5, dy: 0.5), file: StaticString = #filePath, line: UInt = #line) {
        let e = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 10), "\(id) exists", file: file, line: line)
        e.coordinate(withNormalizedOffset: v).tap()
    }

    /// Polls until `condition` holds (UI that settles after a scroll or animation has no element to wait on).
    func waitUntil(_ what: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line,
                   _ condition: () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > end { return XCTFail("timed out waiting for \(what)", file: file, line: line) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }
}
