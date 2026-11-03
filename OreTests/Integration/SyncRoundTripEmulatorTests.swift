import Testing
import Foundation
import SwiftData
@testable import Ore

/// `SyncService` + `FirestoreRemoteStore` against the real Firestore emulator and the real security rules.
@Suite("Sync round trip against the emulator", .emulator, .serialized)
@MainActor
struct SyncRoundTripEmulatorTests {
    // MARK: Rules acceptance

    @Test func rulesAcceptEveryMappedCollection() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let phone = try SyncDevice.phone(for: a)

            let user = phone.user(name: "Ada")
            let press = phone.exercise("Barbell Bench Press")
            let custom = phone.exercise("Cable Face Pull", custom: true)
            let template = phone.template("Push Day", exercise: press)
            phone.workout(exercise: press, template: template, user: user, notes: "felt strong")
            phone.workout(daysAgo: 3, exercise: custom, user: user)
            let split = Split(type: .ppl, days: [SplitDay(dayOfWeek: 1, label: "Push", workoutType: "push"),
                                                 SplitDay(dayOfWeek: 3, label: "Pull", workoutType: "pull")])
            phone.ctx.insert(split)
            user.selectedSplit = split
            phone.ctx.insert(EquipmentProfile(name: "Home gym", availableEquipment: [.barbell, .dumbbell],
                                              barTypes: [.defaultOlympic, .ezCurl]))
            BodyweightLog.record(kg: 71.4, defaults: phone.bodyweight)
            try phone.ctx.save()

            await phone.sync()   // fails if any single payload was rejected (permission-denied)

