import SwiftUI
import SwiftData
import FirebaseAuth

struct ProgramGroupRowView: View {
    let group: ProgramGroup

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name.uppercased())
                        .font(.archivo(18, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Text("\(group.daysPerWeek) DAYS/WK · \(group.totalExercises) EXERCISES · \(group.lastUsedText)")
                        .font(.spaceMono(9))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !group.splitDays.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(group.splitDays.enumerated()), id: \.offset) { _, label in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.oreAccent.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.accentInk.opacity(0.33), lineWidth: 1)
                                )
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Text(label)
                                        .font(.spaceMono(7, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(Color.accentInk)
                                )
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.mono(12))
                    .foregroundStyle(Color.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surf)
            .contentShape(Rectangle())

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }
}

// Keep legacy aliases so existing call sites compile
typealias ProgramRowView = ProgramGroupRowView
typealias TemplateCard = ProgramGroupRowView

// MARK: - Program Day Picker Sheet
