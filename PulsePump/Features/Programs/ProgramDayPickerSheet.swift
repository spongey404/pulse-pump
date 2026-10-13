import SwiftUI
import SwiftData
import FirebaseAuth

struct ProgramDayPickerSheet: View {
    let group: ProgramGroup
    let onSelectTemplate: (WorkoutTemplate) -> Void
    let onStartTemplate: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("‹")
                        .font(.archivo(26, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(PressScaleButtonStyle())
                Text(group.name.uppercased())
                    .font(.archivo(20, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(group.templates.enumerated()), id: \.element.id) { idx, template in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name.uppercased())
                                        .font(.archivo(16, weight: .bold))
                                        .foregroundStyle(Color.inkPrimary)
                                    Text("\(template.templateExercises.count) EXERCISES · \(template.templateExercises.reduce(0) { $0 + $1.targetSets }) SETS")
                                        .font(.spaceMono(9))
                                        .foregroundStyle(Color.inkMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    onStartTemplate(template)
                                } label: {
                                    Text("START")
                                        .font(.spaceMono(9, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.accentInk)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.accentInk.opacity(0.5))
                                        )
                                }
                                .buttonStyle(PressScaleButtonStyle())

                                Button {
                                    onSelectTemplate(template)
                                } label: {
                                    Text("EDIT")
                                        .font(.spaceMono(9, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.inkMuted)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.dsHairLine.opacity(1.5))
                                        )
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preset Template Picker
