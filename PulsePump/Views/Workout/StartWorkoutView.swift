import SwiftUI
import SwiftData

struct StartWorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { $0.isDraft }, sort: \Workout.updatedAt, order: .reverse)
    private var drafts: [Workout]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @State private var showAlternativePicker = false

    private var user: User? { users.first }

    var body: some View {
        VStack(spacing: 16) {
            // Smart prediction
            if let user, let prediction = viewModel.predictNextWorkout(user: user, modelContext: modelContext) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Today's Workout")
                            .font(.mono(11))
                            .foregroundStyle(.secondary)
                        HintButton(hint: .startWorkout)
                    }

                    Button {
                        viewModel.startWorkout(modelContext: modelContext, user: user)
                        showAlternativePicker = false
                    } label: {
                        VStack(spacing: 6) {
                            Text("Start \(prediction)")
                                .font(.display(20))
                            Image(systemName: "play.fill")
                                .font(.display(22))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.pumpAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAlternativePicker.toggle()
                        }
                    } label: {
                        Text(showAlternativePicker ? "Nevermind" : "Something else?")
                            .font(.mono(12))
                            .foregroundStyle(.secondary)
                    }

                    if showAlternativePicker {
                        AlternativeWorkoutPicker(
                            templates: templates,
                            onSelect: { template in
                                viewModel.startWorkout(modelContext: modelContext, user: user, template: template)
                                showAlternativePicker = false
                            },
                            onBlank: {
                                viewModel.startWorkout(modelContext: modelContext, user: user)
                                showAlternativePicker = false
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } else if let user {
                Button {
                    viewModel.startWorkout(modelContext: modelContext, user: user)
                } label: {
                    VStack(spacing: 6) {
                        Text("Start Workout")
                            .font(.display(20))
                        Image(systemName: "play.fill")
                            .font(.display(22))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color.pumpAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            // Draft workouts
            if !drafts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drafts")
                        .font(.mono(14, weight: .medium))
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
                                        .font(.mono(14, weight: .medium))
                                    Text(draft.date, style: .relative)
                                        .font(.mono(11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(Color.pumpAccent)
                            }
                            .padding()
                            .background(Color.surf)
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

// MARK: - Alternative Workout Picker

struct AlternativeWorkoutPicker: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void
    let onBlank: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                onBlank()
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.pumpAccent)
                    Text("Blank workout")
                        .font(.mono(14))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            ForEach(templates.prefix(6)) { template in
                Button {
                    onSelect(template)
                } label: {
                    HStack {
                        Text(template.name)
                            .font(.mono(14))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(template.templateExercises.count) exercises")
                            .font(.mono(11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
