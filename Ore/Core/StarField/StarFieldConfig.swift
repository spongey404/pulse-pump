import Foundation

/// Every StarField tunable, in one typed value. No number lives in the renderer or the engine.
///
/// The defaults are the file `starfield.config.json` (the same JSON an Android build reads), decoded at launch;
/// `StarFieldConfig.fallback` is the copy used if the file is missing or invalid. `StarFieldConfigStore` merges
/// a remote override on top (a hook for Remote Config, see there), so values can change without a release.
struct StarFieldConfig: Codable, Equatable {
    struct Sway: Codable, Equatable { var base: Double; var perSize: Double }
    struct Flash: Codable, Equatable { var prob: Double; var decay: Double }
    struct Flare: Codable, Equatable { var minSize: Double; var length: Double; var flashLength: Double; var width: Double }
    struct FPS: Codable, Equatable { var paywall: Int; var paywallIdle: Int; var more: Int }
    struct Palette: Codable, Equatable {
        /// [deep, accent, light]
        var stops: [String]
        var blob: String
        var veil: String
    }
    struct Variant: Codable, Equatable {
        enum Mode: String, Codable { case full, compact }
        var mode: Mode? = nil
        /// A "Mini": no glow blobs, a compact gradient, finer flicker; for small views (tag, avatar, row icon, card).
        var mini: Bool? = nil
        var speedScale: Double? = nil
        var sizeScale: Double? = nil
        var min: Int? = nil
        /// Absolute gold-pull radius in pt (0 = none). Wins over `pullScale`.
        var pull: Double? = nil
        var pullScale: Double? = nil
    }

    var density: Double
    var minParticles: Int
    var speed: Double
    var gold: Double
    var sparkle: Double
    var goldPull: Double
    var sway: Sway
    var flash: Flash
    var flare: Flare
    var fps: FPS
    var idleAfterMs: Double
    var settleAfterMs: Double
    var palettes: [String: Palette]
    var defaultPalette: String
    var variants: [String: Variant]

    static let referenceArea: Double = 390 * 844

    func variant(_ key: String) -> Variant { variants[key] ?? Variant() }

    /// The shipped values, used when the bundled JSON can't be read.
    static let fallback = StarFieldConfig(
        density: 1600, minParticles: 40, speed: 1.1, gold: 0.40, sparkle: 0.55, goldPull: 180,
        sway: .init(base: 6, perSize: 5), flash: .init(prob: 0.0015, decay: 0.04),
        flare: .init(minSize: 1.1, length: 4, flashLength: 5, width: 0.7),
        fps: .init(paywall: 60, paywallIdle: 30, more: 30), idleAfterMs: 10_000, settleAfterMs: 4_000,
        palettes: ["sky": .init(stops: ["#1A7FE0", "#3DB8FF", "#9FDDFF"], blob: "rgba(15,90,190,0.30)", veil: "rgba(10,70,140,0.05)")],
        defaultPalette: "sky",
        variants: [
            "paywall": .init(mode: .full),
            "banner": .init(mode: .compact, pullScale: 0.45),
            "tag": .init(mini: true, speedScale: 0.2, sizeScale: 0.5, min: 26, pullScale: 0.12),
            "avatar": .init(mini: true, speedScale: 0.35, sizeScale: 0.8, min: 30, pull: 0),
            "rowIcon": .init(mini: true, speedScale: 0.3, sizeScale: 0.6, min: 18, pull: 0),
            "recapCard": .init(mini: true, speedScale: 0.6, sizeScale: 0.9, min: 120, pull: 0),
        ])

    static func load(from data: Data) -> StarFieldConfig? { try? JSONDecoder().decode(StarFieldConfig.self, from: data) }
}

/// Where the live config comes from: the bundled JSON, then an override.
///
/// `override` is the Remote Config hook: assign a decoded `StarFieldConfig` (or JSON through `applyRemote(json:)`)
/// and every StarField created afterwards uses it. Nothing here depends on Firebase, so no dependency is added
/// until the remote-values source is chosen (Firebase Remote Config, Statsig, …).
@MainActor
final class StarFieldConfigStore {
    static let shared = StarFieldConfigStore()
    private(set) var base: StarFieldConfig
    var override: StarFieldConfig?

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "starfield.config", withExtension: "json"),
           let data = try? Data(contentsOf: url), let config = StarFieldConfig.load(from: data) {
            base = config
        } else {
            base = .fallback
        }
    }

    var current: StarFieldConfig { override ?? base }

    /// Applies remote JSON; an invalid payload is ignored (the previous values stay).
    @discardableResult
    func applyRemote(json: Data) -> Bool {
        guard let config = StarFieldConfig.load(from: json) else { return false }
        override = config
        return true
    }
}
