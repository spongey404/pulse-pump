import Foundation

// MARK: - Custom widget catalog  (design: widget-catalog.js)
//
// Shared by the app (builder + preview) and the widget extension (renderer).
// A custom widget is a grid of "pieces". Sizes are in grid cells: small 4×4, medium 8×4,
// large 8×8, lock screen 4×2.

enum PumpWidgetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large, lock

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var cols: Int { switch self { case .small: 4; case .medium, .large: 8; case .lock: 4 } }
    var rows: Int { switch self { case .small, .medium: 4; case .large: 8; case .lock: 2 } }
    var pad: Double { self == .lock ? 4 : 12 }
    /// Design points of the widget canvas.
    var width: Double { switch self { case .small: 158; case .medium, .large: 338; case .lock: 160 } }
    var height: Double { switch self { case .small, .medium: 158; case .large: 354; case .lock: 72 } }
}

enum PumpPieceType: String, Codable, CaseIterable, Identifiable {
    case num, pr, bars, spark, body, next, quick, prog

    var id: String { rawValue }

    var info: PumpPieceInfo { PumpWidgetCatalog.types[self]! }
}

struct PumpWidgetPiece: Codable, Identifiable, Equatable {
    var id: String
    var type: PumpPieceType
    /// Metric id from the catalog; for `pr` and `quick` it is the exercise / template name.
    var metric: String
    var x: Int
    var y: Int
    var w: Int
    var h: Int
}

struct PumpCustomWidget: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var size: PumpWidgetSize
    var pieces: [PumpWidgetPiece]
    var edited: Date
}

/// One selectable option of a piece, with the sample values shown in the design.
struct PumpPieceMetric: Identifiable {
    var id: String
    var label: String
    var k: String = ""        // caption
    var v: String = ""        // value
    var u: String = ""        // unit
    var d: String = ""        // delta
    var dirUp: Bool? = nil
    var ago: String = ""
    var isPR = false
    var data: [Double] = []
    var today: Int = -1
    var t: String = ""        // title
    var meta: String = ""
    var start = false
    var n = 0
    var done = 0
    var cur = -1
    var body: [String: Double] = [:]
}

struct PumpPieceInfo {
    var name: String
    var glyph: String
    var desc: String
    var why: String
    var sizes: [(Int, Int)]
    var metrics: [PumpPieceMetric]
    var picker = false
    var noLock = false
}

enum PumpWidgetCatalog {
    static let order: [PumpPieceType] = [.num, .pr, .bars, .spark, .body, .next, .quick, .prog]

