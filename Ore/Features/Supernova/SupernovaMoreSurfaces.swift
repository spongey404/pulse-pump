import SwiftUI

// The Supernova surfaces on the More tab, from the Claude Design file `Supernova Final.dc.html`:
// the free user's "GO SUPERNOVA*" banner and the member's avatar, profile tag, row icon and Weekly Recap card.
// All glitter is `StarFieldView` configured by `starfield.config.json`; nothing here has its own numbers for it.

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

/// The free plan's banner. The glitter is the compact StarField, pulled toward the asterisk after "GO SUPERNOVA".
/// Tapping it opens the paywall with the shared-element transition (`SupernovaTransition`): this view reports its frame
/// and its asterisk's centre while the screen is at rest, hides the asterisk while the flyer stands in for it, and brings
/// its text back after the close.
struct SupernovaBanner: View {
    @State private var anchor: CGRect?
    @State private var frame: CGRect = .zero
    @State private var transition = SupernovaTransition.shared

    /// The banner's own colour (the palette's accent stop), shown until the first frame.
    private var base: Color {
        let c = StarFieldConfigStore.shared.current
        let p = StarPalette(c.palettes[c.defaultPalette] ?? StarFieldConfig.fallback.palettes["sky"]!)
        return Color(.sRGB, red: (p?.accent.r ?? 61) / 255, green: (p?.accent.g ?? 184) / 255, blue: (p?.accent.b ?? 255) / 255)
    }

    var body: some View {
        Button { transition.open(fromBanner: true) } label: {
            TimelineView(.animation(minimumInterval: nil, paused: !transition.isAnimating)) { tl in
                let text = transition.frame(at: tl.date).bannerText
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
                    StarFieldView(variant: "banner", budget: .more, anchor: anchor)
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

/// A member's glitter palette (derived from their accent) for the Mini fields.
private func memberOverrides() -> StarFieldParams.Overrides {
    StarFieldParams.Overrides(palette: AccentStore.shared.starPalette)
}

/// The member's avatar tile: their accent with glitter behind the initial.
struct MemberAvatar: View {
    let name: String
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            AccentStore.shared.accent
            StarFieldView(variant: "avatar", budget: .more, overrides: memberOverrides())
            Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                .font(.archivo(size * 20 / 48, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 4))
    }
}

/// "SUPERNOVA*" beside the member's handle: 20pt tall, accent with its own small glitter pulled toward the asterisk.
struct MemberProfileTag: View {
    @State private var anchor: CGRect?

    var body: some View {
        SupernovaWordmark(size: 9, face: .mono(bold: true), tracking: 1.2)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background {
                ZStack {
                    AccentStore.shared.accent
                    StarFieldView(variant: "tag", budget: .more, overrides: memberOverrides(), anchor: anchor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onPreferenceChange(SupernovaAsteriskFrameKey.self) { anchor = $0 }
    }
}

/// The member's Supernova row icon: accent tile, glitter, a white bolt.
struct SupernovaRowIcon: View {
    var body: some View {
        ZStack {
            AccentStore.shared.accent
            StarFieldView(variant: "rowIcon", budget: .more, overrides: memberOverrides())
            Image(systemName: "bolt").font(.system(size: 14, weight: .regular)).foregroundStyle(.white)
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// The member's Weekly Recap card: glitter under the whole card, white header and footer on it, and the numbers on a panel that runs
/// edge to edge and fades in and out vertically.
struct MemberRecapCard: View {
    let stats: WeeklyRecapStats
    var action: () -> Void

    /// Light `#FFFFFF`; dark, the canvas mixed 2% toward white (design tokens, no catalogue entry).
    private static let panel = Color(light: "#FFFFFF", dark: "#1E1D1B")

    private var rangeLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let last = stats.calendar.date(byAdding: .day, value: 6, to: stats.weekStart)!
        return "WK \(stats.weekNumber) · \(f.string(from: stats.weekStart).uppercased())–\(f.string(from: last).uppercased())"
    }
    private var nextMonday: String {
        let next = stats.calendar.date(byAdding: .day, value: 7, to: stats.weekStart)!
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: next).uppercased()
    }
    private var volumeDelta: (text: String, up: Bool)? {
        let now = stats.volumeTonnes(stats.week), before = stats.volumeTonnes(stats.prev)
        guard before > 0 else { return nil }
        let pct = (now - before) / before * 100
        return ((pct >= 0 ? "+" : "") + String(format: "%.1f%%", pct), pct >= 0)
    }
    private func tonnes(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    var body: some View {
        let volume = stats.volumeTonnes(stats.week)
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("WEEKLY RECAP").font(.archivo(14, weight: .bold)).tracking(0.5).foregroundStyle(.white)
                    Spacer()
                    Text(rangeLabel).font(.spaceMono(9)).tracking(0.8).foregroundStyle(.white.opacity(0.88))
                }
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        KPIBlock(label: "SESSIONS", value: "\(stats.week.count)/\(stats.target)")
                        KPIBlock(label: "VOLUME \(stats.unit == .kg ? "T" : "K")", value: tonnes(volume),
                                 delta: volumeDelta?.text, deltaColor: (volumeDelta?.up ?? true) ? .signalUp : .signalDown)
                        KPIBlock(label: "PRS", value: "\(stats.records.count)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                    WeekBars(data: stats.bars.map(\.value), done: stats.bars.map(\.done), today: todayIndex, height: 32)
                        .padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 8)
                }
                .background {
                    Self.panel
                        .padding(.vertical, -13)
                        .mask(EasedEdgeFade().padding(.vertical, -13))
                }

                HStack {
                    Text("NEXT · \(nextMonday)").font(.spaceMono(9)).tracking(1).foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text("OPEN RECAP ›").font(.spaceMono(9, weight: .bold)).tracking(1).foregroundStyle(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .background {
                ZStack {
                    AccentStore.shared.accent
                    StarFieldView(variant: "recapCard", budget: .more, overrides: memberOverrides())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var todayIndex: Int {
        guard stats.weeksBack == 0 else { return -1 }
        let d = stats.calendar.dateComponents([.day], from: stats.weekStart, to: stats.now).day ?? -1
        return (0..<7).contains(d) ? d : -1
    }
}
