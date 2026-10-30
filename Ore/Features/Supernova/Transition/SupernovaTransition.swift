import SwiftUI
import Observation

/// The transition between the free More tab's "GO SUPERNOVA*" banner and the full-screen paywall (design "Supernova
/// Transition Final"): the banner grows into the paywall while its gold asterisk flies to the end of the wordmark, and
/// back again on TRAIN FREE. No spring, no overshoot.
///
/// This object owns the state machine and the clock; `SupernovaTransitionMath` turns (phase, time, geometry) into what
/// to draw, so every piece comes from one clock. Geometry is measured before the animation starts, never during.
///
///   closed → measuring (paywall mounted, invisible, star field already running) → opening → open
///   open → closing → revealing (banner text returns, staggered) → closed
///
/// Reduce Motion, or no measured banner (opened from a row, not the banner): the paywall just cross-fades (200 ms).
@MainActor
@Observable
final class SupernovaTransition {
    static let shared = SupernovaTransition()

    enum Phase: Equatable { case closed, measuring, opening, open, closing, revealing }

    private(set) var phase: Phase = .closed
    /// When the running phase began.
    private(set) var t0 = Date()
    /// The shared-element version (flyer, mask, morph); false = the cross-fade.
    private(set) var isShared = false
    /// The More layer (the app shell) is pushed back. Set inside an animation with the open / close curve.
    private(set) var hubPushed = false
    /// The paywall is fading out (cross-fade close).
    private(set) var fadingOut = false

    /// The screen, set by the host.
    var screen: CGRect = UIScreen.main.bounds
    /// The banner's frame and its asterisk's centre (global), reported while the screen is at rest.
    private(set) var bannerRect: CGRect?
    private(set) var bannerAsterisk: CGPoint?
    private var wordmarkRest: CGPoint?
    private var geometry: SupernovaTransitionGeometry?
    private var timers: [Task<Void, Never>] = []
    private var onClosed: (() -> Void)?

    #if DEBUG
    /// `-debugTransition open:400` / `close:300`: run to that point and hold, for screenshots.
    var frozenMs: Double?

    /// While frozen, the More layer's progress is computed from the same time (the animation would run in real time).
    var hubProgressOverride: Double? {
        guard let t = frozenMs else { return nil }
        let c = config
        switch phase {
        case .opening: return CubicBezier(c.open.hubCurve)(SupernovaTransitionMath.clamp(t / c.open.hubMs))
        case .closing: return 1 - CubicBezier(c.close.curve)(SupernovaTransitionMath.clamp(t / c.close.ms))
        case .open: return 1
        default: return nil
        }
    }

