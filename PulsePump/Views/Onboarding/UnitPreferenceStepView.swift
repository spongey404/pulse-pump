import SwiftUI

struct UnitPreferenceStepView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepLayout(
            title: "Preferred units?",
            subtitle: "You can change this anytime in Settings.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 10) {
                ForEach(UnitPreference.allCases) { unit in
                    Button {
                        viewModel.unitPreference = unit
                    } label: {
                        HStack {
                            Text(unit.displayName)
                                .font(.body)
                            Spacer()
                            if viewModel.unitPreference == unit {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.pumpPrimary)
                            }
                        }
                        .padding()
                        .background(viewModel.unitPreference == unit
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
