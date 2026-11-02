import SwiftUI

/// One large figure, centred, plus a small tile in the bottom-right corner showing the other side (FRONT / BACK, tap to swap).
/// Rule: a side appears only if a muscle on it was trained, so with one trained side there is no tile and no flip to an empty figure.
/// The load animation plays when the view first appears and when the tile swaps the view, never on a tap of the figure.
struct BodyMapSwapView: View {
    var levels: [String: Double]
    var member = false
    var accentHex: String? = nil
    /// Tile size from the design (86 × 124).
    var tileSize = CGSize(width: SocialConfigStore.shared.current.card.swapTileWidth, height: SocialConfigStore.shared.current.card.swapTileHeight)
    /// Space above and below the figure inside the view.
    var figureInset: CGFloat = 8
    var onSwap: (() -> Void)? = nil

    @State private var side: BodyMapSide?
    @State private var replay = 0

    private var sides: [BodyMapSide] { BodyMapLevels.trainedSides(levels) }
    private var shown: BodyMapSide { side.flatMap { sides.contains($0) ? $0 : nil } ?? sides.first ?? .front }
    private var other: BodyMapSide? { sides.count == 2 ? (shown == .front ? .back : .front) : nil }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if !sides.isEmpty {
                BodyFigureView(side: shown, levels: levels, member: member, accentHex: accentHex, replay: replay)
                    .padding(.vertical, figureInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)          // centred, whatever the tile does
                    .id(shown)
                    .accessibilityIdentifier(shown == .front ? AX.body.figureFront : AX.body.figureBack)
            }
            if let other {
                Button {
                    side = other
                    replay += 1
                    onSwap?()
                } label: {
                    VStack(spacing: 0) {
                        BodyFigureView(side: other, levels: levels, member: false, accentHex: accentHex, replay: replay)
                            .padding(.top, 6).frame(maxHeight: .infinity)
                        Text(other.rawValue.uppercased()).font(.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .padding(.top, 3).padding(.bottom, 5)
                    }
                    .frame(width: tileSize.width, height: tileSize.height)
                    .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10).padding(.bottom, 12)
                .accessibilityLabel("Show \(other.rawValue)")
                .accessibilityIdentifier("bodymap.swap")
            }
        }
    }
}
