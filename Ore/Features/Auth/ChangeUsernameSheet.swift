import SwiftUI

/// Rename the @username: claims the new handle and releases the old one in one batch.
struct ChangeUsernameSheet: View {
    let user: User
    var remote: ProfileRemote = FirestoreProfileRemote()

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session
    @State private var input: HandleInput?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CHANGE USERNAME")
                    .font(.spaceMono(11, weight: .bold)).tracking(1.5)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Button("CANCEL") { dismiss() }
                    .font(.spaceMono(10, weight: .bold)).foregroundStyle(Color.inkMuted)
            }
            Text("Your old username is released so someone else can take it.")
                .font(.archivo(13)).foregroundStyle(Color.inkMuted)

            if let input {
                HandleField(input: input, isFocused: $focused)
                if let errorMessage {
                    Text(errorMessage).font(.archivo(12)).foregroundStyle(Color.signalDown)
                }
                Button {
                    Task { await save(input) }
                } label: {
                    Group { if isSaving { ProgressView().tint(.white) } else { Text("SAVE") } }
                        .font(.archivo(19, weight: .black)).tracking(2).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background { if canSave(input) { AccentFill(priority: 10) } else { Color.inkFaint } }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canSave(input) || isSaving)
            }
            Spacer()
        }
        .padding(20)
        .background(Color.canvasBg.ignoresSafeArea())
        .presentationDetents([.medium])
        .onAppear {
            guard input == nil, let uid = session.user?.uid else { return }
            let model = HandleInput(remote: remote, uid: uid, ownedHandle: user.username)
            model.text = user.username
            input = model
            focused = true
        }
    }

    private func canSave(_ input: HandleInput) -> Bool {
        input.isAvailable && input.handle != user.username
    }

    private func save(_ input: HandleInput) async {
        guard let uid = session.user?.uid else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await remote.changeHandle(uid: uid, from: user.username, to: input.handle, displayName: user.name)
            user.username = input.handle
            user.updatedAt = Date()
            dismiss()
        } catch let error as ProfileRemoteError {
            if error == .handleTaken { input.markTaken() }
            errorMessage = error.message
        } catch {
            errorMessage = "Couldn't change your username. Please try again."
        }
    }
}
