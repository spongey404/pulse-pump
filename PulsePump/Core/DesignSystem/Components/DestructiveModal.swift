import SwiftUI

// MARK: - Pattern B: Full-bleed destructive modal (delete program, delete account, etc.)

struct DestructiveConsequence {
    let value: String
    let label: String
}

struct DestructiveModalModifier: ViewModifier {
    @Binding var isPresented: Bool
    let kicker: String
    let title: String
    let body: String
    let consequences: [DestructiveConsequence]
    let cancelLabel: String
    let confirmLabel: String
    let onConfirm: () -> Void
    /// Optional content under the body text (e.g. a typed-confirmation field).
    var extra: AnyView? = nil
    var confirmEnabled = true
    /// Shows a spinner on the confirm button and locks both buttons.
    var isWorking = false
    /// false keeps the modal open after confirm so the caller can show progress / errors.
    var dismissOnConfirm = true

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(50)

                modalCard
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(51)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isPresented)
    }

    private var modalCard: some View {
        VStack(spacing: 0) {
            // Red warning strip
            HStack {
                Text("▲ \(kicker)")
                    .font(.spaceMono(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(.white)
                Spacer()
                Text("IRREVERSIBLE")
                    .font(.spaceMono(9))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.signalDown)

            // Body content
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.archivo(22, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .tracking(0.3)
                    .lineSpacing(2)
                    .padding(.bottom, 8)

                Text(body)
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(4)
                    .padding(.bottom, 14)

                if let extra {
                    extra.padding(.bottom, 14)
                }

                if !consequences.isEmpty {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("WHAT YOU'LL LOSE")
                                .font(.spaceMono(8, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Color.inkMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surf2)

                        Rectangle().fill(Color.dsHairLine).frame(height: 1)

                        ForEach(Array(consequences.enumerated()), id: \.offset) { idx, c in
                            HStack(spacing: 10) {
                                Text(c.value)
                                    .font(.spaceMono(11, weight: .bold))
                                    .foregroundStyle(Color.signalDown)
                                    .frame(minWidth: 38, alignment: .leading)
                                Text(c.label)
                                    .font(.archivo(12))
                                    .foregroundStyle(Color.inkPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                            if idx < consequences.count - 1 {
                                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                            }
                        }
                    }
                    .background(Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.dsHairLine, lineWidth: 1)
                    )
                    .padding(.bottom, 14)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 4)

            // Buttons row
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isPresented = false }
                } label: {
                    Text(cancelLabel)
                        .font(.archivo(13, weight: .black))
                        .tracking(1)
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.inkPrimary.opacity(0.13), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityIdentifier(AX.modal.cancel)

                Button {
                    if dismissOnConfirm { withAnimation(.easeInOut(duration: 0.18)) { isPresented = false } }
                    onConfirm()
                } label: {
                    Group {
                        if isWorking { ProgressView().tint(.white) } else { Text(confirmLabel) }
                    }
                        .font(.archivo(13, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.signalDown)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.signalDown.opacity(0.33), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!confirmEnabled || isWorking)
                .opacity(confirmEnabled ? 1 : 0.4)
                .accessibilityIdentifier(AX.modal.confirm)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
            }
        }
        .background(Color.canvasBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.inkPrimary.opacity(0.13), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

extension View {
    func destructiveModal(
        isPresented: Binding<Bool>,
        kicker: String,
        title: String,
        body: String,
        consequences: [DestructiveConsequence] = [],
        cancelLabel: String = "KEEP",
        confirmLabel: String = "DELETE",
        extra: AnyView? = nil,
        confirmEnabled: Bool = true,
        isWorking: Bool = false,
        dismissOnConfirm: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DestructiveModalModifier(
            isPresented: isPresented,
            kicker: kicker,
            title: title,
            body: body,
            consequences: consequences,
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            onConfirm: onConfirm,
            extra: extra,
            confirmEnabled: confirmEnabled,
            isWorking: isWorking,
            dismissOnConfirm: dismissOnConfirm
        ))
    }
}
