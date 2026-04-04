import SwiftUI

struct HeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var focusedField: Field?

    enum Field { case cm, feet, inches }

    var body: some View {
        OnboardingStepLayout(
            title: "What's your height?",
            subtitle: "Used for personalized calculations.",
            canContinue: viewModel.canContinue,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 16) {
                Picker("Format", selection: $viewModel.useImperialHeight) {
                    Text("cm").tag(false)
                    Text("ft / in").tag(true)
                }
                .pickerStyle(.segmented)

                if viewModel.useImperialHeight {
                    HStack(spacing: 12) {
                        TextField("5", text: $viewModel.heightFeet)
                            .font(.title2)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .feet)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("ft")
                            .foregroundStyle(.secondary)

                        TextField("10", text: $viewModel.heightInches)
                            .font(.title2)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .inches)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("in")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 12) {
                        TextField("175", text: $viewModel.heightText)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .cm)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("cm")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            focusedField = viewModel.useImperialHeight ? .feet : .cm
        }
    }
}
