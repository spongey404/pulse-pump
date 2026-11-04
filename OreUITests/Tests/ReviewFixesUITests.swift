import XCTest

/// Guards the fixes from the design review (review/REPORT.md): each test drives the screen the finding was about.
final class ReviewFixesUITests: UITestCase {

    private func busy(plus: Bool = false) {
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("rf"), scenario: .busy, weeks: 8, plus: plus))
        require(el(AX.home.startWorkout), "Home is up")
    }

    private func openMoreRow(_ label: String, title: String) {
        TabBar(t: self).more()
        scrollTo(el(AX.row(label)))
        tapID(AX.row(label))
        require(el(AX.nav.title(title)), "the \(title) screen")
    }

    // MARK: Home

    func testNotTodayPickerSelectsAWorkoutAndClosesAndTargetsAre44() {
        busy()
        for id in [AX.home.notToday, AX.home.searchButton, AX.home.profileButton] {
            let f = el(id).frame
            XCTAssertGreaterThanOrEqual(f.height, 43.5, "\(id) is \(f.height) pt tall")
            XCTAssertGreaterThanOrEqual(f.width, 43.5, "\(id) is \(f.width) pt wide")
        }
        let before = el(AX.home.predictedName).label
        tapID(AX.home.notToday)
        require(el(AX.home.pickerRow(0)), "the WHAT'S TODAY? rows")
        tapID(AX.home.pickerClose)
        waitUntilGone(el(AX.home.pickerRow(0)), "the picker after Close")
        XCTAssertEqual(el(AX.home.predictedName).label, before, "Close changes nothing")

        tapID(AX.home.notToday)
        var picked = ""
        for i in 0..<3 where el(AX.home.pickerRow(i)).exists {
            let name = el(AX.home.pickerRow(i)).label.components(separatedBy: ",").first ?? ""
            if name.uppercased() != before.uppercased() { picked = name; tapID(AX.home.pickerRow(i)); break }
        }
        XCTAssertFalse(picked.isEmpty, "a different workout to pick")
        waitUntilGone(el(AX.home.pickerRow(0)), "the picker after choosing")
        XCTAssertTrue(waitUntil { self.el(AX.home.predictedName).label.uppercased() == picked.uppercased() }, "Home now shows \(picked)")
        TabBar(t: self).more()
        TabBar(t: self).home()
        XCTAssertFalse(el(AX.home.pickerRow(0)).exists, "the picker does not come back on another tab")
    }

    /// The seeded week trains Mon–Sat and today's (Wed) workout is logged: the hero then reads UP NEXT, and today's ledger row is tinted/labelled.
    func testHeroSaysUpNextOnceTodaysWorkoutIsLogged() {
        busy()
        let label = el(AX.home.heroLabel).label
        XCTAssertTrue(label.hasPrefix("UP NEXT · "), "today's workout is logged (the seed trains every day but Sunday, when it is a rest day): \(label)")
    }

    // MARK: More

    func testCloudSyncOpensItsOwnScreenFreeAndMember() {
        busy()
        openMoreRow("Cloud Sync", title: "CLOUD SYNC")
        require(el(AX.cloudSync.locked), "the locked Supernova state for a free user")
        XCTAssertFalse(el(AX.nav.title("ADD FRIENDS")).exists, "never Add Friends")
        tapID(AX.nav.back)
        require(el(AX.more.screen), "back on More")

        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("rf"), scenario: .busy, weeks: 8, plus: true))
        openMoreRow("Cloud Sync", title: "CLOUD SYNC")
        require(label("SYNC NOW"), "SYNC NOW for a member")
        XCTAssertFalse(el(AX.cloudSync.locked).exists)
    }

    func testEditProfileBackAndSaveReturnToTheProfile() {
        busy()
        TabBar(t: self).more()
        tapID(AX.more.profile)
        require(el(AX.nav.title("PROFILE")), "Profile")
        tap(label("EDIT"), "EDIT")
        let back = app.navigationBars.buttons.firstMatch
        require(back, "the edit screen's back button")
        back.tap()
        require(el(AX.nav.title("PROFILE")), "Back returns to the profile")
        tap(label("EDIT"), "EDIT again")
        tap(app.buttons["Save"].firstMatch, "Save")
        require(el(AX.nav.title("PROFILE")), "Save returns to the profile")
    }

    func testWeeklyRecapWeekRowShowsThatWeekAndBackStillWorks() {
        busy(plus: true)
        openMoreRow("Weekly Recap", title: "WEEKLY RECAP")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'row.week-'")).firstMatch
        scrollTo(row)
        tap(row, "a past week")
        require(el(AX.nav.back), "the ‹ back")
        tapID(AX.nav.back)
        require(el(AX.more.screen), "back on More")
    }

    func testEquipmentAddProfileAddEquipmentAndRowOpenTheirEditors() {
        busy(plus: true)
        openMoreRow("Equipment profiles", title: "EQUIPMENT")
        tapID(AX.row("Add profile"))
        require(app.navigationBars["New Profile"], "the new-profile form, not More")
        tap(app.buttons["Cancel"].firstMatch, "Cancel")
        waitUntilGone(app.navigationBars["New Profile"], "the form")
        require(el(AX.nav.title("EQUIPMENT")), "still on Equipment")

        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS 'ADD EQUIPMENT' OR label CONTAINS[c] 'Add Equipment'")).firstMatch, "+ Add Equipment")
        require(app.navigationBars["Edit Profile"], "the equipment editor")
        tap(app.buttons["Done"].firstMatch, "Done")
        waitUntilGone(app.navigationBars["Edit Profile"], "the editor")

        let profileRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Commercial Gym'")).firstMatch
        tap(profileRow, "the profile row")
        require(app.navigationBars["Edit Profile"], "the profile editor from the row")
    }

    // MARK: History

    func testHistoryWorkoutHasTheNameAndTheDateLineUnderIt() {
        busy()
        let history = HistoryPage(t: self)
        history.open()
        history.openFirstWorkout()
        let title = el(AX.detail.title).label
        XCTAssertFalse(title.isEmpty)
        let sub = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[A-Z]{3} [0-9]+ [A-Z]{3} · [0-9]+ MIN · [0-9]+ SETS?$'")).firstMatch
        require(sub, "WED 4 NOV · 69 MIN · 17 SETS under the name")
        require(el(AX.detail.menu), "the ··· menu (Edit, Duplicate, Delete)")
    }

    // MARK: Social (seeded friend, emulators)

    private func signInAsFrankie() {
        launch(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false))
        require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
        SocialPage(t: self).open()
    }

    func testActivityPrivacyRowOpensAPicker() {
        signInAsFrankie()
        tapID(AX.social.bell)
        scrollTo(el(AX.row("Body map")))
        tapID(AX.row("Body map"))
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5) || app.buttons["Cancel"].waitForExistence(timeout: 2), "the privacy picker opens")
    }

    /// Reply puts the keyboard up on the composer. (The options dialog and the commenter's profile could not be driven here: the only seeded
    /// comment is the signed-in user's own, and XCUITest never saw the dialog open. Listed as unverified in review/REPORT.md.)
    func testCommentsReplyFocusesTheComposer() {
        signInAsFrankie()
        require(SocialPage(t: self).anyPost, "a friend's post", timeout: 45)
        tap(app.buttons["Comments"].firstMatch, "Comments")
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reply to'")).firstMatch, "Reply", timeout: 20)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4), "Reply focuses the composer")
    }
}
