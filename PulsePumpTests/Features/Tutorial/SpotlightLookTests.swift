import Testing
import SwiftUI
import UIKit
@testable import PulsePump

/// Guards how the tutorial's spotlight looks: it must fade out smoothly (no hard edge between the lit control
/// and the dim) and it must take the control's shape (a circle for the round + button).
@MainActor
struct SpotlightLookTests {
    private let size = CGSize(width: 240, height: 240)

    /// Dim opacity (0 = clear, 1 = full dim) at each pixel of the row/column through the hole's centre.
    private func dimAlpha(hole: CGRect, along: (Int) -> CGPoint, count: Int) -> [Double] {
        let view = SpotlightLayer(hole: hole, keyboard: .zero, dim: .black, glow: .clear)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.uiImage, let cg = image.cgImage,
              let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return [] }
        let bpp = cg.bitsPerPixel / 8
        return (0..<count).map { i in
            let p = along(i)
            let offset = Int(p.y) * cg.bytesPerRow + Int(p.x) * bpp
            // Premultiplied RGBA or BGRA over black: the alpha byte is the dim.
            return Double(bytes[offset + 3]) / 255
        }
    }

    @Test func theDimFadesOutSmoothlyFromTheControl() {
        let hole = CGRect(x: 90, y: 100, width: 60, height: 40)   // centre (120, 120)
        // Walk left from the control's left edge (x = 90) to the far side.
        let row = dimAlpha(hole: hole, along: { CGPoint(x: 90 - $0, y: 120) }, count: 80)
        #expect(row.count == 80)
        guard row.count == 80 else { return }
        #expect(row[0] < 0.03, "the control itself is clear")
        #expect(row[79] > 0.95, "far from the control it is fully dim")
        for i in 1..<row.count {
            #expect(row[i] + 0.002 >= row[i - 1], "the dim only ever gets darker moving away (x−\(i))")
            #expect(row[i] - row[i - 1] < 0.13, "no hard edge: the dim jumps \(row[i] - row[i - 1]) in one point at x−\(i)")
        }
    }

    @Test func theFadeIsNotWiderThanAFewPoints() {
        let hole = CGRect(x: 90, y: 100, width: 60, height: 40)
        let row = dimAlpha(hole: hole, along: { CGPoint(x: 90 - $0, y: 120) }, count: 80)
        guard row.count == 80 else { return }
        let fullyDim = row.firstIndex { $0 > 0.97 } ?? 80
        #expect(fullyDim <= 28, "the soft edge stays tight around the control (reached full dim after \(fullyDim)pt)")
    }

    @Test func theSquareButtonIsLitAsARoundedSquareNotACircle() {
        let button = CGRect(x: 100, y: 100, width: 40, height: 40)
        #expect(SpotlightLayer.cornerRadius(for: button, grow: 0) == 10, "a squircle, like every other button")
        // The corner of its box is nearly lit (a circle would leave it dim), its edge middle is lit.
        let corner = dimAlpha(hole: button, along: { _ in CGPoint(x: 102, y: 102) }, count: 1)
        let edge = dimAlpha(hole: button, along: { _ in CGPoint(x: 120, y: 101) }, count: 1)
        #expect(corner.first.map { $0 < 0.15 } == true, "the corners are square-ish, not cut off like a circle")
        #expect(edge.first.map { $0 < 0.1 } == true)
    }

    @Test func aWideButtonKeepsAnOrdinaryRoundedRectangle() {
        let wide = CGRect(x: 10, y: 10, width: 80, height: 28)
        #expect(SpotlightLayer.cornerRadius(for: wide, grow: 0) == 10)
        let big = CGRect(x: 10, y: 10, width: 350, height: 54)
        #expect(SpotlightLayer.cornerRadius(for: big, grow: 0) == 10)
    }
}
