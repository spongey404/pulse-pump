import Testing
import Foundation
import CoreGraphics
@testable import Ore

@MainActor
struct SupernovaTransitionTests {
    private let c = SupernovaTransitionConfig.fallback
    private let g = SupernovaTransitionGeometry(bannerRect: CGRect(x: 16, y: 520, width: 358, height: 68),
                                               bannerAsterisk: CGPoint(x: 150, y: 548), wordmarkAsterisk: CGPoint(x: 340, y: 120),
                                               screen: CGRect(x: 0, y: 0, width: 390, height: 844))

    // MARK: Config

    @Test func theBundledJSONEqualsTheFallback() throws {
        let url = try #require(Bundle.main.url(forResource: "supernovaTransition.config", withExtension: "json"))
        #expect(try #require(SupernovaTransitionConfig.load(from: Data(contentsOf: url))) == c)
    }

    @Test func theDesignsNumbers() {
        #expect(c.open.maskMs == 560 && c.open.flyerMs == 760 && c.open.handoffMs == 800 && c.close.ms == 560 && c.close.handoffMs == 590)
        #expect(c.hubScale == 0.94 && c.hubOpacity == 0.35)
        #expect(c.content.offsetPt == 14 && c.content.bannerOffsetPt == 10 && c.content.staggerMs == 90 && c.content.startMs == 380)
        #expect(c.content.fadeMs == 520 && c.content.moveMs == 720 && c.close.contentFadeMs == 180 && c.open.bannerTextFadeMs == 120)
        #expect(c.close.morphAlphaExponent == 2.2 && c.flyer.glyphSize == 44 && c.flyer.startScale == 18.0 / 44.0)
        #expect(c.open.maskCurve == [0.32, 0.72, 0, 1] && c.open.flyerCurve == [0.45, 0, 0.15, 1] && c.content.moveCurve == [0.2, 0.8, 0.2, 1])
    }

    @Test func remoteConfigIsValidatedAndAppliedOrIgnored() throws {
        let store = SupernovaTransitionConfigStore()
        var broken = c; broken.open.maskCurve = [0, 1]
        #expect(!store.applyRemote(json: try JSONEncoder().encode(broken)))
        #expect(!store.applyRemote(json: Data("{}".utf8)))
        var tuned = c; tuned.hubScale = 0.9
        #expect(store.applyRemote(json: try JSONEncoder().encode(tuned)))
        #expect(store.current.hubScale == 0.9)
    }

    // MARK: Curves

    @Test func cubicBezierMatchesTheCSSCurves() {
        let ease = CubicBezier([0.42, 0, 0.58, 1])   // CSS ease-in-out
        #expect(abs(ease(0)) < 1e-9 && abs(ease(1) - 1) < 1e-9)
        #expect(abs(ease(0.5) - 0.5) < 1e-3)
        let out = CubicBezier(c.open.maskCurve)
        #expect(out(0.25) > 0.5, "the open curve is front-loaded")
        #expect(out(0.5) < out(0.75))
        let linear = CubicBezier([0, 0, 1, 1])
        #expect(abs(linear(0.3) - 0.3) < 1e-3)
        #expect(CubicBezier.easeOut(0.5) > 0.5)
    }

    // MARK: Opening

    @Test func openingStartsAtTheBannerAndEndsFullScreen() {
        let start = SupernovaTransitionMath.opening(t: 0, g: g, config: c)
        #expect(start.maskRect == g.bannerRect && start.maskRadius == 12)
        #expect(start.flyer == .init(center: g.bannerAsterisk, scale: 18.0 / 44.0))
        #expect(start.groups.allSatisfy { $0.opacity == 0 && $0.offset == 14 })
        #expect(start.bannerText.allSatisfy { $0.opacity == 1 && $0.offset == 0 })
        let end = SupernovaTransitionMath.opening(t: 800, g: g, config: c)
        #expect(end.maskRect == g.screen && end.maskRadius == 44)
        #expect(end.flyer == .init(center: g.wordmarkAsterisk, scale: 1), "same size and spot as the real asterisk")
        #expect(end.groups[0].opacity > 0.9 && end.groups[5].opacity == 0, "content keeps arriving after the hand-off: the last group starts at 830 ms")
        #expect(end.bannerText.allSatisfy { $0.opacity == 0 && $0.offset == 10 })
    }

