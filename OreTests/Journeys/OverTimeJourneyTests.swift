import Testing
import Foundation
import SwiftData
@testable import Ore

/// Sixteen weeks of realistic training (see `MarcusJourney`): progressive overload, a missed week, a deload,
/// an equal repeat, a rep-only PR, a three-week holiday and a lighter comeback. Every number asserted here is
/// either a hand-derived literal or computed from the harness ledger, never from the code under test.
@MainActor
struct OverTimeJourneyTests {
    private let j = MarcusJourney.shared
    private var sim: UserSim { j.sim }
    private static let bench = "Barbell Bench Press"

    private func utcDayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    /// Runs `body` with the sim clock moved to `day` at `hour`, then puts it back.
    private func atDay(_ day: Int, hour: Int = 20, _ body: () -> Void) {
        let saved = sim.now
        sim.skipToDay(day, hour: hour)
        body()
        sim.goTo(saved)
    }

    // MARK: History

    @Test func historyHasOneRowPerSessionNewestFirst() {
        let rows = sim.historyRows()
        #expect(rows.count == 36)
        let dates = rows.map(\.date)
        #expect(dates == dates.sorted(by: >))
        #expect(Set(rows.map(\.id)) == Set(j.sessions.map(\.workoutId)))
    }

    @Test func historyGrowsByThreeOnTrainedWeeksOnly() {
        var expected = 0
        for c in j.checks {
            if c.trained { expected += 3 }
            #expect(c.historyCount == expected, "week \(c.week)")
        }
    }

    @Test func historyDaysAreMondayWednesdayFridayOfTrainedWeeks() {
        let hist = sim.history()
        let marked = hist.workoutDateSet
        var expected = Set<String>()
        for w in j.trainedWeeks { for off in [0, 2, 4] { expected.insert(utcDayKey(sim.day(7 * w + off))) } }
        #expect(marked == expected)
        #expect(hist.workoutsOn(sim.day(7 * 5 + 2)).isEmpty)            // the missed week
        #expect(hist.workoutsOn(sim.day(7 * 13)).isEmpty)               // the holiday
        #expect(hist.workoutsOn(sim.day(7 * 11 + 4)).count == 1)
    }

    @Test func historyCalendarListsEachSessionOnItsDay() {
        for s in j.sessions {
            let rows = sim.history().workoutsOn(s.day)
            #expect(rows.count == 1)
            #expect(rows.first?.template?.name == s.template)
        }
    }

    @Test func historyStatsRowShowsTotalMonthAndStreak() {
        let hist = sim.history()       // clock: Sunday 26 Apr 2026, 20:00
        #expect(hist.totalCount == 36)
        #expect(hist.thisMonthCount == 3)              // only the comeback week (20, 22, 24 Apr) is in April
        #expect(hist.streak == 5)
    }

    @Test func monthGridPadsToSixRowsWithAMondayFirstOffset() {
        let jan = MonthGrid.days(for: sim.day(0), calendar: sim.calendar)     // 1 Jan 2026 is a Thursday
        #expect(jan.count == 42)
        #expect(jan.prefix(3).allSatisfy { $0.date == nil })
        #expect(jan[3].day == 1)
        #expect(jan.compactMap(\.day).count == 31)
    }

    // MARK: Exercise detail

    @Test func benchTrendPointsAreTheHeaviestWorkingSetOfEachSessionOldestFirst() {
        let points = sim.progress(of: Self.bench).trendPoints
        // Hand-derived: 60 + 2.5/week to week 4, repeat, 72.5, deload -20, 72.5, 75, 75, comeback 65.
        #expect(points.map(\.maxWeight) == [60, 62.5, 65, 67.5, 70, 70, 72.5, 52.5, 72.5, 75, 75, 65])
        #expect(points.map(\.date) == points.map(\.date).sorted())
        // Independent: the max of the ledger per session.
        let perSession = j.trainedWeeks.map { w in j.ledger(week: w, exercise: Self.bench).map(\.kg).max()! }
        #expect(points.map(\.maxWeight) == perSession)
    }

