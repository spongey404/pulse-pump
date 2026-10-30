import Foundation

/// Everything tunable about the Supernova member experience (design "Supernova Member Flow"): the accent palettes, the page
/// glitter (count, coverage and the mask that fades it to charcoal), the More card, and the card ⇄ page transition (same
/// shape as `SupernovaTransitionConfig`, with the member values: 4 content groups, card radius 14). Shared with Android
/// through `Resources/supernovaMember.config.json`; `fallback` must equal it (a test checks); Remote Config key
/// `supernova_member_config` replaces it.
struct SupernovaMemberConfig: Codable, Equatable {
    struct Accent: Codable, Equatable {
        var id: String
        var name: String
        /// The app's accent when this is picked.
        var hex: String
        /// The glitter's gradient: [g0, g1, g2].
        var stops: [String]
        var blob: String
        var veil: String
    }
    struct Page: Codable, Equatable {
        var count: Double
        var speed: Double
        var gold: Double
        var sparkle: Double
        var pull: Double
        /// Share of the screen the glitter covers (the mask below fades it out by then).
        var coverage: Double
        /// [location 0–1, opacity] stops of the vertical mask over the page glitter.
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
        /// Freeze the card's glitter after this many ms (0 = keep moving).
        var settleAfterMs: Double
    }

    var accents: [Accent]
    var defaultAccent: String
    var page: Page
    var card: Card
    var transition: SupernovaTransitionConfig

    static func load(from data: Data) -> SupernovaMemberConfig? {
        guard let c = try? JSONDecoder().decode(SupernovaMemberConfig.self, from: data), c.isUsable else { return nil }
        return c
    }

    var isUsable: Bool {
        !accents.isEmpty && accents.allSatisfy { $0.stops.count == 3 && StarRGBA(css: $0.hex) != nil }
            && accents.contains { $0.id == defaultAccent } && page.maskStops.allSatisfy { $0.count == 2 } && !page.maskStops.isEmpty
            && transition.isUsable
    }

    func accent(id: String?) -> Accent { accents.first { $0.id == id } ?? accents.first { $0.id == defaultAccent } ?? accents[0] }

    static let fallback: SupernovaMemberConfig = {
        var t = SupernovaTransitionConfig.fallback
        t.content.groups = 4
        t.content.bannerItems = 3
        t.maskRadiusStart = 14
        return SupernovaMemberConfig(
            accents: [
                Accent(id: "sky", name: "SKY", hex: "#3DB8FF", stops: ["#1A7FE0", "#3DB8FF", "#9FDDFF"], blob: "rgba(15,90,190,0.30)", veil: "rgba(10,70,140,0.05)"),
                Accent(id: "pink", name: "PINK · FD4A9F", hex: "#FD4A9F", stops: ["#C2186B", "#FD4A9F", "#FFB3D6"], blob: "rgba(140,10,70,0.30)", veil: "rgba(110,10,60,0.05)"),
                Accent(id: "red", name: "SIGNAL RED", hex: "#FF5A4A", stops: ["#B3261E", "#E5281C", "#FF8A7A"], blob: "rgba(120,15,10,0.30)", veil: "rgba(100,15,10,0.05)"),
                Accent(id: "violet", name: "VIOLET", hex: "#A78BFA", stops: ["#5B2BD9", "#8B5CF6", "#C4B5FD"], blob: "rgba(50,20,140,0.30)", veil: "rgba(40,15,110,0.05)"),
                Accent(id: "teal", name: "TEAL", hex: "#2DD4BF", stops: ["#047C74", "#14B8A6", "#99F6E4"], blob: "rgba(0,70,65,0.30)", veil: "rgba(0,60,55,0.05)"),
            ],
            defaultAccent: "sky",
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

extension SupernovaMemberConfig.Accent {
    var rgba: StarRGBA { StarRGBA(css: hex) ?? StarRGBA(r: 61, g: 184, b: 255) }
    /// The glitter palette exactly as the design lists it (not derived).
    var palette: StarPalette {
        StarPalette(deep: StarRGBA(css: stops[0]) ?? .white, accent: StarRGBA(css: stops[1]) ?? .white, light: StarRGBA(css: stops[2]) ?? .white,
                    blob: StarRGBA(css: blob) ?? .clear, veil: StarRGBA(css: veil) ?? .clear)
    }
}
