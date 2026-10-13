import SwiftUI

// MARK: - Theme (asset-catalog names exist in both the app and the widget extension)

enum PumpTheme {
    static let canvas = Color("CanvasBg")
    static let ink = Color("InkPrimary")
    static var muted: Color { ink.opacity(0.50) }
    static var faint: Color { ink.opacity(0.13) }
    static var rule: Color { ink.opacity(0.14) }
    static var hair: Color { ink.opacity(0.08) }
    static let accent = Color("PumpAccent")
    static let accentInk = Color("AccentInk")
    static let accentSoft = Color("AccentSoft")
    static let sunken = Color("Surf2")
    static let up = Color("SignalUp")
    static let down = Color("SignalDown")
}

// MARK: - Grid geometry

struct PumpGrid {
    let size: PumpWidgetSize
    var uw: Double { (size.width - 2 * size.pad) / Double(size.cols) }
    var uh: Double { (size.height - 2 * size.pad) / Double(size.rows) }

    /// Frame of a piece in canvas points (design units), inset 2pt each side.
    func frame(x: Double, y: Double, w: Int, h: Int) -> CGRect {
        CGRect(x: size.pad + x * uw + 2, y: size.pad + y * uh + 2, width: Double(w) * uw - 4, height: Double(h) * uh - 4)
    }
}

struct PumpPlacedPiece: Identifiable {
    var piece: PumpWidgetPiece
    var x: Double
    var y: Double
    var dragging = false
    var id: String { piece.id }

    init(_ piece: PumpWidgetPiece, dragging: Bool = false) {
        self.piece = piece; self.x = Double(piece.x); self.y = Double(piece.y); self.dragging = dragging
    }
}

// MARK: - Canvas (CustomWidget.dc.html)

/// Draws a custom widget at design size, scaled to whatever width it is given.
struct PumpWidgetCanvas: View {
    let size: PumpWidgetSize
    let pieces: [PumpPlacedPiece]
    let snapshot: PumpWidgetSnapshot
    var editing = false
    var selectedId: String? = nil
    /// Snap-preview rectangle in cell units while dragging.
    var preview: (x: Int, y: Int, w: Int, h: Int)? = nil
    /// Draw the widget's own rounded canvas background (off inside WidgetKit, which supplies it).
    var drawsBackground = true
    /// Wrap start / quick-start pieces in a deep link (WidgetKit only; off in the builder).
    var interactive = false

    var body: some View {
        if size == .lock {
            canvas.environment(\.colorScheme, .dark).grayscale(1)
        } else {
            canvas
        }
    }

    private var canvas: some View {
        let g = PumpGrid(size: size)
        return GeometryReader { geo in
            let s = geo.size.width / size.width
            ZStack(alignment: .topLeading) {
                if editing { gridDots(g) }
                if let pv = preview {
                    let r = g.frame(x: Double(pv.x), y: Double(pv.y), w: pv.w, h: pv.h)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PumpTheme.accentSoft)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PumpTheme.accentInk.opacity(0.35), lineWidth: 1))
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX, y: r.minY)
                }
                ForEach(pieces) { p in
                    let r = g.frame(x: p.x, y: p.y, w: p.piece.w, h: p.piece.h)
                    pieceContent(p, r)
                        .frame(width: r.width, height: r.height, alignment: .topLeading)
                        .background(
                            p.dragging ? PumpTheme.canvas : (p.piece.type == .quick ? PumpTheme.sunken : Color.clear),
                            in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(editing ? ((p.dragging || selectedId == p.id) ? PumpTheme.accentInk : PumpTheme.rule) : Color.clear, lineWidth: 1))
                        .opacity(p.dragging ? 0.94 : 1)
                        .zIndex(p.dragging ? 10 : 1)
                        .offset(x: r.minX, y: r.minY)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background {
                if drawsBackground && size != .lock {
                    RoundedRectangle(cornerRadius: 22).fill(PumpTheme.canvas)
                }
            }
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: geo.size.width, height: size.height * s, alignment: .topLeading)
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
    }

    @ViewBuilder private func pieceContent(_ p: PumpPlacedPiece, _ r: CGRect) -> some View {
        let m = snapshot.metric(for: p.piece)
        let view = PumpPieceView(piece: p.piece, metric: m, width: r.width, height: r.height, lock: size == .lock)
        if interactive, p.piece.type == .quick || (p.piece.type == .next && m.start),
           let url = PumpWidgetSnapshot.startURL(template: p.piece.type == .quick ? p.piece.metric : nil) {
            Link(destination: url) { view }
        } else {
            view
        }
    }

    private func gridDots(_ g: PumpGrid) -> some View {
        let occupied: Set<String> = Set(pieces.filter { !$0.dragging }.flatMap { p in
            (0..<p.piece.h).flatMap { j in (0..<p.piece.w).map { i in "\(Int(p.x) + i),\(Int(p.y) + j)" } }
        })
        return ZStack(alignment: .topLeading) {
            ForEach(0..<(size.cols * size.rows), id: \.self) { i in
                let cx = i % size.cols, cy = i / size.cols
                if !occupied.contains("\(cx),\(cy)") {
                    Rectangle().fill(PumpTheme.ink.opacity(0.2)).frame(width: 2, height: 2)
                        .offset(x: size.pad + (Double(cx) + 0.5) * g.uw - 1, y: size.pad + (Double(cy) + 0.5) * g.uh - 1)
                }
            }
        }
    }
}

