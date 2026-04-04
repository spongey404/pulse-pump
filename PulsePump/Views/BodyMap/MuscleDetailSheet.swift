import SwiftUI
import SwiftData

struct MuscleDetailSheet: View {
    let muscle: MuscleGroup
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    private var exercisesForMuscle: (done: [Exercise], notDone: [Exercise]) {
        let matching = allExercises.filter {
            ($0.isApproved || $0.isCustom) &&
            ($0.primaryMuscleGroups.contains(muscle) || $0.secondaryMuscleGroups.contains(muscle))
        }
        let done = matching.filter { !$0.logs.isEmpty }
        let notDone = matching.filter { $0.logs.isEmpty }
        return (done, notDone)
    }

    var body: some View {
        NavigationStack {
            List {
                if !exercisesForMuscle.done.isEmpty {
                    Section("Performed") {
                        ForEach(exercisesForMuscle.done) { exercise in
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                Text("\(exercise.logs.count) sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !exercisesForMuscle.notDone.isEmpty {
                    Section("Not Yet Tried") {
                        ForEach(exercisesForMuscle.notDone) { exercise in
                            Text(exercise.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(muscle.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
