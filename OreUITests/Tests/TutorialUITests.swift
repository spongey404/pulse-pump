import XCTest

/// The interactive tutorial on the real screens. Needs no emulator: it seeds the dev dataset
/// ("new-user" scenario) and relaunches with `-wantsTutorial 1`.
final class TutorialUITests: SeededUITestCase {
    override var tutorialOn: Bool { true }

    private var cardTitle: String { app.staticTexts[AX.tutorial.card].firstMatch.label }

    private func waitForCard(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let t = app.staticTexts[AX.tutorial.card].firstMatch
        let p = NSPredicate(format: "label == %@", title)
        let ex = XCTNSPredicateExpectation(predicate: p, object: t)
        XCTAssertEqual(XCTWaiter().wait(for: [ex], timeout: 14), .completed, "card reads “\(title)”, was “\(cardTitle)”",
                       file: file, line: line)
    }

    // MARK: Helpers

    private func pullDownFromTheTopOfTheList() {
        let header = app.staticTexts[AX.workout.exerciseName(0)].frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 200, dy: header.midY))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 200, dy: header.midY + 380)),
                   withVelocity: .default, thenHoldForDuration: 0.5)
    }

    private var exerciseCount: Int {
        app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.exercise.' AND identifier ENDSWITH '.name'")).count
    }

    // MARK: Tests

    func testWalkthroughFromStartToDiscard() {
        waitForCard("Start a workout")
        shot("01-start")

        // Outside the spotlight nothing reacts: the Programs tab must not open.
        tap(AX.tab.programs)
        RunLoop.current.run(until: Date().addingTimeInterval(1))   // a negative check: give a wrong reaction time to show
        XCTAssertEqual(cardTitle, "Start a workout")
        XCTAssertTrue(app.descendants(matching: .any)[AX.home.startWorkout].exists, "still on Home")

        tap(AX.home.startWorkout)
        for i in 1...3 { shot("02p\(i)-start-transition", settle: 0) }   // frames while the logger slides up
        waitForCard("Add an exercise")
        XCTAssertGreaterThanOrEqual(exerciseCount, 6, "the practice workout is long, like a real session")
        let before = exerciseCount
        shot("02-add-exercise")

        // The + at the top: no scrolling to the bottom of a six-exercise list.
        app.buttons[AX.workout.addExerciseTop].tap()
        waitForCard("Pick a lift")
        shot("03-pick-lift")
        tap(AX.picker.row("Bench Press"))
        waitForCard("Choose a variant")
        shot("04-variant")
        let add = app.buttons["ADD"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the exercise to be added") { self.exerciseCount == before + 1 }

        // RIR is switched on first, so the numbers the tutorial types include it.
        waitForCard("Reps in reserve")
        shot("05-rir")
        app.buttons[AX.workout.exerciseMenu(0)].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitForCard("Turn RIR on")
        shot("05a-rir-row")
        app.buttons[AX.workout.menuRow("RIR column")].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // The tutorial types weight, reps and RIR itself, then walks through the plates.
        waitForCard("Enter your numbers")
        shot("05b-enter")
        waitForCard("Plate calculator")
        XCTAssertEqual(app.descendants(matching: .any)[AX.workout.setWeight(ex: 0, 1)].firstMatch.label, "60", "weight was typed in for the user")
        XCTAssertEqual(app.descendants(matching: .any)[AX.workout.setRIR(ex: 0, 1)].firstMatch.label, "2", "and so was the RIR, since the column is on")
        shot("05c-plates")
        app.buttons[AX.workout.platesToggle(ex: 0, 1)].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        waitForCard("Set types")
        shot("05d-set-types")
        app.buttons[AX.workout.setType(ex: 0, 1)].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        waitForCard("Mark a warm-up")
        let warmup = app.buttons[AX.workout.setTypeRow("Warmup")]
        XCTAssertTrue(warmup.waitForExistence(timeout: 5))
        warmup.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5)).tap()

        waitForCard("Log the set")
        shot("06-log")
        let check = app.buttons[AX.workout.setCheck(ex: 0, 1)]
        check.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitForCard("Swipe to delete")
        shot("07-swipe")
        // The row is wider than the circle: start 1.5 circles to its left, drag 7 circles left.
        check.coordinate(withNormalizedOffset: CGVector(dx: -1.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: check.coordinate(withNormalizedOffset: CGVector(dx: -7, dy: 0.5)))

        // Search: the next exercise is far down, so find it instead of scrolling.
        waitForCard("Search your workout")
        shot("08-search-pull")
        // Only a drag counts here: a tap on a control inside the spotlight does nothing.
        app.buttons[AX.workout.exerciseMenu(0)].tap()
        XCTAssertFalse(app.buttons[AX.workout.menuRow("RIR column")].waitForExistence(timeout: 1.5), "a tap inside the pull zone is ignored")
        pullDownFromTheTopOfTheList()

        // No tap on the bar: the tutorial keeps the keyboard away and types the word as soon as the panel opens.
        waitForCard("Type to find it")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "the tutorial shows no keyboard")
        shot("08b-typing-row")
        waitForCard("Jump to it")
        let jump = app.buttons[AX.workout.searchInWorkoutRow("Barbell Row")]
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "Barbell Row is listed under IN YOUR WORKOUT")
        shot("08c-search-results")
        jump.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)).tap()

        waitForCard("Log it, no scrolling")
        shot("09-log-next")
        let rowName = app.staticTexts[AX.workout.exerciseName(4)]
        XCTAssertLessThan(rowName.frame.minY, app.windows.firstMatch.frame.height * 0.5, "the list jumped to Barbell Row")
        XCTAssertEqual(app.descendants(matching: .any)[AX.workout.setWeight(ex: 4, 1)].firstMatch.label, "40", "its set was filled in")
        app.buttons[AX.workout.setCheck(ex: 4, 1)].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Back to the top: iOS scrolls the list up when the status bar (the clock) is tapped.
        waitForCard("Back to the top")
        shot("10-scroll-top")
        let first = app.staticTexts[AX.workout.exerciseName(0)]
        XCTAssertFalse(first.isHittable, "the list is still down at Barbell Row")
        // The status bar is not in the app's accessibility tree on every device, so aim at the clock's position.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0)).withOffset(CGVector(dx: 0, dy: 22)).tap()
        // (Back at the top: the first exercise's name is below the header again. The tutorial's next card may sit
        // on top of it, so look at where it is, not whether it can be tapped.)
        waitUntil("the list to come back to the top") { first.frame.minY > 60 }

        waitForCard("Leave a workout")
        shot("11-leave")

        // A tap a few points outside the arrow used to count (the spotlight was grown to 44pt) while the app
        // ignored it, which left the tutorial on a Discard step with no modal. Now it is swallowed.
        // The arrow's accessibility frame is just its glyph, so aim by absolute position: the real button runs
        // from x 14 to 42, and the old grown spotlight reached x 50.
        let arrow = app.buttons[AX.workout.cancel].frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 48, dy: arrow.midY)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        XCTAssertEqual(cardTitle, "Leave a workout", "a tap outside the control leaves the step where it was")
        XCTAssertFalse(app.descendants(matching: .any)[AX.modal.primary].exists, "and no modal opened")

        tap(AX.workout.cancel)
        waitForCard("Discard this practice run")
        shot("12-discard")

        tap(AX.modal.primary)
        // The end of the tutorial leads to the Supernova paywall (it replaced the "You're all set" screen).
        XCTAssertTrue(app.buttons[AX.supernova.start].waitForExistence(timeout: 20), "the paywall")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        shot("13-paywall")
        tap(AX.supernova.free)
        XCTAssertTrue(app.descendants(matching: .any)[AX.home.startWorkout].waitForExistence(timeout: 5), "back on Home, no draft left")
    }
}
