import Foundation
import CoreGraphics

/// The member Stardust inside the worked muscles (design: Body Map Batch 3 Grey). Pure and seedable: no SwiftUI types.
/// Stars twinkle in place: each sits on a point of its muscle's pool, lives a while, fades and reappears on another point.
struct BodyStardustEngine {
    struct Star {
        var x = 0.0, y = 0.0
        /// Distance from the muscle's centre, 0–1: the reveal ripples outward.
        var dd = 0.0
        var born = 0.0, life = 1.0
        var gold = false
        var r = 226.0, g = 232.0, b = 240.0
        var z = 1.0, w = 0.0, tw = 0.0, tws = 0.003, fl = 0.0
    }

    /// One star ready to draw: position in artwork units (+ `swayX` in screen points), radius in points.
    struct Drawn {
        var x: Double, y: Double, swayX: Double
        var radius: Double
        var alpha: Double
        var gold: Bool
        var r: Double, g: Double, b: Double
        /// Cross-flare: arm length in points and its alpha (0 = none); a gold star's flare is tinted 255, 214, 100.
        var flareLength: Double
        var flareAlpha: Double
    }

    struct Muscle {
        var shapeIndex: Int
        var pool: [CGPoint]
        var stars: [Star]
        var period: Double
        var phase: Double
        var centre: CGPoint
        var maxDist: Double
        var rank: Int
        var drawn: [Drawn] = []
    }

