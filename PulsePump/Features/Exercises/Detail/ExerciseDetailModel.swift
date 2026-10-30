import Foundation

/// What the exercise detail screen shows, worked out from an exercise's finished sessions. Pure values: the
/// SwiftData models are read once in `ExerciseDetailModel.make(logs:)`, so everything else is testable.
struct ExerciseSession: Identifiable, Equatable {
    struct SetResult: Equatable {
        let weightKg: Double
        let reps: Int
        /// Beat everything lifted in earlier sessions (by estimated 1RM). The first session sets a baseline, not a PR.
        let isPR: Bool
    }

    let id: UUID
    let date: Date
    let workoutName: String
    let sets: [SetResult]

    var volumeKg: Double { sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) } }
    var topWeightKg: Double { sets.map(\.weightKg).max() ?? 0 }
    var bestE1RMKg: Double { sets.map { ExerciseProgress.epley(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0 }
}

enum ExerciseMetric: CaseIterable, Identifiable {
    case e1rm, topSet, volume
    var id: Self { self }

    /// The selector's label, and the chart's heading.
    var selectorLabel: String {
        switch self { case .e1rm: "E1RM"; case .topSet: "TOP SET"; case .volume: "VOLUME" }
    }
    var chartLabel: String {
        switch self { case .e1rm: "ESTIMATED 1RM"; case .topSet: "TOP SET WEIGHT"; case .volume: "SESSION VOLUME" }
    }

    func value(of session: ExerciseSession) -> Double {
        switch self {
        case .e1rm: session.bestE1RMKg
        case .topSet: session.topWeightKg
        case .volume: session.volumeKg
        }
    }
}

enum ExerciseRange: CaseIterable, Identifiable {
    case month, threeMonths, sixMonths, year, all
    var id: Self { self }

    var label: String {
        switch self { case .month: "1M"; case .threeMonths: "3M"; case .sixMonths: "6M"; case .year: "1Y"; case .all: "ALL" }
    }

    /// How far back the range reaches; nil is everything.
    var days: Int? {
        switch self { case .month: 30; case .threeMonths: 90; case .sixMonths: 182; case .year: 365; case .all: nil }
    }
}

struct ExerciseDetailModel: Equatable {
    /// Newest first.
    let sessions: [ExerciseSession]

    // MARK: Records

    var sessionCount: Int { sessions.count }

    /// The set with the highest estimated 1RM ever.
    var bestSet: (weightKg: Double, reps: Int)? {
        sessions.flatMap(\.sets)
            .max { ExerciseProgress.epley(weight: $0.weightKg, reps: $0.reps) < ExerciseProgress.epley(weight: $1.weightKg, reps: $1.reps) }
            .map { ($0.weightKg, $0.reps) }
    }

    var estimated1RMKg: Double? { bestSet.map { ExerciseProgress.epley(weight: $0.weightKg, reps: $0.reps) } }

    /// The heaviest set of the latest session.
    var lastSet: (weightKg: Double, reps: Int)? {
        sessions.first?.sets.max { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) }.map { ($0.weightKg, $0.reps) }
    }

    // MARK: Trend

    struct Point: Equatable {
        let date: Date
        let value: Double
    }

    /// The metric for each session inside `range`, oldest first. Sessions with nothing to plot (no load) are skipped.
    func series(_ metric: ExerciseMetric, range: ExerciseRange, now: Date = Date(), calendar: Calendar = .current) -> [Point] {
        let cutoff = range.days.flatMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        return sessions
            .filter { cutoff == nil || $0.date >= cutoff! }
            .map { Point(date: $0.date, value: metric.value(of: $0)) }
            .filter { $0.value > 0 }
            .sorted { $0.date < $1.date }
    }

    struct Headline: Equatable {
        /// The latest value in the range.
        let value: Double
        /// Change from the first to the last point, in percent; nil with fewer than two points.
        let deltaPercent: Double?
        /// The date the change is measured from.
        let since: Date?
    }

    func headline(_ metric: ExerciseMetric, range: ExerciseRange, now: Date = Date(), calendar: Calendar = .current) -> Headline? {
        let points = series(metric, range: range, now: now, calendar: calendar)
        guard let last = points.last else { return nil }
        guard points.count >= 2, let first = points.first, first.value > 0 else {
            return Headline(value: last.value, deltaPercent: nil, since: nil)
        }
        return Headline(value: last.value, deltaPercent: (last.value - first.value) / first.value * 100, since: first.date)
    }

    // MARK: Building it from the stored sessions

    /// One finished session as it was logged: working sets in order, as (kg, reps).
    struct RawSession {
        let id: UUID
        let date: Date
        let workoutName: String
        let sets: [(weightKg: Double, reps: Int)]
    }

    /// Sessions in any order become the model (newest first), marking each session's PR: only its best set, only if
    /// it beat everything lifted in earlier sessions by estimated 1RM, and never in the first session (a baseline).
    static func make(raw: [RawSession]) -> ExerciseDetailModel {
        var bestSoFar = 0.0
        var built: [ExerciseSession] = []
        for (index, session) in raw.sorted(by: { $0.date < $1.date }).enumerated() {
            let e1rms = session.sets.map { ExerciseProgress.epley(weight: $0.weightKg, reps: $0.reps) }
            let sessionBest = e1rms.max() ?? 0
            let prIndex: Int? = (index > 0 && sessionBest > bestSoFar) ? e1rms.firstIndex(of: sessionBest) : nil
            let sets = session.sets.enumerated().map { i, s in
                ExerciseSession.SetResult(weightKg: s.weightKg, reps: s.reps, isPR: i == prIndex)
            }
            built.append(ExerciseSession(id: session.id, date: session.date, workoutName: session.workoutName, sets: sets))
            bestSoFar = max(bestSoFar, sessionBest)
        }
        return ExerciseDetailModel(sessions: built.reversed())
    }

    /// `logs`: the exercise's finished logs, in any order.
    @MainActor static func make(logs: [ExerciseLog]) -> ExerciseDetailModel {
        make(raw: logs.compactMap { log in
            guard let date = log.workout?.date else { return nil }
            return RawSession(id: log.id, date: date, workoutName: log.workout?.template?.name ?? "Workout",
                              sets: log.workingSets.sorted { $0.order < $1.order }.map { ($0.weight, $0.reps) })
        })
    }
}

/// How the trend chart lays out a series: x spread evenly by position, y padded 8% so the line never touches the
/// edges. Coordinates are 0...1 with y = 0 at the top.
struct TrendChartLayout: Equatable {
    let points: [CGPoint]
    let minValue: Double
    let maxValue: Double

    init(values: [Double]) {
        guard let lo = values.min(), let hi = values.max() else {
            points = []; minValue = 0; maxValue = 0
            return
        }
        let pad = (hi - lo) * 0.08
        let padded = pad == 0 ? 1.0 : pad
        let low = lo - padded, high = hi + padded
        let span = high - low
        let n = values.count
        minValue = low
        maxValue = high
        points = values.enumerated().map { i, v in
            CGPoint(x: n == 1 ? 1 : Double(i) / Double(n - 1), y: 1 - (v - low) / span)
        }
    }
}
