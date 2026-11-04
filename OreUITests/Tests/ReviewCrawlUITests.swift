import XCTest

/// The design review (run through `bin/test-ui.sh --device "iPhone 15"` with `REVIEW_DIR=<dir>`): crawls every tab, taps every
/// interactive element, saves a screenshot of every distinct screen and the audit log. See `ReviewKit`.
///
///   REVIEW_DIR=review TEST_RUNNER_REVIEW_DIR=review bin/test-ui.sh --device "iPhone 15" --only ReviewCrawlUITests
class ReviewCrawlUITests: UITestCase {
    var dir: String { ProcessInfo.processInfo.environment["REVIEW_DIR"] ?? "" }
    var dark: Bool { false }
    var appearance: String { dark ? "dark" : "light" }

    /// The tabs a crawl visits, with the identifier of the tab button.
    static let tabs: [(name: String, id: String)] = [("home", AX.tab.home), ("programs", AX.tab.programs), ("social", AX.tab.social),
                                                     ("body", AX.tab.body), ("more", AX.tab.more)]

    func prepare(_ config: LaunchConfig, state: String) throws -> ReviewKit {
        guard !dir.isEmpty else { throw XCTSkip("set REVIEW_DIR (and TEST_RUNNER_REVIEW_DIR) to run the design review") }
        // Dark mode is not crawled again (it would tap every element twice): ReviewDarkReplayUITests re-visits each screen the light crawl found.
        if dark { throw XCTSkip("dark: see ReviewDarkReplayUITests") }
        launch(config)
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        return ReviewKit(app: app, dir: dir, appearance: appearance, state: state)
    }

    func crawlTabs(_ kit: ReviewKit, tabs: [String], maxDepth: Int = 3) {
        kit.maxDepth = maxDepth
        kit.root = { [unowned self] in self.relaunchKeepingAccount() }
        let only = ProcessInfo.processInfo.environment["REVIEW_TABS"]?.split(separator: ",").map(String.init)
        for name in tabs where only == nil || only!.contains(name) {
            guard let tab = Self.tabs.first(where: { $0.name == name }) else { continue }
            let tabItem = ReviewKit.Item(kind: "button", id: tab.id, label: tab.name, x: 0, y: 0, w: 0, h: 0, scrolls: 0)
            kit.reroute = { [unowned self] screen in self.replay(screen.path, tabs: Self.tabs) }
            tapID(tab.id)
            let shot = kit.shot(name)
            kit.screens.append(ReviewKit.Screen(key: name, title: name, shot: shot, parent: "", via: "tab", path: [tabItem], labels: kit.labels(), depth: 0))
            kit.crawl(name, via: "tab", parent: "", path: [tabItem], depth: 0)
            kit.write(to: "audit-\(kit.state)-\(kit.appearance).jsonl")
        }
    }

    /// Goes to a screen again: the tab, then the recorded taps.
    func replay(_ path: [ReviewKit.Item], tabs: [(name: String, id: String)]) {
        guard let first = path.first else { return }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        if !el(first.id).waitForExistence(timeout: 5) { relaunchKeepingAccount() }
        tapID(first.id)
        for step in path.dropFirst() {
            for _ in 0..<step.scrolls { app.swipeUp(velocity: .slow); RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
            origin.withOffset(CGVector(dx: step.x, dy: step.y)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        }
    }

    // MARK: Crawls

    /// A trained user without Supernova: the audit.
    func testCrawlActiveFree() throws {
        let kit = try prepare(LaunchConfig(email: LaunchConfig.uniqueEmail("rv"), scenario: .busy, weeks: 8), state: "free-active")
        crawlTabs(kit, tabs: ["home", "programs", "body", "more"])
    }

    /// A member: the screens where Supernova changes what is shown.
    func testCrawlActiveMember() throws {
        let kit = try prepare(LaunchConfig(email: LaunchConfig.uniqueEmail("rv"), scenario: .busy, weeks: 8, plus: true), state: "member-active")
        crawlTabs(kit, tabs: ["home", "programs", "body", "more"], maxDepth: 2)
    }

    /// A brand-new account: empty states.
    func testCrawlNewUser() throws {
        let kit = try prepare(LaunchConfig(email: LaunchConfig.uniqueEmail("rv"), scenario: .newUser), state: "new-user")
        crawlTabs(kit, tabs: ["home", "programs", "body", "more"], maxDepth: 2)
    }

    /// The same week's sets on Home, Body and History must agree; writes `consistency-*.json` for the report.
    func testConsistencyAcrossScreens() throws {
        let kit = try prepare(LaunchConfig(email: LaunchConfig.uniqueEmail("rv"), scenario: .busy, weeks: 8), state: "free-active")
        let home = HomePage(t: self)
        let homeSets = home.sets
        TabBar(t: self).body()
        let bodySets = BodyPage(t: self).totalSets
        tapID(AX.tab.more); tapID(AX.row("History"))
        tapID(AX.history.modeCalendar)
        var cal = Calendar(identifier: .iso8601); cal.timeZone = .current
        let week = cal.component(.weekOfYear, from: Date())
        tapID(AX.calendar.week(week))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        var historySets = 0
        for card in els(AX.calendar.cardOpen).allElementsBoundByIndex where card.exists {
            if let m = card.label.range(of: #"(\d+) SETS"#, options: .regularExpression) {
                historySets += Int(card.label[m].split(separator: " ")[0]) ?? 0
            }
        }
        let result: [String: Any] = ["homeSets": homeSets, "bodySets": bodySets, "historyWeekSets": historySets,
                                     "consistent": homeSets == bodySets && bodySets == historySets]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: "\(kit.dir)/consistency-sets.json"))
        XCTAssertEqual(homeSets, bodySets, "Home's weekly sets and Body's agree")
        XCTAssertEqual(bodySets, historySets, "Body's weekly sets and the History week cards agree")
    }

