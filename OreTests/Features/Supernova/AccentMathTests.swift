import Testing
import Foundation
@testable import Ore

@MainActor
struct AccentMathTests {
    private let picker = SupernovaMemberConfig.fallback.picker
    private func pick(_ hex: String) -> AccentPick { let c = AccentMath.hsl(fromHex: hex)!; return AccentPick(h: c.h, s: c.s, l: c.l, hex: hex) }

    @Test func hexAndHslRoundTripAndShorthandIsAccepted() {
        #expect(AccentMath.normalizeHex("abc") == "#AABBCC" && AccentMath.normalizeHex("#3db8ff") == "#3DB8FF" && AccentMath.normalizeHex(" 3DB8FF ") == "#3DB8FF")
        #expect(AccentMath.normalizeHex("#12345") == nil && AccentMath.normalizeHex("ggg") == nil && AccentMath.normalizeHex("") == nil)
        let sky = AccentMath.hsl(fromHex: "#3DB8FF")!
        #expect(sky.h == 202 && sky.s == 100 && sky.l == 62)
        #expect(AccentMath.hex(h: 0, s: 100, l: 50) == "#FF0000" && AccentMath.hex(h: 120, s: 100, l: 50) == "#00FF00" && AccentMath.hex(h: 240, s: 100, l: 50) == "#0000FF")
        #expect(AccentMath.hsl(fromHex: "#FFFFFF")! == (0, 0, 100) && AccentMath.hsl(fromHex: "#000000")! == (0, 0, 0))
    }

    @Test func aNormalColourGetsADeeperAndALighterStopAroundItsExactHex() {
        let p = pick("#FD4A9F")
        let stops = AccentMath.stopHexes(for: p, rule: picker.palette)
        #expect(stops[1] == "#FD4A9F", "the middle stop is the exact picked hex")
        #expect(stops[0] == AccentMath.hex(h: p.h, s: p.s, l: p.l - 16) && stops[2] == AccentMath.hex(h: p.h, s: p.s, l: p.l + 22))
    }

    @Test func veryLightAndVeryDarkColoursUseTheirOwnStops() {
        #expect(AccentMath.stopHexes(for: pick("#FFFFFF"), rule: picker.palette) == ["#9E9E9E", "#D6D6D6", "#FFFFFF"], "white would vanish at lightness 100")
        #expect(AccentMath.stopHexes(for: pick("#000000"), rule: picker.palette) == ["#000000", "#292929", "#616161"])
    }

    @Test func theGlowAndTheVeilAreTheHueAtFixedLightness() {
        let p = AccentPick(h: 330, s: 98, l: 65, hex: nil)
        let pal = AccentMath.palette(for: p, rule: picker.palette)
        #expect(pal.blob.a == 0.3 && pal.veil.a == 0.05)
        let blob = AccentMath.rgb(h: 330, s: 98, l: 22)
        #expect(Int(pal.blob.r) == blob.r && Int(pal.blob.g) == blob.g && Int(pal.blob.b) == blob.b)
    }

    @Test func movingTheHueOfAGreyBlackOrWhiteMakesTheChangeVisible() {
        let rule = picker.huePatch
        let grey = AccentPick(h: 10, s: 5, l: 50, hex: "#808080")
        let moved = AccentMath.setting(.hue, to: 200, in: grey, rule: rule)
        #expect(moved.h == 200 && moved.s == 85 && moved.l == 50 && moved.hex == nil)
        #expect(AccentMath.setting(.hue, to: 90, in: pick("#000000"), rule: rule).l == 30, "black comes up to the shade range")
        #expect(AccentMath.setting(.hue, to: 90, in: pick("#FFFFFF"), rule: rule).l == 70, "white comes down to it")
        let vivid = AccentPick(h: 10, s: 90, l: 50, hex: nil)
        #expect(AccentMath.setting(.hue, to: 200, in: vivid, rule: rule) == AccentPick(h: 200, s: 90, l: 50, hex: nil), "a vivid colour is left alone")
        #expect(AccentMath.setting(.saturation, to: 0, in: grey, rule: rule).s == 0, "only the hue is patched")
    }

