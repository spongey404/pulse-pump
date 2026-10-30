import SwiftUI

struct TutorialPromptStepView: View {
    var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    private var isExperienced: Bool { viewModel.experienceLevel == .experienced }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                // Square checkmark icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.accentInk.opacity(0.27), lineWidth: 1)
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentInk)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("09 / ALMOST DONE")
                        .font(.spaceMono(9))
                        .tracking(1.5)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.bottom, 8)

                    Text(isExperienced
                        ? "You're all set."
                        : "Welcome, \(viewModel.name.isEmpty ? "there" : viewModel.name)."
                    )
                    .font(.archivo(32, weight: .light))
                    .tracking(-0.5)
                    .lineSpacing(2)
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.bottom, 10)

                    Text(isExperienced
                        ? "We've set up a basic template based on your split. You know the drill — start logging and the app learns your patterns."
                        : "Your program is ready. Want a quick tour of the key features before you start?"
                    )
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                if isExperienced {
                    ctaButton("START TRAINING", primary: true, id: AX.onboarding.tutorialStart) {
                        viewModel.wantsTutorial = false
                        onComplete()
                    }
                } else {
                    ctaButton("YES, SHOW ME AROUND", primary: true, id: AX.onboarding.tutorialYes) {
                        viewModel.wantsTutorial = true
                        onComplete()
                    }
                    ctaButton("SKIP, I'LL EXPLORE MYSELF", primary: false, id: AX.onboarding.tutorialSkip) {
                        viewModel.wantsTutorial = false
                        onComplete()
                    }
                }

                Text("TUTORIAL ALWAYS AVAILABLE IN MORE → HELP")
                    .font(.spaceMono(9))
                    .tracking(1)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ctaButton(_ label: String, primary: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.archivo(primary ? 19 : 17, weight: .black))
                .tracking(2)
                .foregroundStyle(primary ? .white : Color.inkPrimary)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(primary ? Color.oreAccent : Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Group {
                        if !primary {
                            RoundedRectangle(cornerRadius: 12).strokeBorder(Color.inkFaint, lineWidth: 1)
                        }
                    }
                )
                .shadow(color: primary ? Color.oreAccent.opacity(0.2) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
