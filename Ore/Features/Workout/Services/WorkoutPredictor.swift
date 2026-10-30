import Foundation

/// Pure "what should I train next" logic (no SwiftData), so it is unit-testable.
/// `WorkoutViewModel.predictNextWorkout` feeds it history, template names and the split.
enum WorkoutPredictor {

    /// Next workout name. Prefers the learned pattern, but only when it resolves to a real
    /// template; otherwise falls back to the split's next day (resolved to a template when one
    /// matches). `history` is newest-first template names of finished workouts.
    static func predict(history: [String], templateNames: [String], split: Split?, todayWeekday: Int) -> String? {
        if let detected = detectNextByPattern(from: history),
           let template = resolveTemplate(detected, among: templateNames) {
            return template
        }
        guard let split else { return nil }
        if let label = nextFromSplit(days: split.days, lastName: history.first, todayWeekday: todayWeekday) {
            return resolveTemplate(label, among: templateNames) ?? label
        }
        return split.days.isEmpty && split.type != .none ? split.type.displayName : nil
    }

    // MARK: Pattern

    /// Frequency-based pattern detection: what most often followed the last session. Ties go to
    /// the most recent successor, so the result is deterministic. No day-of-week assumptions.
    static func detectNextByPattern(from names: [String]) -> String? {
        guard names.count >= 2, let last = names.first else { return nil }
        let lastKey = last.lowercased()

        // names is newest-first; names[i] came AFTER names[i+1] in real time.
        var counts: [String: (name: String, count: Int, recency: Int)] = [:]
        for i in 1..<names.count where names[i].lowercased() == lastKey {
            let successor = names[i - 1]
            let key = successor.lowercased()
            let prev = counts[key]
            counts[key] = (successor, (prev?.count ?? 0) + 1, min(prev?.recency ?? Int.max, i))
        }
        if let best = counts.values.max(by: { ($0.count, -$0.recency) < ($1.count, -$1.recency) }) {
            return best.name
        }

        // Fuzzy keyword fallback for named splits.
        if lastKey.contains("push") { return names.first { $0.lowercased().contains("pull") } ?? "Pull Day" }
        if lastKey.contains("pull") { return names.first { $0.lowercased().contains("leg") } ?? "Leg Day" }
        if lastKey.contains("leg") { return names.first { $0.lowercased().contains("push") } ?? "Push Day" }
        if lastKey.contains("upper") { return names.first { $0.lowercased().contains("lower") } ?? "Lower" }
        if lastKey.contains("lower") { return names.first { $0.lowercased().contains("upper") } ?? "Upper" }
        if lastKey.contains("full") { return last }
        return nil
    }

    // MARK: Template matching

    private static let keywordGroups = ["push", "pull", "leg", "upper", "lower", "full", "torso", "limb",
                                        "chest", "back", "shoulder", "arm"]

    static func normalised(_ s: String) -> String {
        var out = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" day", " workout", " body"] where out.hasSuffix(suffix) { out = String(out.dropLast(suffix.count)) }
        return out
    }

    /// The template name that `name` refers to, or nil. Exact (case-insensitive) first, then
    /// normalised equality ("Push" == "Push Day"), then containment, then a shared keyword.
    static func resolveTemplate(_ name: String, among templates: [String]) -> String? {
        let lower = name.lowercased()
        if let exact = templates.first(where: { $0.lowercased() == lower }) { return exact }
        let norm = normalised(name)
        guard !norm.isEmpty else { return nil }
        if let same = templates.first(where: { normalised($0) == norm }) { return same }
        if let contains = templates.first(where: {
            let n = normalised($0); return !n.isEmpty && (n.contains(norm) || norm.contains(n))
        }) { return contains }
        for key in keywordGroups where lower.contains(key) {
            if let kw = templates.first(where: { $0.lowercased().contains(key) }) { return kw }
        }
        return nil
    }

    /// True when two workout names clearly describe the same split day.
    static func sameDay(_ a: String, _ b: String) -> Bool {
        let na = normalised(a), nb = normalised(b)
        if na == nb || (!na.isEmpty && !nb.isEmpty && (na.contains(nb) || nb.contains(na))) { return true }
        return keywordGroups.contains { a.lowercased().contains($0) && b.lowercased().contains($0) }
    }

    // MARK: Split

    /// Next day of the split after `lastName` (cycling Mon-first); with no usable history, the
    /// first scheduled day on or after today.
    static func nextFromSplit(days: [SplitDay], lastName: String?, todayWeekday: Int) -> String? {
        let cycle = days.sorted { ($0.dayOfWeek + 5) % 7 < ($1.dayOfWeek + 5) % 7 }
        guard !cycle.isEmpty else { return nil }
        func label(_ d: SplitDay) -> String { d.label.isEmpty ? d.workoutType : d.label }
        if let lastName,
           let i = cycle.lastIndex(where: { sameDay(label($0), lastName) || sameDay($0.workoutType, lastName) }) {
            return label(cycle[(i + 1) % cycle.count])
        }
        let todayIndex = (todayWeekday + 5) % 7
        let upcoming = cycle.first { ($0.dayOfWeek + 5) % 7 >= todayIndex } ?? cycle[0]
        return label(upcoming)
    }
}
