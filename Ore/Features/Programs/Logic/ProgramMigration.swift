import Foundation
import SwiftData

/// Moves templates made before Program → Workouts → Exercises into programs. Templates that shared a rotation (the old programs, e.g. Push /
/// Pull / Legs) stay together as one program; the loose ones (Push Day, Pull Day… on their own) join a single program, "My Workouts".
/// Idempotent, and a program id is derived from the group, so two devices migrating the same data agree.
enum ProgramMigration {
    static let epoch = Date(timeIntervalSince1970: 0)

    @discardableResult
    static func run(modelContext: ModelContext) -> Int {
        let all = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let legacy = all.filter { $0.deletedAt == nil && $0.programId == nil }
        guard !legacy.isEmpty else { return 0 }

        var groups: [String: [WorkoutTemplate]] = [:]
        var scheduled: [WorkoutTemplate] = []
        var loose: [WorkoutTemplate] = []
        for t in legacy {
            if t.splitDays.isEmpty { loose.append(t) }
            else if !weekdays(in: t.splitDays).isEmpty { scheduled.append(t) }          // "Mon", "Thu": a weekly schedule
            else { groups[t.splitDays.joined(separator: ","), default: []].append(t) }  // "P", "P", "L": a rotation shared by a preset's workouts
        }
        var migrated = 0
        if !scheduled.isEmpty {
            // Workouts that name their weekdays belong to one weekly program; it trains on the union of those days.
            let days = ProgramPlan.ordered(Array(Set(scheduled.flatMap { weekdays(in: $0.splitDays) })))
            let byFirstDay = scheduled.sorted { (firstDay($0), $0.name) < (firstDay($1), $1.name) }
            migrated += assign(byFirstDay, programKey: "scheduled", days: days, name: ProgramPlan.derivedName(byFirstDay.map(\.name)), keepOrder: true)
        }
        for (key, templates) in groups.sorted(by: { $0.key < $1.key }) {
            migrated += assign(templates, programKey: key, days: ProgramPlan.spread(daysPerWeek: templates.first?.splitDays.count ?? templates.count),
                               name: ProgramPlan.derivedName(sorted(templates).map(\.name)))
        }
        if !loose.isEmpty {
            migrated += assign(loose, programKey: "loose", days: ProgramPlan.spread(daysPerWeek: min(7, max(1, loose.count))), name: "My Workouts")
        }
        try? modelContext.save()
        return migrated
    }

    private static let weekdayByName: [String: Int] = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]

    /// The weekdays named in a template's old `splitDays` ("Mon", "Thursday"…); empty for a rotation like ["P", "P", "L"].
    static func weekdays(in tokens: [String]) -> [Int] { tokens.compactMap { weekdayByName[String($0.lowercased().prefix(3))] } }

    private static func firstDay(_ t: WorkoutTemplate) -> Int {
        ProgramPlan.weekOrder.firstIndex(of: weekdays(in: t.splitDays).min { ProgramPlan.weekOrder.firstIndex(of: $0)! < ProgramPlan.weekOrder.firstIndex(of: $1)! } ?? 2) ?? 0
    }

    private static func sorted(_ ts: [WorkoutTemplate]) -> [WorkoutTemplate] { ts.sorted { ($0.createdAt, $0.name) < ($1.createdAt, $1.name) } }

    private static func assign(_ templates: [WorkoutTemplate], programKey: String, days: [Int], name: String, keepOrder: Bool = false) -> Int {
        let id = ProgramPlan.stableProgramId(programKey)
        for (i, t) in (keepOrder ? templates : sorted(templates)).enumerated() {
            let pristinePreset = t.updatedAt == epoch && t.syncedAt == epoch      // never edited: stays "synced", costs no cloud write
            t.programId = id
            t.programName = name
            t.programDays = days
            t.programOrder = i
            if !pristinePreset { t.markUpdated() }
        }
        return templates.count
    }
}
