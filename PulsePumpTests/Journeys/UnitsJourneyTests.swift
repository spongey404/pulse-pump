import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// A pounds user and a kilograms user doing the same training end up with the same stored kilograms; switching the
/// unit changes only what is printed.
@MainActor
struct UnitsJourneyTests {
    private static let bench = "Barbell Bench Press"
    private static let lb = 0.45359237

    /// The loads (in lb) the pounds user typed each Monday, and the same loads as the kilograms the app stores for them.
    private static let weeksLb: [Double] = [135, 140, 145]
    private static func storedKg(_ lb: Double) -> Double { (lb * UnitsJourneyTests.lb * 10_000).rounded() / 10_000 }

    /// Three Mondays of 3 x 5 at the given loads, typed in the user's own unit.
    private func train(_ sim: UserSim, typed loads: [Double]) {
        for (w, load) in loads.enumerated() {
            sim.skipToDay(7 * w)
            sim.session(template: "Push Day") { s in s.logSets(Self.bench, load, 5, count: 3) }
        }
        sim.skipToDay(7 * loads.count - 1, hour: 20)
    }

    private func pair() throws -> (lbs: UserSim, kg: UserSim) {
        let lbs = try UserSim(unit: .lbs)
        train(lbs, typed: Self.weeksLb)
        let kg = try UserSim(unit: .kg)
        train(kg, typed: Self.weeksLb.map(Self.storedKg))
        return (lbs, kg)
    }

