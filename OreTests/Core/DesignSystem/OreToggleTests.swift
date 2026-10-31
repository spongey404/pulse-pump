import Testing
import Foundation
@testable import Ore

@MainActor
struct OreToggleTests {
    @Test func theBundledJSONEqualsTheFallback() throws {
        let url = try #require(Bundle.main.url(forResource: "oreToggle.config", withExtension: "json"))
        #expect(try JSONDecoder().decode(OreToggleConfig.self, from: Data(contentsOf: url)) == OreToggleConfig.fallback)
    }

    @Test func theDesignsNumbers() {
        let c = OreToggleConfig.fallback
        #expect(c.track.width == 56 && c.track.height == 32 && c.track.radius == 8 && c.track.border == 1)
        #expect(c.knob.size == 24 && c.knob.radius == 6 && c.knob.inset == 3 && c.knob.travel == 24)
        #expect(c.durationMs == 250 && c.minRowHeight == 44 && c.disabledOpacity == 0.4)
        #expect(c.light.offTrack == [224, 229, 235, 1] && c.dark.offKnob == [255, 255, 255, 0.55])
        #expect(c.star.size == 12 && c.star.colorHex == "#FFC83D")
        #expect(c.fx.fps == 30 && c.fx.gold == 0.4 && c.fx.sparkle == 0.55)
        #expect(c.row.padV == 14 && c.row.padH == 16 && c.row.gapV == 6 && c.row.gapH == 16)
    }

    @Test func theKnobEndsThreePointsFromTheTrackEdgeWhenOn() {
        let c = OreToggleConfig.fallback
        // The knob sits border + inset from the left; ON it has moved `travel`, so the gap to the right edge equals the inset.
        let left = c.track.border + c.knob.inset + c.knob.travel
        #expect(c.track.width - (left + c.knob.size) == c.track.border + c.knob.inset)
    }

    @Test func theToggleStardustVariantMatchesTheDesign() {
        let v = StardustConfig.fallback.variant("toggle")
        #expect(v.mini == true && v.speedScale == 0.3 && v.sizeScale == 0.6 && v.min == 18 && v.pull == 0)
    }
}
