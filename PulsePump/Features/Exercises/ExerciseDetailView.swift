import SwiftUI
import SwiftData

/// One exercise: an ABOUT tab (records, the muscles it works, setup) and a HISTORY tab (trend chart and past
/// sessions). Layout is the design's `Exercise Detail.dc.html`.
///
/// `onAddToWorkout` is the context: it is set only when the page is opened from a workout (the add-exercise
/// list inside the logger), which is the only place there is a workout to add to. Opened from search or the
/// library it is nil, and there is no ADD TO WORKOUT button.
struct ExerciseDetailView: View {
    let exercise: Exercise
    var onAddToWorkout: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @Query private var users: [User]

    private enum Tab { case about, history }
    @State private var tab: Tab = .about
    @State private var metric: ExerciseMetric = .e1rm
    @State private var range: ExerciseRange = .threeMonths
    @State private var showAllSessions = false

    private var model: ExerciseDetailModel { ExerciseDetailModel.make(logs: exercise.finalLogs) }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            titleBlock
            tabs
            ScrollView {
                switch tab {
                case .about: about
                case .history: history
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let onAddToWorkout {
                DockedCTA(primaryLabel: "ADD TO WORKOUT", primaryID: AX.exercise.detailAdd, action: onAddToWorkout)
                    .background(Color.canvasBg)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("‹ EXERCISES")
                    .font(.spaceMono(10)).tracking(1.5)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AX.exercise.detailBack)
            Spacer()
            Menu {
                ShareLink(item: exercise.name)
            } label: {
                Text("···")
                    .font(.spaceMono(14, weight: .bold)).tracking(1)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var subtitle: String {
        var parts = [exercise.equipmentType.displayName]
        if let first = exercise.primaryMuscleGroups.first { parts.append(first.displayName) }
        parts.append(exercise.movementPattern.isCompound ? "Compound" : "Isolation")
        return parts.joined(separator: " · ").uppercased()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.archivo(28, weight: .black))
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(0)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.spaceMono(9)).tracking(1.5)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 14)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton("ABOUT", .about, id: AX.exercise.detailTabAbout)
            tabButton("HISTORY", .history, id: AX.exercise.detailTabHistory)
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func tabButton(_ title: String, _ value: Tab, id: String) -> some View {
        Button { tab = value } label: {
            Text(title)
                .font(.spaceMono(10, weight: .bold)).tracking(2)
                .foregroundStyle(tab == value ? Color.inkPrimary : Color.inkMuted)
                .frame(maxWidth: .infinity).frame(height: 40)
                .overlay(alignment: .bottom) {
                    if tab == value { Rectangle().fill(Color.pumpAccent).frame(height: 2) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }

    // MARK: About

    private var about: some View {
        VStack(spacing: 0) {
            kpiRow
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AX.exercise.detailProgress)

            sectionHeader("MUSCLES WORKED")
            MuscleLevelMap(levels: MuscleLevels.levels(primary: exercise.primaryMuscleGroups, secondary: exercise.secondaryMuscleGroups))
                .frame(height: 240)
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
                .overlay(alignment: .bottom) { hair }
            HStack(spacing: 0) {
                muscleColumn("PRIMARY", exercise.primaryMuscleGroups)
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                muscleColumn("SECONDARY", exercise.secondaryMuscleGroups)
            }
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .bottom) { hair }

            sectionHeader("SETUP")
            ForEach(setupRows, id: \.label) { row in
                HStack(spacing: 12) {
                    Text(row.label).font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    Spacer()
                    Text(row.value).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                }
                .padding(.horizontal, 16).frame(height: 44)
                .overlay(alignment: .bottom) { hair }
            }
            Color.clear.frame(height: 24)
        }
    }

    private var hair: some View { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(9)).tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
            .overlay(alignment: .bottom) { hair }
    }

    private func muscleColumn(_ title: String, _ muscles: [MuscleGroup]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            Text(muscles.isEmpty ? "—" : muscles.map(\.displayName).joined(separator: " · "))
                .font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private struct KPI { let value: String; let unit: String; let label: String; let isPR: Bool }

    private var kpis: [KPI] {
        let m = model
        func setText(_ s: (weightKg: Double, reps: Int)?) -> String {
            s.map { "\(unit.number($0.weightKg))×\($0.reps)" } ?? "—"
        }
        return [
            KPI(value: m.estimated1RMKg.map { unit.number($0) } ?? "—", unit: m.estimated1RMKg == nil ? "" : unit.label, label: "EST 1RM", isPR: false),
            KPI(value: setText(m.bestSet), unit: "", label: "BEST SET", isPR: m.bestSet != nil),
            KPI(value: setText(m.lastSet), unit: "", label: "LAST", isPR: false),
            KPI(value: "\(m.sessionCount)", unit: "", label: "SESSIONS", isPR: false),
        ]
    }

    private var kpiRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(kpis.enumerated()), id: \.offset) { index, k in
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        prText(k.value, size: 17, isPR: k.isPR)
                        if !k.unit.isEmpty {
                            Text(k.unit).font(.spaceMono(8)).tracking(1).foregroundStyle(Color.inkMuted)
                        }
                    }
                    Text(k.label).font(.spaceMono(7)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14).padding(.bottom, 12)
                .overlay(alignment: .leading) {
                    if index > 0 { Rectangle().fill(Color.dsHairLine).frame(width: 1) }
                }
            }
        }
        .overlay(alignment: .bottom) { hair }
    }

    /// A number in the app's PR treatment (ink text with a 1.5pt underline), or plain.
    @ViewBuilder
    private func prText(_ text: String, size: CGFloat, isPR: Bool, weight: Font.Weight = .bold) -> some View {
        if isPR {
            VStack(spacing: 2) {
                Text(text).font(.spaceMono(size, weight: weight)).foregroundStyle(Color.inkPrimary)
                Rectangle().fill(Color.inkPrimary).frame(height: 1.5)
            }
            .fixedSize()
        } else {
            Text(text).font(.spaceMono(size, weight: weight)).foregroundStyle(Color.inkPrimary)
        }
    }

    private var user: User? { users.first }

    private var setupRows: [(label: String, value: String)] {
        let d = UserDefaults.standard
        let rest = exercise.movementPattern.isCompound
            ? d.object(forKey: "compoundRestSeconds") as? Int ?? RestTimerService.defaultCompoundSeconds
            : d.object(forKey: "isolationRestSeconds") as? Int ?? RestTimerService.defaultIsolationSeconds
        let increment = user?.progressionIncrementKg ?? 2.5
        return [
            ("EQUIPMENT", exercise.equipmentType.displayName),
            ("PATTERN", exercise.movementPattern.displayName),
            ("DEFAULT REST", String(format: "%d:%02d", rest / 60, rest % 60)),
            ("INCREMENT", unit.format(increment)),
        ]
    }

    // MARK: History

    private static let sessionDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f
    }()
    private static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }()
    private static let monthYear: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f
    }()

    private func chartValue(_ kg: Double) -> String {
        metric == .volume ? unit.volume(kg) : unit.number(kg)
    }

    private func sinceLabel(_ date: Date) -> String {
        (range == .year || range == .all ? Self.monthYear : Self.shortDate).string(from: date).uppercased()
    }

    private var history: some View {
        let m = model
        let points = m.series(metric, range: range)
        let layout = TrendChartLayout(values: points.map(\.value))
        let headline = m.headline(metric, range: range)
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(ExerciseRange.allCases) { r in
                    FilterChip(title: r.label, isSelected: range == r) { range = r }
                        .accessibilityIdentifier(AX.exercise.detailRange(r.label))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.top, 14)

            if m.sessions.isEmpty {
                emptyHistory
            } else {
                chartHeader(headline)
                    .padding(.horizontal, 16).padding(.top, 16)
                chart(points: points, layout: layout)
                    .padding(.horizontal, 16).padding(.top, 12)
                    .accessibilityIdentifier(AX.exercise.detailChart)
                HStack {
                    Text(points.first.map { sinceLabel($0.date) } ?? "")
                    Spacer()
                    Text("TODAY")
                }
                .font(.spaceMono(8)).tracking(1).foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 16).padding(.top, 6)

                HStack {
                    Text("SESSIONS")
                    Spacer()
                    Text("E1RM \(unit.label)")
                }
                .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 8)
                .overlay(alignment: .bottom) { hair }

                let shown = showAllSessions ? m.sessions : Array(m.sessions.prefix(5))
                ForEach(shown) { session in sessionRow(session) }
                if m.sessions.count > 5 {
                    Button { showAllSessions.toggle() } label: {
                        Text(showAllSessions ? "SHOW FEWER ‹" : "SHOW ALL \(m.sessions.count) SESSIONS ›")
                            .font(.spaceMono(9, weight: .bold)).tracking(1.2)
                            .foregroundStyle(Color.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            Color.clear.frame(height: 24)
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 6) {
            Text("NO SESSIONS YET")
                .font(.spaceMono(10, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
            Text("Log this exercise in a workout and its trend and history show up here.")
                .font(.archivo(13)).foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32).padding(.top, 56)
    }

    private func chartHeader(_ headline: ExerciseDetailModel.Headline?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(metric.chartLabel).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(headline.map { chartValue($0.value) } ?? "—")
                        .font(.spaceMono(34, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    Text(unit.label).font(.spaceMono(10)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                if let delta = headline?.deltaPercent, let since = headline?.since {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(delta >= 0 ? "▲" : "▼") \(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta))%")
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(delta >= 0 ? Color.signalUp : Color.signalDown)
                        Text("VS \(sinceLabel(since))").font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(ExerciseMetric.allCases) { mt in
                    Button { metric = mt } label: {
                        Text(mt.selectorLabel)
                            .font(.spaceMono(9, weight: .bold)).tracking(1.2)
                            .foregroundStyle(metric == mt ? Color.inkPrimary : Color.inkFaint)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AX.exercise.detailMetric(mt.selectorLabel))
                }
            }
        }
    }

    /// 150pt chart: three hairlines (top, middle, and a stronger floor), the line, an end dot, and the high/low labels.
    private func chart(points: [ExerciseDetailModel.Point], layout: TrendChartLayout) -> some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                // The design draws in a 358 × 150 box: lines at y 10, 75 and 140; the data between 10 and 140.
                let sx = size.width / 358, sy = size.height / 150
                func hairline(_ y: CGFloat, _ color: Color) {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y * sy)); p.addLine(to: CGPoint(x: size.width, y: y * sy))
                    ctx.stroke(p, with: .color(color), lineWidth: 1)
                }
                hairline(10, .dsHairLine); hairline(75, .dsHairLine); hairline(140, .ruleStrong)
                let mapped = layout.points.map { CGPoint(x: $0.x * size.width, y: (10 + $0.y * 130) * sy) }
                guard let last = mapped.last else { return }
                if mapped.count > 1 {
                    var line = Path(); line.addLines(mapped)
                    ctx.stroke(line, with: .color(Color.pumpAccent), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7)), with: .color(Color.pumpAccent))
                _ = sx
            }
            if !points.isEmpty {
                chartLabel(chartValue(layout.maxValue)).frame(maxWidth: .infinity, alignment: .trailing).offset(y: -2)
                chartLabel(chartValue(layout.minValue)).frame(maxWidth: .infinity, alignment: .trailing).offset(y: 128)
            }
        }
        .frame(height: 150)
    }

    private func chartLabel(_ text: String) -> some View {
        Text(text)
            .font(.spaceMono(8)).foregroundStyle(Color.inkMuted)
            .padding(.leading, 4)
            .background(Color.canvasBg)
    }

    private func sessionRow(_ s: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.workoutName).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text("\(Self.sessionDate.string(from: s.date).uppercased()) · \(s.sets.count) SETS · \(unit.volume(s.volumeKg)) \(unit.label)")
                        .font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
                Text(String(format: "%.1f", unit.display(s.bestE1RMKg)))
                    .font(.spaceMono(15, weight: .bold)).foregroundStyle(Color.inkPrimary)
            }
            // Sets wrap onto further lines when there are many.
            ChipFlowLayout(spacing: 12) {
                ForEach(Array(s.sets.enumerated()), id: \.offset) { _, set in
                    let text = "\(unit.number(set.weightKg))×\(set.reps)"
                    if set.isPR {
                        prText(text, size: 11, isPR: true, weight: .regular)
                    } else {
                        Text(text).font(.spaceMono(11)).foregroundStyle(Color.inkPrimary.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .bottom) { hair }
    }
}
