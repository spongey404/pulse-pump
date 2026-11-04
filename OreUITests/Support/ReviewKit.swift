import XCTest

/// The design-review harness: a depth-first crawl of the running app that taps every interactive element on every screen, records where
/// each one leads, saves a screenshot of every distinct screen (`review/<NN>-<screen>-<state>-<light|dark>.png`) and writes the audit as
/// JSON lines for `review/REPORT.md`. It only drives the real UI (no app-side hooks).
///
/// Taps are by coordinate (the element's centre when it was found), so a screen must look the same after "back" for the next one to land.
/// After every tap that navigated, the crawl goes back (back button, Done/Close, swipe down for a sheet) and checks the screen is the
/// one it left; if it can't get back that is a TRAP, and the crawl re-routes to the screen from a fresh launch.
final class ReviewKit {
    struct Item: Codable {
        var kind: String            // button | switch | cell | link
        var id: String
        var label: String
        var x: Double
        var y: Double
        var w: Double
        var h: Double
        var scrolls: Int
    }

    struct Entry: Codable {
        var screen: String
        var element: String
        var kind: String
        var id: String
        var status: String          // OK | DEAD END | PLACEHOLDER | FAKE AFFORDANCE | TRAP | SKIPPED
        var destination: String
        var shot: String?
        var note: String
    }

    struct Screen: Codable {
        var key: String
        var title: String
        var shot: String
        var parent: String
        var via: String
        var path: [Item]
        var labels: [String]
        var depth: Int
    }

    let app: XCUIApplication
    let dir: String
    let appearance: String          // light | dark
    let state: String               // e.g. free-active
    nonisolated(unsafe) static var counter = 0
    var screens: [Screen] = []
    var entries: [Entry] = []
    private var visited = Set<String>()
    var maxDepth = 3
    var maxItemsPerScreen = 40
    var root: () -> Void = {}       // brings the app to the tab shell's Home (used to recover from a trap)
    var reroute: (Screen) -> Void = { _ in }

    init(app: XCUIApplication, dir: String, appearance: String, state: String) {
        self.app = app; self.dir = dir; self.appearance = appearance; self.state = state
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    // MARK: Screenshots

    @discardableResult
    func shot(_ screen: String, _ stateOverride: String? = nil, number: Int? = nil, settle: TimeInterval = 0.9) -> String {
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        if number == nil { ReviewKit.counter += 1 }
        let name = String(format: "%02d-%@-%@-%@.png", number ?? ReviewKit.counter, Self.slug(screen), stateOverride ?? state, appearance)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name)"))
        return name
    }

