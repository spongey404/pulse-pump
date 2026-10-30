import Testing
import Foundation
import SwiftData
@testable import Ore

/// Push / pull / conflicts / deletes / failures against the in-memory cloud.
@MainActor
struct SyncEngineTests {
    // MARK: Basics

    @Test func pushSendsDirtyRecordsAndMarksThemSynced() async throws {
        let d = try SyncDevice.make()
        let bench = d.exercise()
        let u = d.user()
        let w = d.workout(exercise: bench, user: u)
        let t = d.template("Push", exercise: bench)
        #expect(w.isDirty && t.isDirty && u.isDirty)

        await d.sync()
        #expect(d.remote.count(.workouts) == 1 && d.remote.count(.templates) == 1)
        #expect(d.remote.doc(.profile, id: "alice")?["name"] as? String == "Ada")
        #expect(!w.isDirty && !t.isDirty && !u.isDirty)
        #expect(w.syncedAt?.syncMs == w.updatedAt.syncMs)
        #expect(d.service.lastSyncedAt != nil && d.service.pendingCount == 0)
    }

    @Test func secondPushWritesNothing() async throws {
        let d = try SyncDevice.make()
        d.workout(exercise: d.exercise())
        await d.sync()
        let writes = d.remote.writeCount
        await d.sync()
        await d.sync()
        #expect(d.remote.writeCount == writes)                          // idempotent: nothing dirty, nothing resent
    }

    @Test func draftsNeverSync() async throws {
        let d = try SyncDevice.make()
        let bench = d.exercise()
        d.workout(exercise: bench)
        d.workout(exercise: bench, draft: true)
        await d.sync()
        #expect(d.remote.count(.workouts) == 1)
        #expect(d.service.pendingCount == 0)
    }

    @Test func pushSplitsIntoBatchesOfAtMost400() async throws {
        let d = try SyncDevice.make()
        for i in 0..<850 { d.ctx.insert(WorkoutTemplate(name: "T\(i)")) }
        await d.sync()
        #expect(d.remote.count(.templates) == 850)
        #expect(d.remote.batchSizes == [400, 400, 50])
        #expect(d.remote.batchSizes.allSatisfy { $0 <= RemoteLimits.maxBatch })
    }

    @Test func pullPagesAcrossManyPages() async throws {
        let remote = InMemoryRemoteStore()
        let src = try SyncDevice.make(remote: remote)
        for i in 0..<130 { src.ctx.insert(WorkoutTemplate(name: "T\(i)")) }
        await src.sync()

        let d = try SyncDevice.make(remote: remote, pageSize: 50)
        await d.sync()
        #expect(d.count(WorkoutTemplate.self) == 130)
        #expect(remote.fetchPageSizes.filter { $0 == 50 }.count >= 2)   // 50 + 50 + 30
        #expect(Set(d.fetch(WorkoutTemplate.self).map(\.name)).count == 130)
        #expect(d.service.isInitialSyncComplete && d.service.initialSyncProgress == 1)
    }

    @Test func cursorsPersistAndAdvance() async throws {
        let d = try SyncDevice.make()
        let t = d.template("A")
        await d.sync()
        await d.sync()                                                  // the second pull reads the first push back
        let key = SyncService.cursorKey("alice", .templates)
        // The device pushed it but also read it back: cursor sits at that document's updatedAt.
        #expect(d.defaults.integer(forKey: key) == Int(t.updatedAt.syncMs))
        let other = WorkoutTemplate(name: "B"); d.ctx.insert(other)
        await d.sync()
        #expect(d.defaults.integer(forKey: key) >= Int(t.updatedAt.syncMs))
        #expect(d.count(WorkoutTemplate.self) == 2)
    }

    // MARK: Last write wins

