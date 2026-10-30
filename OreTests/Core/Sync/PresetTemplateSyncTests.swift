import Testing
import Foundation
import SwiftData
@testable import Ore

/// Preset templates are seeded on every install; sync must not multiply them.
@MainActor
struct PresetTemplateSyncTests {
    static func seeded(_ device: SyncDevice) {
        for e in ExerciseSeedService.allExercises { device.ctx.insert(e) }
        TemplateSeedService.seedIfNeeded(modelContext: device.ctx)
    }

    @Test func presetIdsAreStableAndDistinct() {
        let names = TemplateSeedService.allTemplates.map(\.name)
        let ids = names.map(TemplateSeedService.presetId(for:))
        #expect(ids == names.map(TemplateSeedService.presetId(for:)))
        #expect(Set(ids).count == Set(names).count)
    }

    @Test func twoInstallsSeedTheSameIds() throws {
        let a = try SyncDevice.make(uid: "alice", start: false), b = try SyncDevice.make(uid: "alice", start: false)
        Self.seeded(a); Self.seeded(b)
        let idsA = Set(try a.ctx.fetch(FetchDescriptor<WorkoutTemplate>()).map(\.id))
        let idsB = Set(try b.ctx.fetch(FetchDescriptor<WorkoutTemplate>()).map(\.id))
        #expect(idsA.count == 7 && idsA == idsB)
    }

    @Test func untouchedPresetsAreNotPushed() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        Self.seeded(a)
        #expect(SyncService.dirtyCount(a.ctx, bodyweight: a.bodyweight) == 0)
        await a.sync()
        #expect((remote.docs[.templates] ?? [:]).isEmpty)
    }

    @Test func aSecondDeviceDoesNotEndUpWithDuplicates() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote), b = try SyncDevice.make(remote: remote)
        Self.seeded(a); Self.seeded(b)
        let edited = try #require(try a.ctx.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.name == "Push Day" })
        edited.notes = "my notes"; edited.markUpdated()
        await a.sync(); await b.sync()
        let onB = try b.ctx.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(onB.count == 7)
        #expect(onB.first { $0.name == "Push Day" }?.notes == "my notes")
    }

    @Test func deletingAPresetOnOnePhoneRemovesItOnTheOther() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote), b = try SyncDevice.make(remote: remote)
        Self.seeded(a); Self.seeded(b)
        try #require(try a.ctx.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.name == "Leg Day" }).softDelete()
        await a.sync(); await b.sync()
        let live = try b.ctx.fetch(FetchDescriptor<WorkoutTemplate>()).filter(\.isLive)
        #expect(live.count == 6 && !live.contains { $0.name == "Leg Day" })
    }
}
