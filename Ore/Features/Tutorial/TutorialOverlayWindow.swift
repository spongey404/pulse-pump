import SwiftUI
import UIKit

// MARK: - Window

/// A window above the whole app (sheets and full-screen covers included) that dims everything but
/// the current target. Touches inside the spotlight fall through to the real control underneath.
final class TutorialOverlayWindow: UIWindow {
    /// Window-coordinate rects that must receive touches themselves (the spotlight).
    var passThroughRects: () -> [CGRect] = { [] }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if passThroughRects().contains(where: { $0.contains(point) }) { return nil }
        return super.hitTest(point, with: event) ?? rootViewController?.view
    }
}

// MARK: - Touch observer

/// Watches the touches the app receives without taking part in them. It never recognizes, so every
/// control underneath still gets its tap, scroll or swipe; it only reports where a touch went.
final class TutorialTouchSpy: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onBegan: ((CGPoint) -> Void)?
    var onTap: ((CGPoint) -> Void)?
    var onSwipe: ((_ start: CGPoint, _ translation: CGSize) -> Void)?
    /// A touch that began but did not end as a tap or swipe (cancelled by a scroll, say).
    var onCancelled: (() -> Void)?

    private var start: CGPoint = .zero
    private var last: CGPoint = .zero
    private var startTime: TimeInterval = 0

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, let t = touches.first else { return }
        start = t.location(in: view)
        last = start
        startTime = t.timestamp
        onBegan?(start)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let t = touches.first { last = t.location(in: view) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let t = touches.first {
            last = t.location(in: view)
            let dx = last.x - start.x, dy = last.y - start.y
            if hypot(dx, dy) < 12, t.timestamp - startTime < 0.6 {
                onTap?(start)
            } else {
                onSwipe?(start, CGSize(width: dx, height: dy))
            }
        }
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onCancelled?()
        state = .failed
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

// MARK: - Presenter

/// Owns the overlay window and routes what the user does inside the spotlight to the view model.
@MainActor
final class TutorialPresenter {
    private let viewModel: TutorialViewModel
    private var window: TutorialOverlayWindow?
    private var spy: TutorialTouchSpy?
    private weak var spiedWindow: UIWindow?
    private var observers: [NSObjectProtocol] = []

    init(viewModel: TutorialViewModel) { self.viewModel = viewModel }

    /// The spotlight for the current step, grown to a comfortable touch size.
    var spotlight: CGRect? {
        guard !viewModel.isFinished, let r = TutorialTargets.shared.frame(viewModel.currentStep.target) else { return nil }
        return Self.hole(for: r)
    }

    static let holePadding: CGFloat = 3
    /// The area that counts as a tap on the target: the control itself plus a hair. It must not be
    /// bigger than what the control really responds to, or a tap could advance the tutorial while
    /// the app ignores it.
    static func hole(for r: CGRect) -> CGRect { r.insetBy(dx: -holePadding, dy: -holePadding) }

    /// How the spotlight is drawn: exactly the hole, so the light traces the control's own outline.
    static func lit(_ hole: CGRect) -> CGRect { hole }

    func sync() {
        viewModel.isActive ? show() : hide()
    }

    private func show() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive }) ??
                  UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let w = TutorialOverlayWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.passThroughRects = { [weak self] in
            // While the tutorial types for the user (or has finished) nothing underneath is touchable.
            guard let self, !self.viewModel.isFinished, self.viewModel.currentStep.gesture != .auto else { return [] }
            var rects: [CGRect] = []
            // Only the spotlight is live. (The keyboard is not: the tutorial types for the user, so a key
            // pressed there would put text where the walkthrough didn't ask for it.)
            if let s = self.spotlight { rects.append(s) }
            return rects
        }
        let host = UIHostingController(rootView: CoachMarkOverlay(viewModel: viewModel))
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.alpha = 0
        w.isHidden = false
        window = w
        UIView.animate(withDuration: 0.25) { w.alpha = 1 }

        attachSpy(excluding: w)
        observeKeyboard()
    }

    private func hide() {
        guard let w = window else { return }
        window = nil
        spy.map { s in s.view?.removeGestureRecognizer(s) }
        spy = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        TutorialTargets.shared.keyboardFrame = .zero
        UIView.animate(withDuration: 0.2, animations: { w.alpha = 0 }, completion: { _ in w.isHidden = true })
    }

    private func attachSpy(excluding overlay: UIWindow) {
        guard let appWindow = overlay.windowScene?.windows.first(where: { $0 !== overlay && $0.isKeyWindow })
                ?? overlay.windowScene?.windows.first(where: { $0 !== overlay }) else { return }
        let s = TutorialTouchSpy(target: nil, action: nil)
        // Fade the card the moment a finger lands in the spotlight: the next screen's work starts at
        // touch-up and can stall drawing, so waiting until then would leave the old card on screen.
        s.onBegan = { [weak self] p in
            guard let self, let hole = self.spotlight, hole.contains(p) else { return }
            self.viewModel.touchBegan()
        }
        s.onCancelled = { [weak self] in self?.viewModel.touchAbandoned() }
        s.onTap = { [weak self] p in
            guard let self else { return }
            guard let hole = self.spotlight, hole.contains(p) else { return self.viewModel.touchAbandoned() }
            self.viewModel.targetTapped()
        }
        s.onSwipe = { [weak self] start, t in
            guard let self else { return }
            guard let hole = self.spotlight, hole.contains(start) else { return self.viewModel.touchAbandoned() }
            let left = t.width < -40 && abs(t.width) > abs(t.height) * 1.5
            let down = t.height > 40 && abs(t.height) > abs(t.width) * 1.5
            if left { self.viewModel.targetSwiped(.swipeLeft) }
            else if down { self.viewModel.targetSwiped(.swipeDown) }
            else { self.viewModel.touchAbandoned() }
        }
        appWindow.addGestureRecognizer(s)
        spy = s
        spiedWindow = appWindow
    }

    private func observeKeyboard() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { note in
            guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screen = UIScreen.main.bounds
            MainActor.assumeIsolated {
                // A keyboard that is sliding off the bottom of the screen counts as hidden.
                TutorialTargets.shared.keyboardFrame = end.minY >= screen.height ? .zero : end
            }
        })
        observers.append(nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { TutorialTargets.shared.keyboardFrame = .zero }
        })
    }
}
