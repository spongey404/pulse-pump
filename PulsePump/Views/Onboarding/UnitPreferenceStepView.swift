import SwiftUI

struct UnitPreferenceStepView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepLayout(
            label: "UNITS",
            title: "Preferred units?",
            subtitle: "You can change this anytime in Settings.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 8) {
                ForEach(UnitPreference.allCases) { unit in
                    Button { viewModel.unitPreference = unit } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        viewModel.unitPreference == unit ? Color.pumpAccent : Color.dsHairLine,
                                        lineWidth: viewModel.unitPreference == unit ? 2 : 1
                                    )
                                    .frame(width: 22, height: 22)
                                if viewModel.unitPreference == unit {
                                    Circle().fill(Color.pumpAccent).frame(width: 12, height: 12)
                                }
                            }
                            Text(unit.displayName)
                                .font(.archivo(16))
                                .foregroundStyle(Color.inkPrimary)
                            Spacer()
                        }
                        .padding(16)
                        .background(viewModel.unitPreference == unit ? Color.accentSoft : Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                            viewModel.unitPreference == unit ? Color.pumpAccent.opacity(0.4) : Color.dsHairLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
