import SwiftUI

struct ExperienceLevelStepView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepLayout(
            label: "07 / EXPERIENCE",
            title: "How long have you\nbeen lifting?",
            subtitle: "This shapes how we set up your first program.",
            canContinue: viewModel.canContinue,
            scrollable: true,
            onContinue: viewModel.advance
        ) {
            VStack(spacing: 10) {
                ForEach(ExperienceLevel.allCases) { level in
                    experienceCard(level)
                }
            }
        }
    }

    private func experienceCard(_ level: ExperienceLevel) -> some View {
        let selected = viewModel.experienceLevel == level
        return Button { viewModel.experienceLevel = level } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? Color.accentInk : Color.inkFaint,
                            lineWidth: 2
                        )
                        .frame(width: 18, height: 18)
                    if selected {
                        Circle()
                            .fill(Color.pumpAccent)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.archivo(15, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.accentInk : Color.inkPrimary)

                    Text(level.sub)
                        .font(.archivo(12))
                        .foregroundStyle(Color.inkMuted)

                    Text(level.detail)
                        .font(.archivo(12))
                        .foregroundStyle(Color.inkMuted.opacity(0.75))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentSoft : Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    selected ? Color.accentInk : Color.inkFaint,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.08), value: selected)
    }
}
