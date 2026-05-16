import SwiftUI

struct CoachMarkOverlay: View {
    @Bindable var viewModel: TutorialViewModel
    @Binding var selectedTab: Int

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Tap background to advance
                    viewModel.advance()
                }

            // Tooltip card
            VStack(spacing: 16) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.pumpAccent)
                            .frame(width: geo.size.width * viewModel.progress, height: 4)
                    }
                }
                .frame(height: 4)

                // Icon
                Image(systemName: viewModel.currentStep.icon)
                    .font(.mono(40))
                    .foregroundStyle(Color.pumpAccent)

                // Title
                Text(viewModel.currentStep.title)
                    .font(.display(22))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Description
                Text(viewModel.currentStep.description)
                    .font(.mono(16))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Buttons
                HStack(spacing: 16) {
                    if viewModel.currentStep != .complete {
                        Button("Skip") {
                            viewModel.skip()
                        }
                        .font(.mono(14))
                        .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        if viewModel.currentStep == .complete {
                            viewModel.complete()
                        } else {
                            // Navigate to required tab before advancing
                            if let tab = nextStep?.requiredTab, tab != selectedTab {
                                withAnimation {
                                    selectedTab = tab
                                }
                            }
                            viewModel.advance()
                        }
                    } label: {
                        Text(viewModel.currentStep == .complete ? "Get Started" : "Next")
                            .font(.mono(14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.pumpAccent)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
        .onChange(of: viewModel.currentStep) { _, newStep in
            if let tab = newStep.requiredTab, tab != selectedTab {
                withAnimation {
                    selectedTab = tab
                }
            }
        }
    }

    private var nextStep: TutorialStep? {
        let allSteps = TutorialStep.allCases
        guard let idx = allSteps.firstIndex(of: viewModel.currentStep),
              idx + 1 < allSteps.count else { return nil }
        return allSteps[idx + 1]
    }
}