    static let types: [PumpPieceType: PumpPieceInfo] = [
        .num: PumpPieceInfo(
            name: "Single stat", glyph: "12",
            desc: "One number: your streak, sessions this week, how many lifts went up last session, or bodyweight.",
            why: "The core of any widget: one number you check every day.",
            sizes: [(2, 2), (2, 1), (4, 1)],
            metrics: [
                PumpPieceMetric(id: "streak", label: "Streak", k: "STREAK", v: "12", u: "DAYS"),
                PumpPieceMetric(id: "sessions", label: "Sessions this week", k: "SESSIONS", v: "4/5", u: "WK"),
                PumpPieceMetric(id: "improved", label: "Lifts improved, last session", k: "IMPROVED", v: "4/6", u: "LIFTS UP"),
                PumpPieceMetric(id: "topgain", label: "Biggest gain, last session", k: "TOP GAIN", v: "+5", u: "KG · ROW"),
                PumpPieceMetric(id: "bw", label: "Bodyweight", k: "BODYWEIGHT", v: "82.4", u: "KG", d: "-0.6", dirUp: false),
            ]),
        .pr: PumpPieceInfo(
            name: "Exercise PR", glyph: "PR",
            desc: "Your best logged weight for any exercise you choose, and when you set it.",
            why: "A PR is the number lifters actually chase. One piece, any lift from the exercise library.",
            sizes: [(2, 2), (2, 1), (4, 1)],
            metrics: [
                ("Bench Press", "BENCH PR", "100", "3W AGO"), ("Incline Bench Press", "INCLINE PR", "82.5", "2W AGO"),
                ("Overhead Press", "OHP PR", "62.5", "6D AGO"), ("Squat", "SQUAT PR", "135", "5W AGO"),
                ("Deadlift", "DEADLIFT PR", "170", "2W AGO"), ("Barbell Row", "ROW PR", "95", "1W AGO"),
            ].map { PumpPieceMetric(id: $0.0, label: $0.0, k: $0.1, v: $0.2, u: "KG", ago: $0.3, isPR: true) },
            picker: true),
        .bars: PumpPieceInfo(
            name: "Week bars", glyph: "▮▮",
            desc: "One bar per day, Monday to Sunday, for sets or volume. Today is blue.",
            why: "Answers “how has my week gone” in one look: which days you trained and how hard.",
            sizes: [(4, 2), (4, 1)],
            metrics: [
                PumpPieceMetric(id: "sets", label: "Sets per day", k: "SETS · MON–SUN", data: [18, 0, 22, 26, 28, 0, 0], today: 4),
                PumpPieceMetric(id: "volume", label: "Volume per day", k: "VOLUME · MON–SUN", data: [6.1, 0, 7.4, 8.4, 9.3, 0, 0], today: 4),
                PumpPieceMetric(id: "improved", label: "Lifts improved per day", k: "IMPROVED · MON–SUN", data: [3, 0, 4, 2, 4, 0, 0], today: 4),
            ]),
        .spark: PumpPieceInfo(
            name: "Line chart", glyph: "╱",
            desc: "A small line showing how a number has moved over weeks, like bench 1RM or bodyweight.",
            why: "Long-term progress is what keeps people lifting. A line going up is more motivating than any single number.",
            sizes: [(4, 1), (4, 2)],
            metrics: [
                PumpPieceMetric(id: "e1rm", label: "Bench est. 1RM, 12 weeks", k: "BENCH E1RM", v: "98.5", u: "KG",
                                data: [91, 92.5, 92, 94, 95, 94.5, 96, 96.5, 97, 98, 97.5, 98.5]),
                PumpPieceMetric(id: "bw", label: "Bodyweight, 30 days", k: "BODYWEIGHT", v: "82.4", u: "KG",
                                data: [83.6, 83.4, 83.5, 83.2, 83.3, 83.1, 83.2, 83.0, 82.9, 83.1, 82.8, 82.9, 82.7, 82.9, 82.8, 82.6, 82.7, 82.9, 83.0, 82.8, 82.7, 82.6, 82.8, 82.5, 82.6, 82.4]),
                PumpPieceMetric(id: "e1rm_squat", label: "Squat est. 1RM, 12 weeks", k: "SQUAT E1RM", v: "131", u: "KG",
                                data: [120, 122, 121, 124, 125, 126, 125, 127, 128, 129, 130, 131]),
            ]),
        .body: PumpPieceInfo(
            name: "Body map", glyph: "◐",
            desc: "The front body, shaded by volume or by how recently each muscle was trained.",
            why: "Answers “what have I been neglecting” before you pick a session. It is also the most recognisable Pump visual.",
            sizes: [(2, 4), (2, 3)],
            metrics: [
                PumpPieceMetric(id: "volume", label: "Volume, 7 days", k: "VOL · 7D",
                                body: ["chest": 0.95, "shoulders": 0.78, "biceps": 0.6, "forearms": 0.3, "core": 0.12, "traps": 0.4, "quads": 0.22]),
                PumpPieceMetric(id: "recency", label: "Days since trained", k: "RECENCY",
                                body: ["chest": 0.9, "shoulders": 0.9, "biceps": 0.7, "forearms": 0.7, "core": 0.2, "traps": 0.7, "quads": 0.35, "glutes": 0.3, "calves": 0.05]),
            ],
            noLock: true),
        .next: PumpPieceInfo(
            name: "Next workout", glyph: "›",
            desc: "The session Pump predicts you'll do next, with a START button.",
            why: "The prediction is the app’s main promise. This puts it one tap from starting.",
            sizes: [(4, 2)],
            metrics: [
                PumpPieceMetric(id: "start", label: "With START button", k: "NEXT · FRI", t: "PUSH DAY", meta: "6 EX · ~52 MIN", start: true),
                PumpPieceMetric(id: "first", label: "With first exercise", k: "NEXT · FRI", t: "PUSH DAY", meta: "BENCH 4×6 · 82.5 KG", start: false),
            ]),
        .quick: PumpPieceInfo(
            name: "Start button", glyph: "▶",
            desc: "One tap starts a chosen template, without opening Pump first.",
            why: "For people who pick their own session instead of following the prediction. Two or four of these make a launcher.",
            sizes: [(2, 1)],
            metrics: [
                PumpPieceMetric(id: "Push Day", label: "Push Day", t: "PUSH", meta: "6 EX"),
                PumpPieceMetric(id: "Pull Day", label: "Pull Day", t: "PULL", meta: "6 EX"),
                PumpPieceMetric(id: "Legs", label: "Legs", t: "LEGS", meta: "5 EX"),
                PumpPieceMetric(id: "Upper", label: "Upper", t: "UPPER", meta: "7 EX"),
            ],
            picker: true),
        .prog: PumpPieceInfo(
            name: "Progress squares", glyph: "■■□",
            desc: "A row of squares filled toward a target: weekly sessions or program weeks.",
            why: "A target with a visible gap (4 of 5) pulls people into the last session of the week.",
            sizes: [(4, 1), (2, 1)],
            metrics: [
                PumpPieceMetric(id: "goal", label: "Weekly session goal", k: "GOAL · WK 41", v: "4/5", n: 5, done: 4),
                PumpPieceMetric(id: "program", label: "Program weeks", k: "PPL · WEEK", v: "3/8", n: 8, done: 2, cur: 2),
            ]),
    ]