    @Test func stepsClampAndTheHueWraps() {
        let rule = picker.huePatch
        let c = AccentPick(h: 359, s: 100, l: 50, hex: nil)
        #expect(AccentMath.nudged(.hue, by: 2, in: c, rule: rule).h == 1)
        #expect(AccentMath.nudged(.hue, by: -360, in: AccentPick(h: 0, s: 100, l: 50, hex: nil), rule: rule).h == 0)
        #expect(AccentMath.nudged(.hue, by: -1, in: AccentPick(h: 0, s: 100, l: 50, hex: nil), rule: rule).h == 359)
        #expect(AccentMath.nudged(.shade, by: 4, in: AccentPick(h: 0, s: 100, l: 99, hex: nil), rule: rule).l == 100)
        #expect(AccentMath.nudged(.saturation, by: -4, in: AccentPick(h: 0, s: 2, l: 50, hex: nil), rule: rule).s == 0)
        #expect(AccentMath.setting(.hue, to: 360, in: c, rule: rule).h == 360, "a drag can reach the strip's end")
    }

    @Test func holdingAccelerates() {
        #expect([0.0, 1.4, 1.6, 3.2, 5.5, 9].map { AccentMath.holdStep(.hue, seconds: $0, picker: picker) } == [1, 1, 2, 4, 7, 12])
        #expect([0.0, 1.4, 1.6, 4.5].map { AccentMath.holdStep(.shade, seconds: $0, picker: picker) } == [1, 1, 2, 4])
        #expect(AccentMath.holdStep(.saturation, seconds: 3, picker: picker) == 2)
        #expect(AccentMath.holdInterval(seconds: 1, picker: picker) == 90 && AccentMath.holdInterval(seconds: 2, picker: picker) == 50)
    }

    @Test func aFingerFarFromTheStripScrubsFinely() {
        let curve = picker.fine
        #expect([0.0, 60, 61, 120, 121].map { AccentMath.fineFactor(distance: $0, curve: curve) } == [1, 1, 0.25, 0.25, 0.1])
        #expect(AccentMath.dragged(100, dx: 40, width: 200, channel: .hue, distance: 0, curve: curve) == 172)
        #expect(abs(AccentMath.dragged(100, dx: 40, width: 200, channel: .hue, distance: 130, curve: curve) - 107.2) < 1e-9)
        #expect(AccentMath.dragged(95, dx: 400, width: 200, channel: .shade, distance: 0, curve: curve) == 100, "clamped to the strip")
    }

    @Test func theRecentRowIsKeptAsTheDesignSays() {
        let a = AccentSwatch(name: "A", hex: "#111111")!, b = AccentSwatch(name: "B", hex: "#222222")!, c = AccentSwatch(name: "C", hex: "#333333")!
        #expect(AccentMath.committed([a, b, c], pick: a.pick, limit: 3) == [a, b, c], "already first: nothing changes")
        #expect(AccentMath.committed([a, b, c], pick: b.pick, limit: 3) == [b, a, c], "already in the row: it moves to the front")
        let new = AccentMath.committed([a, b, c], pick: AccentPick(h: 0, s: 0, l: 50, hex: "#808080"), limit: 3)
        #expect(new.map(\.hex) == ["#808080", "#111111", "#222222"] && new[0].name == "RECENT", "otherwise everything shifts right and the last drops off")
        #expect(AccentMath.name(for: b.pick, in: [a, b, c]) == "B" && AccentMath.name(for: pick("#123456"), in: [a, b, c]) == "CUSTOM")
    }

    @Test func aSavedRowIsDeduplicatedAndFilledFromThePresets() {
        let sky = AccentSwatch(name: "SKY", hex: "#3DB8FF")!
        let out = AccentMath.normalized([sky, sky, AccentSwatch(name: "RECENT", hex: "#123456")!], picker: picker)
        #expect(out.count == 11 && out[0] == sky && out[1].hex == "#123456" && Set(out.map(\.hex)).count == 11)
    }
}
