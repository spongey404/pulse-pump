import Testing
import Foundation
@testable import Ore

@Suite(.serialized)
struct SupernovaTrialTests {
    private let cal = Calendar(identifier: .gregorian)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    @Test func theDefaultIsThreeMonths() { #expect(SupernovaTrial.defaultMonths == 3) }

    @Test func theTrialRunsForCalendarMonthsFromInstall() {
        let install = day(2026, 1, 31)
        #expect(SupernovaTrial.isActive(installDate: install, now: day(2026, 4, 29), months: 3, calendar: cal))
        #expect(!SupernovaTrial.isActive(installDate: install, now: day(2026, 5, 1), months: 3, calendar: cal))
    }

    @Test func zeroMonthsMeansNoTrial() {
        let install = day(2026, 1, 1)
        #expect(!SupernovaTrial.isActive(installDate: install, now: install, months: 0, calendar: cal))
        #expect(SupernovaTrial.daysRemaining(installDate: install, now: install, months: 0, calendar: cal) == 0)
    }

    @Test func daysRemainingCountsDownAndNeverShowsZeroWhileActive() {
        let install = day(2026, 1, 1)
        #expect(SupernovaTrial.daysRemaining(installDate: install, now: day(2026, 3, 31), months: 3, calendar: cal) == 1)
        #expect(SupernovaTrial.daysRemaining(installDate: install, now: day(2026, 4, 5), months: 3, calendar: cal) == 0)
    }

    @Test func copyFollowsTheMonths() {
        #expect(SupernovaTrial.ctaTitle(months: 3) == "START 3 MONTHS FREE")
        #expect(SupernovaTrial.ctaTitle(months: 1) == "START 1 MONTH FREE")
        #expect(SupernovaTrial.ctaTitle(months: 0) == "START SUPERNOVA")
        #expect(SupernovaTrial.headline(months: 3, apps: "A, B and C") == "3 months free across A, B and C.")
        #expect(SupernovaTrial.headline(months: 0, apps: "A, B and C") == "One membership across A, B and C.")
    }

    @MainActor @Test func remoteValuesApplyAndBadOnesAreIgnored() {
        let saved = UserDefaults.standard.object(forKey: SupernovaTrial.cacheKey)
        defer { UserDefaults.standard.set(saved, forKey: SupernovaTrial.cacheKey) }
        RemoteSettings.apply(trialMonths: 6, starFieldJSON: nil)
        #expect(SupernovaTrial.months == 6)
        RemoteSettings.apply(trialMonths: 99, starFieldJSON: nil)   // out of range: keeps 6
        #expect(SupernovaTrial.months == 6)
        RemoteSettings.apply(trialMonths: nil, starFieldJSON: nil)
        #expect(SupernovaTrial.months == 6)
        RemoteSettings.apply(trialMonths: 0, starFieldJSON: "not json")
        #expect(SupernovaTrial.months == 0)
    }
}
