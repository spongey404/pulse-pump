import Testing
import Foundation
import SwiftData
@testable import Ore

/// Model <-> Firestore dictionary: field names are the contract in docs/sync-architecture.md.
@MainActor
struct SyncMapperTests {
    /// Applies `fields` on a brand-new store (a second phone) and returns that phone.
    private func apply(_ fields: SyncFields, id: UUID, to c: SyncCollection, device: SyncDevice) -> SyncApplier.Outcome {
        let applier = SyncApplier(ctx: device.ctx)
        return applier.apply(RemoteDoc(id: SyncMapper.idString(id), fields: fields), in: c)
    }

    @Test func workoutPayloadUsesContractFieldNamesAndKg() throws {
        let d = try SyncDevice.make()
        let bench = d.exercise()
        let t = d.template("Push Day", exercise: bench)
        let w = d.workout(exercise: bench, template: t, notes: "good")
        let f = SyncMapper.fields(w)

        #expect(Set(f.keys) == ["date", "durationSec", "notes", "calories", "isDeload", "templateId", "templateName",
                                "exercises", "schemaVersion", "updatedAt"])
        #expect(f["templateId"] as? String == SyncMapper.idString(t.id) && f["templateName"] as? String == "Push Day")
        #expect(f["schemaVersion"] as? Int == 1 && f["updatedAt"] as? Int64 == w.updatedAt.syncMs)
        #expect(f["deletedAt"] == nil)                                  // only when set
        let ex = try #require((f["exercises"] as? [[String: Any]])?.first)
        #expect(Set(ex.keys) == ["exerciseId", "exerciseName", "order", "notes", "sets"])
        let sets = try #require(ex["sets"] as? [[String: Any]])
        #expect(sets.count == 3)
        #expect(Set(sets[0].keys) == ["order", "weightKg", "reps", "rir", "setType", "side"])
        // kg invariant: the stored weight is sent verbatim, whatever the display unit is (user prefers lbs).
        #expect(sets.map { $0["weightKg"] as? Double } == [100, 100, 102.5])
        #expect(sets[1]["durationSec"] as? Double == 45 && sets[2]["distanceM"] as? Double == 12.5)
        #expect(sets[0]["setType"] as? String == "warmup" && sets[2]["side"] as? String == "left")
    }

    @Test func deletedAtAppearsOnlyWhenSet() throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise())
        #expect(SyncMapper.fields(w)["deletedAt"] == nil)
        w.softDelete()
        #expect(SyncMapper.fields(w)["deletedAt"] as? Int64 == w.deletedAt?.syncMs)
        #expect(SyncMapper.optionalKeys(.workouts).contains("deletedAt"))
    }

    @Test func workoutRoundTripsThroughAnotherStore() throws {
        let a = try SyncDevice.make(), b = try SyncDevice.make()
        let bench = a.exercise()
        _ = b.exercise()                                                // same catalogue name, different id
        let w = a.workout(exercise: bench, notes: "round trip")
        let outcome = apply(SyncMapper.fields(w), id: w.id, to: .workouts, device: b)
        #expect(outcome == .created)

        let copy = try #require(b.fetch(Workout.self).first)
        #expect(copy.id == w.id && !copy.isDraft && copy.notes == "round trip")
        #expect(copy.duration == 3_300.5 && copy.calorieBurnEstimate == 310 && copy.date.syncMs == w.date.syncMs)
        #expect(copy.updatedAt.syncMs == w.updatedAt.syncMs && !copy.isDirty)   // adopted as already synced
        let sets = copy.exerciseLogs[0].sets.sorted { $0.order < $1.order }
        #expect(sets.map(\.weight) == [100, 100, 102.5] && sets.map(\.reps) == [5, 5, 3])
        #expect(sets.map(\.rir) == [2, nil, nil] && sets[1].duration == 45 && sets[2].distance == 12.5)
        #expect(sets.map(\.setType) == [.warmup, .standard, .standard] && sets[2].side == .left)
        #expect(copy.exerciseLogs[0].notes == "felt strong")
        #expect(copy.exerciseLogs[0].exercise?.id == b.fetch(Exercise.self).first?.id)    // linked by name
        // Only exerciseId differs (catalogue ids are per install); everything else is identical.
        var fa = SyncMapper.fields(copy), fb = SyncMapper.fields(w)
        for k in ["exercises"] { fa.removeValue(forKey: k); fb.removeValue(forKey: k) }
        #expect(SyncMapper.digest(fa) == SyncMapper.digest(fb))
    }

    @Test func templateRoundTripIncludingMissingOptionals() throws {
        let a = try SyncDevice.make(), b = try SyncDevice.make()
        let bench = a.exercise(); let bBench = b.exercise()
        let t = a.template("Pull Day", exercise: bench)
        t.templateExercises.append(TemplateExercise(exerciseId: bench.id, exerciseName: bench.name, order: 1, targetSets: 2))   // no optionals
        _ = apply(SyncMapper.fields(t), id: t.id, to: .templates, device: b)

        let copy = try #require(b.fetch(WorkoutTemplate.self).first)
        #expect(copy.name == "Pull Day" && copy.notes == "heavy" && copy.splitDays == ["Mon", "Thu"])
        let ex = copy.templateExercises.sorted { $0.order < $1.order }
        #expect(ex.count == 2 && ex[0].targetReps == 8 && ex[0].targetRIR == 1 && ex[0].restSeconds == 120 && ex[0].notes == "pause")
        #expect(ex[1].targetReps == nil && ex[1].targetRIR == nil && ex[1].restSeconds == nil && ex[1].notes == nil)
        #expect(ex[0].exerciseId == bBench.id)                          // re-pointed at this install's catalogue row
    }

    @Test func splitEquipmentAndCustomExerciseRoundTrip() throws {
        let a = try SyncDevice.make(), b = try SyncDevice.make()
        let split = SplitSchedule.makeSplit(type: .ppl); a.ctx.insert(split)
        let eq = EquipmentProfile(name: "Home gym", availableEquipment: [.barbell, .dumbbell], availablePlates: [1.25, 5, 20],
                                  barTypes: [BarConfig(name: "Olympic", weightKg: 20), BarConfig(name: "EZ", weightKg: 8)])
        a.ctx.insert(eq)
        let x = Exercise(name: "Zercher Squat", primaryMuscleGroups: [.quads, .glutes], secondaryMuscleGroups: [.abs], equipmentType: .barbell,
                         movementPattern: .squat, exerciseType: .weighted, isCustom: true, isApproved: false, isUnilateral: true,
                         primarySubRegions: [], secondarySubRegions: [])
        a.ctx.insert(x)

        #expect(apply(SyncMapper.fields(split), id: split.id, to: .splits, device: b) == .created)
        #expect(apply(SyncMapper.fields(eq), id: eq.id, to: .equipmentProfiles, device: b) == .created)
        #expect(apply(SyncMapper.fields(x), id: x.id, to: .customExercises, device: b) == .created)

        let s = try #require(b.fetch(Split.self).first)
        #expect(s.type == .ppl && s.name == split.name && s.days.count == 6)
        #expect(s.days.map(\.dayOfWeek) == split.days.map(\.dayOfWeek) && s.days.map(\.label) == split.days.map(\.label))
        let e = try #require(b.fetch(EquipmentProfile.self).first)
        #expect(e.availableEquipment == [.barbell, .dumbbell] && e.availablePlates == [1.25, 5, 20])
        #expect(e.barTypes.map(\.name) == ["Olympic", "EZ"] && e.barTypes.map(\.weightKg) == [20, 8])
        let c = try #require(b.fetch(Exercise.self).first)
        #expect(c.id == x.id && c.isCustom && c.isUnilateral && !c.isApproved)
        #expect(c.primaryMuscleGroups == [.quads, .glutes] && c.secondaryMuscleGroups == [.abs] && c.movementPattern == .squat)
    }

    @Test func profilePayloadOwnsOnlyItsFieldsAndRoundTrips() throws {
        let a = try SyncDevice.make(), b = try SyncDevice.make()
        let split = SplitSchedule.makeSplit(type: .upperLower); a.ctx.insert(split)
        let u = a.user(name: "Ada", weight: 61.5)
        u.selectedSplit = split
        let f = SyncMapper.fields(u)
        #expect(f["privacy"] == nil && f["settings"] == nil)            // social agent's fields are never written
        #expect(Set(f.keys).isSubset(of: ["name", "username", "unit", "experienceLevel", "gender", "age", "heightCm", "weightKg",
                                          "selectedSplitId", "createdAt", "schemaVersion", "updatedAt"]))
        #expect(f["unit"] as? String == "lbs" && f["weightKg"] as? Double == 61.5 && f["heightCm"] as? Double == 170)

        _ = apply(SyncMapper.fields(split), id: split.id, to: .splits, device: b)
        let applier = SyncApplier(ctx: b.ctx)
        #expect(applier.apply(RemoteDoc(id: "alice", fields: f), in: .profile) == .created)
        let copy = try #require(b.fetch(User.self).first)
        #expect(copy.name == "Ada" && copy.unitPreference == .lbs && copy.weight == 61.5 && copy.height == 170 && copy.age == 30)
        #expect(copy.gender == .female && copy.experienceLevel == .intermediate && copy.selectedSplit?.id == split.id)
    }

    @Test func unknownFieldsAreIgnoredAndMissingOnesDefault() throws {
        let b = try SyncDevice.make()
        let id = UUID()
        let outcome = apply(["updatedAt": Int64(5_000), "futureField": ["x": 1], "schemaVersion": 7, "exercises": [["exerciseName": "Mystery Lift", "sets": [["reps": 3]]]]],
                            id: id, to: .workouts, device: b)
        #expect(outcome == .created)
        let w = try #require(b.fetch(Workout.self).first)
        #expect(w.notes == "" && w.duration == 0 && w.calorieBurnEstimate == 0 && !w.isDeload && w.template == nil && w.schemaVersion == 7)
        let set = try #require(w.exerciseLogs.first?.sets.first)
        #expect(set.reps == 3 && set.weight == 0 && set.setType == .standard && set.side == .both && set.rir == nil)
        #expect(w.exerciseLogs.first?.exercise?.name == "Mystery Lift")  // unknown exercise keeps the history (local placeholder)
        // A garbage enum value falls back instead of failing the whole document.
        let bad = apply(["updatedAt": Int64(6_000), "exercises": [["exerciseName": "Mystery Lift", "sets": [["setType": "nonsense", "side": 4]]]]],
                        id: UUID(), to: .workouts, device: b)
        #expect(bad == .created)
    }

    @Test func bodyweightPayloadAndIds() {
        #expect(SyncMapper.bodyweightId(day: "2026-10-07") == "20261007")
        #expect(SyncMapper.bodyweightDay(id: "20261007") == "2026-10-07")
        #expect(SyncMapper.bodyweightDay(id: "2026-10-07") == nil)
        let f = SyncMapper.bodyweightFields(kg: 81.2, updatedAt: Date(syncMs: 1_000))
        #expect(Set(f.keys) == ["kg", "updatedAt"] && f["kg"] as? Double == 81.2 && f["updatedAt"] as? Int64 == 1_000)
    }

    @Test func digestIgnoresUpdatedAtButSeesContent() throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise())
        let before = SyncMapper.digest(SyncMapper.fields(w))
        w.markUpdated()
        #expect(SyncMapper.digest(SyncMapper.fields(w)) == before)
        w.notes = "changed"
        #expect(SyncMapper.digest(SyncMapper.fields(w)) != before)
    }

    @Test func oversizedTextIsClampedToTheRulesLimits() throws {
        let d = try SyncDevice.make()
        let w = d.workout(exercise: d.exercise(), notes: String(repeating: "x", count: 9_000))
        #expect((SyncMapper.fields(w)["notes"] as? String)?.count == 5_000)
    }
}
