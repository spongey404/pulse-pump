import Foundation
import CoreGraphics

/// The pure rules of the logger from Claude Design `Ore Logger 1a.dc.html`: stepping, hold-and-drag, plates, equipment labels,
/// the live estimated 1RM and the auto-progression prefill. No SwiftUI, so every rule is unit-tested.
enum LoggerMath {
    // MARK: Stepping and scrubbing

    /// kg step of the − / + buttons and of a drag: 2.5 kg (5 lb), fine 1.25 kg (2.5 lb).
    static func kgStep(_ unit: UnitPreference, fine: Bool = false) -> Double {
        let s = unit.stepperIncrement
        return fine ? s / 2 : s
    }

    /// Rounds a drop's weight to the nearest 2.5 (the display unit's step), never below 0.
    static func roundToStep(_ displayValue: Double, step: Double = 2.5) -> Double { max(0, (displayValue / step).rounded() * step) }

    /// Adds `delta` (display units) and keeps two decimals, floor 0.
    static func stepped(_ value: Double, by delta: Double) -> Double { max(0, ((value + delta) * 100).rounded() / 100) }

    /// Points of drag per step.
    static let pointsPerStep: CGFloat = 18
    /// Sliding right past this while holding switches a kg drag to fine steps.
    static let fineSlide: CGFloat = 40
    /// How long a finger rests on a number before it becomes a drag.
    static let holdSeconds = 0.22

    /// Whole steps of a vertical drag (up is positive), truncated toward zero like the design.
    static func steps(dragUp dy: CGFloat) -> Int { Int((dy / pointsPerStep).rounded(.towardZero)) }

    static func isFine(dx: CGFloat, isKg: Bool) -> Bool { isKg && dx > fineSlide }

    /// The value while scrubbing: `base` moved by whole steps of `step`, floor 0.
    static func scrubbed(base: Double, dragUp dy: CGFloat, step: Double) -> Double { stepped(base, by: Double(steps(dragUp: dy)) * step) }

    /// A hold-and-drag in progress: the value follows whole steps of drag; sliding right past 40 pt (kg only) switches to fine steps,
    /// counted from the value at that moment.
    struct ScrubTracker: Equatable {
        private(set) var base: Double
        private(set) var offset: CGFloat = 0
        private(set) var fine = false
        private(set) var value: Double
        let isKg: Bool
        let step: Double
        let fineStep: Double

        init(base: Double, isKg: Bool, step: Double, fineStep: Double) {
            self.base = base; self.value = base; self.isKg = isKg; self.step = step; self.fineStep = fineStep
        }

        /// `dragUp` / `slideRight` are measured from where the finger went down.
        mutating func update(dragUp: CGFloat, slideRight: CGFloat) {
            let nowFine = LoggerMath.isFine(dx: slideRight, isKg: isKg)
            if nowFine != fine { fine = nowFine; base = value; offset = dragUp }
            value = LoggerMath.scrubbed(base: base, dragUp: dragUp - offset, step: fine ? fineStep : step)
        }
    }

    // MARK: Estimated 1RM

    static func epley(kg: Double, reps: Int) -> Double { kg > 0 ? kg * (1 + Double(reps) / 30) : 0 }

    /// The live result: a logged set's estimated 1RM beating the best so far makes the header's 1RM gold with the star. Assisted lifts
    /// (negative load) have no 1RM.
    static func liveBest(history: Double, logged: [(kg: Double, reps: Int)], assisted: Bool) -> (value: Double, beat: Bool) {
        guard !assisted else { return (history, false) }
        let best = logged.map { epley(kg: $0.kg, reps: $0.reps) }.max() ?? 0
        return best > history + 0.001 ? (best, true) : (history, false)
    }

    // MARK: Equipment

    enum Load: Equatable {
        case standard, weightedBodyweight, assisted, dumbbell

        /// The KG column's title.
        func header(unit: String) -> String {
            switch self {
            case .standard: unit
            case .weightedBodyweight: "+\(unit)"
            case .assisted: "−\(unit)"
            case .dumbbell: "\(unit) / HAND"
            }
        }

        /// A value as the row shows it: "+7.5", "−20", "16", "60".
        func format(_ number: String) -> String {
            switch self {
            case .weightedBodyweight: "+\(number)"
            case .assisted: "−\(number)"
            default: number
            }
        }
    }

    static func load(equipment: EquipmentType, exerciseType: ExerciseType, name: String) -> Load {
        let n = name.lowercased()
        if n.contains("assisted") { return .assisted }
        if equipment == .bodyweight, exerciseType == .weighted || n.hasPrefix("weighted") { return .weightedBodyweight }
        if equipment == .dumbbell { return .dumbbell }
        return .standard
    }

    // MARK: Plates (IPF colours)

    static let plateSizes: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    /// Plates for ONE side, heaviest first.
    static func plateStack(totalKg: Double, barKg: Double) -> [Double] {
        var rest = max(0, (totalKg - barKg) / 2)
        var out: [Double] = []
        for p in plateSizes { while rest >= p - 1e-9 { out.append(p); rest -= p } }
        return out
    }

    struct PlateChange: Equatable {
        var takeOff: [Double]
        var putOn: [Double]
        var none: Bool { takeOff.isEmpty && putOn.isEmpty }
    }

