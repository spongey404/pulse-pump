import Foundation
import CoreGraphics

/// The double-tap star bursts (Ore Feed Post Final, rule 1 "Likes"): eight patterns, cycled one per double-tap. Pure and seedable:
/// a pattern is a list of `BurstStar`s, each a short polar path from the tap point; `state(at:)` says where it is and how opaque.
/// Stars only. Every star ends at opacity 0.
struct BurstStar: Equatable {
    /// Seconds after the burst starts.
    var delay: Double
    var duration: Double
    /// Radius (pt) and angle (rad) at the start and the end of its path.
    var r0: Double, r1: Double
    var a0: Double, a1: Double
    /// Vertical squash for the flat ring (1 = round).
    var squash: Double = 1
    var size: Double
    /// Total rotation of the star itself over its life (rad).
    var spin: Double = 0
    /// 0 = gold, 1 = the second colour (white in dark, the poster's accent in light).
    var tone: Int = 0
    /// Easing: false = ease-out (flies out and settles), true = ease-in (falls into the centre).
    var easeIn = false

    struct State: Equatable { var x: Double, y: Double, scale: Double, rotation: Double, opacity: Double }

    func state(at t: Double) -> State? {
        let p = (t - delay) / duration
        guard p >= 0, p < 1 else { return nil }
        let e = easeIn ? p * p * p : 1 - pow(1 - p, 3)
        let r = r0 + (r1 - r0) * e
        let a = a0 + (a1 - a0) * e
        // In 0–18 %, hold to 55 %, out by 100 % (the design's oreBurst opacity), so it always ends at 0.
        let o: Double = p < 0.18 ? p / 0.18 : (p < 0.55 ? 1 : max(0, 1 - (p - 0.55) / 0.45))
        let s = p < 0.18 ? p / 0.18 : 1 - 0.35 * ((p - 0.18) / 0.82)
        return State(x: cos(a) * r, y: sin(a) * r * squash, scale: s, rotation: spin * p, opacity: o)
    }
}

enum StarBurstEngine {
    static let patternNames = ["Burst", "Spiral", "Twin swirl", "Shockwave", "Scatter", "Pulsar", "Supernova", "Neutron star collision"]
    static let patternCount = 8

    /// The small burst that comes out of the like button (no heart).
    static func likeBurst(count: Int, seed: UInt64) -> [BurstStar] {
        var g = SplitMix(seed: seed)
        return (0..<count).map { i in
            let a = Double(i) / Double(count) * 2 * .pi + Double.random(in: -0.15...0.15, using: &g)
            let ring = i % 2 == 0
            return BurstStar(delay: Double.random(in: 0...0.06, using: &g), duration: 0.55, r0: 6, r1: ring ? 30 : 20, a0: a, a1: a + 0.4,
                             size: Double.random(in: 4...7, using: &g), spin: 1.2, tone: i % 3 == 0 ? 1 : 0)
        }
    }

