import SwiftUI

/// The sign-up screen's colours: it is always the Sky theme, whatever the system appearance.
enum SignupSkyColors {
    static let base = Color(red: 26 / 255, green: 167 / 255, blue: 1)          // #1AA7FF, Ore's accent
    static let ctaInk = Color(red: 14 / 255, green: 143 / 255, blue: 224 / 255) // #0E8FE0
    static let primaryInk = Color(red: 21 / 255, green: 26 / 255, blue: 33 / 255) // #151A21
    static let ink = Color.white
    static let ink2 = Color.white.opacity(0.86)
    static let muted = Color.white.opacity(0.7)
    static let line = Color.white.opacity(0.45)
    static let rule = Color.white.opacity(0.2)
    static let track = Color.white.opacity(0.22)
    static let card = Color.white.opacity(0.14)
    static let cardBorder = Color.white.opacity(0.28)
    static let offBg = Color.white.opacity(0.16)
    static let offInk = Color.white.opacity(0.6)
    static let placeholder = Color.white.opacity(0.5)
    static let error = Color(red: 1, green: 217 / 255, blue: 210 / 255)         // #FFD9D2
    static let secondaryBg = Color(red: 10 / 255, green: 70 / 255, blue: 140 / 255).opacity(0.28)
    static let secondaryBorder = Color.white.opacity(0.35)
}

private func rgb(_ c: [Double], _ a: Double) -> Color { Color(.sRGB, red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255, opacity: a) }

/// Steps the star engine frame to frame and eases the level toward its target. A class so the Canvas closure can drive it.
@MainActor
final class SignupSkyRunner {
    let config: SignupConfig
    let surge: SignupSurge
    private var engine: SignupStarEngine?
    private let seed = UInt64.random(in: 1...UInt64.max)
    private var lastT: Double = 0
    private(set) var level: Double = 0

    init(config: SignupConfig, surge: SignupSurge) { self.config = config; self.surge = surge }

    var particleCount: Int { engine?.count ?? 0 }

    func frame(size: CGSize, t: Double, target: Double, still: Bool) -> SignupStarEngine {
        if engine == nil || engine!.size != size { engine = SignupStarEngine(config: config.stars, size: size, seed: seed) }
        let dt = still ? 16 : min(64, max(0, t - lastT))
        lastT = t
        if still {
            level = target
            surge.boost = 0
        } else {
            surge.boost *= config.stars.boostDecay
            level += (target - level) * config.stars.levelEase
        }
        engine!.step(t: t, dt: dt, level: level, boost: surge.boost)
        return engine!
    }
}

