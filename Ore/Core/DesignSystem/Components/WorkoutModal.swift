import SwiftUI
import UIKit

// MARK: - Pattern A: Inline confirmation strip (matches design system InlineConfirm)

struct WorkoutModalModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let primaryLabel: String
    let primaryDestructive: Bool
    let onPrimary: () -> Void
    let secondaryLabel: String?
    let onSecondary: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    Color.black.opacity(0.20)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                isPresented = false
                            }
                        }
                    modalCard
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isPresented)
    }

    private var modalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.archivo(13, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(message)
                    .font(.archivo(12))
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isPresented = false }
                    onSecondary?()
                } label: {
                    Text(secondaryLabel ?? "CANCEL")
                        .font(.archivo(11, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.inkPrimary.opacity(0.13), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.modal.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isPresented = false }
                    onPrimary()
                } label: {
                    Text(primaryLabel)
                        .font(.archivo(11, weight: .black))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background { if primaryDestructive { Color.oreAccent } else { AccentFill(priority: 10) } }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(
                            color: Color.oreAccent.opacity(0.33),
                            radius: 8, y: 4
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.modal.primary)
                .tutorialTarget("tutorial.modal-primary")
            }
        }
        .padding(14)
        .frame(width: UIScreen.main.bounds.width - 40)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.inkPrimary.opacity(0.13), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.10), radius: 20, y: 6)
    }
}

extension View {
    func workoutModal(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        primaryLabel: String,
        primaryDestructive: Bool = false,
        onPrimary: @escaping () -> Void,
        secondaryLabel: String? = nil,
        onSecondary: (() -> Void)? = nil
    ) -> some View {
        modifier(WorkoutModalModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            primaryLabel: primaryLabel,
            primaryDestructive: primaryDestructive,
            onPrimary: onPrimary,
            secondaryLabel: secondaryLabel,
            onSecondary: onSecondary
        ))
    }
}
