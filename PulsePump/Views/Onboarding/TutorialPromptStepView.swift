import SwiftUI

struct TutorialPromptStepView: View {
    var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    var body: some View {
        if viewModel.experienceLevel == .experienced {
            ExperiencedQuickStartView(viewModel: viewModel, onComplete: onComplete)
        } else {
            BeginnerTutorialView(viewModel: viewModel, onComplete: onComplete)
        }
    }
}

// MARK: - Beginner: Tutorial prompt

private struct BeginnerTutorialView: View {
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

                Text("We'll walk you through the main features step by step. Takes about 2 minutes.")
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

// MARK: - Experienced: Quick start

private struct ExperiencedQuickStartView: View {
    var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.pumpPrimary)

                Text("You're all set.")
                    .font(.title2.weight(.bold))

                Text("You know the drill. Log your first workout and the app will adapt to your training style. Hints and tutorials are always available in the More tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                viewModel.wantsTutorial = false
                onComplete()
            } label: {
                Text("Start Training")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.pumpPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
