import Testing
import Foundation
@testable import Ore

struct SignupValidationTests {
    private let c = SignupConfig.fallback
    private func check(_ key: String, _ v: String, units: [String: String] = ["weight": "KG", "height": "CM"],
                       status: HandleStatus = .idle) -> SignupValidation.Check {
        SignupValidation.check(key: key, value: v, units: units, handleStatus: status, config: c)
    }

    @Test func emailHints() {
        #expect(check("email", "") == .init(ok: false, hint: "NO SPAM, EVER"))
        #expect(check("email", "casey@") == .init(ok: false, hint: "NOT A VALID EMAIL YET"))
        #expect(check("email", "casey@ore.app") == .init(ok: true, hint: "LOOKS GOOD"))
    }

    @Test func passwordCountsDownThenGradesTheStrength() {
        #expect(check("password", "").hint == "AT LEAST 8 CHARACTERS")
        #expect(check("password", "abc").hint == "5 MORE CHARACTERS")
        #expect(!check("password", "abcdefg").ok)
        #expect(check("password", "abcdefgh") == .init(ok: true, hint: "WEAK"))          // 8+ only
        #expect(check("password", "abcdefg1").hint == "OK")                              // + letters and numbers
        #expect(check("password", "abcdefg1abcd").hint == "GOOD")                        // + 12 characters
        #expect(check("password", "abcdefg1abc!").hint == "STRONG")                      // + a symbol
        #expect(SignupValidation.passwordScore("abcdefgh", config: c) == 1)
    }

    @Test func nameNeedsSomethingButNotMuch() {
        #expect(!check("name", "  ").ok)
        #expect(check("name", "Casey").ok)
        #expect(check("name", "Casey").hint == "FIRST NAME IS FINE · CAN CHANGE LATER")
    }

    @Test func usernameFollowsTheAvailabilityCheck() {
        #expect(check("username", "").hint == "3–20 CHARACTERS: LETTERS, NUMBERS, . AND _")
        #expect(check("username", "ab", status: .invalid(.tooShort)) == .init(ok: false, hint: "USE AT LEAST 3 CHARACTERS"))
        #expect(check("username", "casey", status: .checking).hint == "CHECKING…")
        #expect(check("username", "casey", status: .taken) == .init(ok: false, hint: "ALREADY TAKEN", bad: true))
        #expect(check("username", "casey", status: .available) == .init(ok: true, hint: "AVAILABLE"))
        #expect(check("username", "a..b", status: .invalid(.repeatedPunctuation)).bad)
    }

    @Test func weightRangesFollowTheUnit() {
        #expect(check("weight", "").hint == "USED TO ESTIMATE CALORIE BURN")
        #expect(check("weight", "82.5") == .init(ok: true, hint: "CAN BE UPDATED ANYTIME"))
        #expect(check("weight", "29") == .init(ok: false, hint: "30–300 KG", bad: true))
        #expect(check("weight", "301").bad)
        #expect(check("weight", "66", units: ["weight": "LB"]).ok)
        #expect(check("weight", "65", units: ["weight": "LB"]).hint == "66–660 LB")
        #expect(!check("weight", "3").bad, "one digit isn't an error yet")
    }

    @Test func heightInCentimetresAndFeet() {
        #expect(check("height", "").hint == "USED WITH WEIGHT FOR BASELINE METABOLISM")
        #expect(check("height", "180").ok)
        #expect(check("height", "119") == .init(ok: false, hint: "120–230 CM", bad: true))
        let ft = ["weight": "KG", "height": "FT / IN"]
        #expect(check("height", "", units: ft).hint == "TYPE IT LIKE 5'11")
        for good in ["5'11", "5 11", "5ft11", "5'11\"", "6'", "4'0"] { #expect(check("height", good, units: ft).ok, "\(good)") }
        for bad in ["3'11", "8'0", "5'12", "abc"] { #expect(!check("height", bad, units: ft).ok, "\(bad)") }
        #expect(SignupValidation.parseFtIn("5ft11")! == (5, 11))
    }

    @Test func ageRange() {
        #expect(check("age", "").hint == "NOT SHOWN PUBLICLY")
        #expect(check("age", "13").ok)
        #expect(check("age", "12") == .init(ok: false, hint: "MUST BE 13 OR OVER", bad: true))
        #expect(!check("age", "101").ok)
    }

    @Test func typedTextIsCleanedPerField() {
        #expect(SignupValidation.sanitize(key: "username", text: "Casey Lifts", heightUnit: "CM") == "caseylifts")
        #expect(SignupValidation.sanitize(key: "weight", text: "82.5.1kg", heightUnit: "CM") == "82.51")
        #expect(SignupValidation.sanitize(key: "age", text: "3a1", heightUnit: "CM") == "31")
        #expect(SignupValidation.sanitize(key: "height", text: "18x0", heightUnit: "CM") == "180")
        #expect(SignupValidation.sanitize(key: "height", text: "5'11", heightUnit: "FT / IN") == "5'11")
        #expect(SignupValidation.sanitize(key: "email", text: "A@b.co", heightUnit: "CM") == "A@b.co")
    }
}
