import XCTest

/// Home › search, laid out from Global Search Final.dc.html: a field with a back arrow, filter pills, recents and
/// what you use when empty, grouped results with counts when typing. Seeds the busy dataset.
final class GlobalSearchUITests: SeededUITestCase {
    override var scenario: String { "busy" }

    private func openSearch() {
        tap(AX.home.searchButton)
        XCTAssertTrue(app.textFields[AX.exercise.search].waitForExistence(timeout: 10), "global search field")
    }

    private func pill(_ label: String) -> XCUIElement { app.buttons[AX.exercise.searchPill(label)] }

    func testItOpensWithPillsAndYourTopExercises() {
        openSearch()
        for label in ["All", "Exercises", "Workouts", "Friends"] {
            XCTAssertTrue(pill(label).waitForExistence(timeout: 5), "the \(label) pill")
        }
        XCTAssertTrue(app.staticTexts["YOUR TOP EXERCISES"].waitForExistence(timeout: 5), "top exercises while the field is empty")
        XCTAssertTrue(app.staticTexts["RECENT"].exists, "the dev data seeds recent searches")
        XCTAssertTrue(app.staticTexts["romanian deadlift"].exists, "a seeded recent search")
        shot("s1-empty")
    }

    func testTypingGroupsResultsWithACountAndPillsNarrowThem() {
        openSearch()
        let field = app.textFields[AX.exercise.search]
        field.tap()
        field.typeText("bench")
        let header = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'EXERCISES ·'")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10), "an EXERCISES · n section header")
        shot("s2-results")

        pill("Workouts").tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'EXERCISES ·'")).firstMatch.waitForExistence(timeout: 2),
                       "the Workouts pill hides the exercises section")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'WORKOUTS ·'")).firstMatch.waitForExistence(timeout: 5))
        shot("s3-workouts")
    }

    func testASubmittedSearchBecomesARecentThatCanBeRemoved() {
        openSearch()
        let field = app.textFields[AX.exercise.search]
        field.tap()
        field.typeText("squat\n")
        app.buttons["Clear search"].tap()
        XCTAssertTrue(app.staticTexts["RECENT"].waitForExistence(timeout: 5), "a RECENT section")
        XCTAssertTrue(app.staticTexts["squat"].exists, "the term that was searched")
        shot("s4-recent")
        app.buttons["Remove squat"].tap()
        XCTAssertFalse(app.staticTexts["squat"].waitForExistence(timeout: 2), "removed")
    }
}
