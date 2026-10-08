import SwiftUI

/// Flat 2D muscle heat-map silhouette — the Social tab's "BodyHeat" component.
/// Geometry transcribed 1:1 from `design/design_handoff_social_tab/BodyHeat.dc.html`'s SVG
/// (`viewBox 0 0 200 320`). Not the app's 3D `Body3DSceneView` — this is a cheap,
/// spec-accurate silhouette meant for scroll lists, sheets and share cards.
///
/// Always give this an explicit width/height matching the 0.625 aspect ratio
/// (e.g. 69×110, 75×120, 150×240) — `width: auto` has no intrinsic size.
struct BodyHeat: View {
    struct Intensities {
        var traps: Double?
        var chest: Double?
        var shoulders: Double?
        var biceps: Double?
        var forearms: Double?
        var core: Double?
        var glutes: Double?
        var quads: Double?
        var calves: Double?

        init(
            traps: Double? = nil, chest: Double? = nil, shoulders: Double? = nil,
            biceps: Double? = nil, forearms: Double? = nil, core: Double? = nil,
            glutes: Double? = nil, quads: Double? = nil, calves: Double? = nil
        ) {
            self.traps = traps; self.chest = chest; self.shoulders = shoulders
            self.biceps = biceps; self.forearms = forearms; self.core = core
            self.glutes = glutes; self.quads = quads; self.calves = calves
        }
    }

    let intensities: Intensities
    /// Default matches the light-surface spec value `rgba(31,28,25,0.035)`.
    var base: Color = Color(hex: "#151A21").opacity(0.035)
    /// Default matches the light-surface spec value `rgba(31,28,25,0.07)`.
    var stroke: Color = Color(hex: "#151A21").opacity(0.07)

    /// Dark-surface preset per spec: `base="rgba(236,229,214,0.10)" stroke="rgba(236,229,214,0.12)"`.
    static func darkSurface(_ intensities: Intensities) -> BodyHeat {
        BodyHeat(
            intensities: intensities,
            base: Color(hex: "#ECE5D6").opacity(0.10),
            stroke: Color(hex: "#ECE5D6").opacity(0.12)
        )
    }

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 200
            let sy = size.height / 320
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            func fill(_ region: Double?) -> Color { region.map(thermal) ?? base }
            let strokeStyle = StrokeStyle(lineWidth: max(0.5, 1 * min(sx, sy)))

            func draw(_ path: Path, _ region: Double?) {
                ctx.fill(path, with: .color(fill(region)))
                ctx.stroke(path, with: .color(stroke), style: strokeStyle)
            }

            // Head + neck (always base fill — not a trainable region)
            draw(Path(ellipseIn: CGRect(x: pt(86, 8).x, y: pt(86, 8).y, width: 28 * sx, height: 28 * sy)), nil)
            draw(Path(CGRect(x: pt(94, 34).x, y: pt(94, 34).y, width: 12 * sx, height: 10 * sy)), nil)

            // Traps — M75 46 L100 42 L125 46 L120 56 L100 52 L80 56 Z
            var traps = Path()
            traps.move(to: pt(75, 46)); traps.addLine(to: pt(100, 42)); traps.addLine(to: pt(125, 46))
            traps.addLine(to: pt(120, 56)); traps.addLine(to: pt(100, 52)); traps.addLine(to: pt(80, 56))
            traps.closeSubpath()
            draw(traps, intensities.traps)

            // Chest — M70 56 Q100 48 130 56 L132 96 Q100 102 68 96 Z
            var chest = Path()
            chest.move(to: pt(70, 56)); chest.addQuadCurve(to: pt(130, 56), control: pt(100, 48))
            chest.addLine(to: pt(132, 96)); chest.addQuadCurve(to: pt(68, 96), control: pt(100, 102))
            chest.closeSubpath()
            draw(chest, intensities.chest)

