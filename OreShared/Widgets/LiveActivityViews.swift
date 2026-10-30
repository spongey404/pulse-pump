import SwiftUI
import AppIntents

// MARK: - Live Activity + Dynamic Island layouts (Ore Widgets design, section 08)
//
// Pure SwiftUI views shared by the real ActivityConfiguration (extension) and the Widget Gallery (app).
// The lock-screen card follows OreTheme (light/dark). The island is always black, so it uses the
// dark-mode values directly: bone ink #ECE5D6 and the lifted accent #1AA7FF.

struct WorkoutLiveActivityPreviewState {
    enum Phase { case resting, lifting, restOver }

    var phase: Phase = .resting
    var workoutName = "Push Day"
    var exercise = "Bench Press"
    var exerciseShort = "BENCH"
    var setIndex = 3
    var setCount = 4
    var completedSets = 9
    var totalSets = 18
    var weight = "82.5"
    var reps = "6"
    var unit = "KG"
    var lastTime = "80 × 6 · 80 × 6 · 80 × 5"
    var lastTimeDate = "24:18"

    // Live clocks (real activity)
    var restStart: Date?
    var restEnd: Date?
    var elapsedStart: Date?
    var overSince: Date?
    // Fixed text (gallery); win over live clocks when set
    var fixedRest: String?
    var fixedElapsed: String?
    var fixedOver: String?
    var fixedProgress: Double?

    /// Real activity uses Button(intent:); the gallery renders plain labels.
    var interactive = false

    var nextLabel: String { weight.isEmpty ? reps.isEmpty ? "" : "× \(reps)" : "\(weight) × \(reps)" }
    var hasNext: Bool { !weight.isEmpty || !reps.isEmpty }

    static let restingSample = WorkoutLiveActivityPreviewState(
        phase: .resting, fixedRest: "1:24", fixedElapsed: "24:18", fixedProgress: 0.47)
    static let liftingSample = WorkoutLiveActivityPreviewState(
        phase: .lifting, fixedRest: "0:00", fixedElapsed: "24:18")
    static let restOverSample = WorkoutLiveActivityPreviewState(
        phase: .restOver, fixedRest: "0:00", fixedElapsed: "24:18", fixedOver: "0:12")
}

extension WorkoutLiveActivityPreviewState {
    init(attributes: WorkoutActivityAttributes, state s: WorkoutActivityAttributes.ContentState,
         isStale: Bool = false, interactive: Bool = true) {
        self.init()
        workoutName = attributes.workoutName
        exercise = s.currentExercise
        exerciseShort = s.exerciseShort.isEmpty ? String(s.currentExercise.uppercased().prefix(8)) : s.exerciseShort
        setIndex = s.setIndex
        setCount = s.setCount
        completedSets = s.completedSets
        totalSets = s.totalSets
        weight = s.nextWeight
        reps = s.nextReps
        unit = s.weightUnit
        lastTime = s.lastTime
        lastTimeDate = s.lastTimeDate
        elapsedStart = attributes.startTime
        restStart = s.restStartDate
        restEnd = s.restEndDate
        overSince = s.restOverSince
        self.interactive = interactive
        if let over = s.restOverSince {
            phase = .restOver; overSince = over
        } else if let end = s.restEndDate {
            if isStale || end <= Date() { phase = .restOver; overSince = end } else { phase = .resting }
        } else {
            phase = .lifting
        }
    }
}

// MARK: Tokens

private enum LA {
    static let accent = Color(pwHex: "1AA7FF")
    static let bone = Color(pwHex: "ECE5D6")
    static let boneMuted = Color(pwHex: "ECE5D6").opacity(0.5)
    static let boneRule = Color(pwHex: "ECE5D6").opacity(0.14)
    static let boneFaint = Color(pwHex: "ECE5D6").opacity(0.13)
    static let islandButton = Color(pwHex: "2E2A26")
}

private func cap(_ s: String, _ color: Color, size: CGFloat = 8, tracking: CGFloat = 1.2) -> some View {
    Text(s).font(.spaceMono(size)).tracking(tracking).foregroundStyle(color).lineLimit(1)
}

