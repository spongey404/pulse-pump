import SwiftUI
import SwiftData

struct BodyModelView: View {
    let heatmapMode: HeatmapMode
    let exerciseLogs: [ExerciseLog]
    let onMuscleTap: (MuscleGroup) -> Void

    private let frontMuscles: [(MuscleGroup, CGPoint, CGSize)] = [
        (.chest,      CGPoint(x: 0.5, y: 0.22), CGSize(width: 0.28, height: 0.08)),
        (.frontDelts, CGPoint(x: 0.32, y: 0.18), CGSize(width: 0.08, height: 0.06)),
        (.sideDelts,  CGPoint(x: 0.68, y: 0.18), CGSize(width: 0.08, height: 0.06)),
        (.biceps,     CGPoint(x: 0.27, y: 0.3), CGSize(width: 0.07, height: 0.09)),
        (.forearms,   CGPoint(x: 0.24, y: 0.4), CGSize(width: 0.06, height: 0.09)),
        (.abs,        CGPoint(x: 0.5, y: 0.35), CGSize(width: 0.14, height: 0.12)),
        (.obliques,   CGPoint(x: 0.5, y: 0.38), CGSize(width: 0.22, height: 0.06)),
        (.quads,      CGPoint(x: 0.42, y: 0.55), CGSize(width: 0.1, height: 0.15)),
        (.adductors,  CGPoint(x: 0.5, y: 0.52), CGSize(width: 0.06, height: 0.1)),
    ]

    private let backMuscles: [(MuscleGroup, CGPoint, CGSize)] = [
        (.traps,      CGPoint(x: 0.5, y: 0.14), CGSize(width: 0.16, height: 0.06)),
        (.rearDelts,  CGPoint(x: 0.32, y: 0.18), CGSize(width: 0.08, height: 0.06)),
        (.upperBack,  CGPoint(x: 0.5, y: 0.2), CGSize(width: 0.22, height: 0.06)),
        (.lats,       CGPoint(x: 0.5, y: 0.28), CGSize(width: 0.26, height: 0.1)),
        (.triceps,    CGPoint(x: 0.73, y: 0.3), CGSize(width: 0.07, height: 0.09)),
        (.lowerBack,  CGPoint(x: 0.5, y: 0.38), CGSize(width: 0.14, height: 0.06)),
        (.glutes,     CGPoint(x: 0.5, y: 0.46), CGSize(width: 0.2, height: 0.08)),
        (.hamstrings, CGPoint(x: 0.42, y: 0.58), CGSize(width: 0.1, height: 0.14)),
        (.calves,     CGPoint(x: 0.42, y: 0.74), CGSize(width: 0.08, height: 0.1)),
    ]

    var body: some View {
        HStack(spacing: 24) {
            muscleMapColumn(title: "Front", muscles: frontMuscles)
            muscleMapColumn(title: "Back", muscles: backMuscles)
        }
    }

    private func muscleMapColumn(title: String, muscles: [(MuscleGroup, CGPoint, CGSize)]) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack {
                    // Body silhouette outline
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.tertiarySystemBackground))
                        .overlay(
                            Image(systemName: "figure.stand")
                                .font(.system(size: geo.size.height * 0.7))
                                .foregroundStyle(Color(.systemGray4))
                        )

                    // Muscle overlays
                    ForEach(muscles, id: \.0) { muscle, position, size in
                        let intensity = muscleIntensity(for: muscle)
                        Button {
                            onMuscleTap(muscle)
                        } label: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(heatmapColor(intensity: intensity).opacity(intensity > 0 ? 0.3 + intensity * 0.5 : 0))
                                .overlay(
                                    Text(muscle.displayName)
                                        .font(.system(size: 7))
                                        .foregroundStyle(intensity > 0 ? .primary : .secondary)
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(
                            width: geo.size.width * size.width,
                            height: geo.size.height * size.height
                        )
                        .position(
                            x: geo.size.width * position.x,
                            y: geo.size.height * position.y
                        )
                    }
                }
            }
            .aspectRatio(0.45, contentMode: .fit)
        }
    }

    private func muscleIntensity(for muscle: MuscleGroup) -> Double {
        switch heatmapMode {
        case .volume:
            return volumeIntensity(for: muscle)
        case .recency:
            return recencyIntensity(for: muscle)
        }
    }

    private func volumeIntensity(for muscle: MuscleGroup) -> Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var totalSets = 0

        for log in exerciseLogs {
            guard let exercise = log.exercise,
                  let workout = log.workout,
                  workout.date >= weekAgo,
                  !workout.isDraft else { continue }

            if exercise.primaryMuscleGroups.contains(muscle) {
                totalSets += log.sets.count
            } else if exercise.secondaryMuscleGroups.contains(muscle) {
                totalSets += log.sets.count / 2
            }
        }

        // Normalize: 20+ sets = max intensity
        return min(Double(totalSets) / 20.0, 1.0)
    }

    private func recencyIntensity(for muscle: MuscleGroup) -> Double {
        var latestDate: Date?

        for log in exerciseLogs {
            guard let exercise = log.exercise,
                  let workout = log.workout,
                  !workout.isDraft else { continue }

            if exercise.primaryMuscleGroups.contains(muscle) || exercise.secondaryMuscleGroups.contains(muscle) {
                if latestDate == nil || workout.date > latestDate! {
                    latestDate = workout.date
                }
            }
        }

        guard let date = latestDate else { return 0 }
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 7
        // Today = 1.0, 7+ days ago = 0
        return max(0, 1.0 - Double(daysSince) / 7.0)
    }

    private func heatmapColor(intensity: Double) -> Color {
        if intensity <= 0 { return .clear }
        if intensity < 0.33 { return .blue }
        if intensity < 0.66 { return .green }
        return Color.pumpPrimary
    }
}

// MARK: - Legend

struct HeatmapLegend: View {
    let mode: HeatmapMode

    var body: some View {
        HStack(spacing: 12) {
            Text(mode == .volume ? "Low" : "7+ days")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let intensity = Double(i) / 4.0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(legendColor(intensity: intensity))
                        .frame(width: 20, height: 8)
                }
            }

            Text(mode == .volume ? "High" : "Today")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func legendColor(intensity: Double) -> Color {
        if intensity < 0.25 { return .blue.opacity(0.3) }
        if intensity < 0.5 { return .blue }
        if intensity < 0.75 { return .green }
        return Color.pumpPrimary
    }
}
