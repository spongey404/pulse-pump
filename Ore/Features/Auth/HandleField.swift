import SwiftUI

/// Username field with the availability line; shared by onboarding and the rename sheet.
struct HandleField: View {
    @Bindable var input: HandleInput
    var isFocused: FocusState<Bool>.Binding

    private var statusColor: Color {
        switch input.status {
        case .available: .signalUp
        case .invalid, .taken, .failed: .signalDown
        default: .inkMuted
        }
    }

    private var borderColor: Color {
        switch input.status {
        case .available: .signalUp
        case .invalid, .taken, .failed: .signalDown
        default: input.text.isEmpty ? .inkFaint : .accentInk
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("@")
                    .font(.spaceMono(20, weight: .bold))
                    .foregroundStyle(Color.inkMuted)
                TextField("", text: $input.text)
                    .font(.spaceMono(20, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .tint(Color.accentInk)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .textContentType(.username)
                    .focused(isFocused)
                    .submitLabel(.continue)
                    .accessibilityIdentifier(AX.onboarding.handleField)
                    .onChange(of: input.text) { _, _ in input.textChanged() }
                if input.status == .checking {
                    ProgressView().controlSize(.small)
                } else if input.status == .available {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.signalUp)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(borderColor, lineWidth: 1))

            HStack {
                Text((input.status.message ?? "LOWERCASE · \(input.handle.count)/\(HandleValidator.maxLength)").uppercased())
                    .font(.spaceMono(9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(statusColor)
                    .accessibilityIdentifier(AX.onboarding.handleStatus)
                if case .failed = input.status {
                    Button("RETRY") { Task { await input.checkNow() } }
                        .font(.spaceMono(9, weight: .bold))
                        .foregroundStyle(Color.accentInk)
                }
            }
        }
    }
}
