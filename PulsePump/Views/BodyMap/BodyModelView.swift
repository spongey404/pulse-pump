import SwiftUI
import SwiftData

enum BodyModelNormalization {
    case relativeToDay    // normalise by the day's own peak muscle — body "pops" on focused sessions
    case relativeToTarget // normalise by weekly target sets — shows progress toward goals
}

struct BodyModelView: View {
    let heatmapMode: HeatmapMode
    let exerciseLogs: [ExerciseLog]
    var colorScheme: HeatmapColorScheme = .cool
    var normalization: BodyModelNormalization = .relativeToTarget
    let onMuscleTap: (MuscleGroup) -> Void

    private static let weeklyTargets: [MuscleGroup: Int] = [
        .chest: 16, .lats: 16, .quads: 20, .hamstrings: 12,
        .glutes: 12, .frontDelts: 8, .sideDelts: 10, .rearDelts: 8,
        .biceps: 10, .triceps: 10, .traps: 8, .upperBack: 12
    ]

    private var allIntensities: [MuscleGroup: Double] {
        switch heatmapMode {
        case .volume:
            let raw = rawSetCounts()
            switch normalization {
            case .relativeToDay:
                let peak = raw.values.max() ?? 1
                return raw.mapValues { peak > 0 ? min(1.0, Double($0) / Double(peak)) : 0 }
            case .relativeToTarget:
                return Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { muscle in
                    let sets = raw[muscle] ?? 0
                    let target = Self.weeklyTargets[muscle] ?? 20
                    return (muscle, min(1.0, Double(sets) / Double(target)))
                })
            }
        case .recency:
            return Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { muscle in
                (muscle, recencyIntensity(for: muscle))
            })
        }
    }

    var body: some View {
        Body3DSceneView(
            muscleIntensities: allIntensities,
            colorScheme: colorScheme,
            onMuscleTap: { muscle in
                if let muscle { onMuscleTap(muscle) }
            }
        )
    }

    // MARK: - Intensity helpers

    private func rawSetCounts() -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]
        for log in exerciseLogs {
            guard let exercise = log.exercise,
                  let workout = log.workout,
                  !workout.isDraft else { continue }
            for muscle in exercise.primaryMuscleGroups {
                counts[muscle, default: 0] += log.sets.count
            }
            for muscle in exercise.secondaryMuscleGroups {
                counts[muscle, default: 0] += log.sets.count / 2
            }
        }
        return counts
    }

    private func recencyIntensity(for muscle: MuscleGroup) -> Double {
        var latestDate: Date?
        for log in exerciseLogs {
            guard let exercise = log.exercise,
                  let workout = log.workout,
                  !workout.isDraft else { continue }
            if exercise.primaryMuscleGroups.contains(muscle) || exercise.secondaryMuscleGroups.contains(muscle) {
                if latestDate == nil || workout.date > latestDate! { latestDate = workout.date }
            }
        }
        guard let date = latestDate else { return 0 }
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 7
        return max(0, 1.0 - Double(daysSince) / 7.0)
    }
}

// MARK: - Legend

struct HeatmapLegend: View {
    let mode: HeatmapMode
    var colorScheme: HeatmapColorScheme = .cool

    var body: some View {
        HStack(spacing: 12) {
            Text(mode == .volume ? "Low" : "7+ days")
                .font(.mono(9))
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let intensity = max(0.1, Double(i) / 4.0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorScheme.color(for: intensity))
                        .frame(width: 20, height: 8)
                }
            }
            Text(mode == .volume ? "High" : "Today")
                .font(.mono(9))
                .foregroundStyle(.secondary)
        }
    }
}
