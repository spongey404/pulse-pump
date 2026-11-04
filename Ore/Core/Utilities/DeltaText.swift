import Foundation

/// How a change is written on screen, everywhere: an arrow and the size, or "—" when nothing changed (or there is nothing to compare).
/// Never "▲ 0%" and never a bare 0 as a change.
enum DeltaText {
    /// "▲ 6%" / "▼ 3%" / "—" (nil, or a change that rounds to 0).
    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        let p = Int(value.rounded())
        return p > 0 ? "▲ \(p)%" : p < 0 ? "▼ \(abs(p))%" : "—"
    }

    /// "▲ 4" / "▼ 2" / "—".
    static func count(_ value: Int?) -> String {
        guard let value, value != 0 else { return "—" }
        return value > 0 ? "▲ \(value)" : "▼ \(abs(value))"
    }

    /// Percent change of `now` against `before`; nil when there is nothing before to compare with.
    static func change(now: Double, before: Double) -> Double? { before > 0 ? (now - before) / before * 100 : nil }

    enum Sign { case up, down, flat }

    static func sign(of text: String) -> Sign { text.hasPrefix("▲") ? .up : text.hasPrefix("▼") ? .down : .flat }
}
