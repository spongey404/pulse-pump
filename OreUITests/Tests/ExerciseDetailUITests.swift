import XCTest

/// The exercise detail page, with a few months of history to show. No emulator needed.
final class ExerciseDetailUITests: SeededUITestCase {
    override var scenario: String { "busy" }

    /// Home › search › the first match for `query`.
    private func openFromHomeSearch(_ query: String) {
        tap(AX.home.searchButton)
        let field = app.textFields[AX.exercise.search]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "global search field")
        field.tap()
        field.typeText(query)
        let hit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'search.row.'")).firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 10), "a search result for \(query)")
        hit.tap()
        XCTAssertTrue(app.buttons[AX.exercise.detailBack].waitForExistence(timeout: 10), "the exercise page opened")
    }

    // MARK: The page itself

    func testAboutTabShowsTheRecordsMuscleMapAndSetup() {
        openFromHomeSearch("bench")
        shot("d1-about")
        XCTAssertTrue(app.descendants(matching: .any)[AX.exercise.detailProgress].waitForExistence(timeout: 5), "the records strip")
        for label in ["EST 1RM", "BEST SET", "LAST", "SESSIONS", "MUSCLES WORKED", "PRIMARY", "SECONDARY", "SETUP", "EQUIPMENT", "DEFAULT REST"] {
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 3), "\(label) is on the About tab")
        }
        XCTAssertTrue(app.staticTexts["FRONT"].exists && app.staticTexts["BACK"].exists, "the front and back body map")
    }

    func testHistoryTabShowsTheChartRangesMetricsAndSessions() {
        openFromHomeSearch("bench")
        app.buttons[AX.exercise.detailTabHistory].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AX.exercise.detailChart].waitForExistence(timeout: 5), "the trend chart")
        XCTAssertTrue(app.staticTexts["ESTIMATED 1RM"].exists, "it opens on estimated 1RM")
        XCTAssertTrue(app.staticTexts["TODAY"].exists)
        shot("d2-history")

        // The range chips and the metric selector change what the chart is about.
        for label in ["1M", "3M", "6M", "1Y", "ALL"] {
            XCTAssertTrue(app.buttons[AX.exercise.detailRange(label)].exists, "\(label) chip")
        }
        app.buttons[AX.exercise.detailRange("ALL")].tap()
        app.buttons[AX.exercise.detailMetric("TOP SET")].tap()
        XCTAssertTrue(app.staticTexts["TOP SET WEIGHT"].waitForExistence(timeout: 3))
        app.buttons[AX.exercise.detailMetric("VOLUME")].tap()
        XCTAssertTrue(app.staticTexts["SESSION VOLUME"].waitForExistence(timeout: 3))
        shot("d3-volume-all")

        XCTAssertTrue(app.staticTexts["SESSIONS"].exists, "the session list")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'SHOW ALL'")).firstMatch.exists, "with a way to see them all")
    }

    func testTabsSwitchBackAndForth() {
        openFromHomeSearch("squat")
        app.buttons[AX.exercise.detailTabHistory].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AX.exercise.detailChart].waitForExistence(timeout: 5))
        app.buttons[AX.exercise.detailTabAbout].tap()
        XCTAssertTrue(app.staticTexts["MUSCLES WORKED"].waitForExistence(timeout: 5))
    }

    // MARK: Context: ADD TO WORKOUT only from a workout

    /// Looked up from search there is no workout to add to, so there is no button.
    func testOpenedFromSearchThereIsNoAddToWorkoutButton() {
        openFromHomeSearch("bench")
        XCTAssertFalse(app.buttons[AX.exercise.detailAdd].exists, "no workout to add to")
        XCTAssertFalse(app.staticTexts["ADD TO WORKOUT"].exists)
        app.buttons[AX.exercise.detailTabHistory].tap()
        XCTAssertFalse(app.buttons[AX.exercise.detailAdd].exists, "on either tab")
    }

    /// From the add-exercise list inside a workout, the same page has the button, and it adds the exercise.
    func testOpenedFromTheWorkoutsAddListTheButtonAddsTheExercise() {
        tap(AX.home.startWorkout)
        XCTAssertTrue(app.buttons[AX.workout.addExerciseTop].waitForExistence(timeout: 10), "the logger opened")
        let count = { self.app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.exercise.' AND identifier ENDSWITH '.name'")).count }
        let before = count()

        app.buttons[AX.workout.addExerciseTop].tap()
        let search = app.textFields[AX.picker.search]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("pec deck")
        let info = app.buttons[AX.picker.info("Pec Deck")]
        XCTAssertTrue(info.waitForExistence(timeout: 5), "a single exercise has an info button")
        shot("d4-picker-info")
        info.tap()

        let add = app.buttons[AX.exercise.detailAdd]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the page has ADD TO WORKOUT in this context")
        shot("d5-with-add")
        XCTAssertEqual(count(), before, "looking did not add it")
        add.tap()
        waitUntil("the exercise to be added") { count() == before + 1 }
        XCTAssertFalse(app.buttons[AX.exercise.detailBack].exists, "back in the workout")
    }

    func testBackReturnsToTheListItCameFrom() {
        tap(AX.home.startWorkout)
        XCTAssertTrue(app.buttons[AX.workout.addExerciseTop].waitForExistence(timeout: 10))
        app.buttons[AX.workout.addExerciseTop].tap()
        let search = app.textFields[AX.picker.search]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("pec deck")
        app.buttons[AX.picker.info("Pec Deck")].tap()
        XCTAssertTrue(app.buttons[AX.exercise.detailBack].waitForExistence(timeout: 5))
        app.buttons[AX.exercise.detailBack].tap()
        XCTAssertTrue(app.textFields[AX.picker.search].waitForExistence(timeout: 5), "back to the add-exercise list")
    }
}
