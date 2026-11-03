import SwiftUI

/// What an exported share card shows (Ore Feed Post Final §4). No user name and no promo line: only the Ore mark. Every card gets
/// Stardust; members also get SUPERNOVA*, their accent and the Ticker style.
struct ShareCardModel: Equatable {
    enum Style: String, CaseIterable { case ticker = "TICKER", classic = "CLASSIC" }

    var title: String
    var date: Date
    var prCount: Int
    var sets: Int
    var volumeKg: Double
    var durationSeconds: Int
    var improved: Int
    var totalExercises: Int
    var levels: [String: Double]
    var member: Bool
    /// The member's accent; Ore's blue for free users.
    var accentHex: String
    var style: Style

    /// The loop is 6 s, seamless: every animated thing completes a whole number of cycles in it.
    static let loopSeconds = 6.0
    static let frameRate = 30
    static let frameCount = Int(loopSeconds) * frameRate
    /// 9:16, designed at 540 × 960 pt and rendered at 2× to 1080 × 1920.
    static let size = CGSize(width: 540, height: 960)

    /// Free users only have the Classic card; the Ticker style is a member option.
    static func styles(member: Bool) -> [Style] { member ? [.ticker, .classic] : [.classic] }

    var sides: [BodyMapSide] { BodyMapLevels.trainedSides(levels) }

    var tickerItems: [String] {
        var items = ["DONE"]
        if prCount > 0 { items.append("★ \(prCount) NEW PR\(prCount == 1 ? "" : "S")") }
        if totalExercises > 0 { items.append("IMPROVED \(improved)/\(totalExercises)") }
        items.append("SETS \(sets)")
        return items
    }

    var dateLine: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: date).uppercased()
    }
}

/// Deterministic twinkle: position and phase from a seed, `cycles` whole cycles per loop, so frame 0 == frame 180.
enum ShareTwinkle {
    struct Star { var x: Double, y: Double, size: Double, phase: Double, cycles: Int, gold: Bool }

    static func stars(count: Int, seed: UInt64) -> [Star] {
        var g = StarBurstEngine.SplitMix(seed: seed)
        return (0..<count).map { _ in
            Star(x: Double.random(in: 0...1, using: &g), y: Double.random(in: 0...1, using: &g), size: Double.random(in: 1.2...3.4, using: &g),
                 phase: Double.random(in: 0...1, using: &g), cycles: Int.random(in: 1...3, using: &g), gold: Double.random(in: 0...1, using: &g) < 0.3)
        }
    }

    /// 0.15…1 across a loop, back where it began at t == loop.
    static func level(_ s: Star, t: Double, loop: Double = ShareCardModel.loopSeconds) -> Double {
        0.15 + 0.85 * (0.5 + 0.5 * sin(2 * .pi * (Double(s.cycles) * t / loop + s.phase)))
    }

    /// The ticker slides exactly one tile in a loop, so it ends where it started.
    static func tickerOffset(t: Double, tile: Double, loop: Double = ShareCardModel.loopSeconds) -> Double { -(t / loop).truncatingRemainder(dividingBy: 1) * tile }
}
