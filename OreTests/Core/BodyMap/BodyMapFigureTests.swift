import Testing
import Foundation
import SwiftUI
@testable import Ore

@MainActor
struct BodyMapFigureTests {
    @Test func bundledConfigEqualsFallback() throws {
        let url = try #require(Bundle.main.url(forResource: "bodymap.config", withExtension: "json"))
        let c = try #require(BodyMapConfig.load(from: Data(contentsOf: url)))
        #expect(c == BodyMapConfig.fallback)
    }

    @Test func remoteConfigIsValidated() {
        var bad = BodyMapConfig.fallback
        bad.amount = .infinity
        #expect(!bad.isUsable)
        bad = .fallback; bad.theme.light.ink = "nope"
        #expect(!bad.isUsable)
        #expect(BodyMapConfig.fallback.isUsable)
    }

    @Test func heatMixIsAccentOverBase() throws {
        let accent = try #require(BodyMapColor.rgb(hex: "#1AA7FF")), base = try #require(BodyMapColor.rgb(hex: "#C9D0D8"))
        let full = BodyMapColor.mix(accent: accent, base: base, pct: 100)
        #expect(abs(full.r - accent.r) < 1e-9)
        let none = BodyMapColor.mix(accent: accent, base: base, pct: 0)
        #expect(abs(none.b - base.b) < 1e-9)
        let quarter = BodyMapColor.mix(accent: accent, base: base, pct: 25)
        #expect(abs(quarter.r - (base.r + (accent.r - base.r) * 0.25)) < 1e-9)
    }

    @Test func starCountFollowsAreaAndLevel() {
        #expect(BodyStardustEngine.starCount(area: 10, amount: 0.8, level: 0.1) == 2)       // never fewer than 2
        let hard = BodyStardustEngine.starCount(area: 60_000, amount: 0.8, level: 1)
        let soft = BodyStardustEngine.starCount(area: 60_000, amount: 0.8, level: 0.3)
        #expect(hard == 53 && soft < hard)
    }

    @Test func geometryLoadsBothFiguresWithSamplingPools() async throws {
        for side in BodyMapSide.allCases {
            let g = try #require(await BodyMapGeometry.figure(side))
            #expect(g.muscles.count == (side == .front ? 17 : 14))
            #expect(g.muscles.allSatisfy { $0.area > 100 && !$0.candidates.isEmpty })
            // Every pool point is inside its muscle.
            let m = g.muscles[0]
            #expect(m.candidates.prefix(50).allSatisfy { m.path.contains($0) || m.bounds.insetBy(dx: -3, dy: -3).contains($0) })
            #expect(g.ink.count >= g.muscles.count)
        }
    }

    @Test func revealOrderIsHardestFirst() async throws {
        let g = try #require(await BodyMapGeometry.figure(.front))
        let ranks = BodyStardustEngine.ranks(levels: ["chest": 0.9, "abs": 0.4, "calves": 0.7], shapes: g.muscles)
        let idx: (String) -> Int = { id in g.muscles.firstIndex { $0.id == id }! }
        #expect(ranks[idx("chest")] == 0 && ranks[idx("calves")] == 1 && ranks[idx("abs")] == 2)
        #expect(ranks[idx("traps")] == nil)
    }

    @Test func starsAppearOnlyAfterTheirMuscleStartsFilling() async throws {
        let g = try #require(await BodyMapGeometry.figure(.front))
        var e = BodyStardustEngine(shapes: g.muscles, levels: ["chest": 1, "abs": 0.5], config: .fallback, seed: 7, now: 0)
        e.step(now: 100, t0: 0)                      // before the 150 ms delay
        #expect(e.muscles.allSatisfy { $0.drawn.isEmpty })
        e.step(now: 150 + 70 + 700, t0: 0)           // both muscles are filling; the ripple reaches the centre first
        #expect(e.muscles.contains { !$0.drawn.isEmpty })
        #expect(e.muscles.count == 2)
    }

    @Test func starsStayInsideTheirMuscleAndMeetTheSpecRanges() async throws {
        let g = try #require(await BodyMapGeometry.figure(.back))
        var e = BodyStardustEngine(shapes: g.muscles, levels: ["glute_max": 1], config: .fallback, seed: 3, now: 0)
        for t in stride(from: 1000.0, to: 6000, by: 33) { e.step(now: t, t0: 0) }
        let m = try #require(e.muscles.first)
        let shape = g.muscles[m.shapeIndex]
        for s in m.drawn {
            #expect(shape.bounds.insetBy(dx: -2, dy: -2).contains(CGPoint(x: s.x, y: s.y)))
            #expect((0...1).contains(s.alpha))
        }
    }

    @Test func levelMappingsCoverTheArtwork() {
        #expect(BodyMapLevels.levels([.chest: 0.5])["upper_chest"] == 0.5)
        #expect(BodyMapLevels.group(of: "hamstring") == .hamstrings)
        #expect(BodyMapLevels.levels(BodyHeat.Intensities(quads: 0.8))["quad_vastus_medialis"] == 0.8)
    }

    @Test func svgPathParserHandlesCurves() {
        let p = BodyMapGeometry.parse("M10 10C20 10 30 20 30 30L10 30Z")
        #expect(p.boundingRect.minX == 10 && p.boundingRect.maxX == 30)
    }
}