    /// The seeded friend: the Social tab with real friends, posts and challenges (emulator seed).
    func testCrawlSocial() throws {
        let kit = try prepare(LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false), state: "social")
        require(el(AX.tab.home), "Home for the seeded user", timeout: 90)
        crawlTabs(kit, tabs: ["social"])
    }
}

final class ReviewCrawlDarkUITests: ReviewCrawlUITests {
    override var dark: Bool { true }
}

/// Dark mode for every screen the light crawl found: reads `audit-<state>-light.jsonl`, goes to each screen again by its recorded taps with
/// the device in dark, and saves `<NN>-<screen>-<state>-dark.png` to `<REVIEW_DIR>/dark/`. Run after the light crawl.
final class ReviewDarkReplayUITests: ReviewCrawlUITests {
    private func replayState(_ state: String, _ config: LaunchConfig, signedIn: Bool = false) throws {
        guard !dir.isEmpty else { throw XCTSkip("set REVIEW_DIR") }
        guard let text = try? String(contentsOfFile: "\(dir)/audit-\(state)-light.jsonl", encoding: .utf8) else { throw XCTSkip("no light audit for \(state)") }
        let screens: [(key: String, title: String, path: [ReviewKit.Item])] = text.split(separator: "\n").compactMap { line in
            guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: String], o["type"] == "screen",
                  let p = o["path"], let items = try? JSONDecoder().decode([ReviewKit.Item].self, from: Data(p.utf8)) else { return nil }
            return (o["key"] ?? "", o["title"] ?? "", items)
        }
        let out = "\(dir)/dark"
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        XCUIDevice.shared.appearance = .dark
        launch(config)
        if signedIn { require(el(AX.tab.home), "Home for the seeded user", timeout: 90) }
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        var n = 0
        for s in screens {
            n += 1
            relaunchKeepingAccount()
            replay(s.path, tabs: Self.tabs)
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
            let name = String(format: "%@/%02d-%@-%@-dark.png", out, n, ReviewKit.slug(s.key.replacingOccurrences(of: ">", with: "-")), state)
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: name))
        }
    }

    func testReplayFree() throws { try replayState("free-active", LaunchConfig(email: LaunchConfig.uniqueEmail("rd"), scenario: .busy, weeks: 8)) }
    func testReplayMember() throws { try replayState("member-active", LaunchConfig(email: LaunchConfig.uniqueEmail("rd"), scenario: .busy, weeks: 8, plus: true)) }
    func testReplayNewUser() throws { try replayState("new-user", LaunchConfig(email: LaunchConfig.uniqueEmail("rd"), scenario: .newUser)) }
    func testReplaySocial() throws {
        try replayState("social", LaunchConfig(email: "friend1@example.com", password: "password", autoOnboard: false), signedIn: true)
    }
    override func testConsistencyAcrossScreens() throws { throw XCTSkip("light only") }
    override func testCrawlActiveFree() throws { throw XCTSkip("replay only") }
    override func testCrawlActiveMember() throws { throw XCTSkip("replay only") }
    override func testCrawlNewUser() throws { throw XCTSkip("replay only") }
    override func testCrawlSocial() throws { throw XCTSkip("replay only") }
}