    @Test func theMaskFinishesBeforeTheFlyer() {
        let t = 560.0
        let f = SupernovaTransitionMath.opening(t: t, g: g, config: c)
        #expect(f.maskRect == g.screen, "mask is done at 560 ms")
        #expect(f.flyer!.scale < 1 && f.flyer!.center != g.wordmarkAsterisk, "the flyer is still travelling (760 ms)")
    }

    @Test func contentGroupsStartAt380PlusNinetyEach() {
        #expect(SupernovaTransitionMath.opening(t: 379, g: g, config: c).groups.allSatisfy { $0.opacity == 0 })
        let at = SupernovaTransitionMath.opening(t: 380 + 90 + 100, g: g, config: c)
        #expect(at.groups[0].opacity > at.groups[1].opacity && at.groups[1].opacity > at.groups[2].opacity)
        #expect(at.groups[5].opacity == 0, "the last group starts at 830 ms")
        let late = SupernovaTransitionMath.opening(t: 380 + 5 * 90 + 720, g: g, config: c)
        #expect(late.groups.allSatisfy { $0.opacity == 1 && $0.offset == 0 })
    }

    @Test func bannerTextFadesOutOver120ms() {
        let mid = SupernovaTransitionMath.opening(t: 60, g: g, config: c).bannerText[0]
        #expect(mid.opacity < 1 && mid.opacity > 0 && mid.offset > 0)
        #expect(SupernovaTransitionMath.opening(t: 120, g: g, config: c).bannerText[0].opacity == 0)
    }

    @Test func theFlightIsMonotonicNoOvershoot() {
        var last = SupernovaTransitionMath.opening(t: 0, g: g, config: c).flyer!
        for t in stride(from: 10.0, through: 800, by: 10) {
            let f = SupernovaTransitionMath.opening(t: t, g: g, config: c).flyer!
            #expect(f.scale >= last.scale - 1e-9 && f.scale <= 1 + 1e-9)
            #expect(f.center.x >= last.center.x - 1e-9 && f.center.x <= g.wordmarkAsterisk.x + 1e-9)
            last = f
        }
    }

    // MARK: Closing

    @Test func closingShrinksBackToTheBannerAndMorphsTheGradient() {
        let start = SupernovaTransitionMath.closing(t: 0, g: g, config: c)
        #expect(start.maskRect == g.screen && start.maskRadius == 44)
        #expect(start.flyer == .init(center: g.wordmarkAsterisk, scale: 1))
        #expect(start.morph?.alpha == 0)
        let end = SupernovaTransitionMath.closing(t: 560, g: g, config: c)
        #expect(end.maskRect == g.bannerRect && end.maskRadius == 12)
        #expect(end.flyer?.center == g.bannerAsterisk && abs(end.flyer!.scale - 18.0 / 44.0) < 1e-9)
        #expect(end.morph == .init(rect: g.bannerRect, alpha: 1), "the last frame is the banner's own background")
        #expect(end.groups.allSatisfy { $0.opacity == 0 })
        let mid = SupernovaTransitionMath.closing(t: 280, g: g, config: c)
        #expect(abs(mid.morph!.alpha - pow(0.5, 2.2)) < 1e-9, "alpha is progress^2.2")
        #expect(mid.morph!.rect == mid.maskRect, "the morph follows the mask")
    }

    @Test func contentFadesTogetherOver180msWithNoStagger() {
        let f = SupernovaTransitionMath.closing(t: 90, g: g, config: c)
        #expect(Set(f.groups.map(\.opacity)).count == 1)
        #expect(f.groups[0].opacity > 0 && f.groups[0].opacity < 1)
        #expect(SupernovaTransitionMath.closing(t: 180, g: g, config: c).groups[0].opacity == 0)
    }

    @Test func bannerTextReturnsStaggeredAfterTheSwap() {
        let f = SupernovaTransitionMath.revealing(t: 100, g: g, config: c)
        let o = f.bannerText.map(\.opacity)
        #expect(o[0] > o[1] && o[1] > o[2] && o[2] > o[3] && o[3] == 0 || o[3] >= 0)
        let done = SupernovaTransitionMath.revealing(t: SupernovaTransitionMath.revealMs(config: c), g: g, config: c)
        #expect(done.bannerText.allSatisfy { $0.opacity == 1 && $0.offset == 0 })
        #expect(SupernovaTransitionMath.revealMs(config: c) == 3 * 90 + 720)
        #expect(f.paywallOpacity == 0 && f.flyer == nil)
    }

