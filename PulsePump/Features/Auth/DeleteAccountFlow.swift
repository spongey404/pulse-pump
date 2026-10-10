import SwiftUI
import Observation

/// State for the delete-account confirmation: typed phrase, optional password (email accounts), progress, error.
@MainActor
@Observable
final class DeleteAccountModel {
    static let phrase = "DELETE"

    var typed = ""
    var password = ""
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    /// Email-only accounts have no other way to re-authenticate, so ask for the password up front.
    var needsPassword = false

    var phraseMatches: Bool { typed.trimmingCharacters(in: .whitespaces).uppercased() == Self.phrase }
    var canConfirm: Bool { phraseMatches && (!needsPassword || !password.isEmpty) && !isWorking }

    func reset(for user: AuthUser?) {
        typed = ""
        password = ""
        errorMessage = nil
        isWorking = false
        needsPassword = user?.primaryProvider == .password
    }

    /// Runs the deletion. Returns true when the account is gone (the gate then shows sign-in).
    func confirm(session: AuthSession) async -> Bool {
        guard canConfirm else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await session.deleteAccount(password: needsPassword ? password : nil)
            return true
        } catch let failure as AuthFailure {
            if failure == .passwordRequired { needsPassword = true }
            errorMessage = failure == .cancelled ? nil : failure.message
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private struct DeleteAccountModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(AuthSession.self) private var session
    @State private var model = DeleteAccountModel()

    func body(content: Content) -> some View {
        content
            .destructiveModal(
                isPresented: $isPresented,
                kicker: "DELETE ACCOUNT",
                title: "Delete your account?",
                body: "This permanently deletes your account and everything in the cloud. Data on this device is removed too. This can't be undone.",
                consequences: [
                    DestructiveConsequence(value: "ALL", label: "workouts, programs and history"),
                    DestructiveConsequence(value: "@", label: "your username, posts, friends and challenges"),
                ],
                cancelLabel: "KEEP",
                confirmLabel: "DELETE FOREVER",
                extra: AnyView(DeleteAccountFields(model: model)),
                confirmEnabled: model.canConfirm,
                isWorking: model.isWorking,
                dismissOnConfirm: false,
                onConfirm: {
                    Task {
                        if await model.confirm(session: session) { isPresented = false }
                    }
                }
            )
            .onChange(of: isPresented) { _, shown in
                if shown { model.reset(for: session.user) }
            }
    }
}

private struct DeleteAccountFields: View {
    @Bindable var model: DeleteAccountModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE \(DeleteAccountModel.phrase) TO CONFIRM")
                .font(.spaceMono(8, weight: .bold)).tracking(1.5)
                .foregroundStyle(Color.inkMuted)
            field {
                TextField("", text: $model.typed)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(AX.settings.deleteConfirmField)
            }
            if model.needsPassword {
                Text("PASSWORD")
                    .font(.spaceMono(8, weight: .bold)).tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                field {
                    SecureField("", text: $model.password)
                        .textContentType(.password)
                        .accessibilityIdentifier(AX.settings.deletePasswordField)
                }
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(.archivo(12))
                    .foregroundStyle(Color.signalDown)
                    .accessibilityIdentifier(AX.settings.deleteError)
            }
        }
        .disabled(model.isWorking)
    }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.spaceMono(14, weight: .bold))
            .foregroundStyle(Color.inkPrimary)
            .tint(Color.accentInk)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
    }
}

extension View {
    /// Destructive modal with typed confirmation that deletes the signed-in account (Cloud Function + local wipe).
    func deleteAccountFlow(isPresented: Binding<Bool>) -> some View {
        modifier(DeleteAccountModifier(isPresented: isPresented))
    }
}
