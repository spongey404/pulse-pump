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

    /// + → Blank → a name → CREATE PROGRAM. Lands on the new program's page (its first workout is empty).
    func createBlankProgram(name: String, days: Int? = nil) {
        t.tapID(AX.programs.add)
        t.tapID(AX.programs.template("blank"))
        t.type(name, into: AX.programs.createName)
        t.dismissKeyboard()
        if let days { t.tapID(AX.programs.createDays(days)) }
        t.tapID(AX.programs.createSave)
        t.require(t.el(AX.programs.editProgram), "the new program's page")
    }

    /// From a workout's edit mode: ADD EXERCISE, search, the first result's + ADD, then the docked ADD button.
    func addExercises(search: String) {
        t.dismissKeyboard()
        t.tapID(AX.programs.workoutAddExercise)
        t.type(search, into: AX.programs.pickSearch)
        let add = t.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'programs.pick.add.'")).firstMatch
        if !add.waitForExistence(timeout: 4) {
            // The lift has types ("5 TYPES ›"): open the group, then pick one.
            let group = t.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'programs.pick.row.'")).firstMatch
            t.tap(group, "the first group for '\(search)'")
        }
        t.tap(add, "the first + ADD for '\(search)'")
        t.tapID(AX.programs.pickDock)
    }

    /// Open the program, EDIT, DELETE PROGRAM, confirm.
    func deleteProgram(_ name: String) {
        t.tap(row(name), "program row \(name)")
        t.tapID(AX.programs.editProgram)
        t.scrollTo(t.el(AX.programs.deleteProgram))
        t.tapID(AX.programs.deleteProgram)
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
