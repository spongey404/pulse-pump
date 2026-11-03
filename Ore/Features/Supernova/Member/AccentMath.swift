import Foundation

/// The member's accent colour as the picker edits it: hue 0–360, saturation and lightness ("shade") 0–100, and the exact hex when
/// it was typed or picked from the presets (nil while a slider is moving it: the hex then follows from the three numbers).
struct AccentPick: Codable, Equatable {
    var h: Int
    var s: Int
    var l: Int
    var hex: String?

    var hexString: String { (hex ?? AccentMath.hex(h: h, s: s, l: l)).uppercased() }
}

/// One swatch in the presets & recent row. Presets keep their exact hex.
struct AccentSwatch: Codable, Equatable {
    var name: String
    var h: Int
    var s: Int
    var l: Int
    var hex: String

    init(name: String, h: Int, s: Int, l: Int, hex: String) { self.name = name; self.h = h; self.s = s; self.l = l; self.hex = hex.uppercased() }
    init?(name: String, hex: String) {
        guard let n = AccentMath.normalizeHex(hex), let c = AccentMath.hsl(fromHex: n) else { return nil }
        self.init(name: name, h: c.h, s: c.s, l: c.l, hex: n)
    }
    var pick: AccentPick { AccentPick(h: h, s: s, l: l, hex: hex) }
}

/// The picker's rules, pure (no SwiftUI): colour conversion, the Stardust palette derived from a colour, how a slider edit
/// changes the colour, the hold-to-repeat and fine-scrub curves, and how the recent row is kept. Every number comes from
/// `SupernovaMemberConfig.Picker`.
enum AccentMath {
    enum Channel { case hue, saturation, shade }

    // MARK: Conversion

    static func rgb(h: Double, s: Double, l: Double) -> (r: Int, g: Int, b: Int) {
        let s = s / 100, l = l / 100
        let a = s * min(l, 1 - l)
        func f(_ n: Double) -> Double {
            let k = (n + h / 30).truncatingRemainder(dividingBy: 12)
            return l - a * max(-1, min(k - 3, 9 - k, 1))
        }
        return (Int((f(0) * 255).rounded()), Int((f(8) * 255).rounded()), Int((f(4) * 255).rounded()))
    }

    static func hex(h: Double, s: Double, l: Double) -> String {
        let c = rgb(h: h, s: s, l: l)
        return String(format: "#%02X%02X%02X", c.r, c.g, c.b)
    }

    static func hex(h: Int, s: Int, l: Int) -> String { hex(h: Double(h), s: Double(s), l: Double(l)) }