    struct SplitMix: RandomNumberGenerator {
        var s: UInt64
        mutating func next() -> UInt64 {
            s &+= 0x9E3779B97F4A7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private(set) var muscles: [Muscle] = []
    private var config: BodyMapConfig
    private var rng: SplitMix

    /// Star count for a muscle: `max(2, round(area · 0.0011 · amount · v^1.4))`.
    static func starCount(area: Double, amount: Double, level v: Double) -> Int {
        max(2, Int((area * 0.0011 * amount * pow(max(0, min(1, v)), 1.4)).rounded()))
    }

    /// Reveal order: the hardest-worked muscle first (ties by artwork order). Maps a shape index to its rank.
    static func ranks(levels: [String: Double], shapes: [BodyMuscleShape]) -> [Int: Int] {
        let worked = shapes.enumerated().compactMap { i, s -> (Int, Double)? in
            let v = levels[s.id] ?? 0
            return v > 0 ? (i, v) : nil
        }.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
        var out: [Int: Int] = [:]
        for (rank, item) in worked.enumerated() { out[item.0] = rank }
        return out
    }

    init(shapes: [BodyMuscleShape], levels: [String: Double], config: BodyMapConfig, seed: UInt64, now: Double) {
        self.config = config
        rng = SplitMix(s: seed)
        let ranks = Self.ranks(levels: levels, shapes: shapes)
        for (i, shape) in shapes.enumerated() {
            guard let rank = ranks[i], let v = levels[shape.id], !shape.candidates.isEmpty else { continue }
            let n = Self.starCount(area: shape.area, amount: config.amount, level: v)
            let pool = Array(shape.candidates.prefix(min(n * 8, shape.candidates.count)))
            var cx = 0.0, cy = 0.0
            for p in pool { cx += p.x; cy += p.y }
            cx /= Double(pool.count); cy /= Double(pool.count)
            let maxDist = max(1, pool.map { hypot($0.x - cx, $0.y - cy) }.max() ?? 1)
            var m = Muscle(shapeIndex: i, pool: pool, stars: [], period: 2400 + Double.random(in: 0..<1600, using: &rng),
                           phase: Double.random(in: 0..<6.28, using: &rng), centre: CGPoint(x: cx, y: cy), maxDist: maxDist, rank: rank)
            for _ in 0..<n {
                var s = Star()
                Self.respawn(&s, pool: pool, centre: m.centre, maxDist: maxDist, config: config, rng: &rng, now: now, initial: true)
                m.stars.append(s)
            }
            m.drawn.reserveCapacity(n)
            muscles.append(m)
        }
    }

    /// Gives a star a new spot, colour, size and life.
    private static func respawn(_ s: inout Star, pool: [CGPoint], centre: CGPoint, maxDist: Double, config: BodyMapConfig,
                                rng: inout SplitMix, now: Double, initial: Bool = false) {
        let p = pool[Int.random(in: 0..<pool.count, using: &rng)]
        let lifeK = config.lifespan / 3.1
        s.x = p.x; s.y = p.y
        s.dd = hypot(p.x - centre.x, p.y - centre.y) / maxDist
        s.life = (1800 + Double.random(in: 0..<2600, using: &rng)) * lifeK
        s.born = initial ? now - Double.random(in: 0..<1, using: &rng) * s.life : now
        s.gold = Double.random(in: 0..<1, using: &rng) < config.gold
        let c = Double.random(in: 0..<1, using: &rng)
        (s.r, s.g, s.b) = s.gold ? (255, 196, 48) : c < 0.67 ? (226, 232, 240) : c < 0.9 ? (255, 235, 245) : (255, 255, 255)
        s.z = (0.5 + Double.random(in: 0..<1, using: &rng) * (s.gold ? 1.9 : 1.5)) * 0.6 * config.size
        s.w = Double.random(in: 0..<1, using: &rng)
        s.tw = Double.random(in: 0..<6.28, using: &rng)
        s.tws = 0.002 + Double.random(in: 0..<0.005, using: &rng)
        s.fl = 0
    }

    static func ease(_ x: Double) -> Double { 1 - pow(1 - max(0, min(1, x)), 3) }

    /// Moves every star to `now` (ms on the figure's clock; `t0` is when the reveal started) and fills each muscle's `drawn`.
    mutating func step(now: Double, t0: Double) {
        let c = config, rv = c.reveal
        let t = now - t0
        let depth = min(1, c.flicker * 1.5)
        let flashP = 0.003 * pow(c.flicker / 0.6, 2)
        for mi in muscles.indices {
            muscles[mi].drawn.removeAll(keepingCapacity: true)
            let tm = t0 + rv.delayMs + Double(muscles[mi].rank) * rv.staggerMs
            guard Self.ease((now - tm) / rv.fillMs) > 0 else { continue }
            let (pool, centre, maxDist) = (muscles[mi].pool, muscles[mi].centre, muscles[mi].maxDist)
            let pulse = 0.72 + 0.28 * sin((now - tm) * 6.283 / muscles[mi].period + muscles[mi].phase)
            for si in muscles[mi].stars.indices {
                var s = muscles[mi].stars[si]
                if now > s.born + s.life { Self.respawn(&s, pool: pool, centre: centre, maxDist: maxDist, config: c, rng: &rng, now: now) }
                defer { muscles[mi].stars[si] = s }
                let age = (now - s.born) / s.life
                if age < 0 { continue }
                let env = min(1, sin(Double.pi * age) * 2.2)
                let ap = Self.ease((now - tm - s.dd * rv.rippleMs) / rv.starFadeMs)
                if ap <= 0 { continue }
                if s.fl <= 0, Double.random(in: 0..<1, using: &rng) < flashP { s.fl = 1 }
                s.fl = max(0, s.fl - 0.08)
                let tw = 0.5 + 0.5 * sin(s.tw + t * s.tws)
                let flick = (1 - depth) + depth * (0.5 + 0.5 * sin(t * 0.02 * (0.6 + s.w) + s.tw * 3))
                let al = min(1, (0.2 + tw * 0.7) * flick + s.fl) * env * ap * pulse
                let z = s.z * (0.55 + tw * 0.5 + s.fl * 0.6)
                let sway = sin(t * 0.0012 * (0.5 + s.w) + s.tw) * (0.6 + s.z * 0.8) * c.sway
                let flare = max((tw - 0.9) * 6 * flick, s.fl)
                var arm = 0.0, armAlpha = 0.0
                if c.flare > 0, s.z > 0.66 * c.size, flare > 0.05 {
                    arm = s.z * (3 + s.fl * 4) * c.flare
                    armAlpha = min(1, flare) * env * ap
                }
                muscles[mi].drawn.append(Drawn(x: s.x, y: s.y, swayX: sway, radius: z, alpha: s.gold ? al : al * 0.9, gold: s.gold,
                                               r: s.r, g: s.g, b: s.b, flareLength: arm, flareAlpha: armAlpha))
            }
        }
    }
}
