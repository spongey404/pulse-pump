import SwiftUI

// The Supernova surfaces on the More tab, from the Claude Design file `Supernova Final.dc.html`:
// the free user's "GO SUPERNOVA*" banner and the member's avatar, profile tag, row icon and Weekly Recap card.
// All Stardust is `StardustView` configured by `stardust.config.json`; nothing here has its own numbers for it.

/// A vertical fade over the first and last `edge` points, eased the way the design's mask is (not a straight ramp).
struct EasedEdgeFade: View {
    var edge: CGFloat = 22
    /// (distance in pt from the edge, opacity), from the design's mask-image.
    private static let ramp: [(CGFloat, Double)] = [(0, 0), (3, 0.05), (6, 0.16), (9, 0.34), (12, 0.56), (15, 0.77), (18, 0.92), (22, 1)]

    var body: some View {
        GeometryReader { geo in
            let h = max(geo.size.height, 1)
            let top = Self.ramp.map { Gradient.Stop(color: .black.opacity($0.1), location: min(0.5, $0.0 / h)) }
            let bottom = Self.ramp.reversed().map { Gradient.Stop(color: .black.opacity($0.1), location: max(0.5, 1 - $0.0 / h)) }
            LinearGradient(stops: top + bottom, startPoint: .top, endPoint: .bottom)
        }
    }
}

/// The free plan's banner. The Stardust is the compact Stardust, pulled toward the asterisk after "GO SUPERNOVA".
/// Tapping it opens the paywall with the shared-element transition (`SupernovaTransition`): this view reports its frame
/// and its asterisk's centre while the screen is at rest, hides the asterisk while the flyer stands in for it, and brings
/// its text back after the close.
struct SupernovaBanner: View {
    @State private var anchor: CGRect?
    @State private var frame: CGRect = .zero
    @State private var transition = SupernovaTransition.shared

    /// The banner's own colour (the palette's accent stop), shown until the first frame.
    private var base: Color {
        let c = StardustConfigStore.shared.current
        let p = StarPalette(c.palettes[c.defaultPalette] ?? StardustConfig.fallback.palettes["sky"]!)
        return Color(.sRGB, red: (p?.accent.r ?? 61) / 255, green: (p?.accent.g ?? 184) / 255, blue: (p?.accent.b ?? 255) / 255)
    }

    var body: some View {
        Button { transition.open(fromBanner: true) } label: {
            TimelineView(.animation(minimumInterval: nil, paused: !transition.isAnimating)) { tl in
                let text = transition.sourceText(.paywall, at: tl.date)
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.18))
                        .frame(width: 36, height: 36)
                        .overlay { Image(systemName: "bolt").font(.system(size: 18, weight: .regular)).foregroundStyle(.white) }
                        .opacity(text[0].opacity).offset(y: text[0].offset)
                    VStack(alignment: .leading, spacing: 2) {
                        SupernovaWordmark(size: 18, tracking: 0.6, prefix: "GO ", nameOpacity: text[1].opacity,
                                          nameOffsetY: text[1].offset, asteriskHidden: transition.bannerAsteriskHidden)
                        Text("SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS")
                            .font(.spaceMono(9))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .opacity(text[2].opacity).offset(y: text[2].offset)
                    }
                    Spacer(minLength: 0)
                    Text("›").font(.spaceMono(16, weight: .bold)).foregroundStyle(.white)
                        .opacity(text[3].opacity).offset(y: text[3].offset)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background {
                ZStack {
                    base
                    StardustView(variant: "banner", budget: .more, anchor: anchor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(GeometryReader { p in
                Color.clear.onChange(of: p.frame(in: .global), initial: true) { _, f in frame = f; report() }
            })
            .onPreferenceChange(SupernovaAsteriskFrameKey.self) { anchor = $0; report() }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.supernova.banner)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private func report() {
        guard frame != .zero else { return }
        transition.reportBanner(rect: frame, asterisk: anchor.map { CGPoint(x: $0.midX, y: $0.midY) })
    }
}
