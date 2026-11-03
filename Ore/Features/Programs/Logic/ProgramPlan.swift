import Foundation
import CryptoKit

/// A program as the screens see it (Ore Programs): its workouts in rotation order and the weekdays it trains on.
struct ProgramSummary: Identifiable {
    let id: UUID
    let name: String
    /// Calendar weekdays (1 = Sunday), in week order starting Monday.
    let days: [Int]
    let workouts: [WorkoutTemplate]

    var exerciseCount: Int { workouts.reduce(0) { $0 + $1.templateExercises.count } }
}

/// The pure rules of Program → Workouts → Exercises: grouping, the weekly spread, how workouts rotate over the training days, which one is
/// next, UP NEXT across programs, and the "AVG N MIN" only history can give. No SwiftUI; everything here is unit-tested.
enum ProgramPlan {
    /// Monday first, as the week strips draw it. Values are `Calendar` weekdays (1 = Sunday).
    static let weekOrder = [2, 3, 4, 5, 6, 7, 1]
    static let weekLetters = ["M", "T", "W", "T", "F", "S", "S"]
    static let weekdayNames = [1: "SUN", 2: "MON", 3: "TUE", 4: "WED", 5: "THU", 6: "FRI", 7: "SAT"]

    // MARK: Days

    /// Unique, in week order (Monday first).
    static func ordered(_ days: [Int]) -> [Int] { weekOrder.filter { Set(days).contains($0) } }

