import Foundation

/// The sign-up screen's star simulation: a pure, seedable port of the design's canvas loop. It starts empty and fills to
/// the paywall's density as the answers come in (`level`), and surges (`boost`: stars speed up and stretch into streaks)
/// each time a step is answered. No SwiftUI types, so it is testable and portable. Tunables: `SignupConfig.stars`.
struct SignupStarEngine {
    struct Dot { var x: Double, y: Double, radius: Double, alpha: Double, kind: UInt8 }   // kind: 0 gold, 1 silver, 2 blue, 3 white
    struct Streak { var x: Double, y: Double, y2: Double, alpha: Double, kind: UInt8 }
    struct Flare { var x: Double, y: Double, length: Double, alpha: Double, gold: Bool }

    private struct Particle {
        var x: Double, y: Double, z: Double
        var tw: Double, tws: Double, w: Double
        var fl: Double = 0
        var kind: UInt8
    }

    let config: SignupConfig.Stars
    private(set) var size: CGSize
    private var particles: [Particle] = []
    private var rng: StarRandom

    private(set) var dots: [Dot] = []
    private(set) var streaks: [Streak] = []
    private(set) var flares: [Flare] = []

    var count: Int { particles.count }
    /// Particles drawn at this level: none at 0, all at 1, eased in between.
    func shown(level lv: Double) -> Int {
        let l = max(0, min(1, lv))
        return Int((Double(particles.count) * l * (config.visibleBase + config.visibleCurve * l)).rounded())
    }

    static func particleCount(config: SignupConfig.Stars, size: CGSize) -> Int {
        max(1, Int((config.count * Double(size.width * size.height) / (390 * 844)).rounded()))
    }

    init(config: SignupConfig.Stars, size: CGSize, seed: UInt64 = 1) {
        self.config = config
        self.size = size
        rng = StarRandom(seed: seed)
        let n = Self.particleCount(config: config, size: size)
        for _ in 0..<n {
            let r = rng.unit()
            let kind: UInt8 = r < config.gold ? 0 : r < config.gold + config.silver ? 1 : r < config.gold + config.silver + config.blue ? 2 : 3
            let z = config.sizeBase + rng.unit() * (kind == 0 ? config.sizeGold : config.sizeOther)
            particles.append(Particle(x: rng.unit() * Double(size.width), y: rng.unit() * Double(size.height), z: z,
                                      tw: rng.unit() * 6.28, tws: config.twinkleMin + rng.unit() * (config.twinkleMax - config.twinkleMin),
                                      w: rng.unit(), kind: kind))
        }
        dots.reserveCapacity(n); flares.reserveCapacity(n / 6); streaks.reserveCapacity(n)
    }

    /// Advances to time `t` (ms) with `dt` ms since the last frame, drawing the first `shown(level:)` stars.
    mutating func step(t: Double, dt: Double, level: Double, boost b: Double) {
        dots.removeAll(keepingCapacity: true); streaks.removeAll(keepingCapacity: true); flares.removeAll(keepingCapacity: true)
        let W = Double(size.width), H = Double(size.height)
        let c = config
        for k in 0..<shown(level: level) {
            var p = particles[k]
            let v = (c.riseBase + p.w * c.risePerW + b * c.boostRise) * dt * c.riseScale
            p.y -= v
            if p.y < -10 { p.y = H + 10; p.x = rng.unit() * W }
            let x = p.x + sin(t * c.swaySpeed * (0.5 + p.w) + p.tw) * (c.swayBase + p.z * c.swayPerSize)
            if rng.unit() < c.flashProb { p.fl = 1 }
            p.fl = max(0, p.fl - c.flashDecay)
            let tw = 0.5 + 0.5 * sin(p.tw + t * p.tws)
            let flick = c.flickerMin + (1 - c.flickerMin) * (0.5 + 0.5 * sin(t * c.flickerSpeed * (0.6 + p.w) + p.tw * 3))
            let a = min(1, (0.2 + tw * 0.7) * flick + p.fl + b * c.boostAlpha)
            let radius = p.z * (0.45 + tw * 0.4 + p.fl * 0.6)
            particles[k] = p
            if b > c.streakThreshold {
                streaks.append(Streak(x: x, y: p.y, y2: p.y + v * c.streakLength, alpha: a, kind: p.kind))
                continue
            }
            dots.append(Dot(x: x, y: p.y, radius: radius, alpha: a, kind: p.kind))
            let flare = max((tw - c.flareThreshold) * 6 * flick, p.fl)
            if p.z > c.flareMinSize, flare > 0.05 {
                flares.append(Flare(x: x, y: p.y, length: p.z * (c.flareArm + p.fl * c.flareFlashArm), alpha: min(1, flare) * 0.9, gold: p.kind == 0))
            }
        }
    }

    /// The level the background eases toward: answered steps over all steps (0 on the opening screen).
    static func level(answered: Int, total: Int) -> Double { total > 0 ? min(1, Double(answered) / Double(total)) : 0 }
}

/// The Stardust inside the progress bar's filled part: specks drifting right, twinkling, faster during a surge.
struct SignupBarStardust {
    struct Speck { var x: Double, y: Double, radius: Double, alpha: Double, gold: Bool, silver: Bool }

    private struct Particle { var x: Double, y: Double, z: Double, tw: Double, s: Double, v: Double, fl: Double = 0, gold: Bool, silver: Bool }

    let config: SignupConfig.Bar
    private(set) var width: Double
    private var particles: [Particle] = []
    private var rng: StarRandom
    private(set) var specks: [Speck] = []

    init(config: SignupConfig.Bar, width: Double, seed: UInt64 = 7) {
        self.config = config
        self.width = width
        rng = StarRandom(seed: seed)
        for _ in 0..<config.specks {
            let r = rng.unit()
            particles.append(Particle(x: rng.unit() * width, y: rng.unit() * config.height,
                                      z: config.sizeMin + rng.unit() * (config.sizeMax - config.sizeMin),
                                      tw: rng.unit() * 6.28, s: 0.004 + rng.unit() * 0.01,
                                      v: config.speedMin + rng.unit() * (config.speedMax - config.speedMin),
                                      gold: r < config.goldShare, silver: r >= config.goldShare && r < config.goldShare + config.silverShare))
        }
    }

    mutating func step(t: Double, dt: Double, boost b: Double) {
        specks.removeAll(keepingCapacity: true)
        for i in particles.indices {
            var p = particles[i]
            p.x += p.v * dt * (1 + b * config.boostSpeed)
            if p.x > width + 2 { p.x = -2; p.y = rng.unit() * config.height }
            if rng.unit() < config.flashProb { p.fl = 1 }
            p.fl = max(0, p.fl - config.flashDecay)
            let tw = 0.5 + 0.5 * sin(p.tw + t * p.s)
            specks.append(Speck(x: p.x, y: p.y, radius: p.z * (0.6 + tw * 0.5 + p.fl * 0.8),
                                alpha: min(1, 0.25 + tw * 0.7 + p.fl), gold: p.gold, silver: p.silver))
            particles[i] = p
        }
    }
}
