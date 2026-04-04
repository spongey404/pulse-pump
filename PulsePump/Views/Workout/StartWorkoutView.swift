import SwiftUI
import SwiftData

struct StartWorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { $0.isDraft }, sort: \Workout.updatedAt, order: .reverse)
    private var drafts: [Workout]

    private var user: User? { users.first }

    var body: some View {
        VStack(spacing: 16) {
            // Smart prediction
            if let user, let prediction = viewModel.predictNextWorkout(user: user) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Today's Workout")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HintButton(hint: .startWorkout)
                    }

                    Button {
                        viewModel.startWorkout(modelContext: modelContext, user: user)
                    } label: {
                        VStack(spacing: 6) {
                            Text("Start \(prediction)")
                                .font(.title3.weight(.semibold))
                            Image(systemName: "play.fill")
                                .font(.title2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.pumpPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            } else if let user {
                Button {
                    viewModel.startWorkout(modelContext: modelContext, user: user)
                } label: {
                    VStack(spacing: 6) {
                        Text("Start Workout")
                            .font(.title3.weight(.semibold))
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color.pumpPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            // Draft workouts
            if !drafts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drafts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(drafts) { draft in
                        Button {
                            if let user {
                                draft.user = user
                                viewModel.resumeDraft(workout: draft, modelContext: modelContext)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Draft Workout")
                                        .font(.subheadline.weight(.medium))
                                    Text(draft.date, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(Color.pumpPrimary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
