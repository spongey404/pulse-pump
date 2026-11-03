import Testing
import Foundation
import SwiftData
@testable import Ore

/// Program → Workouts → Exercises (Ore Programs): rotation, up next, averages, drafts, migration, targets and the add-exercises filters.
@MainActor
struct ProgramsTests {
    private func ctx() throws -> ModelContext { ModelContext(try WidgetFixedDataTests.container()) }

    private func program(_ c: ModelContext, name: String = "Push Pull Legs", workouts: [String], days: [Int] = [2, 3, 4, 5, 6, 7], exercises: Int = 3) -> UUID {
        let id = UUID()
        for (i, w) in workouts.enumerated() {
            let t = WorkoutTemplate(name: w, templateExercises: (0..<exercises).map {
                TemplateExercise(exerciseId: UUID(), exerciseName: "Ex \($0)", order: $0, targetSets: 4, targetReps: 6, targetRepsHigh: 8)
            })
            t.programId = id; t.programName = name; t.programDays = days; t.programOrder = i
            c.insert(t)
        }
        return id
    }

    private func log(_ c: ModelContext, _ t: WorkoutTemplate, daysAgo: Double, minutes: Double) {
        let w = Workout(date: Date().addingTimeInterval(-daysAgo * 86_400), duration: minutes * 60, isDraft: false)
        c.insert(w); w.template = t
    }

    private func summaries(_ c: ModelContext) -> [ProgramSummary] {
        ProgramPlan.programs(from: (try? c.fetch(FetchDescriptor<WorkoutTemplate>())) ?? [])
    }

    // MARK: Rotation and days

    @Test func workoutsRotateAcrossTheTrainingDays() {
        let a = ProgramPlan.assignment(days: [2, 3, 4, 5, 6, 7], workoutCount: 3)       // Mon–Sat
        #expect(a[2] == 0 && a[3] == 1 && a[4] == 2 && a[5] == 0 && a[6] == 1 && a[7] == 2)   // Push Mon, Pull Tue, Legs Wed, Push Thu…
        #expect(ProgramPlan.weekdays(ofWorkout: 0, days: [2, 3, 4, 5, 6, 7], workoutCount: 3) == [2, 5])
        #expect(ProgramPlan.weekdayText([2, 5]) == "MON · THU")
        #expect(ProgramPlan.assignment(days: [3, 5], workoutCount: 0).isEmpty)
        #expect(ProgramPlan.ordered([1, 7, 2]) == [2, 7, 1])                             // Monday first, Sunday last
    }

