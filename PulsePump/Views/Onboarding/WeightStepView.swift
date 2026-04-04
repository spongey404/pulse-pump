import SwiftUI

struct WeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingStepLayout(
            title: "What's your weight?",
            subtitle: "Used for calorie estimates. You can change this anytime.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            HStack(spacing: 12) {
                TextField("0", text: $viewModel.weightText)
                    .font(.title2)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(viewModel.unitPreference == .kg ? "kg" : "lbs")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { isFocused = true }
    }
}
