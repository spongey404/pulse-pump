import SwiftUI

enum ShareCardType {
    case postWorkout(WorkoutCompletionData)
    case weeklyRecap(weekWorkouts: Int, weekSets: Int, streak: Int)
    case monthlyRecap(monthWorkouts: Int, prs: Int, consistency: Double)
    case milestone(description: String)
}

struct ShareCardView: View {
    let cardType: ShareCardType

    var body: some View {
        VStack(spacing: 16) {
            cardContent

            // Subtle Pulse branding
            HStack {
                Spacer()
                Text("Pump by Pulse")
                    .font(.mono(9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch cardType {
        case .postWorkout(let data):
            postWorkoutCard(data: data)
        case .weeklyRecap(let workouts, let sets, let streak):
            weeklyRecapCard(workouts: workouts, sets: sets, streak: streak)
        case .monthlyRecap(let workouts, let prs, let consistency):
            monthlyRecapCard(workouts: workouts, prs: prs, consistency: consistency)
        case .milestone(let description):
            milestoneCard(description: description)
        }
    }

    private func postWorkoutCard(data: WorkoutCompletionData) -> some View {
        VStack(spacing: 12) {
            Text("Workout Complete")
                .font(.mono(16, weight: .medium))
            HStack(spacing: 24) {
                VStack {
                    Text(data.formattedDuration)
                        .font(.display(20))
                    Text("Duration")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(data.exerciseCount)")
                        .font(.display(20))
                    Text("Exercises")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(data.totalSets)")
                        .font(.display(20))
                    Text("Sets")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
            }
            if data.prCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "medal.fill")
                        .foregroundStyle(.yellow)
                    Text("\(data.prCount) PR\(data.prCount == 1 ? "" : "s")")
                        .font(.mono(14, weight: .medium))
                }
            }
        }
    }

    private func weeklyRecapCard(workouts: Int, sets: Int, streak: Int) -> some View {
        VStack(spacing: 12) {
            Text("Weekly Recap")
                .font(.mono(16, weight: .medium))
            HStack(spacing: 24) {
                VStack {
                    Text("\(workouts)")
                        .font(.display(20))
                    Text("Workouts")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(sets)")
                        .font(.display(20))
                    Text("Sets")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(streak)")
                        .font(.display(20))
                    Text("Day Streak")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func monthlyRecapCard(workouts: Int, prs: Int, consistency: Double) -> some View {
        VStack(spacing: 12) {
            Text("Monthly Recap")
                .font(.mono(16, weight: .medium))
            HStack(spacing: 24) {
                VStack {
                    Text("\(workouts)")
                        .font(.display(20))
                    Text("Workouts")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(prs)")
                        .font(.display(20))
                    Text("PRs")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f%%", consistency * 100))
                        .font(.display(20))
                    Text("Consistency")
                        .font(.mono(11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func milestoneCard(description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy")
                .font(.display(28))
                .foregroundStyle(Color.accentInk)
            Text("New Milestone")
                .font(.mono(16, weight: .medium))
            Text(description)
                .font(.mono(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

@MainActor
func renderShareCard(_ view: some View, size: CGSize) -> UIImage? {
    let renderer = ImageRenderer(content: view.frame(width: size.width))
    renderer.scale = 3.0
    return renderer.uiImage
}
