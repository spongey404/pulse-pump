import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let onStartWorkout: (WorkoutTemplate) -> Void
    @State private var showEditTemplate = false

    var body: some View {
        List {
            Section {
                Button {
                    onStartWorkout(template)
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.pumpPrimary)
                }
            }

            Section("Exercises") {
                ForEach(template.templateExercises.sorted(by: { $0.order < $1.order })) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.exerciseName)
                                .font(.body)
                            HStack(spacing: 8) {
                                Text("\(exercise.targetSets) sets")
                                Text("\(exercise.targetReps) reps")
                                if let rir = exercise.targetRIR {
                                    Text("\(rir) RIR")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            Section {
                Text("\(template.workouts.count) workouts logged")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditTemplate = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showEditTemplate) {
            EditTemplateView(template: template)
        }
    }
}
