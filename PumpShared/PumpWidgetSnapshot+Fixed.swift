import Foundation

// MARK: - Data for the fixed widget set (Pump Widgets.dc.html)
//
// All fields are plain Codable values written by the app (`WidgetDataService`) into the
// App Group snapshot. `PumpWidgetSnapshot.sample` mirrors the numbers printed in the design
// so the Widget Gallery / placeholders can be compared with it 1:1.

struct PWExercise: Codable, Equatable { var name: String; var target: String; var kg: String }
struct PWRecentSession: Codable, Equatable { var name: String; var when: String; var meta: String }
struct PWVolDay: Codable, Equatable { var day: String; var thisWeek: Double; var lastWeek: Double }
struct PWNamedValue: Codable, Equatable { var name: String; var value: String }
struct PWMuscleRow: Codable, Equatable { var muscle: String; var sets: Int; var last: String; var stale: Bool }
struct PWBalance: Codable, Equatable {
    var key: String            // "PUSH : PULL"
    var ratio: String          // "1.41"
    var share: Double          // 0–1, leading side's share of the bar
    var a: String; var b: String   // "PUSH 48" / "PULL 34"
    var flag: String           // "▼ PULL -14 SETS" or "IN RANGE"
    var flagged: Bool
}
struct PWLift: Codable, Equatable {
    var name: String; var short: String
    var e1rm: Double; var pr: Double
    var series: [Double]       // 12 weekly e1RM points, oldest → newest
}
struct PWLoadWeek: Codable, Equatable { var label: String; var load: Double; var deload: Bool; var current: Bool; var next: Bool }
struct PWProgramDay: Codable, Equatable {
    enum State: String, Codable { case done, next, later }
    var tag: String            // "✓ MON" / "NEXT" / "—"
    var name: String           // "Push"
    var state: State
}
struct PWFriendSession: Codable, Equatable { var initials: String; var name: String; var workout: String; var meta: String; var ago: String }
struct PWQuickStart: Codable, Equatable { var name: String; var meta: String; var predicted: Bool }
struct PWEcoRow: Codable, Equatable { var app: String; var key: String; var value: String; var of: String }

struct PWFixedData: Codable, Equatable {
    // Subscription state — Plus widgets show the locked preview when false.
    var isPlus = false

    // 01 Next workout
    var nextConfidence = 0.0
    var nextDate = ""                  // "FRI 9 OCT"
    var nextSplitLine = ""             // "PUSH PULL LEGS · WK 3"
    var nextSets = 0
    var nextExerciseList: [PWExercise] = []
    var nextLastSameDays = 0           // days since this workout type was last done
    var nextLastSameName = ""          // "PUSH"

    // 02 Streak
    var streakLogged: [Bool] = []      // last 7 days, oldest → newest
    var streakLetters: [String] = []   // weekday initials for those 7 days
    var lastWorkoutName = ""
    var lastWorkoutWeekday = ""        // "WED"
    var lastWorkoutDaysAgo = 0
    var lastWorkoutExercises = 0
    var lastWorkoutMinutes = 0
    var weekSetsPerDay: [Double] = []  // Mon–Sun
    var weekDone: [Bool] = []
    var todayIndex = 0
    var recentSessions: [PWRecentSession] = []

    // 03 Weekly volume
    var setsThisWeek = 0
    var setsLastWeekSameDay = 0
    var volumeTonnes = 0.0
    var volumeDeltaPct = 0.0
    var trainingHours = ""             // "3:42"
    var hoursDeltaPct = 0.0
    var volDays: [PWVolDay] = []
    var weekdayShort = ""              // "FRI"

    // 04 Body map
    var neglected: [PWNamedValue] = [] // CALVES / 12D …
    var topMuscles: [PWNamedValue] = []// CHEST / 16 …
    var muscleRows: [PWMuscleRow] = []

    // 05 Balance
    var balances: [PWBalance] = []

    // 06 PR watch
    var prLifts: [PWLift] = []

    // 07 Deload
    var loadWeeks: [PWLoadWeek] = []
    var blockWeek = 0
    var blockWeeks = 0
    var loadRatio = 0.0
    var loadRatioDelta = 0.0
    var nextDeloadWeek = ""            // "WK 42"
    var lastDeloadWeek = ""            // "WK 37"

    // 09 Recap
    var recapVolumeKg = 0.0
    var recapVolumeDeltaPct = 0.0
    var recapSets = 0
    var recapTime = ""                 // "58:12"
    var recapPRName = ""               // "Barbell Row"
    var recapPRValue = ""              // "95×5"

    // 10 Program
    var programName = ""
    var programWeek = 0
    var programWeeks = 0
    var programSessionsDone = 0
    var programSessionsTarget = 0
    var programDays: [PWProgramDay] = []

    // 11 Goal
    var goalLeftLine = ""              // "1 LEFT · 2 DAYS"

    // 12 Bodyweight
    var bodyweightSeries: [Double] = [] // 30 daily points
    var bodyweightDelta7d = 0.0
    var bodyweightStart = ""           // "6 SEP"

