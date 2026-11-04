import SwiftUI
import SwiftData
import FirebaseAuth

struct WorkoutDayPickerSheet: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    /// "5 EXERCISES · AVG 52 MIN" (the average only when there is history), as on the Programs list.
    static func meta(_ t: WorkoutTemplate) -> String {
        let n = t.templateExercises.count
        var parts = ["\(n) EXERCISE\(n == 1 ? "" : "S")"]
        if let m = ProgramPlan.averageMinutes(durations: t.liveWorkouts.map { ($0.date, $0.duration) }, editedAt: .distantPast) { parts.append("AVG \(m) MIN") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.surf)
                        .frame(width: 34, height: 34)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Close").accessibilityIdentifier(AX.home.pickerClose)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WHAT'S TODAY?")
                        .font(.archivo(22, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                    Text("PICK YOUR WORKOUT FOR TODAY")
                        .font(.spaceMono(9))
                        .tracking(1.2)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            if templates.isEmpty {
                Spacer()
                Text("NO PROGRAMS YET")
                    .font(.archivo(20, weight: .black))
                    .foregroundStyle(Color.inkFaint)
                Text("Create a program first")
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(templates.enumerated()), id: \.element.id) { idx, template in
                            Button {
                                onSelect(template)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name.uppercased())
                                            .font(.archivo(18, weight: .bold))
                                            .foregroundStyle(Color.inkPrimary)
                                            .lineLimit(1)
                                        Text(Self.meta(template))
                                            .font(.spaceMono(9))
                                            .tracking(1.5)
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                    Spacer(minLength: 0)
                                    Text("›").font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkMuted)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.98))
                            .accessibilityIdentifier(AX.home.pickerRow(idx))

                            if idx < templates.count - 1 {
                                Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.leading, 16)
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}

// MARK: - Profile Menu Sheet
