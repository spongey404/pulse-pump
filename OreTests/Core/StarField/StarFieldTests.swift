import Testing
import Foundation
@testable import Ore

struct StarFieldTests {
    private let config = StarFieldConfig.fallback
    private let phone = CGSize(width: 390, height: 844)

    private func engine(_ variant: String, size: CGSize? = nil, overrides: StarFieldParams.Overrides = .init(), seed: UInt64 = 7) -> StarFieldEngine {
        StarFieldEngine(params: StarFieldParams(config: config, variant: variant, overrides: overrides), size: size ?? phone, seed: seed)
    }

    // MARK: config

    @Test func theBundledJSONMatchesTheShippedFallback() throws {
        let url = try #require(Bundle.main.url(forResource: "starfield.config", withExtension: "json"),
                               "starfield.config.json ships in the app bundle")
        let decoded = try #require(StarFieldConfig.load(from: Data(contentsOf: url)))
        #expect(decoded == StarFieldConfig.fallback, "the JSON (shared with Android) and the Swift fallback must not drift apart")
    }

    @Test func aBrokenRemotePayloadIsIgnored() async {
        await MainActor.run {
            let store = StarFieldConfigStore()
            #expect(!store.applyRemote(json: Data("{ nope".utf8)))
            #expect(store.current == store.base)
        }
    }

    @Test func variantsMergeOverTheGlobalDefaults() {
        let full = StarFieldParams(config: config, variant: "paywall")
        #expect(!full.mini && !full.compact && full.speed == 1.1 && full.pull == 180 && full.minCount == 40)
        let banner = StarFieldParams(config: config, variant: "banner")
        #expect(banner.compact && !banner.mini)
        #expect(abs(banner.pull - 180 * 0.45) < 1e-9, "the banner pulls over 45% of the radius")
        let tag = StarFieldParams(config: config, variant: "tag")
        #expect(tag.mini && tag.minCount == 26 && tag.sizeScale == 0.5)
        #expect(abs(tag.speed - 1.1 * 0.2) < 1e-9 && abs(tag.pull - 180 * 0.12) < 1e-9)
        #expect(StarFieldParams(config: config, variant: "avatar").pull == 0, "the avatar has no pull")
        #expect(StarFieldParams(config: config, variant: "recapCard").minCount == 120)
        #expect(StarFieldParams(config: config, variant: "rowIcon").minCount == 18)
    }

    @Test func overridesWinOverTheConfig() {
        let p = StarFieldParams(config: config, variant: "paywall", overrides: .init(density: 300, speed: 2, gold: 0.2, sparkle: 1, goldPull: 50, fps: 24))
        #expect(p.count == 300 && p.speed == 2 && p.gold == 0.2 && p.sparkle == 1 && p.pull == 50 && p.fps == 24)
    }

    @Test func aMiniSwaysLessAndFlashesMore() {
        let mini = StarFieldParams(config: config, variant: "tag"), full = StarFieldParams(config: config, variant: "paywall")
        #expect(mini.swayBase == 1.5 && mini.swayPerSize == 2 && full.swayBase == 6 && full.swayPerSize == 5)
        #expect(mini.flashProb == 0.003 && mini.flashDecay == 0.08 && full.flashProb == 0.0015 && full.flashDecay == 0.04)
        #expect(mini.flareLength == 3 && mini.flareFlashLength == 4 && mini.flareWidth == 0.6)
        #expect(full.flareLength == 4 && full.flareFlashLength == 5 && full.flareWidth == 0.7)
    }

    // MARK: particles

    @Test func aFullScreenHasAboutSixteenHundredParticlesAndSmallViewsScaleWithArea() {
        #expect(engine("paywall").count == 1600)
        #expect(engine("paywall", size: CGSize(width: 195, height: 422)).count == 400, "a quarter of the area, a quarter of the stars")
        #expect(engine("paywall", size: CGSize(width: 20, height: 20)).count == 40, "never fewer than the minimum")
        #expect(engine("tag", size: CGSize(width: 70, height: 20)).count == 26)
        #expect(engine("recapCard", size: CGSize(width: 358, height: 40)).count == 120)
    }

    @Test func goldIsAboutFortyPercentOfTheStars() {
        var e = engine("paywall"); e.step(t: 0, anchor: nil)
        let gold = e.dots.filter { $0.kind == 0 }.count
        #expect(abs(Double(gold) / Double(e.count) - 0.4) < 0.04)
        #expect(e.dots.allSatisfy { $0.kind < 3 }, "with 40% gold the colour bands end at 1.06, so no star is plain white")
    }

    @Test func theSameSeedGivesTheSameFrame() {
        var a = engine("paywall", seed: 3), b = engine("paywall", seed: 3), c = engine("paywall", seed: 4)
        a.step(t: 1234, anchor: nil); b.step(t: 1234, anchor: nil); c.step(t: 1234, anchor: nil)
        #expect(a.dots.map(\.x) == b.dots.map(\.x))
        #expect(a.dots.map(\.x) != c.dots.map(\.x))
    }

    @Test func starsRiseAndWrapInsideTheViewPlusItsMargin() {
        var e = engine("paywall")
        for t in stride(from: 0.0, through: 90_000, by: 3_000) {
            e.step(t: t, anchor: nil)
            #expect(e.dots.allSatisfy { $0.y >= -20.001 && $0.y <= 844 + 20.001 })
        }
        var m = engine("tag", size: CGSize(width: 70, height: 20))
        m.step(t: 40_000, anchor: nil)
        #expect(m.dots.allSatisfy { $0.y >= -4.001 && $0.y <= 24.001 }, "a Mini wraps with a 4pt margin")
        var early = engine("paywall"), late = engine("paywall")
        early.step(t: 0, anchor: nil); late.step(t: 1000, anchor: nil)
        let moved = zip(early.dots, late.dots).filter { $0.0.y > 100 && $0.1.y < $0.0.y }.count
        #expect(moved > early.count / 2, "most stars are higher a second later: they rise")
    }

    // MARK: attraction

    @Test func starsNearTheAnchorTurnGold() {
        var near = engine("paywall"), none = engine("paywall")
        let anchor = CGPoint(x: 200, y: 300)
        near.step(t: 500, anchor: anchor); none.step(t: 500, anchor: nil)
        let pulled = near.dots.filter { $0.pulled > 0 }
        #expect(!pulled.isEmpty)
        #expect(pulled.allSatisfy { hypot($0.x - 200, $0.y - 300) < 180 }, "only stars inside the radius")
        #expect(none.dots.allSatisfy { $0.pulled == 0 }, "no anchor, no pull")
        let closest = pulled.max { $0.pulled < $1.pulled }!
        #expect(closest.pulled > 0.5)
        #expect(closest.color.r > 200 && closest.color.b < 200 || closest.kind == 0, "pulled stars lean toward gold (255,196,48)")
        #expect(pulled.filter { $0.pulled > 0.3 }.allSatisfy { $0.solid }, "past 0.3 a pulled star is drawn solid so it doesn't wash to white")
    }

    @Test func theBannerPullsOverAShorterRadiusAndTheAvatarNotAtAll() {
        var banner = engine("banner", size: CGSize(width: 358, height: 68))
        banner.step(t: 500, anchor: CGPoint(x: 150, y: 20))
        #expect(banner.dots.filter { $0.pulled > 0 }.allSatisfy { hypot($0.x - 150, $0.y - 20) < 180 * 0.45 })
        var avatar = engine("avatar", size: CGSize(width: 48, height: 48))
        avatar.step(t: 500, anchor: CGPoint(x: 24, y: 24))
        #expect(avatar.dots.allSatisfy { $0.pulled == 0 })
    }

    // MARK: flicker

    @Test func goldIsSolidWithAHighlightAndOtherStarsAreAdditive() {
        var e = engine("paywall"); e.step(t: 900, anchor: nil)
        #expect(e.dots.filter { $0.kind == 0 }.allSatisfy { $0.solid && $0.highlight })
        #expect(e.dots.filter { $0.kind != 0 }.allSatisfy { !$0.solid })
        var m = engine("tag", size: CGSize(width: 70, height: 20)); m.step(t: 900, anchor: nil)
        #expect(m.dots.filter { $0.kind == 0 }.allSatisfy { $0.solid && !$0.highlight }, "a Mini's gold is a single solid dot")
    }

    @Test func flaresOnlyComeFromLargerStarsAndAreGoldForGoldOnes() {
        var e = engine("paywall")
        var seen = 0
        for t in stride(from: 0.0, to: 20_000, by: 250) {
            e.step(t: t, anchor: nil)
            seen += e.flares.count
            #expect(e.flares.allSatisfy { $0.color.a > 0.05 && $0.length > 0 })
        }
        #expect(seen > 0, "stars flare now and then")
    }

    @Test func lowSparkleMeansNoFlicker() {
        var calm = engine("paywall", overrides: .init(sparkle: 0)), lively = engine("paywall", overrides: .init(sparkle: 1.5))
        var calmFlares = 0, livelyFlares = 0
        for t in stride(from: 0.0, to: 10_000, by: 250) {
            calm.step(t: t, anchor: nil); lively.step(t: t, anchor: nil)
            calmFlares += calm.flares.count; livelyFlares += lively.flares.count
        }
        #expect(calmFlares == 0 && livelyFlares > calmFlares)
    }

    // MARK: palettes

    @Test func cssColoursParse() {
        #expect(StarRGBA(css: "#1A7FE0") == StarRGBA(r: 26, g: 127, b: 224))
        #expect(StarRGBA(css: "rgba(15,90,190,0.30)") == StarRGBA(r: 15, g: 90, b: 190, a: 0.30))
        #expect(StarRGBA(css: "nonsense") == nil)
        #expect(StarPalette(config.palettes["sky"]!)?.accent.hex == "#3DB8FF")
    }

    @Test func aMemberPaletteKeepsTheirAccentInTheMiddleWithADeeperAndALighterStop() throws {
        let accent = try #require(StarRGBA(css: "#FD4A9F"))
        let p = StarPalette.derived(fromAccent: accent)
        #expect(p.accent == accent)
        #expect(p.deep.hsv.v < accent.hsv.v && p.light.hsv.s < accent.hsv.s && p.light.hsv.v >= accent.hsv.v)
        // The same recipe applied to the Sky accent lands near the design's own stops.
        let sky = StarPalette.derived(fromAccent: StarRGBA(css: "#3DB8FF")!)
        #expect(abs(sky.deep.hsv.h - StarRGBA(css: "#1A7FE0")!.hsv.h) < 12)
        #expect(abs(sky.light.hsv.h - StarRGBA(css: "#9FDDFF")!.hsv.h) < 12)
    }
}


@MainActor
struct RemoteConfigGuardTests {
    @Test func aRemoteStarFieldConfigWithAbsurdOrNonFiniteNumbersIsRejected() throws {
        func json(_ edit: (inout [String: Any]) -> Void) throws -> Data {
            let url = try #require(Bundle.main.url(forResource: "starfield.config", withExtension: "json"))
            var obj = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            edit(&obj)
            return try JSONSerialization.data(withJSONObject: obj)
        }
        #expect(StarFieldConfig.load(from: try json { _ in }) == StarFieldConfig.fallback, "the shipped file is valid")
        #expect(StarFieldConfig.load(from: try json { $0["density"] = 1e12 }) == nil, "millions of particles")
        #expect(StarFieldConfig.load(from: try json { $0["density"] = -5 }) == nil)
        #expect(StarFieldConfig.load(from: try json { $0["fps"] = ["paywall": 0, "paywallIdle": 30, "more": 30] }) == nil)
        #expect(StarFieldConfig.load(from: try json { $0["speed"] = 1e300 }) == nil)
    }
}