    /// `-debugTransition open:400` or `close:300` (More tab, free plan): run the transition and hold at that many ms.
    func runDebugRequest() {
        guard let spec = UserDefaults.standard.string(forKey: "debugTransition"), phase == .closed else { return }
        let parts = spec.split(separator: ":")
        guard parts.count == 2, let ms = Double(parts[1]) else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            if parts[0] == "open" {
                frozenMs = ms
                open(fromBanner: true)
            } else {
                open(fromBanner: true)
                try? await Task.sleep(for: .milliseconds(2500))
                frozenMs = ms
                close()
            }
        }
    }
    #endif

    var config: SupernovaTransitionConfig { SupernovaTransitionConfigStore.shared.current }

    // MARK: Derived

    var isPresented: Bool { phase != .closed && phase != .revealing }
    var isBusy: Bool { phase != .closed }
    var isAnimating: Bool { phase != .closed && phase != .open }
    /// Taps on the paywall count only once it is fully open.
    var acceptsInput: Bool { phase == .open }
    /// The banner's asterisk is swapped for the flyer for the whole flight and while the paywall is open; the wordmark's is
    /// swapped for it during the flight. Never faded: only switched, in the same frame as the flyer appears or goes.
    var bannerAsteriskHidden: Bool { isShared && (phase == .opening || phase == .open || phase == .closing) }
    var wordmarkAsteriskHidden: Bool { isShared && (phase == .opening || phase == .closing) }

    // MARK: Geometry (from the banner and the paywall)

    func reportBanner(rect: CGRect, asterisk: CGPoint?) {
        guard phase == .closed else { return }
        bannerRect = rect
        if let asterisk { bannerAsterisk = asterisk }
    }

    /// The paywall's wordmark asterisk (global). Taken once, while the paywall is mounted but not started: its content is
    /// still `offsetPt` lower than where it will rest, so that is subtracted.
    func wordmarkMeasured(_ frame: CGRect) {
        guard phase == .measuring, isShared, frame != .zero else { return }
        wordmarkRest = CGPoint(x: frame.midX, y: frame.midY - config.content.offsetPt)
        start()
    }

    // MARK: Open and close

    /// The banner was tapped (`fromBanner`), or the paywall is opened from somewhere else (cross-fade).
    func open(fromBanner: Bool) {
        guard phase == .closed else { return }
        cancelTimers()
        fadingOut = false
        let reduce = UIAccessibility.isReduceMotionEnabled
        if fromBanner, !reduce, let rect = bannerRect, let star = bannerAsterisk {
            isShared = true
            geometry = SupernovaTransitionGeometry(bannerRect: rect, bannerAsterisk: star, wordmarkAsterisk: star, screen: screen)
            wordmarkRest = nil
            phase = .measuring
            // If the paywall never reports its asterisk, fall back to the cross-fade rather than hang.
            schedule(ms: 250) { [self] in if phase == .measuring { isShared = false; geometry = nil; start() } }
        } else {
            isShared = false
            geometry = nil
            phase = .measuring
            start()
        }
    }

    private func start() {
        guard phase == .measuring else { return }
        let c = config
        if isShared, var g = geometry, let rest = wordmarkRest {
            g.wordmarkAsterisk = rest
            geometry = g
        }
        t0 = Date()
        phase = .opening
        if isShared {
            withAnimation(.timingCurve(c.open.hubCurve[0], c.open.hubCurve[1], c.open.hubCurve[2], c.open.hubCurve[3], duration: c.open.hubMs / 1000)) { hubPushed = true }
        }
        #if DEBUG
        if let f = frozenMs { _ = f; return }   // hold here
        #endif
        let handoff = isShared ? c.open.handoffMs : c.reduceMotionFadeMs
        schedule(ms: handoff) { [self] in phase = .open }
    }

    /// TRAIN FREE (or a purchase). `crossfade` skips the flight (after a purchase the banner is gone).
    func close(crossfade: Bool = false, completion: (() -> Void)? = nil) {
        guard phase == .open else { return }
        cancelTimers()
        onClosed = completion
        let c = config
        t0 = Date()
        if isShared, !crossfade, geometry != nil {
            phase = .closing
            withAnimation(.timingCurve(c.close.curve[0], c.close.curve[1], c.close.curve[2], c.close.curve[3], duration: c.close.ms / 1000)) { hubPushed = false }
            #if DEBUG
            if frozenMs != nil { return }
            #endif
            schedule(ms: c.close.handoffMs) { [self] in
                // One frame: the paywall and the flyer go, the banner's asterisk is back; the banner's text starts to return.
                t0 = Date()
                phase = .revealing
                schedule(ms: SupernovaTransitionMath.revealMs(config: c)) { [self] in finish() }
            }
        } else {
            fadingOut = true
            withAnimation(.easeOut(duration: c.reduceMotionFadeMs / 1000)) { hubPushed = false }
            schedule(ms: c.reduceMotionFadeMs) { [self] in finish() }
        }
    }

    private func finish() {
        phase = .closed
        fadingOut = false
        isShared = false
        let done = onClosed
        onClosed = nil
        done?()
    }

    // MARK: Frame

    func frame(at date: Date) -> SupernovaTransitionFrame {
        let c = config
        var t = date.timeIntervalSince(t0) * 1000
        #if DEBUG
        if let f = frozenMs { t = f }
        #endif
        let g = geometry ?? SupernovaTransitionGeometry(bannerRect: screen, bannerAsterisk: .zero, wordmarkAsterisk: .zero, screen: screen)
        switch phase {
        case .closed: return SupernovaTransitionMath.measuring(g: g, config: c)
        case .measuring: return isShared ? SupernovaTransitionMath.measuring(g: g, config: c) : fade(0, c)
        case .opening: return isShared ? SupernovaTransitionMath.opening(t: t, g: g, config: c) : fade(SupernovaTransitionMath.clamp(t / c.reduceMotionFadeMs), c)
        case .open: return SupernovaTransitionMath.open(g: g, config: c)
        case .closing: return SupernovaTransitionMath.closing(t: t, g: g, config: c)
        case .revealing: return SupernovaTransitionMath.revealing(t: t, g: g, config: c)
        }
    }

    private func fade(_ p: Double, _ c: SupernovaTransitionConfig) -> SupernovaTransitionFrame {
        var f = SupernovaTransitionMath.open(g: SupernovaTransitionGeometry(bannerRect: screen, bannerAsterisk: .zero, wordmarkAsterisk: .zero, screen: screen), config: c)
        f.paywallOpacity = p
        f.bannerText = SupernovaTransitionMath.shown(c.content.bannerItems)
        return f
    }

    /// While the cross-fade closes, the paywall's opacity runs 1 → 0.
    func fadeOutOpacity(at date: Date) -> Double {
        1 - SupernovaTransitionMath.clamp(date.timeIntervalSince(t0) * 1000 / config.reduceMotionFadeMs)
    }

    // MARK: Timers

    private func schedule(ms: Double, _ work: @escaping @MainActor () -> Void) {
        timers.append(Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(ms))
            guard !Task.isCancelled, self != nil else { return }
            work()
        })
    }

    private func cancelTimers() { timers.forEach { $0.cancel() }; timers.removeAll() }
}
