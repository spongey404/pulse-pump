import Foundation
import Testing
@testable import Ore

/// The shared calendar's rules (History fullscreen, Body modal) against a fixed fake: today is Thursday 5 Nov 2026, the first session
/// was Monday 28 Sep, and the plan is Push / Pull / Legs on Mon-Sat with Sunday off.
struct OreCalendarLogicTests {
    struct Fake: CalendarDataSource {
        let cal: Calendar
        let firstDate: Date
        var sessions: [String: [CalendarSession]]
        func sessions(on day: Date) -> [CalendarSession] { sessions[WorkoutCalendarData.key(day, cal)] ?? [] }
        func plan(on day: Date) -> CalendarPlanDay? {
            let wd = cal.component(.weekday, from: day)
            if wd == 1 { return CalendarPlanDay(name: "Rest", isRest: true) }
            return CalendarPlanDay(name: ["Push Day", "Pull Day", "Leg Day"][(wd - 2) % 3], isRest: false)
        }
    }

    static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; c.firstWeekday = 2; return c }()
    static func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))! }

    static func logic() -> OreCalendarLogic {
        var s: [String: [CalendarSession]] = [:]
        func add(_ date: Date, _ name: String, _ sets: Int) {
            s[WorkoutCalendarData.key(date, cal), default: []].append(CalendarSession(id: UUID(), date: date, name: name, sets: sets, seconds: 3660))
        }
        add(d(2026, 11, 2), "Push Day", 16); add(d(2026, 11, 3), "Pull Day", 17); add(d(2026, 11, 4), "Leg Day", 17)
        add(d(2026, 9, 28), "Push Day", 15)
        let fake = Fake(cal: cal, firstDate: d(2026, 9, 28), sessions: s)
        return OreCalendarLogic(source: fake, today: d(2026, 11, 5), calendar: cal)
    }

    @Test func monthNavigationStopsAtTheFirstMonthAndTheCurrentOne() {
        let l = Self.logic()
        let nov = Self.d(2026, 11, 1)
        #expect(!l.canGoForward(from: nov))
        #expect(l.canGoBack(from: nov))
        let sep = Self.d(2026, 9, 15)
        #expect(!l.canGoBack(from: sep))
        #expect(l.canGoForward(from: sep))
        #expect(l.title(of: nov) == "NOVEMBER 2026")
        #expect(l.shift(nov, by: 1) == l.monthStart(nov))               // can't go past the current month
        #expect(l.shift(sep, by: -1) == l.monthStart(sep))              // can't go before the first
        #expect(l.shift(nov, by: -1) == Self.d(2026, 10, 1, 0))
    }

    @Test func weekNumbersAreIsoAndEveryRowIsMondayFirst() {
        let l = Self.logic()
        let rows = l.rows(for: Self.d(2026, 11, 10), selection: .none)
        #expect(rows.map(\.number) == [44, 45, 46, 47, 48, 49])
        #expect(rows.allSatisfy { Self.cal.component(.weekday, from: $0.monday) == 2 })
        #expect(rows[0].tiles.prefix(6).allSatisfy { $0.state == .blank && $0.date == nil })   // other months' days are never shown
        #expect(rows[0].tiles[6].date.map { Self.cal.component(.day, from: $0) } == 1)
        #expect(rows.last?.tiles.dropFirst().allSatisfy { $0.state == .blank } == true)
    }

    @Test func tileStatesAndLabels() {
        let l = Self.logic()
        let rows = l.rows(for: Self.d(2026, 11, 10), selection: .day(Self.d(2026, 11, 3)))
        let week45 = rows[1].tiles          // Mon 2 … Sun 8
        #expect(week45[0].state == .trained && week45[0].label == "PUSH 16")
        #expect(week45[1].state == .selected && week45[1].label == "PULL 17")      // selected wins over trained
        #expect(week45[2].state == .trained && week45[2].label == "LEGS 17")
        #expect(week45[3].state == .today && week45[3].label == "TODAY")
        #expect(week45[4].state == .planned && week45[4].label == "PULL")
        #expect(week45[6].state == .rest && week45[6].label == "REST")
        let oct = l.rows(for: Self.d(2026, 10, 10), selection: .none)
        let pastRest = oct.flatMap(\.tiles).first { $0.date.map { Self.cal.component(.day, from: $0) } == 4 }       // Sunday 4 Oct
        #expect(pastRest?.state == .rest)
        let pastNoSession = oct.flatMap(\.tiles).first { $0.date.map { Self.cal.component(.day, from: $0) } == 6 }   // Tuesday 6 Oct
        #expect(pastNoSession?.state == .other && pastNoSession?.label == "")
    }

    @Test func shortNames() {
        #expect(OreCalendarLogic.shortName("Push Day") == "PUSH")
        #expect(OreCalendarLogic.shortName("Leg Day") == "LEGS")
        #expect(OreCalendarLogic.shortName("Upper Body A") == "UPPER")
        #expect(OreCalendarLogic.shortName("Full Body Workout") == "FULL")
        #expect(OreCalendarLogic.shortName("") == "WORKO" || OreCalendarLogic.shortName("") == "WORKOUT")
    }

    @Test func dayCards() {
        let l = Self.logic()
        let done = l.card(for: Self.d(2026, 11, 3))
        #expect(done.date == "TUE 3 NOV" && done.name == "PULL DAY" && done.meta == "17 SETS · 61:00" && done.showsChevron && done.session != nil)
        let today = l.card(for: Self.d(2026, 11, 5))
        #expect(today.name == "NO WORKOUT" && today.meta == "PUSH DAY IS UP NEXT" && !today.showsChevron)
        let planned = l.card(for: Self.d(2026, 11, 6))
        #expect(planned.name == "PLANNED · PULL DAY" && !planned.showsChevron)
        let rest = l.card(for: Self.d(2026, 11, 8))
        #expect(rest.name == "REST DAY")
        let none = l.card(for: Self.d(2026, 10, 6))
        #expect(none.name == "NO WORKOUT" && none.meta == "")
    }

    @Test func weekCardsDifferByScreen() {
        let l = Self.logic()
        let history = l.cards(forWeek: Self.d(2026, 11, 2))
        #expect(history.map(\.name) == ["PUSH DAY", "PULL DAY", "LEG DAY"])      // one card per session
        #expect(history.allSatisfy { $0.session != nil })
        let body = l.weekCard(forWeek: Self.d(2026, 11, 2))
        #expect(body.date == "WEEK 45" && body.name == "WHOLE WEEK" && body.meta == "3 SESSIONS · 50 SETS")
        let empty = l.cards(forWeek: Self.d(2026, 10, 5))
        #expect(empty.count == 1 && empty[0].name == "NO WORKOUTS")
    }

    @Test func onlyDaysFromTheFirstSessionToTheEndOfThisWeekCanBeTapped() {
        let l = Self.logic()
        #expect(!l.isSelectable(Self.d(2026, 9, 27)))
        #expect(l.isSelectable(Self.d(2026, 9, 28)))
        #expect(l.isSelectable(Self.d(2026, 11, 8)))
        #expect(!l.isSelectable(Self.d(2026, 11, 9)))
    }
}
