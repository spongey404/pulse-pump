import Testing
import Foundation
import SwiftData
@testable import Ore

/// "Marcus": a 16-week, 3-days-a-week lifter (Mon Push, Wed Pull, Fri Legs) built once and read by many tests.
///
/// Weeks (0-based, Monday-first): 0-4 progress by 2.5 kg a week, 5 missed (illness), 6 repeats week 4's weights,
/// 7 new weights, 8 deload (-20 kg), 9 same weights as 7 with one extra rep on the first set, 10-11 progress then
/// repeat, 12-14 a three-week holiday, 15 comes back 10 kg lighter than week 11.
struct MarcusLift {
    let name: String
    let base: Double
    let sets: Int
    let warmup: Bool
}

enum MarcusWeek {
    case train(level: Int, offset: Double = 0, repBump: Bool = false)
    case off
}

@MainActor
final class MarcusJourney {
    struct SessionRecord {
        let week: Int
        let template: String
        let day: Date
        let data: WorkoutCompletionData
        let workoutId: UUID
    }

    struct WeekCheck {
        let week: Int
        let trained: Bool
        // Read at Sunday 20:00 of the week, from the screens.
        let historyCount: Int
        let streak: Int
        let homeWeekSets: Int
        let homeBars: [Int]
        let recapSessions: Int
        let recapSets: Int
        let recapVolumeT: Double
        let bodyTotalSets: Int
        let bodyVS: BodyMapStats.VSInfo
        let widgetSetsThisWeek: Int
        let widgetStreak: Int
        let widgetVolumeT: Double
    }

    static let push = [MarcusLift(name: "Barbell Bench Press", base: 60, sets: 3, warmup: true),
                       MarcusLift(name: "Overhead Press", base: 35, sets: 2, warmup: false)]
    static let pull = [MarcusLift(name: "Barbell Row", base: 60, sets: 3, warmup: true),
                       MarcusLift(name: "Barbell Curl", base: 25, sets: 2, warmup: false)]
    static let legs = [MarcusLift(name: "Barbell Squat", base: 80, sets: 3, warmup: true),
                       MarcusLift(name: "Leg Press", base: 120, sets: 2, warmup: false)]
    static let days: [(template: String, offset: Int, lifts: [MarcusLift])] = [
        ("Push Day", 0, push), ("Pull Day", 2, pull), ("Leg Day", 4, legs),
    ]
    static let plan: [MarcusWeek] = [
        .train(level: 0), .train(level: 1), .train(level: 2), .train(level: 3), .train(level: 4),
        .off,
        .train(level: 4), .train(level: 5), .train(level: 5, offset: -20), .train(level: 5, repBump: true),
        .train(level: 6), .train(level: 6),
        .off, .off, .off,
        .train(level: 6, offset: -10),
    ]
    /// Scripted PRs per session (each session has two exercises) by week; hand-derived from the plan above.
    static let expectedPRsPerSession: [Int: Int] = [0: 0, 1: 2, 2: 2, 3: 2, 4: 2, 6: 0, 7: 2, 8: 0, 9: 2, 10: 2, 11: 0, 15: 0]
    /// Exercises whose estimated 1RM beat the previous best, per session. Week 10 is the instructive one: Squat and Leg Press
    /// went up 2.5 kg but week 9's extra rep gave them a higher e1RM (92.5 x 6 = 111.0 vs 95 x 5 = 110.8), so Legs improved nothing.
    static func expectedImproved(week: Int, template: String) -> Int {
        if week == 10 && template == "Leg Day" { return 0 }
        return [0: 0, 1: 2, 2: 2, 3: 2, 4: 2, 6: 0, 7: 2, 8: 0, 9: 2, 10: 2, 11: 0, 15: 0][week]!
    }

    static func weight(_ lift: MarcusLift, _ level: Int, _ offset: Double) -> Double { lift.base + 2.5 * Double(level) + offset }
    static func warmupWeight(_ working: Double) -> Double { (working * 0.6 / 2.5).rounded() * 2.5 }
    static func reps(set i: Int, bump: Bool) -> Int { i == 0 && bump ? 6 : 5 }

    let sim: UserSim
    private(set) var sessions: [SessionRecord] = []
    private(set) var checks: [WeekCheck] = []

    /// Built once for the whole test run.
    static let shared: MarcusJourney = try! MarcusJourney()

    /// Trains the first `weeks` weeks of the plan on `sim` (a fresh sim by default).
    init(sim existing: UserSim? = nil, weeks: Int = MarcusJourney.plan.count) throws {
        sim = try existing ?? UserSim()
        sim.setBodyweight(80)
        for (w, kind) in Self.plan.prefix(weeks).enumerated() {
            if case let .train(level, offset, bump) = kind {
                for d in Self.days {
                    sim.skipToDay(7 * w + d.offset, hour: 18)
                    sim.startSession(template: d.template)
                    for lift in d.lifts {
                        let working = Self.weight(lift, level, offset)
                        if lift.warmup { sim.warmup(lift.name, Self.warmupWeight(working), 8) }
                        for i in 0..<lift.sets { sim.log(lift.name, working, Self.reps(set: i, bump: bump), rir: 2 - min(i, 2)) }
                    }
                    let data = sim.finish(minutes: 55 + (w % 3) * 5)
                    sessions.append(SessionRecord(week: w, template: d.template, day: sim.day(7 * w + d.offset),
                                                  data: data, workoutId: sim.finished.last!.id))
                }
            }
            // The weight on the scale drifts: 80 -> 81 after week 4, 79.5 after week 10.
            if w == 4 { sim.skipToDay(7 * w + 5, hour: 8); sim.setBodyweight(81) }
            if w == 10 { sim.skipToDay(7 * w + 5, hour: 8); sim.setBodyweight(79.5) }
            sim.skipToDay(7 * w + 6, hour: 20)
            var kind0 = false
            if case .train = kind { kind0 = true }
            let home = sim.home(), recap = sim.recap(), body = sim.body(), snap = sim.widget()
            checks.append(WeekCheck(week: w, trained: kind0, historyCount: sim.historyRows().count, streak: sim.streak(),
                                    homeWeekSets: home.weekSets, homeBars: home.weekDayBars,
                                    recapSessions: recap.week.count, recapSets: recap.setCount(recap.week),
                                    recapVolumeT: recap.volumeTonnes(recap.week), bodyTotalSets: body.selectedTotalSets,
                                    bodyVS: body.vsInfo, widgetSetsThisWeek: snap.fixed.setsThisWeek, widgetStreak: snap.streak,
                                    widgetVolumeT: snap.fixed.volumeTonnes))
        }
    }

    // MARK: Independent oracles built from the ledger

    func ledger(week: Int, exercise: String? = nil, workingOnly: Bool = true) -> [LoggedSet] {
        let start = sim.day(7 * week), end = sim.day(7 * week + 7)
        return sim.ledger.filter { $0.day >= start && $0.day < end && (!workingOnly || $0.isWorking) && (exercise == nil || $0.exercise == exercise) }
    }

    func trainingDays(through week: Int) -> [Date] {
        let end = sim.day(7 * week + 7)
        return sim.ledger.filter { $0.day < end }.map(\.day)
    }

    var trainedWeeks: [Int] { checks.filter(\.trained).map(\.week) }
}
