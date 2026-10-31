import SwiftUI

/// Where a StarField's frame budget comes from.
enum StarFieldBudget {
    /// Full speed, dropping to the idle rate after `idleAfterMs` (the paywall).
    case paywall
    /// Capped, and frozen on its last frame after `settleAfterMs` (the More tab). 0 = never freeze.
    case more
}

/// Drives one field: owns the engine and reuses it frame to frame (nothing is allocated per frame except the few
/// batched paths). A class, so the Canvas closure can step it without touching SwiftUI state.
@MainActor
final class StarFieldRunner {
    var params: StarFieldParams   // `palette` may change while it runs (the member's accent picker); nothing else does
    private var engine: StarFieldEngine?
    private let seed = UInt64.random(in: 1...UInt64.max)
    /// This view's top-left in global coordinates, and the anchor's centre in global coordinates.
    var origin: CGPoint = .zero
    var anchorGlobal: CGPoint?

    init(params: StarFieldParams) { self.params = params }

    var particleCount: Int { engine?.count ?? 0 }

    func frame(size: CGSize, t: Double) -> (dots: [StarDot], flares: [StarFlare]) {
        if engine == nil || engine!.size != size { engine = StarFieldEngine(params: params, size: size, seed: seed) }
        let anchor = anchorGlobal.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
        engine!.step(t: t, anchor: anchor)
        return (engine!.dots, engine!.flares)
    }
}

/// The glitter: a gradient, two drifting glows, a few hundred twinkling stars, a veil. Everything tunable comes from
/// `StarFieldConfig` (see `starfield.config.json`); this view only draws what `StarFieldEngine` computes.
///
/// Drawing is batched: stars of one colour and one (quantised) brightness are a single path and a single fill, and the
/// gradient is the only full-view fill. The timeline is paused whenever it can't be seen: off screen, app in the
/// background, Low Power Mode, Reduce Motion (one still frame), or once a `.more` field has settled.
struct StarFieldView: View {
    var variant: String = "paywall"
    var budget: StarFieldBudget = .more
    var overrides: StarFieldParams.Overrides = .init()
    /// Frame of the gold anchor (the wordmark's asterisk) in global coordinates.
    var anchor: CGRect? = nil

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// While the paywall closes into the More banner: the banner's own background, drawn over the paywall's inside the
    /// shrinking rect (under the particles), so the last frame is the banner and the glitter never freezes.
    @Environment(\.starFieldMorph) private var morph
    @State private var runner: StarFieldRunner
    @State private var start = Date()
    @State private var visible = false
    @State private var settled = false
    @State private var idle = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    private let config: StarFieldConfig

    init(variant: String = "paywall", budget: StarFieldBudget = .more, overrides: StarFieldParams.Overrides = .init(),
         anchor: CGRect? = nil, config: StarFieldConfig? = nil) {
        self.variant = variant
        self.budget = budget
        self.overrides = overrides
        self.anchor = anchor
        let cfg = config ?? StarFieldConfigStore.shared.current
        self.config = cfg
        var o = overrides
        o.fps = overrides.fps ?? (budget == .paywall ? cfg.fps.paywall : cfg.fps.more)
        _runner = State(initialValue: StarFieldRunner(params: StarFieldParams(config: cfg, variant: variant, overrides: o)))
    }

