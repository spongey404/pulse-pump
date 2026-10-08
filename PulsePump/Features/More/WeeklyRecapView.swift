import SwiftUI
import SwiftData

// MARK: - Weekly Recap  (More Screens.dc.html · 2g)

enum RecapTrend { case up, down }

struct WeeklyRecapView: View {
    let onBack: () -> Void
    @Environment(\.weightUnit) private var unit

    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var users: [User]

    /// 0 = this week, 1 = last week, …
    @State private var weeksBack = 0

    private var calendar: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.firstWeekday = 2
        return c
    }

    private var weekStart: Date {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        return calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: thisWeek)!
    }
    private var weekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekStart)! }
    private var prevStart: Date { calendar.date(byAdding: .day, value: -7, to: weekStart)! }

    private func inRange(_ from: Date, _ to: Date) -> [Workout] {
        workouts.filter { $0.date >= from && $0.date < to }
    }
    private var week: [Workout] { inRange(weekStart, weekEnd) }
    private var prev: [Workout] { inRange(prevStart, weekStart) }

    private func working(_ w: Workout) -> [(log: ExerciseLog, set: SetLog)] {
        w.exerciseLogs.flatMap { log in log.sets.filter { $0.setType != .warmup }.map { (log, $0) } }
    }
    /// Total working volume in thousands of the display unit (tonnes for kg, K lb for lbs). SetLog.weight is kg.
    private func volumeTonnes(_ ws: [Workout]) -> Double {
        unit.display(ws.flatMap(working).reduce(0) { $0 + $1.set.weight * Double($1.set.reps) }) / 1000
    }
    private func setCount(_ ws: [Workout]) -> Int { ws.flatMap(working).count }
    private func minutes(_ ws: [Workout]) -> Int { Int(ws.reduce(0) { $0 + $1.duration } / 60) }

    private var target: Int {
        let n = users.first?.selectedSplit?.days.count ?? 0
        return n > 0 ? n : max(week.count, 5)
    }

    private var weekNumber: Int { calendar.component(.weekOfYear, from: weekStart) }
    private var rangeLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let last = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let l = f.string(from: weekStart).uppercased()
        let r = DateFormatter(); r.dateFormat = "MMM d"
        return "WK \(weekNumber) · \(l)–\(r.string(from: last).uppercased())"
    }

    private var bars: [(value: Double, done: Bool)] {
        (0..<7).map { i in
            let day = calendar.date(byAdding: .day, value: i, to: weekStart)!
            let ws = week.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return (Double(setCount(ws)), !ws.isEmpty)
        }
    }

    // Muscle buckets from the design: Back / Chest / Legs / Shoulders / Arms
    private func bucket(_ m: MuscleGroup) -> String? {
        switch m {
        case .back, .lats, .traps: "Back"
        case .chest: "Chest"
        case .quads, .hamstrings, .glutes, .calves: "Legs"
        case .shoulders: "Shoulders"
        case .biceps, .triceps, .forearms: "Arms"
        default: nil
        }
    }
    private func muscleSets(_ ws: [Workout]) -> [String: Int] {
        var out: [String: Int] = [:]
        for (log, _) in ws.flatMap(working) {
            guard let m = log.exercise?.primaryMuscleGroups.first, let b = bucket(m) else { continue }
            out[b, default: 0] += 1
        }
        return out
    }

    private struct PR: Identifiable { let id = UUID(); let name: String; let meta: String; let value: String }
    private var records: [PR] {
        // Heaviest working set per exercise this week that beats everything logged before the week.
        let before = workouts.filter { $0.date < weekStart }.flatMap(working)
        var bestBefore: [String: Double] = [:]
        for (log, s) in before { if let n = log.exercise?.name { bestBefore[n] = max(bestBefore[n] ?? 0, s.weight) } }
        var out: [PR] = []
        for w in week.sorted(by: { $0.date < $1.date }) {
            var top: [String: SetLog] = [:]
            for (log, s) in working(w) {
                guard let n = log.exercise?.name else { continue }
                if s.weight > (top[n]?.weight ?? 0) { top[n] = s }
            }
            for (n, s) in top where s.weight > (bestBefore[n] ?? 0) && bestBefore[n] != nil {
                bestBefore[n] = s.weight
                let f = DateFormatter(); f.dateFormat = "EEE d MMM"
                out.append(PR(name: n,
                              meta: "\(f.string(from: w.date).uppercased()) · \(w.template?.name.uppercased() ?? "WORKOUT")",
                              value: "\(unit.number(s.weight))×\(s.reps)"))
            }
        }
        return out
    }
    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    private func delta(_ a: Double, _ b: Double, pct: Bool) -> (String, RecapTrend)? {
        guard b > 0 else { return nil }
        let d = a - b
        if pct { let p = d / b * 100; return ((p >= 0 ? "+" : "") + String(format: "%.1f%%", p), p >= 0 ? .up : .down) }
        return ((d >= 0 ? "+" : "") + fmt(d), d >= 0 ? .up : .down)
    }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "WEEKLY RECAP", overline: rangeLabel, onBack: onBack) {
                HStack(spacing: 0) {
                    Button { weeksBack += 1 } label: {
                        Text("‹").font(.spaceMono(18)).foregroundStyle(Color.inkMuted).padding(.horizontal, 6)
                    }
                    Button { weeksBack = max(0, weeksBack - 1) } label: {
                        Text("›").font(.spaceMono(18))
                            .foregroundStyle(weeksBack == 0 ? Color.inkGhost : Color.inkMuted).padding(.horizontal, 6)
                    }
                    .disabled(weeksBack == 0)
                }
                .buttonStyle(.plain)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    kpis
                    musclesTable
                    prSection
                    Text("NEXT RECAP · MON \(nextMonday)")
                        .font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    Spacer().frame(height: 16)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }

    private var nextMonday: String {
        let next = calendar.date(byAdding: .day, value: 7, to: calendar.dateInterval(of: .weekOfYear, for: Date())!.start)!
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return f.string(from: next).uppercased()
    }

    // MARK: Sections

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SESSIONS").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(week.count)").font(.archivo(56, weight: .black)).foregroundStyle(Color.accentInk)
                    Text("/\(target)").font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            weekBars.frame(width: 150)
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var weekBars: some View {
        let maxV = max(bars.map(\.value).max() ?? 1, 1)
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(bars[i].done ? Color.pumpAccent : Color.inkPrimary.opacity(0.10))
                        .frame(height: max(3, 40 * bars[i].value / maxV))
                    Text(days[i]).font(.spaceMono(7)).foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 58, alignment: .bottom)
    }

    private var kpis: some View {
        let v = volumeTonnes(week), pv = volumeTonnes(prev)
        let s = setCount(week), ps = setCount(prev)
        let t = minutes(week), pt = minutes(prev)
        return HStack(alignment: .top, spacing: 12) {
            kpi(unit == .kg ? "VOLUME T" : "VOLUME K LB", String(format: "%.1f", v), delta(v, pv, pct: true))
            kpi("SETS", "\(s)", delta(Double(s), Double(ps), pct: false))
            kpi("TIME", "\(t / 60):\(String(format: "%02d", t % 60))",
                pt > 0 ? ((t - pt >= 0 ? "+" : "-") + "\(abs(t - pt) / 60):\(String(format: "%02d", abs(t - pt) % 60))",
                          t - pt >= 0 ? RecapTrend.up : .down) : nil)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func kpi(_ label: String, _ value: String, _ d: (String, RecapTrend)?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            Text(value).font(.archivo(26, weight: .black)).foregroundStyle(Color.inkPrimary)
            if let d {
                Text((d.1 == .up ? "▲ " : "▼ ") + d.0)
                    .font(.spaceMono(9, weight: .bold))
                    .foregroundStyle(d.1 == .up ? Color.signalUp : Color.signalDown)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var musclesTable: some View {
        let cur = muscleSets(week), last = muscleSets(prev)
        let rows = ["Back", "Chest", "Legs", "Shoulders", "Arms"]
        return VStack(spacing: 0) {
            sectionHeader("SETS BY MUSCLE", meta: "VS WK \(weekNumber - 1)").padding(.top, 10)
            HStack(spacing: 8) {
                Text("MUSCLE").frame(maxWidth: .infinity, alignment: .leading)
                Text("SETS").frame(width: 50, alignment: .trailing)
                Text("VS LAST").frame(width: 64, alignment: .trailing)
            }
            .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            ForEach(rows, id: \.self) { m in
                let c = cur[m] ?? 0, l = last[m] ?? 0, d = c - l
                HStack(spacing: 8) {
                    Text(m).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(c)").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        .frame(width: 50, alignment: .trailing)
                    Text(d == 0 ? "0" : (d > 0 ? "▲ +\(d)" : "▼ \(d)"))
                        .font(.spaceMono(10, weight: .bold))
                        .foregroundStyle(d > 0 ? Color.signalUp : d < 0 ? Color.signalDown : Color.inkMuted)
                        .frame(width: 64, alignment: .trailing)
                }
                .padding(.horizontal, 16).frame(height: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
        }
    }

    private var prSection: some View {
        VStack(spacing: 0) {
            sectionHeader("PERSONAL RECORDS", meta: "\(records.count)").padding(.top, 20)
            if records.isEmpty {
                Text("NO NEW RECORDS THIS WEEK")
                    .font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            ForEach(records) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.name).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                        Text(p.meta).font(.spaceMono(8)).tracking(1).foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                    // PR treatment: ink + underline (design-system PRMark)
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(p.value).font(.spaceMono(15, weight: .bold))
                            Text(unit.label).font(.spaceMono(8)).tracking(1).foregroundStyle(Color.inkMuted)
                        }
                        .foregroundStyle(Color.inkPrimary)
                        Rectangle().fill(Color.inkPrimary).frame(height: 1.5)
                    }
                    .fixedSize()
                }
                .padding(.horizontal, 16).frame(height: 52)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
        }
    }

    private func sectionHeader(_ title: String, meta: String) -> some View {
        HStack {
            Text(title).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            Spacer()
            Text(meta).font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 16).padding(.bottom, 4)
    }
}
