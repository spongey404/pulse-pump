import Foundation

// MARK: - Widget data contract
//
// The app computes one snapshot after each workout (WidgetDataService) and stores it in the
// App Group. Pieces resolve their display values from it; with no data yet they fall back to
// the catalog's sample values so the builder and gallery always have something to draw.

struct PumpWidgetSnapshot: Codable, Equatable {
    struct PR: Codable, Equatable { var weight: Double; var date: Date }
    struct Template: Codable, Equatable { var name: String; var exercises: Int }

    var hasData = false
    var updated = Date()

    /// Display unit chosen by the user. ALL numeric weights in this snapshot are kg (like everywhere
    /// else); widget views convert and label through `unit`. Optional so older stored snapshots still decode.
    var weightUnit: UnitPreference?
    var unit: UnitPreference { weightUnit ?? .kg }

    var streak = 0
    var sessionsThisWeek = 0
    var sessionGoal = 5
    var improvedCount = 0
    var improvedTotal = 0
    var topGainKg = 0.0
    var topGainExercise = ""
    var bodyweight = 0.0

    var prs: [String: PR] = [:]
    /// Mon–Sun, this week.
    var setsPerDay = [Double](repeating: 0, count: 7)
    var volumePerDay = [Double](repeating: 0, count: 7)
    var improvedPerDay = [Double](repeating: 0, count: 7)
    var todayIndex = 0
    /// Weekly estimated 1RM series (oldest → newest), by exercise name.
    var e1rm: [String: [Double]] = [:]
    /// BodyHeat regions 0–1: volume over 7 days, and recency fade over 48h.
    var bodyVolume: [String: Double] = [:]
    var bodyRecency: [String: Double] = [:]

    var nextName = ""
    var nextDay = ""
    var nextExercises = 0
    var nextEstMinutes = 0
    var nextFirst = ""
    var templates: [Template] = []
    var weekNumber = 1

    /// Data for the fixed widget set (see PumpWidgetSnapshot+Fixed.swift).
    var _fixed: PWFixedData?
}

// MARK: - Resolution

extension PumpWidgetSnapshot {
    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
    /// Weight (stored kg) in the display unit, one decimal at most.
    private func fmtW(_ kg: Double) -> String { fmt(unit.display(kg)) }

    private func ago(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days >= 14 ? "\(days / 7)W AGO" : "\(max(days, 0))D AGO"
    }

    /// Display values for a placed piece.
    func metric(for piece: PumpWidgetPiece) -> PumpPieceMetric {
        let info = piece.type.info
        let sample = info.metrics.first { $0.id == piece.metric } ?? info.metrics[0]
        guard hasData else {
            // Pickers (PR / quick) keep the chosen name even without data.
            var m = sample
            if piece.type == .pr { m.k = shortCaption(piece.metric) + " PR"; m.label = piece.metric }
            if piece.type == .quick { m.t = shortTitle(piece.metric); m.label = piece.metric }
            return m
        }
        var m = sample
        switch piece.type {
        case .num:
            switch piece.metric {
            case "streak": m.v = "\(streak)"
            case "sessions": m.v = "\(sessionsThisWeek)/\(sessionGoal)"
            case "improved": m.v = "\(improvedCount)/\(improvedTotal)"
            case "topgain":
                m.v = (topGainKg >= 0 ? "+" : "") + fmtW(topGainKg)
                m.u = topGainExercise.isEmpty ? unit.label : unit.label + " · " + shortCaption(topGainExercise)
            case "bw": m.v = bodyweight > 0 ? fmtW(bodyweight) : "—"; m.d = ""; m.u = unit.label
            default: break
            }
        case .pr:
            m.label = piece.metric
            m.k = shortCaption(piece.metric) + " PR"
            m.u = unit.label
            if let pr = bestPR(for: piece.metric) { m.v = fmtW(pr.weight); m.ago = ago(pr.date) } else { m.v = "—"; m.ago = "" }
        case .bars:
            switch piece.metric {
            case "volume": m.data = volumePerDay
            case "improved": m.data = improvedPerDay
            default: m.data = setsPerDay
            }
            m.today = todayIndex
        case .spark:
            let name = piece.metric == "e1rm_squat" ? "Squat" : "Bench Press"
            if piece.metric != "bw", let series = e1rm[name], series.count > 1 {
                m.data = series.map(unit.display); m.v = fmtW(series.last ?? 0); m.u = unit.label
            }
        case .body:
            m.body = piece.metric == "recency" ? bodyRecency : bodyVolume
        case .next:
            if !nextName.isEmpty {
                m.k = "NEXT · " + nextDay
                m.t = nextName.uppercased()
                m.meta = m.start ? "\(nextExercises) EX · ~\(nextEstMinutes) MIN" : nextFirst.uppercased()
            }
        case .quick:
            m.label = piece.metric
            let tmpl = templates.first { $0.name == piece.metric }
            m.t = shortTitle(piece.metric)
            m.meta = tmpl.map { "\($0.exercises) EX" } ?? ""
        case .prog:
            if piece.metric == "goal" {
                m.n = max(sessionGoal, 1); m.done = min(sessionsThisWeek, m.n)
                m.v = "\(sessionsThisWeek)/\(sessionGoal)"; m.k = "GOAL · WK \(weekNumber)"
            }
        }
        return m
    }

    /// Exact match first; otherwise the heaviest lift whose name contains the chosen one
    /// ("Bench Press" finds "Barbell Bench Press"), ignoring incline / decline variants.
    func bestPR(for name: String) -> PR? {
        if let exact = prs[name] { return exact }
        let q = name.lowercased()
        let variants = ["incline", "decline", "dumbbell", "close", "smith"]
        return prs.filter { key, _ in
            let k = key.lowercased()
            return k.contains(q) && !variants.contains(where: { k.contains($0) && !q.contains($0) })
        }.values.max { $0.weight < $1.weight }
    }

    func shortCaption(_ name: String) -> String {
        let up = name.uppercased()
        return up.count <= 10 ? up : String(up.prefix(10))
    }

    func shortTitle(_ name: String) -> String {
        let first = name.uppercased().split(separator: " ").first.map(String.init) ?? name.uppercased()
        return first
    }

    /// Deep link for pieces that start a workout.
    static func startURL(template: String?) -> URL? {
        var c = URLComponents()
        c.scheme = "pulsepump"; c.host = "start-workout"
        if let template { c.queryItems = [URLQueryItem(name: "template", value: template)] }
        return c.url
    }
}