    @Test func remoteNewerWins() async throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise(), notes: "local")
        await d.sync()
        let newer = w.updatedAt.syncMs + 10_000
        d.remote.put(.workouts, id: SyncMapper.idString(w.id), ["notes": "from other phone", "updatedAt": newer])
        await d.sync()
        #expect(w.notes == "from other phone" && w.updatedAt.syncMs == newer && !w.isDirty)
        #expect(w.exerciseLogs.count == 1 && w.exerciseLogs[0].sets.count == 3)   // children intact (remote doc still carries them)
    }

    @Test func localNewerWinsAndIsPushed() async throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise(), notes: "v1")
        await d.sync()
        d.remote.put(.workouts, id: SyncMapper.idString(w.id), ["notes": "stale remote", "updatedAt": w.updatedAt.syncMs - 5_000])
        w.notes = "v2 local"; w.markUpdated()
        await d.sync()
        #expect(w.notes == "v2 local")
        #expect(d.remote.doc(.workouts, id: SyncMapper.idString(w.id))?["notes"] as? String == "v2 local")
        #expect(!w.isDirty)
    }

    @Test func equalTimestampsChangeNothing() async throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise(), notes: "mine")
        await d.sync()
        let writes = d.remote.writeCount
        d.remote.put(.workouts, id: SyncMapper.idString(w.id), ["notes": "same stamp, other text"])
        await d.sync()
        #expect(w.notes == "mine" && d.remote.writeCount == writes)
    }

    @Test func twoPhonesConvergeOnTheNewestEdit() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote), b = try SyncDevice.make(remote: remote)
        let bench = a.exercise(); b.exercise()
        let w = a.workout(exercise: bench, notes: "first")
        await a.sync(); await b.sync()
        let copy = try #require(b.fetch(Workout.self).first)
        #expect(copy.id == w.id && copy.notes == "first")

        copy.notes = "edited on b"; copy.markUpdated(now: Date().addingTimeInterval(60))
        await b.sync(); await a.sync()
        #expect(w.notes == "edited on b")
    }

    // MARK: Deletes

    @Test func localSoftDeletePropagatesAndHidesRemotelyDeletedRecord() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote), b = try SyncDevice.make(remote: remote)
        let bench = a.exercise(); b.exercise()
        let w = a.workout(exercise: bench)
        await a.sync(); await b.sync()
        let copy = try #require(b.fetch(Workout.self).first)

        a.ctx.softDelete(w)
        await a.sync()
        let doc = try #require(remote.doc(.workouts, id: SyncMapper.idString(w.id)))
        #expect(doc["deletedAt"] != nil && doc["exercises"] != nil)     // tombstone keeps the required fields
        await b.sync()
        #expect(copy.deletedAt != nil && !copy.isHistory)
        let live = try b.ctx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil }))
        #expect(live.isEmpty)
    }

    @Test func remoteDeleteIsAppliedAndNeverResurrectedByThePhoneThatHadIt() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        let t = a.template("Doomed")
        await a.sync()
        remote.put(.templates, id: SyncMapper.idString(t.id), ["deletedAt": t.updatedAt.syncMs + 1_000, "updatedAt": t.updatedAt.syncMs + 1_000])
        await a.sync()
        #expect(t.deletedAt != nil && !t.isDirty)
        await a.sync()
        #expect(remote.doc(.templates, id: SyncMapper.idString(t.id))?["deletedAt"] != nil)
    }

    @Test func deletedRemoteRecordsAreNotCreatedOnAFreshPhone() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        let t = a.template("Gone")
        await a.sync()
        a.ctx.softDelete(t)
        await a.sync()
        let b = try SyncDevice.make(remote: remote)
        await b.sync()
        #expect(b.count(WorkoutTemplate.self) == 0)
    }

    @Test func splitChangeToNoneSoftDeletesTheOldSplit() async throws {
        let d = try SyncDevice.make()
        let u = d.user()
        SplitSchedule.apply(type: .ppl, to: u, modelContext: d.ctx)
        await d.sync()
        let old = try #require(u.selectedSplit)
        SplitSchedule.apply(type: .none, to: u, modelContext: d.ctx)
        #expect(u.selectedSplit == nil && old.deletedAt != nil && old.isDirty && u.isDirty)
        await d.sync()
        #expect(d.remote.doc(.splits, id: SyncMapper.idString(old.id))?["deletedAt"] != nil)
        #expect(d.remote.doc(.profile, id: "alice")?["selectedSplitId"] == nil)   // cleared with FieldValue.delete semantics
    }

    // MARK: Relationships

    @Test func relationshipsAreLinkedByIdAndName() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        let bench = a.exercise()
        let custom = a.exercise("My Custom Curl", custom: true)
        let u = a.user()
        SplitSchedule.apply(type: .fullBody, to: u, modelContext: a.ctx)
        let t = a.template("Full A", exercise: bench)
        let w = a.workout(exercise: bench, template: t, user: u)
        a.workout(daysAgo: 3, exercise: custom, user: u)
        await a.sync()

        let b = try SyncDevice.make(remote: remote)
        let bBench = b.exercise()                                       // catalogue row: different UUID than a's
        await b.sync()
        let user = try #require(b.fetch(User.self).first)
        #expect(user.selectedSplit?.id == u.selectedSplit?.id && user.workouts.count == 2)
        let bw = try #require(b.fetch(Workout.self).first { $0.id == w.id })
        #expect(bw.template?.id == t.id && bw.user === user)
        #expect(bw.exerciseLogs[0].exercise === bBench)                 // catalogue exercise: by name
        let bCustom = try #require(b.fetch(Exercise.self).first { $0.isCustom })
        #expect(bCustom.id == custom.id && bCustom.logs.count == 1)      // custom exercise: by id
        #expect(b.fetch(WorkoutTemplate.self).first?.templateExercises.first?.exerciseId == bBench.id)
    }

    // MARK: Failures and retry

    @Test func failedCycleLeavesRecordsDirtyAndRetrySucceeds() async throws {
        let d = try SyncDevice.make()
        d.workout(exercise: d.exercise())
        d.remote.failNextCalls = 1
        await d.service.syncNow()
        #expect(d.service.status == .error("simulated outage"))
        #expect(d.service.pendingCount > 0 && d.service.scheduledRetryDelay == 5)
        #expect(d.remote.count(.workouts) == 0 && !d.service.isInitialSyncComplete)

        await d.sync()
        #expect(d.remote.count(.workouts) == 1 && d.service.pendingCount == 0 && d.service.scheduledRetryDelay == nil)
        #expect(d.service.isInitialSyncComplete)
    }

    @Test func pushFailureAfterInitialSyncKeepsDirtyAndBacksOff() async throws {
        let d = try SyncDevice.make()
        await d.sync()
        let w = d.workout(exercise: d.exercise())
        d.remote.failNextCalls = 1
        #expect(await d.service.flushPending() == false)
        #expect(w.isDirty && d.service.scheduledRetryDelay == 5)
        d.remote.failNextCalls = 1
        await d.service.syncNow()                                       // pull fails: second failure, longer backoff
        #expect(d.service.scheduledRetryDelay == 15)
        #expect(await d.service.flushPending() == true)
        #expect(!w.isDirty && d.remote.count(.workouts) == 1)
    }

    @Test func offlineIsReportedAndRecovers() async throws {
        let d = try SyncDevice.make()
        d.workout(exercise: d.exercise())
        d.remote.isOffline = true
        await d.service.syncNow()
        #expect(d.service.status == .offline)
        d.remote.isOffline = false
        await d.sync()
        #expect(d.remote.count(.workouts) == 1)
    }

    @Test func oneRejectedDocumentDoesNotBlockTheRest() async throws {
        let d = try SyncDevice.make()
        let bad = d.template("Bad"), good = d.template("Good")
        d.remote.rejectedIds = [SyncMapper.idString(bad.id)]
        await d.service.syncNow()
        #expect(d.service.status == .error("1 item could not be synced"))
        #expect(!good.isDirty && bad.isDirty)
        #expect(d.remote.doc(.templates, id: SyncMapper.idString(good.id)) != nil)
    }

    // MARK: Accounts

    @Test func differentAccountWipesLocalDataButKeepsCatalogue() async throws {
        let d = try SyncDevice.make(uid: "alice")
        let bench = d.exercise()                                        // catalogue row
        let u = d.user()
        d.workout(exercise: bench, user: u)
        d.workout(exercise: d.exercise("Custom", custom: true), draft: true)
        d.template("T")
        d.ctx.insert(EquipmentProfile(name: "E"))
        BodyweightLog.record(kg: 80, defaults: d.bodyweight)
        await d.sync()
        #expect(d.service.isInitialSyncComplete && d.defaults.string(forKey: SyncAccount.lastUidKey) == "alice")

        d.service.start(uid: "bob", context: d.ctx, remote: InMemoryRemoteStore(), triggerSync: false)
        #expect(d.count(Workout.self) == 0 && d.count(User.self) == 0 && d.count(WorkoutTemplate.self) == 0)
        #expect(d.count(EquipmentProfile.self) == 0 && BodyweightLog.load(defaults: d.bodyweight).isEmpty)
        #expect(d.fetch(Exercise.self).map(\.name) == ["Barbell Bench Press"])      // custom gone, catalogue stays
        #expect(!d.service.isInitialSyncComplete && SyncAccount.lastUid(d.defaults) == "bob")
        #expect(d.defaults.integer(forKey: SyncService.cursorKey("alice", .workouts)) == 0)
    }

    @Test func sameAccountKeepsDataOnRestartAndFirstSignInAdoptsExistingData() async throws {
        let d = try SyncDevice.make(start: false)
        d.workout(exercise: d.exercise())
        d.service.start(uid: "alice", context: d.ctx, remote: d.remote, triggerSync: false)   // first ever sign-in: adopt
        #expect(d.count(Workout.self) == 1)
        await d.sync()
        d.service.start(uid: "alice", context: d.ctx, remote: d.remote, triggerSync: false)   // relaunch
        #expect(d.count(Workout.self) == 1 && d.service.isInitialSyncComplete)
        #expect(d.remote.count(.workouts) == 1)
    }

    @Test func signOutWipeRemovesPersonalDataOnDemand() async throws {
        let d = try SyncDevice.make()
        d.user(); d.workout(exercise: d.exercise())
        await d.sync()
        #expect(await d.service.flushPending())
        d.service.wipeLocalUserData()
        #expect(d.count(User.self) == 0 && d.count(Workout.self) == 0 && d.count(ExerciseLog.self) == 0 && d.count(SetLog.self) == 0)
        #expect(!d.service.isInitialSyncComplete)
        // Signing back in restores everything from the cloud.
        d.service.start(uid: "alice", context: d.ctx, remote: d.remote, triggerSync: false)
        await d.sync()
        #expect(d.count(User.self) == 1 && d.count(Workout.self) == 1)
    }

    // MARK: Bodyweight

    @Test func bodyweightSyncsBothWaysWithLastWriteWins() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote), b = try SyncDevice.make(remote: remote)
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        BodyweightLog.record(kg: 80.5, on: day, defaults: a.bodyweight)
        await a.sync()
        let id = SyncMapper.bodyweightId(day: BodyweightLog.load(defaults: a.bodyweight)[0].day)
        #expect(remote.doc(.bodyweight, id: id)?["kg"] as? Double == 80.5)
        await b.sync()
        #expect(BodyweightLog.load(defaults: b.bodyweight).map(\.kg) == [80.5])

        BodyweightLog.record(kg: 79.9, on: day, defaults: b.bodyweight)   // newer edit on b
        await b.sync(); await a.sync()
        #expect(BodyweightLog.load(defaults: a.bodyweight).map(\.kg) == [79.9])
        // Re-recording the same value (the widget refresh does this constantly) is not an edit.
        let stamp = BodyweightLog.load(defaults: a.bodyweight)[0].updatedAt
        BodyweightLog.record(kg: 79.9, on: day, defaults: a.bodyweight)
        #expect(BodyweightLog.load(defaults: a.bodyweight)[0].updatedAt == stamp && BodyweightLog.dirtyEntries(defaults: a.bodyweight).isEmpty)
    }

    @Test func legacyBodyweightEntriesDecodeAndSync() async throws {
        let d = try SyncDevice.make()
        d.bodyweight.set(Data(#"[{"day":"2026-09-01","kg":82.0}]"#.utf8), forKey: BodyweightLog.key)   // saved before sync existed
        let loaded = BodyweightLog.load(defaults: d.bodyweight)
        #expect(loaded.count == 1 && loaded[0].updatedAt == nil && loaded[0].syncedAt == nil)
        await d.sync()
        #expect(d.remote.doc(.bodyweight, id: "20260901")?["kg"] as? Double == 82.0)
        #expect(BodyweightLog.dirtyEntries(defaults: d.bodyweight).isEmpty)
    }
}
