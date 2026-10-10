import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// Smart weight suggestions end to end: view model ghost, settings persistence, sync, Plus gating.
@MainActor
struct ProgressionIntegrationTests {
    private func settings() -> UserDefaults {
        let n = "prog-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: n)!
        d.removePersistentDomain(forName: n)
        return d
    }

    /// Fixture with an active workout, Plus on, private settings and a bench threshold of 8.
    private func active(threshold: Int? = 8, plus: Bool = true, unit: UnitPreference = .kg) throws -> (WorkoutDraftTests.Fixture, Int) {
        let f = try WorkoutDraftTests.fixture()
        f.user.unitPreference = unit
        f.vm.settings = settings()
        f.vm.hasPlusAccess = { plus }
        f.vm.startWorkout(modelContext: f.ctx, user: f.user)
        f.vm.addExercise(f.bench)
        if let threshold { f.user.setProgressionThreshold(threshold, forExercise: f.bench.name) }
        return (f, 0)
    }

    private func logRow(_ f: WorkoutDraftTests.Fixture, _ ei: Int, _ si: Int, _ w: String, _ r: String, _ t: SetType = .standard) {
        while f.vm.exerciseEntries[ei].sets.count <= si { f.vm.addSet(to: ei) }
        f.vm.exerciseEntries[ei].sets[si].weight = w
        f.vm.exerciseEntries[ei].sets[si].reps = r
        f.vm.exerciseEntries[ei].sets[si].setType = t
        f.vm.logSet(exerciseIndex: ei, setIndex: si, modelContext: f.ctx)
    }

    private func nextGhost(_ f: WorkoutDraftTests.Fixture, _ ei: Int) -> (weight: String, reps: String)? {
        let entry = f.vm.exerciseEntries[ei]
        let next = entry.sets.firstIndex { !$0.isCompleted } ?? entry.sets.count
        if next == entry.sets.count { f.vm.addSet(to: ei) }
        return f.vm.ghostText(for: entry.exerciseId, setIndex: next, modelContext: f.ctx)
    }

    // MARK: View model

