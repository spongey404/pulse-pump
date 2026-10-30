import SwiftUI
import SwiftData
import FirebaseAuth

struct WorkoutDayPickerSheet: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.surf)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())

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
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.oreAccent.opacity(0.10))
                                            .frame(width: 40, height: 40)
                                        Text(String(template.name.prefix(1)).uppercased())
                                            .font(.archivo(16, weight: .black))
                                            .foregroundStyle(Color.accentInk)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(template.name.uppercased())
                                            .font(.archivo(16, weight: .semibold))
                                            .foregroundStyle(Color.inkPrimary)
                                        Text("\(template.templateExercises.count) EXERCISES")
                                            .font(.spaceMono(9))
                                            .tracking(0.8)
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.inkFaint)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.98))

                            if idx < templates.count - 1 {
                                Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.leading, 70)
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
