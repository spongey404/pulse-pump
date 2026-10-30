import SwiftUI

/// Dashed-border "add" affordance — reserved exclusively for add actions per the design
/// system ("Dashed borders are reserved exclusively for 'add' affordances"). Row height
/// never below 44px.
struct DashedAdd: View {
    let title: String
    var height: CGFloat = 36
    var cornerRadius: CGFloat = 8
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("+").font(.spaceMono(14)).lineLimit(1)
                Text(title)
                    .font(.spaceMono(10))
                    .tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.inkPrimary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        DashedAdd(title: "Create Challenge") {}
        DashedAdd(title: "Share Invite Link") {}
        DashedAdd(title: "Find Friends", cornerRadius: 14, action: {})
    }
    .padding()
}
