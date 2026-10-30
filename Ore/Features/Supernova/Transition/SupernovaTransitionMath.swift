import Foundation
import CoreGraphics

/// A CSS `cubic-bezier(x1, y1, x2, y2)` timing curve (Newton-Raphson on x, as in the design's `bez`).
struct CubicBezier: Equatable {
    let x1: Double, y1: Double, x2: Double, y2: Double
    init(_ c: [Double]) { x1 = c[0]; y1 = c[1]; x2 = c[2]; y2 = c[3] }

    func callAsFunction(_ q: Double) -> Double {
        let q = min(1, max(0, q))
        var t = q
        for _ in 0..<12 {
            let u = 1 - t
            let x = 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t - q
            let dx = 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2)
            if abs(dx) < 1e-6 { break }
            t = min(1, max(0, t - x / dx))
        }
        let u = 1 - t
        return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t
    }

    /// CSS `ease-out`.
    static let easeOut = CubicBezier([0, 0, 0.58, 1])
}

/// What the transition draws at one instant: the paywall's mask, its content groups, the flying asterisk, the star field's
/// morph toward the banner, and the banner's own text. Computed from the time and the pre-measured geometry only, so every
/// piece comes from the same clock and can't drift (and it is testable without a screen).
struct SupernovaTransitionFrame: Equatable {
    struct Piece: Equatable { var opacity: Double; var offset: Double }
    struct Flyer: Equatable { var center: CGPoint; var scale: Double }
    /// Which source's own background the star field draws while the page closes into it.
    enum MorphStyle: Equatable { case banner, card }
    struct Morph: Equatable { var rect: CGRect; var alpha: Double; var style: MorphStyle = .banner }

    var maskRect: CGRect
    var maskRadius: Double
    var paywallOpacity: Double
    var groups: [Piece]
    var flyer: Flyer?
    var morph: Morph?
    var bannerText: [Piece]
}

/// Geometry measured before the animation starts (never mid-way): all in screen coordinates.
struct SupernovaTransitionGeometry: Equatable {
    var bannerRect: CGRect
    var bannerAsterisk: CGPoint
    var wordmarkAsterisk: CGPoint
    var screen: CGRect
    /// The flyer's scale at the source: the banner's fixed 18/44, or the card's asterisk height over the 44 pt glyph.
    var startScale: Double = 18.0 / 44.0
}

enum SupernovaTransitionMath {
    static func lerp(_ a: Double, _ b: Double, _ e: Double) -> Double { a + (b - a) * e }
    static func lerp(_ a: CGPoint, _ b: CGPoint, _ e: Double) -> CGPoint { CGPoint(x: lerp(a.x, b.x, e), y: lerp(a.y, b.y, e)) }
    static func lerp(_ a: CGRect, _ b: CGRect, _ e: Double) -> CGRect {
        CGRect(x: lerp(a.minX, b.minX, e), y: lerp(a.minY, b.minY, e), width: lerp(a.width, b.width, e), height: lerp(a.height, b.height, e))
    }
    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    /// A content group (or banner item) `i`: opacity ease-out over `fadeMs`, translateY over `moveMs`, both starting `startMs + i × stagger`.
    static func piece(index i: Int, t: Double, startMs: Double, offsetPt: Double, config c: SupernovaTransitionConfig) -> SupernovaTransitionFrame.Piece {
        let begin = startMs + Double(i) * c.content.staggerMs
        let fade = CubicBezier.easeOut(clamp((t - begin) / c.content.fadeMs))
        let move = CubicBezier(c.content.moveCurve)(clamp((t - begin) / c.content.moveMs))
        return .init(opacity: fade, offset: offsetPt * (1 - move))
    }

    static func shown(_ n: Int) -> [SupernovaTransitionFrame.Piece] { Array(repeating: .init(opacity: 1, offset: 0), count: n) }
    static func hidden(_ n: Int, offset: Double) -> [SupernovaTransitionFrame.Piece] { Array(repeating: .init(opacity: 0, offset: offset), count: n) }

