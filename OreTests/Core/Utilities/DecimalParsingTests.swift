import Testing
@testable import Ore

struct DecimalParsingTests {
    @Test func dotAndCommaDecimals() {
        #expect(parseDecimal("82.5") == 82.5)
        #expect(parseDecimal("82,5") == 82.5)
        #expect(parseDecimal(" 82,5 ") == 82.5)
        #expect(parseDecimal("100") == 100)
        #expect(parseDecimal(",5") == 0.5)
    }

    @Test func thousandsSeparatorsWhenBothPresent() {
        #expect(parseDecimal("1,234.5") == 1234.5)
        #expect(parseDecimal("1.234,5") == 1234.5)
    }

    @Test func rejectsGarbage() {
        #expect(parseDecimal("") == nil)
        #expect(parseDecimal("   ") == nil)
        #expect(parseDecimal("abc") == nil)
        #expect(parseDecimal("8,2,1x") == nil)
        #expect(parseDecimal("inf") == nil)
        #expect(parseDecimal("nan") == nil)
    }

    @Test func wholeNumbers() {
        #expect(parseWholeNumber("8") == 8)
        #expect(parseWholeNumber(" 12 ") == 12)
        #expect(parseWholeNumber("8,0") == 8)
        #expect(parseWholeNumber("8,5") == nil)
        #expect(parseWholeNumber("") == nil)
    }
}
