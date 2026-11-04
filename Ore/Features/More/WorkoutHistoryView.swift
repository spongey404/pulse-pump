import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }) private var templates: [WorkoutTemplate]
    #if DEBUG
    // `-debugHistoryMode calendar` opens the calendar view for visual checks.
    @State private var viewMode: HistoryViewMode = UserDefaults.standard.string(forKey: "debugHistoryMode") == "calendar" ? .calendar : .list
    #else
    @State private var viewMode: HistoryViewMode = .list
    #endif
    @State private var calendarSelection: CalendarSelection = .day(Date())
    @State private var openedWorkout: Workout?
    @State private var workoutToDelete: Workout?

    // MARK: - Helpers

    private var stats: HistoryStats { HistoryStats(workouts: workouts) }

    private var workoutDateSet: Set<String> { stats.workoutDateSet }

    private func dateKey(_ date: Date) -> String { stats.dateKey(date) }

    private func workoutsOn(_ date: Date) -> [Workout] { stats.workoutsOn(date) }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            switch viewMode {
            case .list: listContent
            case .calendar: calendarContent
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $openedWorkout) { w in
            LocalWorkoutFullView(workout: w, editable: true).navigationBarHidden(true)
        }
        .confirmationDialog("Delete Workout?", isPresented: .init(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let w = workoutToDelete { modelContext.softDelete(w); workoutToDelete = nil }
            }
        } message: {
            Text("This workout will be permanently deleted.")
        }
    }

    // MARK: - Header (Ore History Calendar Final)

    private var header: some View {
        HStack(spacing: 12) {
            Button { (onBack ?? { dismiss() })() } label: {
                Text("‹").font(.archivo(22)).foregroundStyle(Color.inkPrimary)
                    .frame(width: 44, height: 44).background(Color.surf2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain).accessibilityLabel("Back").accessibilityIdentifier(AX.nav.back)
            Text("HISTORY").font(.archivo(28, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier(AX.nav.title("HISTORY"))
            HStack(spacing: 2) {
                ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                    let active = viewMode == mode
                    Button { withAnimation(.easeInOut(duration: 0.15)) { viewMode = mode } } label: {
                        historyIcon(mode)
                            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                            .frame(width: 20, height: 20)
                            .foregroundStyle(active ? Color.accentInk : Color.inkMuted)
                        .frame(width: 44, height: 36)
                        .background(active ? (scheme == .dark ? Color.surf : Color.white) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode == .list ? "List view" : "Calendar view")
                    .accessibilityIdentifier(mode == .list ? AX.history.modeList : AX.history.modeCalendar)
                }
            }
            .padding(3).background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
        .padding(.bottom, 1)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func historyIcon(_ mode: HistoryViewMode) -> AnyShape {
        mode == .list ? AnyShape(HistoryListIcon()) : AnyShape(HistoryCalendarIcon())
    }

    // MARK: - Calendar (the shared component, fullscreen)

    private var calendarContent: some View {
        ScrollView {
            OreCalendarView(mode: .fullscreen, source: calendarData, selection: $calendarSelection, cardAction: .openWorkout,
                            onOpenWorkout: { s in openedWorkout = workouts.first { $0.id == s.id } })
        }
        .scrollIndicators(.hidden)
    }

    private var calendarData: WorkoutCalendarData { WorkoutCalendarData(workouts: workouts, templates: templates) }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        if workouts.isEmpty {
            emptyState
        } else {
            List {
                ForEach(monthGroups, id: \.title) { group in
                    MoreSectionLabel(title: group.title)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    ForEach(group.workouts) { workout in
                        Button { openedWorkout = workout } label: {
                            listRow(workout)
                        }
                        .buttonStyle(OreRowPressStyle())
                        .accessibilityIdentifier(AX.history.row)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { workoutToDelete = workout } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Color.signalDown)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .environment(\.defaultMinListRowHeight, 1)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 32, for: .scrollContent)
        }
    }

    /// Workouts grouped by month, newest first: "OCTOBER 2026 · 18 WORKOUTS".
    private var monthGroups: [(title: String, workouts: [Workout])] {
        let cal = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [Workout]] = [:]
        for w in workouts {
            let month = cal.date(from: cal.dateComponents([.year, .month], from: w.date)) ?? w.date
            if buckets[month] == nil { order.append(month) }
            buckets[month, default: []].append(w)
        }
        return order.map { month in
            let list = buckets[month] ?? []
            return ("\(monthYearLabel(month)) · \(list.count) \(list.count == 1 ? "WORKOUT" : "WORKOUTS")", list)
        }
    }

    /// Row: the workout's name, then "SAT 25 OCT · 62 MIN · 24 SETS" in Space Mono caps (real numbers only) and a ›.
    private func listRow(_ workout: Workout) -> some View {
        let sets = workout.workingSetCount
        let mins = Int(workout.duration) / 60
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE d MMM"
        let detail = "\(f.string(from: workout.date).uppercased()) · \(mins) MIN · \(sets) \(sets == 1 ? "SET" : "SETS")"
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 16) {
                Text(workout.template?.name ?? "Workout")
                    .font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
            }
            Text(detail).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .frame(minHeight: 44).frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("NO WORKOUTS YET")
                .font(.archivo(28, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.inkFaint)
                .accessibilityIdentifier(AX.history.empty)
            Text("Complete your first workout to see it here.")
                .font(.archivo(13))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Calendar helpers

    private func monthYearLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: date).uppercased()
    }

    private func calDateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: date).uppercased()
    }

    // MARK: - Date formatting helpers

    private func shortDay(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date).uppercased()
    }
    private func dayNum(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: date).uppercased()
    }
}

