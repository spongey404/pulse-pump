import SwiftUI

/// The fill behind a Social primary action: flat accent, or the member's Stardust when they have Stardust buttons on
/// (`AccentStore.shared.stardustEnabled`). `variant` is "cta" for the 52 pt docked buttons and "toggle" for the small 32 pt actions
/// (JOIN, INVITE, ACCEPT), as the design's sdCta* / sdJoin do. The Stardust is mounted only while the view is on screen.
struct SocialStardustFill: View {
    var variant = "cta"
    @State private var visible = false

    var body: some View {
        ZStack {
            Color.oreAccent
            if AccentStore.shared.stardustEnabled && visible {
                StardustView(variant: variant, budget: .more,
                             overrides: StardustParams.Overrides(palette: AccentStore.shared.starPalette, density: variant == "cta" ? 1600 : 1200,
                                                                  gold: 0.4, sparkle: 0.55, fps: 30))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

/// A Social primary button, 52 pt, radius 12, Archivo 900 15: the title on the left, optional info (Space Mono 9) and a › on the
/// right, e.g. "DONE · 2 INVITED ›" or "RUN IT AGAIN · SAME METRIC · 4 WEEKS ›". Stardust for members with it on, flat accent otherwise.
/// Use `SocialDock` to dock it at the bottom of a screen.
struct SocialCTA: View {
    let title: String
    var info: String? = nil
    var disabled = false
    var id: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(.archivo(15, weight: .black)).tracking(1)
                Spacer(minLength: 8)
                if let info {
                    Text(info).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.white.opacity(0.92)).lineLimit(1)
                }
                Text("›").font(.archivo(20))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background { SocialStardustFill(variant: "cta") }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(PressOpacityButtonStyle())
        .disabled(disabled)
        .axID(id)
    }
}

/// The docked bar under a Social screen: hairline on top, canvas, padding 10 / 16 / `bottom`. The design's 30 includes the home
/// indicator; the app's tab bar below already carries that space, so the default is the footer's 14.
struct SocialDock<Content: View>: View {
    var bottom: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, bottom)
            .frame(maxWidth: .infinity)
            .background(Color.canvasBg)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

/// A small 32 pt action, radius 8, Space Mono 700 9: filled = primary (accent, or Stardust "toggle" for members), outlined = secondary.
struct SocialSmallAction: View {
    enum Style { case filled, outlined }
    let title: String
    var style: Style = .filled
    var isDisabled = false
    /// A status, not an action (FOLLOWING, FRIENDS): drawn like the button but does nothing and is not dimmed.
    var isStatic = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.spaceMono(9, weight: .bold)).tracking(1.5)
                .foregroundStyle(style == .filled ? Color.white : Color.inkMuted)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background { if style == .filled { SocialStardustFill(variant: "toggle") } }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if style == .outlined { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1) }
                }
                .opacity(isDisabled ? 0.5 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isStatic)
        .accessibilityIdentifier(AX.social.pill(title))
    }
}

/// The same 32 pt small action under the names the other Social screens grew (one component: Space Mono 700 9, radius 8).
typealias SocialPill = SocialSmallAction
typealias SocialSmallButton = SocialSmallAction