// MARK: Clock text

private enum LAClockKind { case rest, elapsed, over }

private struct LAClock: View {
    let s: WorkoutLiveActivityPreviewState
    let kind: LAClockKind
    var size: CGFloat
    var color: Color
    var bold = true
    var alignment: Alignment = .leading

    var body: some View {
        content
            .font(.spaceMono(size, weight: bold ? .bold : .regular))
            .foregroundStyle(color)
            .lineLimit(1)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: alignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .rest:
            if let f = s.fixedRest { Text(f) }
            else if let end = s.restEnd {
                Text(timerInterval: Date.now...max(end, Date.now), pauseTime: nil, countsDown: true, showsHours: false)
            } else { Text("0:00") }
        case .elapsed:
            if let f = s.fixedElapsed { Text(f) }
            else if let st = s.elapsedStart {
                Text(timerInterval: st...st.addingTimeInterval(86400 * 2), pauseTime: nil, countsDown: false, showsHours: false)
            } else { Text("0:00") }
        case .over:
            if let f = s.fixedOver { Text("+" + f) }
            else if let o = s.overSince {
                HStack(spacing: 0) {
                    Text("+")
                    Text(timerInterval: o...o.addingTimeInterval(86400), pauseTime: nil, countsDown: false, showsHours: false)
                }
            } else { Text("+0:00") }
        }
    }
}

private struct LARestBar: View {
    let s: WorkoutLiveActivityPreviewState
    let fill: Color
    let track: Color

    var body: some View {
        Group {
            if let p = s.fixedProgress {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(track)
                        Rectangle().fill(fill).frame(width: g.size.width * p)
                    }.clipShape(Capsule())
                }
            } else if let a = s.restStart, let b = s.restEnd, b > a {
                ProgressView(timerInterval: a...b, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(fill)
            } else {
                Capsule().fill(track)
            }
        }
        .frame(height: 3)
    }
}

@ViewBuilder
private func laAction<I: AppIntent, L: View>(_ intent: I, interactive: Bool, @ViewBuilder label: () -> L) -> some View {
    if interactive { Button(intent: intent, label: label).buttonStyle(.plain) } else { label() }
}

private struct LATicks: View {
    let done: Int, total: Int
    let height: CGFloat
    let doneColor: Color, currentColor: Color, restColor: Color

    var body: some View {
        let n = max(total, 1)
        HStack(spacing: 3) {
            ForEach(0..<n, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < done ? doneColor : i == done ? currentColor : restColor)
                    .frame(height: height)
            }
        }
    }
}

// MARK: - Lock screen card (8A / 8B)

struct WorkoutLockScreenCard: View {
    let s: WorkoutLiveActivityPreviewState

