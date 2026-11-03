import Testing
import Foundation
import SwiftData
@testable import Ore

/// The ~90-workout dev dataset pushed from one phone and restored on an empty one.
@MainActor
struct SyncDatasetTests {
    private static var now: Date {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 7; c.hour = 20
        return Calendar(identifier: .iso8601).date(from: c)!
    }

    private static func config() -> DevDataConfig {
        var c = DevDataConfig()
        c.scenario = .busy; c.seed = 42; c.weeks = 20; c.reset = true; c.now = now
        c.calendar = Calendar(identifier: .iso8601)
        return c
    }

    private struct Totals: Equatable {
        var workouts = 0, logs = 0, sets = 0, workingSets = 0, templates = 0, equipment = 0
        var volume = 0.0, duration = 0.0, calories = 0.0
        var names: [String] = []
    }

    private func totals(_ d: SyncDevice) -> Totals {
        let ws = d.fetch(Workout.self).filter(\.isHistory)
        var t = Totals()
        t.workouts = ws.count
        t.logs = ws.flatMap(\.exerciseLogs).count
        t.sets = ws.flatMap(\.exerciseLogs).flatMap(\.sets).count
        t.workingSets = ws.reduce(0) { $0 + $1.workingSetCount }
        t.volume = (ws.reduce(0) { $0 + $1.workingVolume } * 1000).rounded() / 1000
        t.duration = ws.reduce(0) { $0 + $1.duration }
        t.calories = ws.reduce(0) { $0 + $1.calorieBurnEstimate }
        t.templates = d.fetch(WorkoutTemplate.self).count
        t.equipment = d.fetch(EquipmentProfile.self).count
        t.names = ws.flatMap(\.exerciseLogs).compactMap { $0.exercise?.name }.sorted()
        return t
    }

    @Test func ninetyWorkoutHistoryPushesInBatchesAndRestoresIdenticallyOnANewPhone() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        let summary = DevDataService.run(Self.config(), modelContext: a.ctx)
        #expect(summary.workouts >= 70)
        // DevData writes the App Group log; mirror it into this phone's private store.
        if let data = OreWidgetStore.defaults?.data(forKey: BodyweightLog.key) { a.bodyweight.set(data, forKey: BodyweightLog.key) }
        let aTotals = totals(a)
        #expect(aTotals.workouts == summary.workouts && aTotals.sets == summary.sets)

        let clock = ContinuousClock()
        let pushTime = await clock.measure { await a.sync() }
        #expect(pushTime < .seconds(20))
        #expect(remote.count(.workouts) == summary.workouts && remote.count(.templates) == 3)
        #expect(remote.batchSizes.allSatisfy { $0 <= 400 } && remote.batchSizes.count <= 3)   // batched, not per document
        #expect(a.service.pendingCount == 0)
        let bodyweightDays = BodyweightLog.load(defaults: a.bodyweight).count
        #expect(remote.count(.bodyweight) == bodyweightDays)

        // New phone: empty store, its own freshly seeded catalogue (different exercise UUIDs).
        let b = try SyncDevice.make(remote: remote)
        UserDefaults.standard.removeObject(forKey: "exerciseSeedVersion")
        ExerciseSeedService.seedIfNeeded(modelContext: b.ctx)
        #expect(b.service.isInitialSyncComplete == false)
        let pullTime = await clock.measure { await b.sync() }
        #expect(pullTime < .seconds(20))
        #expect(b.service.isInitialSyncComplete && b.service.initialSyncProgress == 1)

        let bTotals = totals(b)
        #expect(bTotals == aTotals)                                     // counts, volume, duration, calories, exercise names
        #expect(BodyweightLog.load(defaults: b.bodyweight).map(\.kg) == BodyweightLog.load(defaults: a.bodyweight).map(\.kg))
        let au = try #require(a.fetch(User.self).first), bu = try #require(b.fetch(User.self).first)
        #expect(bu.name == au.name && bu.weight == au.weight && bu.unitPreference == au.unitPreference)
        #expect(bu.selectedSplit?.days.count == au.selectedSplit?.days.count && bu.liveEquipmentProfiles.count == 2)
        // Every restored log points at a real catalogue exercise on this phone (linked by name, no placeholders).
        #expect(b.fetch(Workout.self).flatMap(\.exerciseLogs).allSatisfy { $0.exercise != nil && $0.exercise?.isCustom == false })
        // Restored data is clean: a further sync sends nothing.
        let writes = remote.writeCount
        await b.sync()
        #expect(remote.writeCount == writes)
    }

    @Test func editingOnTheSecondPhoneComesBackToTheFirst() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        var cfg = Self.config(); cfg.weeks = 4
        _ = DevDataService.run(cfg, modelContext: a.ctx)
        await a.sync()
        let b = try SyncDevice.make(remote: remote)
        UserDefaults.standard.removeObject(forKey: "exerciseSeedVersion")
        ExerciseSeedService.seedIfNeeded(modelContext: b.ctx)
        await b.sync()

        let target = try #require(b.fetch(Workout.self).filter(\.isHistory).first)
        b.ctx.softDelete(target)
        let before = totals(a).workouts
        await b.sync(); await a.sync()
        #expect(totals(a).workouts == before - 1)
        #expect(totals(a) == totals(b))
    }
}
