import Foundation

/// A small seedable generator, so a field can be rebuilt identically (tests) and so the engine never touches global state.
struct StarRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double.random(in: 0..<1, using: &self) }
}

/// One instance's settings once the global config, the variant and the caller's overrides are merged.
struct StarFieldParams: Equatable {
    var mini: Bool
    var compact: Bool
    var count: Double          // density per 390×844 pt
    var minCount: Int
    var speed: Double
    var sizeScale: Double
    var gold: Double
    var sparkle: Double
    var pull: Double           // pt around the anchor; 0 = no attraction
    var swayBase: Double, swayPerSize: Double
    var flashProb: Double, flashDecay: Double
    var flareMinSize: Double, flareLength: Double, flareFlashLength: Double, flareWidth: Double
    var palette: StarPalette
    var fps: Int

    /// Caller overrides, applied over the variant.
    struct Overrides: Equatable {
        var palette: StarPalette? = nil
        var density: Double? = nil
        var speed: Double? = nil
        var gold: Double? = nil
        var sparkle: Double? = nil
        var goldPull: Double? = nil
        var fps: Int? = nil
    }

    init(config: StarFieldConfig, variant key: String, overrides: Overrides = .init()) {
        let v = config.variant(key)
        let mini = v.mini ?? false
        self.mini = mini
        compact = (v.mode ?? .full) == .compact
        count = overrides.density ?? config.density
        minCount = v.min ?? (mini ? 12 : config.minParticles)
        speed = (overrides.speed ?? config.speed) * (v.speedScale ?? 1)
        sizeScale = v.sizeScale ?? 1
        gold = overrides.gold ?? config.gold
        sparkle = overrides.sparkle ?? config.sparkle
        let basePull = overrides.goldPull ?? config.goldPull
        pull = v.pull ?? basePull * (v.pullScale ?? 1)
        // A Mini sways less, flashes twice as often and fades quicker; its flares are shorter and finer.
        swayBase = mini ? 1.5 : config.sway.base
        swayPerSize = mini ? 2 : config.sway.perSize
        flashProb = mini ? config.flash.prob * 2 : config.flash.prob
        flashDecay = mini ? config.flash.decay * 2 : config.flash.decay
        flareMinSize = config.flare.minSize
        flareLength = mini ? config.flare.length - 1 : config.flare.length
        flareFlashLength = mini ? config.flare.flashLength - 1 : config.flare.flashLength
        flareWidth = mini ? config.flare.width - 0.1 : config.flare.width
        palette = overrides.palette ?? StarPalette(config.palettes[config.defaultPalette] ?? StarFieldConfig.fallback.palettes["sky"]!) ?? StarPalette.derived(fromAccent: StarRGBA(r: 61, g: 184, b: 255))
        fps = overrides.fps ?? 30
    }
}

/// What one frame draws. Filled by `StarFieldEngine.step` into reused arrays (nothing is allocated per frame).
struct StarDot {
    var x: Double, y: Double, radius: Double
    var color: StarRGBA          // alpha already applied
    /// Drawn over the background normally (gold, or a star that has turned gold); otherwise additively.
    var solid: Bool
    /// Gold dots also get a small bright highlight offset toward the top left.
    var highlight: Bool
    /// 0 gold, 1 silver, 2 blue, 3 white: lets the renderer batch dots of one colour into a single draw.
    var kind: UInt8
    /// How far this star has been pulled toward gold (0 = not at all). Pulled stars are drawn one by one.
    var pulled: Double
}
struct StarFlare { var x: Double, y: Double, length: Double, color: StarRGBA }

/// The particle simulation: positions, twinkle, flashes, flares and the pull toward the gold anchor. Pure maths on
/// plain values (no SwiftUI), a port of the design's canvas loop, so it is deterministic under a seed and testable.
struct StarFieldEngine {
    enum Kind: UInt8 { case gold, silver, blue, white }

    private struct Particle {
        var u: Double, v: Double, w: Double, z: Double
        var tw: Double, tws: Double
        var fl: Double = 0
        var kind: Kind
        var k: Double = 0
    }

    let params: StarFieldParams
    private(set) var size: CGSize
    private var particles: [Particle] = []
    private var rng: StarRandom
    private let depth: Double, flareK: Double, flashP: Double

    private(set) var dots: [StarDot] = []
    private(set) var flares: [StarFlare] = []

    var count: Int { particles.count }

    /// Particle count for a view of this area: scales with area so small views stay cheap.
    static func particleCount(params: StarFieldParams, size: CGSize) -> Int {
        let n = (params.count * Double(size.width * size.height) / StarFieldConfig.referenceArea).rounded()
        return max(params.minCount, Int(n))
    }