    @Test func theMoreLayerPushesBackToScale094AndOpacity035() {
        let rest = SupernovaTransitionMath.hub(progress: 0, config: c)
        let pushed = SupernovaTransitionMath.hub(progress: 1, config: c)
        #expect(rest.scale == 1 && rest.opacity == 1)
        #expect(pushed.scale == 0.94 && pushed.opacity == 0.35)
    }

    // MARK: Controller

    /// The controller's hand-offs run on timers; under a loaded test run they come late, so wait for the state, not the clock.
    private func wait(_ t: SupernovaTransition, for phase: SupernovaTransition.Phase) async {
        for _ in 0..<600 where t.phase != phase { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func theControllerOpensClosesAndIgnoresTapsWhileBusy() async {
        let t = SupernovaTransition()
        #expect(t.phase == .closed && !t.isPresented)
        // No measured banner: the cross-fade (no flyer, no mask).
        t.open(fromBanner: true)
        #expect(t.phase == .opening && !t.isShared && t.isPresented)
        t.open(fromBanner: true)   // ignored: already open
        t.close()                   // ignored: not open yet
        #expect(t.phase == .opening)
        await wait(t, for: .open)
        #expect(t.phase == .open && t.acceptsInput)
        var done = false
        t.close { done = true }
        await wait(t, for: .closed)
        #expect(t.phase == .closed && done)
    }

    @Test func aCompletionIsNeverDroppedWhateverPhaseTheCloseArrivesIn() async {
        // Already closed: nothing to wait for, so it runs at once.
        let closed = SupernovaTransition()
        var ranWhenClosed = false
        closed.close { ranWhenClosed = true }
        #expect(ranWhenClosed)

        // Asked while opening: closes as soon as it has opened, then runs.
        let opening = SupernovaTransition()
        opening.open(fromBanner: true)
        var ranAfterOpening = false
        opening.close(crossfade: true) { ranAfterOpening = true }
        await wait(opening, for: .closed)
        #expect(opening.phase == .closed && ranAfterOpening)

        // Asked while already closing (TRAIN FREE, then the purchase lands): both run.
        let closing = SupernovaTransition()
        closing.open(fromBanner: true)
        await wait(closing, for: .open)
        var order: [String] = []
        closing.close { order.append("first") }
        closing.close { order.append("second") }
        await wait(closing, for: .closed)
        #expect(order == ["first", "second"])
    }

    @Test func theFlyerVersionWaitsForTheWordmarkThenRunsAndHandsOff() async {
        let t = SupernovaTransition()
        t.reportBanner(rect: g.bannerRect, asterisk: g.bannerAsterisk)
        t.open(fromBanner: true)
        #expect(t.phase == .measuring && t.isShared)
        #expect(!t.bannerAsteriskHidden, "the banner is unchanged until the flight starts")
        // The wordmark's asterisk, 14 pt lower than it will rest while the content is still offset.
        t.wordmarkMeasured(CGRect(x: 330, y: 124, width: 20, height: 40))
        #expect(t.phase == .opening)
        #expect(t.bannerAsteriskHidden && t.wordmarkAsteriskHidden, "swapped for the flyer in the same frame")
        let rest = t.frame(at: t.t0.addingTimeInterval(0.9)).flyer
        #expect(rest?.center == CGPoint(x: 340, y: 144 - 14 + 0), "measured at its resting position: the 14 pt offset is taken off")
        await wait(t, for: .open)
        #expect(t.phase == .open)
        #expect(!t.wordmarkAsteriskHidden, "the real asterisk is back, the flyer gone")
        t.close()
        #expect(t.phase == .closing && t.wordmarkAsteriskHidden)
        await wait(t, for: .revealing)
        #expect((t.phase == .revealing || t.phase == .closed) && !t.isPresented, "the paywall is removed in the same step the banner's asterisk returns")
        #expect(!t.bannerAsteriskHidden)
        await wait(t, for: .closed)
        #expect(t.phase == .closed)
    }
}
