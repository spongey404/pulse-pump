import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.canvasBg.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.currentStep != .welcome {
                    progressHeader
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
                        // Unit captured inline in weight/height — skip straight through
                        Color.clear.onAppear { viewModel.advance() }
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
        .onChange(of: viewModel.shouldSkipToComplete) { _, skip in
            if skip { viewModel.completeOnboarding(modelContext: modelContext) }
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

    // MARK: - Progress header (back btn + bar) — matches HTML layout exactly

    private var progressHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            // Back button
            if viewModel.currentStep != .name {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 36, height: 36)
            }

            // Progress bar + labels
            VStack(spacing: 0) {
                // Track + fill
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999)
                            .fill(Color.dsHairLine)
                            .frame(height: 2)
                        RoundedRectangle(cornerRadius: 999)
                            .fill(Color.pumpAccent)
                            .frame(width: geo.size.width * viewModel.progress, height: 2)
                            .animation(.easeInOut(duration: 0.35), value: viewModel.progress)
                    }
                }
                .frame(height: 2)

                // Step counter + percentage
                HStack {
                    Text("STEP \(viewModel.stepNumber) OF \(viewModel.totalSteps)")
                        .font(.spaceMono(8))
                        .tracking(1)
                        .foregroundStyle(Color.inkMuted)
                    Spacer()
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.spaceMono(8))
                        .tracking(1)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.top, 5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
