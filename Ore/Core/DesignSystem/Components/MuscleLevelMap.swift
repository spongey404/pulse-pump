import SwiftUI

extension MuscleGroup {
    /// The body-map regions this muscle group lights up (the design's `levels` keys).
    var mapRegions: [String] {
        switch self {
        case .chest: ["chest"]
        case .shoulders: ["frontDelts", "sideDelts", "rearDelts"]
        case .frontDelts: ["frontDelts"]
        case .sideDelts: ["sideDelts"]
        case .rearDelts: ["rearDelts"]
        case .back: ["upperBack", "lats", "lowerBack"]
        case .traps: ["traps"]
        case .lats: ["lats"]
        case .upperBack: ["upperBack"]
        case .lowerBack: ["lowerBack"]
        case .biceps: ["biceps"]
        case .triceps: ["triceps"]
        case .forearms: ["forearms"]
        case .abs: ["abs"]
        case .obliques: ["obliques"]
        case .glutes: ["glutes"]
        case .quads: ["quads"]
        case .hamstrings: ["hamstrings"]
        case .calves: ["calves"]
        case .hipFlexors, .adductors, .abductors, .neck: []   // not drawn on the map
        }
    }
}

/// How hard an exercise works each region, 0...1: primary muscles full, secondary half.
enum MuscleLevels {
    static func levels(primary: [MuscleGroup], secondary: [MuscleGroup]) -> [String: Double] {
        var out: [String: Double] = [:]
        for g in secondary { for r in g.mapRegions { out[r] = max(out[r] ?? 0, 0.5) } }
        for g in primary { for r in g.mapRegions { out[r] = 1.0 } }
        return out
    }
}

/// Front and back body map, each muscle tinted `--accent` by its level over the figure's base fill.
/// Geometry is the design's `BodyMap.dc.html`.
struct MuscleLevelMap: View {
    let levels: [String: Double]
    @Environment(\.colorScheme) private var scheme

    struct RGBA: Equatable { var r, g, b, a: Double }

    /// `color-mix(in srgb, accent <level>%, base)`.
    static func mix(accent: RGBA, base: RGBA, level: Double) -> RGBA {
        let v = max(0, min(1, level))
        return RGBA(r: accent.r * v + base.r * (1 - v), g: accent.g * v + base.g * (1 - v),
                    b: accent.b * v + base.b * (1 - v), a: accent.a * v + base.a * (1 - v))
    }

    private var base: Color { scheme == .dark ? Color(hex: "#ECE5D6").opacity(0.10) : Color(hex: "#151A21").opacity(0.035) }
    private var stroke: Color { scheme == .dark ? Color(hex: "#ECE5D6").opacity(0.12) : Color(hex: "#151A21").opacity(0.09) }

    private func rgba(_ color: Color) -> RGBA {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(r: r, g: g, b: b, a: a)
    }

    private func fill(for muscle: String) -> Color {
        guard let level = levels[muscle], level > 0 else { return base }
        let m = Self.mix(accent: rgba(.oreAccent), base: rgba(base), level: level)
        return Color(.sRGB, red: m.r, green: m.g, blue: m.b, opacity: m.a)
    }

    var body: some View {
        HStack(spacing: 8) {
            figure("FRONT", MuscleLevelMapShapes.front)
            figure("BACK", MuscleLevelMapShapes.back)
        }
    }

    private func figure(_ label: String, _ shapes: [(muscle: String, path: String)]) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.spaceMono(8)).tracking(1.5)
                .foregroundStyle(Color.inkMuted)
            Canvas { ctx, size in
                let box = MuscleLevelMapShapes.viewBox
                let s = min(size.width / box.width, size.height / box.height)
                let dx = (size.width - box.width * s) / 2, dy = (size.height - box.height * s) / 2
                let transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: s, y: s).translatedBy(x: -box.minX, y: -box.minY)
                let line = StrokeStyle(lineWidth: 1)
                func draw(_ path: Path, _ color: Color) {
                    let p = path.applying(transform)
                    ctx.fill(p, with: .color(color))
                    ctx.stroke(p, with: .color(stroke), style: line)
                }
                let h = MuscleLevelMapShapes.head
                draw(Path(ellipseIn: CGRect(x: h.cx - h.r, y: h.cy - h.r, width: h.r * 2, height: h.r * 2)), base)
                draw(Path(MuscleLevelMapShapes.neck), base)
                for (muscle, data) in shapes { draw(SVGPathLite.path(data), fill(for: muscle)) }
                for f in MuscleLevelMapShapes.feet {
                    draw(Path(ellipseIn: CGRect(x: f.cx - f.rx, y: f.cy - f.ry, width: f.rx * 2, height: f.ry * 2)), base)
                }
            }
            .aspectRatio(MuscleLevelMapShapes.viewBox.width / MuscleLevelMapShapes.viewBox.height, contentMode: .fit)
        }
        .frame(maxWidth: .infinity)
    }
}
