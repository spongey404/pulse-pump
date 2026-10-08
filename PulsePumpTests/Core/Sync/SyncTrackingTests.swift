import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// Dirty tracking, the change-tracker safety net and soft-delete filtering.
@MainActor
struct SyncTrackingTests {
    // MARK: Dirty tracking

    @Test func markUpdatedMakesACleanRecordDirtyAgain() async throws {
        let d = try SyncDevice.make()
        let t = d.template("T")
        await d.sync()
        #expect(!t.isDirty)
        let before = t.updatedAt
        d.ctx.markUpdated(t)
        #expect(t.updatedAt > before && t.isDirty)
    }

    @Test func editsMadeWhilePushIsInFlightStayDirty() async throws {
        let d = try SyncDevice.make()
        let t = d.template("T")
        await d.sync()
        t.name = "renamed"; t.markUpdated()
        await d.sync()
        #expect(d.remote.doc(.templates, id: SyncMapper.idString(t.id))?["name"] as? String == "renamed")
        // syncedAt stores the pushed updatedAt, not "now": a later stamp is always newer than it.
        #expect(t.syncedAt?.syncMs == t.updatedAt.syncMs)
        t.markUpdated()
        #expect(t.isDirty)
    }

    @Test func completingAWorkoutThroughTheViewModelMarksItDirtyAndSyncable() async throws {
        let f = try WorkoutDraftTests.fixture()
        let remote = InMemoryRemoteStore()
        let service = SyncService(defaults: SyncDevice.suite(), bodyweightDefaults: SyncDevice.suite())
        service.clearsWidgetData = false
        service.start(uid: "alice", context: f.ctx, remote: remote, triggerSync: false)

        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        WorkoutDraftTests.log(f, f.bench, [("80", "5", .standard), ("82,5", "5", .standard)])
        let draft = try #require(f.vm.workout)
        await service.syncNow()
        #expect(remote.count(.workouts) == 0)                           // still a draft: never synced

        f.vm.completeWorkout(modelContext: f.ctx)
        #expect(!draft.isDraft && draft.isDirty)
        await service.syncNow()
        let doc = try #require(remote.doc(.workouts, id: SyncMapper.idString(draft.id)))
        #expect((doc["exercises"] as? [[String: Any]])?.first?["exerciseName"] as? String == "Barbell Bench Press")
        #expect(!draft.isDirty)
    }

