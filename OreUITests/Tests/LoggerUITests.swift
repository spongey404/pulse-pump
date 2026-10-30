import XCTest

/// The workout logger: adding an exercise in the middle of a workout without scrolling to the bottom (the + in
/// the header, pulling the list down to search), the set-type chip, the exercise number beside a wrapped name,
/// and the log circle. No emulator needed.
final class LoggerUITests: SeededUITestCase {

    private var exerciseCount: Int {
        app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.exercise.' AND identifier ENDSWITH '.name'")).count
    }

    private func startWorkout() {
        tap(AX.home.startWorkout)
        XCTAssertTrue(app.buttons[AX.workout.addExerciseTop].waitForExistence(timeout: 10), "logger opened")
    }

    private func pullListDown() {
        // A slow drag from the top of the list, held at the bottom: the rubber band stretches while the finger is down.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.5)
    }

    func testPullingTheListDownOpensSearchAndAnythingYouTypeIsMatchedAgainstYourWorkout() {
        startWorkout()
        let before = exerciseCount
        XCTAssertGreaterThan(before, 0, "a program workout starts with its exercises")

        pullListDown()
        let field = app.textFields[AX.workout.searchField]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "pulling the list down opens the search")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "the keyboard is already up, no tap on the bar needed")
        shot("s1-search-open")
        let lastName = app.staticTexts[AX.workout.exerciseName(before - 1)].label
        let word = lastName.split(separator: " ").last.map(String.init) ?? lastName   // any word of the name works
        app.typeText(word)   // straight into the focused field: nothing tapped first
        XCTAssertTrue(app.buttons[AX.workout.searchInWorkoutRow(lastName)].waitForExistence(timeout: 5),
                      "typing \"\(word)\" finds \(lastName), already in the workout")
        XCTAssertEqual(exerciseCount, before, "searching never adds anything")
    }

    /// The point of searching your own workout: the exercise you want next is far down, and typing its name
    /// takes you there.
    func testSearchJumpsToAnExerciseThatIsAlreadyFarDownTheWorkout() {
        startWorkout()
        let last = exerciseCount - 1
        XCTAssertGreaterThan(last, 2, "a long workout")
        let lastName = app.staticTexts[AX.workout.exerciseName(last)].label   // may be off screen; the label still reads
        let firstWord = lastName.split(separator: " ").first.map(String.init) ?? lastName

        pullListDown()
        let field = app.textFields[AX.workout.searchField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(firstWord)
        let jump = app.buttons[AX.workout.searchInWorkoutRow(lastName)]
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "it is listed under IN YOUR WORKOUT")
        shot("s4-in-workout")
        let before = exerciseCount
        jump.tap()
        waitUntil("the search to close") { !field.exists }
        shot("s5a-after-jump", settle: 2.5)

        // The exercise's name lands just below the header: visible, at the top, not scrolled past it.
        let name = app.staticTexts[AX.workout.exerciseName(last)]
        let header = app.staticTexts[AX.workout.sessionTitle]
        waitUntil("the list to scroll to \(lastName)") { name.frame.minY > header.frame.maxY - 2 && name.frame.minY < header.frame.maxY + 70 }
        shot("s5-after-jump")
        XCTAssertEqual(exerciseCount, before, "jumping does not add anything")
    }

    func testNothingMatchingShowsAHintAndAddingIsTheJobOfThePlus() {
        startWorkout()
        pullListDown()
        let field = app.textFields[AX.workout.searchField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("zzzzqq")
        XCTAssertTrue(app.staticTexts["NOTHING IN YOUR WORKOUT MATCHES"].waitForExistence(timeout: 3))
    }

    func testPlusInTheHeaderOpensTheFullListFromAnywhere() {
        startWorkout()
        app.buttons[AX.workout.addExerciseTop].tap()
        XCTAssertTrue(app.textFields[AX.picker.search].waitForExistence(timeout: 5), "the + opens the exercise list")
    }

    /// The set-type sheet picks a type when its row is tapped.
    func testSetTypeSheetPicksAWarmup() {
        startWorkout()
        app.buttons[AX.workout.setType(ex: 0, 1)].tap()
        let row = app.buttons[AX.workout.setTypeRow("Warmup")]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the sheet opened")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        row.tap()
        waitUntil("the sheet to close") { !row.exists }
    }

    // MARK: - The set row

    private func frame(_ id: String) -> CGRect { app.descendants(matching: .any)[id].firstMatch.frame }

    /// Choosing a type used to swap the dashed "+" for a narrower tag, so the row's columns jumped.
    func testPickingASetTypeKeepsTheChipAndTheRowWhereTheyWere() {
        startWorkout()
        let chip = AX.workout.setType(ex: 0, 1)
        XCTAssertTrue(app.buttons[chip].waitForExistence(timeout: 5))
        let before = (chip: frame(chip), number: frame(AX.workout.setNumber(ex: 0, 1)), weight: frame(AX.workout.setWeight(ex: 0, 1)))

        app.buttons[chip].tap()
        let row = app.buttons[AX.workout.setTypeRow("Warmup")]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        // Tap the empty right end of the row: the whole row takes the tap, not just its text.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        waitUntil("the sheet to close") { !row.exists }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        shot("c1-chip-after")

        let after = (chip: frame(chip), number: frame(AX.workout.setNumber(ex: 0, 1)), weight: frame(AX.workout.setWeight(ex: 0, 1)))
        XCTAssertEqual(after.chip.minX, before.chip.minX, accuracy: 1, "the tag starts where the dashed box started")
        XCTAssertEqual(after.chip.height, before.chip.height, accuracy: 1, "and is as tall")
        XCTAssertGreaterThanOrEqual(after.chip.width + 1, before.chip.width, "and is not narrower")
        XCTAssertLessThanOrEqual(after.chip.width, 37, "and fits the TYPE column")
        XCTAssertEqual(after.number.minX, before.number.minX, accuracy: 1, "the set number did not move")
        XCTAssertEqual(after.weight.minX, before.weight.minX, accuracy: 1, "the weight column did not move")
    }

    func testEveryTypeInTheSheetCanBePickedFromTheMiddleOfItsRow() {
        startWorkout()
        for name in ["Warmup", "Dropset", "AMRAP"] {
            app.buttons[AX.workout.setType(ex: 0, 1)].tap()
            let row = app.buttons[AX.workout.setTypeRow(name)]
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(name) is in the sheet")
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()
            waitUntil("the sheet to close after \(name)") { !row.exists }
        }
    }

    /// The unticked circle is only a 2pt ring: its middle used to ignore taps.
    func testTappingTheMiddleOfTheLogCircleLogsTheSet() {
        startWorkout()
        let check = app.buttons[AX.workout.setCheck(ex: 0, 1)]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertTrue(check.label.hasPrefix("Log set"))
        check.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the set to be logged") { check.label.hasPrefix("Set 1 done") }
    }

    // MARK: - The exercise header

    /// With a name that wraps to two lines the "01" used to hang at the first line; it stays beside the middle.
    func testTheExerciseNumberStaysCentredBesideAWrappedName() {
        startWorkout()
        let before = exerciseCount
        app.buttons[AX.workout.addExerciseTop].tap()
        let search = app.textFields[AX.picker.search]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("single arm overhead tricep")
        let row = app.descendants(matching: .any)[AX.picker.row("Single Arm Overhead Tricep Extension")].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        waitUntil("the exercise to be added") { self.exerciseCount == before + 1 }

        let i = before   // the new card is last
        let name = app.staticTexts[AX.workout.exerciseName(i)]
        let number = app.staticTexts[AX.workout.exerciseNumber(i)]
        // Scroll the new card into view if needed.
        for _ in 0..<4 where !name.isHittable { app.swipeUp() }
        XCTAssertTrue(name.waitForExistence(timeout: 5) && number.exists)
        shot("c2-wrapped-header")
        XCTAssertGreaterThan(name.frame.height, 28, "the name wraps to two lines")
        XCTAssertEqual(number.frame.midY, name.frame.midY, accuracy: 3, "the number sits beside the middle of the name")
    }

    // MARK: - Back to the top

    /// A tap on the clock, where iOS listens for "scroll to top". (The status bar is not in the app's
    /// accessibility tree on every device, so aim at the screen position.)
    private func tapStatusBar() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0)).withOffset(CGVector(dx: 0, dy: 22)).tap()
    }

    /// iOS lets you tap the status bar (the clock, the very top edge) to scroll the main list to its top.
    /// It is how you get back to where pulling down opens the search.
    func testTappingTheStatusBarScrollsTheListBackToTheTop() {
        startWorkout()
        let first = app.staticTexts[AX.workout.exerciseName(0)]
        let header = app.staticTexts[AX.workout.sessionTitle]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(first.isHittable, "scrolled well down the workout")
        shot("t1-scrolled-down")

        tapStatusBar()
        waitUntil("the list to be back at the top") { first.frame.minY > header.frame.maxY - 2 && first.frame.minY < header.frame.maxY + 40 }
        shot("t2-back-at-top")
    }
}