    init(params: StarFieldParams, size: CGSize, seed: UInt64 = 1) {
        self.params = params
        self.size = size
        rng = StarRandom(seed: seed)
        let s = params.sparkle
        depth = min(1, s * 1.5)
        flashP = params.flashProb * pow(s / 0.6, 2)
        flareK = s / 0.6
        let n = Self.particleCount(params: params, size: size)
        particles.reserveCapacity(n)
        for _ in 0..<n {
            let r = rng.unit()
            let kind: Kind = r < params.gold ? .gold : r < params.gold + 0.4 ? .silver : r < params.gold + 0.66 ? .blue : .white
            let base = 0.5 + rng.unit() * (kind == .gold ? 1.9 : 1.5)
            particles.append(Particle(u: rng.unit(), v: rng.unit(), w: rng.unit(), z: base * params.sizeScale,
                                      tw: rng.unit() * 6.28, tws: 0.002 + rng.unit() * 0.005, kind: kind))
        }
        dots.reserveCapacity(n)
        flares.reserveCapacity(n / 8 + 8)
    }

    private func color(of kind: Kind) -> StarRGBA {
        switch kind {
        case .gold: .gold
        case .silver: .silver
        case .blue: params.mini ? .pinkWhite : .lightBlue
        case .white: .white
        }
    }

    /// Advances to time `t` (ms since the field started) and fills `dots` and `flares`. `anchor` is the gold
    /// anchor (the wordmark's asterisk) in this view's own coordinates, nil when it isn't known.
    mutating func step(t: Double, anchor: CGPoint?) {
        dots.removeAll(keepingCapacity: true)
        flares.removeAll(keepingCapacity: true)
        let W = Double(size.width), H = Double(size.height)
        let margin = params.mini ? 8.0 : 40.0, offset = params.mini ? 4.0 : 20.0
        let span = H + margin
        let pull = params.pull
        for i in particles.indices {
            var p = particles[i]
            let speed = (0.012 + p.w * 0.03) * params.speed
            var y = (p.v * span - t * speed).truncatingRemainder(dividingBy: span)
            if y < 0 { y += span }
            y -= offset
            let x = p.u * W + sin(t * 0.0012 * (0.5 + p.w) + p.tw) * (params.swayBase + p.z * params.swayPerSize)
            if p.fl <= 0 && rng.unit() < flashP { p.fl = 1 }
            p.fl = max(0, p.fl - params.flashDecay)
            let tw = 0.5 + 0.5 * sin(p.tw + t * p.tws)
            let flick = (1 - depth) + depth * (0.5 + 0.5 * sin(t * 0.02 * (0.6 + p.w) + p.tw * 3))
            let al = min(1, (0.2 + tw * 0.7) * flick + p.fl)
            let z = p.z * (0.55 + tw * 0.5 + p.fl * 0.6)

            var k = 0.0
            if p.kind != .gold, pull > 0, let a = anchor {
                let d = hypot(x - Double(a.x), y - Double(a.y))
                k = max(0, 1 - d / pull)
                k = k * k * (3 - 2 * k)
            }
            p.k = k
            if p.kind == .gold {
                var c = StarRGBA.gold; c.a = al
                dots.append(StarDot(x: x, y: y, radius: z, color: c, solid: true, highlight: !params.mini, kind: p.kind.rawValue, pulled: 0))
            } else if params.mini {
                if k > 0.3 {
                    var c = color(of: p.kind).mixed(toward: .gold, k); c.a = al
                    dots.append(StarDot(x: x, y: y, radius: z, color: c, solid: true, highlight: false, kind: p.kind.rawValue, pulled: k))
                } else {
                    var c = color(of: p.kind); c.a = al * 0.9
                    dots.append(StarDot(x: x, y: y, radius: z, color: c, solid: false, highlight: false, kind: p.kind.rawValue, pulled: 0))
                }
            } else {
                var c = color(of: p.kind)
                if k > 0 { c = c.mixed(toward: .gold, k) }
                c.a = min(1, al * (0.9 + k * 0.3))
                dots.append(StarDot(x: x, y: y, radius: z * (1 + k * 0.25), color: c, solid: k > 0.3, highlight: false, kind: p.kind.rawValue, pulled: k))
            }

            let flare = max((tw - 0.9) * 6 * flick, p.fl) * flareK
            if flare > 0.05 && p.z > params.flareMinSize * params.sizeScale {
                let gold = p.kind == .gold || p.k > 0.4
                var c = gold ? StarRGBA.goldFlare : color(of: p.kind)
                c.a = min(1, flare)
                let length = p.z * (params.flareLength + p.fl * params.flareFlashLength)
                flares.append(StarFlare(x: x, y: y, length: length, color: c))
            }
            particles[i] = p
        }
    }
}
