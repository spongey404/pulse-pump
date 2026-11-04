import XCTest

/// The second design review's flows, beyond what the crawl taps into: the logger from start to a posted workout, the Supernova paywall
/// (opened, never bought), challenges, Add friends and profiles. Screenshots go to `<REVIEW_DIR>/flows/NN-name-<light|dark>.png`;
/// `REVIEW_APPEARANCE=dark` switches the device to dark. A missing control is noted in `flows/notes.txt` and skipped, so one change
/// never loses the rest of a flow.
///
///   REVIEW_DIR=review2 TEST_RUNNER_REVIEW_DIR=review2 bin/test-ui.sh --device "iPhone 15" --only ReviewFlowsUITests
final class ReviewFlowsUITests: UITestCase {
    private var root: String { ProcessInfo.processInfo.environment["REVIEW_DIR"] ?? "" }
    private var dark: Bool { ProcessInfo.processInfo.environment["REVIEW_APPEARANCE"] == "dark" }
    private var dir: String { root + "/flows" }
    private var n = 0
    private var notes: [String] = []

    private func begin(_ config: LaunchConfig, as login: Bool = false) throws {
        guard !root.isEmpty else { throw XCTSkip("set REVIEW_DIR") }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        XCUIDevice.shared.appearance = dark ? .dark : .light
        launch(config)
    }

    private func shot(_ name: String, wait: TimeInterval = 1.0) {
        RunLoop.current.run(until: Date().addingTimeInterval(wait))
        n += 1
        let file = String(format: "%@/%@-%02d-%@-%@.png", dir, name.hasPrefix("logger") ? "L" : name.hasPrefix("paywall") ? "P" : "S", n, name, dark ? "dark" : "light")
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: file))
    }

    private func flush(_ tag: String) { try? notes.joined(separator: "\n").write(toFile: "\(dir)/notes-\(tag)-\(dark ? "dark" : "light").txt", atomically: true, encoding: .utf8) }

    @discardableResult
    private func press(_ id: String, _ why: String = "") -> Bool {
        let e = el(id)
        guard e.waitForExistence(timeout: 5), e.isHittable else { notes.append("not found: \(id) \(why)"); return false }
        e.tap(); RunLoop.current.run(until: Date().addingTimeInterval(0.7)); return true
    }

    /// A tap at the top of the screen closes a sheet or popover (a swipe down would pull the search overlay open).
    private func tapOutside() {
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    // MARK: Logger → post

    func testLoggerStartToPost() throws {
        try begin(LaunchConfig(email: LaunchConfig.uniqueEmail("fl"), scenario: .busy, weeks: 8))
        HomePage(t: self).startPredictedWorkout()
        shot("logger-start")
        let workout = WorkoutPage(t: self)

        // The keypad, a typed set, logged.
        tapID(AX.workout.setWeight(ex: 0, 1))
        require(el(AX.keypad.root), "the keypad")
        shot("logger-keypad")
        workout.keys("80")
        tapID(AX.keypad.next)
        workout.keys("8")
        shot("logger-keypad-reps")
        tapID(AX.keypad.done)
        waitUntilGone(el(AX.keypad.root), "the keypad")
        workout.logSet(1)
        workout.waitForSetLogged(1)
        shot("logger-set-logged")

        // The sheets and the ··· menu.
        if press(AX.workout.setType(ex: 0, 2)) { shot("logger-set-type"); tapOutside() }
        if press(AX.workout.restPill) { shot("logger-rest"); tapOutside() }
        if press(AX.workout.exerciseMenu(0)) {
            shot("logger-menu")
            tapOutside()
        }

        // Finish: the modal, then the summary (the full-screen body map), the composer and the post.
        workout.closeNumberPad()
        tapID(AX.workout.finish)                                   // the first tap may only close the ··· popover
        if !el(AX.modal.primary).waitForExistence(timeout: 2) { tapID(AX.workout.finish) }
        shot("logger-finish-modal")
        if el(AX.modal.primary).waitForExistence(timeout: 3) { tapID(AX.modal.primary) }
        let summary = CompletionPage(t: self)
        summary.waitForIt()
        shot("logger-summary-bodymap", wait: 2.5)
        summary.openComposer()
        shot("logger-composer", wait: 1.5)
        tapID(AX.completion.cta)                                   // POST
        waitUntilGone(el(AX.completion.title), "the summary after posting", timeout: 30)
        shot("logger-after-post", wait: 1.5)
        flush("logger")
    }

    // MARK: Paywall (opened, never bought)

    func testPaywall() throws {
        try begin(LaunchConfig(email: LaunchConfig.uniqueEmail("fp"), scenario: .busy, weeks: 4))
        TabBar(t: self).more()
        scrollTo(el(AX.supernova.banner))
        tapID(AX.supernova.banner)               // the free banner grows into the paywall; nothing is bought
        waitForPaywall()
        shot("paywall", wait: 2.0)
        if press(AX.supernova.free) { shot("paywall-closed") }
        flush("paywall")
    }

    // MARK: Social: challenges, Add friends, profiles

    private func signInAsFrankie() throws {
        try begin(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
        require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
        SocialPage(t: self).open()
    }

    func testChallenges() throws {
        try signInAsFrankie()
        tapID(AX.social.tabChallenges)
        require(el(AX.social.challengeName), "the global challenge card", timeout: 45)
        shot("challenges")
        // Create → NEW CHALLENGE steps.
        scrollTo(el(AX.row("Create challenge")))
        if press(AX.row("Create challenge")) {
            shot("challenge-create-1")
            type("Review Volume", into: AX.row("Challenge name")); dismissKeyboard()
            shot("challenge-create-named")
            tapBack(); if el(AX.row("Create challenge")).exists == false { tapBack() }
        }
        // Sent: invite a friend to Bench Club.
        let club = labelContaining("Bench Club")
        scrollTo(club)
        tap(club, "Bench Club")
        require(el(AX.nav.back), "the friend board", timeout: 20)
        shot("challenge-friend-board")
        if labelContaining("+ INVITE").waitForExistence(timeout: 3) {
            tap(labelContaining("+ INVITE"), "invite")
            shot("challenge-invite")
            if press(AX.social.pill("INVITE")) { shot("challenge-sent") }
        }
        flush("challenges")
    }

    func testPendingInvitesAndAddFriendAndProfiles() throws {
        try signInAsFrankie()
        // Pending: Activity's NEEDS YOU (friend requests and challenge invites).
        if press(AX.social.bell) { shot("activity-pending", wait: 1.8) ; tapBack() }
        // Your profile, Add friends, a friend's profile.
        if press(AX.social.profile) {
            shot("your-profile", wait: 2.0)
            let find = app.buttons["Find friends"]
            if find.waitForExistence(timeout: 4) {
                find.tap(); shot("add-friends", wait: 2.0)
                tapBack()
            }
            let tess = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tess Three'")).firstMatch
            if tess.waitForExistence(timeout: 4) { tess.tap(); shot("friend-profile", wait: 2.5) }
        }
        flush("people")
    }
}
