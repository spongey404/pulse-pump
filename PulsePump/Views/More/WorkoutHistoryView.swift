import SwiftUI
import SwiftData

enum HistoryViewMode: String, CaseIterable {
    case list = "List"
    case calendar = "Calendar"
}

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var viewMode: HistoryViewMode = .list
    @State private var selectedDate = Date()
    @State private var workoutToDelete: Workout?

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $viewMode) {
                ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch viewMode {
            case .list:
                listView
            case .calendar:
                calendarView
            }
        }
        .navigationTitle("History")
        .confirmationDialog("Delete Workout?", isPresented: .init(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    modelContext.delete(workout)
                    workoutToDelete = nil
                }
            }
        } message: {
            Text("This workout will be permanently deleted.")
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "dumbbell",
                    description: Text("Completed workouts will appear here.")
                )
            } else {
                ForEach(workouts) { workout in
                    NavigationLink(value: workout) {
                        WorkoutHistoryRow(workout: workout)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            workoutToDelete = workout
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        VStack(spacing: 0) {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.pumpPrimary)
                .padding(.horizontal)

            let selectedWorkouts = workoutsOn(date: selectedDate)
            if selectedWorkouts.isEmpty {
                ContentUnavailableView(
                    "No Workout",
                    systemImage: "calendar",
                    description: Text("No workout on this date.")
                )
            } else {
                List(selectedWorkouts) { workout in
                    NavigationLink(value: workout) {
                        WorkoutHistoryRow(workout: workout)
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Workout.self) { workout in
                    WorkoutDetailView(workout: workout)
                }
            }
        }
    }

    private func workoutsOn(date: Date) -> [Workout] {
        let calendar = Calendar.current
        return workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

struct WorkoutHistoryRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.template?.name ?? "Workout")
                    .font(.body.weight(.medium))
                Spacer()
                Text(workout.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label("\(workout.exerciseLogs.count) exercises", systemImage: "figure.strengthtraining.traditional")
                Label(formatDuration(workout.duration), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        return "\(m) min"
    }
}
