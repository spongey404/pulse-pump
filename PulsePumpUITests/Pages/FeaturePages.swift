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

    func createProgram(name: String, days: Int, exerciseSearch: String) {
        t.tapID(AX.programs.newProgram)
        t.type(name, into: AX.programs.createName)
        t.dismissKeyboard()
        t.tapID(AX.programs.createDays(days))
        addExercise(buttonID: AX.programs.createAddExercise, search: exerciseSearch)
        t.tapID(AX.programs.createSave)
        t.require(t.el(AX.programs.screen), "Programs list after saving")
    }

    /// Opens the picker from `buttonID`, searches and takes the first result.
    func addExercise(buttonID: String, search: String) {
        t.dismissKeyboard()
        t.tapID(buttonID)
        t.type(search, into: AX.picker.search)
        let first = t.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'picker.row.'")).firstMatch
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

    /// Taps inside the front figure where the chest is drawn. The map is vector art laid out as
    /// `min(w/160, h/292)` over a 160x292 viewBox shifted by (-20,-10) (BodyMap2DView); the chest path spans x 70..99, y 56..92.
    func tapChestOnFrontFigure() {
        let figure = t.require(t.el(AX.body.figureFront), "front body map")
        let f = figure.frame
        let s = min(f.width / 160, f.height / 292)
        let ox = (f.width - 160 * s) / 2
        let x = ox + (84 - 20) * s
        let y = (72 - 10) * s
        figure.coordinate(withNormalizedOffset: CGVector(dx: x / f.width, dy: y / f.height)).tap()
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
        let row = t.el(AX.row("Sign Out"))
        t.scrollTo(row)
        row.tap()
        t.tap(t.app.alerts.buttons["Sign Out"].firstMatch, "Sign Out in the alert")
    }
}

struct SocialPage {
    let t: UITestCase

    func open() { TabBar(t: t).social() }

    var anyPost: XCUIElement {
        t.app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'feed.post.'")).firstMatch
    }
}
