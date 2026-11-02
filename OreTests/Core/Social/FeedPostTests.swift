import Testing
import Foundation
import CoreGraphics
@testable import Ore

@MainActor
struct FeedPostTests {
    @Test func bundledSocialConfigEqualsFallback() throws {
        let url = try #require(Bundle.main.url(forResource: "social.config", withExtension: "json"))
        let c = try JSONDecoder().decode(SocialConfig.self, from: Data(contentsOf: url))
        #expect(c == SocialConfig.fallback)
        #expect(c.isUsable)
    }

    @Test func badRemoteConfigIsIgnored() {
        var bad = SocialConfig.fallback; bad.meter.bars = 0
        #expect(!bad.isUsable)
    }

    @Test func everyPatternIsStarsThatEndInvisible() {
        for i in 0..<StarBurstEngine.patternCount {
            let stars = StarBurstEngine.pattern(i, seed: 3)
            #expect(!stars.isEmpty, "pattern \(i)")
            let end = StarBurstEngine.length(of: stars)
            #expect(stars.allSatisfy { $0.state(at: $0.delay + $0.duration - 0.0001).map { $0.opacity < 0.01 } ?? true }, "pattern \(i) ends at 0")
            #expect(stars.allSatisfy { $0.state(at: end + 0.01) == nil })
        }
    }

    @Test func patternsCycleAndNamesMatch() {
        #expect(StarBurstEngine.patternNames.count == StarBurstEngine.patternCount)
        let c = BurstController(startPattern: 6)
        for _ in 0..<3 { c.doubleTap(at: .zero, dark: true) }
        // 6 (Supernova), 7 (collision), then 0 (Burst): the third has the four rings of 18+14+16+10 stars.
        #expect(c.bursts.count == 3)
        #expect(c.bursts[2].stars.count == 58)
    }

    @Test func burstRingSizesFollowTheDesign() {
        #expect(StarBurstEngine.pattern(0, seed: 1).count == 18 + 14 + 16 + 10)
        let light = StarBurstEngine.pattern(0, density: 1.25, seed: 1)
        #expect(light.count > 58)
        let shock = StarBurstEngine.pattern(3, seed: 1)
        #expect(Set(shock.map(\.delay)).count == 3)
        #expect(Set(shock.map(\.r1)) == [110, 170, 210])
    }

    @Test func heartKeyframes() {
        let s = DoubleTapHeartMotion.state
        #expect(s(0, 104).scale == 0)
        #expect(abs(s(0.14, 104).scale - 1.12) < 1e-9)
        #expect(abs(s(0.26, 104).scale - 0.96) < 1e-9)
        #expect(abs(s(0.38, 104).scale - 1) < 1e-9)
        #expect(s(0.6, 104).opacity == 1)
        #expect(s(0.99, 104).opacity < 0.1)
        #expect(s(0.99, 104).lift > 25)
    }

    @Test func meterIsFlatWhenSettledAndBouncesWhilePlaying() {
        let c = SocialConfig.fallback.meter
        #expect(SongLevelMeter.settled(from: 0.9, elapsedMs: 0, cfg: c) == 0.9)               // the 20 ms hold
        #expect(abs(SongLevelMeter.settled(from: 0.9, elapsedMs: 20 + 550, cfg: c) - c.idleAlpha) < 1e-9)
        let a = SongLevelMeter.level(bar: 0, at: 0.3, cfg: c), b = SongLevelMeter.level(bar: 3, at: 0.3, cfg: c)
        #expect(a != b)                                                                         // out of phase
        for t in stride(from: 0.0, to: 2, by: 0.05) { for i in 0..<5 { let v = SongLevelMeter.level(bar: i, at: t, cfg: c); #expect(v >= 0.2 && v <= 1) } }
    }

    @Test func songPausesKeepPositionAndAnotherSongPausesThisOne() {
        let p = PostSongPlayer(); p.silent = true
        let song = PostSong(title: "T", artist: "A")
        p.play(postId: "a", song: song)
        p.pause("a")
        #expect(!p.isPlaying("a"))
        p.play(postId: "b", song: song)
        p.play(postId: "a", song: song)
        #expect(p.isPlaying("a") && !p.isPlaying("b"))
        var s = SongPlaybackState(position: 12, playing: true)
        #expect(s.label == "0:12 / 0:30")
        s.tick(by: 20, length: 30)
        #expect(s.position == 0 && !s.playing && s.label == "PREVIEW 0:30")
    }

    @Test func bodyMapShowsOnlyTrainedSides() {
        let chestOnly = BodyMapLevels.levels(muscleSets: ["Chest": 8])
        #expect(BodyMapLevels.trainedSides(chestOnly) == [.front])
        let legsAndBack = BodyMapLevels.levels(muscleSets: ["Lats": 6, "Quads": 4])
        #expect(BodyMapLevels.trainedSides(legsAndBack) == [.front, .back])
        #expect(BodyMapLevels.trainedSides([:]).isEmpty)
    }

    @Test func titleCaseAndTimes() {
        #expect("BACK SQUAT".exerciseTitleCase == "Back Squat")
        #expect("romanian deadlift".exerciseTitleCase == "Romanian Deadlift")
        #expect("EZ bar curl".exerciseTitleCase == "EZ Bar Curl")
        #expect(PostTime.duration(4325) == "1:12:05")
        #expect(PostTime.duration(2710) == "45:10")
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(PostTime.ago(now.addingTimeInterval(-86_400), now: now, calendar: cal) == "YESTERDAY")
    }
}