    private var resting: Bool { s.phase == .resting }
    private var heroLabel: String { s.phase == .lifting ? "ELAPSED" : s.phase == .restOver ? "REST DONE" : "REST" }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if resting {
                    HStack(spacing: 0) {
                        Text(s.workoutName.uppercased() + " · ")
                        if s.fixedElapsed != nil { Text(s.fixedElapsed!) }
                        else if let st = s.elapsedStart {
                            Text(timerInterval: st...st.addingTimeInterval(86400 * 2), pauseTime: nil, countsDown: false, showsHours: false)
                                .monospacedDigit()
                        }
                    }
                    .font(.spaceMono(9)).tracking(1.5).foregroundStyle(OreTheme.muted).lineLimit(1)
                } else {
                    cap(s.workoutName.uppercased(), OreTheme.muted, size: 9, tracking: 1.5)
                }
                Spacer(minLength: 8)
                cap("\(s.completedSets)/\(s.totalSets) SETS", OreTheme.muted, size: 9, tracking: 1.5)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    cap(heroLabel, resting || s.phase == .restOver ? OreTheme.accentInk : OreTheme.muted)
                    if s.phase == .lifting {
                        LAClock(s: s, kind: .elapsed, size: 40, color: OreTheme.ink)
                    } else if s.phase == .restOver {
                        LAClock(s: s, kind: .over, size: 40, color: OreTheme.accentInk)
                    } else {
                        LAClock(s: s, kind: .rest, size: 40, color: OreTheme.accentInk)
                    }
                }
                .frame(width: 150, alignment: .leading)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    cap((s.phase == .lifting ? "NOW" : s.phase == .restOver ? "UP" : "NEXT") + " · SET \(s.setIndex)/\(s.setCount)", OreTheme.muted)
                    Text(s.exercise).font(.archivo(14, weight: .semibold)).foregroundStyle(OreTheme.ink).lineLimit(1)
                    if s.hasNext {
                        Text("\(s.nextLabel.replacingOccurrences(of: " ×", with: " \(s.unit) ×"))")
                            .font(.spaceMono(11)).foregroundStyle(OreTheme.ink).lineLimit(1)
                    }
                }
            }

            if resting {
                LARestBar(s: s, fill: OreTheme.accent, track: OreTheme.ruleStrong)
                HStack(spacing: 8) {
                    laAction(AdjustRestIntent(deltaSeconds: -15), interactive: s.interactive) { sunkenButton("-15S") }
                    laAction(AdjustRestIntent(deltaSeconds: 15), interactive: s.interactive) { sunkenButton("+15S") }
                    laAction(SkipRestIntent(), interactive: s.interactive) { sunkenButton("SKIP ›") }
                }
            } else {
                LATicks(done: s.completedSets, total: s.totalSets, height: 6,
                        doneColor: OreTheme.ink, currentColor: OreTheme.accent, restColor: OreTheme.faint)
                laAction(LogSetIntent(), interactive: s.interactive) {
                    Text("✓ LOG SET").font(.archivo(13, weight: .black)).tracking(0.5).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(OreTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func sunkenButton(_ t: String) -> some View {
        Text(t).font(.spaceMono(10, weight: .bold)).tracking(1).foregroundStyle(OreTheme.ink)
            .frame(maxWidth: .infinity).frame(height: 32)
            .background(OreTheme.sunken, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Dynamic Island

enum WorkoutIslandView {
    /// Expanded leading region (hero).
    struct Leading: View {
        let s: WorkoutLiveActivityPreviewState
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                switch s.phase {
                case .resting:
                    cap("REST · " + s.workoutName.uppercased(), LA.accent)
                    LAClock(s: s, kind: .rest, size: 32, color: LA.accent)
                case .lifting:
                    cap("NOW · \(s.exercise.uppercased()) · SET \(s.setIndex)/\(s.setCount)", LA.boneMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(s.nextLabel).font(.spaceMono(32, weight: .bold)).foregroundStyle(LA.bone)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        if s.hasNext { cap(s.unit, LA.boneMuted) }
                    }
                case .restOver:
                    cap("REST DONE", LA.accent)
                    LAClock(s: s, kind: .rest, size: 32, color: LA.accent)
                }
            }
        }
    }

    /// Expanded trailing region.
    struct Trailing: View {
        let s: WorkoutLiveActivityPreviewState
        var body: some View {
            VStack(alignment: .trailing, spacing: 0) {
                if s.phase == .restOver {
                    LAClock(s: s, kind: .over, size: 22, color: LA.bone, alignment: .trailing)
                    cap("OVER REST", LA.boneMuted)
                } else {
                    Text("\(s.completedSets)/\(s.totalSets)").font(.spaceMono(22, weight: .bold)).foregroundStyle(LA.bone)
                    cap("SETS DONE", LA.boneMuted)
                }
            }
        }
    }

    /// Expanded bottom region.
    struct Bottom: View {
        let s: WorkoutLiveActivityPreviewState
        var body: some View {
            VStack(spacing: 12) {
                switch s.phase {
                case .resting:
                    LARestBar(s: s, fill: LA.accent, track: LA.boneRule)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            cap("NEXT · SET \(s.setIndex)/\(s.setCount)", LA.boneMuted)
                            exerciseLine
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 6) {
                            laAction(AdjustRestIntent(deltaSeconds: 15), interactive: s.interactive) { pill("+15S") }
                            laAction(SkipRestIntent(), interactive: s.interactive) { pill("SKIP ›") }
                        }
                    }
                case .lifting:
                    LATicks(done: s.completedSets, total: s.totalSets, height: 5,
                            doneColor: LA.bone, currentColor: LA.accent, restColor: LA.boneFaint)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if !s.lastTime.isEmpty {
                                cap("LAST TIME" + (s.lastTimeDate.isEmpty ? "" : " · " + s.lastTimeDate), LA.boneMuted)
                                Text(s.lastTime).font(.spaceMono(11)).foregroundStyle(LA.bone).lineLimit(1).minimumScaleFactor(0.7)
                            } else {
                                cap("NEXT · SET \(s.setIndex)/\(s.setCount)", LA.boneMuted)
                                exerciseLine
                            }
                        }
                        Spacer(minLength: 8)
                        logButton
                    }
                case .restOver:
                    Rectangle().fill(LA.boneRule).frame(height: 1)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            cap("UP · SET \(s.setIndex)/\(s.setCount)", LA.boneMuted)
                            exerciseLine
                        }
                        Spacer(minLength: 8)
                        logButton
                    }
                }
            }
        }

        private var exerciseLine: some View {
            HStack(spacing: 0) {
                Text(s.exercise + (s.hasNext ? " · " : "")).font(.archivo(13, weight: .semibold)).foregroundStyle(LA.bone).lineLimit(1)
                if s.hasNext {
                    Text(s.nextLabel.replacingOccurrences(of: "×", with: "×")).font(.spaceMono(11)).foregroundStyle(LA.bone).lineLimit(1)
                }
            }
        }
        private var logButton: some View {
            laAction(LogSetIntent(), interactive: s.interactive) {
                Text("✓ LOG SET").font(.archivo(12, weight: .black)).tracking(0.5).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(LA.accent, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        private func pill(_ t: String) -> some View {
            Text(t).font(.spaceMono(10, weight: .bold)).tracking(1).foregroundStyle(LA.bone)
                .padding(.horizontal, 10).frame(height: 28)
                .background(LA.islandButton, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Compact leading.
    struct CompactLeading: View {
        let s: WorkoutLiveActivityPreviewState
        var body: some View {
            if s.phase == .lifting {
                HStack(spacing: 6) {
                    Rectangle().fill(LA.accent).frame(width: 8, height: 8)
                    Text(String(s.exerciseShort.prefix(6))).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                        .foregroundStyle(LA.bone).lineLimit(1)
                }
            } else {
                Text(s.phase == .restOver ? "DONE" : "REST").font(.spaceMono(9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(LA.accent)
            }
        }
    }

    /// Compact trailing.
    struct CompactTrailing: View {
        let s: WorkoutLiveActivityPreviewState
        var body: some View {
            if s.phase == .lifting || s.phase == .restOver {
                Text(s.nextLabel.replacingOccurrences(of: " × ", with: "×")).font(.spaceMono(12, weight: .bold))
                    .foregroundStyle(s.phase == .restOver ? LA.accent : LA.bone).lineLimit(1)
            } else {
                LAClock(s: s, kind: .rest, size: 12, color: LA.accent, alignment: .trailing)
                    .frame(maxWidth: 48, alignment: .trailing)
            }
        }
    }

    /// Minimal: rest seconds in accent, or next reps.
    struct Minimal: View {
        let s: WorkoutLiveActivityPreviewState
        var body: some View {
            if s.phase == .resting {
                if let f = s.fixedRest, let secs = Self.seconds(f) {
                    Text("\(secs)").font(.spaceMono(10, weight: .bold)).foregroundStyle(LA.accent)
                } else {
                    LAClock(s: s, kind: .rest, size: 10, color: LA.accent, alignment: .center)
                }
            } else {
                Text("×" + (s.reps.isEmpty ? "–" : s.reps)).font(.spaceMono(10, weight: .bold))
                    .foregroundStyle(s.phase == .restOver ? LA.accent : LA.bone)
            }
        }
        static func seconds(_ mmss: String) -> Int? {
            let p = mmss.split(separator: ":").compactMap { Int($0) }
            return p.count == 2 ? p[0] * 60 + p[1] : nil
        }
    }

    /// Full expanded block as the gallery draws it (the real island splits it across regions).
    struct Expanded: View {
        let s: WorkoutLiveActivityPreviewState
        var body: some View {
            VStack(spacing: 12) {
                HStack(alignment: .bottom) {
                    Leading(s: s)
                    Spacer(minLength: 8)
                    Trailing(s: s)
                }
                Bottom(s: s)
            }
            .padding(.top, 16).padding(.horizontal, 20).padding(.bottom, 18)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
        }
    }
}

// MARK: - Gallery

enum LiveActivityGallery {
    static let blurb = "Live Activity restyle. Rest countdown is the hero; between sets the elapsed time takes its place. -15S, +15S and SKIP are interactive. Red is removed from rest; it now reads in the accent. The island is always black, so it uses the dark values."

    private static func card(_ s: WorkoutLiveActivityPreviewState) -> AnyView {
        AnyView(WorkoutLockScreenCard(s: s)
            .frame(width: 364)
            .background(OreTheme.canvas, in: RoundedRectangle(cornerRadius: 22, style: .continuous)))
    }
    private static func pill<C: View>(_ w: CGFloat, _ h: CGFloat, radius: CGFloat = 20, pad: CGFloat = 0, @ViewBuilder _ c: () -> C) -> AnyView {
        AnyView(c().padding(.horizontal, pad).frame(width: w, height: h)
            .background(Color.black, in: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }
    private static func compact(_ s: WorkoutLiveActivityPreviewState) -> AnyView {
        pill(250, 37, pad: 14) {
            HStack { WorkoutIslandView.CompactLeading(s: s); Spacer(minLength: 0); WorkoutIslandView.CompactTrailing(s: s) }
        }
    }
    private static func expanded(_ s: WorkoutLiveActivityPreviewState) -> AnyView {
        AnyView(WorkoutIslandView.Expanded(s: s).frame(width: 370))
    }

    static var gallery: [PWGalleryItem] {
        let rest = WorkoutLiveActivityPreviewState.restingSample
        let lift = WorkoutLiveActivityPreviewState.liftingSample
        let over = WorkoutLiveActivityPreviewState.restOverSample
        let lockSize = CGSize(width: 364, height: 176)
        let compactSize = CGSize(width: 250, height: 37)
        return [
            PWGalleryItem("8A · LOCK SCREEN · RESTING", .medium, customSize: lockSize) { _ in card(rest) },
            PWGalleryItem("8B · LOCK SCREEN · LIFTING", .medium, customSize: lockSize) { _ in card(lift) },
            PWGalleryItem("8C · COMPACT · RESTING", .small, customSize: compactSize) { _ in compact(rest) },
            PWGalleryItem("8D · COMPACT · LIFTING · NEXT SET", .small, customSize: compactSize) { _ in compact(lift) },
            PWGalleryItem("8E · MINIMAL · REST SECS", .small, customSize: CGSize(width: 37, height: 37)) { _ in
                pill(37, 37) { WorkoutIslandView.Minimal(s: { var r = rest; r.fixedRest = "1:24"; return r }()) } },
            PWGalleryItem("8E · MINIMAL · NEXT REPS", .small, customSize: CGSize(width: 37, height: 37)) { _ in
                pill(37, 37) { WorkoutIslandView.Minimal(s: lift) } },
            PWGalleryItem("8F · EXPANDED · RESTING", .medium, customSize: CGSize(width: 370, height: 150)) { _ in expanded(rest) },
            PWGalleryItem("8G · EXPANDED · LIFTING · NEXT SET", .medium, customSize: CGSize(width: 370, height: 150)) { _ in expanded(lift) },
            PWGalleryItem("8H · EXPANDED · REST ENDED (AUTO)", .medium, customSize: CGSize(width: 370, height: 140)) { _ in expanded(over) },
        ]
    }
}
