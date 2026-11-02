import XCTest

/// Saves screenshots of the workout logger in light and dark, free and member (`LOGGER_SHOTS=<dir>`).
final class LoggerShotsUITests: UITestCase {
    func testLoggerScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["LOGGER_SHOTS"] else { throw XCTSkip("set LOGGER_SHOTS to save screenshots") }
        for (mode, plus) in [("light", false), ("dark", false), ("light", true), ("dark", true)] {
            let tag = "\(mode)-\(plus ? "member" : "free")"
            var config = LaunchConfig(email: LaunchConfig.uniqueEmail("lg"), scenario: .busy, weeks: 4, plus: plus)
            config.extraArguments = ["-appTheme", mode]
            launch(config)
            func shot(_ n: String) {
                RunLoop.current.run(until: Date().addingTimeInterval(0.9))
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(n)-\(tag).png"))
            }
            HomePage(t: self).startPredictedWorkout()
            let w = WorkoutPage(t: self)
            shot("1-top")
            w.fillSet(1, weight: "100", reps: "8")
            shot("2-filled")
            w.logSet(1)
            w.waitForSetLogged(1)
            shot("3-logged")
            app.swipeUp()
            shot("4-scrolled")
            app.terminate()
        }
    }
}
