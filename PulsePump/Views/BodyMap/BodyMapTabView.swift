import SwiftUI
import SwiftData

enum BodyMapMode: String, CaseIterable {
    case bodyMap = "Body Map"
    case analytics = "Analytics"
}

enum HeatmapMode: String, CaseIterable {
    case volume = "Volume"
    case recency = "Recency"
}

enum HeatmapColorScheme: String, CaseIterable, Identifiable {
    case cool      // blue → green → red
    case warm      // yellow → orange → red
    case mono      // light gray → primary color
    case spectrum  // blue → cyan → green → yellow → red

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cool: "Cool"
        case .warm: "Warm"
        case .mono: "Mono"
        case .spectrum: "Spectrum"
        }
    }

    func color(for intensity: Double) -> Color {
        guard intensity > 0 else { return .clear }
        switch self {
        case .cool:
            if intensity < 0.33 { return .blue }
            if intensity < 0.66 { return .green }
            return Color.pumpPrimary
        case .warm:
            if intensity < 0.33 { return .yellow }
            if intensity < 0.66 { return .orange }
            return .red
        case .mono:
            return Color.pumpPrimary.opacity(0.3 + intensity * 0.7)
        case .spectrum:
            if intensity < 0.2 { return .blue }
            if intensity < 0.4 { return .cyan }
            if intensity < 0.6 { return .green }
            if intensity < 0.8 { return .yellow }
            return .red
        }
    }
}

struct BodyMapTabView: View {
    @State private var mode: BodyMapMode = .bodyMap
    @State private var heatmapMode: HeatmapMode = .volume
    @State private var selectedMuscle: MuscleGroup?
    @State private var colorScheme: HeatmapColorScheme = {
        HeatmapColorScheme(rawValue: UserDefaults.standard.string(forKey: "heatmapColorScheme") ?? "") ?? .cool
    }()
    @Query private var exerciseLogs: [ExerciseLog]
    @State private var pulsePlusService = PulsePlusService()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(BodyMapMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch mode {
            case .bodyMap:
                bodyMapContent
            case .analytics:
                AnalyticsView()
            }
        }
        .navigationTitle("Body Map")
        .sheet(item: $selectedMuscle) { muscle in
            MuscleDetailSheet(muscle: muscle)
        }
        .task {
            await pulsePlusService.refreshSubscriptionStatus()
        }
    }

    private var bodyMapContent: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Heatmap", selection: $heatmapMode) {
                    ForEach(HeatmapMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Menu {
                    ForEach(HeatmapColorScheme.allCases) { scheme in
                        Button {
                            colorScheme = scheme
                            UserDefaults.standard.set(scheme.rawValue, forKey: "heatmapColorScheme")
                        } label: {
                            HStack {
                                Text(scheme.displayName)
                                if scheme == colorScheme {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(Color.pumpPrimary)
                }
            }
            .padding(.horizontal)

            ScrollView {
                BodyModelView(
                    heatmapMode: heatmapMode,
                    exerciseLogs: exerciseLogs,
                    colorScheme: colorScheme,
                    onMuscleTap: { muscle in
                        selectedMuscle = muscle
                    }
                )
                .padding()

                HeatmapLegend(mode: heatmapMode, colorScheme: colorScheme)
                    .padding(.horizontal)

                // Neglected muscle nudges (Pulse+ only)
                if pulsePlusService.isSubscribed {
                    let neglected = neglectedMuscles
                    if !neglected.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Neglected Muscles")
                                .font(.subheadline.weight(.semibold))

                            ForEach(neglected, id: \.self) { muscle in
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    Text("\(muscle.displayName) — not trained in 7+ days")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Balance analysis
                    MuscleBalanceView(exerciseLogs: exerciseLogs)
                        .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
        }
    }

    private var neglectedMuscles: [MuscleGroup] {
        let majorGroups: [MuscleGroup] = [.chest, .lats, .quads, .hamstrings, .glutes, .frontDelts, .biceps, .triceps]
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        return majorGroups.filter { muscle in
            !exerciseLogs.contains { log in
                guard let exercise = log.exercise,
                      let workout = log.workout,
                      !workout.isDraft,
                      workout.date >= weekAgo else { return false }
                return exercise.primaryMuscleGroups.contains(muscle)
            }
        }
    }
}

// MARK: - Muscle Balance Analysis (Pulse+)

struct MuscleBalanceView: View {
    let exerciseLogs: [ExerciseLog]

    private var pushVolume: Int {
        weeklyVolume(for: [.chest, .frontDelts, .sideDelts, .triceps])
    }

    private var pullVolume: Int {
        weeklyVolume(for: [.lats, .upperBack, .rearDelts, .biceps, .traps])
    }

    private var quadVolume: Int {
        weeklyVolume(for: [.quads])
    }

    private var hamVolume: Int {
        weeklyVolume(for: [.hamstrings, .glutes])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Balance")
                .font(.subheadline.weight(.semibold))

            BalanceBar(label: "Push / Pull", left: pushVolume, right: pullVolume, leftLabel: "Push", rightLabel: "Pull")
            BalanceBar(label: "Quads / Posterior", left: quadVolume, right: hamVolume, leftLabel: "Quads", rightLabel: "Hams/Glutes")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func weeklyVolume(for muscles: [MuscleGroup]) -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var total = 0
        for log in exerciseLogs {
            guard let exercise = log.exercise,
                  let workout = log.workout,
                  !workout.isDraft,
                  workout.date >= weekAgo else { continue }
            if !Set(exercise.primaryMuscleGroups).intersection(muscles).isEmpty {
                total += log.sets.count
            }
        }
        return total
    }
}

struct BalanceBar: View {
    let label: String
    let left: Int
    let right: Int
    let leftLabel: String
    let rightLabel: String

    private var total: Int { max(left + right, 1) }
    private var leftRatio: Double { Double(left) / Double(total) }

    private var isImbalanced: Bool {
        guard total > 0 else { return false }
        let ratio = left > right ? Double(left) / max(Double(right), 1) : Double(right) / max(Double(left), 1)
        return ratio > 1.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isImbalanced {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: max(geo.size.width * leftRatio, 4))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green)
                }
            }
            .frame(height: 8)
            HStack {
                Text("\(leftLabel): \(left) sets")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(rightLabel): \(right) sets")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
