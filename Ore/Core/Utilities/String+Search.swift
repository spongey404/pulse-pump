import Foundation

extension String {
    /// Returns true if any whitespace-separated word in the string
    /// starts with `prefix` (case-insensitive).
    /// "Dumbbell Shoulder Press".hasWordPrefix("s") → true  (Shoulder)
    /// "Assault Bike".hasWordPrefix("s")            → false (no word starts with s)
    func hasWordPrefix(_ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }
        let p = prefix.lowercased()
        return components(separatedBy: .whitespaces)
            .contains { $0.lowercased().hasPrefix(p) }
    }
}
