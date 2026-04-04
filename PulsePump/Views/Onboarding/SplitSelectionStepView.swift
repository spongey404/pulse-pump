import SwiftUI

struct SplitSelectionStepView: View {
    var viewModel: OnboardingViewModel

    private var splits: [SplitType] {
        SplitType.allCases
    }

    var body: some View {
        OnboardingStepLayout(
            title: "Training split?",
            subtitle: "Pick a program structure or choose custom to build your own later.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(splits) { split in
                        Button {
                            viewModel.selectedSplitType = split
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(split.displayName)
                                        .font(.body.weight(.medium))
                                    if let days = split.daysPerWeek {
                                        Text("\(days) days/week")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if viewModel.selectedSplitType == split {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.pumpPrimary)
                                }
                            }
                            .padding()
                            .background(viewModel.selectedSplitType == split
                                ? Color.pumpPrimary.opacity(0.1)
                                : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
