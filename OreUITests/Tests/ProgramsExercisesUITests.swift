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
        programs.createBlankProgram(name: "Smoke", days: 3)

        // The first workout is empty: + EXERCISES opens it straight into edit mode.
        tapID(AX.programs.workoutStart(0))
        require(el(AX.programs.workoutAddExercise), "the empty workout opens in edit mode")
        programs.addExercises(search: "Pec Deck")
        require(el(AX.programs.exerciseRow(0)), "the exercise added to the workout")

        // Its targets: tap the row, step SETS.
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "REST")).firstMatch, "the exercise row")
        tapID(AX.programs.exerciseField(0, "sets", plus: true))
        require(labelContaining("4 × 8–12"), "the new default 3 × 8–12 became 4 sets")
        tapID(AX.programs.workoutDone)

        // Start a session from it.
        tapID(AX.programs.workoutStartDock)
        require(el(AX.workout.sessionTitle), "logger opened from the workout")
        waitForLabel(el(AX.workout.sessionTitle), matching: "CONTAINS[c]", "Workout A")
        XCTAssertTrue(el(AX.workout.exerciseName(0)).exists)
    }

    /// The seeded Push / Pull / Leg days are three workouts of one program, "Push Pull Legs".
    func testDeletingAProgramFromItsEditPageShowsTheEmptyState() {
        newUser()
        let programs = ProgramsPage(t: self)
        programs.open()
        require(programs.row("Push Pull Legs"), "the seeded Push / Pull / Legs workouts are one program")
        programs.deleteProgram("Push Pull Legs")
        waitUntilGone(programs.row("Push Pull Legs"), "deleted program row")
        require(el(AX.programs.empty), "NO PROGRAMS empty state")
    }

    func testUpNextIsTheOnlyAccentActionAndStartsTheNextWorkout() {
        newUser()
        ProgramsPage(t: self).open()
        require(el(AX.programs.upNext), "the UP NEXT card")
        tapID(AX.programs.upNextStart)
        require(el(AX.workout.sessionTitle), "the logger opens from UP NEXT")
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
