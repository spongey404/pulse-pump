import SwiftUI

/// Profile-photo placeholder — a rounded square, matching the Home tab masthead's
/// canonical avatar treatment (`ContentView.mastheadRow`), not a circle. Corner radius
/// scales with size so every avatar in the app reads with the same roundedness.
struct Avatar: View {
    let initial: String
    var size: CGFloat = 36
    var showBorder: Bool = true
    var textColor: Color = .inkPrimary

    private var cornerRadius: CGFloat { size * 0.267 }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.surf2)
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.ruleStrong, lineWidth: 1)
                }
            }
            .overlay {
                Text(initial.prefix(1).uppercased())
                    .font(.archivo(size * 0.42, weight: .black))
                    .foregroundStyle(textColor)
            }
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 12) {
        Avatar(initial: "A", size: 22, showBorder: false)
        Avatar(initial: "B", size: 32)
        Avatar(initial: "C", size: 38)
        Avatar(initial: "D", size: 44)
        Avatar(initial: "E", size: 60)
    }
    .padding()
}
