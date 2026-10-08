import SwiftUI
import SwiftData

struct MuscleDetailSheet: View {
    let muscle: MuscleGroup
    var subRegion: MuscleSubRegion?
    @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name) private var allExercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    @State private var pulsePlusService = PulsePlusService()

    private var exercisesForMuscle: (done: [Exercise], notDone: [Exercise]) {
        let matching = allExercises.filter {
            ($0.isApproved || $0.isCustom) &&
            ($0.primaryMuscleGroups.contains(muscle) || $0.secondaryMuscleGroups.contains(muscle))
        }
        let done = matching.filter { !$0.finalLogs.isEmpty }
        let notDone = matching.filter { $0.finalLogs.isEmpty }
        return (done, notDone)
    }

    private var subRegions: [MuscleSubRegion] {
        MuscleSubRegion.subRegions(for: muscle)
    }

    var body: some View {
        NavigationStack {
            List {
                // Sub-region breakdown (Pulse+ only, for muscles with sub-regions)
                if pulsePlusService.isSubscribed && !subRegions.isEmpty {
                    Section("Sub-Regions") {
                        ForEach(subRegions) { sub in
                            let exercises = exercisesTargeting(subRegion: sub)
                            HStack {
                                Circle()
                                    .fill(subRegion == sub ? Color.pumpAccent : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Text(sub.displayName)
                                    .font(subRegion == sub ? .body.weight(.semibold) : .body)
                                Spacer()
                                Text("\(exercises.count) exercises")
                                    .font(.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !exercisesForMuscle.done.isEmpty {
                    Section("Performed") {
                        ForEach(exercisesForMuscle.done) { exercise in
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(exercise.finalLogs.count) sessions")
                                        .font(.mono(11))
                                        .foregroundStyle(.secondary)
                                    if pulsePlusService.isSubscribed {
                                        let subs = exerciseSubRegionLabels(exercise)
                                        if !subs.isEmpty {
                                            Text(subs)
                                                .font(.mono(9))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if !exercisesForMuscle.notDone.isEmpty {
                    Section("Not Yet Tried") {
                        ForEach(exercisesForMuscle.notDone) { exercise in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .foregroundStyle(.secondary)
                                if pulsePlusService.isSubscribed {
                                    let subs = exerciseSubRegionLabels(exercise)
                                    if !subs.isEmpty {
                                        Text(subs)
                                            .font(.mono(9))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(subRegion?.displayName ?? muscle.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await pulsePlusService.refreshSubscriptionStatus()
            }
        }
    }

    private func exercisesTargeting(subRegion: MuscleSubRegion) -> [Exercise] {
        allExercises.filter {
            ($0.isApproved || $0.isCustom) &&
            ($0.primarySubRegions.contains(subRegion) || $0.secondarySubRegions.contains(subRegion))
        }
    }

    private func exerciseSubRegionLabels(_ exercise: Exercise) -> String {
        let relevant = (exercise.primarySubRegions + exercise.secondarySubRegions)
            .filter { $0.parentGroup == muscle }
        return relevant.map(\.displayName).joined(separator: ", ")
    }
}
