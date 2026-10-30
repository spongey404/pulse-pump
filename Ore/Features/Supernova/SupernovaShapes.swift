import SwiftUI

/// The four-point star used as the paywall's bullet. The design's own SVG path (24 × 24 box), scaled to fit.
struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24, sy = rect.height / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(12, 0))
        path.addCurve(to: p(24, 12), control1: p(13, 8), control2: p(16, 11))
        path.addCurve(to: p(12, 24), control1: p(16, 13), control2: p(13, 16))
        path.addCurve(to: p(0, 12), control1: p(11, 16), control2: p(8, 13))
        path.addCurve(to: p(12, 0), control1: p(8, 11), control2: p(11, 8))
        path.closeSubpath()
        return path
    }
}
