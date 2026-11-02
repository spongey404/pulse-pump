import XCTest

/// More › History and the workout detail it opens.
struct HistoryPage {
    let t: UITestCase

    func open() {
        TabBar(t: t).more()
        t.tapID(AX.row("History"))
        t.require(t.el(AX.nav.title("HISTORY")), "History screen")
    }

    var firstRow: XCUIElement { t.els(AX.history.row).firstMatch }

    func openFirstWorkout() {
        t.tap(firstRow, "first history row")
        t.require(t.el(AX.detail.title), "workout detail")
    }

    func back() { t.tapID(AX.nav.back) }

    /// The "Delete Workout?" confirmation is a system action sheet.
    func confirmDelete() {
        let delete = t.app.buttons["Delete"].firstMatch
        t.tap(delete, "Delete in the confirmation sheet")
    }

    func deleteViaDetailMenu() {
        t.tapID(AX.detail.menu)
        t.tap(t.app.buttons["Delete"].firstMatch, "Delete menu item")
        confirmDelete()
    }
}

struct ProgramsPage {
    let t: UITestCase

    func open() { TabBar(t: t).programs() }

    func row(_ name: String) -> XCUIElement { t.el(AX.programs.row(name)) }

    /// `exerciseSearch` adds an exercise from the New Program screen's own picker.
    func createProgram(name: String, days: Int, exerciseSearch: String? = nil) {
        t.tapID(AX.programs.newProgram)
        t.type(name, into: AX.programs.createName)
        t.dismissKeyboard()
        t.tapID(AX.programs.createDays(days))
        if let exerciseSearch { addExercise(buttonID: AX.programs.createAddExercise, search: exerciseSearch) }
        t.tapID(AX.programs.createSave)
        t.require(t.el(AX.programs.screen), "Programs list after saving")
    }

    /// Opens the picker from `buttonID`, searches and takes the first result.
    func addExercise(buttonID: String, search: String) {
        t.dismissKeyboard()
        t.tapID(buttonID)
        t.type(search, into: AX.picker.search)
        let first = t.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'picker.row.'")).firstMatch
        t.tap(first, "first picker result for '\(search)'")
    }

    func swipeToDelete(_ name: String) {
        t.require(row(name), "program row \(name)").swipeLeft()
        t.tapID(AX.swipeDelete)
        t.tapID(AX.modal.confirm)
    }
}

struct BodyPage {
    let t: UITestCase

    func open() { TabBar(t: t).body() }

    var totalSets: Int { Int(t.require(t.el(AX.body.totalSets), "hero total").label) ?? -1 }

    /// Taps inside the front figure where the chest is drawn: the artwork is 1640 x 2360 and fills the element; the chest
    /// spans x 603..1037, y 693..882 (BodyMap geometry), so (700, 790) is on a pec.
    func tapChestOnFrontFigure() {
        let figure = t.require(t.el(AX.body.figureFront), "front body map")
        figure.coordinate(withNormalizedOffset: CGVector(dx: 700.0 / 1640, dy: 790.0 / 2360)).tap()
    }
}

struct SettingsPage {
    let t: UITestCase

    func open() {
        TabBar(t: t).more()
        t.tapID(AX.row("Settings"))
        t.require(t.el(AX.nav.title("SETTINGS")), "Settings screen")
    }

    /// Picks `option` from a menu row (a UIKit menu; options are buttons in the app's menu).
    func choose(_ option: String, inMenu label: String) {
        t.tapID(AX.menu(label))
        t.tap(t.app.buttons[option].firstMatch, "menu option \(option)")
    }

    func scrollToRow(_ label: String) {
        t.scrollTo(t.el(AX.row(label)))
    }

    /// More hub / Settings sign out (alert).
    func signOutFromMoreHub() {
        TabBar(t: t).more()
        let row = t.el(AX.row("Sign out"))
        t.scrollTo(row)
        row.tap()
        t.tap(t.el(AX.more.signOutConfirm), "SIGN OUT in the sheet")
    }
}

struct SocialPage {
    let t: UITestCase

    func open() { TabBar(t: t).social() }

    var anyPost: XCUIElement {
        t.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'feed.post.'")).firstMatch
    }
}
