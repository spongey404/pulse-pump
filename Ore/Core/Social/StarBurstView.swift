import SwiftUI

/// One running burst: where it started, when, and its stars. `heart` adds the big double-tap heart.
struct RunningBurst: Identifiable, Equatable {
    let id = UUID()
    var origin: CGPoint
    var start: Date
    var stars: [BurstStar]
    var heart: Bool
    var end: Double { max(StarBurstEngine.length(of: stars), heart ? SocialConfigStore.shared.current.heart.durationMs / 1000 : 0) }
}

/// Draws running bursts (and double-tap hearts) over whatever it is laid on; hit-testing is off. Stars only: no glows or flashes.
/// Dark: gold and white. Light: gold and the poster's accent, each with a thin amber edge, and `lightStarBonus` more stars (made by the engine).
struct StarBurstLayer: View {
    var bursts: [RunningBurst]
    /// The poster's accent (heart fill, and the second star colour in light).
    var accent: Color
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if bursts.isEmpty || reduceMotion {
            Color.clear.allowsHitTesting(false)
        } else {
            TimelineView(.animation) { timeline in
                Canvas { ctx, _ in
                    let cfg = SocialConfigStore.shared.current
                    let dark = scheme == .dark
                    let gold = Color(hex: dark ? cfg.burst.darkGold : cfg.burst.lightGold)
                    let second = dark ? Color(hex: cfg.burst.darkWhite) : accent
                    let edge = Color(hex: cfg.burst.lightEdge)
                    let star = FourPointStar()
                    for b in bursts {
                        let t = timeline.date.timeIntervalSince(b.start)
                        if t < 0 || t > b.end { continue }
                        if b.heart {
                            let h = DoubleTapHeartMotion.state(progress: t / (cfg.heart.durationMs / 1000), size: cfg.heart.size)
                            if h.opacity > 0, let sym = ctx.resolveSymbol(id: "heart") {
                                var c = ctx
                                c.opacity = h.opacity
                                c.translateBy(x: b.origin.x, y: b.origin.y - h.lift)
                                c.scaleBy(x: h.scale, y: h.scale)
                                c.draw(sym, at: .zero)
                            }
                        }
                        for s in b.stars {
                            guard let st = s.state(at: t), st.opacity > 0 else { continue }
                            let side = s.size * 2 * st.scale
                            var c = ctx
                            c.opacity = st.opacity
                            c.translateBy(x: b.origin.x + st.x, y: b.origin.y + st.y)
                            c.rotate(by: .radians(st.rotation))
                            let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
                            let path = star.path(in: rect)
                            c.fill(path, with: .color(s.tone == 0 ? gold : second))
                            if !dark { c.stroke(path, with: .color(edge.opacity(0.7)), lineWidth: 0.6) }
                        }
                    }
                } symbols: {
                    Image(systemName: "heart.fill")
                        .resizable().scaledToFit()
                        .frame(width: SocialConfigStore.shared.current.heart.size, height: SocialConfigStore.shared.current.heart.size)
                        .foregroundStyle(accent)
                        .tag("heart")
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Owns the burst queue for one surface: `double-tap` adds the next pattern at the tap point (cycling through the eight), `like`
/// adds the small ring from the like button. Finished bursts are dropped.
@Observable
final class BurstController {
    private(set) var bursts: [RunningBurst] = []
    private var next = 0
    private var seed: UInt64 = 1

    /// Pattern index for the next double-tap. Start anywhere so two posts don't open on the same one.
    init(startPattern: Int = 0) { next = startPattern }

    func doubleTap(at p: CGPoint, dark: Bool, now: Date = Date()) {
        let cfg = SocialConfigStore.shared.current
        seed &+= 1
        let stars = StarBurstEngine.pattern(next, density: dark ? 1 : cfg.burst.lightStarBonus, size: cfg.burst.starSize, seed: seed &* 7919)
        next = (next + 1) % StarBurstEngine.patternCount
        add(RunningBurst(origin: p, start: now, stars: stars, heart: true))
    }

    func likeButton(at p: CGPoint, now: Date = Date()) {
        let cfg = SocialConfigStore.shared.current
        seed &+= 1
        let n = Int.random(in: cfg.like.starsMin...cfg.like.starsMax)
        add(RunningBurst(origin: p, start: now, stars: StarBurstEngine.likeBurst(count: n, seed: seed &* 104729), heart: false))
    }

    private func add(_ b: RunningBurst) {
        bursts.append(b)
        let id = b.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(b.end + 0.1))
            self?.bursts.removeAll { $0.id == id }
        }
    }
}
