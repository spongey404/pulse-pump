import Foundation

/// Every number of the post / social surfaces (timings, star counts, meter, sizes, colours). Shared source:
/// `Resources/social.config.json` (an Android build reads the same file); `SocialConfig.fallback` must equal it (a test checks).
/// The design brief called this `social.config.ts`; on iOS it is JSON + this type, like the other configs.
struct SocialConfig: Codable, Equatable {
    struct Heart: Codable, Equatable { var size: Double, durationMs: Double, doubleTapMs: Double, doubleTapSlop: Double }
    struct Like: Codable, Equatable { var popMs: Double, popScale: Double, starsMin: Int, starsMax: Int }
    struct Burst: Codable, Equatable {
        var starSize: Double, lightStarBonus: Double
        var darkGold: String, darkWhite: String, lightGold: String, lightEdge: String
    }
    struct Meter: Codable, Equatable {
        var bars: Int, barWidth: Double, barHeight: Double, barRadius: Double, gap: Double, idleAlpha: Double
        var loopMinS: Double, loopMaxS: Double, holdMs: Double, settleMs: Double, colorFadeMs: Double
    }
    struct Song: Codable, Equatable { var previewSeconds: Double, artSize: Double, playSize: Double }
    struct Card: Codable, Equatable {
        var radius: Double, avatar: Double, slideHeight: Double, swapTileWidth: Double, swapTileHeight: Double
        var previewRows: Int, menuWidth: Double, menuRowHeight: Double
    }
    struct Star: Codable, Equatable { var loopS: Double }

    var heart: Heart
    var like: Like
    var burst: Burst
    var meter: Meter
    var song: Song
    var card: Card
    var star: Star

    static let fallback = SocialConfig(
        heart: .init(size: 104, durationMs: 1000, doubleTapMs: 350, doubleTapSlop: 40),
        like: .init(popMs: 380, popScale: 1.25, starsMin: 18, starsMax: 26),
        burst: .init(starSize: 11, lightStarBonus: 1.25, darkGold: "#FFC83D", darkWhite: "#FFFFFF", lightGold: "#F2A900", lightEdge: "#E8A200"),
        meter: .init(bars: 5, barWidth: 3, barHeight: 16, barRadius: 1.5, gap: 2, idleAlpha: 0.15, loopMinS: 0.55, loopMaxS: 0.9,
                     holdMs: 20, settleMs: 550, colorFadeMs: 450),
        song: .init(previewSeconds: 30, artSize: 36, playSize: 32),
        card: .init(radius: 14, avatar: 36, slideHeight: 400, swapTileWidth: 86, swapTileHeight: 124, previewRows: 3, menuWidth: 210, menuRowHeight: 48),
        star: .init(loopS: 2.6))

    var isUsable: Bool {
        func ok(_ v: Double, _ r: ClosedRange<Double>) -> Bool { v.isFinite && r.contains(v) }
        return ok(heart.size, 10...400) && ok(heart.durationMs, 100...5000) && ok(heart.doubleTapMs, 100...1000) && ok(heart.doubleTapSlop, 1...200)
            && ok(like.popMs, 50...2000) && ok(like.popScale, 1...3) && like.starsMin >= 0 && like.starsMax >= like.starsMin && like.starsMax <= 200
            && ok(burst.starSize, 2...60) && ok(burst.lightStarBonus, 1...3)
            && (1...12).contains(meter.bars) && ok(meter.barHeight, 4...64) && ok(meter.idleAlpha, 0...1)
            && ok(meter.loopMinS, 0.1...5) && meter.loopMaxS >= meter.loopMinS && ok(meter.settleMs, 0...5000)
            && ok(song.previewSeconds, 1...120) && (1...6).contains(card.previewRows) && ok(star.loopS, 0.2...20)
    }
}

/// The live config: the bundled JSON, or the fallback if it is missing or invalid; `override` is the Remote Config hook.
final class SocialConfigStore: @unchecked Sendable {
    static let shared = SocialConfigStore()
    private let lock = NSLock()
    private var override: SocialConfig?
    private let bundled: SocialConfig

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "social.config", withExtension: "json"),
           let data = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(SocialConfig.self, from: data), c.isUsable {
            bundled = c
        } else {
            bundled = .fallback
        }
    }

    var current: SocialConfig { lock.withLock { override ?? bundled } }

    func applyRemote(json: String) {
        guard let data = json.data(using: .utf8), let c = try? JSONDecoder().decode(SocialConfig.self, from: data), c.isUsable else { return }
        lock.withLock { override = c }
    }
}
