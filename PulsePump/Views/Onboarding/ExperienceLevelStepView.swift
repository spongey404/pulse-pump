import SwiftUI

struct ExperienceLevelStepView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepLayout(
            title: "Experience level?",
            subtitle: "This helps us tailor your experience.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 10) {
                ForEach(ExperienceLevel.allCases) { level in
                    Button {
                        viewModel.experienceLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(level.displayName)
                                    .font(.body.weight(.medium))
                                Spacer()
                                if viewModel.experienceLevel == level {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.pumpPrimary)
                                }
                            }
                            Text(level == .beginner
                                ? "New to lifting or less than 6 months"
                                : "Consistent training for 6+ months")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(viewModel.experienceLevel == level
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
