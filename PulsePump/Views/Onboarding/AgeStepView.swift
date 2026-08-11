import SwiftUI

struct AgeStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingStepLayout(
            label: "04 / BODY",
            title: "How old are you?",
            subtitle: "Used to calibrate calorie estimates. Not shown publicly.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    TextField("—", text: $viewModel.ageText)
                        .font(.archivo(56, weight: .black))
                        .tracking(-1)
                        .foregroundStyle(Color.inkPrimary)
                        .tint(Color.accentInk)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                        .frame(width: 160)

                    Text("YRS")
                        .font(.archivo(28, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                }

                Rectangle()
                    .fill(Color.dsHairLine)
                    .frame(height: 1)
            }
        }
        .onAppear { isFocused = true }
    }
}
