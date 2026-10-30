import XCTest

/// History editing/deleting, the Home tiles per dev-data scenario, and the Body tab.
final class HistoryHomeBodyUITests: UITestCase {

    private func user(_ scenario: LaunchConfig.Scenario, lbs: Bool = false, tab: Int? = nil) {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("h"), scenario: scenario, weeks: 4, lbs: lbs, startTab: tab))
    }

    // MARK: History

    func testHistoryListsSeededSessionsAndOpensTheNewestOne() {
        user(.busy)
        let history = HistoryPage(t: self)
        history.open()
        require(history.firstRow, "a history row")
        history.openFirstWorkout()
        require(labelContaining("SETS"), "stats strip in the detail")
        history.back()
        require(el(AX.nav.title("HISTORY")), "back on the History list")
    }

    func testEditingAPastSetUpdatesTheDetail() {
        user(.busy)
        let history = HistoryPage(t: self)
        history.open()
        history.openFirstWorkout()
        tapID(AX.detail.menu)
        tap(app.buttons["Edit"].firstMatch, "Edit menu item")
        replaceText(in: AX.detail.setWeight(1), with: "123")
        dismissKeyboard()
        tapID(AX.detail.done)
        require(labelContaining("123"), "edited weight 123 in the read-only detail")
    }

    func testDeletingAPastWorkoutFromItsDetailRemovesItFromHistoryAndHome() {
        user(.busy)
        let home = HomePage(t: self)
        let newestOnHome = require(el(AX.home.recentRow(0)), "newest recent row").label
        let history = HistoryPage(t: self)
        history.open()
        history.openFirstWorkout()
        history.deleteViaDetailMenu()
        require(el(AX.nav.title("HISTORY")), "History after deleting")
        TabBar(t: self).home()
        _ = home
        waitForLabel(el(AX.home.recentRow(0)), matching: "!=", newestOnHome)
    }

    func testSwipeToDeleteInHistoryRemovesTheRowAfterConfirming() {
        user(.busy)
        let home = HomePage(t: self)
        let newestOnHome = require(el(AX.home.recentRow(0)), "newest recent row").label
        let history = HistoryPage(t: self)
        history.open()
        require(history.firstRow, "first row").swipeLeft()
        tap(app.buttons["Delete"].firstMatch, "swipe Delete action")
        history.confirmDelete()
        TabBar(t: self).home()
        _ = home
        waitForLabel(el(AX.home.recentRow(0)), matching: "!=", newestOnHome)
    }

    // MARK: Home tiles per scenario

    func testHomeBusyScenarioShowsStreakSetsPredictionAndRecentTable() {
        user(.busy)
        let home = HomePage(t: self)
        home.waitForStreak(atLeast: 1)
        XCTAssertGreaterThan(home.sets, 0)
        XCTAssertFalse(home.predictedName.isEmpty)
        require(el(AX.home.recent), "RECENT table")
        require(el(AX.home.startWorkout), "START WORKOUT dock")
    }

    func testHomeLapsedScenarioHasNoStreakButKeepsHistory() {
        user(.lapsed)
        let home = HomePage(t: self)
        require(el(AX.home.recent), "RECENT table (history exists)")
        XCTAssertEqual(home.streak, 0, "no sessions in 12 days -> streak 0")
        XCTAssertEqual(home.sets, 0, "nothing logged this week")
    }

    func testHomeNewUserScenarioShowsEmptyStatesEverywhere() {
        user(.newUser)
        let home = HomePage(t: self)
        XCTAssertEqual(home.streak, 0)
        XCTAssertEqual(home.sets, 0)
        XCTAssertFalse(home.hasRecentTable, "no workouts -> no RECENT table")
        require(el(AX.home.startWorkout), "START WORKOUT still offered")
        let history = HistoryPage(t: self)
        history.open()
        require(el(AX.history.empty), "NO WORKOUTS YET empty state")
    }

    // MARK: Body

    func testBodyTabShowsFrontAndBackFiguresAndTheWeekTotal() {
        user(.busy)
        let body = BodyPage(t: self)
        body.open()
        require(el(AX.body.figureFront), "FRONT figure")
        require(el(AX.body.figureBack), "BACK figure")
        XCTAssertGreaterThan(body.totalSets, 0, "a busy user trained this week")
    }

    func testBodyDayScrubberNarrowsTheTotalAndAllWeekRestoresIt() {
        user(.busy)
        let body = BodyPage(t: self)
        body.open()
        let week = body.totalSets
        var narrowed = false
        for day in 0..<7 {
            tapID(AX.body.day(day))
            if labelChanges(el(AX.body.totalSets), from: "\(week)", within: 3) { narrowed = true; break }
            tapID(AX.body.day(day))                                    // tapping again deselects
        }
        XCTAssertTrue(narrowed, "selecting a single day must change the hero set count from the week total \(week)")
        tapID(AX.body.allWeek)
        waitForLabel(el(AX.body.totalSets), matching: "==", "\(week)")
    }

    func testBodyWeekArrowsMoveBackAndForward() {
        user(.busy)
        BodyPage(t: self).open()
        let before = el(AX.body.allWeek).label
        tapID(AX.body.prevWeek)
        waitForLabel(el(AX.body.allWeek), matching: "!=", before)
        tapID(AX.body.nextWeek)
        waitForLabel(el(AX.body.allWeek), matching: "==", before)
    }

    func testTappingTheChestOnTheBodyMapOpensTheMuscleSheet() {
        user(.busy)
        let body = BodyPage(t: self)
        body.open()
        body.tapChestOnFrontFigure()
        require(el(AX.body.muscleSheet), "muscle detail sheet (Done button)")
        tapID(AX.body.muscleSheet)
        waitUntilGone(el(AX.body.muscleSheet), "muscle sheet")
    }
}
