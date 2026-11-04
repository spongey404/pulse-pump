import Foundation
import Testing
@testable import Ore

@MainActor
struct BodyPageStatsTests {
    private let j = MarcusJourney.shared
    private var sim: UserSim { j.sim }

    private func atDay(_ day: Int, hour: Int = 20, _ body: () -> Void) {
        let saved = sim.now
        sim.skipToDay(day, hour: hour)
        body()
        sim.goTo(saved)
    }

    private func stats(week: Int = 0, day: Int? = nil) -> BodyPageStats {
        BodyPageStats(workouts: sim.historyRows(), weekOffset: week, dayIndex: day, now: sim.now, calendar: sim.calendar)
    }

    @Test func theTreeIsTheSixGroupsAndTwentyMusclesOfTheArtwork() {
        #expect(BodyMuscleTree.groups.map(\.name) == ["Chest", "Back", "Shoulders", "Arms", "Core", "Legs"])
        #expect(BodyMuscleTree.muscles.count == 20)
        #expect(BodyMuscleTree.groups.first { $0.name == "Arms" }?.muscles.first { $0.name == "Forearm" }?.heads.count == 3)
        // Every id the tree lights is an id the artwork has.
        let artwork = BodyMapLevels.frontIds.union(BodyMapLevels.backIds)
        #expect(BodyMuscleTree.allIds.isSubset(of: artwork))
    }

    @Test func aWeeksWorkoutSetsMatchTheScreensAndTheirPerMuscleSumIsNotWhatTheHeadlineShows() {
        atDay(7 * 3 + 6) {
            let s = stats()
            #expect(s.workoutSets == j.checks[3].bodyTotalSets)
            #expect(s.daySets.reduce(0, +) == s.weekSets)
            #expect(s.groupsHit >= 1 && s.groupsHit <= 6)
            #expect(s.musclesHit >= s.groupsHit)
        }
    }

    @Test func aDayIsMeasuredAgainstHalfTheWeeklyTarget() {
        atDay(7 * 3 + 6) {
            #expect(stats().target(10) == 10)
            #expect(stats(day: 0).target(10) == 5)
        }
    }

    @Test func chestSetsAreTheBenchSetsOfThatWeek() {
        atDay(7 * 3 + 6) {
            let chest = stats().tally.group["chest"] ?? 0
            let bench = j.ledger(week: 3, exercise: "Barbell Bench Press").count
            #expect(chest == bench)
            #expect(stats(day: 0).tally.group["chest"] == bench)         // Monday is the push day
            #expect((stats(day: 2).tally.group["chest"] ?? 0) == 0)      // Wednesday is the pull day
        }
    }

    @Test func weekNavigationStopsAtTheFirstLoggedWeekAndTheCurrentOne() {
        atDay(7 * 4 + 6) {
            let s = stats()
            #expect(!s.canGoForward)
            #expect(s.oldestOffset == -4)
            #expect(stats(week: -4).canGoBack == false)
            #expect(stats(week: -3).canGoBack)
            #expect(stats(week: -1).relativeLabel == "LAST WEEK")
            #expect(stats(week: -3).relativeLabel == "3 WEEKS AGO")
            #expect(s.relativeLabel == "THIS WEEK")
        }
    }