    @Test func benchTrendRisesWhileProgressingAndDipsOnTheDeloadAndComeback() {
        let w = sim.progress(of: Self.bench).trendPoints.map(\.maxWeight)
        #expect(Array(w[0...4]) == Array(w[0...4]).sorted())            // monotonic through week 4
        #expect(w[4] == w[5])                                           // equal repeat is flat, not a rise
        #expect(w[7] < w[6])                                            // deload dips
        #expect(w[11] < w[10])                                          // comeback is lighter
    }

    @Test func exerciseStatCardsMatchTheLedger() {
        let p = sim.progress(of: Self.bench)
        let working = j.sim.working(Self.bench)
        #expect(p.weightPR == 75 && p.weightPR == working.map(\.kg).max())
        #expect(p.repsPR == 6 && p.repsPR == working.map(\.reps).max())
        let e1rm = working.map { Oracle.epleyDetail($0.kg, $0.reps) }.max()!
        #expect(abs(p.estimated1RM - e1rm) < 1e-9)
        #expect(abs(p.estimated1RM - 87.5) < 1e-9)                       // 75 x 5
        // Volume PR: best single-session volume, week 9's 6+5+5 reps at 72.5.
        let perSession = j.trainedWeeks.map { Oracle.volume(j.ledger(week: $0, exercise: Self.bench)) }
        #expect(p.volumePR == perSession.max())
        #expect(p.volumePR == 72.5 * 16)
    }

    @Test func everyLiftTrendHasOnePointPerSessionItAppearedIn() {
        for name in ["Barbell Bench Press", "Overhead Press", "Barbell Row", "Barbell Curl", "Barbell Squat", "Leg Press"] {
            #expect(sim.progress(of: name).trendPoints.count == 12, "\(name)")
            #expect(sim.progress(of: name).allSets.count == j.sim.working(name).count)
        }
    }

    // MARK: PRs

    @Test func prCountPerSessionFollowsTheScript() {
        for s in j.sessions {
            #expect(s.data.prCount == MarcusJourney.expectedPRsPerSession[s.week], "week \(s.week) \(s.template)")
        }
    }

    @Test func improvedCountPerSessionFollowsTheScript() {
        for s in j.sessions {
            #expect(s.data.improvedCount == MarcusJourney.expectedImproved(week: s.week, template: s.template), "week \(s.week) \(s.template)")
        }
    }

    @Test func progressiveWeeksFlagWeightPRsWithTheRightDelta() {
        for s in j.sessions where [1, 2, 3, 4, 7, 10].contains(s.week) {
            #expect(s.data.prDetails.count == 2)
            #expect(s.data.prDetails.allSatisfy { $0.isWeightPR && $0.weightDelta == 2.5 && $0.repsDelta == 0 }, "week \(s.week)")
        }
    }

    @Test func theRepOnlyWeekFlagsRepPRsAtTheSameWeight() {
        for s in j.sessions where s.week == 9 {
            #expect(s.data.prDetails.count == 2)
            #expect(s.data.prDetails.allSatisfy { !$0.isWeightPR && $0.repsDelta == 1 && $0.weightDelta == 0 })
        }
    }

    @Test func equalRepeatsDeloadsAndComebacksAreNeverPRs() {
        for s in j.sessions where [6, 8, 11, 15].contains(s.week) {
            #expect(s.data.prCount == 0 && s.data.prDetails.isEmpty, "week \(s.week)")
        }
    }

