import SwiftUI

// MARK: - 17 Locked preview  (Ore Widgets.dc.html · w17)
// What a free user sees after adding a Plus widget: the widget's shape at 0.18 opacity,
// one line of fact, one action (opens the Supernova sheet).

enum LockedKind {
    case bodyMap, prWatch, balance, deload

    var title: String {
        switch self {
        case .bodyMap: "Muscle heatmap"
        case .prWatch: "PR watch"
        case .balance: "Muscle balance"
        case .deload: "Deload and recovery"
        }
    }
    var fact: String {
        switch self {
        case .bodyMap: "Which muscles are fresh and which are neglected."
        case .prWatch: "Lifts close to a record, with estimated 1RM trend."
        case .balance: "Push vs pull over 4 weeks."
        case .deload: "Weekly load and when to back off."
        }
    }
}

struct LockedWidgetPreview: View {
    let family: PWFamily
    let snap: OreWidgetSnapshot
    var kind: LockedKind? = nil

    private var resolved: LockedKind { kind ?? (family == .small ? .bodyMap : .prWatch) }
    private static let url = URL(string: "\(Brand.urlScheme)://supernova")!

    var body: some View {
        Group {
            if family == .small { small } else { medium }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock").font(.system(size: 10, weight: .semibold)).foregroundStyle(OreTheme.ink)
                .frame(width: 12, height: 12)
            Text("SUPERNOVA").pwCap()
        }
    }

    private func unlock(_ size: CGFloat) -> some View {
        Link(destination: Self.url) {
            Text("UNLOCK SUPERNOVA").font(.archivo(size, weight: .black)).tracking(0.5).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(OreTheme.accent, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Text(resolved.title).pwBody(14).frame(maxWidth: 90, alignment: .leading).padding(.top, 8)
            Spacer(minLength: 0)
            unlock(11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            BodyHeat(intensities: .init(chest: 0.9, shoulders: 0.7, biceps: 0.8, core: 0.3))
                .frame(width: 64, height: 110)
                .opacity(0.18)
                .offset(x: 4, y: -4)   // 10pt from edge inside 14pt padding
                .allowsHitTesting(false)
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Text(resolved.title).pwDisplay(18, tracking: 0).padding(.top, 8).lineLimit(2)
                Text(resolved.fact).pwBody(12, weight: .regular, color: OreTheme.secondary).lineSpacing(2).padding(.top, 4)
                Spacer(minLength: 0)
                unlock(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ghostRows.frame(width: 150).opacity(0.18).allowsHitTesting(false)
        }
    }

    private var ghostRows: some View {
        let lifts = Array(snap.fixed.prLifts.prefix(3))
        let series: [[Double]] = lifts.isEmpty
            ? [[1, 2, 2, 3], [1, 1, 2, 3], [2, 2, 3, 4]] : lifts.map(\.series)
        return VStack(spacing: 0) {
            ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                HStack {
                    RoundedRectangle(cornerRadius: 2).fill(OreTheme.ink).frame(width: 64, height: 8)
                    Spacer(minLength: 0)
                    PWSpark(values: s).frame(width: 56, height: 16)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { Rectangle().fill(OreTheme.ink).frame(height: 1) }
            }
        }
    }
}

/// Shows `content` for Plus subscribers, otherwise the locked preview for `locked`.
struct PWPlusGate<Content: View>: View {
    let family: PWFamily
    let snap: OreWidgetSnapshot
    let locked: LockedKind
    @ViewBuilder var content: () -> Content

    init(family: PWFamily, snap: OreWidgetSnapshot, locked: LockedKind, @ViewBuilder content: @escaping () -> Content) {
        self.family = family; self.snap = snap; self.locked = locked; self.content = content
    }

    var body: some View {
        if snap.fixed.isPlus { content() } else { LockedWidgetPreview(family: family, snap: snap, kind: locked) }
    }
}

enum LockedPreviews {
    static let blurb = "What a free user sees after adding a Plus widget. The widget's shape at 0.18 opacity, one line of fact, one action. Tap opens the Supernova sheet."

    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("17 · SMALL", .small) { AnyView(LockedWidgetPreview(family: .small, snap: $0)) },
            PWGalleryItem("17 · MEDIUM", .medium) { AnyView(LockedWidgetPreview(family: .medium, snap: $0)) },
        ]
    }
}
