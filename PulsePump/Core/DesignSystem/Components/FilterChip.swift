import SwiftUI

/// Pill filter/selection chip. Filled `--accent` + white text when selected, hairline
/// border + muted text otherwise. Covers both toggle pairs (GLOBAL/FRIENDS) and wrapping
/// selection rows (RUNS FOR windows).
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.spaceMono(10, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.pumpAccent : Color.surf2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Color.pumpAccent : Color.dsHairLine, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 8) {
        FilterChip(title: "Global", isSelected: true) {}
        FilterChip(title: "Friends", isSelected: false) {}
    }
    .padding()
}
