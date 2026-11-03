import Foundation

/// Username (handle) rules. Must match `usernames/{handle}` in firestore.rules:
/// lower-case, 3-20 characters, `[a-z0-9._]`.
enum HandleValidator {
    static let minLength = 3
    static let maxLength = 20
    static let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._")

    /// Handles nobody may claim (impersonation / routes / system).
    static let reserved: Set<String> = [
        "admin", "administrator", "root", "support", "help", "pump", "pulse", "pulsepump", "pulseplus", "ore", "supernova", "tare", "drift",
        "official", "staff", "team", "moderator", "mod", "system", "null", "undefined", "anonymous",
        "me", "you", "settings", "privacy", "terms", "api", "www", "fuel", "stride",
    ]

    enum Problem: Equatable {
        case empty
        case tooShort
        case tooLong
        case invalidCharacters
        case uppercase
        case edgePunctuation      // starts or ends with . or _
        case repeatedPunctuation  // ".." "__" "._" ...
        case reserved

        var message: String {
            switch self {
            case .empty: "Choose a username."
            case .tooShort: "Use at least \(HandleValidator.minLength) characters."
            case .tooLong: "Use at most \(HandleValidator.maxLength) characters."
            case .invalidCharacters: "Only letters, numbers, dots and underscores."
            case .uppercase: "Usernames are lowercase."
            case .edgePunctuation: "Can't start or end with a dot or underscore."
            case .repeatedPunctuation: "No two dots or underscores in a row."
            case .reserved: "That username isn't available."
            }
        }
    }

    /// Lower-cases and trims; use before validating typed input.
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// First problem with an already-normalised handle, or nil when it is well-formed.
    /// Pass `strictCase: true` to flag upper-case instead of silently accepting it (input is normally normalised first).
    static func validate(_ handle: String, strictCase: Bool = false) -> Problem? {
        if handle.isEmpty { return .empty }
        if strictCase, handle != handle.lowercased() { return .uppercase }
        let h = handle.lowercased()
        if h.count > maxLength { return .tooLong }
        if h.contains(where: { !allowed.contains($0) }) { return .invalidCharacters }
        if h.count < minLength { return .tooShort }
        let punctuation: Set<Character> = [".", "_"]
        if let first = h.first, let last = h.last, punctuation.contains(first) || punctuation.contains(last) {
            return .edgePunctuation
        }
        var previous: Character?
        for c in h {
            if punctuation.contains(c), let p = previous, punctuation.contains(p) { return .repeatedPunctuation }
            previous = c
        }
        if reserved.contains(h) { return .reserved }
        return nil
    }

    /// A reasonable first suggestion from a display name or email prefix (may still need a number suffix).
    static func suggestion(from name: String) -> String {
        var out = ""
        for c in name.lowercased() {
            if allowed.contains(c) { out.append(c) }
            else if c == " " || c == "-" { out.append("_") }
        }
        while out.first == "." || out.first == "_" { out.removeFirst() }
        while out.last == "." || out.last == "_" { out.removeLast() }
        if out.count > maxLength { out = String(out.prefix(maxLength)) }
        while out.last == "." || out.last == "_" { out.removeLast() }
        return out.count >= minLength ? out : (out.isEmpty ? "" : out + String(repeating: "0", count: minLength - out.count))
    }
}
