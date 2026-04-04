import SwiftUI

struct GenderStepView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepLayout(
            title: "What's your gender?",
            subtitle: "Used for more accurate calorie estimates.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 10) {
                ForEach(Gender.allCases) { gender in
                    Button {
                        viewModel.gender = gender
                    } label: {
                        HStack {
                            Text(gender.displayName)
                                .font(.body)
                            Spacer()
                            if viewModel.gender == gender {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.pumpPrimary)
                            }
                        }
                        .padding()
                        .background(viewModel.gender == gender
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