            // Shoulders — L: M55 60 Q48 70 50 90 L66 92 Q70 76 70 56 Z / R mirrored
            var shoulderL = Path()
            shoulderL.move(to: pt(55, 60)); shoulderL.addQuadCurve(to: pt(50, 90), control: pt(48, 70))
            shoulderL.addLine(to: pt(66, 92)); shoulderL.addQuadCurve(to: pt(70, 56), control: pt(70, 76))
            shoulderL.closeSubpath()
            var shoulderR = Path()
            shoulderR.move(to: pt(145, 60)); shoulderR.addQuadCurve(to: pt(150, 90), control: pt(152, 70))
            shoulderR.addLine(to: pt(134, 92)); shoulderR.addQuadCurve(to: pt(130, 56), control: pt(130, 76))
            shoulderR.closeSubpath()
            draw(shoulderL, intensities.shoulders); draw(shoulderR, intensities.shoulders)

            // Biceps — L: M40 90 Q34 110 36 130 L52 130 Q54 110 50 90 Z / R mirrored
            var bicepsL = Path()
            bicepsL.move(to: pt(40, 90)); bicepsL.addQuadCurve(to: pt(36, 130), control: pt(34, 110))
            bicepsL.addLine(to: pt(52, 130)); bicepsL.addQuadCurve(to: pt(50, 90), control: pt(54, 110))
            bicepsL.closeSubpath()
            var bicepsR = Path()
            bicepsR.move(to: pt(160, 90)); bicepsR.addQuadCurve(to: pt(164, 130), control: pt(166, 110))
            bicepsR.addLine(to: pt(148, 130)); bicepsR.addQuadCurve(to: pt(150, 90), control: pt(146, 110))
            bicepsR.closeSubpath()
            draw(bicepsL, intensities.biceps); draw(bicepsR, intensities.biceps)

            // Forearms — L: M30 130 Q26 154 30 172 L48 172 Q50 154 48 130 Z / R mirrored
            var forearmL = Path()
            forearmL.move(to: pt(30, 130)); forearmL.addQuadCurve(to: pt(30, 172), control: pt(26, 154))
            forearmL.addLine(to: pt(48, 172)); forearmL.addQuadCurve(to: pt(48, 130), control: pt(50, 154))
            forearmL.closeSubpath()
            var forearmR = Path()
            forearmR.move(to: pt(170, 130)); forearmR.addQuadCurve(to: pt(170, 172), control: pt(174, 154))
            forearmR.addLine(to: pt(152, 172)); forearmR.addQuadCurve(to: pt(152, 130), control: pt(150, 154))
            forearmR.closeSubpath()
            draw(forearmL, intensities.forearms); draw(forearmR, intensities.forearms)

            // Core — M75 96 Q100 100 125 96 L122 138 Q100 142 78 138 Z
            var core = Path()
            core.move(to: pt(75, 96)); core.addQuadCurve(to: pt(125, 96), control: pt(100, 100))
            core.addLine(to: pt(122, 138)); core.addQuadCurve(to: pt(78, 138), control: pt(100, 142))
            core.closeSubpath()
            draw(core, intensities.core)

            // Glutes — M76 138 L124 138 L128 158 L72 158 Z
            var glutes = Path()
            glutes.move(to: pt(76, 138)); glutes.addLine(to: pt(124, 138))
            glutes.addLine(to: pt(128, 158)); glutes.addLine(to: pt(72, 158))
            glutes.closeSubpath()
            draw(glutes, intensities.glutes)