    @Test func theEmptyDayNotesSayWhatIsGoingOn() {
        atDay(7 * 5 + 2) {      // the missed week, Wednesday evening
            #expect(stats(day: 2).dayNote == "Nothing logged yet.")
            #expect(stats(day: 0).dayNote == "Nothing logged.")
        }
        atDay(7 * 3 + 6) { #expect(stats(day: 0).dayNote == nil) }
    }

    @Test func freshnessFadesFromOneToAQuarterThenGoesGrey() {
        #expect(BodyPageStats.freshness(hours: 0) == 1.0)
        #expect(abs((BodyPageStats.freshness(hours: 48) ?? 0) - 0.25) < 1e-9)
        #expect(abs((BodyPageStats.freshness(hours: 24) ?? 0) - 0.625) < 1e-9)
        #expect(BodyPageStats.freshness(hours: 48.5) == nil)
        #expect(BodyPageStats.freshness(hours: nil) == nil)
    }

    @Test func theAgoTextSwitchesToDaysAfterSeventyTwoHours() {
        #expect(BodyPageStats.agoText(hours: 22) == "22H AGO")
        #expect(BodyPageStats.agoText(hours: 71.9) == "71H AGO")
        #expect(BodyPageStats.agoText(hours: 72) == "3D AGO")
        #expect(BodyPageStats.agoText(hours: 100) == "4D AGO")
        #expect(BodyPageStats.agoText(hours: nil) == "—")
    }

    @Test func theWindowIsOneConfigValue() {
        let saved = BodyPageConfig.windowHours
        defer { BodyPageConfig.windowHours = saved }
        BodyPageConfig.windowHours = 24
        #expect(BodyPageStats.freshness(hours: 25) == nil)
        #expect(abs((BodyPageStats.freshness(hours: 24) ?? 0) - 0.25) < 1e-9)
    }

    @Test func rightAfterTheLegSessionTheLegsAreInTheWindowAndTwoDaysLaterTheyAreDue() {
        atDay(7 * 3 + 4, hour: 20) {       // Friday 20:00, an hour after the legs session ends
            let s = stats()
            #expect(s.inWindowCount > 0)
            #expect(s.dueCount == 0 || s.dueCount < s.muscleCount)
            let quad = BodyMuscleTree.muscles.first { $0.id == "quad" }!
            #expect(s.freshness(of: quad, last: s.lastTrainedById).inWindow)
        }
        atDay(7 * 3 + 6, hour: 20) {       // Sunday 20:00, about 49 hours on
            let s = stats()
            let quad = BodyMuscleTree.muscles.first { $0.id == "quad" }!
            #expect(s.freshness(of: quad, last: s.lastTrainedById).isDue)
            #expect(s.dueCount > 0)
        }
    }

    @Test func theTickerHasMuscleSetChangesWithoutZerosAndInWindowOnlyForMembers() {
        atDay(7 * 6 + 6) {       // week 7 follows the missed week: every muscle changed
            let s = stats()
            let free = s.tickerItems(member: false), member = s.tickerItems(member: true)
            #expect(!free.isEmpty)
            #expect(free.allSatisfy { !$0.value.hasPrefix("0 ") })
            #expect(free.allSatisfy { $0.label != "IN WINDOW" })
            let groups = Set(BodyMuscleTree.groups.map { $0.name.uppercased() })
            #expect(free.allSatisfy { groups.contains($0.label) }, "the ticker names muscle groups, not muscles")
            #expect(free.count <= 6 && member.count <= 6, "at most six items")
            #expect(member.last?.label == "IN WINDOW")
            #expect(member.last?.value == "\(s.inWindowCount)/20")
        }
        atDay(7 * 7 + 6) {       // an identical week to the one before: nothing changed, so nothing is listed
            #expect(stats().tickerItems(member: false).isEmpty)
        }
    }

    /// Early in the week the comparison is with the same point of last week, so a week that has barely started isn't all down arrows.
    @Test func theTickerComparesWithTheSamePointOfLastWeek() {
        atDay(7 * 7, hour: 7) {          // Monday 07:00 of week 8: nothing trained yet, and nothing had been trained by then last week either
            #expect(stats().groupChanges.isEmpty)
            #expect(stats().tickerItems(member: false).isEmpty)
        }
    }

    @Test func aCalendarJumpLandsOnTheRightWeekAndDay() {
        atDay(7 * 6 + 6) {
            let s = stats()
            let t = s.target(for: sim.day(7 * 3 + 2))       // week 4's Wednesday
            #expect(t.weekOffset == -3 && t.dayIndex == 2)
            let u = s.target(for: sim.day(7 * 6))            // this week's Monday
            #expect(u.weekOffset == 0 && u.dayIndex == 0)
        }
    }

    @Test func aFocusedBackOnlyMuscleSwitchesTheMainViewToTheBack() {
        #expect(BodyMapTabView.autoSide(for: ["lats"]) == .back)
        #expect(BodyMapTabView.autoSide(for: ["abs"]) == .front)
        #expect(BodyMapTabView.autoSide(for: ["calves"]) == nil)          // both sides
        #expect(BodyMapTabView.autoSide(for: ["lats", "chest"]) == nil)   // mixed: leave the view alone
        #expect(BodyMapTabView.autoSide(for: []) == nil)
    }
}
