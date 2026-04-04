import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.currentStep != .welcome {
                    onboardingHeader
                }

                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeView(viewModel: viewModel)
                    case .name:
                        NameStepView(viewModel: viewModel)
                    case .weight:
                        WeightStepView(viewModel: viewModel)
                    case .height:
                        HeightStepView(viewModel: viewModel)
                    case .age:
                        AgeStepView(viewModel: viewModel)
                    case .gender:
                        GenderStepView(viewModel: viewModel)
                    case .unitPreference:
                        UnitPreferenceStepView(viewModel: viewModel)
                    case .experienceLevel:
                        ExperienceLevelStepView(viewModel: viewModel)
                    case .splitSelection:
                        SplitSelectionStepView(viewModel: viewModel)
                    case .tutorialPrompt:
                        TutorialPromptStepView(viewModel: viewModel) {
                            viewModel.completeOnboarding(modelContext: modelContext)
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.authError != nil },
            set: { if !$0 { viewModel.authError = nil } }
        )) {
            Button("OK") { viewModel.authError = nil }
        } message: {
            Text(viewModel.authError ?? "")
        }
    }

    private var onboardingHeader: some View {
        VStack(spacing: 12) {
            HStack {
                if viewModel.currentStep.rawValue > 1 {
                    Button(action: viewModel.goBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            ProgressView(value: viewModel.progress)
                .tint(Color.pumpPrimary)
                .padding(.horizontal)
        }
        .padding(.top, 8)
    }
}
