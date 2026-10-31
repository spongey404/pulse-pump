import Testing
import Foundation
@testable import Ore

/// More › Analytics: e1RM per exercise over 30 days with its change on the 30 before, and weekly volume.
@MainActor
struct AnalyticsStatsTests {
    private static let bench = "Barbell Bench Press"

    @Test func e1RMUsesTheBestWorkingSetAndComparesWithThePreviousThirtyDays() throws {
        let sim = try UserSim()
        // An earlier session (45 days ago): 80 × 5 → e1RM 80 × (1 + 5/30).
        sim.skipToDay(1)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 5)
        sim.warmup(Self.bench, 200, 10)   // never counts
        _ = sim.finish()
        sim.skipToDay(46)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 90, 5)
        _ = sim.finish()

        let stats = AnalyticsStats(workouts: sim.historyRows(), now: sim.now, calendar: sim.calendar)
        let rows = stats.e1RMRows()
        let row = try #require(rows.first { $0.name == Self.bench })
        let now = ExerciseProgress.epley(weight: 90, reps: 5)
        let before = ExerciseProgress.epley(weight: 80, reps: 5)
        #expect(abs(row.e1rmKg - now) < 1e-9, "the warm-up's 200 kg is ignored")
        #expect(abs((row.change ?? 0) - (now / before - 1)) < 1e-9)
    }

    @Test func anExerciseWithNothingBeforeHasNoChange() throws {
        let sim = try UserSim()
        sim.skipToDay(1)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 70, 8)
        _ = sim.finish()
        let rows = AnalyticsStats(workouts: sim.historyRows(), now: sim.now, calendar: sim.calendar).e1RMRows()
        #expect(rows.first { $0.name == Self.bench }?.change == nil)
    }

    @Test func volumeIsTheWorkingVolumeOfTheWeek() throws {
        let sim = try UserSim()
        sim.skipToDay(1)
        sim.startSession(template: "Push Day")
        sim.log(Self.bench, 80, 8)
        sim.log(Self.bench, 80, 8)
        sim.warmup(Self.bench, 40, 10)
        _ = sim.finish()
        let stats = AnalyticsStats(workouts: sim.historyRows(), now: sim.now, calendar: sim.calendar)
        #expect(stats.volumeKg(weeksBack: 0) == 1280)
        #expect(stats.volumeKg(weeksBack: 1) == 0)
    }

    @Test func textHelpers() {
        #expect(AnalyticsView.changeText(0.042) == "▲ 4.2%")
        #expect(AnalyticsView.changeText(-0.01) == "▼ 1.0%")
        #expect(AnalyticsView.volumeText(0, unit: .kg) == "—")
        #expect(AnalyticsView.volumeText(12400, unit: .kg) == "12.4 T")
    }
}
