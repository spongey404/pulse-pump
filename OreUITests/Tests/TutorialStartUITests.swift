import XCTest

/// How the tutorial is started and left, from the More tab (the walkthrough itself is `TutorialUITests`).
final class TutorialStartUITests: SeededUITestCase {

    private func openTutorialFromMore() {
        tap(AX.tab.more)
        let row = app.descendants(matching: .any)[AX.row("Tutorial")].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the Tutorial row")
        row.tap()
    }

    private var cardTitle: String { app.staticTexts[AX.tutorial.card].firstMatch.label }

    func testMoreTutorialStartsTheWalkthroughOnHome() {
        openTutorialFromMore()
        XCTAssertTrue(app.staticTexts[AX.tutorial.card].waitForExistence(timeout: 10), "the tutorial card")
        XCTAssertEqual(cardTitle, "Start a workout")
        XCTAssertTrue(app.descendants(matching: .any)[AX.home.startWorkout].waitForExistence(timeout: 5), "it moved to Home")
    }

    /// The tutorial runs a practice workout, so it must not start on top of a real unfinished one.
    func testTutorialWillNotStartOverARealDraft() {
        tap(AX.home.startWorkout)
        XCTAssertTrue(app.buttons[AX.workout.cancel].waitForExistence(timeout: 10))
        app.buttons[AX.workout.cancel].tap()
        XCTAssertTrue(app.buttons[AX.modal.secondary].waitForExistence(timeout: 5))
        app.buttons[AX.modal.secondary].tap()   // SAVE AS DRAFT
        XCTAssertTrue(app.descendants(matching: .any)[AX.home.continueDraft].waitForExistence(timeout: 10), "a draft is waiting on Home")

        openTutorialFromMore()
        XCTAssertTrue(app.alerts["Finish your workout first"].waitForExistence(timeout: 5), "the tutorial refuses")
        XCTAssertFalse(app.staticTexts[AX.tutorial.card].exists, "and does not start")
    }

    /// Leaving mid-way must take the practice workout with it, not leave a draft behind.
    func testSkippingTheTutorialMidWayCleansUpThePracticeWorkout() {
        openTutorialFromMore()
        XCTAssertTrue(app.staticTexts[AX.tutorial.card].waitForExistence(timeout: 10))
        tap(AX.home.startWorkout)
        XCTAssertTrue(app.buttons[AX.workout.addExercise].waitForExistence(timeout: 10), "the practice workout opened")

        app.buttons[AX.tutorial.skip].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AX.home.startWorkout].waitForExistence(timeout: 10), "back on Home with START, not CONTINUE")
        XCTAssertFalse(app.descendants(matching: .any)[AX.home.continueDraft].exists, "no draft was left behind")
        XCTAssertFalse(app.staticTexts[AX.tutorial.card].exists, "the tutorial is gone")
    }
}
