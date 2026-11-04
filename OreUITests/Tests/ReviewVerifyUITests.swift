import XCTest

/// Re-checks, one by one, the elements the crawl could not judge (it cannot tell "changed in place" from "did nothing").
/// Taps each by identifier and records what is on screen afterwards to `<REVIEW_DIR>/verify.jsonl`; never asserts.
final class ReviewVerifyUITests: UITestCase {
    private func texts() -> Set<String> {
        Set(app.staticTexts.allElementsBoundByIndex.prefix(80).compactMap { $0.exists ? $0.label : nil }.filter { !$0.isEmpty })
    }

    private func record(_ tab: String?, _ id: String, _ dir: String, _ file: inout [String]) {
        if let tab, el(tab).waitForExistence(timeout: 20) { el(tab).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        let e = el(id)
        guard e.waitForExistence(timeout: 6) else { file.append(json(id, "NOT FOUND", "", "")); return }
        let before = texts()
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()     // by coordinate: some targets are too small to be "hittable"
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        let after = texts()
        let back = el(AX.nav.back).exists
        let changed = before.symmetricDifference(after).count
        let name = id.replacingOccurrences(of: ".", with: "-")
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/verify-\(name).png"))
        file.append(json(id, changed > 0 || back ? "RESPONDS" : "NOTHING", "height=\(Int(e.frame.height)) back=\(back) labelsChanged=\(changed)", Array(after.subtracting(before)).prefix(6).joined(separator: " / ")))
    }

    private func json(_ id: String, _ result: String, _ detail: String, _ new: String) -> String {
        let d = try? JSONSerialization.data(withJSONObject: ["id": id, "result": result, "detail": detail, "appeared": new], options: [.sortedKeys])
        return d.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    /// One element per test (a fresh launch each), so nothing left open by one tap can catch the next.
    private func verifyOne(_ tab: String, _ id: String) throws {
        let dir = ProcessInfo.processInfo.environment["REVIEW_DIR"] ?? ""
        guard !dir.isEmpty else { throw XCTSkip("set REVIEW_DIR") }
        launch(LaunchConfig(email: LaunchConfig.uniqueEmail("vf"), scenario: .busy, weeks: 8))
        require(el(AX.home.startWorkout), "Home is up")
        var out: [String] = []
        record(tab, id, dir, &out)
        let f = "\(dir)/verify-\(id).jsonl"
        try out.joined(separator: "\n").write(toFile: f, atomically: true, encoding: .utf8)
    }

    func testVerifyNotToday() throws { try verifyOne(AX.tab.home, AX.home.notToday) }
    func testVerifyLedgerRow() throws { try verifyOne(AX.tab.home, AX.home.ledgerRow(0)) }
}