// MARK: - A single piece

struct PumpPieceView: View {
    let piece: PumpWidgetPiece
    let metric: PumpPieceMetric
    let width: Double
    let height: Double
    var lock = false

    private var tall: Bool { piece.h >= 2 }

    private func mono(_ size: CGFloat, bold: Bool = false) -> Font { .spaceMono(size, weight: bold ? .bold : .regular) }
    private func caption(_ text: String, _ size: CGFloat = 7, tracking: CGFloat = 1.2) -> some View {
        Text(text).font(mono(size)).tracking(tracking).foregroundStyle(PumpTheme.muted).lineLimit(1)
    }

    var body: some View {
        content
            .padding(.horizontal, 7).padding(.vertical, 5)
            .frame(width: width, height: height, alignment: .topLeading)
            .clipped()
    }

    @ViewBuilder private var content: some View {
        switch piece.type {
        case .num, .pr: numeric
        case .bars: bars
        case .spark: spark
        case .body: bodyMap
        case .next: next
        case .quick: quick
        case .prog: progress
        }
    }

    // MARK: Numbers (single stat / PR)

    private var valueFont: CGFloat {
        let vlen = metric.v.count
        let byLen: CGFloat = vlen <= 2 ? 34 : vlen <= 3 ? 28 : 22
        return min(byLen, CGFloat(floor(height - (metric.isPR ? 42 : 36))))
    }

    private func valueText(_ size: CGFloat) -> some View {
        Text(metric.v).font(mono(size, bold: true)).lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(PumpTheme.ink)
            .underline(metric.isPR, color: PumpTheme.ink)
    }

    private func delta(_ size: CGFloat = 9) -> some View {
        Text(metric.d).font(mono(size, bold: true)).foregroundStyle(
            metric.dirUp == nil ? PumpTheme.muted : (metric.dirUp! ? PumpTheme.up : PumpTheme.down))
    }

    private var unitLong: String { metric.ago.isEmpty ? metric.u : "\(metric.u) · \(metric.ago)" }

