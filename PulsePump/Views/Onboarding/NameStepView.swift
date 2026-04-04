import SwiftUI

struct NameStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingStepLayout(
            title: "What's your name?",
            subtitle: "This is how you'll appear to friends.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            TextField("Name", text: $viewModel.name)
                .font(.title2)
                .textContentType(.name)
                .focused($isFocused)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .submitLabel(.continue)
                .onSubmit {
                    if viewModel.canContinue { viewModel.advance() }
                }
        }
        .onAppear { isFocused = true }
    }
}
