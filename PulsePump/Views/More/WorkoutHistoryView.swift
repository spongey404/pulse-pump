import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var viewMode: HistoryViewMode = .list
    @State private var selectedDate = Date()
    @State private var calendarMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var workoutToDelete: Workout?
    @State private var selectedWorkout: Workout?

    // MARK: - Helpers

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private var workoutDateSet: Set<String> {
        Set(workouts.map { dayFormatter.string(from: $0.date) })
    }

    private func dateKey(_ date: Date) -> String { dayFormatter.string(from: date) }

    private func workoutsOn(_ date: Date) -> [Workout] {
        let key = dateKey(date)
        return workouts.filter { dateKey($0.date) == key }
    }

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
        .navigationDestination(item: $selectedWorkout) { w in
            WorkoutDetailView(workout: w)
        }
        .confirmationDialog("Delete Workout?", isPresented: .init(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let w = workoutToDelete { modelContext.delete(w); workoutToDelete = nil }
            }
        } message: {
            Text("This workout will be permanently deleted.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Text("HISTORY")
                .font(.archivo(24, weight: .black))
                .tracking(0.5)
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Icon toggle
            HStack(spacing: 2) {
                ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                    let active = viewMode == mode
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewMode = mode } } label: {
                        Image(systemName: mode == .list ? "list.bullet" : "calendar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(active ? Color.pumpAccent : Color.inkMuted)
                            .frame(width: 36, height: 30)
                            .background(active ? Color.canvasBg : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.surf2)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.dsHairLine, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Calendar

    private var calendarContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                calendarGrid
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                Rectangle().fill(Color.dsHairLine).frame(height: 1)

                workoutPreviewSection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            // Month nav
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Text(monthYearLabel(calendarMonth))
                    .font(.archivo(20, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // Day letter headers
            HStack(spacing: 0) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                    Text(d)
                        .font(.spaceMono(9))
                        .tracking(0.8)
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            // Fixed 6-row grid (always 42 cells)
            let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            let days = calendarDays()
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(0..<42, id: \.self) { i in
                    if i < days.count {
                        calCell(days[i])
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private func calCell(_ day: CalDay) -> some View {
        let isSelected = day.date.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } ?? false
        let isToday    = day.date.map { Calendar.current.isDateInToday($0) } ?? false
        let hasWorkout = day.date.map { workoutDateSet.contains(dateKey($0)) } ?? false

        let bg: Color = isSelected ? Color.pumpAccent
                      : hasWorkout ? Color.pumpAccent.opacity(0.1)
                      : Color.clear
        let border: Color = isSelected ? Color.pumpAccent
                          : hasWorkout ? Color.pumpAccent.opacity(0.25)
                          : day.date != nil ? Color.dsHairLine
                          : Color.clear
        let numColor: Color = isSelected ? .white
                            : hasWorkout || isToday ? Color.pumpAccent
                            : Color.inkMuted

        return Button {
            if let date = day.date { selectedDate = date }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(bg)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(border, lineWidth: 1))

                VStack(spacing: 2) {
                    if let d = day.day {
                        Text("\(d)")
                            .font(.spaceMono(11, weight: hasWorkout || isSelected || isToday ? .bold : .regular))
                            .foregroundStyle(numColor)
                        if hasWorkout && !isSelected {
                            Circle()
                                .fill(Color.pumpAccent)
                                .frame(width: 4, height: 4)
                        } else if isSelected {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 4, height: 4)
                        } else {
                            Color.clear.frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(day.date == nil)
    }

    @ViewBuilder
    private var workoutPreviewSection: some View {
        let dayWorkouts = workoutsOn(selectedDate)
        if dayWorkouts.isEmpty {
            VStack(spacing: 6) {
                Spacer().frame(height: 24)
                Text("NO WORKOUT")
                    .font(.archivo(20, weight: .black))
                    .foregroundStyle(Color.inkFaint)
                Text("No workout logged on this date.")
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 10) {
                ForEach(dayWorkouts) { workout in
                    Button { selectedWorkout = workout } label: {
                        calWorkoutCard(workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func calWorkoutCard(_ workout: Workout) -> some View {
        let sets = workout.exerciseLogs.flatMap(\.sets).count
        let mins = Int(workout.duration) / 60
        let secs = Int(workout.duration) % 60
        let dateLabel = calDateLabel(workout.date)
        return VStack(alignment: .leading, spacing: 6) {
            Text(dateLabel)
                .font(.spaceMono(8))
                .tracking(1.3)
                .foregroundStyle(Color.inkMuted)
            Text((workout.template?.name ?? "Workout").uppercased())
                .font(.archivo(20, weight: .black))
                .foregroundStyle(Color.inkPrimary)
            HStack(spacing: 8) {
                Text("\(sets) SETS")
                    .font(.spaceMono(9))
                    .foregroundStyle(Color.inkMuted)
                Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkFaint)
                Text(String(format: "%d:%02d", mins, secs))
                    .font(.spaceMono(9))
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.dsHairLine, lineWidth: 1))
    }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        if workouts.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                statsRow
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                Text("RECENT")
                    .font(.spaceMono(9))
                    .tracking(1.3)
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                LazyVStack(spacing: 0) {
                    ForEach(workouts) { workout in
                        Button { selectedWorkout = workout } label: {
                            listRow(workout)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { workoutToDelete = workout } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Color.signalDown)
                        }
                        Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    }
                }
            }
        }
    }

    private var statsRow: some View {
        let cal = Calendar.current
        let month = cal.component(.month, from: Date())
        let year  = cal.component(.year,  from: Date())
        let thisMonth = workouts.filter {
            cal.component(.month, from: $0.date) == month && cal.component(.year, from: $0.date) == year
        }.count
        let streak = StreakCalculator.currentStreak(from: workouts.map(\.date))
        return HStack(spacing: 0) {
            statCell(value: "\(workouts.count)", label: "WORKOUTS")
            Rectangle().fill(Color.dsHairLine).frame(width: 1)
            statCell(value: "\(thisMonth)", label: "THIS MONTH")
            Rectangle().fill(Color.dsHairLine).frame(width: 1)
            statCell(value: "\(streak)D", label: "STREAK")
        }
        .frame(height: 60)
        .background(Color.surf)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.spaceMono(8))
                .tracking(1.2)
                .foregroundStyle(Color.inkMuted)
            Text(value)
                .font(.archivo(22, weight: .black))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func listRow(_ workout: Workout) -> some View {
        let sets = workout.exerciseLogs.flatMap(\.sets).count
        let mins = Int(workout.duration) / 60

        return HStack(spacing: 12) {
            // Date column
            VStack(spacing: 0) {
                Text(shortDay(workout.date))
                    .font(.spaceMono(8))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkMuted)
                Text(dayNum(workout.date))
                    .font(.archivo(20, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text(shortMonth(workout.date))
                    .font(.spaceMono(7))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text((workout.template?.name ?? "Workout").uppercased())
                    .font(.archivo(16, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text("\(sets) SETS · \(mins)M")
                    .font(.spaceMono(9))
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.canvasBg)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("NO WORKOUTS YET")
                .font(.archivo(28, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.inkFaint)
            Text("Complete your first workout to see it here.")
                .font(.archivo(13))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Calendar helpers

    private struct CalDay {
        let date: Date?
        let day: Int?
    }

    private func calendarDays() -> [CalDay] {
        let cal = Calendar.current
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: calendarMonth)),
              let range = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }

        // Monday-based offset (Mon=0 … Sun=6)
        let weekday = cal.component(.weekday, from: startOfMonth)
        let offset = (weekday + 5) % 7

        var days: [CalDay] = Array(repeating: CalDay(date: nil, day: nil), count: offset)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: startOfMonth) {
                days.append(CalDay(date: date, day: d))
            }
        }
        // Always pad to 42 (6 rows) for fixed height
        while days.count < 42 { days.append(CalDay(date: nil, day: nil)) }
        return days
    }

    private func shiftMonth(_ delta: Int) {
        let cal = Calendar.current
        if let newMonth = cal.date(byAdding: .month, value: delta, to: calendarMonth) {
            calendarMonth = newMonth
        }
    }

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
                .background(Color.pumpAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text((workout.template?.name ?? "Workout").uppercased())
                        .font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                    let sets = workout.exerciseLogs.flatMap(\.sets).count
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