    @Test func editingASetInHistoryThroughMarkUpdatedDirtiesTheWorkout() async throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise())
        await d.sync()
        let set = try #require(w.exerciseLogs.first?.sets.first { $0.order == 0 })
        set.weight = 120
        d.ctx.markUpdated(set)                                          // what WorkoutDetailView does
        #expect(w.isDirty)
        await d.sync()
        let sets = (d.remote.doc(.workouts, id: SyncMapper.idString(w.id))?["exercises"] as? [[String: Any]])?.first?["sets"] as? [[String: Any]]
        #expect(sets?.first?["weightKg"] as? Double == 120)
    }

    @Test func softDeleteHelperSetsBothTimestamps() throws {
        let d = try SyncDevice.make()
        let t = d.template("T")
        let before = t.updatedAt
        d.ctx.softDelete(t)
        #expect(t.deletedAt != nil && t.updatedAt > before && !t.isLive)
    }

    // MARK: Safety net

    @Test func trackerCatchesAMutationNobodyMarked() async throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise())
        let t = d.template("T")
        await d.sync()
        #expect(!w.isDirty && !t.isDirty)

        w.exerciseLogs[0].sets[0].reps = 99                             // forgot markUpdated (child edit)
        t.notes = "forgot too"                                          // and a direct edit
        try d.ctx.save()
        #expect(w.isDirty && t.isDirty)
        #expect(d.service.pendingCount >= 2)
        await d.sync()
        #expect(!w.isDirty && !t.isDirty)
    }

    @Test func trackerIgnoresRelationshipNoiseAndTheEnginesOwnSaves() async throws {
        let d = try SyncDevice.make()
        let bench = d.exercise()
        let u = d.user()
        let t = d.template("T", exercise: bench)
        await d.sync()
        #expect(!u.isDirty && !t.isDirty)

        // A new workout touches the user's and template's inverse relationships but changes none of their content.
        let w = d.workout(exercise: bench, template: t, user: u)
        try d.ctx.save()
        #expect(w.isDirty && !u.isDirty && !t.isDirty)
        await d.sync()
        #expect(!u.isDirty && !t.isDirty && !w.isDirty)                  // applying syncedAt did not re-dirty anything
        let writes = d.remote.writeCount
        await d.sync()
        #expect(d.remote.writeCount == writes)
    }

    @Test func fullReconcileCatchesEditsMadeWhileNoTrackerWasInstalled() async throws {
        let d = try SyncDevice.make()
        let t = d.template("T")
        await d.sync()
        d.service.stop()                                                // no tracker
        t.name = "edited offline"
        try d.ctx.save()
        #expect(!t.isDirty)
        d.service.start(uid: "alice", context: d.ctx, remote: d.remote, triggerSync: false)
        await d.sync()                                                  // reconcileAll runs at the start of every cycle
        #expect(d.remote.doc(.templates, id: SyncMapper.idString(t.id))?["name"] as? String == "edited offline")
    }

    // MARK: Soft deletes vanish from lists and stats

    @Test func softDeletedWorkoutsAreExcludedFromHistoryQueriesAndStats() throws {
        let d = try SyncDevice.make()
        let bench = d.exercise()
        let t = d.template("T", exercise: bench)
        let keep = d.workout(daysAgo: 1, exercise: bench, template: t)
        let gone = d.workout(daysAgo: 2, exercise: bench, template: t)
        d.workout(daysAgo: 3, exercise: bench, draft: true)
        gone.softDelete()
        try d.ctx.save()

        // The exact predicate the screens' @Query use.
        let history = try d.ctx.fetch(FetchDescriptor<Workout>(predicate: #Predicate { !$0.isDraft && $0.deletedAt == nil }))
        #expect(history.map(\.id) == [keep.id])
        #expect(bench.finalLogs.count == 1)                              // exercise detail / body map sessions
        #expect(d.ctx.finalLogs(forExercise: bench.id).count == 1)       // ghost values, predictor, PR comparison
        #expect(t.liveWorkouts.map(\.id) == [keep.id])                   // "N logged" on a program
        #expect(gone.exerciseLogs.allSatisfy { !$0.isFinal })
        #expect(keep.isHistory && !gone.isHistory)
    }

    @Test func softDeletedTemplatesSplitsEquipmentAndExercisesAreExcludedFromQueries() throws {
        let d = try SyncDevice.make()
        let live = d.template("Live"), dead = d.template("Dead")
        dead.softDelete()
        let u = d.user()
        let eq1 = EquipmentProfile(name: "A"), eq2 = EquipmentProfile(name: "B")
        d.ctx.insert(eq1); d.ctx.insert(eq2); eq1.user = u; eq2.user = u
        eq2.softDelete()
        let x1 = d.exercise("Keep Me", custom: true), x2 = d.exercise("Delete Me", custom: true)
        x2.softDelete()
        try d.ctx.save()

        let templates = try d.ctx.fetch(FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.deletedAt == nil }))
        #expect(templates.map(\.id) == [live.id])
        #expect(u.liveEquipmentProfiles.map(\.id) == [eq1.id])
        let exercises = try d.ctx.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.deletedAt == nil }))
        #expect(exercises.map(\.id) == [x1.id])
    }

    @Test func softDeletedWorkoutsDoNotFeedWidgetsOrExport() throws {
        let d = try SyncDevice.make()
        let bench = d.exercise()
        let u = d.user()
        let keep = d.workout(daysAgo: 1, exercise: bench, user: u)
        let gone = d.workout(daysAgo: 0, exercise: bench, user: u)
        gone.softDelete()
        try d.ctx.save()

        let json = try DataExportService.exportWorkouts(from: d.ctx)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(WorkoutExportData.self, from: json)
        #expect(exported.workouts.count == 1)
        let csv = try DataExportService.generateCSV(from: d.ctx)
        #expect(csv.split(separator: "\n").count - 1 == keep.exerciseLogs.flatMap(\.sets).count)   // header + live workout's sets only
    }
}
