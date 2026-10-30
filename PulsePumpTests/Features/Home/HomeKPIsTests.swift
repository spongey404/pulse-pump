import Foundation
import Testing
@testable import PulsePump

/// `HomeKPIs.init(onePassOver:)` answers every Home number in one walk over the history. It must give exactly
/// the numbers the individual `HomeStats` properties give (the readable definition of each), at every point of
/// sixteen weeks of realistic training (see `MarcusJourney`).
@MainActor
struct HomeKPIsTests {
    private let j = MarcusJourney.shared
    private var sim: UserSim { j.sim }

    private func atDay(_ day: Int, hour: Int = 20, _ body: () -> Void) {
        let saved = sim.now
        sim.skipToDay(day, hour: hour)
        body()
        sim.goTo(saved)
    }

    @Test func theSinglePassMatchesTheIndividualPropertiesAcrossSixteenWeeks() {
        // Every week boundary and a day in the middle of each week: new weeks, a missed week, a deload, a holiday.
        for week in 0..<16 {
            for dayInWeek in [0, 3, 6] {
                atDay(week * 7 + dayInWeek) {
                    let stats = sim.home()
                    let reference = HomeKPIs(stats)
                    let onePass = HomeKPIs(onePassOver: stats)
                    #expect(onePass == reference, "week \(week + 1), day \(dayInWeek + 1)")
                }
            }
        }
    }

    @Test func theNumbersAreRealNotJustEqualEmptyOnes() {
        // Guard against both sides being trivially empty: find a moment with training in the current week.
        var sawSets = false, sawPRs = false, sawImproved = false, sawTicker = false, sawRows = false
        for day in stride(from: 3, to: 112, by: 3) {
            atDay(day) {
                let k = HomeKPIs(onePassOver: sim.home())
                sawSets = sawSets || k.weekSets > 0
                sawPRs = sawPRs || k.weekPRs > 0
                sawImproved = sawImproved || k.weekImproved > 0
                sawTicker = sawTicker || !k.tickerRows.isEmpty
                sawRows = sawRows || k.recentRows.contains { $0.improved > 0 }
            }
        }
        #expect(sawSets && sawPRs && sawImproved && sawTicker && sawRows)
    }

    @Test func anEmptyHistoryGivesEmptyNumbers() throws {
        let fresh = try UserSim()
        let k = HomeKPIs(onePassOver: fresh.home())
        #expect(k == HomeKPIs(fresh.home()))
        #expect(k.weekSets == 0 && k.weekPRs == 0 && k.weekImproved == 0 && k.recentRows.isEmpty)
        #expect(k.weekDayBars == [0, 0, 0, 0, 0, 0, 0])
    }

    @Test func theWeekBarsAddUpToTheWeeksSets() {
        atDay(7 * 10 + 4) {
            let k = HomeKPIs(onePassOver: sim.home())
            #expect(k.weekDayBars.reduce(0, +) == k.weekSets)
        }
    }
}
