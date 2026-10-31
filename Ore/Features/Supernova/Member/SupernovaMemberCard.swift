import SwiftUI

/// The member's card at the top of More (design "Supernova Member Flow"): it replaces the profile row. Stardust in the member's
/// accent behind white text; tapping it opens the membership page with the shared-element transition. It reports its frame and
/// its "*" to `SupernovaTransition`, hides the "*" while the flyer stands in for it, and brings its text back after the close.
struct SupernovaMemberCard: View {
    let name: String
    let username: String
    let program: String
    let service: SupernovaService
    @State private var transition = SupernovaTransition.shared
    @State private var frame: CGRect = .zero
    @State private var star: CGRect = .zero
    private var config: SupernovaMemberConfig { SupernovaMemberConfigStore.shared.current }

    var body: some View {
        let palette = AccentStore.shared.pickedPalette
        Button { transition.open(.member, fromSource: true) } label: {
            TimelineView(.animation(minimumInterval: nil, paused: !transition.isAnimating)) { tl in
                let text = transition.sourceText(.member, at: tl.date)
                VStack(alignment: .leading, spacing: config.card.gap) {
                    HStack(alignment: .top) {
                        HStack(spacing: 0) {
                            Text("SUPERNOVA").opacity(text[0].opacity).offset(y: text[0].offset)
                            // The flyer is an Archivo Black "*" scaled from 44 pt, so the card's is the same face (a Space Mono one
                            // is a different shape and sits lower, which showed as a jump when the flyer landed).
                            Text("*").font(.custom("Archivo-Black", size: Self.starSize)).foregroundStyle(Color(hex: "#FFC83D"))
                                .opacity(transition.sourceAsteriskHidden(.member) ? 0 : 1)
                                .transaction { $0.animation = nil }
                                .background(GeometryReader { p in Color.clear.onChange(of: p.frame(in: .global), initial: true) { _, f in star = f; report() } })
                            Text("\u{00A0}MEMBER · \(service.planWord)").opacity(text[0].opacity).offset(y: text[0].offset)
                        }
                        .font(.spaceMono(9, weight: .bold)).tracking(2)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1).fixedSize()
                        Spacer(minLength: 0)
                        Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                            .font(.archivo(20, weight: .black)).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(text[0].opacity).offset(y: text[0].offset)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).font(.archivo(22, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                            .cssLineHeight(fontName: "Archivo-Bold", size: 22, multiple: 1.1)
                        Text("@\(username.uppercased())" + (program.isEmpty ? "" : " · \(program)"))
                            .font(.spaceMono(10)).tracking(1.5).foregroundStyle(.white.opacity(0.92)).lineLimit(1)
                            .padding(.top, 6)
                    }
                    .opacity(text[1].opacity).offset(y: text[1].offset)
                    HStack(alignment: .bottom, spacing: 10) {
                        HStack(alignment: .top, spacing: 18) {
                            dateColumn("MEMBER SINCE", service.memberSinceShort)
                            dateColumn("RENEWS", service.renewsShort)
                        }
                        Spacer(minLength: 0)
                        Text("MEMBERSHIP ›").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(.white)
                    }
                    .opacity(text[2].opacity).offset(y: text[2].offset)
                }
            }
            .padding(.horizontal, config.card.padH).padding(.vertical, config.card.padV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Color(hex: palette.accent.hex)
                    StardustView(variant: "recapCard", budget: .more,
                                  overrides: StardustParams.Overrides(palette: palette, density: config.card.count, fps: config.card.fps))   // recoloured live, no remount
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: config.card.radius))
            .background(GeometryReader { p in Color.clear.onChange(of: p.frame(in: .global), initial: true) { _, f in frame = f; report() } })
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.supernova.memberCard)
        .accessibilityLabel("Supernova membership")
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    /// Font size of the card's "*"; the flyer lands at this size (`SupernovaTransition.Source.starHeight` is a font size here).
    private static let starSize: CGFloat = 11

    private func dateColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.spaceMono(7)).tracking(1.5).foregroundStyle(.white.opacity(0.8))
            Text(value).font(.spaceMono(12, weight: .bold)).foregroundStyle(.white)
        }
    }

    private func report() {
        guard frame != .zero, star != .zero else { return }
        transition.report(.member, rect: frame, asterisk: CGPoint(x: star.midX, y: star.midY), starHeight: Double(Self.starSize))
    }
}
