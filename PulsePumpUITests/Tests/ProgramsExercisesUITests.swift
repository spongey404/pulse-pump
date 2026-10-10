import XCTest

/// Programs (templates) and the exercise catalogue.
final class ProgramsExercisesUITests: UITestCase {

    private func newUser() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("p"), scenario: .newUser, weeks: 2))
    }

    func testCreatingEditingAndStartingAProgram() {
        newUser()
        let programs = ProgramsPage(t: self)
        programs.open()
        programs.createProgram(name: "Smoke", days: 3, exerciseSearch: "Barbell Squat")

        tap(programs.row("Smoke"), "the new Smoke program")
        require(el(AX.programs.detailTitle), "program detail")
        waitForLabel(el(AX.programs.detailTitle), matching: "CONTAINS[c]", "Smoke")

        // Edit: add a second exercise, then finish editing.
        tapID(AX.programs.detailEdit)
        programs.addExercise(buttonID: AX.programs.detailAddExercise, search: "Pec Deck")
        tapID(AX.programs.detailDone)
        require(labelContaining("PEC DECK"), "the exercise added while editing")

        // Start a session from it.
        tapID(AX.programs.detailStart)
        require(el(AX.workout.sessionTitle), "logger opened from the program")
        waitForLabel(el(AX.workout.sessionTitle), matching: "CONTAINS[c]", "Smoke")
        XCTAssertTrue(el(AX.workout.exerciseName(0)).exists)
    }

    func testSwipingAProgramRowDeletesItAfterConfirmation() {
        newUser()
        let programs = ProgramsPage(t: self)
        programs.open()
        programs.createProgram(name: "Temp", days: 2, exerciseSearch: "Barbell Squat")
        require(programs.row("Temp"), "Temp program")
        programs.swipeToDelete("Temp")
        waitUntilGone(programs.row("Temp"), "deleted program row")
        require(programs.row("Push Pull Legs"), "the seeded program is untouched")
    }

    func testSwipingTheLastProgramShowsTheEmptyState() {
        newUser()
        let programs = ProgramsPage(t: self)
        programs.open()
        programs.swipeToDelete("Push Pull Legs")
        require(el(AX.programs.empty), "NO PROGRAMS empty state")
    }

    func testGlobalSearchFindsAnExerciseAndOpensItsDetail() {
        newUser()
        HomePage(t: self).openSearch()
        type("bench", into: AX.exercise.search)
        let hit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'search.row.'")).firstMatch
        tap(hit, "a 'bench' search result")
        require(labelContaining("Equipment"), "exercise detail info section")
    }

    func testCreatingACustomExercise() throws {
        throw XCTSkip("""
            Custom-exercise creation is unreachable: CreateExerciseView (and ExerciseLibraryView, its only presenter) \
            is never instantiated anywhere in the app (grep: no call sites besides their own definitions), and the \
            workout / program pickers have no 'create' entry. Un-skip once a screen presents it.
            """)
    }
}
