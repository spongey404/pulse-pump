import SwiftUI
import SwiftData
import FirebaseAuth

struct PresetTemplatePicker: View {
    let onSelectPresets: ([WorkoutTemplate]) -> Void
    let onBlank: () -> Void
    @Environment(\.dismiss) private var dismiss

    private struct PresetGroup {
        let name: String
        let desc: String
        let days: Int
        let templates: [WorkoutTemplate]
    }

    private let presets: [PresetGroup] = [
        PresetGroup(name: "Push Pull Legs",
                    desc: "6-day split. Push (chest/shoulders/triceps), Pull (back/biceps), Legs. High frequency.",
                    days: 6, templates: TemplateSeedService.pplTemplates),
        PresetGroup(name: "Upper Lower",
                    desc: "4-day split. Two upper and two lower sessions per week. Balanced frequency.",
                    days: 4, templates: TemplateSeedService.upperLowerTemplates),
        PresetGroup(name: "Full Body",
                    desc: "3-day split. Hit every major muscle group each session. Great for beginners.",
                    days: 3, templates: TemplateSeedService.fullBodyTemplates),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.inkFaint)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CHOOSE A TEMPLATE")
                        .font(.archivo(22, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                    Text("All exercises are editable after selecting")
                        .font(.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("×")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    Button {
                        dismiss()
                        onBlank()
                    } label: {
                        presetRow(name: "Blank Program",
                                  desc: "Start from scratch — add your own exercises and structure",
                                  days: nil)
                    }
                    .buttonStyle(.plain)

                    ForEach(presets, id: \.name) { p in
                        Rectangle().fill(Color.dsHairLine).frame(height: 1)
                        Button {
                            dismiss()
                            onSelectPresets(p.templates)
                        } label: {
                            presetRow(name: p.name, desc: p.desc, days: p.days)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color.canvasBg)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func presetRow(name: String, desc: String, days: Int?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(days == nil ? Color.surf2 : Color.oreAccent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(days == nil ? Color.dsHairLine : Color.accentInk.opacity(0.2), lineWidth: 1)
                    )
                if let d = days {
                    Text("\(d)D")
                        .font(.archivo(14, weight: .semibold))
                        .foregroundStyle(Color.accentInk)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.archivo(14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(desc)
                    .font(.archivo(12))
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.inkFaint)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Workout Day Picker Sheet
