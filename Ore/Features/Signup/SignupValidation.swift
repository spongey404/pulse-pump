import Foundation

/// The sign-up questions' rules and hint lines, as pure functions (tested in `SignupValidationTests`).
/// Hints are the design's wording; `bad` is the error colour, `ok` enables CONTINUE.
enum SignupValidation {
    struct Check: Equatable {
        var ok: Bool
        var hint: String
        var bad = false
    }

    static func check(key: String, value v: String, units: [String: String], handleStatus: HandleStatus,
                      config c: SignupConfig) -> Check {
        switch key {
        case "email": return email(v, config: c)
        case "password": return password(v, config: c)
        case "name": return Check(ok: !v.trimmingCharacters(in: .whitespaces).isEmpty, hint: "FIRST NAME IS FINE · CAN CHANGE LATER")
        case "username": return username(v, status: handleStatus, config: c)
        case "weight": return weight(v, unit: units["weight"] ?? "KG", config: c)
        case "height": return height(v, unit: units["height"] ?? "CM", config: c)
        case "age": return age(v, config: c)
        default: return Check(ok: false, hint: "")
        }
    }

    static func email(_ v: String, config c: SignupConfig) -> Check {
        let ok = v.range(of: c.validation.emailPattern, options: .regularExpression) != nil
        return ok ? Check(ok: true, hint: "LOOKS GOOD") : Check(ok: false, hint: v.isEmpty ? "NO SPAM, EVER" : "NOT A VALID EMAIL YET")
    }

    /// +1 each for 8+ characters, 12+ characters, letters and numbers, a symbol; 8+ is at least 1.
    static func passwordScore(_ v: String, config c: SignupConfig) -> Int {
        var s = 0
        if v.count >= c.validation.passwordMin { s += 1 }
        if v.count >= c.validation.passwordStrong { s += 1 }
        if v.range(of: "[0-9]", options: .regularExpression) != nil, v.range(of: "[a-zA-Z]", options: .regularExpression) != nil { s += 1 }
        if v.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { s += 1 }
        return max(v.count >= c.validation.passwordMin ? 1 : 0, s)
    }

    static func password(_ v: String, config c: SignupConfig) -> Check {
        let min = c.validation.passwordMin
        if v.count >= min { return Check(ok: true, hint: ["", "WEAK", "OK", "GOOD", "STRONG"][passwordScore(v, config: c)]) }
        return Check(ok: false, hint: v.isEmpty ? "AT LEAST \(min) CHARACTERS" : "\(min - v.count) MORE CHARACTERS")
    }

    static func username(_ v: String, status: HandleStatus, config c: SignupConfig) -> Check {
        if v.isEmpty { return Check(ok: false, hint: "3–20 CHARACTERS: LETTERS, NUMBERS, . AND _") }
        switch status {
        case .available: return Check(ok: true, hint: "AVAILABLE")
        case .taken: return Check(ok: false, hint: "ALREADY TAKEN", bad: true)
        case .checking, .idle: return Check(ok: false, hint: "CHECKING…")
        case .invalid(let problem):
            return problem == .tooShort ? Check(ok: false, hint: "USE AT LEAST 3 CHARACTERS")
                                        : Check(ok: false, hint: problem.message.uppercased(), bad: true)
        case .failed(let text): return Check(ok: false, hint: text.uppercased(), bad: true)
        }
    }

    static func weight(_ v: String, unit: String, config c: SignupConfig) -> Check {
        let r = unit == "LB" ? c.validation.weightLb : c.validation.weightKg
        if v.isEmpty { return Check(ok: false, hint: "USED TO ESTIMATE CALORIE BURN") }
        if let n = Double(v), n >= r[0], n <= r[1] { return Check(ok: true, hint: "CAN BE UPDATED ANYTIME") }
        return Check(ok: false, hint: "\(Int(r[0]))–\(Int(r[1])) \(unit)", bad: v.count >= 2)
    }

    static func height(_ v: String, unit: String, config c: SignupConfig) -> Check {
        let imperial = unit != "CM"
        if v.isEmpty { return Check(ok: false, hint: imperial ? "TYPE IT LIKE 5'11" : "USED WITH WEIGHT FOR BASELINE METABOLISM") }
        if !imperial {
            let r = c.validation.heightCm
            if let n = Double(v), n >= r[0], n <= r[1] { return Check(ok: true, hint: "LOOKS RIGHT") }
            return Check(ok: false, hint: "\(Int(r[0]))–\(Int(r[1])) CM", bad: v.count >= 3)
        }
        if let p = parseFtIn(v), p.ft >= c.validation.heightFt[0], p.ft <= c.validation.heightFt[1] { return Check(ok: true, hint: "LOOKS RIGHT") }
        return Check(ok: false, hint: "TYPE IT LIKE 5'11", bad: v.count >= 3)
    }

    static func age(_ v: String, config c: SignupConfig) -> Check {
        if v.isEmpty { return Check(ok: false, hint: "NOT SHOWN PUBLICLY") }
        let r = c.validation.age
        if let n = Int(v), n >= r[0], n <= r[1] { return Check(ok: true, hint: "NOT SHOWN PUBLICLY") }
        let n = Int(v) ?? 0
        return Check(ok: false, hint: n > r[1] ? "\(r[0])–\(r[1]) YRS" : "MUST BE \(r[0]) OR OVER", bad: v.count >= 2)
    }

    /// "5'11", "5 11", "5ft11", "5'11\"": feet 0–9 and inches below 12.
    static func parseFtIn(_ v: String) -> (ft: Int, inch: Int)? {
        let pattern = #"^(\d)\s*(?:'|ft|\s)\s*(\d{1,2})?\s*(?:"|in)?$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let t = v.trimmingCharacters(in: .whitespaces)
        let ns = t as NSString
        guard let m = re.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let ft = Int(ns.substring(with: m.range(at: 1))) ?? 0
        let inch = m.range(at: 2).location == NSNotFound ? 0 : Int(ns.substring(with: m.range(at: 2))) ?? 0
        return inch < 12 ? (ft, inch) : nil
    }

    /// What the field keeps of what was typed: usernames are lower case without spaces; number fields keep digits
    /// (weight also one decimal point); ft / in is typed freely.
    static func sanitize(key: String, text: String, heightUnit: String) -> String {
        switch key {
        case "username": return text.lowercased().filter { !$0.isWhitespace }
        case "weight":
            var seenDot = false
            return text.filter { c in
                if c.isASCII, c.isNumber { return true }
                if c == ".", !seenDot { seenDot = true; return true }
                return false
            }
        case "height": return heightUnit == "CM" ? text.filter { $0.isASCII && $0.isNumber } : text
        case "age": return text.filter { $0.isASCII && $0.isNumber }
        default: return text
        }
    }
}
