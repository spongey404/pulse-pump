import Foundation

/// Everything tunable about the Supernova member experience (design "Supernova Member Flow"): the accent palettes, the page
/// Stardust (count, coverage and the mask that fades it to charcoal), the More card, and the card ⇄ page transition (same
/// shape as `SupernovaTransitionConfig`, with the member values: 4 content groups, card radius 14). Shared with Android
/// through `Resources/supernovaMember.config.json`; `fallback` must equal it (a test checks); Remote Config key
/// `supernova_member_config` replaces it.
struct SupernovaMemberConfig: Codable, Equatable {
    /// The custom accent picker (Account tab): the presets row, the hold-to-repeat and fine-scrub curves, the rules that
    /// turn a picked colour into the Stardust's palette.
    struct Picker: Codable, Equatable {
        struct HuePatch: Codable, Equatable {
            var satBelow: Int, shadeBelow: Int, shadeAbove: Int, minSat: Int, shadeMin: Int, shadeMax: Int
        }
        struct PaletteRule: Codable, Equatable {
            /// Lightness values [g0, g1, g2] for a very light accent (the colour at lightness 100 would vanish), and for a very dark one.
            var lightStops: [Double], darkStops: [Double]
            /// Normal accents: g0 = lightness − stopDark, g1 = the exact picked hex, g2 = lightness + stopLight.
            var stopDark: Double, stopLight: Double
            var blobLightness: Double, blobAlpha: Double, veilLightness: Double, veilAlpha: Double
        }
        var defaultHex: String
        /// [name, hex]; the first is the default.
        var presets: [[String]]
        var recentLimit: Int
        var holdDelayMs: Double
        /// [until seconds held, step] for hue, and for saturation and shade.
        var holdHue: [[Double]]
        var holdOther: [[Double]]
        /// [until seconds held, ms between repeats].
        var holdIntervalsMs: [[Double]]
        /// [finger distance from the strip in pt, speed factor], largest distance first.
        var fine: [[Double]]
        var huePatch: HuePatch
        var palette: PaletteRule
        /// Dark text on very light accents (white is always used while this is false).
        var lightTextOnLightAccents: Bool
    }
    struct Page: Codable, Equatable {
        var count: Double
        var speed: Double
        var gold: Double
        var sparkle: Double
        var pull: Double
        /// Share of the screen the Stardust covers (the mask below fades it out by then).
        var coverage: Double
        /// [location 0–1, opacity] stops of the vertical mask over the page Stardust.
        var maskStops: [[Double]]
        var starBullet: Double
        /// Seconds between one perk's star and the next one's phase.
        var perkOffset: Double
    }
    struct Card: Codable, Equatable {
        var radius: Double
        var padH: Double
        var padV: Double
        var gap: Double
        var count: Double
        var fps: Int
        /// Freeze the card's Stardust after this many ms (0 = keep moving).
        var settleAfterMs: Double
    }

    var picker: Picker
    var page: Page
    var card: Card
    var transition: SupernovaTransitionConfig

    static func load(from data: Data) -> SupernovaMemberConfig? {
        guard let c = try? JSONDecoder().decode(SupernovaMemberConfig.self, from: data), c.isUsable else { return nil }
        return c
    }

    var isUsable: Bool {
        picker.isUsable && page.maskStops.allSatisfy { $0.count == 2 } && !page.maskStops.isEmpty
            && transition.isUsable
            && (1...6000).contains(page.count) && (0...10).contains(page.speed) && (0...1).contains(page.gold) && (0...1).contains(page.sparkle)
            && (0...2000).contains(page.pull) && [page.coverage, page.starBullet, page.perkOffset].allSatisfy(\.isFinite)
            && page.maskStops.allSatisfy { $0.allSatisfy(\.isFinite) }
    }

    static let fallback: SupernovaMemberConfig = {
        var t = SupernovaTransitionConfig.fallback
        t.content.groups = 4
        t.content.bannerItems = 3
        t.maskRadiusStart = 14
        return SupernovaMemberConfig(
            picker: Picker(
                defaultHex: "#3DB8FF",
                presets: [["SKY", "#3DB8FF"], ["PINK", "#FD4A9F"], ["RED", "#FF001E"], ["PURPLE", "#8C0099"], ["GREEN", "#009945"], ["CYAN", "#00EBEB"],
                          ["ROSE", "#FD6892"], ["GOLD", "#FCC01D"], ["SILVER", "#C0C0C0"], ["BLACK", "#000000"], ["WHITE", "#FFFFFF"]],
                recentLimit: 11, holdDelayMs: 380,
                holdHue: [[1.5, 1], [3, 2], [5, 4], [8, 7], [1000, 12]], holdOther: [[1.5, 1], [4, 2], [1000, 4]],
                holdIntervalsMs: [[1.5, 90], [1000, 50]], fine: [[120, 0.1], [60, 0.25]],
                huePatch: .init(satBelow: 15, shadeBelow: 8, shadeAbove: 92, minSat: 85, shadeMin: 30, shadeMax: 70),
                palette: .init(lightStops: [62, 84, 100], darkStops: [0, 16, 38], stopDark: 16, stopLight: 22,
                               blobLightness: 22, blobAlpha: 0.3, veilLightness: 25, veilAlpha: 0.05),
                lightTextOnLightAccents: false),
            page: Page(count: 900, speed: 1.1, gold: 0.4, sparkle: 0.55, pull: 150, coverage: 0.65,
                       maskStops: [[0, 1], [0.51, 1], [0.59, 0.6], [0.67, 0.2], [0.73, 0]], starBullet: 13, perkOffset: 0.47),
            card: Card(radius: 14, padH: 18, padV: 16, gap: 16, count: 1600, fps: 30, settleAfterMs: 0),
            transition: t)
    }()
}

@MainActor
final class SupernovaMemberConfigStore {
    static let shared = SupernovaMemberConfigStore()
    private(set) var base: SupernovaMemberConfig
    var override: SupernovaMemberConfig?

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "supernovaMember.config", withExtension: "json"),
           let data = try? Data(contentsOf: url), let config = SupernovaMemberConfig.load(from: data) {
            base = config
        } else {
            base = .fallback
        }
    }

    var current: SupernovaMemberConfig { override ?? base }

    @discardableResult
    func applyRemote(json: Data) -> Bool {
        guard let config = SupernovaMemberConfig.load(from: json) else { return false }
        override = config
        return true
    }
}