enum HistoryViewMode: String, CaseIterable {
    case list = "LIST"
    case calendar = "CALENDAR"
}

// MARK: - Legacy row alias (keep callers compiling)
typealias WorkoutHistoryRow = HistoryWorkoutRow

struct HistoryWorkoutRow: View {
    let workout: Workout
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 1) {
                    let f1: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()
                    let f2: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d"; return f }()
                    let f3: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM"; return f }()
                    Text(f1.string(from: workout.date).uppercased()).font(.spaceMono(7, weight: .bold)).foregroundStyle(.white)
                    Text(f2.string(from: workout.date)).font(.spaceMono(15, weight: .bold)).foregroundStyle(.white)
                    Text(f3.string(from: workout.date).uppercased()).font(.spaceMono(7)).foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 42).padding(.vertical, 6)
                .background(Color.oreAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text((workout.template?.name ?? "Workout").uppercased())
                        .font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                    let sets = workout.workingSetCount
                    Text("\(workout.exerciseLogs.count) EX · \(sets) SETS · \(Int(workout.duration)/60)M")
                        .font(.spaceMono(8)).foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkFaint)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }
}


/// The History view switch's icons, drawn on a 24-unit grid like the design's (Lucide: list, calendar).
struct HistoryListIcon: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / 24
        var p = Path()
        for y in [6.0, 12, 18] {
            p.move(to: CGPoint(x: 8 * k, y: y * k)); p.addLine(to: CGPoint(x: 21 * k, y: y * k))
            p.move(to: CGPoint(x: 3 * k, y: y * k)); p.addLine(to: CGPoint(x: 3.01 * k, y: y * k))
        }
        return p
    }
}

struct HistoryCalendarIcon: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / 24
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 3 * k, y: 4 * k, width: 18 * k, height: 18 * k), cornerSize: CGSize(width: 2 * k, height: 2 * k))
        p.move(to: CGPoint(x: 16 * k, y: 2 * k)); p.addLine(to: CGPoint(x: 16 * k, y: 6 * k))
        p.move(to: CGPoint(x: 8 * k, y: 2 * k)); p.addLine(to: CGPoint(x: 8 * k, y: 6 * k))
        p.move(to: CGPoint(x: 3 * k, y: 10 * k)); p.addLine(to: CGPoint(x: 21 * k, y: 10 * k))
        return p
    }
}