            // Quads — L: M76 158 Q72 200 76 230 L98 230 Q100 200 98 158 Z / R mirrored
            var quadL = Path()
            quadL.move(to: pt(76, 158)); quadL.addQuadCurve(to: pt(76, 230), control: pt(72, 200))
            quadL.addLine(to: pt(98, 230)); quadL.addQuadCurve(to: pt(98, 158), control: pt(100, 200))
            quadL.closeSubpath()
            var quadR = Path()
            quadR.move(to: pt(124, 158)); quadR.addQuadCurve(to: pt(124, 230), control: pt(128, 200))
            quadR.addLine(to: pt(102, 230)); quadR.addQuadCurve(to: pt(102, 158), control: pt(100, 200))
            quadR.closeSubpath()
            draw(quadL, intensities.quads); draw(quadR, intensities.quads)

            // Knee marks (stroke only, no fill)
            var kneeL = Path(); kneeL.move(to: pt(78, 232)); kneeL.addLine(to: pt(98, 232))
            var kneeR = Path(); kneeR.move(to: pt(102, 232)); kneeR.addLine(to: pt(124, 232))
            ctx.stroke(kneeL, with: .color(stroke), style: strokeStyle)
            ctx.stroke(kneeR, with: .color(stroke), style: strokeStyle)

            // Calves — L: M80 234 Q76 260 80 286 L96 286 Q98 260 96 234 Z / R mirrored
            var calfL = Path()
            calfL.move(to: pt(80, 234)); calfL.addQuadCurve(to: pt(80, 286), control: pt(76, 260))
            calfL.addLine(to: pt(96, 286)); calfL.addQuadCurve(to: pt(96, 234), control: pt(98, 260))
            calfL.closeSubpath()
            var calfR = Path()
            calfR.move(to: pt(120, 234)); calfR.addQuadCurve(to: pt(120, 286), control: pt(124, 260))
            calfR.addLine(to: pt(104, 286)); calfR.addQuadCurve(to: pt(104, 234), control: pt(102, 260))
            calfR.closeSubpath()
            draw(calfL, intensities.calves); draw(calfR, intensities.calves)

            // Feet (always base fill)
            draw(Path(ellipseIn: CGRect(x: pt(77, 289).x, y: pt(77, 289).y, width: 22 * sx, height: 10 * sy)), nil)
            draw(Path(ellipseIn: CGRect(x: pt(101, 289).x, y: pt(101, 289).y, width: 22 * sx, height: 10 * sy)), nil)
        }
    }

    /// Thermal ramp — 5-stop linear interpolation on the Pump blue accent, exact stops from spec:
    /// 0 → rgb(236,229,214) · 0.2 → rgb(184,217,242) · 0.45 → rgb(107,176,232) ·
    /// 0.7 → rgb(26,131,214) · 1 → rgb(10,111,192).
    private func thermal(_ t: Double) -> Color {
        let t = max(0, min(1, t))
        let stops: [(Double, (Double, Double, Double))] = [
            (0.00, (236, 229, 214)),
            (0.20, (184, 217, 242)),
            (0.45, (107, 176, 232)),
            (0.70, (26, 131, 214)),
            (1.00, (26, 167, 255)),
        ]
        for i in 0..<(stops.count - 1) {
            let (a, ca) = stops[i]
            let (b, cb) = stops[i + 1]
            if t <= b {
                let k = (t - a) / (b - a)
                return Color(
                    red: (ca.0 + (cb.0 - ca.0) * k) / 255,
                    green: (ca.1 + (cb.1 - ca.1) * k) / 255,
                    blue: (ca.2 + (cb.2 - ca.2) * k) / 255
                )
            }
        }
        return Color(red: 26 / 255, green: 167 / 255, blue: 255 / 255)
    }
}

#Preview("BodyHeat — Push Day reference") {
    HStack(spacing: 24) {
        BodyHeat(intensities: .init(traps: 0.3, chest: 0.95, shoulders: 0.78, biceps: 0.8, core: 0.18))
            .frame(width: 69, height: 110)
        BodyHeat.darkSurface(.init(traps: 0.3, chest: 0.95, shoulders: 0.78, biceps: 0.8, core: 0.18))
            .frame(width: 75, height: 120)
            .background(Color.black)
    }
    .padding()
}