    static func hsl(fromHex hex: String) -> (h: Int, s: Int, l: Int)? {
        guard let n = normalizeHex(hex), let v = UInt32(n.dropFirst(), radix: 16) else { return nil }
        let r = Double((v >> 16) & 255) / 255, g = Double((v >> 8) & 255) / 255, b = Double(v & 255) / 255
        let mx = max(r, g, b), mn = min(r, g, b), l = (mx + mn) / 2, d = mx - mn
        var h = 0.0, s = 0.0
        if d != 0 {
            s = d / (1 - abs(2 * l - 1))
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) } else if mx == g { h = (b - r) / d + 2 } else { h = (r - g) / d + 4 }
            h = (h * 60 + 360).truncatingRemainder(dividingBy: 360)
        }
        return (Int(h.rounded()), Int((s * 100).rounded()), Int((l * 100).rounded()))
    }

    /// "#RRGGBB" from "#abc", "abc", "AABBCC" or "#aabbcc"; nil if it isn't a colour.
    static func normalizeHex(_ text: String) -> String? {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("#") { t.removeFirst() }
        if t.count == 3 { t = t.map { "\($0)\($0)" }.joined() }
        guard t.count == 6, t.allSatisfy(\.isHexDigit) else { return nil }
        return "#" + t.uppercased()
    }

    // MARK: Stardust palette

    /// [g0, g1, g2] as hex plus the glow and veil, from the picked colour.
    static func palette(for pick: AccentPick, rule: SupernovaMemberConfig.Picker.PaletteRule) -> StarPalette {
        let base = pick.hexString
        let l = Double(pick.l)
        let stops: [String]
        if l + rule.stopLight > 100 {
            stops = rule.lightStops.map { hex(h: Double(pick.h), s: Double(pick.s), l: $0) }
        } else if l - rule.stopDark < 0 {
            stops = rule.darkStops.map { hex(h: Double(pick.h), s: Double(pick.s), l: $0) }
        } else {
            stops = [hex(h: Double(pick.h), s: Double(pick.s), l: l - rule.stopDark), base, hex(h: Double(pick.h), s: Double(pick.s), l: l + rule.stopLight)]
        }
        func color(_ hexCode: String) -> StarRGBA { StarRGBA(css: hexCode) ?? .white }
        func alpha(_ lightness: Double, _ a: Double) -> StarRGBA {
            let c = rgb(h: Double(pick.h), s: Double(pick.s), l: lightness)
            return StarRGBA(r: Double(c.r), g: Double(c.g), b: Double(c.b), a: a)
        }
        return StarPalette(deep: color(stops[0]), accent: color(stops[1]), light: color(stops[2]),
                           blob: alpha(rule.blobLightness, rule.blobAlpha), veil: alpha(rule.veilLightness, rule.veilAlpha))
    }

    /// The [g0, g1, g2] hexes alone (tests, the card's gradient).
    static func stopHexes(for pick: AccentPick, rule: SupernovaMemberConfig.Picker.PaletteRule) -> [String] {
        let p = palette(for: pick, rule: rule)
        return [p.deep.hex, p.accent.hex, p.light.hex]
    }

    // MARK: Editing

    /// Moving the hue of a grey, black or white would show nothing, so it also brings the saturation and shade into range.
    static func huePatched(_ c: AccentPick, rule: SupernovaMemberConfig.Picker.HuePatch) -> AccentPick {
        var c = c
        if c.s < rule.satBelow || c.l < rule.shadeBelow || c.l > rule.shadeAbove {
            c.s = max(c.s, rule.minSat)
            c.l = max(rule.shadeMin, min(rule.shadeMax, c.l))
        }
        return c
    }

    /// A slider (or ± step) sets one channel; the hex then follows from the three numbers.
    static func setting(_ channel: Channel, to value: Double, in c: AccentPick, rule: SupernovaMemberConfig.Picker.HuePatch) -> AccentPick {
        var c = c
        let v = Int(value.rounded())
        switch channel {
        case .hue: c.h = max(0, min(360, v))   // a drag can reach 360 (the strip's end); ± steps wrap (below)
        case .saturation: c.s = max(0, min(100, v))
        case .shade: c.l = max(0, min(100, v))
        }
        c.hex = nil
        return channel == .hue ? huePatched(c, rule: rule) : c
    }

    static func nudged(_ channel: Channel, by n: Int, in c: AccentPick, rule: SupernovaMemberConfig.Picker.HuePatch) -> AccentPick {
        switch channel {
        case .hue: return setting(.hue, to: Double(((c.h + n) % 360 + 360) % 360), in: c, rule: rule)
        case .saturation: return setting(.saturation, to: Double(c.s + n), in: c, rule: rule)
        case .shade: return setting(.shade, to: Double(c.l + n), in: c, rule: rule)
        }
    }

    static func range(_ channel: Channel) -> ClosedRange<Double> { channel == .hue ? 0...360 : 0...100 }

    // MARK: Drag and hold

    /// Speed of a drag while the finger is `distance` pt away from the strip (1 on it, ¼ and 1/10 further out).
    static func fineFactor(distance: Double, curve: [[Double]]) -> Double {
        for step in curve where step.count == 2 && distance > step[0] { return step[1] }
        return 1
    }

    /// New value after the finger moved `dx` pt over a strip `width` pt wide.
    static func dragged(_ value: Double, dx: Double, width: Double, channel: Channel, distance: Double, curve: [[Double]]) -> Double {
        let r = range(channel), span = r.upperBound - r.lowerBound
        let v = value + dx / max(1, width) * span * fineFactor(distance: distance, curve: curve)
        return max(r.lowerBound, min(r.upperBound, v))
    }

    /// Step of a ± button held for `seconds`.
    static func holdStep(_ channel: Channel, seconds: Double, picker: SupernovaMemberConfig.Picker) -> Int {
        let table = channel == .hue ? picker.holdHue : picker.holdOther
        return Int(table.first { seconds < $0[0] }?.last ?? table.last?.last ?? 1)
    }

    static func holdInterval(seconds: Double, picker: SupernovaMemberConfig.Picker) -> Double {
        picker.holdIntervalsMs.first { seconds < $0[0] }?.last ?? picker.holdIntervalsMs.last?.last ?? 90
    }

    // MARK: Presets and recent

    static func defaultSwatches(_ picker: SupernovaMemberConfig.Picker) -> [AccentSwatch] {
        picker.presets.compactMap { $0.count == 2 ? AccentSwatch(name: $0[0], hex: $0[1]) : nil }
    }

    /// A saved list, de-duplicated by hex and filled up from the presets to the limit.
    static func normalized(_ saved: [AccentSwatch], picker: SupernovaMemberConfig.Picker) -> [AccentSwatch] {
        var seen = Set<String>(), out: [AccentSwatch] = []
        for s in saved where seen.insert(s.hex).inserted { out.append(s) }
        for p in defaultSwatches(picker) where out.count < picker.recentLimit && seen.insert(p.hex).inserted { out.append(p) }
        return Array(out.prefix(picker.recentLimit))
    }

    /// When the member leaves the page with a colour: it goes to the far left. Already first: nothing changes. Already in the
    /// row: it moves to the front. Otherwise everything shifts right and the last one drops off.
    static func committed(_ swatches: [AccentSwatch], pick: AccentPick, limit: Int) -> [AccentSwatch] {
        let current = pick.hexString
        let i = swatches.firstIndex { $0.hex == current }
        if i == 0 { return swatches }
        let item = i.map { swatches[$0] } ?? AccentSwatch(name: "RECENT", h: pick.h, s: pick.s, l: pick.l, hex: current)
        var rest = swatches
        if let i { rest.remove(at: i) }
        return Array(([item] + rest).prefix(limit))
    }

    /// The name under the hex field: the preset's or recent's name, else CUSTOM.
    static func name(for pick: AccentPick, in swatches: [AccentSwatch]) -> String {
        swatches.first { $0.hex == pick.hexString }?.name ?? "CUSTOM"
    }
}

extension SupernovaMemberConfig.Picker {
    var isUsable: Bool {
        func validTable(_ t: [[Double]], count: Int = 2) -> Bool { !t.isEmpty && t.allSatisfy { $0.count == count && $0.allSatisfy(\.isFinite) && $0[1] > 0 } }
        return AccentMath.normalizeHex(defaultHex) != nil
            && !presets.isEmpty && presets.count <= 20 && presets.allSatisfy { $0.count == 2 && AccentMath.normalizeHex($0[1]) != nil }
            && (1...20).contains(recentLimit) && holdDelayMs.isFinite && (0...5000).contains(holdDelayMs)
            && validTable(holdHue) && validTable(holdOther) && validTable(holdIntervalsMs)
            && fine.allSatisfy { $0.count == 2 && $0.allSatisfy(\.isFinite) && $0[1] > 0 }
            && palette.lightStops.count == 3 && palette.darkStops.count == 3
            && (palette.lightStops + palette.darkStops + [palette.stopDark, palette.stopLight, palette.blobLightness, palette.blobAlpha,
                                                          palette.veilLightness, palette.veilAlpha]).allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 100 }
    }
}
