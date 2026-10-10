import XCTest

/// The five tabs of the shell. Every tab press waits for a marker element of the screen it opens.
struct TabBar {
    let t: UITestCase

    func home() { go(AX.tab.home, marker: AX.home.profileButton) }
    func programs() { go(AX.tab.programs, marker: AX.programs.screen) }
    func social() { go(AX.tab.social, marker: AX.social.screen) }
    func body() { go(AX.tab.body, marker: AX.body.screen) }
    func more() { go(AX.tab.more, marker: AX.more.screen) }

    private func go(_ tab: String, marker: String) {
        t.tapID(tab)
        t.require(t.el(marker), "screen marker \(marker) after tapping \(tab)")
    }
}

struct HomePage {
    let t: UITestCase

    /// Numeric value of a KPI tile ("0" when the tile shows an empty state).
    func kpi(_ id: String) -> Int {
        Int(t.require(t.el(id), id).label) ?? -1
    }

    var streak: Int { kpi(AX.home.kpiStreak) }
    var sets: Int { kpi(AX.home.kpiSets) }

    func waitForStreak(atLeast n: Int) {
        let predicate = NSPredicate { _, _ in self.streak >= n }
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: 20), .completed, "streak never reached \(n), is \(streak)")
    }

    var predictedName: String { t.require(t.el(AX.home.predictedName), "predicted workout").label }

    func startPredictedWorkout() {
        t.tapID(AX.home.startWorkout)
        t.require(t.el(AX.workout.sessionTitle), "active workout screen")
    }

    func continueDraft() {
        t.tapID(AX.home.continueDraft)
        t.require(t.el(AX.workout.sessionTitle), "resumed workout screen")
    }

    var hasRecentTable: Bool { t.el(AX.home.recent).waitForExistence(timeout: 3) }

    func openSearch() {
        t.tapID(AX.home.searchButton)
        t.require(t.el(AX.exercise.search), "global search field")
    }
}

/// The full-screen logger.
struct WorkoutPage {
    let t: UITestCase

    var title: XCUIElement { t.require(t.el(AX.workout.sessionTitle), "workout title") }

    func exerciseName(_ i: Int = 0) -> String { t.require(t.el(AX.workout.exerciseName(i)), "exercise \(i)").label }

    /// Types weight/reps into set `n` (1-based) of exercise card `ex`. `weight` is in the user's display unit.
    func fillSet(ex: Int = 0, _ n: Int, weight: String, reps: String) {
        t.type(weight, into: AX.workout.setWeight(ex: ex, n))
        t.type(reps, into: AX.workout.setReps(ex: ex, n))
    }

    /// Taps the set's check circle. The unlogged circle is a stroked ring with no contentShape, so only the 2pt
    /// ring itself is hit-testable: a tap on the centre (what `tap()` does) falls through. Tap the ring's top edge.
    /// (Real fingers usually land on the ring; the empty middle not registering is an app hit-target bug.)
    func logSet(ex: Int = 0, _ n: Int) {
        closeNumberPad()
        let check = t.el(AX.workout.setCheck(ex: ex, n))
        t.require(check, AX.workout.setCheck(ex: ex, n))
        check.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
    }

    /// The number pad has no return key and covers the FINISH bar. Opening an exercise note switches to the text
    /// keyboard, whose "Done" button resigns focus for good.
    func closeNumberPad() {
        guard t.app.keyboards.firstMatch.exists else { return }
        let note = t.app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'exercise note'")).firstMatch
        guard note.exists else { return }
        note.tap()
        let done = t.app.buttons["DONE"].firstMatch
        if done.waitForExistence(timeout: 3) { done.tap() }
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 0"), object: t.app.keyboards)
        _ = XCTWaiter().wait(for: [gone], timeout: 3)
    }

    func isSetLogged(ex: Int = 0, _ n: Int) -> Bool {
        t.el(AX.workout.setCheck(ex: ex, n)).label == "Set \(n) done"
    }

    func waitForSetLogged(ex: Int = 0, _ n: Int) {
        t.waitForLabel(t.el(AX.workout.setCheck(ex: ex, n)), matching: "==", "Set \(n) done")
    }

    func addSet(ex: Int = 0) {
        closeNumberPad()
        t.tapID(AX.workout.addSet(ex))
    }

    func addExerciseViaPicker(search: String, pick row: String) {
        t.dismissKeyboard()
        t.scrollTo(t.el(AX.workout.addExercise))
        t.tapID(AX.workout.addExercise)
        t.type(search, into: AX.picker.search)
        t.tapID(AX.picker.row(row))
    }

    func finish() {
        closeNumberPad()
        t.tapID(AX.workout.finish)
    }

    /// Finish even when sets are unlogged ("REMOVE + FINISH" confirmation).
    func finishConfirmingRemoval() {
        finish()
        let confirm = t.el(AX.modal.primary)
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
    }

    func discard() {
        t.dismissKeyboard()
        t.tapID(AX.workout.cancel)
        t.snap("discard confirmation")
        t.tapID(AX.modal.primary)           // DISCARD WORKOUT
        t.snap("after discard")
    }
}

/// Post-workout summary with the caption composer.
struct CompletionPage {
    let t: UITestCase

    func waitForIt() { t.require(t.el(AX.completion.title), "workout summary", timeout: 20) }

    func caption(_ text: String) {
        t.type(text, into: AX.completion.caption)
        t.dismissKeyboard()
    }

    /// Primary button: POST (auto-share on) or DONE.
    var primaryLabel: String { t.require(t.el(AX.completion.cta), "summary CTA").label }

    func dismiss() {
        t.tapID(AX.completion.cta)
        t.waitUntilGone(t.el(AX.completion.title), "summary")
    }

    func dontPostViaMenu() {
        t.tapID(AX.completion.menu)
        t.tapID(AX.completion.dontPost)
        t.waitUntilGone(t.el(AX.completion.title), "summary")
    }
}
