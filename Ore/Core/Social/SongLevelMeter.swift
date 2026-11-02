import SwiftUI

/// The five-bar level meter. Idle: a flat grey line (all bars at `idleAlpha` height… 15 %). Playing: the poster's accent, each bar
/// bounces on its own loop (0.55–0.9 s, out of phase). Pause: hold 20 ms, bars ease from where they froze to flat over 550 ms
/// (ease-out) while the colour fades to grey over 450 ms. Play again: bars snap back to the heights they froze at.
struct SongLevelMeter: View {
    var playing: Bool
    var accent: Color
    @State private var frozen: [Double] = []
    @State private var pausedAt: Date?
    @State private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cfg: SocialConfig.Meter { SocialConfigStore.shared.current.meter }

    /// Bar `i` height fraction (0–1) at time `t`: a triangle between 0.2 and 1 on its own period and phase.
    static func level(bar i: Int, at t: Double, cfg c: SocialConfig.Meter) -> Double {
        let span = max(c.loopMaxS - c.loopMinS, 0)
        let period = c.loopMinS + (c.bars > 1 ? span * Double(i) / Double(c.bars - 1) : 0)
        let phase = (t / period + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
        let tri = 1 - abs(2 * phase - 1)
        return 0.2 + 0.8 * tri
    }

    /// Frozen heights settle to the flat line: ease-out over `settleMs` after a `holdMs` hold.
    static func settled(from h: Double, elapsedMs: Double, cfg c: SocialConfig.Meter) -> Double {
        let t = min(max((elapsedMs - c.holdMs) / c.settleMs, 0), 1)
        let e = 1 - pow(1 - t, 3)
        return h + (flatFraction(c) - h) * e
    }
    static func flatFraction(_ c: SocialConfig.Meter) -> Double { c.idleAlpha }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing && (pausedAt == nil || Date().timeIntervalSince(pausedAt!) > 1))) { tl in
            let now = tl.date
            HStack(alignment: .bottom, spacing: cfg.gap) {
                ForEach(0..<cfg.bars, id: \.self) { i in
                    let h = height(i, now: now)
                    RoundedRectangle(cornerRadius: cfg.barRadius)
                        .fill(color(now: now))
                        .frame(width: cfg.barWidth, height: max(1, cfg.barHeight * h))
                }
            }
            .frame(height: cfg.barHeight, alignment: .bottom)
        }
        .onChange(of: playing) { _, isPlaying in
            if isPlaying {
                pausedAt = nil
                startedAt = Date().addingTimeInterval(-resumeOffset)
            } else {
                let now = Date()
                frozen = (0..<cfg.bars).map { Self.level(bar: $0, at: now.timeIntervalSince(startedAt), cfg: cfg) }
                resumeOffset = now.timeIntervalSince(startedAt)
                pausedAt = now
            }
        }
        .accessibilityHidden(true)
    }
    @State private var resumeOffset: Double = 0

    private func height(_ i: Int, now: Date) -> Double {
        if reduceMotion { return playing ? 0.6 : Self.flatFraction(cfg) }
        if playing { return Self.level(bar: i, at: now.timeIntervalSince(startedAt), cfg: cfg) }
        guard let p = pausedAt, i < frozen.count else { return Self.flatFraction(cfg) }
        return Self.settled(from: frozen[i], elapsedMs: now.timeIntervalSince(p) * 1000, cfg: cfg)
    }

    private func color(now: Date) -> Color {
        if playing { return accent }
        guard let p = pausedAt else { return Color.inkMuted.opacity(0.5) }
        let t = min(max(now.timeIntervalSince(p) * 1000 / cfg.colorFadeMs, 0), 1)
        return accent.mix(with: Color.inkMuted.opacity(0.5), by: t)
    }
}
