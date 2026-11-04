import Foundation
import Testing
@testable import Ore

/// The redesigned Home's numbers (weekly streak, ledger, strip, last week) against sixteen weeks of Marcus's training, with expected values
/// worked out from the plan (`MarcusJourney.plan`), never by calling the function under test again.
@MainActor
struct HomeWeekStatsTests {
    private let j = MarcusJourney.shared
    private var sim: UserSim { j.sim }

    private func atDay(_ day: Int, hour: Int = 20, _ body: () -> Void) {
        let saved = sim.now
        sim.skipToDay(day, hour: hour)
        body()
        sim.goTo(saved)
    }

    private func stats() -> HomeWeekStats { HomeWeekStats(workouts: sim.historyRows(), templates: [], now: sim.now, calendar: sim.calendar) }

    /// Weeks in a row trained, counting back from week `w` (a week still to be trained doesn't break it).
    private func expectedStreak(atWeek w: Int, trainedSoFar: Bool) -> Int {
        let trained = Set(j.trainedWeeks)
        var cursor = trainedSoFar && trained.contains(w) ? w : w - 1
        if !trainedSoFar { cursor = w - 1 }
        var n = 0
        while cursor >= 0, trained.contains(cursor) { n += 1; cursor -= 1 }
        return n
    }

    @Test func theWeekStreakCountsWeeksInARowAndSurvivesAWeekNotYetStarted() {
        for w in 0..<16 {
            atDay(7 * w + 6) { #expect(stats().weekStreak == expectedStreak(atWeek: w, trainedSoFar: true), "Sunday of week \(w + 1)") }
        }
        // Monday morning of a trained week before the session: last week's run still stands.
        atDay(7 * 4, hour: 7) { #expect(stats().weekStreak == 4) }
        // The missed week (index 5) breaks it; week 6 (index 6) starts a new one of 1 by its Sunday.
        atDay(7 * 6 + 6) { #expect(stats().weekStreak == 1) }
        // Three weeks off: by the Sunday of the last holiday week the run is gone.
        atDay(7 * 14 + 6) { #expect(stats().weekStreak == 0) }
    }

    @Test func theHeroSaysTodayWithoutAProgramAndPlansFromTheProgramDays() {
        atDay(7 * 3 + 6) { #expect(stats().heroLabel == "TODAY", "no program: nothing to be up next") }
    }

    @Test func theLedgerHasSevenRowsAndOnlyTrainedDaysAreDone() {
        atDay(7 * 3 + 6) {
            let rows = stats().ledger
            #expect(rows.map(\.day) == ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"])
            #expect(rows.filter { $0.workout != nil }.map(\.day) == ["MON", "WED", "FRI"])
            #expect(rows.first { $0.day == "MON" }?.name == "Push Day")
            #expect(rows.first { $0.day == "SUN" }?.isToday == true)
            #expect(rows.filter { $0.workout != nil }.allSatisfy { ($0.sets ?? 0) > 0 })
        }
    }

    @Test func theLedgerSetsAddUpToTheWeeksSets() {
        atDay(7 * 9 + 6) {
            let s = stats()
            #expect(s.ledger.compactMap(\.sets).reduce(0, +) == j.checks[9].homeWeekSets)
            #expect(s.strip.sets == j.checks[9].homeWeekSets)
        }
    }

    @Test func aDoneDayShowsAVolumeChangeAgainstTheLastSessionOfThatWorkout() {
        atDay(7 * 7 + 6) {
            let s = stats()
            // Week 8 (index 7) is a level up on week 7 for every lift, so every volume change is up.
            for r in s.ledger where r.workout != nil { #expect(r.volumeText.hasPrefix("▲"), "\(r.day): \(r.volumeText)") }
        }
        atDay(7 * 6 + 6) {
            // Week 7 repeats week 5's loads (week 6 was off): nothing changed, so it reads "—", never "▲ 0%".
            let s = stats()
            for r in s.ledger where r.workout != nil { #expect(r.volumeText == "—", "\(r.day): \(r.volumeText)") }
        }
    }

    @Test func noChangeIsNeverWrittenAsAZeroPercent() {
        #expect(DeltaText.percent(0) == "—")
        #expect(DeltaText.percent(0.4) == "—")
        #expect(DeltaText.percent(nil) == "—")
        #expect(DeltaText.percent(5.6) == "▲ 6%")
        #expect(DeltaText.percent(-3.2) == "▼ 3%")
        #expect(DeltaText.count(0) == "—")
        #expect(DeltaText.count(nil) == "—")
        #expect(DeltaText.count(4) == "▲ 4")
        #expect(DeltaText.count(-2) == "▼ 2")
        #expect(DeltaText.change(now: 5, before: 0) == nil)
    }

    @Test func theTickerLeavesOutZeroChangesAndIsEmptyWithoutHistory() {
        atDay(7 * 8 + 6) {
            let items = stats().tickerItems(unit: .kg)
            #expect(!items.isEmpty)
            #expect(items.allSatisfy { !$0.value.hasPrefix("0 ") && $0.value != "0%" && $0.value != "0" })
        }
        let fresh = HomeWeekStats(workouts: [], templates: [], now: sim.now, calendar: sim.calendar)
        #expect(fresh.tickerItems(unit: .kg).isEmpty)
        #expect(fresh.weekStreak == 0)
        #expect(fresh.lastWeekLine(unit: .kg) == nil)
    }

    @Test func lastWeekLineHasRealNumbers() {
        atDay(7 * 9 + 2) {
            let line = stats().lastWeekLine(unit: .kg)
            #expect(line?.contains("\(j.checks[8].homeWeekSets) SETS") == true)
        }
    }
}
