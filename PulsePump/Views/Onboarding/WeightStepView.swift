import SwiftUI

struct WeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    private var unitLabel: String { viewModel.unitPreference == .kg ? "KG" : "LBS" }
    var body: some View {
        OnboardingStepLayout(
            label: "02 / BODY",
            title: viewModel.name.isEmpty
                ? "How much do\nyou weigh?"
                : "How much do\nyou weigh, \(viewModel.name)?",
            subtitle: "Used to estimate calorie burn. Can be updated anytime.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(alignment: .leading, spacing: 16) {
                unitToggle

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        TextField("—", text: $viewModel.weightText)
                            .font(.archivo(56, weight: .black))
                            .tracking(-1)
                            .foregroundStyle(Color.inkPrimary)
                            .tint(Color.pumpAccent)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                            .frame(width: 160)

                        Text(unitLabel)
                            .font(.archivo(28, weight: .black))
                            .tracking(0.5)
                            .foregroundStyle(Color.inkMuted)
                    }

                    Rectangle()
                        .fill(Color.dsHairLine)
                        .frame(height: 1)
                }

            }
        }
        .onAppear { isFocused = true }
    }

    private var unitToggle: some View {
        HStack(spacing: 2) {
            ForEach([UnitPreference.kg, .lbs], id: \.self) { unit in
                let selected = viewModel.unitPreference == unit
                Button { viewModel.unitPreference = unit } label: {
                    Text(unit.rawValue.uppercased())
                        .font(.spaceMono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? Color.pumpAccent : Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(selected ? Color.canvasBg : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: selected)
            }
        }
        .padding(3)
        .background(Color.surf2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(width: 140)
    }
}
