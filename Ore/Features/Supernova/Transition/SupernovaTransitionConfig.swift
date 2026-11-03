import Foundation

/// Every number of the More-tab banner ⇄ Supernova paywall transition (design "Supernova Transition Final"): durations,
/// curves, the More layer's scale and opacity, content offsets and stagger, the flyer's size, the hand-off times.
/// Shared with Android through `Resources/supernovaTransition.config.json` (`fallback` must equal it, a test checks);
/// Remote Config key `supernova_transition_config` replaces it.
struct SupernovaTransitionConfig: Codable, Equatable {
    /// A CSS `cubic-bezier(x1, y1, x2, y2)`.
    typealias Curve = [Double]

    struct Open: Codable, Equatable {
        var maskMs: Double, maskCurve: Curve
        var hubMs: Double, hubCurve: Curve
        var flyerMs: Double, flyerCurve: Curve
        var handoffMs: Double
        var bannerTextFadeMs: Double
    }
    struct Close: Codable, Equatable {
        var ms: Double, curve: Curve
        var contentFadeMs: Double
        var handoffMs: Double
        var morphAlphaExponent: Double
    }
    struct Content: Codable, Equatable {
        var groups: Int
        var fadeMs: Double
        var moveMs: Double, moveCurve: Curve
        var offsetPt: Double
        var bannerOffsetPt: Double
        var staggerMs: Double
        var startMs: Double
        var bannerItems: Int
    }
    struct Flyer: Codable, Equatable {
        var glyphSize: Double
        var startScale: Double
        var colorHex: String
        var glowRadius: Double, glowAlpha: Double
    }

    var open: Open
    var close: Close
    var content: Content
    var flyer: Flyer
    var hubScale: Double
    var hubOpacity: Double
    var hubCornerRadius: Double
    var maskRadiusStart: Double
    var maskRadiusEnd: Double
    var reduceMotionFadeMs: Double

    static func load(from data: Data) -> SupernovaTransitionConfig? {
        guard let c = try? JSONDecoder().decode(SupernovaTransitionConfig.self, from: data), c.isUsable else { return nil }
        return c
    }

    var isUsable: Bool {
        [open.maskCurve, open.hubCurve, open.flyerCurve, close.curve, content.moveCurve].allSatisfy { $0.count == 4 }
            && open.maskMs > 0 && open.flyerMs > 0 && close.ms > 0 && content.groups > 0
            && [open.maskCurve, open.hubCurve, open.flyerCurve, close.curve, content.moveCurve].allSatisfy { $0.allSatisfy(\.isFinite) }
            && [open.maskMs, open.hubMs, open.flyerMs, open.handoffMs, close.ms, close.handoffMs, content.fadeMs, content.moveMs, content.staggerMs, content.startMs]
                .allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 10_000 }
    }

    static let fallback = SupernovaTransitionConfig(
        open: Open(maskMs: 560, maskCurve: [0.32, 0.72, 0, 1], hubMs: 600, hubCurve: [0.32, 0.72, 0, 1],
                   flyerMs: 760, flyerCurve: [0.45, 0, 0.15, 1], handoffMs: 800, bannerTextFadeMs: 120),
        close: Close(ms: 560, curve: [0.45, 0, 0.15, 1], contentFadeMs: 180, handoffMs: 590, morphAlphaExponent: 2.2),
        content: Content(groups: 6, fadeMs: 520, moveMs: 720, moveCurve: [0.2, 0.8, 0.2, 1], offsetPt: 14, bannerOffsetPt: 10,
                         staggerMs: 90, startMs: 380, bannerItems: 4),
        flyer: Flyer(glyphSize: 44, startScale: 18.0 / 44.0, colorHex: "#FFC83D", glowRadius: 14, glowAlpha: 0.85),
        hubScale: 0.94, hubOpacity: 0.35, hubCornerRadius: 44, maskRadiusStart: 12, maskRadiusEnd: 44, reduceMotionFadeMs: 200
    )
}

@MainActor
final class SupernovaTransitionConfigStore {
    static let shared = SupernovaTransitionConfigStore()
    private(set) var base: SupernovaTransitionConfig
    var override: SupernovaTransitionConfig?

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "supernovaTransition.config", withExtension: "json"),
           let data = try? Data(contentsOf: url), let config = SupernovaTransitionConfig.load(from: data) {
            base = config
        } else {
            base = .fallback
        }
    }

    var current: SupernovaTransitionConfig { override ?? base }

    @discardableResult
    func applyRemote(json: Data) -> Bool {
        guard let config = SupernovaTransitionConfig.load(from: json) else { return false }
        override = config
        return true
    }
}
