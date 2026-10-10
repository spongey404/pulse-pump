import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// Two simulated phones on one account, last-write-wins by `updatedAt`, through the real Firestore emulator.
@Suite("Sync conflicts between two phones against the emulator", .emulator, .serialized)
@MainActor
struct SyncConflictEmulatorTests {
    /// Both phones hold the same synced workout.
    @MainActor private struct Pair {
        let account: TestAccount
        let a: SyncDevice
        let b: SyncDevice
        let workoutId: UUID
        var key: String { SyncMapper.idString(workoutId) }

        func workout(on phone: SyncDevice) throws -> Workout {
            try #require(phone.fetch(Workout.self).first { $0.id == workoutId })
        }
        func remoteNotes() async throws -> String? {
            try await account.store.fetchDoc(.workouts, id: key)?.fields["notes"] as? String
        }
    }

    private static func pair(_ world: EmulatorWorld) async throws -> Pair {
        let account = try await world.account("ada")
        let a = try SyncDevice.phone(for: account)
        a.user()
        let workout = a.workout(exercise: a.exercise(), notes: "base")
        try a.ctx.save()
        await a.sync()
        let b = try SyncDevice.phone(for: account)
        await b.sync()
        #expect(b.count(Workout.self) == 1)
        return Pair(account: account, a: a, b: b, workoutId: workout.id)
    }

    private func tick() async { try? await Task.sleep(for: .milliseconds(40)) }

    @Test func aNewerEditOnPhoneAReachesPhoneB() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            try p.a.edit(try p.workout(on: p.a)) { $0.notes = "edited on A" }
            await p.a.sync()
            await p.b.sync()
            #expect(try p.workout(on: p.b).notes == "edited on A")
        }
    }

    @Test func aNewerEditOnPhoneBReachesPhoneAInTheOtherDirection() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            try p.b.edit(try p.workout(on: p.b)) { $0.notes = "edited on B" }
            await p.b.sync()
            await p.a.sync()
            #expect(try p.workout(on: p.a).notes == "edited on B")
            #expect(try await p.remoteNotes() == "edited on B")
        }
    }

    @Test func anOlderOfflineEditLosesToANewerRemoteEdit() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            try p.b.edit(try p.workout(on: p.b)) { $0.notes = "B edited first, offline" }
            await tick()
            try p.a.edit(try p.workout(on: p.a)) { $0.notes = "A edited later" }
            await p.a.sync()

            await p.b.sync()   // pull sees a strictly newer remote, so B's older edit must not be pushed over it
            #expect(try p.workout(on: p.b).notes == "A edited later")
            #expect(try await p.remoteNotes() == "A edited later")
        }
    }

    @Test func aNewerLocalEditBeatsAnOlderRemoteEdit() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            try p.a.edit(try p.workout(on: p.a)) { $0.notes = "A edited first" }
            await p.a.sync()
            await tick()
            try p.b.edit(try p.workout(on: p.b)) { $0.notes = "B edited last" }

            await p.b.sync()
            #expect(try await p.remoteNotes() == "B edited last")
            await p.a.sync()
            #expect(try p.workout(on: p.a).notes == "B edited last")
        }
    }

    @Test func aSoftDeleteOnOnePhoneRemovesTheWorkoutFromTheOther() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            try p.a.edit(try p.workout(on: p.a)) { $0.softDelete() }
            await p.a.sync()

            let remote = try #require(try await p.account.store.fetchDoc(.workouts, id: p.key))
            #expect(remote.isDeleted, "the tombstone is kept remotely so the deletion can propagate")
            #expect(remote.fields["exercises"] != nil, "a tombstone still satisfies the rules' required fields")

            await p.b.sync()
            let onB = try p.workout(on: p.b)
            #expect(onB.deletedAt != nil && !onB.isHistory)
            #expect(HistoryTotals(p.b).workouts == 0)
        }
    }

    @Test func aSoftDeletedWorkoutIsNotResurrectedOnANewPhone() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            try p.a.edit(try p.workout(on: p.a)) { $0.softDelete() }
            await p.a.sync()

            let fresh = try SyncDevice.phone(for: p.account)
            await fresh.sync()
            #expect(fresh.fetch(Workout.self).filter(\.isHistory).isEmpty)
        }
    }

    @Test func aTemplateEditedOnTwoPhonesKeepsTheLaterName() async throws {
        try await Emulator.isolated { world in
            let account = try await world.account("ada")
            let a = try SyncDevice.phone(for: account)
            a.user()
            let template = a.template("Push Day", exercise: a.exercise())
            try a.ctx.save()
            await a.sync()
            let b = try SyncDevice.phone(for: account)
            await b.sync()

            template.name = "Push Day (A)"; template.markUpdated(); try a.ctx.save()
            await tick()
            let onB = try #require(b.fetch(WorkoutTemplate.self).first)
            onB.name = "Push Day (B)"; onB.markUpdated(); try b.ctx.save()

            await a.sync()      // pushes A's name
            await b.sync()      // B is newer: wins
            await a.sync()
            #expect(try #require(a.fetch(WorkoutTemplate.self).first).name == "Push Day (B)")
            #expect(try await account.store.fetchDoc(.templates, id: SyncMapper.idString(template.id))?.fields["name"] as? String == "Push Day (B)")
        }
    }

    @Test func aBodyweightEntryLoggedOnOnePhoneAppearsOnTheOther() async throws {
        try await Emulator.isolated { world in
            let account = try await world.account("ada")
            let a = try SyncDevice.phone(for: account)
            let b = try SyncDevice.phone(for: account)
            await b.sync()
            BodyweightLog.record(kg: 82.5, defaults: a.bodyweight)
            await a.sync()
            await b.sync()
            let entries = BodyweightLog.load(defaults: b.bodyweight)
            #expect(entries.count == 1 && entries.first?.kg == 82.5)
        }
    }

    @Test func twoPhonesAddingDifferentWorkoutsEndUpWithBoth() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            p.a.workout(daysAgo: 2, exercise: p.a.exercise("Overhead Press"))
            p.b.workout(daysAgo: 3, exercise: p.b.exercise("Deadlift"))
            try p.a.ctx.save(); try p.b.ctx.save()
            await p.a.sync()
            await p.b.sync()
            await p.a.sync()
            #expect(p.a.fetch(Workout.self).filter(\.isHistory).count == 3)
            #expect(p.b.fetch(Workout.self).filter(\.isHistory).count == 3)
            #expect(try await p.account.store.allDocs(.workouts).count == 3)
        }
    }

    @Test func twoConsecutiveEditsOnOnePhoneEndUpOnTheOtherPhoneAsTheLastOne() async throws {
        try await Emulator.isolated { world in
            let p = try await Self.pair(world)
            try p.a.edit(try p.workout(on: p.a)) { $0.notes = "first" }
            await p.a.sync()
            try p.a.edit(try p.workout(on: p.a)) { $0.notes = "second" }
            await p.a.sync()
            await p.b.sync()
            #expect(try p.workout(on: p.b).notes == "second")
        }
    }
}
