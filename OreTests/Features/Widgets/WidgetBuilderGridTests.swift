import Foundation
import Testing
@testable import Ore

struct WidgetBuilderGridTests {
    private func piece(_ id: String, _ type: OrePieceType, x: Int, y: Int, w: Int, h: Int) -> OreWidgetPiece {
        OreWidgetPiece(id: id, type: type, metric: type.info.metrics[0].id, x: x, y: y, w: w, h: h)
    }

    @Test func emptyGridPlacesTopLeft() {
        let g = WidgetBuilderGrid(size: .small)
        let s = g.fit([], skipping: nil, type: .num, w: 2, h: 2, near: nil, nil)
        #expect(s == .init(x: 0, y: 0, w: 2, h: 2))
    }

    @Test func snapsToNearestFreeSpot() {
        let g = WidgetBuilderGrid(size: .medium)
        let existing = [piece("a", .num, x: 0, y: 0, w: 2, h: 2)]
        let s = g.fit(existing, skipping: nil, type: .num, w: 2, h: 2, near: 0.2, 0.1)
        #expect(s?.x == 2 && s?.y == 0)
    }

    @Test func fallsBackToAnotherSizeWhenRequestedWontFit() {
        let g = WidgetBuilderGrid(size: .small)
        // Only a 2×2 pocket is left, so the requested 4-wide size falls back to the piece's 2×2.
        let existing = [piece("a", .bars, x: 0, y: 0, w: 4, h: 2), piece("b", .num, x: 0, y: 2, w: 2, h: 1)]
        let s = g.fit(existing, skipping: nil, type: .num, w: 4, h: 2, near: nil, nil)
        #expect(s == .init(x: 2, y: 2, w: 2, h: 2))
    }

    @Test func fullGridHasNoSpot() {
        let g = WidgetBuilderGrid(size: .lock)
        let full = [piece("a", .prog, x: 0, y: 0, w: 4, h: 1), piece("b", .prog, x: 0, y: 1, w: 4, h: 1)]
        #expect(g.fit(full, skipping: nil, type: .quick, w: 2, h: 1, near: nil, nil) == nil)
    }

    @Test func skippingIgnoresThePieceBeingMoved() {
        let g = WidgetBuilderGrid(size: .small)
        let existing = [piece("a", .num, x: 0, y: 0, w: 2, h: 2)]
        let s = g.fit(existing, skipping: "a", type: .num, w: 2, h: 2, near: 0, 0)
        #expect(s?.x == 0 && s?.y == 0)
    }

    @Test func tidyPacksInReadingOrder() {
        let g = WidgetBuilderGrid(size: .medium)
        let scattered = [piece("b", .num, x: 6, y: 2, w: 2, h: 2), piece("a", .num, x: 4, y: 0, w: 2, h: 2)]
        let r = g.tidy(scattered)
        #expect(r.dropped == 0)
        #expect(r.out.map(\.id) == ["a", "b"])
        #expect(r.out[0].x == 0 && r.out[1].x == 2)
    }

    @Test func tidyDropsBodyMapOnLockScreen() {
        let g = WidgetBuilderGrid(size: .lock)
        let r = g.tidy([piece("m", .body, x: 0, y: 0, w: 2, h: 3)])
        #expect(r.dropped == 1 && r.out.isEmpty)
    }

    @Test func presetsFitTheirOwnSize() {
        for w in OreWidgetCatalog.presets() {
            let g = WidgetBuilderGrid(size: w.size)
            let r = g.tidy(w.pieces)
            #expect(r.dropped == 0, "\(w.name) should fit its size")
        }
    }

    @Test func prLookupFindsVariantNames() {
        var s = OreWidgetSnapshot()
        s.hasData = true
        s.prs = ["Barbell Bench Press": .init(weight: 100, date: Date()),
                 "Incline Barbell Bench Press": .init(weight: 120, date: Date())]
        #expect(s.bestPR(for: "Bench Press")?.weight == 100)
    }
}
