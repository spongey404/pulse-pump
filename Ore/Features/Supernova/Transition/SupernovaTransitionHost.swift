import SwiftUI

/// What the paywall's six content groups show right now (header label, wordmark, subhead, feature list, CTA block, free
/// strip): opacity and a downward offset, from the transition's clock. Empty = everything shown.
private struct PaywallRevealKey: EnvironmentKey { static let defaultValue: [SupernovaTransitionFrame.Piece] = [] }
/// The banner-look morph the paywall's star field draws while it closes.
private struct StarFieldMorphKey: EnvironmentKey { static let defaultValue: SupernovaTransitionFrame.Morph? = nil }

extension EnvironmentValues {
    var paywallReveal: [SupernovaTransitionFrame.Piece] {
        get { self[PaywallRevealKey.self] }
        set { self[PaywallRevealKey.self] = newValue }
    }
    var starFieldMorph: SupernovaTransitionFrame.Morph? {
        get { self[StarFieldMorphKey.self] }
        set { self[StarFieldMorphKey.self] = newValue }
    }
}

extension View {
    /// Content group `i` of the paywall, driven by the transition.
    func paywallGroup(_ i: Int, _ reveal: [SupernovaTransitionFrame.Piece]) -> some View {
        let p = reveal.indices.contains(i) ? reveal[i] : .init(opacity: 1, offset: 0)
        return opacity(p.opacity).offset(y: p.offset)
    }
}

/// A rounded rectangle at a given rect of the host: the paywall's mask (the banner's rect grows to the screen and back).
struct SupernovaMaskShape: Shape {
    var rect: CGRect
    var radius: Double
    func path(in _: CGRect) -> Path { Path(roundedRect: rect, cornerRadius: radius, style: .continuous) }
}

/// The gold "*" that flies between the banner and the wordmark. Rendered at the large size and scaled down, never a
/// small glyph scaled up (that blurs and jitters). Same face and size as the real asterisks, so the swap is invisible.
struct SupernovaFlyer: View {
    let flyer: SupernovaTransitionFrame.Flyer
    let config: SupernovaTransitionConfig.Flyer

    var body: some View {
        let font = Font.custom("Archivo-Black", size: config.glyphSize)
        let gold = Color(hex: config.colorHex)
        ZStack {
            Text(SupernovaAsterisk.glyph).font(font).foregroundStyle(gold).blur(radius: config.glowRadius).opacity(config.glowAlpha)
            Text(SupernovaAsterisk.glyph).font(font).foregroundStyle(gold)
        }
        .fixedSize()
        .scaleEffect(flyer.scale)
        .position(flyer.center)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Wraps the app shell: pushes it back while the paywall is open (the More layer) and draws the paywall, its mask and the
/// flyer above everything.
struct SupernovaTransitionHost<Content: View>: View {
    var onSubscribed: () -> Void = {}
    @ViewBuilder var content: Content
    @State private var transition = SupernovaTransition.shared

    var body: some View {
        let c = transition.config
        let pushed = hubProgress
        let hub = SupernovaTransitionMath.hub(progress: pushed, config: c)
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .scaleEffect(hub.scale)
                .opacity(hub.opacity)
                .clipShape(RoundedRectangle(cornerRadius: pushed > 0 ? c.hubCornerRadius : 0, style: .continuous))
                .allowsHitTesting(!transition.isBusy)
                .accessibilityHidden(transition.isPresented)   // VoiceOver stays on the paywall, not the page behind it
            if transition.isPresented { overlay }
        }
        .onAppear { transition.screen = UIScreen.main.bounds }
    }

    /// How far the More layer is pushed back (0 at rest, 1 fully).
    private var hubProgress: Double {
        #if DEBUG
        if let o = transition.hubProgressOverride { return o }
        #endif
        return transition.hubPushed ? 1 : 0
    }

    private var overlay: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !transition.isAnimating && !transition.fadingOut)) { tl in
            let f = transition.frame(at: tl.date)
            let opacity = f.paywallOpacity * (transition.fadingOut ? transition.fadeOutOpacity(at: tl.date) : 1)
            // The paywall keeps the real safe areas (its content sits below the status bar); the mask and the flyer are in
            // screen coordinates, so they are moved by where this view starts.
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                ZStack {
                    SupernovaPaywallView(
                        context: .more,
                        onSubscribed: { transition.close(crossfade: true) { onSubscribed() } },
                        onTrainFree: { transition.close() })
                        .environment(\.paywallReveal, f.groups)
                        .environment(\.starFieldMorph, f.morph)
                        .clipShape(SupernovaMaskShape(rect: f.maskRect.offsetBy(dx: -origin.x, dy: -origin.y), radius: f.maskRadius))
                        .opacity(opacity)
                        .allowsHitTesting(transition.acceptsInput)
                    if var fl = f.flyer, transition.isShared {
                        let _ = { fl.center = CGPoint(x: fl.center.x - origin.x, y: fl.center.y - origin.y) }()
                        SupernovaFlyer(flyer: fl, config: transition.config.flyer)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}