    @Test func hittingTheThresholdGhostsTheHeavierWeight() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        #expect(nextGhost(f, ei)?.weight == "102.5")
    }

    @Test func ghostIsNotAutoFilledIntoTheRow() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        _ = nextGhost(f, ei)
        #expect(f.vm.exerciseEntries[ei].sets[1].weight.isEmpty)
    }

    @Test func missingTheThresholdKeepsPreviousSessionGhost() throws {
        let (f, ei) = try active()
        WorkoutDraftTests.addHistory(f, f.bench, daysAgo: 7, sets: [(90, 8, .standard), (92.5, 8, .standard)])
        logRow(f, ei, 0, "100", "6")
        let g = nextGhost(f, ei)
        #expect(g?.weight == "92.5" && g?.reps == "8")
    }

    @Test func suggestedWeightKeepsPreviousSessionRepsGhost() throws {
        let (f, ei) = try active()
        WorkoutDraftTests.addHistory(f, f.bench, daysAgo: 7, sets: [(90, 9, .standard), (90, 9, .standard)])
        logRow(f, ei, 0, "100", "8")
        let g = nextGhost(f, ei)
        #expect(g?.weight == "102.5" && g?.reps == "9")
    }

    @Test func noThresholdMeansNoSuggestion() throws {
        let (f, ei) = try active(threshold: nil)
        logRow(f, ei, 0, "100", "20")
        #expect(nextGhost(f, ei) == nil)
    }

    @Test func masterToggleOffRemovesTheGhost() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        f.vm.settings.set(false, forKey: "smartWeightSuggestions")
        #expect(nextGhost(f, ei) == nil)
        f.vm.settings.set(true, forKey: "smartWeightSuggestions")
        #expect(nextGhost(f, ei)?.weight == "102.5")
    }

    @Test func masterToggleDefaultsOn() throws {
        let vm = WorkoutViewModel(restTimer: WorkoutDraftTests.isolatedRestTimer())
        vm.settings = settings()
        #expect(vm.smartSuggestionsEnabled)
    }

    @Test func freeUserGetsNoGhost() throws {
        let (f, ei) = try active(plus: false)
        logRow(f, ei, 0, "100", "8")
        #expect(nextGhost(f, ei) == nil)
    }

    @Test func freeUserCannotSetAThreshold() throws {
        let (f, ei) = try active(threshold: nil, plus: false)
        f.vm.setProgressionThreshold(8, exerciseIndex: ei, modelContext: f.ctx)
        #expect(f.user.progressionThresholds.isEmpty && f.vm.progressionThreshold(exerciseIndex: ei) == nil)
    }

    @Test func plusUserSetsAndClearsThresholdThroughTheViewModel() throws {
        let (f, ei) = try active(threshold: nil)
        f.vm.setProgressionThreshold(10, exerciseIndex: ei, modelContext: f.ctx)
        #expect(f.vm.progressionThreshold(exerciseIndex: ei) == 10)
        #expect(f.user.progressionThresholds[Exercise.normalisedName(f.bench.name)] == 10)
        f.vm.setProgressionThreshold(nil, exerciseIndex: ei, modelContext: f.ctx)
        #expect(f.user.progressionThresholds.isEmpty)
    }

    @Test func warmUpsDoNotTriggerOrMoveTheTopWeight() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "140", "12", .warmup)
        #expect(nextGhost(f, ei) == nil)
        logRow(f, ei, 1, "100", "8")
        #expect(nextGhost(f, ei)?.weight == "102.5")
    }

    @Test func warmUpIsNeverGhostedWithASuggestion() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        f.vm.addSet(to: ei)
        f.vm.exerciseEntries[ei].sets[1].setType = .warmup
        #expect(f.vm.ghostText(for: f.bench.id, setIndex: 1, modelContext: f.ctx) == nil)
    }

    @Test func onlyTheNextRowGetsTheGhost() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        f.vm.addSet(to: ei); f.vm.addSet(to: ei)
        #expect(f.vm.ghostText(for: f.bench.id, setIndex: 1, modelContext: f.ctx)?.weight == "102.5")
        #expect(f.vm.ghostText(for: f.bench.id, setIndex: 2, modelContext: f.ctx) == nil)
    }

    @Test func heavierWeightMovesTheCheckAndKeepsClimbing() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        logRow(f, ei, 1, "102.5", "8")
        #expect(nextGhost(f, ei)?.weight == "105")
        logRow(f, ei, 2, "105", "5")
        #expect(nextGhost(f, ei) == nil)
    }

    @Test func lbsUserSeesWholePoundSuggestionStoredAsKg() throws {
        let (f, ei) = try active(unit: .lbs)
        let hundredLb = UnitPreference.lbs.kgString(displayText: "100")
        logRow(f, ei, 0, hundredLb, "8")
        let text = try #require(nextGhost(f, ei)?.weight)
        let kg = try #require(Double(text))
        #expect(abs(UnitPreference.lbs.display(kg) - 105) < 0.001)
        // Kg storage invariant: the ghost text is kg, never the display number.
        #expect(kg > 45 && kg < 50)
    }

    @Test func timeBasedExercisesAreNeverSuggested() throws {
        let (f, ei) = try active()
        f.vm.exerciseEntries[ei].exerciseType = .timeBased
        logRow(f, ei, 0, "100", "8")
        #expect(nextGhost(f, ei) == nil)
    }

    @Test func bodyweightExerciseHasNothingToSuggest() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "", "20")
        #expect(nextGhost(f, ei) == nil)
    }

    @Test func tickingAnUntouchedGhostSavesTheSuggestedWeight() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        f.vm.addSet(to: ei)
        f.vm.exerciseEntries[ei].sets[1].reps = "8"
        f.vm.logSet(exerciseIndex: ei, setIndex: 1, modelContext: f.ctx)
        #expect(f.vm.exerciseEntries[ei].sets[1].weight == "102.5")
    }

    @Test func typingOverTheGhostWins() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        logRow(f, ei, 1, "100", "8")          // user stays at 100
        #expect(f.vm.exerciseEntries[ei].sets[1].weight == "100")
    }

    // MARK: Settings persistence

    @Test func incrementDefaultsFollowTheUnit() throws {
        let kg = User(name: "k", unitPreference: .kg), lb = User(name: "l", unitPreference: .lbs)
        #expect(kg.effectiveProgressionIncrementKg == 2.5)
        #expect(abs(lb.effectiveProgressionIncrementKg - 5 * 0.45359237) < 1e-9)
    }

    @Test func incrementIsStoredInKgAndSurvivesUnitSwitch() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let u = User(name: "u", unitPreference: .lbs); ctx.insert(u)
        u.setProgressionIncrementKg(UnitPreference.lbs.kg(fromDisplay: 10))
        try ctx.save()
        u.unitPreference = .kg
        #expect(abs(u.effectiveProgressionIncrementKg - 4.5359237) < 1e-9)
        let again = try #require(try ctx.fetch(FetchDescriptor<User>()).first)
        #expect(again.progressionIncrementKg == u.progressionIncrementKg)
    }

    @Test func thresholdsPersistKeyedByNormalisedName() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let u = User(name: "u"); ctx.insert(u)
        u.setProgressionThreshold(8, forExercise: "Barbell  Bench-Press")
        try ctx.save()
        let again = try #require(try ctx.fetch(FetchDescriptor<User>()).first)
        #expect(again.progressionThresholds == ["barbell bench press": 8])
        #expect(again.progressionThreshold(forExercise: "barbell bench press") == 8)
    }

    @Test func invalidValuesAreRejected() {
        let u = User(name: "u")
        u.setProgressionThreshold(0, forExercise: "Squat")
        u.setProgressionThreshold(99, forExercise: "Squat")
        u.setProgressionThreshold(8, forExercise: "  ")
        u.setProgressionIncrementKg(-1)
        u.setProgressionIncrementKg(0)
        #expect(u.progressionThresholds.isEmpty && u.progressionIncrementKg == nil)
    }

    @Test func changesMarkTheUserDirtyOnlyWhenTheyChange() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let u = User(name: "u"); ctx.insert(u)
        u.markSynced(digest: "x")
        u.setProgressionThreshold(nil, forExercise: "Squat")            // nothing to clear
        #expect(!u.isDirty)
        u.setProgressionThreshold(5, forExercise: "Squat")
        #expect(u.isDirty)
    }

    // MARK: Sync

    @Test func profilePayloadCarriesProgressionInKg() throws {
        let d = try SyncDevice.make()
        let u = d.user()                                                // lbs user
        #expect(SyncMapper.fields(u)["progression"] == nil)             // omitted when unused
        u.setProgressionThreshold(8, forExercise: "Barbell Bench Press")
        u.setProgressionIncrementKg(2.5)
        let p = try #require(SyncMapper.fields(u)["progression"] as? [String: Any])
        let rows = try #require(p["thresholds"] as? [[String: Any]])
        #expect(rows.count == 1 && rows[0]["name"] as? String == "barbell bench press" && rows[0]["reps"] as? Int == 8)
        #expect(p["incrementKg"] as? Double == 2.5)
        #expect(SyncMapper.optionalKeys(.profile).contains("progression"))
    }

    @Test func progressionRoundTripsToAnotherPhone() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote)
        let u = a.user()
        u.setProgressionThreshold(8, forExercise: "Barbell Bench Press")
        u.setProgressionThreshold(12, forExercise: "Lateral Raise")
        u.setProgressionIncrementKg(1.25)
        await a.sync()
        let b = try SyncDevice.make(remote: remote)
        await b.sync()
        let copy = try #require(b.fetch(User.self).first)
        #expect(copy.progressionThresholds == ["barbell bench press": 8, "lateral raise": 12])
        #expect(copy.progressionIncrementKg == 1.25)
    }

    @Test func clearingEverythingIsPropagated() async throws {
        let remote = InMemoryRemoteStore()
        let a = try SyncDevice.make(remote: remote), b = try SyncDevice.make(remote: remote)
        let u = a.user()
        u.setProgressionThreshold(8, forExercise: "Squat")
        await a.sync(); await b.sync()
        let copy = try #require(b.fetch(User.self).first)
        #expect(copy.progressionThresholds.count == 1)
        u.setProgressionThreshold(nil, forExercise: "Squat")
        u.markUpdated(now: Date().addingTimeInterval(60))
        await a.sync(); await b.sync()
        #expect(copy.progressionThresholds.isEmpty && copy.progressionIncrementKg == nil)
        #expect(remote.doc(.profile, id: "alice")?["progression"] == nil)
    }

    @Test func newerRemoteProgressionWinsAndOlderLoses() async throws {
        let d = try SyncDevice.make()
        let u = d.user()
        u.setProgressionThreshold(8, forExercise: "Squat")
        await d.sync()
        let id = "alice"
        var f = try #require(d.remote.doc(.profile, id: id))
        f["progression"] = ["thresholds": [["name": "squat", "reps": 5]], "incrementKg": 5.0]
        f["updatedAt"] = u.updatedAt.syncMs - 5_000                     // stale
        d.remote.put(.profile, id: id, f)
        await d.sync()
        #expect(u.progressionThresholds == ["squat": 8])                // local newer wins
        f["updatedAt"] = u.updatedAt.syncMs + 10_000                    // newer
        d.remote.put(.profile, id: id, f)
        await d.sync()
        #expect(u.progressionThresholds == ["squat": 5] && u.progressionIncrementKg == 5)
    }

    @Test func unknownAndInvalidProgressionFieldsAreIgnored() async throws {
        let d = try SyncDevice.make()
        let u = d.user()
        await d.sync()
        var f = try #require(d.remote.doc(.profile, id: "alice"))
        f["progression"] = ["thresholds": [["name": "squat", "reps": 5, "future": 1], ["name": "bad", "reps": 400], ["reps": 3]],
                            "incrementKg": -3.0, "somethingNew": true]
        f["updatedAt"] = u.updatedAt.syncMs + 10_000
        d.remote.put(.profile, id: "alice", f)
        await d.sync()
        #expect(u.progressionThresholds == ["squat": 5] && u.progressionIncrementKg == nil)
    }

    // MARK: Gating

    @Test func plusGateControlsSuggestionsButNotStoredSettings() throws {
        let (f, ei) = try active()
        logRow(f, ei, 0, "100", "8")
        #expect(nextGhost(f, ei)?.weight == "102.5")
        f.vm.hasPlusAccess = { false }
        #expect(nextGhost(f, ei) == nil)
        #expect(f.user.progressionThreshold(forExercise: f.bench.name) == 8)   // kept for when they resubscribe
        f.vm.hasPlusAccess = { true }
        #expect(nextGhost(f, ei)?.weight == "102.5")
    }

    @Test func featureIsListedInPlusFeatures() {
        #expect(PulsePlusFeature.allCases.contains(.smartWeightSuggestions))
    }
}
