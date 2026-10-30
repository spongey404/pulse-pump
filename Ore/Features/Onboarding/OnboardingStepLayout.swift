import SwiftUI

// MARK: - Shared layout shell — matches QHead + PrimaryCTA pattern in Ore Onboarding.html

struct OnboardingStepLayout<Content: View>: View {
    let label: String         // e.g. "01 / NAME"
    let title: String         // e.g. "What should\nwe call you?"
    let subtitle: String?
    let canContinue: Bool
    let ctaLabel: String
    let onContinue: () -> Void
    let scrollable: Bool
    @ViewBuilder let content: Content

    init(
        label: String = "",
        title: String,
        subtitle: String? = nil,
        canContinue: Bool,
        ctaLabel: String = "CONTINUE",
        scrollable: Bool = false,
        onContinue: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.canContinue = canContinue
        self.ctaLabel = ctaLabel
        self.scrollable = scrollable
        self.onContinue = onContinue
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── QHead ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                if !label.isEmpty {
                    Text(label)
                        .font(.spaceMono(9))
                        .tracking(1.5)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.bottom, 8)
                }

                Text(title)
                    .font(.archivo(30, weight: .light))
                    .tracking(-0.5)
                    .lineSpacing(2)
                    .foregroundStyle(Color.inkPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.archivo(13))
                        .foregroundStyle(Color.inkMuted)
                        .lineSpacing(3)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 20)

            // ── Content ────────────────────────────────────────────
            if scrollable {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading) { content }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
            } else {
                VStack(alignment: .leading) { content }
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)

            // ── PrimaryCTA ─────────────────────────────────────────
            Button(action: onContinue) {
                Text(ctaLabel)
                    .font(.archivo(22, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canContinue ? Color.oreAccent : Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(
                        color: canContinue ? Color.oreAccent.opacity(0.2) : .clear,
                        radius: 10, y: 4
                    )
            }
            .disabled(!canContinue)
            .accessibilityIdentifier(AX.onboarding.next)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
    }
}
