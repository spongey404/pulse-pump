import SwiftUI
import Observation

// MARK: - Spotlight target registry
// Views mark themselves with `.tutorialTarget("id")`. A tiny UIView behind the content is kept in the
// registry and asked for its window frame whenever the overlay draws, so the spotlight follows
// scrolling and sheet transitions exactly and works for targets inside sheets and covers.

@MainActor
@Observable
final class TutorialTargets {
    static let shared = TutorialTargets()

    /// Software keyboard in window coordinates; `.zero` while hidden. Never dimmed, so typing works.
    var keyboardFrame: CGRect = .zero

    private final class Box { weak var view: UIView?; init(_ v: UIView) { view = v } }
    /// Several views can briefly share an id while SwiftUI rebuilds a row; the one in a window wins.
    @ObservationIgnored private var boxes: [String: [Box]] = [:]

    fileprivate func register(_ id: String, view: UIView) {
        var list = (boxes[id] ?? []).filter { $0.view != nil && $0.view !== view }
        list.append(Box(view))
        boxes[id] = list
    }

    fileprivate func unregister(_ id: String, view: UIView) {
        boxes[id] = boxes[id]?.filter { $0.view != nil && $0.view !== view }
    }

    /// The status bar is not a view of ours: the strip across the top of the screen where a tap scrolls the
    /// main list back up.
    static let statusBarID = "tutorial.status-bar"

    private static func statusBarFrame() -> CGRect {
        let top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 47
        return CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: max(top, 20))
    }

    /// Current frame of the target in window coordinates, nil while it isn't on screen.
    func frame(_ id: String) -> CGRect? {
        if id == Self.statusBarID { return Self.statusBarFrame() }
        guard let v = boxes[id]?.last(where: { $0.view?.window != nil })?.view else { return nil }
        let r = v.convert(v.bounds, to: nil)
        return r.width > 0 && r.height > 0 ? r : nil
    }
}

private struct TutorialTargetAnchor: UIViewRepresentable {
    let id: String
    let enabled: Bool

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ view: UIView, context: Context) {
        if enabled { TutorialTargets.shared.register(id, view: view) } else { TutorialTargets.shared.unregister(id, view: view) }
    }

    static func dismantleUIView(_ view: UIView, coordinator: ()) {
        // The id isn't known here; the box holds the view weakly, so a stale entry reads as "not on screen".
    }
}

extension View {
    /// Registers this view as a tutorial spotlight target; `enabled: false` unregisters it.
    func tutorialTarget(_ id: String, enabled: Bool = true) -> some View {
        background(TutorialTargetAnchor(id: id, enabled: enabled).allowsHitTesting(false))
    }
}