    @Test func warmUpsAreNeverPRsEvenWhenHeavierThanTheBest() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 100, 5, count: 3) }
        sim.skipToDay(2)
        sim.startSession(template: "Push Day")
        sim.warmup(Self.bench, 120, 3)                               // heavier than anything done, but a warm-up
        let warmIdx = sim.entryIndex(Self.bench)!
        sim.vm.checkPR(exerciseIndex: warmIdx, setIndex: 0, modelContext: sim.ctx)
        #expect(!sim.vm.exerciseEntries[warmIdx].sets[0].isPR)
        sim.logSets(Self.bench, 100, 5, count: 3)
        let data = sim.finish()
        #expect(data.prCount == 0 && data.improvedCount == 0)
        #expect(sim.progress(of: Self.bench).weightPR == 100)
    }

    @Test func theLiveSetFlagLightsOnlyOnARealNewBest() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 100, 5, count: 3) }
        sim.skipToDay(2)
        sim.startSession(template: "Push Day")
        let a = sim.log(Self.bench, 100, 5)                          // equal repeat
        sim.vm.checkPR(exerciseIndex: a.exercise, setIndex: a.set, modelContext: sim.ctx)
        let b = sim.log(Self.bench, 100, 6)                          // more reps at the same weight
        sim.vm.checkPR(exerciseIndex: b.exercise, setIndex: b.set, modelContext: sim.ctx)
        let c = sim.log(Self.bench, 102.5, 3)                        // heavier
        sim.vm.checkPR(exerciseIndex: c.exercise, setIndex: c.set, modelContext: sim.ctx)
        let flags = sim.vm.exerciseEntries[a.exercise].sets.prefix(3).map(\.isPR)
        #expect(flags == [false, true, true])
    }

    @Test func aLighterWeightForMoreRepsImprovesE1RMWithoutBeingAPR() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 100, 5, count: 3) }      // e1RM 116.7
        sim.skipToDay(2)
        sim.startSession(template: "Push Day")
        sim.logSets(Self.bench, 95, 8, count: 3)                                                 // e1RM 120.3
        let data = sim.finish()
        #expect(data.prCount == 0)                       // no new heaviest weight, no earlier lighter set to beat on reps
        #expect(data.improvedCount == 1)                 // but the estimated 1RM went up
        #expect(abs(sim.progress(of: Self.bench).estimated1RM - 95 * (1 + 8.0 / 30)) < 1e-9)
    }

    @Test func aSingleRepRecordAgreesBetweenTheCompletionSummaryAndTheExerciseScreen() throws {
        let sim = try UserSim()
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 100, 10, count: 3) }     // e1RM 133.3
        let before = sim.progress(of: Self.bench).estimated1RM
        sim.skipToDay(2)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 133, 1)                                                              // a single
        let data = sim.finish()
        let after = sim.progress(of: Self.bench).estimated1RM
        #expect(data.improvedCount == 1)                 // completion: 133 x 1 = 137.5 beats 133.3
        withKnownIssue("Estimated-1RM is defined three ways: WorkoutViewModel.epley (weight*(1+reps/30), also for singles) vs ExerciseProgress.epley / WidgetDataService.FSet.e1rm (a single = the weight). The summary says 'improved' while the exercise screen's EST 1RM does not move", isIntermittent: true) {
            #expect(after > before)
        }
    }

    // MARK: Volume, bars, recap

    @Test func weekOneAndTwoVolumesMatchHandSums() {
        // Week 0: 5 sets x5 reps at 60,35,60,25,80,120 kg (3,2,3,2,3,2 sets) = 900+350+900+250+1200+1200.
        #expect(abs(j.checks[0].recapVolumeT - 4.8) < 1e-9)
        // Week 1: every lift +2.5 kg over 75 reps.
        #expect(abs(j.checks[1].recapVolumeT - 4.9875) < 1e-9)
    }

    @Test func recapVolumeSetsAndSessionsEqualTheLedgerEveryWeek() {
        for c in j.checks {
            let sets = j.ledger(week: c.week)
            #expect(c.recapSets == sets.count, "week \(c.week)")
            #expect(abs(c.recapVolumeT - Oracle.volume(sets) / 1000) < 1e-9, "week \(c.week)")
            #expect(c.recapSessions == (c.trained ? 3 : 0), "week \(c.week)")
        }
    }

    @Test func homeWeekBarsPutEachDaysSetsOnTheRightWeekday() {
        for c in j.checks {
            let expected = c.trained ? [5, 0, 5, 0, 5, 0, 0] : [0, 0, 0, 0, 0, 0, 0]
            #expect(c.homeBars == expected, "week \(c.week)")
            #expect(c.homeWeekSets == expected.reduce(0, +))
        }
    }

    @Test func widgetBodyAndHomeAgreeWithTheLedgerEachWeek() {
        for c in j.checks {
            let sets = j.ledger(week: c.week).count
            #expect(c.widgetSetsThisWeek == sets, "widget week \(c.week)")
            #expect(c.bodyTotalSets == sets, "body week \(c.week)")
            #expect(c.homeWeekSets == sets, "home week \(c.week)")
            #expect(abs(c.widgetVolumeT - (Oracle.volume(j.ledger(week: c.week)) / 100).rounded() / 10) < 1e-9, "widget volume week \(c.week)")
        }
    }

    @Test func theMissedWeekAndTheHolidayReadAsZeroEverywhere() {
        for w in [5, 12, 13, 14] {
            let c = j.checks[w]
            #expect(c.recapSessions == 0 && c.recapSets == 0 && c.recapVolumeT == 0)
            #expect(c.homeWeekSets == 0 && c.bodyTotalSets == 0 && c.widgetSetsThisWeek == 0)
            #expect(c.homeBars == [0, 0, 0, 0, 0, 0, 0])
        }
    }

    @Test func theDeloadWeekIsLighterByExactlyTheDroppedKilograms() {
        // Same sets and reps as week 7 but 20 kg lighter on 15 sets of 5 reps.
        let drop = j.checks[7].recapVolumeT - j.checks[8].recapVolumeT
        #expect(abs(drop - 20.0 * 75 / 1000) < 1e-9)
        #expect(j.checks[8].recapSets == j.checks[7].recapSets)
    }

    @Test func recapRecordsListEachWeightRecordOfTheWeek() {
        let saved = sim.now
        defer { sim.goTo(saved) }
        sim.skipToDay(7 * 7 + 6, hour: 20)                       // Sunday of week 7
        let r = sim.recap().records
        #expect(r.count == 6)
        #expect(r.first { $0.name == Self.bench }?.value == "72.5×5")
        #expect(Set(r.map(\.name)) == ["Barbell Bench Press", "Overhead Press", "Barbell Row", "Barbell Curl", "Barbell Squat", "Leg Press"])
        sim.skipToDay(7 * 6 + 6, hour: 20)
        #expect(sim.recap().records.isEmpty)                      // equal repeat week: no records
    }

    @Test func personalRecordCountsAgreeAcrossCompletionHomeAndRecapOnARepPRWeek() {
        let saved = sim.now
        defer { sim.goTo(saved) }
        sim.skipToDay(7 * 9 + 6, hour: 20)
        let completionPRs = j.sessions.filter { $0.week == 9 }.reduce(0) { $0 + $1.data.prCount }
        #expect(completionPRs == 6)
        withKnownIssue("Weekly Recap PERSONAL RECORDS (WeeklyRecapStats.records) and Home PRs (HomeStats.weekPRs) count only heavier weights; the completion summary (WorkoutViewModel.completeWorkout:294) also counts rep PRs, so week 9 shows 6 vs 0 vs 0", isIntermittent: true) {
            #expect(sim.recap().records.count == completionPRs)
            #expect(sim.home().weekPRs == completionPRs)
        }
    }

    // MARK: Calories

    @Test func caloriesFollowTheBasicFormulaPerDayType() {
        // push/pull/squat sets are compound (10 each), curl is isolation (6): Push 5x10, Pull 3x10+2x6, Legs 5x10.
        for s in j.sessions {
            let w = j.sim.historyRows().first { $0.id == s.workoutId }!
            let expected: Double = s.template == "Pull Day" ? 42 : 50
            #expect(w.calorieBurnEstimate == expected, "\(s.template) week \(s.week)")
        }
    }

    // MARK: Streak across the weeks

    @Test func streakAtTheEndOfEachWeekFollowsTheGapRule() {
        let expected = [5, 12, 19, 26, 33, 0, 5, 12, 19, 26, 33, 40, 0, 0, 0, 5]
        #expect(j.checks.map(\.streak) == expected)
        for c in j.checks {
            let today = sim.day(7 * c.week + 6)
            #expect(c.streak == Oracle.streak(trainingDays: j.trainingDays(through: c.week), today: today), "week \(c.week)")
            #expect(c.widgetStreak == c.streak)
        }
    }

    @Test func theCompletionScreenStreakMatchesTheOraclePerSession() {
        for s in j.sessions {
            let days = j.sim.ledger.filter { $0.day <= s.day }.map(\.day)
            #expect(s.data.streakCount == max(1, Oracle.streak(trainingDays: days, today: s.day)), "week \(s.week) \(s.template)")
        }
    }

    @Test func theStreakSurvivesTheFridayToMondayGapButNotAMissedWeek() {
        #expect(j.checks[1].streak > j.checks[0].streak)       // Fri -> Mon is a 3-day gap: still one streak
        #expect(j.checks[5].streak == 0)                        // a full missed week breaks it
        #expect(j.checks[6].streak == 5)                        // and the new one starts from scratch
    }

    // MARK: Body tab

    @Test func muscleRecencyHeatFadesOverFortyEightHours() {
        // Push day (week 1, Monday 12 Jan) ended 19:00; chest is a primary of the bench press.
        atDay(7, hour: 21) {
            let monday = sim.body().heatLevels(mode: .recency)
            #expect(abs(monday[.chest]! - (1 - 3.0 / 48)) < 1e-9)          // Monday 21:00 reference: 3 h after the 18:00 start
        }
        atDay(8, hour: 12) {
            let tuesday = sim.body().heatLevels(mode: .recency)
            #expect(abs(tuesday[.chest]! - (1 - 27.0 / 48)) < 1e-9)
        }
        atDay(9, hour: 21) {
            let wednesday = sim.body().heatLevels(mode: .recency)
            #expect(wednesday[.chest]! == 0)                                // 51 h: fully faded
            #expect(abs(wednesday[.lats]! - (1 - 3.0 / 48)) < 1e-9)        // today's pull day is hot
        }
    }

    @Test func volumeHeatIsSetsOverTheWeeklyTargetAndCapsAtOne() {
        atDay(7 * 1 + 6) {
            let h = sim.body().heatLevels(mode: .volume)
            #expect(abs(h[.chest]! - 3.0 / 16) < 1e-9)
            #expect(abs(h[.lats]! - 3.0 / 16) < 1e-9)
            #expect(abs(h[.quads]! - 5.0 / 20) < 1e-9)              // squat 3 + leg press 2
            #expect(abs(h[.biceps]! - 2.0 / 10) < 1e-9)
            #expect(h[.hamstrings]! == 0 && h[.calves]! == 0)
        }
    }

    @Test func vsPaceReadsSetsAgainstTheShareOfTheWeeklyTarget() {
        // Weekly target is the sum of the 17 per-muscle targets = 176 sets.
        #expect(BodyMapStats.weeklyTarget == 176)
        atDay(7, hour: 20) {                                         // Monday after push: 5 sets, 25 due
            let v = sim.body().vsInfo
            #expect(v.label == "VS PACE" && v.value == "▼ -80%" && v.sub == "25 DUE BY MON" && v.sign == -1)
        }
        atDay(9, hour: 20) {                                         // Wednesday: 10 sets, 75 due
            let v = sim.body().vsInfo
            #expect(v.value == "▼ -87%" && v.sub == "75 DUE BY WED")
        }
        atDay(11, hour: 20) {                                        // Friday: 15 sets, 126 due
            let v = sim.body().vsInfo
            #expect(v.value == "▼ -88%" && v.sub == "126 DUE BY FRI")
        }
        atDay(13, hour: 20) {                                        // Sunday: 15 sets, all 176 due
            let v = sim.body().vsInfo
            #expect(v.value == "▼ -91%" && v.sub == "176 DUE BY SUN")
        }
    }

    @Test func vsLastWeekCompareUsesTheWeekBeforeAndShowsZeroWhenEqual() {
        atDay(7 * 2 + 1) {
            let v = sim.body(weekOffset: -1).vsInfo                  // week 1 (12-18 Jan) vs week 0
            #expect(v.label == "VS WK 2" && v.value == "● 0%" && v.sub == "15 SETS" && v.sign == 0)
        }
        atDay(7 * 6 + 1) {
            let v = sim.body(weekOffset: -1).vsInfo                  // the missed week vs week 4: nothing before it
            #expect(v.value == "▼ -100%" && v.sub == "15 SETS")
        }
        atDay(7 * 7 + 1) {
            let v = sim.body(weekOffset: -2).vsInfo                  // the missed week itself vs week 4
            #expect(v.value == "▼ -100%")
            let missed = sim.body(weekOffset: -2).vsInfo
            #expect(missed.sub == "15 SETS")
        }
    }

    @Test func aDaySelectionComparesWithTheLastSessionOfTheSameTemplate() {
        atDay(7 * 3 + 6) {
            let v = sim.body(weekOffset: 0, day: 2).vsInfo          // Wednesday of week 3 = pull day
            #expect(v.label == "VS LAST PULL" && v.value == "● 0%")
            #expect(sim.body(weekOffset: 0, day: 1).vsInfo.sub == "REST DAY")
        }
        atDay(6) {
            #expect(sim.body(weekOffset: 0, day: 0).vsInfo.sub == "FIRST SESSION")
        }
    }

    @Test func topAndGapsAfterAProgressiveWeek() {
        atDay(7 * 1 + 6) {
            let b = sim.body()
            #expect(b.topMuscles[0].key == "GLUTE" && b.topMuscles[0].sets == 5 && b.topMuscles[0].target == 12)
            #expect(b.gapMuscles.count == 3 && b.gapMuscles.allSatisfy { $0.sets == 0 })
            #expect(b.musclesWorkedCount == 6)             // chest, front delts, lats, biceps, quads, glutes (generic shoulders/back are not counted next to their specific groups)
        }
    }

    @Test func everyGroupGoesColdAfterTheHolidayAndTheBodyTabSaysSo() {
        atDay(7 * 14 + 6) {                                          // Sunday of the third holiday week
            let b = sim.body()
            #expect(b.selectedTotalSets == 0 && b.musclesWorkedCount == 0)
            #expect(b.topMuscles.allSatisfy { $0.sets == 0 } && b.gapMuscles.allSatisfy { $0.sets == 0 })
            #expect(b.vsInfo.value == "▼ -100%" && b.vsInfo.sub == "176 DUE BY SUN")
            #expect(b.heatLevels(mode: .volume).values.allSatisfy { $0 == 0 })
            #expect(b.heatLevels(mode: .recency).values.allSatisfy { $0 == 0 })
            let vol = b.coldSpots(mode: .vol)
            #expect(vol.count == 3 && vol.allSatisfy { $0.value == 0 && $0.isFlagged })
            let freq = b.coldSpots(mode: .freq)
            #expect(freq.count == 3 && freq.allSatisfy(\.isFlagged))
        }
    }

    @Test func daysSinceTheLastPushPullAndLegsKeepCountingThroughTheHoliday() {
        atDay(7 * 14 + 6) {
            let b = sim.body()
            #expect(b.daysSince(workoutNamed: "PUSH") == "27D")      // Mon wk 11 (day 77) -> day 104
            #expect(b.daysSince(workoutNamed: "PULL") == "25D")
            #expect(b.daysSince(workoutNamed: "LEG") == "23D")
        }
    }

    @Test func coldSpotCadenceFlagsOnlyOnceTheGapIsOneAndAHalfTimesTheUsualRest() {
        // Day 7*11+6 = 83: legs last trained on day 81 (2 days), chest on day 77 (6 days; cadence 4 -> flag at 6).
        atDay(7 * 11 + 6) {
            let freq = sim.body().coldSpots(mode: .freq)
            let chest = sim.body().coldSpots(mode: .freq).first { $0.muscleName == MuscleGroup.chest.displayName }
            #expect(freq.count == 3)
            // Never-trained groups (99-day sentinel) lead the list; trained ones are measured in real days.
            #expect(freq[0].value == 99)
            if let chest { #expect(chest.value == 6 && chest.isFlagged) }
        }
    }

    @Test func theCalendarJumpLandsOnTheTappedWeekWithinThreeWeeks() throws {
        // Clock: Sunday of week 15. Week 15's own Wednesday is this week; week 12 (holiday) is 3 weeks back.
        let thisWed = try #require(sim.body().viewTarget(for: sim.day(7 * 15 + 2)))
        #expect(thisWed.weekOffset == 0 && thisWed.dayIndex == 2)
        let target = sim.body(weekOffset: thisWed.weekOffset).weekMonday
        #expect(target == sim.day(7 * 15))
        let threeBack = try #require(sim.body().viewTarget(for: sim.day(7 * 12 + 4)))
        #expect(threeBack.weekOffset == -3 && threeBack.dayIndex == 4)
        #expect(sim.body(weekOffset: threeBack.weekOffset).weekMonday == sim.day(7 * 12))
    }

    @Test func theCalendarOffersNoJumpForAWorkoutOlderThanTheWeekScrubber() {
        // The scrubber covers the last 4 weeks; clamping would open a different week than the one tapped, so the
        // calendar shows "OLDER THAN 4 WEEKS" instead of VIEW ›.
        let friday = sim.day(7 * 11 + 4)                             // a session 4 weeks back
        #expect(sim.body().viewTarget(for: friday) == nil)
    }

    // MARK: Widgets, bodyweight, predictor

    @Test func theBodyweightLogFollowsTheScaleAndNeverChangesLiftingStats() {
        #expect(sim.user.weight == 79.5)
        atDay(7 * 10 + 6) {
            let snap = sim.widget()
            #expect(snap.bodyweight == 79.5)
            #expect(snap.fixed.bodyweightSeries.last == 79.5)
            #expect(snap.fixed.bodyweightDelta7d == -1.5)             // 81 a week earlier
        }
        #expect(sim.progress(of: Self.bench).weightPR == 75)
    }

    @Test func theNextWorkoutKeepsRotatingThroughTheLapse() {
        // History (newest first) is a clean Push, Pull, Legs rotation; the predictor never looks at dates.
        #expect(sim.historyNames().prefix(3) == ["Leg Day", "Pull Day", "Push Day"])
        #expect(sim.prediction() == "Push Day")
    }

    @Test func predictionConfidenceGrowsWithTheLengthOfAConsistentHistory() {
        let rotation = ["Push Day", "Pull Day", "Leg Day"]
        func history(_ n: Int) -> [String] { (0..<n).map { rotation[(n - 1 - $0) % 3] } }     // newest first, ends on Legs
        var last = 0.0
        for n in [7, 10, 13] {
            let c = WidgetDataService.predictionConfidence(names: history(n), hasSplit: true, predicted: true)
            #expect(c >= last, "confidence at \(n) sessions")
            last = c
        }
        #expect(WidgetDataService.predictionConfidence(names: history(10), hasSplit: true, predicted: true) == 0.95)
        #expect(WidgetDataService.predictionConfidence(names: history(7), hasSplit: true, predicted: true) == 0.67)
    }
}
