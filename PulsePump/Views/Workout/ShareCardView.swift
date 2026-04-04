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
                    .font(.caption2)
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
                .font(.headline)
            HStack(spacing: 24) {
                VStack {
                    Text(data.formattedDuration)
                        .font(.title3.weight(.bold))
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(data.exerciseCount)")
                        .font(.title3.weight(.bold))
                    Text("Exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(data.totalSets)")
                        .font(.title3.weight(.bold))
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if data.prCount > 0 {
                Text("\(data.prCount) PR\(data.prCount == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pumpPrimary)
            }
        }
    }

    private func weeklyRecapCard(workouts: Int, sets: Int, streak: Int) -> some View {
        VStack(spacing: 12) {
            Text("Weekly Recap")
                .font(.headline)
            HStack(spacing: 24) {
                VStack {
                    Text("\(workouts)")
                        .font(.title3.weight(.bold))
                    Text("Workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(sets)")
                        .font(.title3.weight(.bold))
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(streak)")
                        .font(.title3.weight(.bold))
                    Text("Day Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func monthlyRecapCard(workouts: Int, prs: Int, consistency: Double) -> some View {
        VStack(spacing: 12) {
            Text("Monthly Recap")
                .font(.headline)
            HStack(spacing: 24) {
                VStack {
                    Text("\(workouts)")
                        .font(.title3.weight(.bold))
                    Text("Workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(prs)")
                        .font(.title3.weight(.bold))
                    Text("PRs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f%%", consistency * 100))
                        .font(.title3.weight(.bold))
                    Text("Consistency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func milestoneCard(description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy")
                .font(.title)
                .foregroundStyle(Color.pumpPrimary)
            Text("New Milestone")
                .font(.headline)
            Text(description)
                .font(.subheadline)
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
