import SwiftUI
import SwiftData

struct SetTypeSheetView: View {
    let currentType: SetType
    let onPick: (SetType) -> Void
    let onClose: () -> Void

    @State private var cardOffset: CGFloat = 500

    private struct TypeRow {
        let type: SetType
        let name: String
        let desc: String
    }

    private let rows: [TypeRow] = [
        TypeRow(type: .standard,   name: "Standard",    desc: "Normal working set"),
        TypeRow(type: .warmup,     name: "Warmup",      desc: "Excluded from volume"),
        TypeRow(type: .superset,   name: "Superset",    desc: "Paired with next exercise, no rest"),
        TypeRow(type: .dropset,    name: "Dropset",     desc: "Multiple weight drops in one set"),
        TypeRow(type: .restPause,  name: "Rest-Pause",  desc: "Short rest, continue same set"),
        TypeRow(type: .amrap,      name: "AMRAP",       desc: "As many reps as possible"),
        TypeRow(type: .failureSet, name: "To Failure",  desc: "Last possible rep"),
        TypeRow(type: .leftRight,  name: "Unilateral",  desc: "Log left and right sides separately"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Invisible tap-to-close area
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            // Sheet card — slides up independently
            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.inkFaint)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // Label
                Text("SET TYPE")
                    .font(.spaceMono(9))
                    .foregroundStyle(Color.accentInk)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                // Type rows
                ForEach(rows, id: \.type) { row in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { onPick(row.type) }
                    } label: {
                        HStack(spacing: 10) {
                            let style = setTypeStyles[row.type] ?? setTypeStyles[.standard]!
                            ZStack {
                                if row.type == .standard {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
                                        .foregroundStyle(Color.inkFaint)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(style.bg)
                                }
                                Text(style.label)
                                    .font(.spaceMono(9, weight: .bold))
                                    .foregroundStyle(style.fg)
                                    .tracking(0.6)
                            }
                            .frame(width: 42, height: 22)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.name)
                                    .font(.archivo(14, weight: .semibold))
                                    .foregroundStyle(Color.inkPrimary)
                                Text(row.desc)
                                    .font(.archivo(13))
                                    .foregroundStyle(Color.inkMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if currentType == row.type {
                                Circle()
                                    .fill(Color.oreAccent)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())   // the whole row takes the tap, not just its text
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.dsHairLine).frame(height: 1)
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier(AX.workout.setTypeRow(row.name))
                    .tutorialTarget("tutorial.set-type-warmup", enabled: row.type == .warmup)
                }

                Color.clear.frame(height: 28)
            }
            .background(Color.canvasBg)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.inkPrimary.opacity(0.14), lineWidth: 1)
                    .padding(.bottom, -28)
            )
            .offset(y: cardOffset)
            .onAppear {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    cardOffset = 0
                }
            }
        }
    }
}

// MARK: - Rest Timer Modal
