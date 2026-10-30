import CoreGraphics
import Foundation
import Testing
@testable import PulsePump

/// The numbers on the exercise detail page.
struct ExerciseDetailModelTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }()
    private func day(_ offset: Int) -> Date {   // offset days before 2026-10-28 noon UTC
        cal.date(byAdding: .day, value: -offset, to: Date(timeIntervalSince1970: 1_793_188_800))!
    }
    private var now: Date { day(0) }

    private func raw(_ ago: Int, _ sets: [(Double, Int)], name: String = "Push Day") -> ExerciseDetailModel.RawSession {
        .init(id: UUID(), date: day(ago), workoutName: name, sets: sets.map { (weightKg: $0.0, reps: $0.1) })
    }

    // MARK: Records

    @Test func newestSessionComesFirstAndTheCountIsEverySession() {
        let m = ExerciseDetailModel.make(raw: [raw(20, [(100, 5)]), raw(2, [(105, 4)]), raw(10, [(102.5, 5)])])
        #expect(m.sessionCount == 3)
        #expect(m.sessions.map(\.date) == [day(2), day(10), day(20)])
    }

    @Test func bestSetAndEstimatedOneRepMaxComeFromTheHighestEstimate() {
        let m = ExerciseDetailModel.make(raw: [raw(20, [(100, 5), (90, 8)]), raw(2, [(105, 4)])])
        // 100x5 = 116.7, 90x8 = 114, 105x4 = 119
        #expect(m.bestSet?.weightKg == 105 && m.bestSet?.reps == 4)
        #expect(abs((m.estimated1RMKg ?? 0) - 119) < 0.01)
    }

    @Test func lastSetIsTheHeaviestOfTheLatestSession() {
        let m = ExerciseDetailModel.make(raw: [raw(10, [(110, 3)]), raw(1, [(90, 8), (100, 5), (95, 6)])])
        #expect(m.lastSet?.weightKg == 100 && m.lastSet?.reps == 5)
    }

    @Test func noSessionsMeansNoRecords() {
        let m = ExerciseDetailModel.make(raw: [])
        #expect(m.sessionCount == 0)
        #expect(m.bestSet == nil && m.estimated1RMKg == nil && m.lastSet == nil)
        #expect(m.headline(.e1rm, range: .all, now: now, calendar: cal) == nil)
        #expect(m.series(.e1rm, range: .all, now: now, calendar: cal).isEmpty)
    }

    // MARK: PRs

    @Test func theFirstSessionIsABaselineNotAPR() {
        let m = ExerciseDetailModel.make(raw: [raw(10, [(100, 5), (105, 3)])])
        #expect(m.sessions[0].sets.allSatisfy { !$0.isPR })
    }

    @Test func onlyASessionsBestSetIsMarkedAndOnlyWhenItBeatsEarlierSessions() {
        let m = ExerciseDetailModel.make(raw: [
            raw(30, [(100, 5)]),
            raw(20, [(100, 5), (95, 5)]),            // no better than before
            raw(10, [(100, 5), (105, 4), (95, 6)]),  // 105x4 beats 100x5
        ])
        let newest = m.sessions[0].sets
        #expect(newest.map(\.isPR) == [false, true, false])
        #expect(m.sessions[1].sets.allSatisfy { !$0.isPR }, "matching your best is not a PR")
        #expect(m.sessions[2].sets.allSatisfy { !$0.isPR })
    }

    // MARK: Trend

    @Test func theMetricsReadTheRightThingFromASession() {
        let s = ExerciseSession(id: UUID(), date: day(1), workoutName: "x",
                                sets: [.init(weightKg: 100, reps: 5, isPR: false), .init(weightKg: 90, reps: 8, isPR: false)])
        #expect(ExerciseMetric.topSet.value(of: s) == 100)
        #expect(ExerciseMetric.volume.value(of: s) == 100 * 5 + 90 * 8)
        #expect(abs(ExerciseMetric.e1rm.value(of: s) - 116.6667) < 0.01)
    }

    @Test func aRangeKeepsOnlyTheSessionsInsideItOldestFirst() {
        let m = ExerciseDetailModel.make(raw: [raw(2, [(100, 5)]), raw(20, [(95, 5)]), raw(60, [(90, 5)]), raw(400, [(80, 5)])])
        func count(_ r: ExerciseRange) -> Int { m.series(.topSet, range: r, now: now, calendar: cal).count }
        #expect(count(.month) == 2)
        #expect(count(.threeMonths) == 3)
        #expect(count(.year) == 3)
        #expect(count(.all) == 4)
        let all = m.series(.topSet, range: .all, now: now, calendar: cal)
        #expect(all.map(\.value) == [80, 90, 95, 100], "oldest first")
    }

    @Test func sessionsWithNothingToPlotAreSkipped() {
        let m = ExerciseDetailModel.make(raw: [raw(2, [(0, 10)]), raw(5, [(60, 8)])])
        #expect(m.series(.topSet, range: .all, now: now, calendar: cal).count == 1)
    }

    @Test func theHeadlineIsTheLatestValueAndTheChangeSinceTheFirstPointInTheRange() throws {
        let m = ExerciseDetailModel.make(raw: [raw(60, [(80, 5)]), raw(20, [(90, 5)]), raw(2, [(100, 5)])])
        let h = try #require(m.headline(.topSet, range: .threeMonths, now: now, calendar: cal))
        #expect(h.value == 100)
        #expect(abs((h.deltaPercent ?? 0) - 25) < 0.001, "80 → 100 is +25%")
        #expect(h.since == day(60))

        let month = try #require(m.headline(.topSet, range: .month, now: now, calendar: cal))
        #expect(abs((month.deltaPercent ?? 0) - 11.111) < 0.01, "within a month it is measured from 90")
    }

    @Test func aSinglePointHasAValueButNoChange() throws {
        let m = ExerciseDetailModel.make(raw: [raw(2, [(100, 5)])])
        let h = try #require(m.headline(.topSet, range: .all, now: now, calendar: cal))
        #expect(h.value == 100 && h.deltaPercent == nil && h.since == nil)
    }

    @Test func aFallIsANegativeChange() throws {
        let m = ExerciseDetailModel.make(raw: [raw(30, [(100, 5)]), raw(2, [(90, 5)])])
        #expect(try #require(m.headline(.topSet, range: .all, now: now, calendar: cal).flatMap(\.deltaPercent)) < 0)
    }

    @Test func everyRangeAndMetricHasALabelForItsChip() {
        #expect(ExerciseRange.allCases.map(\.label) == ["1M", "3M", "6M", "1Y", "ALL"])
        #expect(ExerciseMetric.allCases.map(\.selectorLabel) == ["E1RM", "TOP SET", "VOLUME"])
        #expect(ExerciseMetric.allCases.map(\.chartLabel) == ["ESTIMATED 1RM", "TOP SET WEIGHT", "SESSION VOLUME"])
    }

    // MARK: Chart layout

    @Test func theChartPadsTheRangeSoTheLineNeverTouchesTheEdges() {
        let l = TrendChartLayout(values: [100, 110, 120])
        #expect(l.minValue < 100 && l.maxValue > 120)
        #expect(abs((100 - l.minValue) - (l.maxValue - 120)) < 0.0001, "evenly padded")
        #expect(l.points.map(\.x) == [0, 0.5, 1], "spread evenly by position")
        #expect(l.points[0].y > l.points[2].y, "a higher value is higher up (smaller y)")
        #expect(l.points.allSatisfy { $0.y > 0 && $0.y < 1 })
    }

    @Test func aFlatSeriesStillDrawsInTheMiddleWithoutDividingByZero() {
        let l = TrendChartLayout(values: [100, 100, 100])
        #expect(l.points.allSatisfy { abs($0.y - 0.5) < 0.0001 })
        #expect(l.maxValue > l.minValue)
    }

    @Test func oneValueSitsAtTheRightEndAndNoValuesDrawNothing() {
        #expect(TrendChartLayout(values: [90]).points.first?.x == 1)
        #expect(TrendChartLayout(values: []).points.isEmpty)
    }
}
