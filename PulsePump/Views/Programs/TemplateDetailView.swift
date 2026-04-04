import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let onStartWorkout: (WorkoutTemplate) -> Void
    @State private var showEditTemplate = false
    @State private var showShareSheet = false

    private var shareData: String {
        let exercises = template.templateExercises.sorted(by: { $0.order < $1.order })
        let exerciseJSON = exercises.map { ex -> [String: Any] in
            var dict: [String: Any] = [
                "name": ex.exerciseName,
                "sets": ex.targetSets,
                "reps": ex.targetReps
            ]
            if let rir = ex.targetRIR { dict["rir"] = rir }
            return dict
        }
        let payload: [String: Any] = ["name": template.name, "exercises": exerciseJSON]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let encoded = data.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return "pulsepump://template"
        }
        return "pulsepump://template?data=\(encoded)"
    }

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

                Button {
                    showShareSheet = true
                } label: {
                    Label("Share Template", systemImage: "square.and.arrow.up")
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
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: shareData) {
                ShareSheet(items: [url])
            }
        }
    }
}
