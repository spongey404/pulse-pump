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
        require(home.doneRows.firstMatch, "a finished day on the week ledger")
        let newestOnHome = home.doneRowsSignature
        let history = HistoryPage(t: self)
        history.open()
        history.openFirstWorkout()
        history.deleteViaDetailMenu()
        require(el(AX.nav.title("HISTORY")), "History after deleting")
        TabBar(t: self).home()
        _ = home
        XCTAssertTrue(waitUntil { home.doneRowsSignature != newestOnHome }, "the deleted workout leaves Home's week ledger")
    }

    func testSwipeToDeleteInHistoryRemovesTheRowAfterConfirming() {
        user(.busy)
        let home = HomePage(t: self)
        require(home.doneRows.firstMatch, "a finished day on the week ledger")
        let newestOnHome = home.doneRowsSignature
        let history = HistoryPage(t: self)
        history.open()
        require(history.firstRow, "first row").swipeLeft()
        tap(app.buttons["Delete"].firstMatch, "swipe Delete action")
        history.confirmDelete()
        TabBar(t: self).home()
        _ = home
        XCTAssertTrue(waitUntil { home.doneRowsSignature != newestOnHome }, "the deleted workout leaves Home's week ledger")
    }

    // MARK: Home tiles per scenario

    func testHomeBusyScenarioShowsStreakSetsPredictionAndRecentTable() {
        user(.busy)
        let home = HomePage(t: self)
        home.waitForStreak(atLeast: 1)
        XCTAssertGreaterThan(home.sets, 0)
        XCTAssertFalse(home.predictedName.isEmpty)
        require(el(AX.home.recent), "week ledger")
        require(el(AX.home.startWorkout), "START WORKOUT dock")
    }

    func testHomeLapsedScenarioHasNoStreakButKeepsHistory() {
        user(.lapsed)
        let home = HomePage(t: self)
        require(el(AX.home.recent), "RECENT table (history exists)")
        XCTAssertEqual(home.sets, 0, "nothing logged this week")
    }

    func testHomeNewUserScenarioShowsEmptyStatesEverywhere() {
        user(.newUser)
        let home = HomePage(t: self)
        XCTAssertEqual(home.streak, 0)
        require(el(AX.home.newUserNote), "No workouts yet.")
        XCTAssertFalse(el(AX.home.kpiSets).exists, "a new user has no stats strip")
        XCTAssertFalse(home.hasRecentTable, "no workouts -> the ledger shows only the plan")
        require(el(AX.home.startWorkout), "START WORKOUT still offered")
        let history = HistoryPage(t: self)
        history.open()
        require(el(AX.history.empty), "NO WORKOUTS YET empty state")
    }

    // MARK: Body

    func testBodyTabShowsTheMapWithTheOtherSideInTheCornerAndTheWeekTotal() {
        user(.busy)
        let body = BodyPage(t: self)
        body.open()
        require(el(AX.body.figureFront), "the front figure")
        XCTAssertEqual(el(AX.body.mapSwap).label, "Show back view")
        tapID(AX.body.mapSwap)
        waitForLabel(el(AX.body.mapSwap), matching: "==", "Show front view")
        require(el(AX.body.figureBack), "the back figure is now the main view")
        XCTAssertGreaterThan(body.totalSets, 0, "a busy user trained this week")
    }

    /// A member's map draws Stardust per muscle; swapping sides used to index the old side's muscles and crash.
    func testMemberCanSwapTheMapBackAndForthWithoutCrashing() {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("h"), scenario: .busy, weeks: 4, plus: true))
        BodyPage(t: self).open()
        for _ in 0..<3 {
            tapID(AX.body.mapSwap)
            require(el(AX.body.figureBack), "the back figure")
            tapID(AX.body.mapSwap)
            require(el(AX.body.figureFront), "the front figure")
        }
        XCTAssertEqual(app.state, .runningForeground, "the app is still running")
    }

    func testBodyDayStripNarrowsTheTotalAndWeekRestoresIt() {
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
        XCTAssertTrue(narrowed, "selecting a single day must change the SETS stat from the week total \(week)")
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

    func testOpeningAGroupFocusesItsMusclesAndTheChipClearsIt() {
        user(.busy)
        BodyPage(t: self).open()
        scrollTo(el(AX.body.row("chest")))
        tapID(AX.body.row("chest"))
        scrollTo(el(AX.body.row("upper_chest")))
        require(el(AX.body.row("upper_chest")), "the Chest group opens to Upper Chest")
        require(el(AX.body.row("chest")), "and Lower Chest")
        scrollUp()
        require(el(AX.body.focusChip), "the CHEST × chip")
        tapID(AX.body.focusChip)
        waitUntilGone(el(AX.body.focusChip), "the chip")
    }

    func testFrequencyIsLockedForFreeUsers() {
        user(.busy)
        BodyPage(t: self).open()
        tapID(AX.body.modeFrequency)
        require(el(AX.body.locked), "the locked FREQUENCY · SUPERNOVA* card")
        require(el(AX.body.lockedCTA), "GO SUPERNOVA*")
        XCTAssertFalse(el(AX.body.focusChip).exists, "no focus chip when locked")
    }

    func testCalendarModalOpensSelectsADayAndShowsItOnTheMap() {
        user(.busy)
        BodyPage(t: self).open()
        tapID(AX.body.calendar)
        require(el(AX.calendar.modal), "the calendar modal")
        let trainedDay = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.day.' AND label MATCHES '.*[A-Z]+ [0-9]+'")).firstMatch
        tap(trainedDay, "a trained day")
        tapID(AX.calendar.showOnMap)
        waitUntilGone(el(AX.calendar.modal), "the modal after SHOW ON MAP")
        XCTAssertGreaterThan(BodyPage(t: self).totalSets, 0, "the chosen day is on the map")
    }

    func testCalendarModalCloses() {
        user(.busy)
        BodyPage(t: self).open()
        tapID(AX.body.calendar)
        require(el(AX.calendar.modal), "the calendar modal")
        tapID(AX.calendar.close)
        waitUntilGone(el(AX.calendar.modal), "the modal")
    }

    // MARK: History calendar

    func testHistoryCalendarShowsSessionsAndOpensTheFullWorkoutView() {
        user(.busy)
        let history = HistoryPage(t: self)
        history.open()
        tapID(AX.history.modeCalendar)
        require(el(AX.calendar.root), "the calendar")
        let trainedDay = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.day.' AND label MATCHES '.*[A-Z]+ [0-9]+'")).firstMatch
        tap(trainedDay, "a trained day")
        tapID(AX.calendar.cardOpen)
        require(labelContaining("SETS"), "the full workout view")
        tapID(AX.nav.back)
        require(el(AX.calendar.root), "back on the calendar")
    }
}