            #expect(phone.service.pendingCount == 0)
            #expect(try await a.store.allDocs(.workouts).count == 2)
            #expect(try await a.store.allDocs(.templates).count == 1)
            #expect(try await a.store.allDocs(.splits).count == 1)
            #expect(try await a.store.allDocs(.equipmentProfiles).count == 1)
            #expect(try await a.store.allDocs(.customExercises).count == 1)
            #expect(try await a.store.allDocs(.bodyweight).count == 1)
            let profile = try #require(try await a.store.fetchDoc(.profile, id: a.uid))
            #expect(profile.fields["name"] as? String == "Ada")
            #expect(profile.fields["selectedSplitId"] as? String == SyncMapper.idString(split.id))
        }
    }

    @Test func aPayloadTheRulesRefuseSurfacesAsAPermanentRemoteError() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            // `exercises` must be a list: an app bug writing garbage must be a permanent error, never a retry loop.
            let bad = RemoteWrite(collection: .workouts, id: UUID().uuidString.lowercased(),
                                  fields: ["date": Date(), "updatedAt": 1, "exercises": "not a list", "schemaVersion": 1])
            do {
                try await a.store.batchWrite([bad])
                Issue.record("the rules must refuse a workout whose exercises are not a list")
            } catch let error as RemoteError {
                #expect(error.isPermanent, "got \(error)")
            }
        }
    }

    @Test func fetchDocReturnsNilForAMissingDocumentAndTheDocumentOnceWritten() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let id = UUID().uuidString.lowercased()
            #expect(try await a.store.fetchDoc(.templates, id: id) == nil)
            try await a.store.batchWrite([RemoteWrite(collection: .templates, id: id,
                fields: ["name": "Legs", "exercises": [[String: Any]](), "updatedAt": 5_000, "schemaVersion": 1])])
            let doc = try #require(try await a.store.fetchDoc(.templates, id: id))
            #expect(doc.fields["name"] as? String == "Legs" && doc.updatedAtMs == 5_000)
        }
    }

    // MARK: Dataset

    @Test func ninetyWorkoutHistoryPushesAndRestoresIdenticallyOnAnEmptyPhone() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let old = try SyncDevice.phone(for: a)
            let summary = IntegrationData.busyHistory(into: old)
            #expect(summary.workouts >= 70)
            try old.ctx.save()
            let before = HistoryTotals(old)
            #expect(before.workouts == summary.workouts)

            await old.sync()
            #expect(old.service.pendingCount == 0)
            #expect(try await a.store.allDocs(.workouts).count == summary.workouts)
            #expect(try await a.store.allDocs(.templates).count == 3)

            // A new phone (reinstall): nothing local, initial pull restores everything.
            let fresh = try SyncDevice.phone(for: a)
            #expect(fresh.count(Workout.self) == 0)
            await fresh.sync()
            #expect(HistoryTotals(fresh) == before)
            #expect(fresh.count(User.self) == 1)
            #expect(BodyweightLog.load(defaults: fresh.bodyweight).count == BodyweightLog.load(defaults: old.bodyweight).count)
        }
    }

    @Test func initialPullCompletesTheRestoreGate() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let seed = try SyncDevice.phone(for: a)
            seed.user(); seed.workout(exercise: seed.exercise())
            try seed.ctx.save()
            await seed.sync()

            let fresh = try SyncDevice.phone(for: a)
            #expect(fresh.service.isInitialSyncComplete == false && fresh.service.initialSyncProgress == 0)
            await fresh.sync()
            #expect(fresh.service.isInitialSyncComplete && fresh.service.initialSyncProgress == 1)
            #expect(fresh.service.lastSyncedAt != nil)
        }
    }

    @Test func pushingMoreThanOneBatchStoresEveryDocument() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let phone = try SyncDevice.phone(for: a)
            phone.user()
            IntegrationData.lightWorkouts(850, on: phone)   // 850 + profile > two 400-write batches

            await phone.sync()
            #expect(phone.service.pendingCount == 0)
            #expect(try await a.store.allDocs(.workouts).count == 850)
        }
    }

    @Test func pullingALargeCollectionPagesThroughEveryDocument() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let writer = try SyncDevice.phone(for: a)
            writer.user()
            IntegrationData.lightWorkouts(130, on: writer)
            await writer.sync()

            let reader = try SyncDevice.phone(for: a, pageSize: 25)   // six pages
            await reader.sync()
            #expect(reader.count(Workout.self) == 130)
            #expect(reader.defaults.integer(forKey: SyncService.cursorKey(a.uid, .workouts)) > 0, "cursor advanced")
        }
    }

    @Test func aSecondSyncWithNothingChangedWritesNothing() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let phone = try SyncDevice.phone(for: a)
            phone.user(); phone.workout(exercise: phone.exercise())
            try phone.ctx.save()
            await phone.sync()
            let first = try await a.store.allDocs(.workouts).map { ($0.id, $0.updatedAtMs) }

            await phone.sync()
            await phone.sync()
            let second = try await a.store.allDocs(.workouts).map { ($0.id, $0.updatedAtMs) }
            #expect(first.count == 1 && first.map(\.0) == second.map(\.0) && first.map(\.1) == second.map(\.1))
            #expect(phone.service.pendingCount == 0)
        }
    }

    @Test func aRestoredWorkoutIsLinkedBackToItsTemplate() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let source = try SyncDevice.phone(for: a)
            let bench = source.exercise("Barbell Bench Press")
            let template = source.template("Push Day", exercise: bench)
            source.workout(exercise: bench, template: template)
            source.user()
            try source.ctx.save()
            await source.sync()

            let fresh = try SyncDevice.phone(for: a)
            await fresh.sync()
            let restored = try #require(fresh.fetch(Workout.self).first)
            #expect(restored.template?.name == "Push Day")
            #expect(restored.exerciseLogs.first?.exercise?.name == "Barbell Bench Press")
            #expect(restored.exerciseLogs.first?.sets.count == 3)
        }
    }

    // MARK: Field level behaviour

    @Test func clearingAnOptionalFieldRemovesItRemotelyWithFieldValueDelete() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let phone = try SyncDevice.phone(for: a)
            let bench = phone.exercise()
            let template = phone.template("Push Day", exercise: bench)
            let workout = phone.workout(exercise: bench, template: template)
            phone.user()
            try phone.ctx.save()
            await phone.sync()
            let id = SyncMapper.idString(workout.id)
            #expect(try await a.store.fetchDoc(.workouts, id: id)?.fields["templateId"] as? String == SyncMapper.idString(template.id))

            try phone.edit(workout) { $0.template = nil }
            await phone.sync()
            let doc = try #require(try await a.store.fetchDoc(.workouts, id: id))
            #expect(doc.fields["templateId"] == nil && doc.fields["templateName"] == nil, "fields removed, not left stale")
            #expect(doc.fields["notes"] != nil, "other fields survive the merge")
        }
    }

    @Test func syncingTheProfileKeepsThePrivacyMapWrittenBySocialCode() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            var privacy = PrivacySettings.default
            privacy.workoutPosts = .onlyMe
            privacy.bodyMap = .everyone
            try await a.social.savePrivacy(privacy)

            let phone = try SyncDevice.phone(for: a)
            phone.user(name: "Ada Renamed", weight: 66)
            try phone.ctx.save()
            await phone.sync()

            let raw = try #require(try await a.document("users/\(a.uid)"))
            #expect(raw["name"] as? String == "Ada Renamed", "sync wrote its own fields")
            let map = try #require(raw["privacy"] as? [String: Any])
            #expect(PrivacySettings(firestoreMap: map) == privacy, "the merge write must not clobber privacy")
            #expect(try await a.social.loadPrivacy() == privacy)
        }
    }

    @Test func socialCodeWritingPrivacyAfterSyncKeepsTheSyncedProfileFields() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            let phone = try SyncDevice.phone(for: a)
            phone.user(name: "Ada Synced", weight: 64)
            try phone.ctx.save()
            await phone.sync()

            var privacy = PrivacySettings.default
            privacy.profile = .friendsOnly
            try await a.social.savePrivacy(privacy)

            let raw = try #require(try await a.document("users/\(a.uid)"))
            #expect(raw["name"] as? String == "Ada Synced" && raw["weightKg"] as? Double == 64)
            #expect(try await a.document("profiles/\(a.uid)")?["profileVisibility"] as? String == "friends")
        }
    }

    // MARK: Accounts

    @Test func signingInAsAnotherAccountWipesTheFirstAccountsLocalData() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada")
            let bea = try await world.account("bea")
            let phone = try SyncDevice.phone(for: ada)
            phone.user(name: "Ada"); phone.workout(exercise: phone.exercise())
            try phone.ctx.save()
            await phone.sync()
            #expect(phone.count(Workout.self) == 1)

            phone.service.start(uid: bea.uid, context: phone.ctx, remote: bea.store, triggerSync: false)
            #expect(phone.count(Workout.self) == 0 && phone.count(User.self) == 0, "Ada's data must never mix into Bea's account")
            await phone.sync()
            #expect(phone.count(Workout.self) == 0)
            #expect(try await bea.store.allDocs(.workouts).isEmpty)
        }
    }

    @Test func flushPendingPushesEverythingBeforeSignOut() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let phone = try SyncDevice.phone(for: a)
            phone.user(); phone.workout(exercise: phone.exercise())
            try phone.ctx.save()
            #expect(try await a.store.allDocs(.workouts).isEmpty)
            #expect(await phone.service.flushPending())
            #expect(try await a.store.allDocs(.workouts).count == 1)
        }
    }
}
