import XCTest

/// Base class: one fresh launch per test, failure screenshots + UI hierarchy attached to the result bundle, and a
/// handler for the system dialogs (notifications, keyboard tips) that would otherwise block taps.
class UITestCase: XCTestCase {
    let app = XCUIApplication()
    /// The identity (email) the app is signed in as after `launch`. Static: tests share one process and one
    /// simulator, so the next test can tell whether a sign-out is needed before its own account takes over.
    nonisolated(unsafe) static var signedInEmail: String?
    var currentConfig = LaunchConfig(email: nil)

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        // Notification prompt right after onboarding; "Allow" keeps the rest-timer paths realistic.
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow", "OK", "Continue", "Not Now", "Don’t Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        if let run = testRun, run.failureCount > 0 {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Failure screenshot"
            shot.lifetime = .keepAlways
            add(shot)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "UI hierarchy at failure"
            tree.lifetime = .keepAlways
            add(tree)
        }
        app.terminate()
    }

    /// Attaches a named screenshot to the result bundle (kept for every run; handy when a step needs a second look).
    func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: Element lookup

    /// Any element type with this accessibility identifier (a Text, a Button and a TextField are all found the same way).
    func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Taps the back button of the page on top (a pushed page leaves the one underneath in the hierarchy, offscreen).
    func tapBack(file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if let back = els(AX.nav.back).allElementsBoundByIndex.last(where: { $0.exists && $0.isHittable }) { back.tap(); return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("no hittable back button", file: file, line: line)
    }

    func els(_ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: id)
    }

    /// A button or static text by its visible label (for system UI and one-off texts that carry no identifier).
    func label(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    func labelContaining(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    // MARK: Waiting (no sleeps: every wait is an expectation on app state)

    @discardableResult
    func require(_ element: XCUIElement, _ what: String = "", timeout: TimeInterval = 15,
                 file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        if !element.waitForExistence(timeout: timeout) {
            XCTFail("Expected \(what.isEmpty ? element.description : what) to appear within \(Int(timeout))s",
                    file: file, line: line)
        }
        return element
    }

    func waitUntilGone(_ element: XCUIElement, _ what: String = "", timeout: TimeInterval = 15,
                       file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        if XCTWaiter().wait(for: [gone], timeout: timeout) != .completed {
            XCTFail("Expected \(what.isEmpty ? element.description : what) to disappear within \(Int(timeout))s",
                    file: file, line: line)
        }
    }

    /// Waits until the element's label (static texts, buttons) satisfies the predicate.
    func waitForLabel(_ element: XCUIElement, matching format: String, _ arg: String, timeout: TimeInterval = 15,
                      file: StaticString = #filePath, line: UInt = #line) {
        require(element, timeout: timeout, file: file, line: line)
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label \(format) %@", arg), object: element)
        if XCTWaiter().wait(for: [match], timeout: timeout) != .completed {
            XCTFail("Expected label of \(element.description) \(format) '\(arg)', but it is '\(element.label)'",
                    file: file, line: line)
        }
    }

    /// True when the element's label stops equalling `from` within the time (a non-failing wait).
    func labelChanges(_ element: XCUIElement, from: String, within seconds: TimeInterval) -> Bool {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", from), object: element)
        return XCTWaiter().wait(for: [changed], timeout: seconds) == .completed
    }

    func waitForLabelNotContaining(_ element: XCUIElement, _ text: String, timeout: TimeInterval = 15,
                                   file: StaticString = #filePath, line: UInt = #line) {
        require(element, timeout: timeout, file: file, line: line)
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label CONTAINS[c] %@)", text), object: element)
        if XCTWaiter().wait(for: [match], timeout: timeout) != .completed {
            XCTFail("Expected label of \(element.description) not to contain '\(text)', but it is '\(element.label)'",
                    file: file, line: line)
        }
    }

    func waitForValue(_ element: XCUIElement, equals value: String, timeout: TimeInterval = 15,
                      file: StaticString = #filePath, line: UInt = #line) {
        require(element, timeout: timeout, file: file, line: line)
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        if XCTWaiter().wait(for: [match], timeout: timeout) != .completed {
            XCTFail("Expected value of \(element.description) to be '\(value)', but it is '\(String(describing: element.value))'",
                    file: file, line: line)
        }
    }

    func waitForCount(_ query: XCUIElementQuery, _ format: String = "==", _ count: Int, timeout: TimeInterval = 15,
                      file: StaticString = #filePath, line: UInt = #line) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count \(format) %d", count), object: query)
        if XCTWaiter().wait(for: [match], timeout: timeout) != .completed {
            XCTFail("Expected \(query.description) count \(format) \(count), but it is \(query.count)", file: file, line: line)
        }
    }

    // MARK: Interaction

    /// Taps "Allow" on a pending system permission dialog (notifications after onboarding). Returns whether one was shown.
    @discardableResult
    func dismissSystemAlert() -> Bool {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        guard alert.exists else { return false }
        for label in ["Allow", "OK", "Continue", "Not Now"] where alert.buttons[label].exists {
            alert.buttons[label].tap()
            return true
        }
        return false
    }

    /// Waits for the Supernova paywall (shown once, after onboarding). The notification permission prompt can land on top of
    /// it and hides the app's elements from queries until it is answered, so it is dismissed while waiting.
    func waitForPaywall(timeout: TimeInterval = 30, file: StaticString = #filePath, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            dismissSystemAlert()
            if el(AX.supernova.start).exists { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTFail("the Supernova paywall did not appear within \(Int(timeout))s\n\(app.debugDescription.prefix(3500))", file: file, line: line)
    }

    /// iOS offers to save a password after a password field was used ("Save Password?"); decline it if shown.
    func declineSavePasswordPrompt(timeout: TimeInterval = 4) {
        let notNow = app.buttons["Not Now"].firstMatch
        if notNow.waitForExistence(timeout: timeout) { notNow.tap() }
    }

    /// Waits for the element to exist and be hittable, then taps it.
    func tap(_ element: XCUIElement, _ what: String = "", timeout: TimeInterval = 15,
             file: StaticString = #filePath, line: UInt = #line) {
        require(element, what, timeout: timeout, file: file, line: line)
        dismissSystemAlert()
        element.tap()
    }

    func tapID(_ id: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        tap(el(id), id, timeout: timeout, file: file, line: line)
    }

    /// Taps the field, clears nothing (fields start empty) and types.
    func type(_ text: String, into id: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = el(id)
        focus(field, id, file: file, line: line)
        field.typeText(text)
    }

    /// Taps a text field until it holds keyboard focus (a tap during a keyboard transition can miss).
    func focus(_ field: XCUIElement, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 {
            tap(field, id, file: file, line: line)
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            if XCTWaiter().wait(for: [focused], timeout: 3) == .completed { return }
        }
    }

    /// Replaces a field's content (select-all via a long press is flaky; deleting the existing characters is not).
    func replaceText(in id: String, with text: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = el(id)
        focus(field, id, file: file, line: line)
        let current = (field.value as? String) ?? ""
        if !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    /// Dismisses the keyboard if it is up (tap on a neutral status-bar area is unreliable; the return key is not).
    func dismissKeyboard() {
        let kb = app.keyboards.firstMatch
        guard kb.exists else { return }
        for key in ["Done", "Return", "return"] where kb.buttons[key].exists {
            kb.buttons[key].tap()
            return
        }
        // Number pads have no return key: scroll a little to resign first responder.
        app.swipeDown()
    }

    /// Scrolls the nearest scroll view until the element is hittable.
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8, file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        if !(element.exists && element.isHittable) {
            XCTFail("Could not scroll \(element.description) into view", file: file, line: line)
        }
    }
}
