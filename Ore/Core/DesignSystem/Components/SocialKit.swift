import SwiftUI

// Small pieces the Social screens share (design "Ore Social Final"): the gold PR star, the board medals, the SUPERNOVA tag and a
// body-map Stardust overlay for members. Build the screens from these instead of re-drawing them.

/// A personal record: the gold four-point star (#FFC83D) with a soft glow, twinkling over 2.6 s (scale 0.82 → 1.08, 8° turn,
/// opacity 0.85 → 1). Reduce Motion keeps it still. The value next to it is `Color.prGold` (#C9892E).
struct PRStar: View {
    var size: CGFloat = 12
    /// Seconds to hold off before the twinkle starts (the design staggers the stars in a list).
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    var body: some View {
        ZStack {
            FourPointStar().fill(Color(hex: "#FFC83D")).blur(radius: 1.5).opacity(0.8)   // CSS drop-shadow 3 px = SwiftUI radius 1.5
            FourPointStar().fill(Color(hex: "#FFC83D"))
        }
        .frame(width: size, height: size)
        .scaleEffect(up ? 1.08 : 0.82)
        .rotationEffect(.degrees(up ? 8 : 0))
        .opacity(up ? 1 : 0.85)
        .onAppear {
            guard !reduceMotion else { up = true; return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true).delay(delay)) { up = true }
        }
        .accessibilityHidden(true)
    }
}

/// The top three on a board: gold, silver (#C9D1DA) and bronze (#C88A4E) four-point stars; the name next to it stays ink.
struct MedalStar: View {
    let rank: Int
    var size: CGFloat = 12

    static func color(rank: Int) -> Color {
        switch rank {
        case 1: Color(hex: "#FFC83D")
        case 2: Color(hex: "#C9D1DA")
        default: Color(hex: "#C88A4E")
        }
    }

    var body: some View {
        FourPointStar().fill(Self.color(rank: rank))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// "SUPERNOVA*" under a member's name: Space Mono bold 8, ink, the asterisk gold (only on branded surfaces: see CLAUDE.md).
struct SupernovaTag: View {
    var body: some View {
        (Text("SUPERNOVA").foregroundStyle(Color.inkPrimary) + Text("*").foregroundStyle(Color(hex: "#FFC83D")))
            .font(.spaceMono(8, weight: .bold)).tracking(1.5)
            .accessibilityLabel("Supernova")
    }
}
