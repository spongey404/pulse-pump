import XCTest

/// The logger, from starting a session to the summary, the draft, and what the finished session changes elsewhere.
final class WorkoutUITests: UITestCase {

    private func busyUser(lbs: Bool = false, draft: Bool = false) {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("w"), scenario: .busy, weeks: 4, lbs: lbs, draft: draft))
    }

    func testStartingTodaysWorkoutFromHomeOpensTheLoggerWithTemplateExercises() {
        busyUser()
        let home = HomePage(t: self)
        let predicted = home.predictedName
        home.startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        waitForLabel(workout.title, matching: "CONTAINS[c]", predicted.components(separatedBy: " ").first ?? predicted)
        XCTAssertFalse(workout.exerciseName(0).isEmpty)
        require(el(AX.workout.setWeight(ex: 0, 1)), "first set row")
    }

    func testLoggingASetMarksItDoneAndStartsTheRestTimer() {
        busyUser()
        HomePage(t: self).startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        XCTAssertEqual(el(AX.workout.restTime).label, "—:—", "no rest timer before the first set is logged")
        workout.fillSet(1, weight: "100", reps: "5")
        workout.dismissAndLog(1)
        workout.waitForSetLogged(1)
        waitForLabel(el(AX.workout.restTime), matching: "MATCHES", "\\d+:\\d{2}")
        XCTAssertNotEqual(el(AX.workout.restTime).label, "—:—")
    }

    func testAddSetButtonAppendsAnotherSetRow() {
        busyUser()
        HomePage(t: self).startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        var count = 0
        while el(AX.workout.setWeight(ex: 0, count + 1)).exists { count += 1 }
        XCTAssertGreaterThan(count, 0)
        workout.addSet()
        require(el(AX.workout.setWeight(ex: 0, count + 1)), "set \(count + 1) after + ADD SET")
        XCTAssertFalse(el(AX.workout.setWeight(ex: 0, count + 2)).exists)
    }

    func testAddingAnExerciseFromThePickerAppendsACard() {
        busyUser()
        HomePage(t: self).startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        var cards = 0
        while el(AX.workout.exerciseName(cards)).exists { cards += 1 }
        workout.addExerciseViaPicker(search: "Pec Deck", pick: "Pec Deck")
        let added = el(AX.workout.exerciseName(cards))
        require(added, "new exercise card")
        XCTAssertTrue(added.label.localizedCaseInsensitiveContains("pec deck"))
    }

    func testFinishingShowsSummaryThenHomeCountsTheSetAndExerciseDetailShowsTheNewPR() {
        busyUser()
        let home = HomePage(t: self)
        let setsBefore = home.sets
        home.startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        let exercise = workout.exerciseName(0)
        workout.fillSet(1, weight: "300", reps: "1")
        workout.dismissAndLog(1)
        workout.waitForSetLogged(1)
        workout.finishConfirmingRemoval()

        let summary = CompletionPage(t: self)
        summary.waitForIt()
        summary.caption("PR day")
        summary.dontPostViaMenu()

        require(el(AX.home.kpiSets), "Home after the summary")
        waitForLabel(el(AX.home.kpiSets), matching: "==", "\(setsBefore + 1)")

        home.openSearch()
        type(String(exercise.lowercased().split(separator: " ").last ?? ""), into: AX.exercise.search)   // multi-word queries find nothing in Global Search today
        let hit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'search.row.'")).firstMatch
        tap(hit, "exercise search result")
        require(el(AX.exercise.detailProgress), "exercise progress section")
        require(labelContaining("300"), "the new 300 weight PR")
    }

    func testFinishedSessionAppearsAtTheTopOfHistory() {
        busyUser()
        HomePage(t: self).startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        workout.fillSet(1, weight: "50", reps: "10")
        workout.dismissAndLog(1)
        workout.waitForSetLogged(1)
        workout.finishConfirmingRemoval()
        let summary = CompletionPage(t: self)
        summary.waitForIt()
        summary.dontPostViaMenu()

        let history = HistoryPage(t: self)
        history.open()
        history.openFirstWorkout()
        require(labelContaining("50"), "the logged 50 x 10 set in the newest session")
    }

    func testLbsUserLogsPoundsAndSeesPoundsInHistory() {
        busyUser(lbs: true)
        HomePage(t: self).startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        workout.fillSet(1, weight: "225", reps: "5")
        workout.dismissAndLog(1)
        workout.waitForSetLogged(1)
        workout.finishConfirmingRemoval()
        let summary = CompletionPage(t: self)
        summary.waitForIt()
        summary.dontPostViaMenu()

        let history = HistoryPage(t: self)
        history.open()
        history.openFirstWorkout()
        let row = labelContaining("225")
        require(row, "225 lb set in the detail (stored as kg, shown in pounds)")
        XCTAssertTrue(row.label.lowercased().contains("lb"), "label should carry the pound unit: \(row.label)")
    }

    func testDraftSurvivesKillingTheAppAndCanBeResumed() {
        busyUser()
        HomePage(t: self).startPredictedWorkout()
        let workout = WorkoutPage(t: self)
        workout.fillSet(1, weight: "100", reps: "5")
        workout.dismissAndLog(1)
        workout.waitForSetLogged(1)

        relaunchKeepingAccount()                          // terminate = swipe-up in the app switcher
        require(el(AX.home.continueDraft), "CONTINUE card for the unfinished workout", timeout: 30)
        XCTAssertFalse(el(AX.home.startWorkout).exists, "the draft replaces the START button")
        HomePage(t: self).continueDraft()
        WorkoutPage(t: self).waitForSetLogged(1)
    }

    func testSeededDraftShowsContinueCardAndDiscardReturnsToStart() {
        busyUser(draft: true)
        require(el(AX.home.continueDraft), "seeded draft CONTINUE card")
        tapID(AX.home.startNew)                           // "START NEW WORKOUT" asks to discard the draft
        tapID(AX.modal.primary)
        require(el(AX.workout.sessionTitle), "a fresh workout opens after discarding the draft")
        WorkoutPage(t: self).discard()
        require(el(AX.home.startWorkout), "START WORKOUT is back with no draft")
        XCTAssertFalse(el(AX.home.continueDraft).exists)
    }

    func testDiscardingAStartedWorkoutReturnsHomeWithoutADraft() {
        busyUser()
        HomePage(t: self).startPredictedWorkout()
        WorkoutPage(t: self).discard()
        require(el(AX.home.startWorkout), "START WORKOUT after discarding")
        XCTAssertFalse(el(AX.home.continueDraft).exists)
    }
}

private extension WorkoutPage {
    /// Closes the numeric keyboard (it covers the check button) and logs the set.
    func dismissAndLog(_ n: Int) {
        logSet(n)
    }
}
