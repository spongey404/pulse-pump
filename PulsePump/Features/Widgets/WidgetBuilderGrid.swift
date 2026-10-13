import Foundation

// Placement logic for the widget builder (ported from WidgetBuilderPhone.dc.html):
// occupancy, nearest-free-spot snapping, size fallback, and tidy packing.

struct WidgetBuilderGrid {
    let size: PumpWidgetSize

    struct Spot: Equatable { var x: Int; var y: Int; var w: Int; var h: Int }

    func occupancy(_ pieces: [PumpWidgetPiece], skipping skip: String? = nil) -> [[Bool]] {
        var o = Array(repeating: Array(repeating: false, count: size.cols), count: size.rows)
        for p in pieces where p.id != skip {
            for y in p.y..<min(p.y + p.h, size.rows) {
                for x in p.x..<min(p.x + p.w, size.cols) { o[y][x] = true }
            }
        }
        return o
    }

    func isFree(_ o: [[Bool]], x: Int, y: Int, w: Int, h: Int) -> Bool {
        guard x >= 0, y >= 0, x + w <= size.cols, y + h <= size.rows else { return false }
        for j in y..<(y + h) { for i in x..<(x + w) where o[j][i] { return false } }
        return true
    }

    /// Nearest free origin for a w×h piece; reading order when no target point is given.
    func best(_ o: [[Bool]], w: Int, h: Int, near fx: Double?, _ fy: Double?) -> Spot? {
        var found: Spot?
        var bestD = Double.infinity
        guard w <= size.cols, h <= size.rows else { return nil }
        for y in 0...(size.rows - h) {
            for x in 0...(size.cols - w) where isFree(o, x: x, y: y, w: w, h: h) {
                let d: Double = (fx == nil || fy == nil)
                    ? Double(y * 100 + x)
                    : pow(Double(x) - fx!, 2) + pow(Double(y) - fy!, 2)
                if d < bestD { bestD = d; found = Spot(x: x, y: y, w: w, h: h) }
            }
        }
        return found
    }

    /// Tries the requested size first, then the piece's other sizes.
    func fit(_ pieces: [PumpWidgetPiece], skipping skip: String?, type: PumpPieceType,
             w: Int, h: Int, near fx: Double?, _ fy: Double?) -> Spot? {
        let o = occupancy(pieces, skipping: skip)
        for (sw, sh) in PumpWidgetCatalog.sizes(for: type, in: size, first: (w, h)) {
            if let b = best(o, w: sw, h: sh, near: fx, fy) { return b }
        }
        return nil
    }

    /// Packs pieces to the top-left in reading order; returns what didn't fit.
    func tidy(_ pieces: [PumpWidgetPiece]) -> (out: [PumpWidgetPiece], dropped: Int) {
        var out: [PumpWidgetPiece] = []
        var dropped = 0
        for p in pieces.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
            if size == .lock && p.type.info.noLock { dropped += 1; continue }
            if let s = fit(out, skipping: nil, type: p.type, w: min(p.w, size.cols), h: p.h, near: nil, nil) {
                var q = p; q.x = s.x; q.y = s.y; q.w = s.w; q.h = s.h
                out.append(q)
            } else { dropped += 1 }
        }
        return (out, dropped)
    }
}