    @ViewBuilder private var numeric: some View {
        let wide = piece.w >= 4
        if tall {
            VStack(alignment: .leading, spacing: 0) {
                caption(metric.k, 8)
                Spacer(minLength: 0)
                valueText(max(valueFont, 10))
                if !metric.d.isEmpty { delta().padding(.top, 3) }
                else { caption(unitLong).padding(.top, 3) }
            }
        } else if wide {
            HStack(alignment: .center, spacing: 6) {
                if width > 170 || metric.d.isEmpty {
                    caption((!metric.ago.isEmpty ? "\(metric.k) · \(metric.ago)" : metric.k), 7)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    valueText(14)
                    if metric.d.isEmpty { caption(metric.u, 7, tracking: 1) } else { delta() }
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            HStack(alignment: .center, spacing: 4) {
                valueText(14)
                Spacer(minLength: 0)
                caption(metric.u, 7, tracking: 1)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: Week bars

    private var bars: some View {
        let mx = max(metric.data.max() ?? 1, 0.0001)
        return VStack(alignment: .leading, spacing: 4) {
            if tall { caption(metric.k) }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(metric.data.enumerated()), id: \.offset) { i, v in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i == metric.today ? PumpTheme.accent : (v > 0 ? PumpTheme.ink : PumpTheme.faint))
                        .frame(height: v > 0 ? max(2, (height - (tall ? 24 : 10)) * v / mx) : 2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: Line chart

    private func line(_ data: [Double]) -> some View {
        GeometryReader { geo in
            Path { p in
                guard data.count > 1 else { return }
                let mn = data.min()!, mx = data.max()!, r = max(mx - mn, 0.0001)
                for (i, v) in data.enumerated() {
                    let pt = CGPoint(x: geo.size.width * Double(i) / Double(data.count - 1),
                                     y: geo.size.height * (28 - (v - mn) / r * 26) / 30)
                    i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
            }
            .stroke(PumpTheme.ink, lineWidth: 1.5)
        }
    }

    @ViewBuilder private var spark: some View {
        if tall {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    caption(metric.k)
                    Spacer(minLength: 4)
                    Text(metric.v).font(mono(12, bold: true)).foregroundStyle(PumpTheme.ink)
                }
                line(metric.data).frame(maxHeight: .infinity)
            }
        } else {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    caption(metric.k, 7, tracking: 1)
                    Text(metric.v).font(mono(11, bold: true)).foregroundStyle(PumpTheme.ink)
                }
                .fixedSize()
                line(metric.data).frame(height: (height - 10) * 0.7)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: Body map

    private var bodyMap: some View {
        let bh = max(20, min(height - 20, (width - 6) / 0.625))
        let b = metric.body
        return VStack(alignment: .leading, spacing: 0) {
            caption(metric.k)
            BodyHeat(intensities: .init(
                traps: b["traps"], chest: b["chest"], shoulders: b["shoulders"], biceps: b["biceps"],
                forearms: b["forearms"], core: b["core"], glutes: b["glutes"], quads: b["quads"], calves: b["calves"]),
                base: PumpTheme.ink.opacity(0.035), stroke: PumpTheme.ink.opacity(0.07))
                .frame(width: bh * 0.625, height: bh)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Next workout

    private var next: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption(metric.k)
            Text(metric.t).font(.archivo(16, weight: .black)).tracking(0.3).foregroundStyle(PumpTheme.ink)
                .lineLimit(1).padding(.top, 3)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 6) {
                caption(metric.meta, 7, tracking: 1).frame(maxWidth: .infinity, alignment: .leading)
                if metric.start {
                    Text("START ›").font(.archivo(10, weight: .black)).tracking(0.5).foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(PumpTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: Quick start

    private var quick: some View {
        HStack {
            Text(metric.t).font(.archivo(11, weight: .black)).tracking(0.3).foregroundStyle(PumpTheme.ink).lineLimit(1)
            Spacer(minLength: 4)
            Text("›").font(mono(12, bold: true)).foregroundStyle(PumpTheme.ink)
        }
        .padding(.horizontal, 1)
        .frame(maxHeight: .infinity)
    }

    // MARK: Progress squares

    private var progress: some View {
        let narrow = piece.w < 4 && metric.n > 5
        let showK = width >= 120 && height >= 34
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if showK { caption(metric.k, 7, tracking: 1) }
                Text(metric.v).font(mono(11, bold: true)).foregroundStyle(PumpTheme.ink)
            }
            .fixedSize()
            if narrow {
                let f = Double(metric.done) / Double(max(metric.n, 1))
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2).fill(PumpTheme.ink).frame(width: max(0, geo.size.width * f - 1))
                        RoundedRectangle(cornerRadius: 2).fill(PumpTheme.faint)
                    }
                }
                .frame(height: 10)
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<max(metric.n, 1), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < metric.done ? PumpTheme.ink : (i == metric.cur ? PumpTheme.accent : PumpTheme.faint))
                            .frame(height: 10)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
