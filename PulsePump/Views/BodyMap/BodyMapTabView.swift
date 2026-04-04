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

struct BodyMapTabView: View {
    @State private var mode: BodyMapMode = .bodyMap
    @State private var heatmapMode: HeatmapMode = .volume
    @State private var selectedMuscle: MuscleGroup?
    @Query private var exerciseLogs: [ExerciseLog]

    var body: some View {
        VStack(spacing: 0) {
            // TODO: UX test — swipe, toggle, or segmented control (spec open question #4)
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
    }

    private var bodyMapContent: some View {
        VStack(spacing: 12) {
            Picker("Heatmap", selection: $heatmapMode) {
                ForEach(HeatmapMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ScrollView {
                BodyModelView(
                    heatmapMode: heatmapMode,
                    exerciseLogs: exerciseLogs,
                    onMuscleTap: { muscle in
                        selectedMuscle = muscle
                    }
                )
                .padding()

                HeatmapLegend(mode: heatmapMode)
                    .padding(.horizontal)
            }
        }
    }
}
