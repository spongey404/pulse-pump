import Foundation

/// Parses a user-typed decimal. Accepts a comma as the decimal separator ("82,5" -> 82.5),
/// surrounding whitespace, and a thousands separator when both separators are present
/// ("1,234.5" or "1.234,5"). Returns nil for empty, non-numeric or non-finite input.
func parseDecimal(_ text: String) -> Double? {
    var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\u{00A0}", with: "")
        .replacingOccurrences(of: " ", with: "")
    guard !s.isEmpty else { return nil }
    let lastComma = s.lastIndex(of: ",")
    let lastDot = s.lastIndex(of: ".")
    switch (lastComma, lastDot) {
    case let (c?, d?):
        // Both present: whichever comes last is the decimal separator, the other groups thousands.
        if c > d { s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
        else { s = s.replacingOccurrences(of: ",", with: "") }
    case (_?, nil):
        s = s.replacingOccurrences(of: ",", with: ".")
    default:
        break
    }
    guard let value = Double(s), value.isFinite else { return nil }
    return value
}

/// Whole-number variant for reps/RIR. "8", " 8 " and "8,0" parse; "8,5" does not.
func parseWholeNumber(_ text: String) -> Int? {
    guard let value = parseDecimal(text), value == value.rounded(), abs(value) < 1e15 else { return nil }
    return Int(value)
}