    static func slug(_ text: String) -> String {
        let s = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != ">" }).joined(separator: "-")
        return String(s.prefix(70))
    }

    // MARK: Reading the screen

    private var screenFrame: CGRect { app.windows.firstMatch.frame }

    /// Every visible interactive element, once (an outer element hides the buttons inside it that share its frame).
    func interactives(scrolls: Int = 0) -> [Item] {
        var items: [Item] = []
        let f = screenFrame
        func add(_ q: XCUIElementQuery, _ kind: String) {
            let all = q.allElementsBoundByIndex
            for e in all.prefix(120) where e.exists {
                let fr = e.frame
                guard fr.width > 8, fr.height > 8, fr.intersects(f.insetBy(dx: 0, dy: 40)), e.isHittable else { continue }
                items.append(Item(kind: kind, id: e.identifier, label: e.label, x: Double(fr.midX), y: Double(fr.midY), w: Double(fr.width), h: Double(fr.height), scrolls: scrolls))
            }
        }
        add(app.buttons, "button"); add(app.switches, "switch"); add(app.links, "link"); add(app.cells, "cell")
        // De-duplicate by centre; keep the one with an identifier or label.
        var seen: [String: Item] = [:]
        for it in items {
            let k = "\(Int(it.x / 6))-\(Int(it.y / 6))"
            if let old = seen[k] { if old.id.isEmpty && !it.id.isEmpty { seen[k] = it } } else { seen[k] = it }
        }
        return seen.values.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    }

    /// What is visible: the texts and button labels, trimmed of numbers that tick (clocks, counters).
    func labels() -> [String] {
        var out = Set<String>()
        let f = screenFrame.insetBy(dx: 0, dy: 20)
        for q in [app.staticTexts, app.buttons] {
            for e in q.allElementsBoundByIndex.prefix(150) where e.exists && e.frame.intersects(f) {
                let l = e.label.trimmingCharacters(in: .whitespaces)
                if !l.isEmpty, l.count < 80, l.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) == nil { out.insert(l) }
            }
        }
        return out.sorted()
    }

    func hasBack() -> Bool { app.buttons[AX.nav.back].exists && app.buttons[AX.nav.back].isHittable }
    func hasTabBar() -> Bool { app.buttons[AX.tab.home].exists && app.buttons[AX.tab.home].isHittable }

    /// The identifier-based page title ("HISTORY"), nil when the screen has none.
    private func titleID() -> String? {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'nav.title.'")).allElementsBoundByIndex
            .first { $0.exists && $0.isHittable }.map { String($0.identifier.dropFirst("nav.title.".count)) }
    }

    private func title() -> String {
        let t = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'nav.title.'")).allElementsBoundByIndex
            .first { $0.exists && $0.isHittable }
        if let t { return String(t.identifier.dropFirst("nav.title.".count)) }
        let big = app.staticTexts.allElementsBoundByIndex.filter { $0.exists && $0.frame.minY < 330 && $0.frame.minY > 40 && $0.frame.height > 22 }
        return big.first?.label ?? "screen"
    }

    // MARK: Safety

    /// Things the crawl never taps: they end the session, destroy data, spend money, post to other people, or leave the app.
    static let denied = try! NSRegularExpression(pattern: #"sign out|log out|delete|discard|remove|erase|reset|cancel membership|manage subscription|restore|subscribe|start .*free|train free|^post$|^post |send|invite|unfriend|unfollow|block|report|share|export|import|contact|terms|privacy policy|support|rate|app store|finish|start workout|continue|resume|log set|take photo|choose|camera|add friend|follow|accept|decline|mute|hide|^done$|keep going|go supernova|supernova|upgrade|open settings|tutorial|replay|walkthrough|workout in progress|add exercise|search your workout"#, options: [.caseInsensitive])

    func isDenied(_ it: Item) -> Bool {
        let text = it.label + " " + it.id
        return Self.denied.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: Tapping

    func tap(_ it: Item) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: it.x, dy: it.y)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        if app.state != .runningForeground { app.activate(); RunLoop.current.run(until: Date().addingTimeInterval(1.0)) }
    }

    func scrollDown(_ n: Int) { for _ in 0..<n { app.swipeUp(velocity: .slow); RunLoop.current.run(until: Date().addingTimeInterval(0.3)) } }
    func scrollTop() { for _ in 0..<4 { app.swipeDown(velocity: .fast) }; RunLoop.current.run(until: Date().addingTimeInterval(0.4)) }

    /// Goes back from a pushed page or dismisses a sheet/modal. True when the labels match `before` again.
    func goBack(to before: [String]) -> Bool {
        for attempt in 0..<4 {
            if same(labels(), before) { return true }
            if hasBack() { app.buttons[AX.nav.back].tap() }
            else if let close = firstClose() { close.tap() }
            else if attempt < 2 { app.swipeDown(velocity: .fast) }
            else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        return same(labels(), before)
    }

    /// If a live workout is on screen, discards it (cancel + confirm) and returns true.
    private func discardLiveWorkout() -> Bool {
        let title = app.descendants(matching: .any)[AX.workout.sessionTitle].firstMatch
        guard title.waitForExistence(timeout: 1.5) else { return false }
        let cancel = app.descendants(matching: .any)[AX.workout.cancel].firstMatch
        if cancel.waitForExistence(timeout: 3) {
            cancel.tap()
            let confirm = app.descendants(matching: .any)[AX.modal.primary].firstMatch
            if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        }
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)], timeout: 5)
        return true
    }

    private func firstClose() -> XCUIElement? {
        let names = ["Close", "Done", "DONE", "Cancel", "CANCEL", "Back", "×", "‹", "Dismiss", "KEEP GOING", "Not Now", "TRAIN FREE", "SKIP", "CLOSE"]
        for n in names {
            let b = app.buttons[n]
            if b.exists, b.isHittable { return b }
        }
        for id in [AX.calendar.close, AX.nav.back, AX.modal.cancel, AX.modal.secondary, AX.workout.sheetClose] {
            let b = app.descendants(matching: .any)[id].firstMatch
            if b.exists, b.isHittable { return b }
        }
        return nil
    }

    func same(_ a: [String], _ b: [String]) -> Bool {
        let x = Set(a), y = Set(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        let inter = x.intersection(y).count
        return Double(inter) / Double(max(x.count, y.count)) > 0.85
    }

    private func placeholderLike(_ labels: [String]) -> Bool {
        let joined = labels.joined(separator: " ").lowercased()
        if ["coming soon", "not available yet", "placeholder", "todo", "lorem ipsum", "under construction", "not implemented"].contains(where: { joined.contains($0) }) { return true }
        return labels.count < 3 && !hasBack()
    }

    // MARK: Crawl

    /// Crawls the screen that is showing now. `key` is its path ("home", "more>history").
    func crawl(_ key: String, via: String, parent: String, path: [Item], depth: Int) {
        let before = labels()
        var offsets: [[Item]] = []
        offsets.append(interactives(scrolls: 0))
        for s in 1...2 {
            scrollDown(1)
            let more = interactives(scrolls: s)
            let known = Set(offsets.flatMap { $0 }.map { "\($0.id)|\($0.label)" })
            let fresh = more.filter { !known.contains("\($0.id)|\($0.label)") }
            if fresh.isEmpty { break }
            offsets.append(fresh)
        }
        scrollTop()
        var count = 0
        var repeated: [String: Int] = [:]
        for group in offsets {
            for it in group {
                guard count < maxItemsPerScreen else { break }
                if it.id.hasPrefix("tab.") { continue }     // the tabs are visited by the test, not tapped from inside a screen
                let family = it.id.isEmpty ? "label|" + String(it.label.prefix(3)) : it.id.replacingOccurrences(of: #"[0-9]+"#, with: "#", options: .regularExpression)
                if repeated[family, default: 0] >= 2 { continue }       // rows of one list: the first two are enough
                repeated[family, default: 0] += 1
                let name = it.label.isEmpty ? (it.id.isEmpty ? "(unlabelled \(it.kind))" : it.id) : it.label
                if isDenied(it) {
                    entries.append(Entry(screen: key, element: name, kind: it.kind, id: it.id, status: "SKIPPED", destination: "", shot: nil,
                                         note: "not tapped: ends the session, deletes, spends, posts or leaves the app"))
                    continue
                }
                count += 1
                if it.scrolls > 0 { scrollDown(it.scrolls) }
                let pre = labels()
                let preBack = hasBack(), preTab = hasTabBar(), preTitle = titleID(), preClose = firstClose() != nil
                tap(it)
                if discardLiveWorkout() {
                    // The tap started a workout (a recent search or template row). Note it, throw the workout away and carry on.
                    entries.append(Entry(screen: key, element: name, kind: it.kind, id: it.id, status: "OK", destination: "starts a workout",
                                         shot: nil, note: "started a live workout; the crawl discarded it"))
                    write(to: "audit-\(state)-\(appearance).jsonl")
                    root(); reroute(screens.first { $0.key == key } ?? Screen(key: key, title: key, shot: "", parent: "", via: "", path: path, labels: before, depth: depth))
                    continue
                }
                let post = labels()
                var status = "OK", dest = "", shotName: String? = nil, note = ""
                if same(pre, post) {
                    // Nothing changed on screen.
                    let chevron = it.label.contains("›") || it.label.contains(">")
                    if it.kind == "switch" { note = "toggle (state changed in place)" }
                    else if chevron || it.kind == "cell" { status = "FAKE AFFORDANCE"; note = "looks tappable but nothing happens" }
                    else { status = "DEAD END"; note = "tap changed nothing on screen" }
                } else if (!preBack && hasBack()) || (preTab && !hasTabBar()) || (titleID() != preTitle) || (!preClose && firstClose() != nil) {
                    // A new screen (pushed, sheet, modal, full-screen cover).
                    let t = title()
                    dest = t
                    let childKey = key + ">" + Self.slug(name)
                    if placeholderLike(post) { status = "PLACEHOLDER"; note = "blank or placeholder screen" }
                    let sigKey = post.joined(separator: "|")
                    if !visited.contains(sigKey) {
                        visited.insert(sigKey)
                        shotName = shot(Self.slug(name) + "-" + Self.slug(t))
                        var p = path; p.append(it)
                        screens.append(Screen(key: childKey, title: t, shot: shotName!, parent: key, via: name, path: p, labels: post, depth: depth + 1))
                        if depth + 1 < maxDepth { crawl(childKey, via: name, parent: key, path: p, depth: depth + 1) }
                    }
                    if !goBack(to: pre) {
                        status = "TRAP"; note = "no way back found from \(t)"
                        root(); reroute(screens.first { $0.key == key } ?? Screen(key: key, title: key, shot: "", parent: "", via: "", path: path, labels: before, depth: depth))
                    }
                } else {
                    note = "changed in place (\(Set(post).symmetricDifference(Set(pre)).count) labels)"
                    // Put it back if it is a toggle-like control we can undo with a second tap.
                    if it.kind == "switch" || it.kind == "button" { _ = same(labels(), pre) }
                }
                entries.append(Entry(screen: key, element: name, kind: it.kind, id: it.id, status: status, destination: dest, shot: shotName, note: note))
                write(to: "audit-\(state)-\(appearance).jsonl")
                if it.scrolls > 0 { scrollTop() }
            }
        }
    }

    // MARK: Output

    func write(to file: String) {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        var lines: [String] = []
        for s in screens {
            let path = (try? enc.encode(s.path)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
            if let d = try? enc.encode(["type": "screen", "key": s.key, "title": s.title, "shot": s.shot, "parent": s.parent, "via": s.via, "depth": String(s.depth), "path": path]) { lines.append(String(decoding: d, as: UTF8.self)) }
        }
        for e in entries { if let d = try? enc.encode(["type": "entry", "screen": e.screen, "element": e.element, "kind": e.kind, "id": e.id, "status": e.status, "destination": e.destination, "shot": e.shot ?? "", "note": e.note]) { lines.append(String(decoding: d, as: UTF8.self)) } }
        try? lines.joined(separator: "\n").write(toFile: "\(dir)/\(file)", atomically: true, encoding: .utf8)
    }
}
