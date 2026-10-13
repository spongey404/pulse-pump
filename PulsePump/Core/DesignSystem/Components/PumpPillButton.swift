import SwiftUI

struct PumpPillButton: View {
    let title: String
    var progress: Double? = nil  // 0–1, nil = no fill indicator
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Base fill
                    Capsule()
                        .fill(isDestructive ? Color.signalDown : Color.pumpAccent)

                    // Progress overlay (lighter tint on top)
                    if let progress {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: geo.size.width * max(0, min(1, progress)))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                    }

                    // Label
                    Text(title)
                        .font(.display(17))
                        .foregroundStyle(.white)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(height: 56)
            .clipShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
    }
}

// Smaller secondary pill (for share destinations etc.)
struct PumpChipButton: View {
    let title: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.mono(11, weight: .medium))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.pumpAccent : Color.surf2)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