    @Test func bothUsersStoreTheSameKilogramsSetForSet() throws {
        let (lbs, kg) = try pair()
        let a = lbs.historyRows().reversed().flatMap { $0.exerciseLogs.flatMap { $0.sets.sorted { $0.order < $1.order } } }
        let b = kg.historyRows().reversed().flatMap { $0.exerciseLogs.flatMap { $0.sets.sorted { $0.order < $1.order } } }
        #expect(a.count == 9 && b.count == 9)
        for (x, y) in zip(a, b) { #expect(abs(x.weight - y.weight) < 1e-9) }
        #expect(abs(a[0].weight - 61.235) < 1e-9)                       // 135 lb = 61.23496 kg, stored to 4 decimals
    }

    @Test func theChartsAndStatCardsAreIdenticalInKilograms() throws {
        let (lbs, kg) = try pair()
        let pl = lbs.progress(of: Self.bench), pk = kg.progress(of: Self.bench)
        #expect(pl.trendPoints.map(\.maxWeight) == pk.trendPoints.map(\.maxWeight))
        #expect(pl.weightPR == pk.weightPR && pl.repsPR == pk.repsPR)
        #expect(abs(pl.estimated1RM - pk.estimated1RM) < 1e-9 && abs(pl.volumePR - pk.volumePR) < 1e-9)
        #expect(lbs.home().weekSets == kg.home().weekSets && lbs.streak() == kg.streak())
        #expect(lbs.widget().prs[Self.bench]?.weight == kg.widget().prs[Self.bench]?.weight)
    }

    @Test func eachUserSeesTheirOwnUnitOnTheSameNumbers() throws {
        let (lbs, kg) = try pair()
        let u = UnitPreference.lbs, k = UnitPreference.kg
        #expect(u.format(lbs.progress(of: Self.bench).weightPR) == "145 LB")
        #expect(k.format(kg.progress(of: Self.bench).weightPR) == "65.77 KG")        // 145 lb = 65.7709 kg
        #expect(u.number(lbs.progress(of: Self.bench).trendPoints[0].maxWeight) == "135")
        #expect(lbs.widget().weightUnit == .lbs && kg.widget().weightUnit == .kg)
    }

    @Test func theRecapVolumeIsTheSameWeightInEachUsersUnit() throws {
        let (lbs, kg) = try pair()
        let week = 2
        let vl = lbs.recap().volumeTonnes(lbs.recap().week), vk = kg.recap().volumeTonnes(kg.recap().week)
        // The last Monday: 3 x 5 x 145 lb. kg screen shows tonnes; lb screen shows thousands of lb.
        #expect(abs(vl - 3 * 5 * 145.0 / 1000) < 1e-3)
        #expect(abs(vk * 1000 - 3 * 5 * Self.storedKg(145)) < 1e-9)
        #expect(abs(vl - vk / Self.lb) < 1e-6)
        _ = week
    }

    @Test func completionPRsAndPostVolumesAreUnitFree() throws {
        let (lbs, kg) = try pair()
        #expect(lbs.completions.map(\.prCount) == kg.completions.map(\.prCount))
        #expect(lbs.completions.map(\.prCount) == [0, 1, 1])
        let a = try #require(lbs.postPayload(of: lbs.completions[2])), b = try #require(kg.postPayload(of: kg.completions[2]))
        #expect(abs(a.stats.volumeKg - b.stats.volumeKg) < 1e-9)
        #expect(a.exercises[0].sets.map(\.weight) == b.exercises[0].sets.map(\.weight))
    }

    @Test func exportIsAlwaysKilogramsWhateverTheUnit() throws {
        let (lbs, _) = try pair()
        let csv = try DataExportService.generateCSV(from: lbs.ctx)
        let rows = csv.split(separator: "\n").dropFirst()
        #expect(rows.count == 9)
        #expect(rows.allSatisfy { $0.contains(",kg,") })
        #expect(rows.contains { $0.contains(",61.235,kg,5,") })
    }

    @Test func switchingTheUnitMidJourneyChangesOnlyTheDisplay() throws {
        let sim = try UserSim(unit: .kg)
        for (w, load) in [100.0, 102.5].enumerated() {
            sim.skipToDay(7 * w)
            sim.session(template: "Push Day") { s in s.logSets(Self.bench, load, 5, count: 3) }
        }
        let before = sim.historyRows().flatMap { $0.exerciseLogs.flatMap(\.sets) }.map(\.weight).sorted()
        #expect(sim.user.unitPreference.number(100) == "100")

        sim.user.unitPreference = .lbs                                    // Settings > Units
        let after = sim.historyRows().flatMap { $0.exerciseLogs.flatMap(\.sets) }.map(\.weight).sorted()
        #expect(before == after)                                          // not one stored number moved
        #expect(sim.user.unitPreference.number(100) == "220.5")           // 100 kg = 220.46 lb, shown to 0.5 lb
        #expect(sim.user.unitPreference.format(sim.progress(of: Self.bench).weightPR) == "226 LB")
        #expect(sim.widget().weightUnit == .lbs)

        sim.user.unitPreference = .kg                                     // and back
        #expect(sim.historyRows().flatMap { $0.exerciseLogs.flatMap(\.sets) }.map(\.weight).sorted() == before)
        #expect(sim.user.unitPreference.number(102.5) == "102.5")
    }

    @Test func aSessionTypedInPoundsAfterTheSwitchComparesCorrectlyWithEarlierKilograms() throws {
        let sim = try UserSim(unit: .kg)
        sim.skipToDay(0)
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 100, 5, count: 3) }
        sim.skipToDay(7)
        sim.session(template: "Push Day") { s in s.logSets(Self.bench, 102.5, 5, count: 3) }
        sim.user.unitPreference = .lbs
        sim.skipToDay(14)
        sim.startSession(template: "Push Day")
        // The ghost is last time's 102.5 kg, shown in pounds.
        let ghost = try #require(sim.vm.ghostText(for: sim.exercise(Self.bench).id, setIndex: 0, modelContext: sim.ctx))
        #expect(ghost.weight == "102.5")
        #expect(sim.user.unitPreference.displayText(kgString: ghost.weight) == "225.97")
        sim.logSets(Self.bench, 230, 5, count: 3)                           // typed in lb = 104.3263 kg
        let data = sim.finish()
        #expect(data.prCount == 1)
        let delta = try #require(data.prDetails.first?.weightDelta)
        #expect(abs(delta - (230 * Self.lb - 102.5)) < 1e-3)
        #expect(sim.progress(of: Self.bench).trendPoints.map(\.maxWeight).prefix(2) == [100, 102.5])
        #expect(sim.user.unitPreference.number(sim.progress(of: Self.bench).weightPR) == "230")
    }

    @Test func aDecimalCommaInPoundsIsUnderstood() throws {
        let sim = try UserSim(unit: .lbs)
        sim.startSession(template: "Push Day")
        let (e, s) = sim.log(Self.bench, nil, 5)
        sim.vm.unlogSet(exerciseIndex: e, setIndex: s)
        sim.vm.exerciseEntries[e].sets[s].weight = sim.user.unitPreference.kgString(displayText: "62,5")
        sim.vm.logSet(exerciseIndex: e, setIndex: s, modelContext: sim.ctx)
        sim.finish()
        let stored = sim.historyRows()[0].exerciseLogs.flatMap(\.sets).first(where: { $0.weight > 0 })?.weight ?? 0
        #expect(abs(stored - 62.5 * Self.lb) < 1e-3)
        #expect(sim.user.unitPreference.number(stored) == "62.5")
    }

    @Test func bodyweightIsStoredInKilogramsAndShownInTheUsersUnit() throws {
        let sim = try UserSim(unit: .lbs, bodyweightKg: 81.6466)         // 180 lb
        #expect(sim.user.weight == 81.6466)
        #expect(sim.user.unitPreference.number(sim.user.weight) == "180")
        sim.setBodyweight(79.3786)                                       // 175 lb
        #expect(sim.widget().bodyweight == 79.3786)
        #expect(sim.user.unitPreference.number(sim.widget().bodyweight) == "175")
    }
}