    private static func p(_ id: String, _ type: PumpPieceType, _ metric: String, _ x: Int, _ y: Int, _ w: Int, _ h: Int) -> PumpWidgetPiece {
        PumpWidgetPiece(id: id, type: type, metric: metric, x: x, y: y, w: w, h: h)
    }

    /// Starter widgets from the design's library.
    static func presets(now: Date = Date()) -> [PumpCustomWidget] {
        [
            PumpCustomWidget(id: "glance", name: "Gym glance", size: .medium, pieces: [
                p("a1", .next, "start", 0, 0, 4, 2), p("a2", .num, "streak", 4, 0, 2, 2), p("a3", .pr, "Bench Press", 6, 0, 2, 2),
                p("a4", .bars, "sets", 0, 2, 4, 2), p("a5", .prog, "goal", 4, 2, 4, 1), p("a6", .quick, "Pull Day", 4, 3, 2, 1), p("a7", .quick, "Legs", 6, 3, 2, 1),
            ], edited: now),
            PumpCustomWidget(id: "pr", name: "PR board", size: .small, pieces: [
                p("b2", .spark, "e1rm", 0, 0, 4, 2), p("b3", .pr, "Bench Press", 0, 2, 2, 2), p("b4", .num, "improved", 2, 2, 2, 2),
            ], edited: now),
            PumpCustomWidget(id: "full", name: "Full board", size: .large, pieces: [
                p("c2", .body, "volume", 0, 0, 2, 4), p("c3", .num, "streak", 2, 0, 2, 2), p("c4", .pr, "Squat", 4, 0, 2, 2), p("c5", .pr, "Deadlift", 6, 0, 2, 2),
                p("c6", .bars, "sets", 2, 2, 4, 2), p("c7", .prog, "program", 6, 2, 2, 1), p("c8", .prog, "goal", 6, 3, 2, 1),
                p("c9", .next, "first", 0, 4, 4, 2), p("c10", .spark, "bw", 4, 4, 4, 2),
                p("c15", .spark, "e1rm", 0, 6, 4, 2), p("c11", .quick, "Push Day", 4, 6, 2, 1), p("c12", .quick, "Pull Day", 6, 6, 2, 1),
                p("c13", .quick, "Legs", 4, 7, 2, 1), p("c14", .quick, "Upper", 6, 7, 2, 1),
            ], edited: now),
            PumpCustomWidget(id: "lockline", name: "Lock glance", size: .lock, pieces: [
                p("d1", .pr, "Bench Press", 0, 0, 4, 1), p("d2", .prog, "goal", 0, 1, 4, 1),
            ], edited: now),
        ]
    }

    // MARK: Grid helpers (shared by builder logic and renderer)

    static func sizes(for type: PumpPieceType, in size: PumpWidgetSize, first: (Int, Int)? = nil) -> [(Int, Int)] {
        var s = type.info.sizes
        if let first { s = [first] + s.filter { $0.0 != first.0 || $0.1 != first.1 } }
        return s.filter { $0.0 <= size.cols && $0.1 <= size.rows }
    }
}

/// App Group storage for the widget library (read by the extension's configuration intent).
enum PumpWidgetStore {
    static let appGroupId = "group.com.pulse.PulsePump"
    private static let libraryKey = "custom_widget_library"
    private static let snapshotKey = "widget_snapshot"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    static func loadLibrary() -> [PumpCustomWidget] {
        guard let data = defaults?.data(forKey: libraryKey),
              let lib = try? JSONDecoder().decode([PumpCustomWidget].self, from: data) else { return [] }
        return lib
    }

    static func saveLibrary(_ lib: [PumpCustomWidget]) {
        guard let data = try? JSONEncoder().encode(lib) else { return }
        defaults?.set(data, forKey: libraryKey)
    }

    static func loadSnapshot() -> PumpWidgetSnapshot {
        guard let data = defaults?.data(forKey: snapshotKey),
              let s = try? JSONDecoder().decode(PumpWidgetSnapshot.self, from: data) else { return PumpWidgetSnapshot() }
        return s
    }

    static func saveSnapshot(_ s: PumpWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }
}
