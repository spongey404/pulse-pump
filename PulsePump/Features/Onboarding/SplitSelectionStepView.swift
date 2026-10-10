import SwiftUI

struct SplitSelectionStepView: View {
    var viewModel: OnboardingViewModel

    private let splits: [(type: SplitType, label: String, meta: String)] = [
        (.ppl,        "Push / Pull / Legs", "6 DAYS/WK · HIGH FREQUENCY · POPULAR"),
        (.upperLower, "Upper / Lower",      "4 DAYS/WK · BALANCED · GREAT FOR MOST"),
        (.fullBody,   "Full Body",          "3 DAYS/WK · EFFICIENT · GOOD FOR BEGINNERS"),
        (.broSplit,   "Bro Split",          "5 DAYS/WK · ONE MUSCLE/DAY · CLASSIC"),
        (.custom,     "Custom",             "DEFINE YOUR OWN DAYS AND FOCUS"),
        (.none,       "No fixed split",     "TRAIN WHENEVER · LOG FREELY"),
    ]

    var body: some View {
        OnboardingStepLayout(
            label: "08 / PROGRAM",
            title: "How do you structure\nyour training?",
            subtitle: "This sets up your first program template. Change it anytime.",
            canContinue: viewModel.canContinue,
            scrollable: true,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 8) {
                ForEach(splits, id: \.type) { item in
                    splitRow(item)
                }
            }
        }
    }

    private func splitRow(_ item: (type: SplitType, label: String, meta: String)) -> some View {
        let selected = viewModel.selectedSplitType == item.type
        return Button { viewModel.selectedSplitType = item.type } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? Color.accentInk : Color.inkFaint,
                            lineWidth: 2
                        )
                        .frame(width: 18, height: 18)
                    if selected {
                        Circle()
                            .fill(Color.pumpAccent)
                            .frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label)
                        .font(.archivo(14, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.accentInk : Color.inkPrimary)

                    Text(item.meta)
                        .font(.spaceMono(8))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                }

                Spacer()
            }
            .frame(height: 56)
            .padding(.horizontal, 16)
            .background(selected ? Color.accentSoft : Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    selected ? Color.accentInk : Color.inkFaint,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.onboarding.split(item.label))
        .animation(.easeInOut(duration: 0.08), value: selected)
    }
}
