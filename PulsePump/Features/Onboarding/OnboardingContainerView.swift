import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext

    /// `onCreated` runs once the cloud profile and the local user both exist.
    init(uid: String, prefilledName: String, remote: ProfileRemote, onCreated: @escaping (String) -> Void) {
        let model = OnboardingViewModel(uid: uid, prefilledName: prefilledName, remote: remote)
        model.onAccountCreated = onCreated
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            Color.canvasBg.ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader

                Group {
                    switch viewModel.currentStep {
                    case .name:
                        NameStepView(viewModel: viewModel)
                    case .handle:
                        HandleStepView(viewModel: viewModel)
                    case .weight:
                        WeightStepView(viewModel: viewModel)
                    case .height:
                        HeightStepView(viewModel: viewModel)
                    case .age:
                        AgeStepView(viewModel: viewModel)
                    case .gender:
                        GenderStepView(viewModel: viewModel)
                    case .experienceLevel:
                        ExperienceLevelStepView(viewModel: viewModel)
                    case .splitSelection:
                        SplitSelectionStepView(viewModel: viewModel)
                    case .tutorialPrompt:
                        TutorialPromptStepView(viewModel: viewModel) {
                            Task { await viewModel.submit(modelContext: modelContext) }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .overlay {
            if viewModel.isSubmitting {
                ZStack {
                    Color.canvasBg.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView().tint(Color.accentInk)
                        Text("CREATING YOUR ACCOUNT")
                            .font(.spaceMono(10, weight: .bold)).tracking(1.5)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
        }
        .alert("Couldn't finish setup", isPresented: .init(
            get: { viewModel.submitError != nil },
            set: { if !$0 { viewModel.submitError = nil } }
        )) {
            Button("OK") { viewModel.submitError = nil }
        } message: {
            Text(viewModel.submitError ?? "")
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
                .accessibilityLabel("Back")
                .accessibilityIdentifier(AX.onboarding.back)
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
                        .accessibilityIdentifier(AX.onboarding.stepCounter)
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
