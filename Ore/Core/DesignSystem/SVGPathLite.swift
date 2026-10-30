import SwiftUI

/// Reads the tiny subset of SVG path data the design's body map uses: absolute `M`, `L`, `Q` and `Z`.
/// Anything else is ignored, so a path the parser doesn't understand draws nothing instead of garbage.
enum SVGPathLite {
    static func path(_ data: String) -> Path {
        var path = Path()
        let tokens = tokenize(data)
        var i = 0
        func number() -> CGFloat? {
            guard i < tokens.count, case .number(let n) = tokens[i] else { return nil }
            i += 1
            return CGFloat(n)
        }
        var command: Character = "M"
        while i < tokens.count {
            if case .command(let c) = tokens[i] { command = c; i += 1 }
            switch command {
            case "M":
                guard let x = number(), let y = number() else { return path }
                path.move(to: CGPoint(x: x, y: y))
                command = "L"   // extra pairs after M are lines, as in SVG
            case "L":
                guard let x = number(), let y = number() else { return path }
                path.addLine(to: CGPoint(x: x, y: y))
            case "Q":
                guard let cx = number(), let cy = number(), let x = number(), let y = number() else { return path }
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
            case "Z", "z":
                path.closeSubpath()
            default:
                return path
            }
        }
        return path
    }

    private enum Token { case command(Character), number(Double) }

    private static func tokenize(_ s: String) -> [Token] {
        var out: [Token] = []
        var current = ""
        func flush() {
            if !current.isEmpty, let n = Double(current) { out.append(.number(n)) }
            current = ""
        }
        for ch in s {
            if ch.isLetter {
                flush()
                out.append(.command(ch))
            } else if ch == " " || ch == "," {
                flush()
            } else if ch == "-", !current.isEmpty {
                flush()
                current = "-"
            } else {
                current.append(ch)
            }
        }
        flush()
        return out
    }
}