    /// Opening: the banner grows into the paywall (`t` ms since the start).
    static func opening(t: Double, g: SupernovaTransitionGeometry, config c: SupernovaTransitionConfig) -> SupernovaTransitionFrame {
        let mask = CubicBezier(c.open.maskCurve)(clamp(t / c.open.maskMs))
        let fly = CubicBezier(c.open.flyerCurve)(clamp(t / c.open.flyerMs))
        let textT = CubicBezier.easeOut(clamp(t / c.open.bannerTextFadeMs))
        return SupernovaTransitionFrame(
            maskRect: lerp(g.bannerRect, g.screen, mask),
            maskRadius: lerp(c.maskRadiusStart, c.maskRadiusEnd, mask),
            paywallOpacity: 1,
            groups: (0..<c.content.groups).map { piece(index: $0, t: t, startMs: c.content.startMs, offsetPt: c.content.offsetPt, config: c) },
            flyer: .init(center: lerp(g.bannerAsterisk, g.wordmarkAsterisk, fly), scale: lerp(g.startScale, 1, fly)),
            morph: nil,
            bannerText: Array(repeating: .init(opacity: 1 - textT, offset: c.content.bannerOffsetPt * textT), count: c.content.bannerItems))
    }

    /// Closing: the paywall shrinks back into the banner and the gradient morphs to the banner's look (`t` ms since the start).
    static func closing(t: Double, g: SupernovaTransitionGeometry, config c: SupernovaTransitionConfig,
                        morph style: SupernovaTransitionFrame.MorphStyle = .banner) -> SupernovaTransitionFrame {
        let q = clamp(t / c.close.ms)
        let e = CubicBezier(c.close.curve)(q)
        let rect = lerp(g.screen, g.bannerRect, e)
        let fade = 1 - CubicBezier.easeOut(clamp(t / c.close.contentFadeMs))
        return SupernovaTransitionFrame(
            maskRect: rect,
            maskRadius: lerp(c.maskRadiusEnd, c.maskRadiusStart, e),
            paywallOpacity: 1,
            groups: Array(repeating: .init(opacity: fade, offset: 0), count: c.content.groups),
            flyer: .init(center: lerp(g.wordmarkAsterisk, g.bannerAsterisk, e), scale: lerp(1, g.startScale, e)),
            morph: .init(rect: rect, alpha: pow(q, c.close.morphAlphaExponent), style: style),
            bannerText: hidden(c.content.bannerItems, offset: c.content.bannerOffsetPt))
    }

    /// Settled open: the whole screen, everything shown, no flyer.
    static func open(g: SupernovaTransitionGeometry, config c: SupernovaTransitionConfig) -> SupernovaTransitionFrame {
        SupernovaTransitionFrame(maskRect: g.screen, maskRadius: c.maskRadiusEnd, paywallOpacity: 1, groups: shown(c.content.groups),
                                 flyer: nil, morph: nil, bannerText: hidden(c.content.bannerItems, offset: c.content.bannerOffsetPt))
    }

    /// Mounted but not started: the paywall is there (its star field already running) but not visible, at the banner's rect.
    static func measuring(g: SupernovaTransitionGeometry, config c: SupernovaTransitionConfig) -> SupernovaTransitionFrame {
        SupernovaTransitionFrame(maskRect: g.bannerRect, maskRadius: c.maskRadiusStart, paywallOpacity: 0,
                                 groups: hidden(c.content.groups, offset: c.content.offsetPt), flyer: nil, morph: nil,
                                 bannerText: shown(c.content.bannerItems))
    }

    /// The banner's text coming back after the close, exactly like the paywall's content (offset 10 pt), `t` ms after the swap.
    static func revealing(t: Double, g: SupernovaTransitionGeometry, config c: SupernovaTransitionConfig) -> SupernovaTransitionFrame {
        var f = measuring(g: g, config: c)
        f.paywallOpacity = 0
        f.bannerText = (0..<c.content.bannerItems).map { piece(index: $0, t: t, startMs: 0, offsetPt: c.content.bannerOffsetPt, config: c) }
        return f
    }

    /// When the banner's text has all arrived.
    static func revealMs(config c: SupernovaTransitionConfig) -> Double {
        Double(c.content.bannerItems - 1) * c.content.staggerMs + max(c.content.fadeMs, c.content.moveMs)
    }

    /// The More layer (the app shell) at progress `e` of the open (0 = at rest, 1 = pushed back).
    static func hub(progress e: Double, config c: SupernovaTransitionConfig) -> (scale: Double, opacity: Double) {
        (lerp(1, c.hubScale, e), lerp(1, c.hubOpacity, e))
    }
}
