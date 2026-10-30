import Testing
import Foundation
@testable import Ore

@MainActor
struct SignupStarEngineTests {
    private let size = CGSize(width: 390, height: 844)
    private let stars = SignupConfig.fallback.stars

    @Test func startsEmptyAndFillsToTheFullCount() {
        var e = SignupStarEngine(config: stars, size: size, seed: 3)
        #expect(e.count == 420)
        e.step(t: 100, dt: 16, level: 0, boost: 0)
        #expect(e.dots.isEmpty)
        var last = 0
        for level in stride(from: 0.0, through: 1.0, by: 0.125) {
            #expect(e.shown(level: level) >= last, "never fewer stars as the level rises")
            last = e.shown(level: level)
        }
        #expect(e.shown(level: 1) == 420)
        #expect(e.shown(level: 0.5) == Int((420 * 0.5 * (0.25 + 0.75 * 0.5)).rounded()))
        e.step(t: 200, dt: 16, level: 1, boost: 0)
        #expect(e.dots.count == 420)
    }

    @Test func countScalesWithTheScreenArea() {
        #expect(SignupStarEngine.particleCount(config: stars, size: CGSize(width: 390, height: 844)) == 420)
        #expect(SignupStarEngine.particleCount(config: stars, size: CGSize(width: 195, height: 422)) == 105)
    }

    @Test func aSurgeDrawsStreaksInsteadOfDotsAndStarsRise() {
        var e = SignupStarEngine(config: stars, size: size, seed: 3)
        e.step(t: 100, dt: 16, level: 1, boost: 0)
        let before = e.dots.map(\.y)
        e.step(t: 116, dt: 16, level: 1, boost: 1)
        #expect(e.dots.isEmpty && e.streaks.count == 420)
        #expect(e.streaks.allSatisfy { $0.y2 > $0.y })
        e.step(t: 132, dt: 16, level: 1, boost: 0.05)   // below the streak threshold: dots again
        #expect(e.streaks.isEmpty && e.dots.count == 420)
        #expect(before.count == 420)
    }

    @Test func theSameSeedGivesTheSameField() {
        var a = SignupStarEngine(config: stars, size: size, seed: 9)
        var b = SignupStarEngine(config: stars, size: size, seed: 9)
        a.step(t: 500, dt: 16, level: 1, boost: 0); b.step(t: 500, dt: 16, level: 1, boost: 0)
        #expect(a.dots.map(\.x) == b.dots.map(\.x))
        #expect(a.dots.map(\.alpha) == b.dots.map(\.alpha))
    }

    @Test func starsWrapAndStayOnScreenOverTime() {
        var e = SignupStarEngine(config: stars, size: size, seed: 5)
        for i in 1...200 { e.step(t: Double(i) * 16, dt: 16, level: 1, boost: 0.5) }
        e.step(t: 4000, dt: 16, level: 1, boost: 0)
        #expect(e.dots.allSatisfy { $0.alpha >= 0 && $0.alpha <= 1 && $0.y > -20 && $0.y < 870 })
    }

    @Test func levelIsAnsweredOverTotal() {
        #expect(SignupStarEngine.level(answered: 0, total: 10) == 0)
        #expect(SignupStarEngine.level(answered: 5, total: 10) == 0.5)
        #expect(SignupStarEngine.level(answered: 10, total: 10) == 1)
        #expect(SignupStarEngine.level(answered: 0, total: 0) == 0)
    }

    @Test func barGlitterDriftsRightAndWraps() {
        var g = SignupBarGlitter(config: SignupConfig.fallback.bar, width: 334)
        g.step(t: 100, dt: 16, boost: 0)
        #expect(g.specks.count == 90)
        let x0 = g.specks.map(\.x)
        g.step(t: 116, dt: 16, boost: 0)
        #expect(zip(x0, g.specks.map(\.x)).allSatisfy { $1 > $0 || $1 < 0 })
        for i in 0..<2000 { g.step(t: Double(i) * 16, dt: 16, boost: 1) }
        #expect(g.specks.allSatisfy { $0.x >= -2 && $0.x <= 336 && $0.alpha <= 1 })
    }

    @Test func bulletDanceSwellsAndTwistsAndStandsStillWithReduceMotion() {
        let b = SignupConfig.fallback.bullet
        let rest = StarBullet.motion(at: 0, delay: 0, config: b, still: false)
        #expect(rest.scale == b.scaleMin && rest.rotation == 0 && rest.opacity == b.opacityMin)
        let peak = StarBullet.motion(at: b.seconds / 2, delay: 0, config: b, still: false)
        #expect(abs(peak.scale - b.scaleMax) < 1e-9 && abs(peak.rotation - b.rotateMax) < 1e-9 && abs(peak.opacity - 1) < 1e-9)
        let shifted = StarBullet.motion(at: 0, delay: -b.seconds / 2, config: b, still: false)
        #expect(shifted == peak, "a negative delay starts the loop part-way")
        #expect(StarBullet.motion(at: 1.234, delay: 0, config: b, still: true) == .init(scale: 1, rotation: 0, opacity: 1))
    }
}
