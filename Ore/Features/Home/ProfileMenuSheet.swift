import SwiftUI
import SwiftData
import FirebaseAuth

struct ProfileMenuSheet: View {
    let user: User?
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.oreAccent.opacity(0.10))
                        .frame(width: 44, height: 44)
                    Text(user?.name.prefix(1).uppercased() ?? "?")
                        .font(.archivo(20, weight: .black))
                        .foregroundStyle(Color.accentInk)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text((user?.name ?? "ATHLETE").uppercased())
                        .font(.archivo(18, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                    if let username = user?.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.spaceMono(9))
                            .tracking(0.8)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.surf)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.inkMuted)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            // Menu rows
            VStack(spacing: 0) {
                menuRow(icon: "arrow.right.square", label: "SIGN OUT", destructive: true) {
                    dismiss()
                    Task { await session.signOut() }
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }

    private func menuRow(icon: String, label: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(destructive ? Color.signalDown.opacity(0.10) : Color.surf2)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(destructive ? Color.signalDown : Color.inkMuted)
                }
                Text(label)
                    .font(.archivo(15, weight: .medium))
                    .foregroundStyle(destructive ? Color.signalDown : Color.inkPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.98))
    }
}

// MARK: - Chip Flow Layout
