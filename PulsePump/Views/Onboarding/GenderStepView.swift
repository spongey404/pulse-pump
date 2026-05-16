import SwiftUI

struct GenderStepView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepLayout(
            label: "05 / BODY",
            title: "Which best describes you?",
            subtitle: "Used only for calorie burn calculations.",
            canContinue: viewModel.canContinue,
            scrollable: true,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 8) {
                ForEach(Gender.allCases) { gender in
                    Button { viewModel.gender = gender } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        viewModel.gender == gender ? Color.pumpAccent : Color.inkFaint,
                                        lineWidth: 2
                                    )
                                    .frame(width: 18, height: 18)
                                if viewModel.gender == gender {
                                    Circle()
                                        .fill(Color.pumpAccent)
                                        .frame(width: 8, height: 8)
                                }
                            }

                            Text(gender.displayName)
                                .font(.archivo(15, weight: viewModel.gender == gender ? .semibold : .medium))
                                .foregroundStyle(viewModel.gender == gender ? Color.pumpAccent : Color.inkPrimary)

                            Spacer()
                        }
                        .frame(height: 52)
                        .padding(.horizontal, 16)
                        .background(viewModel.gender == gender ? Color.accentSoft : Color.surf)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).strokeBorder(
                                viewModel.gender == gender ? Color.pumpAccent : Color.inkFaint,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.08), value: viewModel.gender == gender)
                }
            }
        }
    }
}
