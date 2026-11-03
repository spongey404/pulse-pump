import Foundation

/// Every tunable of the body map (heat fill, reveal and the member Stardust). Shared source: `Resources/bodymap.config.json`
/// (an Android build reads the same file); `BodyMapConfig.fallback` must equal it (a test checks). Remote Config key `bodymap_config`.
struct BodyMapConfig: Codable, Equatable {
    struct Reveal: Codable, Equatable {
        var delayMs: Double
        var staggerMs: Double
        var fillMs: Double
        var rippleMs: Double
        var starFadeMs: Double
    }
    struct Colors: Codable, Equatable {
        var outline: String
        var muscle: String
        var ink: String
    }
    struct Theme: Codable, Equatable {
        var light: Colors
        var dark: Colors
    }

    /// Star count multiplier.
    var amount: Double
    /// Star size multiplier.
    var size: Double
    /// Twinkle depth and flash rate.
    var flicker: Double
    /// Share of gold stars.
    var gold: Double
    /// Cross-flare arm length (0 = off).
    var flare: Double
    /// How fast stars hop to new spots (scale of their life; 3.1 = the design's base).
    var lifespan: Double
    /// Drift in place (0 = still).
    var sway: Double
    var fps: Int
    var heatAccent: String
    var reveal: Reveal
    var theme: Theme

    static let fallback = BodyMapConfig(
        amount: 0.8, size: 0.95, flicker: 0.55, gold: 0.30, flare: 0.8, lifespan: 0.5, sway: 0, fps: 30,
        heatAccent: "#1AA7FF",
        reveal: .init(delayMs: 150, staggerMs: 70, fillMs: 650, rippleMs: 420, starFadeMs: 380),
        theme: .init(light: .init(outline: "#E0E5EB", muscle: "#C9D0D8", ink: "#8A929C"),
                     dark: .init(outline: "#2E2A26", muscle: "#433D37", ink: "#6E6760")))

    static func load(from data: Data) -> BodyMapConfig? {
        guard let c = try? JSONDecoder().decode(BodyMapConfig.self, from: data), c.isUsable else { return nil }
        return c
    }

    /// Finite numbers in sane ranges and well-formed colours: a bad remote value is ignored, never trusted.
    var isUsable: Bool {
        func ok(_ v: Double, _ r: ClosedRange<Double>) -> Bool { v.isFinite && r.contains(v) }
        let hexes = [heatAccent, theme.light.outline, theme.light.muscle, theme.light.ink, theme.dark.outline, theme.dark.muscle, theme.dark.ink]
        return ok(amount, 0...10) && ok(size, 0.05...5) && ok(flicker, 0...1) && ok(gold, 0...1) && ok(flare, 0...5) && ok(lifespan, 0.05...20)
            && ok(sway, 0...10) && (1...120).contains(fps)
            && ok(reveal.delayMs, 0...5000) && ok(reveal.staggerMs, 0...2000) && ok(reveal.fillMs, 1...5000)
            && ok(reveal.rippleMs, 0...5000) && ok(reveal.starFadeMs, 1...5000)
            && hexes.allSatisfy { BodyMapColor.rgb(hex: $0) != nil }
    }
}

/// Hex helpers for the map's colours (sRGB 0–1).
enum BodyMapColor {
    static func rgb(hex: String) -> (r: Double, g: Double, b: Double)? {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        return (Double(v >> 16 & 255) / 255, Double(v >> 8 & 255) / 255, Double(v & 255) / 255)
    }

    /// `color-mix(in srgb, accent pct%, base)`.
    static func mix(accent: (r: Double, g: Double, b: Double), base: (r: Double, g: Double, b: Double), pct: Double) -> (r: Double, g: Double, b: Double) {
        let a = max(0, min(1, pct / 100))
        return (base.r + (accent.r - base.r) * a, base.g + (accent.g - base.g) * a, base.b + (accent.b - base.b) * a)
    }
}

@MainActor
final class BodyMapConfigStore {
    static let shared = BodyMapConfigStore()
    private(set) var base: BodyMapConfig
    var override: BodyMapConfig?

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "bodymap.config", withExtension: "json"),
           let data = try? Data(contentsOf: url), let c = BodyMapConfig.load(from: data) {
            base = c
        } else {
            base = .fallback
        }
    }

    var current: BodyMapConfig { override ?? base }

    /// Applies remote JSON; an invalid payload is ignored.
    @discardableResult
    func applyRemote(json: Data) -> Bool {
        guard let c = BodyMapConfig.load(from: json) else { return false }
        override = c
        return true
    }
}
