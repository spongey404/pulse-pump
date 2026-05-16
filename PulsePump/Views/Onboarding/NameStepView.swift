import SwiftUI

struct NameStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingStepLayout(
            label: "01 / NAME",
            title: "What should we call you?",
            subtitle: "This is how you'll appear to friends and on your profile.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .leading) {
                    if viewModel.name.isEmpty {
                        Text("Your name")
                            .font(.archivo(22, weight: .medium))
                            .foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 16)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $viewModel.name)
                        .font(.archivo(24, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkPrimary)
                        .tint(Color.pumpAccent)
                        .textContentType(.name)
                        .focused($isFocused)
                        .padding(.horizontal, 16)
                        .submitLabel(.continue)
                        .onSubmit { if viewModel.canContinue { viewModel.advance() } }
                }
                .frame(height: 54)
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).strokeBorder(
                        !viewModel.name.isEmpty ? Color.pumpAccent : Color.inkFaint,
                        lineWidth: 1
                    )
                )

                Text("FIRST NAME IS FINE · CAN CHANGE LATER")
                    .font(.spaceMono(9))
                    .tracking(0.8)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .onAppear { isFocused = true }
    }
}
