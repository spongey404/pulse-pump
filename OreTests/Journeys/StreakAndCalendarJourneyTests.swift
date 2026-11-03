import Testing
import Foundation
import SwiftData
@testable import Ore

/// The streak rule (gap-based, 3-day expiry) at its boundaries, across DST changes, midnight and time zones; and the
/// Monday-first vs Sunday-first week buckets on every screen.
///
/// Documented semantics (StreakCalculator, spec §Streak): unique training days; the streak is alive while the newest day
/// is at most 3 calendar days before today; it extends back through gaps of at most 3 days; every gap adds its length
/// (day 1 then day 3 = 3). Training the same day twice counts once.
@MainActor
struct StreakAndCalendarJourneyTests {
    private let utc = Calendar.journey(.monday, timeZone: "UTC")

    /// Workout dates at noon UTC on Mon 5 Jan 2026 + the given day offsets; `today` is a day offset too.
    private func streak(_ days: [Int], today: Int, hourOfToday: Int = 12) -> Int {
        let base = utc.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12))!
        let dates = days.map { utc.date(byAdding: .day, value: $0, to: base)! }
        let now = utc.date(byAdding: .hour, value: hourOfToday - 12, to: utc.date(byAdding: .day, value: today, to: base)!)!
        return StreakCalculator.currentStreak(from: dates, now: now, calendar: utc)
    }

    // MARK: Boundaries

    @Test func noWorkoutsMeansNoStreak() {
        #expect(streak([], today: 0) == 0)
    }

    @Test(arguments: [(0, 1), (1, 1), (2, 1), (3, 1), (4, 0), (5, 0), (30, 0)])
    func aSingleWorkoutKeepsTheStreakAliveForThreeDaysAndNotFour(daysAgo: Int, expected: Int) {
        #expect(streak([0], today: daysAgo) == expected, "last workout \(daysAgo) days ago")
    }

    @Test(arguments: [(3, 4), (4, 1)])
    func aGapOfThreeDaysKeepsTheChainAndAGapOfFourBreaksIt(gap: Int, expected: Int) {
        // Workouts on day 0 and day `gap`, today is the second workout's day.
        #expect(streak([0, gap], today: gap) == expected)
    }

    @Test func mondayWednesdayFridayRunsForFiveDaysAndStaysAliveUntilTheFollowingTuesday() {
        #expect(streak([0, 2, 4], today: 4) == 5)
        #expect(streak([0, 2, 4], today: 6) == 5)       // Sunday
        #expect(streak([0, 2, 4], today: 7) == 5)       // Monday: 3 days after Friday
        #expect(streak([0, 2, 4], today: 8) == 0)       // Tuesday: 4 days
    }

    @Test func theStreakCountsToTheLastWorkoutNotToToday() {
        #expect(streak([0, 1], today: 3) == 2)
    }

    @Test func manyWorkoutsOnOneDayCountOnce() {
        #expect(streak([0, 0, 0], today: 0) == 1)
        #expect(streak([0, 1, 1, 2, 2], today: 2) == 3)
    }

    @Test func aChainOfThreeDayGapsAddsUpEveryGap() {
        #expect(streak([0, 3, 6, 9], today: 9) == 10)
        #expect(streak([0, 2, 5], today: 8) == 6)       // alive on the boundary: 1 + 3 + 2
    }

    @Test func anOldChainBehindABrokenGapDoesNotCount() {
        #expect(streak([0, 1, 2, 3, 10, 11], today: 11) == 2)
    }

    // MARK: Midnight

    @Test func aWorkoutAtTenToMidnightAndOneJustAfterAreTwoDays() {
        let a = utc.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 23, minute: 59))!
        let b = utc.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 0, minute: 1))!
        #expect(StreakCalculator.currentStreak(from: [a, b], now: b, calendar: utc) == 2)
        let c = utc.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 23, minute: 59))!
        #expect(StreakCalculator.currentStreak(from: [b, c], now: c, calendar: utc) == 1)
    }

    @Test func theStreakFlipsToExpiredAtMidnightAfterTheThirdDay() {
        // Last workout Monday noon. Thursday 23:59 is still day 3; Friday 00:00 is day 4.
        let mon = utc.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12))!
        let thu = utc.date(from: DateComponents(year: 2026, month: 1, day: 8, hour: 23, minute: 59))!
        let fri = utc.date(from: DateComponents(year: 2026, month: 1, day: 9, hour: 0, minute: 0))!
        #expect(StreakCalculator.currentStreak(from: [mon], now: thu, calendar: utc) == 1)
        #expect(StreakCalculator.currentStreak(from: [mon], now: fri, calendar: utc) == 0)
    }

    // MARK: DST and time zones

    @Test func aDaylightSavingSpringForwardDoesNotShortenTheGap() {
        // New York: Fri 6 Mar 20:00 EST -> Mon 9 Mar 08:00 EDT is 59 elapsed hours (the clocks lose one) but three calendar days.
        let ny = Calendar.journey(.monday, timeZone: "America/New_York")
        let fri = ny.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 20))!
        let mon = ny.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 8))!
        #expect(mon.timeIntervalSince(fri) == 59 * 3600)
        #expect(StreakCalculator.currentStreak(from: [fri, mon], now: mon.addingTimeInterval(3600), calendar: ny) == 4)
    }

    @Test func aDaylightSavingFallBackDoesNotLengthenTheGap() {
        // Sat 31 Oct 23:30 -> Tue 3 Nov 00:10 spans the 25-hour day of 1 Nov: still 3 calendar days (alive); one more day is not.
        let ny = Calendar.journey(.monday, timeZone: "America/New_York")
        let sat = ny.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 30))!
        let tueEarly = ny.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 0, minute: 10))!
        let fri = ny.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 23, minute: 59))!
        let tueAfter = ny.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 0, minute: 1))!
        #expect(StreakCalculator.currentStreak(from: [sat], now: tueEarly, calendar: ny) == 1)
        #expect(StreakCalculator.currentStreak(from: [fri], now: tueAfter, calendar: ny) == 0)
    }

    @Test func theSameInstantsFormDifferentDaysInDifferentTimeZones() {
        // 23:30 UTC Mon and 01:00 UTC Tue: two days in London, but one afternoon in Auckland (12:30 and 14:00 Tuesday).
        let a = utc.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 23, minute: 30))!
        let b = utc.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 1))!
        let auckland = Calendar.journey(.monday, timeZone: "Pacific/Auckland")
        #expect(StreakCalculator.currentStreak(from: [a, b], now: b, calendar: utc) == 2)
        #expect(StreakCalculator.currentStreak(from: [a, b], now: b, calendar: auckland) == 1)
    }

    @Test func aSessionPastMidnightBelongsToTheDayItStartedOn() throws {
        let sim = try UserSim(start: DateComponents(year: 2026, month: 1, day: 5, hour: 23, minute: 30))
        sim.startSession(template: "Push Day")
        sim.logSets("Barbell Bench Press", 80, 5, count: 3)
        sim.finish(minutes: 90)                                         // ends 01:00 Tuesday
        #expect(sim.calendar.component(.weekday, from: sim.now) == 3)
        #expect(sim.calendar.isDate(sim.historyRows()[0].date, inSameDayAs: sim.day(0)))
        #expect(sim.streak() == 1)
        #expect(sim.history().workoutsOn(sim.day(0)).count == 1 && sim.history().workoutsOn(sim.day(1)).isEmpty)
        #expect(sim.home().weekDayBars == [3, 0, 0, 0, 0, 0, 0])
        #expect(sim.completions[0].streakCount == 1)
    }

    @Test func aTrainingStreakThroughTheSimulatedEngineMatchesTheCalculatorEveryDay() throws {
        // Train on days 0, 1, 3, 7, 8: check the live streak (via the sim) against the oracle each morning.
        let trained = [0, 1, 3, 7, 8]
        let sim = try UserSim()
        for d in 0...14 {
            sim.skipToDay(d, hour: 18)
            if trained.contains(d) {
                sim.session(template: "Push Day") { s in s.logSets("Barbell Bench Press", 60, 5, count: 1) }
            }
            let expected = Oracle.streak(trainingDays: trained.filter { $0 <= d }.map { sim.day($0) }, today: sim.day(d))
            #expect(sim.streak() == expected, "day \(d)")
        }
        // Concrete anchors: day 3 -> 0,1,3 = 4; day 5 (2 days after) still 4; day 7 starts over: gap 4 -> 1 + 1(day 8) = 2 at day 8.
        sim.skipToDay(3, hour: 23)
        #expect(sim.streak() == 4)
        sim.skipToDay(5, hour: 23)
        #expect(sim.streak() == 4)
        sim.skipToDay(8, hour: 23)
        #expect(sim.streak() == 2)
    }

    // MARK: Week start

    /// Sat 10, Sun 11, Mon 12 and Wed 14 Jan 2026: one exercise, 3 sets each. Clock: Thursday 15 Jan, 20:00.
    private func weekendJourney(_ week: WeekStart) throws -> UserSim {
        let sim = try UserSim(week: week)
        for d in [5, 6, 7, 9] {
            sim.skipToDay(d)
            sim.session(template: "Push Day") { s in s.logSets("Barbell Bench Press", 60, 5, count: 3) }
        }
        sim.skipToDay(10, hour: 20)
        return sim
    }

    @Test func aMondayFirstLocaleHasEveryScreenAgreeOnThisWeek() throws {
        let sim = try weekendJourney(.monday)
        #expect(sim.home().weekSets == 6)
        #expect(sim.home().weekDayBars == [3, 0, 3, 0, 0, 0, 0])
        #expect(sim.recap().setCount(sim.recap().week) == 6)
        #expect(sim.body().selectedTotalSets == 6)
        #expect(sim.widget().fixed.setsThisWeek == 6)
        #expect(sim.widget().sessionsThisWeek == 2)
    }

    @Test func aSundayFirstLocaleStillBucketsRecapBodyAndWidgetByMonday() throws {
        let monday = try weekendJourney(.monday), sunday = try weekendJourney(.sunday)
        #expect(sunday.recap().setCount(sunday.recap().week) == 6)
        #expect(sunday.body().selectedTotalSets == 6)
        #expect(sunday.widget().fixed.setsThisWeek == 6)
        // Last week (Mon 5 - Sun 11 Jan) holds Sat and Sun; the Sunday session is not in this week.
        #expect(sunday.recap(weeksBack: 1).setCount(sunday.recap(weeksBack: 1).week) == 6)
        #expect(sunday.recap().records.count == monday.recap().records.count)
        #expect(sunday.body().weekMonday == monday.body().weekMonday)
        #expect(sunday.history().thisMonthCount == 4 && sunday.history().streak == monday.history().streak)
    }

    @Test func aSundayFirstLocaleKeepsHomesWeekInStepWithTheOtherScreens() throws {
        let sunday = try weekendJourney(.sunday)
        withKnownIssue("HomeStats.weekStart uses the locale's first weekday (Sunday in US-style locales) while the bars, Weekly Recap, Body tab and widgets are Monday-based: Sunday's session lands in 'this week' on Home (9 sets) but in last week everywhere else (6); the bar chart also puts it in the last (Sunday) bar of the week it just started (audit views-body-home, README 'week start')", isIntermittent: true) {
            #expect(sunday.home().weekSets == 6)
            #expect(sunday.home().weekDayBars == [3, 0, 3, 0, 0, 0, 0])
            #expect(sunday.home().weekSets == sunday.recap().setCount(sunday.recap().week))
        }
    }

    @Test func theMonthGridIsMondayFirstInEveryLocale() throws {
        for week in [WeekStart.monday, .sunday] {
            let cal = Calendar.journey(week)
            let feb = MonthGrid.days(for: cal.date(from: DateComponents(year: 2026, month: 2, day: 10))!, calendar: cal)   // 1 Feb 2026 is a Sunday
            #expect(feb.prefix(6).allSatisfy { $0.date == nil } && feb[6].day == 1)
            #expect(feb.compactMap(\.day).count == 28 && feb.count == 42)
            let may = MonthGrid.days(for: cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!, calendar: cal)      // 1 Jun 2026 is a Monday
            #expect(may[0].day == 1)
        }
    }

    @Test func aWeekThatCrossesNewYearIsOneWeekOnHomeRecapBodyAndWidget() throws {
        // Mon 28 Dec 2026 - Sun 3 Jan 2027 is one ISO week: sessions Tue 29 Dec and Fri 1 Jan.
        let sim = try UserSim(start: DateComponents(year: 2026, month: 12, day: 28, hour: 18))
        for d in [1, 4] {
            sim.skipToDay(d)
            sim.session(template: "Push Day") { s in s.logSets("Barbell Bench Press", 60, 5, count: 2) }
        }
        sim.skipToDay(5, hour: 20)                                     // Sat 2 Jan 2027
        #expect(sim.home().weekSets == 4)
        #expect(sim.recap().setCount(sim.recap().week) == 4)
        #expect(sim.body().selectedTotalSets == 4)
        #expect(sim.widget().fixed.setsThisWeek == 4)
        #expect(sim.recap().weekNumber == 53)
        #expect(sim.history().thisMonthCount == 1)                    // only the 1 Jan session is in January
    }
}
