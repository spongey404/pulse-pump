import SwiftUI

struct AgeStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingStepLayout(
            title: "How old are you?",
            subtitle: "Used for calorie and recovery estimates.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            HStack(spacing: 12) {
                TextField("25", text: $viewModel.ageText)
                    .font(.title2)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("years")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { isFocused = true }
    }
}