    /// What to take off and put on going from the previous set's load to this one's.
    static func plateChange(from previous: [Double], to current: [Double]) -> PlateChange {
        func counts(_ a: [Double]) -> [Double: Int] { a.reduce(into: [:]) { $0[$1, default: 0] += 1 } }
        let c = counts(current), p = counts(previous)
        var off: [Double] = [], on: [Double] = []
        for size in Set(c.keys).union(p.keys).sorted(by: >) {
            let d = (c[size] ?? 0) - (p[size] ?? 0)
            if d > 0 { on += Array(repeating: size, count: d) } else if d < 0 { off += Array(repeating: size, count: -d) }
        }
        return PlateChange(takeOff: off, putOn: on)
    }

    struct PlateStyle: Equatable { var fill: String; var text: String; var border: String?; var height: Double; var width: Double }

    /// Plate colours and drawn sizes: 25 red, 20 blue, 15 yellow (dark text), 10 green, 5 white (dark text + hairline), 2.5 black (white text +
    /// light hairline), 1.25 chrome (dark text). Heights and widths are the design's (points).
    static func plateStyle(_ size: Double) -> PlateStyle {
        switch size {
        case 25: PlateStyle(fill: "#E51B1B", text: "#FFFFFF", border: nil, height: 68, width: 16)
        case 20: PlateStyle(fill: "#1F4EA3", text: "#FFFFFF", border: nil, height: 68, width: 15)
        case 15: PlateStyle(fill: "#F2C200", text: "#151A21", border: nil, height: 60, width: 14)
        case 10: PlateStyle(fill: "#1F8F5A", text: "#FFFFFF", border: nil, height: 50, width: 12)
        case 5: PlateStyle(fill: "#F4F4F2", text: "#151A21", border: "rgba(21,26,33,0.28)", height: 38, width: 10)
        case 2.5: PlateStyle(fill: "#151515", text: "#FFFFFF", border: "rgba(255,255,255,0.28)", height: 28, width: 8)
        default: PlateStyle(fill: "#E6E8EA", text: "#151A21", border: "rgba(21,26,33,0.2)", height: 22, width: 7)   // 1.25 chrome (a gradient to #A9AEB3)
        }
    }

    struct Bar: Equatable { var name: String; var kg: Double }
    static let bars = [Bar(name: "BARBELL", kg: 20), Bar(name: "EZ", kg: 7.5), Bar(name: "TRAP", kg: 25), Bar(name: "SAFETY", kg: 32), Bar(name: "LIGHT", kg: 15)]

    // MARK: Auto progression (prefill)

    struct ProgressionConfig: Equatable {
        var enabled = false
        /// "When you hit [8] reps".
        var reps = 8
        /// "Go up by +2.5 kg": kg.
        var incrementKg = 2.5
        static let increments: [Double] = [1.25, 2.5, 5, 10]
        static let off = ProgressionConfig()
    }

    /// Whether the set's prefill is bumped: the previous set (this workout) reached the rep target, or, with none logged yet, last
    /// time's reps at this position did.
    static func isBumped(_ p: ProgressionConfig, previousLoggedReps: Int?, lastTimeReps: Int?) -> Bool {
        guard p.enabled else { return false }
        if let previousLoggedReps { return previousLoggedReps >= p.reps }
        return (lastTimeReps ?? 0) >= p.reps
    }

    /// The prefilled kg: last time's weight at this position, or the previous set's logged weight when progression is on, plus the
    /// increment when bumped.
    static func prefillKg(_ p: ProgressionConfig, lastTimeKg: Double?, previousLoggedKg: Double?, bumped: Bool) -> Double? {
        guard let base = (p.enabled ? (previousLoggedKg ?? lastTimeKg) : lastTimeKg) else { return nil }
        return bumped ? ((base + p.incrementKg) * 100).rounded() / 100 : base
    }

    // MARK: Drop sets, rest-pause, unilateral

    /// A drop set's first two drops: 80 % then 65 % of the set's weight, rounded to 2.5.
    static func dropWeights(from kg: Double, step: Double = 2.5) -> [Double] { [roundToStep(kg * 0.8, step: step), roundToStep(kg * 0.65, step: step)] }

    /// Rest-pause rounds are prefilled at a third then a quarter of the reps (floor 2).
    static func restPauseReps(from reps: Int) -> [Int] { [max(2, Int((Double(reps) / 3).rounded())), max(2, Int((Double(reps) / 4).rounded()))] }

    /// Reps logged for the whole set: the sum of the sets' lines (drops and rounds add to the first set's reps; L + R for unilateral).
    static func totalReps(main: Int, subs: [Int], type: SetType) -> Int {
        switch type {
        case .dropset, .restPause: main + subs.reduce(0, +)
        case .leftRight: subs.reduce(0, +)
        default: main
        }
    }

    /// The single weight a drop set is stored with so its volume (weight × reps) is exact: the rep-weighted average.
    static func averageKg(mainKg: Double, mainReps: Int, drops: [(kg: Double, reps: Int)]) -> Double {
        let lines = [(mainKg, mainReps)] + drops.map { ($0.kg, $0.reps) }
        let reps = lines.reduce(0) { $0 + $1.1 }
        guard reps > 0 else { return mainKg }
        return lines.reduce(0.0) { $0 + $1.0 * Double($1.1) } / Double(reps)
    }

    // MARK: Finish bar

    /// How full the FINISH WORKOUT button is.
    static func fill(done: Int, total: Int) -> Double { total > 0 ? min(1, Double(done) / Double(total)) : 0 }

    /// "N LEFT" or "ALL DONE ›".
    static func leftLabel(done: Int, total: Int) -> String { total - done > 0 ? "\(total - done) LEFT" : "ALL DONE ›" }

    /// The modal's text (§11).
    static func finishMessage(unlogged: Int) -> String {
        unlogged > 0 ? "\(unlogged) sets aren't logged and will be left out. Only logged sets count toward your body map." : "Every set is logged."
    }
}