    private var fps: Int { budget == .paywall && idle ? config.fps.paywallIdle : runner.params.fps }
    private var paused: Bool { !visible || scenePhase != .active || lowPower || reduceMotion || settled }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Double(max(1, fps)), paused: paused)) { timeline in
            Canvas(opaque: true, rendersAsynchronously: false) { ctx, size in
                let t = reduceMotion || lowPower ? 1500 : timeline.date.timeIntervalSince(start) * 1000
                draw(ctx: &ctx, size: size, t: t)
            }
        }
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { runner.origin = proxy.frame(in: .global).origin }
                .onChange(of: proxy.frame(in: .global)) { _, f in runner.origin = f.origin }
        })
        .onChange(of: overrides.palette) { _, palette in if let palette { runner.params.palette = palette } }   // recolour live, no remount
        .onChange(of: anchor) { _, a in runner.anchorGlobal = a.map { CGPoint(x: $0.midX, y: $0.midY) } }
        .onAppear {
            runner.anchorGlobal = anchor.map { CGPoint(x: $0.midX, y: $0.midY) }
            visible = true
        }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: visible) {
            guard visible else { return }
            start = Date(); settled = false; idle = false
            switch budget {
            case .more where config.settleAfterMs > 0:
                try? await Task.sleep(for: .milliseconds(config.settleAfterMs))
                if !Task.isCancelled { settled = true }
            case .paywall:
                try? await Task.sleep(for: .milliseconds(config.idleAfterMs))
                if !Task.isCancelled { idle = true }
            default: break
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Drawing

    private static let levels = 12
    #if DEBUG
    private static let debugNoStars = UserDefaults.standard.bool(forKey: "debugSignupNoStars")   // read once, not per frame
    #endif

    /// The banner's compact background inside `rect`: the same gradient (from the rect's top left toward 40 % of its height),
    /// the two drifting glows positioned inside the rect, and the veil, at `alpha`.
    private func drawBannerMorph(ctx: inout GraphicsContext, rect: CGRect, alpha: Double, t: Double, palette pal: StarPalette,
                                 style: SupernovaTransitionFrame.MorphStyle) {
        func color(_ c: StarRGBA, _ a: Double? = nil) -> Color {
            Color(.sRGB, red: c.r / 255, green: c.g / 255, blue: c.b / 255, opacity: a ?? c.a)
        }
        var layer = ctx
        layer.opacity = alpha
        let path = Path(rect)
        if style == .card {
            // The member card's own background: g0 → g1 at 80 % diagonally across the rect, and the veil (no glows).
            let stops: [Gradient.Stop] = [.init(color: color(pal.deep, 1), location: 0), .init(color: color(pal.accent, 1), location: 0.8),
                                          .init(color: color(pal.accent, 1), location: 1)]
            layer.fill(path, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                                   endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            layer.fill(path, with: .color(color(pal.veil)))
            return
        }
        let stops: [Gradient.Stop] = [.init(color: color(pal.deep, 1), location: 0), .init(color: color(pal.accent, 1), location: 0.75),
                                      .init(color: color(pal.accent, 1), location: 1)]
        layer.fill(path, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                               endPoint: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.4)))
        let r = max(rect.width, rect.height) * 0.55
        let glows: [(CGPoint, StarRGBA)] = [
            (CGPoint(x: rect.minX + rect.width * (0.3 + 0.1 * sin(t * 0.0003)), y: rect.minY + rect.height * 0.35), pal.blob),
            (CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * (0.65 + 0.06 * cos(t * 0.00025))), StarRGBA(r: 190, g: 215, b: 240, a: 0.2)),
        ]
        for (centre, c) in glows {
            layer.fill(path, with: .radialGradient(Gradient(colors: [color(c), color(c, 0)]), center: centre, startRadius: 0, endRadius: r))
        }
        layer.fill(path, with: .color(color(pal.veil)))
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let p = runner.params
        let W = size.width, H = size.height
        let pal = p.palette
        func color(_ c: StarRGBA, _ a: Double? = nil) -> Color {
            Color(.sRGB, red: c.r / 255, green: c.g / 255, blue: c.b / 255, opacity: a ?? c.a)
        }

        // Background gradient (the only full-view fill).
        let stops: [Gradient.Stop]
        let from: CGPoint, to: CGPoint
        if p.mini {
            from = .zero; to = CGPoint(x: W, y: H)
            stops = [.init(color: color(pal.deep, 1), location: 0), .init(color: color(pal.accent, 1), location: 0.8), .init(color: color(pal.accent, 1), location: 1)]
        } else if p.compact {
            from = .zero; to = CGPoint(x: W, y: H * 0.4)
            stops = [.init(color: color(pal.deep, 1), location: 0), .init(color: color(pal.accent, 1), location: 0.75), .init(color: color(pal.accent, 1), location: 1)]
        } else {
            from = .zero; to = CGPoint(x: W * 0.35, y: H)
            stops = [.init(color: color(pal.deep, 1), location: 0), .init(color: color(pal.accent, 1), location: 0.5), .init(color: color(pal.light, 1), location: 1)]
        }
        let full = Path(CGRect(origin: .zero, size: size))
        ctx.fill(full, with: .linearGradient(Gradient(stops: stops), startPoint: from, endPoint: to))

        // Two slow glows (not in a Mini).
        if !p.mini {
            let r = max(W, H) * 0.55
            let glows: [(CGPoint, StarRGBA)] = [
                (CGPoint(x: W * (0.3 + 0.1 * sin(t * 0.0003)), y: H * 0.35), pal.blob),
                (CGPoint(x: W * 0.75, y: H * (0.65 + 0.06 * cos(t * 0.00025))), StarRGBA(r: 190, g: 215, b: 240, a: 0.2)),
            ]
            for (centre, c) in glows {
                ctx.fill(full, with: .radialGradient(Gradient(colors: [color(c), color(c, 0)]), center: centre, startRadius: 0, endRadius: r))
            }
        }

        if let m = morph, !p.mini, m.alpha > 0.001 {
            drawBannerMorph(ctx: &ctx, rect: m.rect.offsetBy(dx: -runner.origin.x, dy: -runner.origin.y), alpha: m.alpha, t: t, palette: pal, style: m.style)
        }

        #if DEBUG
        if Self.debugNoStars { ctx.fill(full, with: .color(color(pal.veil))); return }   // clean frames for measuring against the design
        #endif

        let (dots, flares) = runner.frame(size: size, t: t)

        // Stars, batched: one path per (colour, brightness level).
        let levels = Self.levels
        var additive = [[Path]](repeating: [Path](repeating: Path(), count: levels), count: 4)
        var solidGold = [Path](repeating: Path(), count: levels)
        var highlights = [Path](repeating: Path(), count: levels)
        var single: [StarDot] = []
        for d in dots {
            let level = min(levels - 1, Int(d.color.a * Double(levels)))
            let rect = CGRect(x: d.x - d.radius, y: d.y - d.radius, width: d.radius * 2, height: d.radius * 2)
            if d.pulled > 0 { single.append(d); continue }
            if d.solid {
                solidGold[level].addEllipse(in: rect)
                if d.highlight {
                    let h = d.radius * 0.45
                    highlights[level].addEllipse(in: CGRect(x: d.x - d.radius * 0.25 - h, y: d.y - d.radius * 0.25 - h, width: h * 2, height: h * 2))
                }
            } else {
                additive[Int(d.kind)][level].addEllipse(in: rect)
            }
        }
        let kindColors: [StarRGBA] = [.gold, .silver, p.mini ? .pinkWhite : .lightBlue, .white]
        let alpha = { (level: Int) in (Double(level) + 0.5) / Double(levels) }
        ctx.blendMode = .plusLighter
        for kind in 1..<4 {
            for level in 0..<levels where !additive[kind][level].isEmpty {
                ctx.fill(additive[kind][level], with: .color(color(kindColors[kind], alpha(level) * (p.mini ? 0.9 : 1))))
            }
        }
        ctx.blendMode = .normal
        for level in 0..<levels where !solidGold[level].isEmpty {
            ctx.fill(solidGold[level], with: .color(color(.gold, alpha(level))))
            if !highlights[level].isEmpty { ctx.fill(highlights[level], with: .color(color(.goldHighlight, alpha(level) * 0.8))) }
        }
        // Stars being pulled toward the anchor (few): one by one, gold ones solid.
        for d in single {
            let rect = CGRect(x: d.x - d.radius, y: d.y - d.radius, width: d.radius * 2, height: d.radius * 2)
            ctx.blendMode = d.solid ? .normal : .plusLighter
            ctx.fill(Path(ellipseIn: rect), with: .color(color(d.color)))
        }

        // Cross flares.
        ctx.blendMode = .plusLighter
        for f in flares {
            var line = Path()
            line.move(to: CGPoint(x: f.x - f.length, y: f.y)); line.addLine(to: CGPoint(x: f.x + f.length, y: f.y))
            line.move(to: CGPoint(x: f.x, y: f.y - f.length)); line.addLine(to: CGPoint(x: f.x, y: f.y + f.length))
            ctx.stroke(line, with: .color(color(f.color)), lineWidth: p.flareWidth)
        }

        // Veil over everything.
        ctx.blendMode = .normal
        ctx.fill(full, with: .color(color(pal.veil)))
    }
}
