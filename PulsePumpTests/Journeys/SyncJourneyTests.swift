import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// Everything the user sees, as plain comparable values. Two phones holding the same account must produce equal digests.
struct ScreenDigest: Equatable {
    var history: [String] = []
    var historyStats: [String] = []
    var lifts: [String] = []
    var home: [String] = []
    var recaps: [String] = []
    var body: [String] = []
    var widget: [String] = []
    var prediction = ""

    private static func n(_ v: Double) -> String { String(format: "%.6f", v) }

    @MainActor
    init(_ sim: UserSim) {
        let rows = sim.historyRows()
        history = rows.map { w in
            "\(Int(w.date.timeIntervalSince1970)) \(w.template?.name ?? "-") sets=\(w.workingSetCount) vol=\(Self.n(w.workingVolume)) "
            + "dur=\(Int(w.duration)) cal=\(Self.n(w.calorieBurnEstimate)) ex=\(w.exerciseLogs.count) deload=\(w.isDeload)"
        }
        let h = sim.history()
        historyStats = ["\(h.totalCount)", "\(h.thisMonthCount)", "\(h.streak)", h.workoutDateSet.sorted().joined(separator: ",")]
        for name in ["Barbell Bench Press", "Overhead Press", "Barbell Row", "Barbell Curl", "Barbell Squat", "Leg Press"] {
            let p = sim.progress(of: name)
            lifts.append("\(name) pr=\(Self.n(p.weightPR)) reps=\(p.repsPR) e1rm=\(Self.n(p.estimated1RM)) vol=\(Self.n(p.volumePR)) "
                         + "trend=\(p.trendPoints.map { Self.n($0.maxWeight) }.joined(separator: ","))")
        }
        let home = sim.home()
        self.home = ["streak=\(home.currentStreak)", "sets=\(home.weekSets)", "prs=\(home.weekPRs)", "impr=\(home.weekImproved)",
                     "bars=\(home.weekDayBars)", "recent=\(home.recentRows)", "ticker=\(home.tickerRows)"]
        for back in 0..<12 {
            let r = sim.recap(weeksBack: back)
            recaps.append("\(back) n=\(r.week.count) sets=\(r.setCount(r.week)) vol=\(Self.n(r.volumeTonnes(r.week))) min=\(r.minutes(r.week)) "
                          + "rec=\(r.records.map { $0.name + $0.value }.sorted())")
        }
        let b = sim.body()
        let heat = b.heatLevels(mode: .volume).map { "\($0.key.rawValue)=\(Self.n($0.value))" }.sorted()
        let recency = b.heatLevels(mode: .recency).map { "\($0.key.rawValue)=\(Self.n($0.value))" }.sorted()
        body = ["sets=\(b.selectedTotalSets)", "worked=\(b.musclesWorkedCount)", "vs=\(b.vsInfo)", "top=\(b.topMuscles)", "gaps=\(b.gapMuscles)",
                "heat=\(heat)", "recency=\(recency)", "cold=\(b.coldSpots(mode: .freq))", "coldVol=\(b.coldSpots(mode: .vol))"]
        let snap = sim.widget()
        widget = ["streak=\(snap.streak)", "week=\(snap.sessionsThisWeek)", "sets=\(snap.fixed.setsThisWeek)", "vol=\(snap.fixed.volumeTonnes)",
                  "last=\(snap.fixed.lastWorkoutName)", "prs=\(snap.prs.keys.sorted().map { "\($0)=\(snap.prs[$0]!.weight)" })",
                  "bw=\(snap.fixed.bodyweightSeries)", "unit=\(String(describing: snap.weightUnit))", "goal=\(snap.sessionGoal)",
                  "load=\(snap.fixed.loadWeeks)", "neglected=\(snap.fixed.neglected)", "bodyVol=\(snap.bodyVolume.sorted { $0.key < $1.key })"]
        prediction = "\(sim.prediction() ?? "nil") \(sim.confidence())"
    }
}

@MainActor
struct SyncJourneyTests {
    /// Phone A trains `weeks` weeks of the Marcus plan, syncs, and a fresh phone B restores the account.
    private func twoPhones(weeks: Int, unit: UnitPreference = .kg) async throws -> (a: SyncDevice, b: SyncDevice, simA: UserSim, simB: UserSim, remote: InMemoryRemoteStore) {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        let simA = try UserSim(unit: unit, context: a.ctx, defaults: a.bodyweight)
        _ = try MarcusJourney(sim: simA, weeks: weeks)
        await a.sync()
        let b = try SyncDevice.make(remote: remote)
        for e in ExerciseSeedService.allExercises { b.ctx.insert(e) }        // its own freshly seeded catalogue (different ids)
        TemplateSeedService.seedIfNeeded(modelContext: b.ctx)               // and presets, which share stable ids across installs
        await b.sync()
        let simB = try UserSim(adopting: b.ctx, now: simA.now, origin: simA.origin, defaults: b.bodyweight)
        return (a, b, simA, simB, remote)
    }

    @Test func aTenWeekHistoryRestoresOnANewPhoneWithEveryDerivedNumberIdentical() async throws {
        let (a, b, simA, simB, remote) = try await twoPhones(weeks: 10)
        #expect(b.service.isInitialSyncComplete)
        #expect(remote.count(.workouts) == 27 && b.count(Workout.self) == 27)
        #expect(a.count(SetLog.self) == b.count(SetLog.self))

        let da = ScreenDigest(simA), db = ScreenDigest(simB)
        #expect(da.history.count == 27)
        #expect(da.history == db.history)
        #expect(da.historyStats == db.historyStats)
        #expect(da.lifts == db.lifts)
        #expect(da.home == db.home)
        #expect(da.recaps == db.recaps)
        #expect(da.body == db.body)
        #expect(da.widget == db.widget)
        #expect(da.prediction == db.prediction)
        #expect(da == db)
    }

