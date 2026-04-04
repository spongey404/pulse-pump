import SwiftUI

struct TutorialPromptStepView: View {
    var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.pumpPrimary)

                Text("Want a quick tutorial?")
                    .font(.title2.weight(.bold))

                Text("We'll walk you through the main features. You can always access this later from Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    viewModel.wantsTutorial = true
                    onComplete()
                } label: {
                    Text("Yes, show me around")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.pumpPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    viewModel.wantsTutorial = false
                    onComplete()
                } label: {
                    Text("Skip, I'll figure it out")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