    /// Pattern `index` (wrapped into 0..<8). `density` is 1 in dark and `lightStarBonus` in light.
    static func pattern(_ index: Int, density: Double = 1, size: Double = 11, seed: UInt64) -> [BurstStar] {
        var g = SplitMix(seed: seed)
        let n = { (base: Int) in max(1, Int((Double(base) * density).rounded())) }
        var out: [BurstStar] = []

        func ring(_ count: Int, radius: Double, delay: Double, dur: Double = 0.9, squash: Double = 1, twist: Double = 0.5, sz: Double? = nil, offset: Double = 0) {
            for i in 0..<count {
                let a = Double(i) / Double(count) * 2 * .pi + offset
                out.append(BurstStar(delay: delay, duration: dur, r0: 0, r1: radius, a0: a, a1: a + twist, squash: squash,
                                     size: sz ?? size * Double.random(in: 0.6...1.1, using: &g), spin: 1.5, tone: i % 3 == 0 ? 1 : 0))
            }
        }

        switch ((index % patternCount) + patternCount) % patternCount {
        case 0: // Burst
            ring(n(18), radius: 165, delay: 0)
            ring(n(14), radius: 115, delay: 0.05, offset: 0.2)
            ring(n(16), radius: 200, delay: 0.1, offset: 0.1)
            ring(n(10), radius: 70, delay: 0.15, offset: 0.4)
        case 1: // Spiral
            let count = n(40)
            for i in 0..<count {
                let f = Double(i) / Double(count)
                out.append(BurstStar(delay: f * 0.45, duration: 0.8, r0: 10, r1: 30 + 170 * f, a0: f * 5 * .pi, a1: f * 5 * .pi + 1.2,
                                     size: size * (0.7 + 0.5 * (1 - f)), spin: 2, tone: i % 3 == 0 ? 1 : 0))
            }
        case 2: // Twin swirl, four arms
            for arm in 0..<4 {
                let base = Double(arm) * .pi / 2
                for i in 0..<n(10) {
                    let f = Double(i) / Double(n(10))
                    out.append(BurstStar(delay: f * 0.35, duration: 0.8, r0: 8, r1: 40 + 150 * f, a0: base + f * 2.2, a1: base + f * 2.2 + 1.0,
                                         size: size * (0.65 + 0.45 * (1 - f)), spin: 2, tone: (arm + i) % 3 == 0 ? 1 : 0))
                }
            }
        case 3: // Shockwave: three rings, 140 ms apart
            for (i, r) in [110.0, 170.0, 210.0].enumerated() { ring(n(22), radius: r, delay: Double(i) * 0.14, dur: 0.8, twist: 0.15, sz: size * 0.8) }
        case 4: // Scatter
            for _ in 0..<n(56) {
                let a = Double.random(in: 0...(2 * .pi), using: &g), r = 30 + 170 * sqrt(Double.random(in: 0...1, using: &g))
                out.append(BurstStar(delay: Double.random(in: 0...0.5, using: &g), duration: 0.55, r0: r, r1: r + 14, a0: a, a1: a + 0.2,
                                     size: size * Double.random(in: 0.45...1.0, using: &g), spin: 1, tone: Bool.random(using: &g) ? 1 : 0))
            }
        case 5: // Pulsar: two opposite beams sweeping, tiny core ring
            let count = n(22)
            for beam in 0..<2 {
                for i in 0..<count {
                    let f = Double(i) / Double(count)
                    let a = Double(beam) * .pi + f * 1.6
                    out.append(BurstStar(delay: f * 0.5, duration: 0.6, r0: 12, r1: 190, a0: a, a1: a + 0.05, size: size * 0.8, spin: 0.5, tone: i % 4 == 0 ? 1 : 0))
                }
            }
            ring(n(8), radius: 26, delay: 0, dur: 0.7, twist: 0.3, sz: size * 0.55)
        case 6: // Supernova: a fast shell and slower spinning debris
            ring(n(30), radius: 210, delay: 0, dur: 0.55, twist: 0.05, sz: size * 0.9)
            for i in 0..<n(26) {
                let a = Double.random(in: 0...(2 * .pi), using: &g), r = Double.random(in: 60...160, using: &g)
                out.append(BurstStar(delay: 0.05, duration: 1.1, r0: 10, r1: r, a0: a, a1: a + 2.4, size: size * Double.random(in: 0.4...0.9, using: &g),
                                     spin: 4, tone: i % 3 == 0 ? 1 : 0))
            }
        default: // Neutron star collision
            for k in 0..<2 {
                let a = Double(k) * .pi
                out.append(BurstStar(delay: 0, duration: 0.7, r0: 46, r1: 0, a0: a, a1: a + 3 * .pi, size: size * 1.5, spin: 6, tone: k, easeIn: true))
            }
            ring(n(16), radius: 150, delay: 0.7, dur: 0.8, twist: 0.2, sz: size * 0.8)
            ring(n(14), radius: 180, delay: 0.75, dur: 0.8, squash: 0.35, twist: 0.1, sz: size * 0.7)
        }
        return out
    }

    /// When the last star is gone (seconds).
    static func length(of stars: [BurstStar]) -> Double { stars.map { $0.delay + $0.duration }.max() ?? 0 }

    struct SplitMix: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}

/// The big heart that appears where a double-tap landed: 0 → 1.12 (14 %) → 0.96 (26 %) → 1 (38 %), hold to 78 %, then drifts up and fades.
enum DoubleTapHeartMotion {
    struct State: Equatable { var scale: Double, opacity: Double, lift: Double }
    static func state(progress p: Double, size: Double) -> State {
        guard p >= 0, p < 1 else { return State(scale: 0, opacity: 0, lift: 0) }
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
        let scale: Double, opacity: Double, lift: Double
        switch p {
        case ..<0.14: scale = lerp(0, 1.12, p / 0.14); opacity = p / 0.14; lift = 0
        case ..<0.26: scale = lerp(1.12, 0.96, (p - 0.14) / 0.12); opacity = 1; lift = 0
        case ..<0.38: scale = lerp(0.96, 1, (p - 0.26) / 0.12); opacity = 1; lift = 0
        case ..<0.78: scale = 1; opacity = 1; lift = 0
        default:
            let t = (p - 0.78) / 0.22
            scale = lerp(1, 0.85, t); opacity = 1 - t; lift = size * 0.3 * t
        }
        return State(scale: scale, opacity: opacity, lift: lift)
    }
}