    @Test func spreadsAreSensible() {
        #expect(ProgramPlan.spread(daysPerWeek: 3) == [2, 4, 6] && ProgramPlan.spread(daysPerWeek: 4) == [2, 3, 5, 6])
        #expect(ProgramPlan.spread(daysPerWeek: 6) == [2, 3, 4, 5, 6, 7] && ProgramPlan.spread(daysPerWeek: 7).count == 7)
        for n in 1...7 { #expect(ProgramPlan.spread(daysPerWeek: n).count == n) }
        #expect(ProgramPlan.spread(daysPerWeek: 0).count == 1 && ProgramPlan.spread(daysPerWeek: 9).count == 7)
    }

    @Test func nextIsTheWorkoutAfterTheLastLoggedOne() {
        #expect(ProgramPlan.nextIndex(lastLogged: nil, count: 3) == 0)
        #expect(ProgramPlan.nextIndex(lastLogged: 1, count: 3) == 2)
        #expect(ProgramPlan.nextIndex(lastLogged: 2, count: 3) == 0)                     // wraps
    }

    @Test func nextTrainingDayIsTodayOrTheNextOne() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 2))!                // a Monday
        #expect(ProgramPlan.nextTrainingDay(from: monday, days: [2, 4], calendar: cal)! == (2, true))
        #expect(ProgramPlan.nextTrainingDay(from: monday, days: [2, 4], trainedToday: true, calendar: cal)! == (4, false))
        #expect(ProgramPlan.nextTrainingDay(from: monday, days: [1], calendar: cal)! == (1, false))
        #expect(ProgramPlan.nextTrainingDay(from: monday, days: [], calendar: cal) == nil)
    }

    // MARK: Programs and UP NEXT

    @Test func programsGroupTheirWorkoutsInRotationOrder() throws {
        let c = try ctx()
        _ = program(c, workouts: ["Pull Day", "Push Day", "Leg Day"])
        _ = program(c, name: "Full Body", workouts: ["Full Body A"], days: [2, 4, 6])
        let ps = summaries(c)
        #expect(ps.count == 2)
        let ppl = try #require(ps.first { $0.name == "Push Pull Legs" })
        #expect(ppl.workouts.map(\.name) == ["Pull Day", "Push Day", "Leg Day"] && ppl.days == [2, 3, 4, 5, 6, 7])    // order is programOrder, not the name
    }

    @Test func upNextIsTheMostRecentProgramsNextWorkout() throws {
        let c = try ctx()
        let a = program(c, name: "A", workouts: ["A1", "A2"])
        let b = program(c, name: "B", workouts: ["B1", "B2"])
        let ts = try c.fetch(FetchDescriptor<WorkoutTemplate>())
        log(c, try #require(ts.first { $0.name == "A1" }), daysAgo: 3, minutes: 50)
        log(c, try #require(ts.first { $0.name == "B1" }), daysAgo: 1, minutes: 50)
        _ = a; _ = b
        guard case .workout(let p, let i, let t)? = ProgramPlan.upNext(summaries(c)) else { Issue.record("no up next"); return }
        #expect(p.name == "B" && i == 1 && t.name == "B2")
    }

    @Test func upNextSkipsAProgramWhoseNextWorkoutIsEmptyAndFallsBackToAddExercises() throws {
        let c = try ctx()
        _ = program(c, name: "Empty", workouts: ["E1"], exercises: 0)
        _ = program(c, name: "Ready", workouts: ["R1"])
        guard case .workout(let p, _, _)? = ProgramPlan.upNext(summaries(c)) else { Issue.record("expected a ready workout"); return }
        #expect(p.name == "Ready")
        let c2 = try ctx()
        _ = program(c2, name: "Only", workouts: ["O1", "O2"], exercises: 0)
        guard case .allEmpty(let q, let i, _)? = ProgramPlan.upNext(summaries(c2)) else { Issue.record("expected ADD EXERCISES"); return }
        #expect(q.name == "Only" && i == 0)
        #expect(ProgramPlan.upNext([]) == nil)
    }

    // MARK: Workout time

    @Test func averageTimeComesOnlyFromHistory() {
        let now = Date()
        let edited = now.addingTimeInterval(-10 * 86_400)
        let sessions: [(Date, TimeInterval)] = (1...6).map { (now.addingTimeInterval(-Double($0) * 86_400), Double($0) * 600) }   // 10, 20…60 min
        #expect(ProgramPlan.averageMinutes(durations: sessions.map { ($0.0, $0.1) }, editedAt: edited) == 30)      // the latest five: 10…50
        #expect(ProgramPlan.averageMinutes(durations: [], editedAt: edited) == nil)                                // no history: no time
        #expect(ProgramPlan.averageMinutes(durations: sessions.map { ($0.0, $0.1) }, editedAt: now) == nil)        // edited since the last session
        #expect(ProgramPlan.averageMinutes(durations: [(now, 12)], editedAt: edited) == nil)                        // rounds to 0: never "~0 MIN"
    }

    @Test func targetTextAndMeta() {
        var e = TemplateExercise(exerciseId: UUID(), exerciseName: "Bench", order: 0, targetSets: 4, targetReps: 6, targetRepsHigh: 8, targetRIR: 2, restSeconds: 150)
        #expect(ProgramPlan.targetText(e) == "4 × 6–8")
        #expect(ProgramTargets.metaLine(e, equipment: "Barbell") == "BARBELL · 4 × 6–8 · RIR 2 · REST 2:30")
        e.targetRepsHigh = nil
        #expect(ProgramPlan.targetText(e) == "4 × 6")
        e.targetReps = nil
        #expect(ProgramPlan.targetText(e) == "4 SETS")
        let d = ProgramPlan.defaultExercise(id: UUID(), name: "Row", order: 2)
        #expect(d.targetSets == 3 && d.targetReps == 8 && d.targetRepsHigh == 12 && d.targetRIR == 2 && d.restSeconds == 90)
    }

    @Test func steppingTargets() {
        var e = ProgramPlan.defaultExercise(id: UUID(), name: "Row", order: 0)           // 3 × 8–12, RIR 2, rest 1:30
        ProgramTargets.adjust(&e, .sets, 1); #expect(e.targetSets == 4)
        for _ in 0..<20 { ProgramTargets.adjust(&e, .sets, -1) }; #expect(e.targetSets == 1)
        ProgramTargets.adjust(&e, .repsHigh, -1)
        for _ in 0..<10 { ProgramTargets.adjust(&e, .repsHigh, -1) }; #expect(ProgramTargets.high(e) == 8)    // the high end stops at the low end
        for _ in 0..<5 { ProgramTargets.adjust(&e, .repsLow, 1) }; #expect(ProgramTargets.low(e) == 13 && ProgramTargets.high(e) == 13)   // the low end pushes it up
        for _ in 0..<9 { ProgramTargets.adjust(&e, .rir, 1) }; #expect(e.targetRIR == 5)
        ProgramTargets.adjust(&e, .rest, 1); #expect(e.restSeconds == 105)
        for _ in 0..<100 { ProgramTargets.adjust(&e, .rest, -1) }; #expect(e.restSeconds == 15)
    }

    // MARK: The form

    @Test func theFormRulesAndDefaults() {
        var d = ProgramDraft()
        #expect(!d.canSave && d.daysPerWeek == 3 && d.workouts.count == 1)                // needs a name
        d.name = "  "; #expect(!d.canSave)
        d.name = "My Split"; #expect(d.canSave)
        d.setDaysPerWeek(5); #expect(d.days == Set([2, 3, 4, 5, 6]))
        d.toggle(2); #expect(d.daysPerWeek == 4)
        d.days = [4]; d.toggle(4); #expect(d.days == [4])                                 // the last day stays
        d.addWorkout(); d.addWorkout(); #expect(d.workouts.map(\.name) == ["Workout A", "Workout B", "Workout C"])
        let remove = d.workouts[1].id
        d.remove(remove); #expect(d.workouts.map(\.name) == ["Workout A", "Workout C"])
        d.workouts[0].name = ""; #expect(!d.canSave)
        var one = ProgramDraft(); one.name = "x"; one.remove(one.workouts[0].id); #expect(one.workouts.count == 1)   // never zero
        var ppl = ProgramDraft(); ppl.name = "PPL"; ppl.setDaysPerWeek(6); ppl.workouts = ["Push", "Pull", "Legs"].map { ProgramDraft.Workout(name: $0) }
        #expect(ppl.weekdayText(forWorkout: 0) == "MON · THU" && ppl.weekdayText(forWorkout: 2) == "WED · SAT")
    }

    @Test func templatesFillTheForm() {
        let all = ProgramTemplates.all
        #expect(all.map(\.id) == ["blank", "ppl", "ul", "fb"] && all.map(\.tag) == ["+", "6D", "4D", "3D"])
        let ppl = all[1].draft()
        #expect(ppl.name == "Push Pull Legs" && ppl.daysPerWeek == 6 && ppl.workouts.map(\.name) == ["Push Day", "Pull Day", "Leg Day"])
        #expect(ppl.workouts.allSatisfy { !$0.exercises.isEmpty && $0.exercises.allSatisfy { $0.targetRepsHigh != nil && $0.targetRIR != nil && $0.restSeconds != nil } })
        #expect(all[2].draft().daysPerWeek == 4 && all[3].draft().daysPerWeek == 3)
        #expect(all[0].draft().name.isEmpty)
    }

    @Test func creatingEditingAndDeletingAProgram() throws {
        let c = try ctx()
        var d = ProgramDraft(); d.name = "Mine"; d.setDaysPerWeek(4)
        d.workouts = [ProgramDraft.Workout(name: "Upper"), ProgramDraft.Workout(name: "Lower")]
        let id = ProgramStore.create(d, modelContext: c)
        var p = try #require(summaries(c).first { $0.id == id })
        #expect(p.name == "Mine" && p.days == [2, 3, 5, 6] && p.workouts.map(\.name) == ["Upper", "Lower"] && p.workouts.map(\.programOrder) == [0, 1])
        // Edit: rename, new days, drop one workout, add another, reorder.
        var e = ProgramStore.draft(for: p)
        e.name = "Mine v2"; e.setDaysPerWeek(3)
        e.workouts.remove(at: 0)
        e.workouts.append(ProgramDraft.Workout(name: "Arms"))
        ProgramStore.save(e, modelContext: c)
        p = try #require(summaries(c).first { $0.id == id })
        #expect(p.name == "Mine v2" && p.days == [2, 4, 6] && p.workouts.map(\.name) == ["Lower", "Arms"])
        let all = try c.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(all.first { $0.name == "Upper" }?.deletedAt != nil, "a removed workout is soft-deleted so it syncs")
        ProgramStore.delete(programId: id, modelContext: c)
        #expect(summaries(c).isEmpty)
    }

    // MARK: Migration

    @Test func oldTemplatesBecomeProgramsAndMigrationIsIdempotent() throws {
        let c = try ctx()
        for n in ["Push Day", "Pull Day", "Leg Day"] { c.insert(WorkoutTemplate(name: n, splitDays: ["P", "P", "L", "P", "P", "L"])) }
        for n in ["Upper Body", "Lower Body"] { c.insert(WorkoutTemplate(name: n, splitDays: ["U", "L", "U", "L"])) }
        c.insert(WorkoutTemplate(name: "Arm Day")); c.insert(WorkoutTemplate(name: "Core Day"))
        #expect(ProgramMigration.run(modelContext: c) == 7)
        let ps = summaries(c)
        #expect(Set(ps.map(\.name)) == ["Push Pull Legs", "Upper Lower", "My Workouts"])
        let ppl = try #require(ps.first { $0.name == "Push Pull Legs" })
        #expect(ppl.days == [2, 3, 4, 5, 6, 7] && ppl.workouts.count == 3)
        #expect(try #require(ps.first { $0.name == "Upper Lower" }).days == [2, 3, 5, 6])
        #expect(ProgramMigration.run(modelContext: c) == 0)                                 // nothing left to migrate
    }

    @Test func templatesThatNameWeekdaysJoinOneWeeklyProgram() throws {
        let c = try ctx()
        c.insert(WorkoutTemplate(name: "Push Day", splitDays: ["Mon", "Thu"]))
        c.insert(WorkoutTemplate(name: "Pull Day", splitDays: ["Tue", "Fri"]))
        c.insert(WorkoutTemplate(name: "Leg Day", splitDays: ["Wed", "Sat"]))
        ProgramMigration.run(modelContext: c)
        let p = try #require(summaries(c).first)
        #expect(summaries(c).count == 1 && p.name == "Push Pull Legs" && p.days == [2, 3, 4, 5, 6, 7])
        #expect(p.workouts.map(\.name) == ["Push Day", "Pull Day", "Leg Day"])
        #expect(ProgramMigration.weekdays(in: ["Mon", "thursday"]) == [2, 5] && ProgramMigration.weekdays(in: ["P", "L"]).isEmpty)
    }

    @Test func aMigratedProgramIdIsStableAcrossDevices() {
        #expect(ProgramPlan.stableProgramId("P,P,L") == ProgramPlan.stableProgramId("P,P,L"))
        #expect(ProgramPlan.stableProgramId("P,P,L") != ProgramPlan.stableProgramId("U,L"))
    }

    @Test func untouchedPresetsStaySyncedAfterMigration() throws {
        let c = try ctx()
        let t = WorkoutTemplate(name: "Push Day", splitDays: ["P", "L"])
        t.updatedAt = ProgramMigration.epoch; t.syncedAt = ProgramMigration.epoch
        c.insert(t)
        ProgramMigration.run(modelContext: c)
        #expect(t.programId != nil && t.updatedAt == ProgramMigration.epoch, "no cloud write for a preset nobody edited")
    }

    // MARK: Add exercises

    private func lib(_ c: ModelContext) -> [Exercise] {
        let specs: [(String, [MuscleGroup], MovementPattern, EquipmentType)] = [
            ("Barbell Bench Press", [.chest], .push, .barbell), ("Dumbbell Bench Press", [.chest], .push, .dumbbell), ("Smith Machine Bench Press", [.chest], .push, .smithMachine),
            ("Pull Up", [.lats], .pull, .bodyweight), ("Lateral Raise", [.sideDelts], .isolation, .dumbbell), ("Barbell Squat", [.quads], .squat, .barbell),
            ("Conventional Deadlift", [.hamstrings], .hinge, .barbell), ("Plank", [.abs], .isolation, .bodyweight),
        ]
        return specs.map { s in let e = Exercise(name: s.0, primaryMuscleGroups: s.1, equipmentType: s.3, movementPattern: s.2); c.insert(e); return e }
    }

    @Test func exercisesWithTypesGroupAndSearchMatchesTheTypes() throws {
        let c = try ctx(); let ex = lib(c)
        let all = ProgramPicker.items(exercises: ex, query: "", move: .all, muscle: .all)
        let bench = try #require(all.first { $0.title == "Bench Press" })
        #expect(bench.isGroup && bench.exercises.count == 3 && ProgramPicker.typesLabel(typeCount: 3, picked: 0) == "3 TYPES")
        #expect(ProgramPicker.typesLabel(typeCount: 3, picked: 1) == "1 PICKED · 3 TYPES")
        #expect(all.contains { $0.title == "Plank" && !$0.isGroup })
        // "smith" matches a type, so its group shows.
        #expect(ProgramPicker.items(exercises: ex, query: "smith", move: .all, muscle: .all).map(\.title) == ["Bench Press"])
        #expect(ProgramPicker.items(exercises: ex, query: "zzz", move: .all, muscle: .all).isEmpty)
    }

    @Test func movementAndMuscleFiltersCombine() throws {
        let c = try ctx(); let ex = lib(c)
        #expect(ProgramPicker.items(exercises: ex, query: "", move: .pull, muscle: .all).map(\.title) == ["Pull Up"])
        #expect(Set(ProgramPicker.items(exercises: ex, query: "", move: .all, muscle: .shoulders).map(\.title)) == ["Lateral Raise"])
        #expect(ProgramPicker.items(exercises: ex, query: "", move: .push, muscle: .legs).isEmpty)
        #expect(ProgramPicker.items(exercises: ex, query: "", move: .squat, muscle: .legs).map(\.title) == ["Barbell Squat"])
        #expect(ProgramPicker.items(exercises: ex, query: "", move: .all, muscle: .core).map(\.title) == ["Plank"])
        let present = Set([ex[0].id])
        #expect(ProgramPicker.items(exercises: ex, query: "bench", move: .all, muscle: .chest, excluded: present).first?.exercises.count == 2)   // already in the workout
        #expect(ProgramPicker.dockTitle(count: 0) == "PICK EXERCISES" && ProgramPicker.dockTitle(count: 1) == "ADD 1 EXERCISE" && ProgramPicker.dockTitle(count: 3) == "ADD 3 EXERCISES")
    }

    // MARK: Stardust limiter

    @Test func onlyTheTopFourStardustButtonsAnimateDockedFirst() {
        let ids = (0..<6).map { _ in UUID() }
        var claims: [UUID: StardustLimiter.Claim] = [:]
        for (i, id) in ids.enumerated() { claims[id] = .init(priority: 5, y: CGFloat(100 * i)) }
        claims[ids[5]] = .init(priority: 10, y: 800)                                       // the docked primary, lowest on screen
        let win = StardustLimiter.winners(claims, limit: 4)
        #expect(win.count == 4 && win.contains(ids[5]))                                    // docked wins
        #expect(win == [ids[5], ids[0], ids[1], ids[2]])                                   // then the top-most
    }
}
