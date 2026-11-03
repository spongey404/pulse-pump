import XCTest

/// Screenshots of the Programs flow in the order of the design's 15 screens, light/free and dark/member (`PROGRAM_SHOTS=<dir>`, with
/// `TEST_RUNNER_PROGRAM_SHOTS` for the test host).
final class ProgramShotsUITests: UITestCase {
    func testProgramScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["PROGRAM_SHOTS"] else { throw XCTSkip("set PROGRAM_SHOTS to save screenshots") }
        for (mode, plus) in [("light", false), ("dark", true)] {
            let tag = "\(mode)-\(plus ? "member" : "free")"
            var config = LaunchConfig(email: LaunchConfig.uniqueEmail("pg"), scenario: .busy, weeks: 4, plus: plus)
            config.extraArguments = ["-appTheme", mode]
            launch(config)
            var n = 0
            func shot(_ name: String) {
                n += 1
                RunLoop.current.run(until: Date().addingTimeInterval(1.0))
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(String(format: "%02d", n))-\(name)-\(tag).png"))
            }
            let programs = ProgramsPage(t: self)
            programs.open()
            require(el(AX.programs.upNext), "UP NEXT")
            shot("programs-tab")

            // + → START FROM → a template fills the form.
            tapID(AX.programs.add)
            require(el(AX.programs.template("ppl")), "Start from")
            shot("start-from")
            tapID(AX.programs.template("ppl"))
            require(el(AX.programs.createName), "the form")
            shot("new-program-from-ppl")
            tapID(AX.nav.back); tapID(AX.nav.back)
            // Blank.
            tapID(AX.programs.add)
            tapID(AX.programs.template("blank"))
            shot("new-program-blank")
            type("Upper Body", into: AX.programs.createName)
            dismissKeyboard()
            tapID(AX.programs.createSave)
            require(el(AX.programs.editProgram), "the new program")
            shot("program-just-created")

            // The empty workout opens in edit mode; add exercises.
            tapID(AX.programs.workoutStart(0))
            require(el(AX.programs.workoutAddExercise), "edit mode")
            shot("empty-workout")
            tapID(AX.programs.workoutAddExercise)
            require(el(AX.programs.pickSearch), "add exercises")
            shot("add-exercises")
            tapID(AX.programs.pickRow("Bench Press"))
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            shot("choose-a-type")
            let adds = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'programs.pick.add.'"))
            if adds.count > 0 { adds.element(boundBy: 0).tap() }
            shot("choose-a-type-picked")
            tapID(AX.nav.back)
            type("row", into: AX.programs.pickSearch)
            shot("search")
            dismissKeyboard()
            tapID(AX.programs.pickDock)

            // Editing a workout: expand a row.
            require(el(AX.programs.workoutDone), "edit mode again")
            tap(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "REST")).firstMatch, "the exercise row")
            shot("workout-editing")
            tapID(AX.programs.workoutDone)
            shot("workout-read")
            tapID(AX.nav.back)

            // The program page and its edit form.
            shot("program-page")
            tapID(AX.programs.editProgram)
            shot("edit-program")
            tapID(AX.nav.back); tapID(AX.nav.back)
            shot("two-programs")

            // The seeded Push Pull Legs program: week strip, workouts with exercises, NEXT.
            tap(programs.row("Push Pull Legs"), "Push Pull Legs")
            shot("program-with-history")
            tapID(AX.programs.workoutRow(0))
            shot("workout-with-targets")
            tapID(AX.programs.workoutStartDock)
            require(el(AX.workout.sessionTitle), "the logger")
            shot("started")
            app.terminate()
        }
    }
}
