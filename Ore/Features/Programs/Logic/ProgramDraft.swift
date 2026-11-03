import Foundation
import SwiftData

/// The New / Edit program form (Ore Programs 03, 04, 13): name, training days, and the list of workouts. Nothing is saved until CREATE
/// PROGRAM / SAVE CHANGES.
struct ProgramDraft: Equatable {
    struct Workout: Identifiable, Equatable {
        var id = UUID()
        var name: String
        /// The saved workout this row edits (nil = new).
        var templateId: UUID?
        /// What a template starts the new workout with.
        var exercises: [TemplateExercise] = []

        static func == (a: Workout, b: Workout) -> Bool { a.id == b.id && a.name == b.name && a.templateId == b.templateId && a.exercises.map(\.id) == b.exercises.map(\.id) }
    }

    var name = ""
    var days: Set<Int> = Set(ProgramPlan.spread(daysPerWeek: 3))
    var workouts: [Workout] = [Workout(name: "Workout A")]
    /// Set when editing an existing program.
    var programId: UUID?

    var daysPerWeek: Int { days.count }
    var isEditing: Bool { programId != nil }

    /// CREATE PROGRAM stays grey until it has a name, days and at least one workout.
    var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !days.isEmpty && !workouts.isEmpty && workouts.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty } }

    /// Picking a count picks a sensible spread.
    mutating func setDaysPerWeek(_ n: Int) { days = Set(ProgramPlan.spread(daysPerWeek: n)) }

    /// Toggles a weekday; the last one cannot be removed.
    mutating func toggle(_ weekday: Int) {
        if days.contains(weekday) { if days.count > 1 { days.remove(weekday) } } else { days.insert(weekday) }
    }

    /// "Workout B" after "Workout A"…
    mutating func addWorkout() {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let used = Set(workouts.map { $0.name.uppercased() })
        let next = letters.map { "Workout \($0)" }.first { !used.contains($0.uppercased()) } ?? "Workout \(workouts.count + 1)"
        workouts.append(Workout(name: next))
    }

    /// × on a workout; there is always at least one.
    mutating func remove(_ id: UUID) { if workouts.count > 1 { workouts.removeAll { $0.id == id } } }

    /// "MON · THU": the weekdays workout `index` lands on.
    func weekdayText(forWorkout index: Int) -> String {
        ProgramPlan.weekdayText(ProgramPlan.weekdays(ofWorkout: index, days: Array(days), workoutCount: workouts.count))
    }

    var daysText: String { "\(daysPerWeek) DAY\(daysPerWeek == 1 ? "" : "S")" }
    var pickedText: String { "\(daysPerWeek) PICKED" }
}

/// The "Start from" choices: Blank and the three presets, as drafts.
enum ProgramTemplates {
    struct Choice: Identifiable {
        let id: String
        let tag: String
        let name: String
        let blurb: String
        let draft: () -> ProgramDraft
        var meta: String { let d = draft(); return ProgramPlan.metaLine(workouts: d.workouts.count, days: d.daysPerWeek) }
    }

    private static func draft(name: String, days: Int, from templates: [WorkoutTemplate]) -> ProgramDraft {
        var d = ProgramDraft()
        d.name = name
        d.setDaysPerWeek(days)
        d.workouts = templates.map { t in
            ProgramDraft.Workout(name: t.name, exercises: t.templateExercises.map { e in
                var x = e
                if x.targetRepsHigh == nil, let low = x.targetReps { x.targetRepsHigh = low >= 12 ? low + 3 : low + 2 }
                if x.targetRIR == nil { x.targetRIR = 2 }
                if x.restSeconds == nil { x.restSeconds = 90 }
                return x
            })
        }
        return d
    }

    static var all: [Choice] {
        [
            Choice(id: "blank", tag: "+", name: "Blank", blurb: "Start from scratch and add your own workouts.", draft: { ProgramDraft() }),
            Choice(id: "ppl", tag: "6D", name: "Push Pull Legs", blurb: "Push, Pull and Legs take turns across six days. High frequency.",
                   draft: { draft(name: "Push Pull Legs", days: 6, from: TemplateSeedService.pplTemplates) }),
            Choice(id: "ul", tag: "4D", name: "Upper Lower", blurb: "Two upper and two lower sessions a week. Balanced frequency.",
                   draft: { draft(name: "Upper Lower", days: 4, from: TemplateSeedService.upperLowerTemplates) }),
            Choice(id: "fb", tag: "3D", name: "Full Body", blurb: "Every major muscle group each session. Great for beginners.",
                   draft: { draft(name: "Full Body", days: 3, from: TemplateSeedService.fullBodyTemplates) }),
        ]
    }
}

/// Saving, editing and deleting programs. Every change marks the touched workouts updated so it syncs.
@MainActor
enum ProgramStore {
    @discardableResult
    static func create(_ draft: ProgramDraft, modelContext: ModelContext) -> UUID {
        let id = UUID()
        let library = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let days = ProgramPlan.ordered(Array(draft.days))
        let made: [WorkoutTemplate] = draft.workouts.enumerated().map { i, w in
            let t = WorkoutTemplate(name: w.name.trimmingCharacters(in: .whitespaces), templateExercises: w.exercises)
            t.programId = id
            t.programName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            t.programDays = days
            t.programOrder = i
            return t
        }
        TemplateSeedService.resolveExerciseLinks(in: made, exercises: library)
        for t in made { modelContext.insert(t) }
        try? modelContext.save()
        return id
    }

    /// SAVE CHANGES: renames, new days, new / removed / reordered workouts. Removed workouts are soft-deleted (their sessions stay in History).
    static func save(_ draft: ProgramDraft, modelContext: ModelContext) {
        guard let programId = draft.programId else { return }
        let all = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let existing = Dictionary(uniqueKeysWithValues: all.filter { $0.programId == programId && $0.deletedAt == nil }.map { ($0.id, $0) })
        let keep = Set(draft.workouts.compactMap(\.templateId))
        for (id, t) in existing where !keep.contains(id) { modelContext.softDelete(t) }
        let library = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let days = ProgramPlan.ordered(Array(draft.days))
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        for (i, w) in draft.workouts.enumerated() {
            let t: WorkoutTemplate
            if let id = w.templateId, let e = existing[id] { t = e } else {
                t = WorkoutTemplate(name: w.name, templateExercises: w.exercises)
                TemplateSeedService.resolveExerciseLinks(in: [t], exercises: library)
                modelContext.insert(t)
            }
            let workoutName = w.name.trimmingCharacters(in: .whitespaces)
            // Only a real change dirties a workout (no cloud write for a save that changed nothing).
            if t.name != workoutName || t.programName != name || t.programDays != days || t.programOrder != i || t.programId != programId {
                t.name = workoutName; t.programName = name; t.programDays = days; t.programOrder = i; t.programId = programId
                t.markUpdated()
            }
        }
        try? modelContext.save()
    }

    static func delete(programId: UUID, modelContext: ModelContext) {
        let all = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        for t in all where t.programId == programId && t.deletedAt == nil { modelContext.softDelete(t) }
        try? modelContext.save()
    }

    /// A draft of an existing program for the Edit screen.
    static func draft(for p: ProgramSummary) -> ProgramDraft {
        var d = ProgramDraft()
        d.programId = p.id
        d.name = p.name
        d.days = Set(p.days)
        d.workouts = p.workouts.map { ProgramDraft.Workout(name: $0.name, templateId: $0.id) }
        return d
    }
}
