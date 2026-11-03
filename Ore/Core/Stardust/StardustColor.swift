import Foundation

/// A colour as 0–255 channels and 0–1 alpha: what the engine and the renderer pass around (no SwiftUI types, so the
/// engine stays portable and testable).
struct StarRGBA: Equatable {
    var r: Double, g: Double, b: Double, a: Double = 1

    static let gold = StarRGBA(r: 255, g: 196, b: 48)
    static let goldFlare = StarRGBA(r: 255, g: 214, b: 100)
    static let goldHighlight = StarRGBA(r: 255, g: 236, b: 170)
    static let silver = StarRGBA(r: 226, g: 232, b: 240)
    static let lightBlue = StarRGBA(r: 150, g: 215, b: 255)
    static let pinkWhite = StarRGBA(r: 255, g: 235, b: 245)
    static let white = StarRGBA(r: 255, g: 255, b: 255)
    static let clear = StarRGBA(r: 0, g: 0, b: 0, a: 0)

    func mixed(toward other: StarRGBA, _ k: Double) -> StarRGBA {
        StarRGBA(r: (r + (other.r - r) * k).rounded(), g: (g + (other.g - g) * k).rounded(),
                 b: (b + (other.b - b) * k).rounded(), a: a)
    }

    /// "#RRGGBB" or "rgba(r,g,b,a)" / "rgb(r,g,b)".
    init?(css: String) {
        let s = css.trimmingCharacters(in: .whitespaces).lowercased()
        if s.hasPrefix("#"), s.count == 7, let v = UInt32(s.dropFirst(), radix: 16) {
            self.init(r: Double((v >> 16) & 255), g: Double((v >> 8) & 255), b: Double(v & 255))
        } else if s.hasPrefix("rgb"), let open = s.firstIndex(of: "("), let close = s.firstIndex(of: ")") {
            let parts = s[s.index(after: open)..<close].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count >= 3 else { return nil }
            self.init(r: parts[0], g: parts[1], b: parts[2], a: parts.count > 3 ? parts[3] : 1)
        } else { return nil }
    }

    init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }

    var hex: String {
        String(format: "#%02X%02X%02X", Int(r.rounded()), Int(g.rounded()), Int(b.rounded()))
    }
}

/// [deep, accent, light] plus the glow blob and the veil laid over everything.
struct StarPalette: Equatable {
    var deep: StarRGBA, accent: StarRGBA, light: StarRGBA
    var blob: StarRGBA, veil: StarRGBA

    init(deep: StarRGBA, accent: StarRGBA, light: StarRGBA, blob: StarRGBA, veil: StarRGBA) {
        self.deep = deep; self.accent = accent; self.light = light; self.blob = blob; self.veil = veil
    }

    init?(_ p: StardustConfig.Palette) {
        guard p.stops.count == 3, let d = StarRGBA(css: p.stops[0]), let a = StarRGBA(css: p.stops[1]),
              let l = StarRGBA(css: p.stops[2]), let b = StarRGBA(css: p.blob), let v = StarRGBA(css: p.veil) else { return nil }
        self.init(deep: d, accent: a, light: l, blob: b, veil: v)
    }

    /// A palette from one accent colour, shaped like the "Sky" one: the accent in the middle, a deeper and more
    /// saturated blue-leaning stop at one end, a pale tint at the other. Members' accents use it.
    static func derived(fromAccent accent: StarRGBA) -> StarPalette {
        let (h, s, v) = accent.hsv
        let deep = StarRGBA(hue: h + 7, saturation: min(1, s * 1.15), value: v * 0.88)
        let light = StarRGBA(hue: h - 4, saturation: s * 0.5, value: 1)
        let blob = StarRGBA(hue: h + 7, saturation: min(1, s * 1.2), value: v * 0.6, alpha: 0.30)
        let veil = StarRGBA(hue: h + 7, saturation: min(1, s * 1.2), value: v * 0.5, alpha: 0.05)
        return StarPalette(deep: deep, accent: accent, light: light, blob: blob, veil: veil)
    }
}

extension StarRGBA {
    /// Hue in degrees, saturation and value 0–1.
    var hsv: (h: Double, s: Double, v: Double) {
        let rr = r / 255, gg = g / 255, bb = b / 255
        let mx = max(rr, gg, bb), mn = min(rr, gg, bb), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == rr { h = (gg - bb) / d + (gg < bb ? 6 : 0) }
            else if mx == gg { h = (bb - rr) / d + 2 }
            else { h = (rr - gg) / d + 4 }
            h *= 60
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    init(hue: Double, saturation: Double, value: Double, alpha: Double = 1) {
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let c = value * saturation, x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)), m = value - c
        let (r1, g1, b1): (Double, Double, Double)
        switch Int(h) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        self.init(r: ((r1 + m) * 255).rounded(), g: ((g1 + m) * 255).rounded(), b: ((b1 + m) * 255).rounded(), a: alpha)
    }
}
