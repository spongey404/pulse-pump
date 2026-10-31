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
    /// What grows out of what: the free paywall out of the More banner, or the member page out of the More membership card.
    enum Kind: Hashable { case paywall, member }
    struct Source: Equatable { var rect: CGRect; var asterisk: CGPoint?; var starHeight: Double }

    private(set) var phase: Phase = .closed
    private(set) var kind: Kind = .paywall
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
    /// Each source's frame, its asterisk's centre and that asterisk's height (global), reported while the screen is at rest.
    private(set) var sources: [Kind: Source] = [:]
    private var wordmarkRest: CGPoint?
    private var geometry: SupernovaTransitionGeometry?
    private var timers: [Task<Void, Never>] = []
    private var onClosed: (() -> Void)?
    private var closeWhenOpen: (crossfade: Bool, completion: (() -> Void)?)?

    #if DEBUG
    /// While set, the transition is held at this many ms (screenshots).
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

    /// `-debugTransition open:400` / `close:300` (the free banner) or `member-open:400` / `member-close:300` (the member card,
    /// with `-devDataPlus 1`): run the transition and hold at that many ms, for screenshots.
    func runDebugRequest() {
        guard let spec = UserDefaults.standard.string(forKey: "debugTransition"), phase == .closed else { return }
        let parts = spec.split(separator: ":")
        guard parts.count == 2, let ms = Double(parts[1]) else { return }
        let source: Kind = parts[0].hasPrefix("member") ? .member : .paywall
        let opening = parts[0].hasSuffix("open")
        Task {
            try? await Task.sleep(for: .milliseconds(2000))
            if opening {
                frozenMs = ms
                open(source, fromSource: true)
            } else {
                open(source, fromSource: true)
                try? await Task.sleep(for: .milliseconds(2500))
                frozenMs = ms
                close()
            }
        }
    }
    #endif

    var config: SupernovaTransitionConfig {
        kind == .member ? SupernovaMemberConfigStore.shared.current.transition : SupernovaTransitionConfigStore.shared.current
    }

    // MARK: Derived

    var isPresented: Bool { phase != .closed && phase != .revealing }
    var isBusy: Bool { phase != .closed }
    var isAnimating: Bool { phase != .closed && phase != .open }
    /// Taps on the paywall count only once it is fully open.
    var acceptsInput: Bool { phase == .open }
    /// The banner's asterisk is swapped for the flyer for the whole flight and while the paywall is open; the wordmark's is
    /// swapped for it during the flight. Never faded: only switched, in the same frame as the flyer appears or goes.
    func sourceAsteriskHidden(_ source: Kind) -> Bool { source == kind && isShared && (phase == .opening || phase == .open || phase == .closing) }
    var bannerAsteriskHidden: Bool { sourceAsteriskHidden(.paywall) }
    var wordmarkAsteriskHidden: Bool { isShared && (phase == .opening || phase == .closing) }

    // MARK: Geometry (from the banner and the paywall)

    func reportBanner(rect: CGRect, asterisk: CGPoint?) { report(.paywall, rect: rect, asterisk: asterisk, starHeight: 0) }

    func report(_ source: Kind, rect: CGRect, asterisk: CGPoint?, starHeight: Double) {
        guard phase == .closed else { return }
        var s = sources[source] ?? Source(rect: rect, asterisk: nil, starHeight: starHeight)
        s.rect = rect
        if let asterisk { s.asterisk = asterisk }
        if starHeight > 0 { s.starHeight = starHeight }
        sources[source] = s
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
    func open(fromBanner: Bool) { open(.paywall, fromSource: fromBanner) }

    /// Opens what grows out of `source` (the banner or the member card); `fromSource` false: no source tapped, cross-fade.
    func open(_ source: Kind, fromSource: Bool) {
        guard phase == .closed else { return }
        cancelTimers()
        closeWhenOpen = nil
        fadingOut = false
        kind = source
        let reduce = UIAccessibility.isReduceMotionEnabled
        if fromSource, !reduce, let src = sources[source], let star = src.asterisk {
            isShared = true
            let scale = source == .member && src.starHeight > 0 ? src.starHeight / config.flyer.glyphSize : config.flyer.startScale
            geometry = SupernovaTransitionGeometry(bannerRect: src.rect, bannerAsterisk: star, wordmarkAsterisk: star, screen: screen, startScale: scale)
            wordmarkRest = nil
            phase = .measuring
            // If the page never reports its asterisk, fall back to the cross-fade rather than hang.
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
        schedule(ms: handoff) { [self] in
            phase = .open
            if let pending = closeWhenOpen { closeWhenOpen = nil; close(crossfade: pending.crossfade, completion: pending.completion) }
        }
    }

    /// TRAIN FREE (or a purchase). `crossfade` skips the flight (after a purchase the banner is gone).
    func close(crossfade: Bool = false, completion: (() -> Void)? = nil) {
        // A completion must never be dropped (a purchase can finish while TRAIN FREE is already closing the page):
        switch phase {
        case _ where fadingOut, .closing, .revealing:   // (a cross-fade close keeps the phase `.open` while it fades)
            if let completion { let previous = onClosed; onClosed = { previous?(); completion() } }   // runs when it has closed
            return
        case .closed:
            completion?()   // already closed: nothing to wait for
            return
        case .opening, .measuring:
            // A plain close is a tap during the animation and is ignored; one that carries a completion (a purchase finished)
            // must not be lost, so it closes the moment the page has opened.
            if completion != nil { closeWhenOpen = (crossfade, completion) }
            return
        case .open:
            break
        }
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
        case .closing: return SupernovaTransitionMath.closing(t: t, g: g, config: c, morph: kind == .member ? .card : .banner)
        case .revealing: return SupernovaTransitionMath.revealing(t: t, g: g, config: c)
        }
    }

    private func fade(_ p: Double, _ c: SupernovaTransitionConfig) -> SupernovaTransitionFrame {
        var f = SupernovaTransitionMath.open(g: SupernovaTransitionGeometry(bannerRect: screen, bannerAsterisk: .zero, wordmarkAsterisk: .zero, screen: screen), config: c)
        f.paywallOpacity = p
        f.bannerText = SupernovaTransitionMath.shown(c.content.bannerItems)
        return f
    }

    /// The text pieces of one source (the banner's four, the card's three) at `date`: animating only while that source is the
    /// one in play, otherwise just shown.
    func sourceText(_ source: Kind, at date: Date) -> [SupernovaTransitionFrame.Piece] {
        source == kind ? frame(at: date).bannerText : SupernovaTransitionMath.shown(source == .member ? 3 : 4)
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
