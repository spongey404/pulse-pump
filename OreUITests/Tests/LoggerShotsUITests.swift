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
            // The plate calculator: a barbell exercise's next set shows PLATES under it; the toggle opens the bar diagram.
            var cards = 0
            while el(AX.workout.exerciseName(cards)).exists { cards += 1 }
            w.addExerciseViaPicker(search: "Barbell Bench Press", pick: "Barbell Bench Press")
            w.fillSet(ex: cards, 1, weight: "100", reps: "8")
            w.closeNumberPad()
            let toggle = el(AX.workout.platesToggle(ex: cards, 1))
            scrollTo(toggle)
            tapID(AX.workout.platesToggle(ex: cards, 1))
            shot("5-plates")
            app.terminate()
        }
    }

    /// Every set type on its own row: the type sheet, then each type picked, filled in and logged, so the shots show what the
    /// tag, the row and the logged state look like for Warm-up, Superset, Drop, Rest-pause, AMRAP, Failure and Unilateral.
    func testSetTypeScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["LOGGER_SHOTS"] else { throw XCTSkip("set LOGGER_SHOTS to save screenshots") }
        let types: [(row: String, slug: String)] = [("Warmup", "warmup"), ("Superset", "superset"), ("Dropset", "dropset"), ("Rest-Pause", "rest-pause"),
                                                    ("AMRAP", "amrap"), ("To Failure", "failure"), ("Unilateral", "unilateral")]
        for (mode, plus) in [("light", false), ("dark", false), ("light", true), ("dark", true)] {
            let tag = "\(mode)-\(plus ? "member" : "free")"
            var config = LaunchConfig(email: LaunchConfig.uniqueEmail("st"), scenario: .busy, weeks: 4, plus: plus)
            config.extraArguments = ["-appTheme", mode]
            launch(config)
            var n = 10
            func shot(_ name: String) {
                n += 1
                RunLoop.current.run(until: Date().addingTimeInterval(0.9))
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(n)-\(name)-\(tag).png"))
            }
            HomePage(t: self).startPredictedWorkout()
            let w = WorkoutPage(t: self)
            require(el(AX.workout.setType(ex: 0, 1)), "set 1 type chip")
            shot("set-types-none")

            // The sheet itself.
            app.buttons[AX.workout.setType(ex: 0, 1)].tap()
            require(el(AX.workout.setTypeRow("Warmup")), "the set type sheet")
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            shot("set-type-sheet")
            app.buttons[AX.workout.setTypeRow("Standard")].coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()

            for (i, t) in types.enumerated() {
                let set = i + 1
                while !el(AX.workout.setType(ex: 0, set)).exists { w.addSet() }
                scrollTo(el(AX.workout.setType(ex: 0, set)))
                app.buttons[AX.workout.setType(ex: 0, set)].tap()
                let row = app.buttons[AX.workout.setTypeRow(t.row)]
                require(row, "\(t.row) in the sheet")
                RunLoop.current.run(until: Date().addingTimeInterval(0.8))
                row.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()
                waitUntilGone(row, "the sheet after \(t.row)")
                w.fillSet(set, weight: "60", reps: "10")
                w.closeNumberPad()
                shot("type-\(t.slug)")
                w.logSet(set)
                w.waitForSetLogged(set)
                shot("type-\(t.slug)-logged")
            }
            app.terminate()
        }
    }
}