/// The flat Ore blue that becomes the Supernova paywall's sky as the answers come in, with the stars on top.
struct SignupBackdrop: View {
    let runner: SignupSkyRunner
    /// 0 on the opening screen, answered / total after (1 from the setup on).
    var target: Double

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var config: SignupConfig { runner.config }
    private var paused: Bool { !visible || scenePhase != .active || lowPower || reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Double(max(1, config.stars.fps)), paused: paused)) { timeline in
            Canvas(opaque: true, rendersAsynchronously: false) { ctx, size in
                let still = reduceMotion || lowPower
                let t = still ? 1500 : timeline.date.timeIntervalSince(start) * 1000
                draw(ctx: &ctx, size: size, t: t, still: still)
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static let levels = 12

    private func draw(ctx: inout GraphicsContext, size: CGSize, t: Double, still: Bool) {
        let W = size.width, H = size.height
        let full = Path(CGRect(origin: .zero, size: size))
        let bg = config.background
        func css(_ s: String) -> Color { StarRGBA(css: s).map { Color(.sRGB, red: $0.r / 255, green: $0.g / 255, blue: $0.b / 255, opacity: $0.a) } ?? .clear }
        func css0(_ s: String) -> Color { StarRGBA(css: s).map { Color(.sRGB, red: $0.r / 255, green: $0.g / 255, blue: $0.b / 255, opacity: 0) } ?? .clear }

        ctx.fill(full, with: .color(css(bg.base)))
        let engine = runner.frame(size: size, t: t, target: target, still: still)
        let lv = runner.level, b = runner.surge.boost

        // The paywall's sky, fading in over the flat blue.
        if lv > 0.001 {
            var layer = ctx
            layer.opacity = min(1, lv)
            let stops = [Gradient.Stop(color: css(bg.gradient[0]), location: 0), .init(color: css(bg.gradient[1]), location: 0.5), .init(color: css(bg.gradient[2]), location: 1)]
            layer.fill(full, with: .linearGradient(Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: W * 0.35, y: H)))
            let r = bg.glowRadius * max(W, H)
            let a = CGPoint(x: W * (0.3 + 0.1 * sin(t * 0.0003)), y: 0.35 * H)
            layer.fill(full, with: .radialGradient(Gradient(colors: [css(bg.glowA), css0(bg.glowA)]), center: a, startRadius: 0, endRadius: r))
            let c = CGPoint(x: 0.75 * W, y: H * (0.65 + 0.06 * cos(t * 0.00025)))
            layer.fill(full, with: .radialGradient(Gradient(colors: [css(bg.glowB), css0(bg.glowB)]), center: c, startRadius: 0, endRadius: r))
        }
        // The soft glow in the top right corner grows with the level.
        let glowRGB = bg.topGlowRGB
        let glowStops = [Gradient.Stop(color: rgb(glowRGB, lv * bg.topGlowAlpha + b * 0.1 * lv), location: 0),
                         .init(color: rgb(glowRGB, lv * bg.topGlowMidAlpha), location: 0.5), .init(color: rgb(glowRGB, 0), location: 1)]
        ctx.fill(full, with: .radialGradient(Gradient(stops: glowStops), center: CGPoint(x: W * 0.85, y: 0), startRadius: 0,
                                             endRadius: W * (bg.topGlowRadiusBase + lv * bg.topGlowRadiusPerLevel)))

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugSignupNoStars") { return }   // clean frames for measuring against the design
        #endif

        // Stars: one path per (colour, brightness level).
        let levels = Self.levels
        let s = config.stars
        let colors = [s.goldRGB, s.silverRGB, s.blueRGB, s.whiteRGB]
        let alpha = { (l: Int) in (Double(l) + 0.5) / Double(levels) }
        var dots = [[Path]](repeating: [Path](repeating: Path(), count: levels), count: 4)
        for d in engine.dots {
            dots[Int(d.kind)][min(levels - 1, Int(d.alpha * Double(levels)))]
                .addEllipse(in: CGRect(x: d.x - d.radius, y: d.y - d.radius, width: d.radius * 2, height: d.radius * 2))
        }
        for kind in 0..<4 {
            ctx.blendMode = kind == 0 ? .normal : .plusLighter
            for l in 0..<levels where !dots[kind][l].isEmpty { ctx.fill(dots[kind][l], with: .color(rgb(colors[kind], alpha(l)))) }
        }
        if !engine.streaks.isEmpty {
            var lines = [[Path]](repeating: [Path](repeating: Path(), count: levels), count: 4)
            for st in engine.streaks {
                lines[Int(st.kind)][min(levels - 1, Int(max(0, st.alpha) * Double(levels)))].addLines([CGPoint(x: st.x, y: st.y), CGPoint(x: st.x, y: st.y2)])
            }
            for kind in 0..<4 {
                ctx.blendMode = kind == 0 ? .normal : .plusLighter
                for l in 0..<levels where !lines[kind][l].isEmpty {
                    ctx.stroke(lines[kind][l], with: .color(rgb(colors[kind], alpha(l))), lineWidth: 1.3 * s.streakWidth)
                }
            }
        }
        ctx.blendMode = .plusLighter
        for f in engine.flares {
            var line = Path()
            line.move(to: CGPoint(x: f.x - f.length, y: f.y)); line.addLine(to: CGPoint(x: f.x + f.length, y: f.y))
            line.move(to: CGPoint(x: f.x, y: f.y - f.length)); line.addLine(to: CGPoint(x: f.x, y: f.y + f.length))
            ctx.stroke(line, with: .color(rgb(f.gold ? s.flareGoldRGB : s.flareRGB, f.alpha)), lineWidth: s.flareWidth)
        }
        ctx.blendMode = .normal
    }
}

/// Steps the bar's Stardust; a class so the Canvas closure can drive it.
@MainActor
final class SignupBarRunner {
    private var Stardust: SignupBarStardust?
    private var lastT = 0.0

    func frame(config: SignupConfig, width: Double, t: Double, boost: Double) -> [SignupBarStardust.Speck] {
        if Stardust == nil || Stardust!.width != width { Stardust = SignupBarStardust(config: config.bar, width: width) }
        let dt = min(64, max(0, t - lastT))
        lastT = t
        Stardust!.step(t: t, dt: dt, boost: boost)
        return Stardust!.specks
    }
}

/// The 6 pt progress bar: a white fill with Stardust drifting through the filled part only.
struct SignupProgressBar: View {
    let config: SignupConfig
    let surge: SignupSurge
    var progress: Double

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var runner = SignupBarRunner()
    private static var noStars: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "debugSignupNoStars")
        #else
        false
        #endif
    }
    @State private var start = Date()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SignupSkyColors.track)
                ZStack(alignment: .leading) {
                    LinearGradient(colors: [.white, Color(red: 221 / 255, green: 242 / 255, blue: 1)], startPoint: .leading, endPoint: .trailing)
                    if !reduceMotion && !Self.noStars {
                        TimelineView(.animation(minimumInterval: 1.0 / Double(max(1, config.stars.fps)), paused: scenePhase != .active || progress <= 0)) { tl in
                            Canvas { ctx, size in
                                let t = tl.date.timeIntervalSince(start) * 1000
                                for sp in runner.frame(config: config, width: geo.size.width, t: t, boost: surge.boost) {
                                    let c = sp.gold ? config.stars.goldRGB : sp.silver ? [235.0, 242, 250] : [255.0, 255, 255]
                                    ctx.blendMode = sp.gold ? .normal : .plusLighter
                                    ctx.fill(Path(ellipseIn: CGRect(x: sp.x - sp.radius, y: sp.y - sp.radius, width: sp.radius * 2, height: sp.radius * 2)),
                                             with: .color(rgb(c, sp.alpha)))
                                }
                            }
                            .frame(width: geo.size.width, height: config.bar.height)
                        }
                    }
                }
                .frame(width: max(0, geo.size.width * progress), alignment: .leading)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: Double(config.bar.fillMs) / 1000), value: progress)
            }
        }
        .frame(height: config.bar.height)
        .accessibilityHidden(true)
    }
}
