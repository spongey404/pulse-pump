import SwiftUI

/// The glowing, dancing gold four-point star used as a bullet: the sign-up log and setup lines, the choice cards and the
/// Supernova paywall's feature list. The dance (swell, brighten, twist, 2.6 s loop) and the glow are in
/// `SignupConfig.bullet`. `delay` is the design's negative animation delay in seconds, so a column of bullets never
/// pulses together. With Reduce Motion the star is still and keeps its glow.
struct StarBullet: View {
    var size: CGFloat = 12
    /// Phase offset in seconds (the design writes it as a negative animation-delay).
    var delay: Double = 0
    var config: SignupConfig.Bullet = SignupConfigStore.shared.current.bullet

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
            let m = Self.motion(at: timeline.date.timeIntervalSinceReferenceDate, delay: delay, config: config, still: reduceMotion)
            star
                .scaleEffect(m.scale)
                .rotationEffect(.degrees(m.rotation))
                .opacity(m.opacity)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var star: some View {
        ZStack {
            // The halo: a blurred copy behind the star (the app has no drop shadows).
            FourPointStar().fill(Self.gold).blur(radius: config.glowRadius / 2).opacity(config.glowAlpha)   // CSS drop-shadow blur 3 px is a Gaussian of σ 1.5
            FourPointStar().fill(Self.gold)
            Circle().fill(Self.core).frame(width: size * 4.4 / 24, height: size * 4.4 / 24)
        }
        .frame(width: size, height: size)
    }

    static let gold = Color(red: 1, green: 200 / 255, blue: 61 / 255)
    static let core = Color(red: 1, green: 242 / 255, blue: 200 / 255)

    struct Motion: Equatable { var scale: Double, rotation: Double, opacity: Double }

    /// 0 % and 100 %: small, upright, dim; 50 %: swollen, twisted 8°, bright. Each half eases in and out.
    static func motion(at time: Double, delay: Double, config c: SignupConfig.Bullet, still: Bool) -> Motion {
        if still { return Motion(scale: 1, rotation: 0, opacity: 1) }
        let phase = ((time - delay) / c.seconds).truncatingRemainder(dividingBy: 1)
        let f = phase < 0 ? phase + 1 : phase
        let tri = 1 - abs(2 * f - 1)
        let e = tri * tri * (3 - 2 * tri)
        return Motion(scale: c.scaleMin + (c.scaleMax - c.scaleMin) * e, rotation: c.rotateMax * e, opacity: c.opacityMin + (1 - c.opacityMin) * e)
    }
}
