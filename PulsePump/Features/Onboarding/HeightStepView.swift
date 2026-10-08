import SwiftUI

struct HeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var focusedField: Field?
    enum Field { case cm, feet, inches }

    var body: some View {
        OnboardingStepLayout(
            label: "03 / BODY",
            title: "How tall are you?",
            subtitle: "Used with weight to estimate your baseline metabolism.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Unit toggle
                HStack(spacing: 2) {
                    ForEach([("CM", false), ("FT / IN", true)], id: \.0) { label, imperial in
                        let selected = viewModel.useImperialHeight == imperial
                        Button { viewModel.useImperialHeight = imperial } label: {
                            Text(label)
                                .font(.spaceMono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(selected ? Color.accentInk : Color.inkMuted)
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

                if viewModel.useImperialHeight {
                    HStack(alignment: .lastTextBaseline, spacing: 24) {
                        imperialInput(text: $viewModel.heightFeet, unit: "FT", focus: .feet)
                        imperialInput(text: $viewModel.heightInches, unit: "IN", focus: .inches)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            TextField("—", text: $viewModel.heightText)
                                .font(.archivo(56, weight: .black))
                                .tracking(-1)
                                .foregroundStyle(Color.inkPrimary)
                                .tint(Color.accentInk)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .cm)
                                .frame(width: 160)

                            Text("CM")
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
        }
        .onAppear { focusedField = viewModel.useImperialHeight ? .feet : .cm }
    }

    private func imperialInput(text: Binding<String>, unit: String, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                TextField("—", text: text)
                    .font(.archivo(56, weight: .black))
                    .tracking(-1)
                    .foregroundStyle(Color.inkPrimary)
                    .tint(Color.accentInk)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: focus)
                    .frame(width: 100)

                Text(unit)
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
