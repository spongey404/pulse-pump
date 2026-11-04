import XCTest

/// The states a crawl cannot reach by tapping around: Body lenses and focus, the calendar modal's selections, empty states for a
/// new user and the logger's sheets. Light mode, saved to `<REVIEW_DIR>/states/NN-name.png`; missing controls are skipped and
/// noted in `states/notes.txt` rather than failing, so one change never loses the rest.
///
///   REVIEW_DIR=review TEST_RUNNER_REVIEW_DIR=review bin/test-ui.sh --device "iPhone 15" --only ReviewStatesUITests
final class ReviewStatesUITests: UITestCase {
    private var dark: Bool { ProcessInfo.processInfo.environment["REVIEW_APPEARANCE"] == "dark" }
    private var dir: String { (ProcessInfo.processInfo.environment["REVIEW_DIR"] ?? "") + (dark ? "/states-dark" : "/states") }
    private var n = 0
    private var notes: [String] = []

    private func start(_ config: LaunchConfig) throws {
        guard !(ProcessInfo.processInfo.environment["REVIEW_DIR"] ?? "").isEmpty else { throw XCTSkip("set REVIEW_DIR") }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        XCUIDevice.shared.appearance = dark ? .dark : .light
        launch(config)
    }

    private func shot(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        n += 1
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: String(format: "%@/%02d-%@.png", dir, n, name)))
    }

    private func flush() { try? notes.joined(separator: "\n").write(toFile: "\(dir)/notes-\(n).txt", atomically: true, encoding: .utf8) }

    /// Taps `id` if it is there; notes it otherwise.
    @discardableResult
    private func press(_ id: String, _ why: String = "") -> Bool {
        let e = el(id)
        guard e.waitForExistence(timeout: 4), e.isHittable else { notes.append("not found: \(id) \(why)"); return false }
        e.tap(); RunLoop.current.run(until: Date().addingTimeInterval(0.7)); return true
    }

    private func body(_ plus: Bool) throws {
        try start(LaunchConfig(email: LaunchConfig.uniqueEmail("bs"), scenario: .busy, weeks: 8, plus: plus))
        let who = plus ? "member" : "free"
        press(AX.tab.body)
        shot("body-volume-\(who)")
        // A day with sets, then an empty day's note.
        press(AX.body.day(0)); shot("body-volume-day-selected-\(who)")
        for d in 0..<7 {
            press(AX.body.day(d))
            if el(AX.body.dayNote).exists { shot("body-volume-rest-day-note-\(who)"); break }
            press(AX.body.day(d))     // deselect
        }
        press(AX.body.allWeek)
        if press(AX.body.row("chest")) { shot("body-volume-chest-opened-\(who)") }
        app.swipeDown(velocity: .fast)
        if el(AX.body.focusChip).exists { shot("body-volume-focused-chip-\(who)") }
        press(AX.body.focusChip)
        if press(AX.body.mapSwap) { shot("body-volume-back-main-\(who)"); press(AX.body.mapSwap) }
        press(AX.body.modeFrequency)
        shot("body-frequency-\(who)")
        if plus {
            if press(AX.body.row("chest")) { app.swipeDown(velocity: .fast); shot("body-frequency-focused-\(who)") }
            press(AX.body.focusChip)
            if press(AX.body.mapSwap) { shot("body-frequency-back-main-\(who)"); press(AX.body.mapSwap) }
        }
        press(AX.body.modeVolume)
        // The calendar modal and its selections.
        if press(AX.body.calendar) {
            shot("body-calendar-open-\(who)")
            let trained = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.day.' AND label MATCHES '.*[A-Z]+ [0-9]+'")).firstMatch
            if trained.waitForExistence(timeout: 3) { trained.tap(); shot("body-calendar-day-selected-\(who)") }
            let week = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.week.'")).element(boundBy: 1)
            if week.exists { week.tap(); shot("body-calendar-week-selected-\(who)") }
            press(AX.calendar.close)
        }
        flush()
    }

    func testBodyStatesFree() throws { try body(false) }
    func testBodyStatesMember() throws { try body(true) }

    /// Empty states for an account with no workouts.
    func testNewUserStates() throws {
        try start(LaunchConfig(email: LaunchConfig.uniqueEmail("nu"), scenario: .newUser))
        shot("home-new-user")
        press(AX.tab.body); shot("body-new-user")
        press(AX.tab.programs); shot("programs-new-user")
        press(AX.tab.more); press(AX.row("History")); shot("history-new-user")
        press(AX.history.modeCalendar); shot("history-calendar-new-user")
        flush()
    }

    /// Home for a member and in each state of the dock.
    func testHomeMember() throws {
        try start(LaunchConfig(email: LaunchConfig.uniqueEmail("hm"), scenario: .busy, weeks: 8, plus: true))
        shot("home-member")
        press(AX.home.notToday); shot("home-not-today")
        flush()
    }

    /// The logger's sheets, one at a time, on a started workout (nothing is saved; the workout is discarded).
    func testLoggerSheets() throws {
        try start(LaunchConfig(email: LaunchConfig.uniqueEmail("lgs"), scenario: .busy, weeks: 4))
        HomePage(t: self).startPredictedWorkout()
        shot("logger-top")
        if press(AX.workout.setWeight(ex: 0, 1)) { shot("logger-keypad-weight"); press(AX.workout.sheetClose); app.swipeDown() }
        if press(AX.workout.setType(ex: 0, 1)) { shot("logger-set-type-sheet"); app.swipeDown() }
        if press(AX.workout.restPill) { shot("logger-rest-sheet"); app.swipeDown() }
        if press(AX.workout.exerciseMenu(0)) {
            shot("logger-exercise-menu")
            let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'workout.menu.'")).allElementsBoundByIndex.map { $0.identifier }
            for id in rows where !id.contains("remove") {
                guard press(id) else { continue }
                shot("logger-menu-" + id.replacingOccurrences(of: "workout.menu.", with: ""))
                if el(AX.workout.sheetClose).exists { press(AX.workout.sheetClose) } else { app.swipeDown() }
                if !el(id).exists { press(AX.workout.exerciseMenu(0)) }
            }
            app.swipeDown()
        }
        if press(AX.workout.addExerciseTop) { shot("logger-add-exercise-picker"); app.swipeDown() }
        if press(AX.workout.finish) { shot("logger-finish-modal"); press(AX.workout.finishKeepGoing) }
        if press(AX.workout.cancel) { shot("logger-discard-modal") }
        flush()
    }
}