    /// A sensible spread for N training days a week: 1 → Wed; 2 → Mon Thu; 3 → Mon Wed Fri; 4 → Mon Tue Thu Fri; 5 → Mon–Fri; 6 → Mon–Sat; 7 → all.
    static func spread(daysPerWeek n: Int) -> [Int] {
        switch max(1, min(7, n)) {
        case 1: [4]
        case 2: [2, 5]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 6]
        case 5: [2, 3, 4, 5, 6]
        case 6: [2, 3, 4, 5, 6, 7]
        default: weekOrder
        }
    }

    // MARK: Rotation

    /// The i-th training day of the week gets workout i mod n: PPL on Mon–Sat is Push Mon, Pull Tue, Legs Wed, Push Thu…
    static func assignment(days: [Int], workoutCount n: Int) -> [Int: Int] {
        guard n > 0 else { return [:] }
        var out: [Int: Int] = [:]
        for (i, d) in ordered(days).enumerated() { out[d] = i % n }
        return out
    }

    /// The weekdays workout `index` lands on in the week strip.
    static func weekdays(ofWorkout index: Int, days: [Int], workoutCount n: Int) -> [Int] {
        let a = assignment(days: days, workoutCount: n)
        return ordered(days).filter { a[$0] == index }
    }

    /// "MON · THU".
    static func weekdayText(_ days: [Int]) -> String { days.compactMap { weekdayNames[$0] }.joined(separator: " · ") }

    /// The workout after the last one logged in the program, wrapping; the first when nothing was logged.
    static func nextIndex(lastLogged: Int?, count: Int) -> Int {
        guard count > 0 else { return 0 }
        guard let lastLogged else { return 0 }
        return (lastLogged + 1) % count
    }

    /// The training day the next workout falls on: today when it is one (and nothing was logged today), else the next one in the week.
    static func nextTrainingDay(from now: Date, days: [Int], trainedToday: Bool = false, calendar: Calendar = .current) -> (weekday: Int, isToday: Bool)? {
        let set = Set(days)
        guard !set.isEmpty else { return nil }
        let today = calendar.component(.weekday, from: now)
        for ahead in (trainedToday ? 1 : 0)...7 {
            let wd = (today - 1 + ahead) % 7 + 1
            if set.contains(wd) { return (wd, ahead == 0) }
        }
        return nil
    }

    // MARK: Programs from templates

    /// Live templates that carry a program id, grouped into programs (workouts by `programOrder`, then name), oldest program first.
    static func programs(from templates: [WorkoutTemplate]) -> [ProgramSummary] {
        let live = templates.filter { $0.deletedAt == nil && $0.programId != nil }
        let grouped = Dictionary(grouping: live) { $0.programId! }
        return grouped.map { id, ts in
            let sorted = ts.sorted { ($0.programOrder, $0.name) < ($1.programOrder, $1.name) }
            let name = sorted.compactMap(\.programName).first ?? sorted.first?.name ?? "Program"
            return ProgramSummary(id: id, name: name, days: ordered(sorted.first?.programDays ?? []), workouts: sorted)
        }
        .sorted { ($0.workouts.map(\.createdAt).min() ?? .distantPast, $0.name) < ($1.workouts.map(\.createdAt).min() ?? .distantPast, $1.name) }
    }

    /// Index (in rotation order) of the workout most recently logged in the program.
    static func lastLoggedIndex(in p: ProgramSummary) -> Int? {
        var best: (index: Int, date: Date)?
        for (i, t) in p.workouts.enumerated() {
            if let d = t.liveWorkouts.map(\.date).max(), best == nil || d > best!.date { best = (i, d) }
        }
        return best?.index
    }

    static func lastUsed(_ p: ProgramSummary) -> Date? { p.workouts.flatMap(\.liveWorkouts).map(\.date).max() }

    static func nextWorkout(of p: ProgramSummary) -> (index: Int, template: WorkoutTemplate)? {
        guard !p.workouts.isEmpty else { return nil }
        let i = nextIndex(lastLogged: lastLoggedIndex(in: p), count: p.workouts.count)
        return (i, p.workouts[i])
    }

    enum UpNext {
        case workout(ProgramSummary, index: Int, template: WorkoutTemplate)
        /// Every program's next workout is empty: the button becomes ADD EXERCISES and opens that workout in edit mode.
        case allEmpty(ProgramSummary, index: Int, template: WorkoutTemplate)
    }

    /// The program that is up next: most recently used first (then the oldest), skipping any whose next workout is empty.
    static func upNext(_ programs: [ProgramSummary]) -> UpNext? {
        let order = programs.sorted { (lastUsed($0) ?? .distantPast) > (lastUsed($1) ?? .distantPast) }
        var firstEmpty: (ProgramSummary, Int, WorkoutTemplate)?
        for p in order {
            guard let n = nextWorkout(of: p) else { continue }
            if !n.template.templateExercises.isEmpty { return .workout(p, index: n.index, template: n.template) }
            if firstEmpty == nil { firstEmpty = (p, n.index, n.template) }
        }
        return firstEmpty.map { .allEmpty($0.0, index: $0.1, template: $0.2) }
    }

    // MARK: Workout time

    /// "AVG N MIN": the mean of the last 5 sessions of this workout, only from history; none if it has no sessions, it was edited since the
    /// last one, or the mean rounds to 0. Never "~0 MIN".
    static func averageMinutes(durations: [(date: Date, seconds: TimeInterval)], editedAt: Date) -> Int? {
        let recent = durations.sorted { $0.date > $1.date }.prefix(5)
        guard let latest = recent.first, editedAt <= latest.date else { return nil }
        let mean = recent.reduce(0) { $0 + $1.seconds } / Double(recent.count) / 60
        let minutes = Int(mean.rounded())
        return minutes >= 1 ? minutes : nil
    }

    static func averageMinutes(for t: WorkoutTemplate) -> Int? {
        averageMinutes(durations: t.liveWorkouts.map { ($0.date, $0.duration) }, editedAt: t.updatedAt)
    }

    // MARK: Text

    /// "4 × 6–8", "4 × 8", or "4 SETS" with no reps.
    static func targetText(_ e: TemplateExercise) -> String {
        guard let low = e.targetReps else { return "\(e.targetSets) SETS" }
        if let high = e.targetRepsHigh, high > low { return "\(e.targetSets) × \(low)–\(high)" }
        return "\(e.targetSets) × \(low)"
    }

    /// "REST 2:30".
    static func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    /// Defaults for a freshly added exercise: 3 × 8–12, RIR 2, rest 1:30.
    static func defaultExercise(id: UUID, name: String, order: Int) -> TemplateExercise {
        TemplateExercise(exerciseId: id, exerciseName: name, order: order, targetSets: 3, targetReps: 8, targetRepsHigh: 12, targetRIR: 2, restSeconds: 90)
    }

    /// "3 WORKOUTS · 6 DAYS/WK".
    static func metaLine(workouts: Int, days: Int) -> String { "\(workouts) WORKOUT\(workouts == 1 ? "" : "S") · \(days) DAY\(days == 1 ? "" : "S")/WK" }

    /// The name a program of these workouts is known by ("Push Pull Legs", "Upper Lower"…), else the names joined.
    static func derivedName(_ names: [String]) -> String {
        if names.count == 1 { return names[0] }
        let lower = names.map { $0.lowercased() }
        let has = { (k: String) in lower.contains { $0.contains(k) } }
        if has("push") && has("pull") && has("leg") { return "Push Pull Legs" }
        if has("push") && has("leg") { return "Push Legs" }
        if has("pull") && has("leg") { return "Pull Legs" }
        if has("push") && has("pull") { return "Push Pull" }
        if has("upper") && has("lower") { return "Upper Lower" }
        if has("full") { return "Full Body" }
        return names.joined(separator: " / ")
    }

    /// A stable id for a migrated or seeded program, so every device converges on the same one.
    static func stableProgramId(_ key: String) -> UUID {
        var b = Array(SHA256.hash(data: Data("ore.program.\(key)".utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50; b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

/// The targets a workout stores for each exercise (sets, rep range, RIR, rest) and how the editor steps them.
enum ProgramTargets {
    enum Field: String { case sets, repsLow, repsHigh, rir, rest }

    static let defaultRest = 90
    static let restStep = 15

    static func sets(_ e: TemplateExercise) -> Int { e.targetSets }
    static func low(_ e: TemplateExercise) -> Int { e.targetReps ?? 8 }
    static func high(_ e: TemplateExercise) -> Int { max(low(e), e.targetRepsHigh ?? low(e)) }
    static func rir(_ e: TemplateExercise) -> Int? { e.targetRIR }
    static func rest(_ e: TemplateExercise) -> Int { e.restSeconds ?? defaultRest }

    /// One tap of − / + (dir -1 / 1): sets 1–12, reps low 1–50 (the high end never goes below it), reps high low–60, RIR 0–5, rest ±15 s (0:15–10:00).
    static func adjust(_ e: inout TemplateExercise, _ field: Field, _ dir: Int) {
        switch field {
        case .sets:
            e.targetSets = max(1, min(12, e.targetSets + dir))
        case .repsLow:
            let lo = max(1, min(50, low(e) + dir))
            e.targetReps = lo
            if let h = e.targetRepsHigh, h < lo { e.targetRepsHigh = lo }
        case .repsHigh:
            let hi = max(low(e), min(60, high(e) + dir))
            e.targetRepsHigh = hi
        case .rir:
            e.targetRIR = max(0, min(5, (e.targetRIR ?? 2) + dir))
        case .rest:
            e.restSeconds = max(15, min(600, rest(e) + dir * restStep))
        }
    }

    /// "BARBELL · 4 × 6–8 · RIR 2 · REST 2:30".
    static func metaLine(_ e: TemplateExercise, equipment: String?) -> String {
        var parts: [String] = []
        if let equipment, !equipment.isEmpty { parts.append(equipment.uppercased()) }
        parts.append(ProgramPlan.targetText(e))
        if let r = e.targetRIR { parts.append("RIR \(r)") }
        parts.append("REST \(ProgramPlan.clock(rest(e)))")
        return parts.joined(separator: " · ")
    }
}