    @Test func restoringDoesNotMakeThePhonesChatterBackAndForth() async throws {
        let (a, b, _, _, remote) = try await twoPhones(weeks: 3)
        let writes = remote.writeCount
        await a.sync(); await b.sync(); await a.sync()
        #expect(remote.writeCount == writes)
        #expect(a.service.pendingCount == 0 && b.service.pendingCount == 0)
    }

    @Test func aWorkoutDeletedOnOnePhoneUpdatesTheOthersStreakChartsAndPRs() async throws {
        let (a, b, simA, simB, _) = try await twoPhones(weeks: 5)
        let before = ScreenDigest(simB)
        let newest = try #require(simA.historyRows().first)             // Friday of week 4: the 70 kg bench PR session? (legs)
        simA.deleteWorkout(newest)
        await a.sync(); await b.sync()

        let da = ScreenDigest(simA), db = ScreenDigest(simB)
        #expect(da == db)
        #expect(db.history.count == before.history.count - 1)
        #expect(simB.historyRows().count == 14)
        #expect(simB.progress(of: "Barbell Squat").trendPoints.count == 4)     // week 4's squat session is gone
        #expect(da.widget != before.widget)
    }

    @Test func editsToDifferentWorkoutsOnBothPhonesMergeAndAgree() async throws {
        let (a, b, simA, simB, _) = try await twoPhones(weeks: 3)
        let wa = try #require(simA.workout(onDay: 0))                   // week 0 push, edited on A (set 0 is the warm-up, set 1 the first working set)
        simA.editSet(wa, "Barbell Bench Press", setIndex: 1, weight: 70)
        let wb = try #require(simB.workout(onDay: 2))                   // week 0 pull, edited on B
        simB.editSet(wb, "Barbell Row", setIndex: 1, weight: 70)
        await a.sync(); await b.sync(); await a.sync()

        #expect(ScreenDigest(simA) == ScreenDigest(simB))
        #expect(simA.progress(of: "Barbell Bench Press").weightPR == 70)
        #expect(simB.progress(of: "Barbell Bench Press").weightPR == 70)
        #expect(simA.progress(of: "Barbell Row").weightPR == 70)
        #expect(simB.progress(of: "Barbell Row").weightPR == 70)
    }

    @Test func anInProgressDraftStaysOnItsPhone() async throws {
        let (a, b, simA, simB, remote) = try await twoPhones(weeks: 2)
        let uploaded = remote.count(.workouts)
        simA.skipToDay(14)
        simA.startSession(template: "Push Day")
        simA.logSets("Barbell Bench Press", 100, 5, count: 3)
        await a.sync(); await b.sync()
        #expect(remote.count(.workouts) == uploaded)
        #expect(simB.drafts().isEmpty && simB.historyRows().count == 6)
        #expect(simA.drafts().count == 1)
        // Finishing it makes it history everywhere.
        simA.finish()
        await a.sync(); await b.sync()
        #expect(remote.count(.workouts) == uploaded + 1)
        simB.goTo(simA.now)
        #expect(simB.historyRows().count == 7 && ScreenDigest(simA) == ScreenDigest(simB))
    }

    @Test func theUnitSplitAndDeloadFlagsTravelWithTheAccount() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        let simA = try UserSim(unit: .lbs, split: .upperLower, context: a.ctx, defaults: a.bodyweight)
        _ = try MarcusJourney(sim: simA, weeks: 3)
        for w in simA.historyRows() where w.date >= simA.day(14) { w.isDeload = true; w.markUpdated() }
        await a.sync()
        let b = try SyncDevice.make(remote: remote)
        for e in ExerciseSeedService.allExercises { b.ctx.insert(e) }
        TemplateSeedService.seedIfNeeded(modelContext: b.ctx)
        await b.sync()
        let simB = try UserSim(adopting: b.ctx, now: simA.now, origin: simA.origin, defaults: b.bodyweight)

        #expect(simB.user.unitPreference == .lbs && simB.user.selectedSplit?.days.count == 4)
        #expect(simB.historyRows().filter(\.isDeload).count == 3)
        #expect(simB.widget().weightUnit == .lbs && simB.widget().sessionGoal == 4)
        #expect(ScreenDigest(simA) == ScreenDigest(simB))
        #expect(simB.user.unitPreference.number(simB.progress(of: "Barbell Bench Press").weightPR) == "65")      // typed in lb on phone A
    }

    @Test func theBodyweightLogAndTheProfileWeightArriveToo() async throws {
        let (_, _, simA, simB, _) = try await twoPhones(weeks: 6)
        #expect(simB.user.weight == simA.user.weight)
        let a = simA.widget().fixed, b = simB.widget().fixed
        #expect(!a.bodyweightSeries.isEmpty && a.bodyweightSeries == b.bodyweightSeries)
        #expect(a.bodyweightDelta7d == b.bodyweightDelta7d)
    }

    @Test func trainingContinuesOnThePhoneThatRestoredTheAccountWithPRsAgainstTheSyncedHistory() async throws {
        let (a, b, simA, simB, _) = try await twoPhones(weeks: 5)
        simB.skipToDay(7 * 5 + 7)                                       // the Monday after the missed week
        simB.startSession(template: "Push Day")
        simB.logSets("Barbell Bench Press", 75, 5, count: 3)            // heavier than the 70 kg best from week 4
        let data = simB.finish()
        #expect(data.prCount == 1 && data.prDetails.first?.weightDelta == 5)
        await b.sync(); await a.sync()
        simA.goTo(simB.now)
        #expect(simA.historyRows().count == 16)
        #expect(simA.progress(of: "Barbell Bench Press").weightPR == 75)
    }
}