    // 13 Friends
    var friends: [PWFriendSession] = []

    // 14 Quick start
    var quickStarts: [PWQuickStart] = []

    // 15 Pulse ecosystem (Fuel / Stride write their own rows into the App Group)
    var eco: [PWEcoRow] = []
}

extension PumpWidgetSnapshot {
    var fixed: PWFixedData {
        get { _fixed ?? PWFixedData() }
        set { _fixed = newValue }
    }

    /// The numbers printed in Pump Widgets.dc.html — used by the Widget Gallery, placeholders and previews.
    static var sample: PumpWidgetSnapshot {
        var s = PumpWidgetSnapshot()
        s.hasData = true
        s.streak = 12
        s.sessionsThisWeek = 4
        s.sessionGoal = 5
        s.weekNumber = 41
        s.nextName = "PUSH DAY"
        s.nextDay = "FRI"
        s.nextExercises = 6
        s.nextEstMinutes = 52

        var f = PWFixedData()
        f.isPlus = true
        f.nextConfidence = 0.8
        f.nextDate = "FRI 9 OCT"
        f.nextSplitLine = "PUSH PULL LEGS · WK 3"
        f.nextSets = 18
        f.nextExerciseList = [
            PWExercise(name: "Bench Press", target: "4×6", kg: "82.5"),
            PWExercise(name: "Overhead Press", target: "3×8", kg: "50"),
            PWExercise(name: "Incline DB Press", target: "3×10", kg: "28"),
            PWExercise(name: "Lateral Raise", target: "3×15", kg: "10"),
            PWExercise(name: "Triceps Pushdown", target: "3×12", kg: "32.5"),
            PWExercise(name: "Cable Fly", target: "2×12", kg: "15"),
        ]
        f.nextLastSameDays = 4
        f.nextLastSameName = "PUSH"

        f.streakLetters = ["T", "F", "S", "S", "M", "T", "W"]
        f.streakLogged = [true, false, true, true, true, false, true]
        f.lastWorkoutName = "Pull Day"
        f.lastWorkoutWeekday = "WED"
        f.lastWorkoutDaysAgo = 2
        f.lastWorkoutExercises = 6
        f.lastWorkoutMinutes = 58
        f.weekSetsPerDay = [18, 0, 22, 26, 28, 0, 0]
        f.weekDone = [true, false, true, true, false, false, false]
        f.todayIndex = 4
        f.recentSessions = [
            PWRecentSession(name: "Pull Day", when: "WED · 2 DAYS AGO", meta: "6 EX · 58M"),
            PWRecentSession(name: "Legs", when: "MON · 4 DAYS AGO", meta: "5 EX · 51M"),
            PWRecentSession(name: "Push Day", when: "SAT · 6 DAYS AGO", meta: "6 EX · 49M"),
        ]

        f.setsThisWeek = 94
        f.setsLastWeekSameDay = 84
        f.volumeTonnes = 31.2
        f.volumeDeltaPct = 6.4
        f.trainingHours = "3:42"
        f.hoursDeltaPct = -4.1
        f.weekdayShort = "FRI"
        f.volDays = [("M", 18, 16), ("T", 0, 0), ("W", 22, 20), ("T", 26, 0), ("F", 28, 18), ("S", 0, 30), ("S", 0, 0)]
            .map { PWVolDay(day: $0.0, thisWeek: $0.1, lastWeek: $0.2) }

        s.bodyVolume = ["chest": 0.95, "shoulders": 0.78, "biceps": 0.6, "forearms": 0.3, "core": 0.12, "traps": 0.4, "quads": 0.22]
        s.bodyRecency = ["chest": 0.9, "shoulders": 0.9, "biceps": 0.7, "forearms": 0.7, "core": 0.2, "traps": 0.7, "quads": 0.35, "glutes": 0.3, "calves": 0.05]
        f.neglected = [PWNamedValue(name: "CALVES", value: "12D"), PWNamedValue(name: "CORE", value: "8D"), PWNamedValue(name: "QUADS", value: "6D")]
        f.topMuscles = [("CHEST", "16"), ("BACK", "14"), ("SHOULDERS", "12"), ("TRICEPS", "10")].map { PWNamedValue(name: $0.0, value: $0.1) }
        f.muscleRows = [
            ("CHEST", 16, "1D", false), ("BACK", 14, "2D", false), ("SHOULDERS", 12, "1D", false), ("TRICEPS", 10, "1D", false),
            ("BICEPS", 9, "2D", false), ("TRAPS", 6, "2D", false), ("FOREARMS", 4, "2D", false),
            ("QUADS", 4, "6D", true), ("CORE", 2, "8D", true), ("CALVES", 0, "12D", true),
        ].map { PWMuscleRow(muscle: $0.0, sets: $0.1, last: $0.2, stale: $0.3) }

        f.balances = [
            PWBalance(key: "PUSH : PULL", ratio: "1.41", share: 0.585, a: "PUSH 48", b: "PULL 34", flag: "▼ PULL -14 SETS", flagged: true),
            PWBalance(key: "UPPER : LOWER", ratio: "2.73", share: 0.732, a: "UPPER 82", b: "LOWER 30", flag: "▼ LOWER -52 SETS", flagged: true),
            PWBalance(key: "ANT : POST", ratio: "1.20", share: 0.545, a: "ANT 61", b: "POST 51", flag: "IN RANGE", flagged: false),
        ]

        f.prLifts = [
            PWLift(name: "Bench Press", short: "Bench", e1rm: 98.5, pr: 100, series: [91, 92.5, 92, 94, 95, 94.5, 96, 96.5, 97, 98, 97.5, 98.5]),
            PWLift(name: "Overhead Press", short: "OHP", e1rm: 61, pr: 62.5, series: [55, 56, 56, 57.5, 57, 58, 59, 59, 60, 60.5, 60, 61]),
            PWLift(name: "Barbell Row", short: "Row", e1rm: 92, pr: 95, series: [84, 85, 86, 86, 88, 87.5, 89, 90, 90, 91, 91.5, 92]),
            PWLift(name: "Squat", short: "Squat", e1rm: 131, pr: 135, series: [120, 122, 121, 124, 125, 126, 125, 127, 128, 129, 130, 131]),
            PWLift(name: "Deadlift", short: "Deadlift", e1rm: 162.5, pr: 170, series: [150, 152, 155, 154, 156, 158, 157, 159, 160, 161, 161, 162.5]),
        ]

        f.loadWeeks = [("34", 62, false, false), ("35", 70, false, false), ("36", 78, false, false), ("37", 40, true, false),
                       ("38", 74, false, false), ("39", 82, false, false), ("40", 88, false, false), ("41", 93, false, true)]
            .map { PWLoadWeek(label: "W\($0.0)", load: $0.1, deload: $0.2, current: $0.3, next: false) }
            + [PWLoadWeek(label: "W42", load: 0, deload: true, current: false, next: true)]
        f.blockWeek = 5
        f.blockWeeks = 6
        f.loadRatio = 1.18
        f.loadRatioDelta = 0.09
        f.nextDeloadWeek = "WK 42"
        f.lastDeloadWeek = "WK 37"

        f.recapVolumeKg = 8420
        f.recapVolumeDeltaPct = 4.2
        f.recapSets = 22
        f.recapTime = "58:12"
        f.recapPRName = "Barbell Row"
        f.recapPRValue = "95×5"

        f.programName = "Push Pull Legs"
        f.programWeek = 3
        f.programWeeks = 8
        f.programSessionsDone = 2
        f.programSessionsTarget = 4
        f.programDays = [
            PWProgramDay(tag: "✓ MON", name: "Push", state: .done),
            PWProgramDay(tag: "✓ WED", name: "Pull", state: .done),
            PWProgramDay(tag: "NEXT", name: "Legs", state: .next),
            PWProgramDay(tag: "—", name: "Upper", state: .later),
        ]
        f.goalLeftLine = "1 LEFT · 2 DAYS"

        f.bodyweightSeries = [83.6, 83.4, 83.5, 83.2, 83.3, 83.1, 83.2, 83.0, 82.9, 83.1, 82.8, 82.9, 82.7, 82.9, 82.8, 82.6, 82.7, 82.9, 83.0, 82.8, 82.7, 82.6, 82.8, 82.5, 82.6, 82.4, 82.5, 82.6, 82.3, 82.4]
        s.bodyweight = 82.4
        f.bodyweightDelta7d = -0.6
        f.bodyweightStart = "6 SEP"

        f.friends = [
            PWFriendSession(initials: "MK", name: "Maya K", workout: "Legs", meta: "14 SETS · 48 MIN", ago: "1H"),
            PWFriendSession(initials: "JT", name: "Jonah T", workout: "Push Day", meta: "18 SETS · 55 MIN", ago: "3H"),
            PWFriendSession(initials: "RS", name: "Riya S", workout: "Pull Day", meta: "PR · DEADLIFT 140×3", ago: "1D"),
        ]
        f.quickStarts = [
            PWQuickStart(name: "PUSH DAY", meta: "PREDICTED · 6 EX", predicted: true),
            PWQuickStart(name: "PULL DAY", meta: "6 EX", predicted: false),
            PWQuickStart(name: "LEGS", meta: "5 EX", predicted: false),
            PWQuickStart(name: "UPPER", meta: "7 EX", predicted: false),
        ]
        f.eco = [
            PWEcoRow(app: "PUMP", key: "SESSIONS", value: "4", of: "/ 5"),
            PWEcoRow(app: "FUEL", key: "KCAL TODAY", value: "1,840", of: "/ 2,400"),
            PWEcoRow(app: "STRIDE", key: "KM THIS WK", value: "18.2", of: "/ 25"),
        ]
        s.fixed = f
        return s
    }
}
