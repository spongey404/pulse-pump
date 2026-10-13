import SwiftUI

// MARK: - 14 Quick start  (Pump Widgets.dc.html · w12)
// Each tile is a Link that starts that template. First (predicted) tile is accent fill.

struct QuickStartWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var small: Bool { family == .small }

    var body: some View {
        let items = Array(snap.fixed.quickStarts.prefix(small ? 2 : 4).enumerated())
        Group {
            if small {
                VStack(alignment: .leading, spacing: 6) {
                    Text("QUICK START").pwCap()
                    ForEach(items, id: \.offset) { i, q in tile(q, first: i == 0) }
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { r in
                        HStack(spacing: 6) {
                            ForEach(items.filter { $0.offset / 2 == r }, id: \.offset) { i, q in tile(q, first: i == 0) }
                        }
                    }
                }
            }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    @ViewBuilder private func tile(_ q: PWQuickStart, first: Bool) -> some View {
        let fg: Color = first ? .white : PumpTheme.ink
        let content = HStack {
            VStack(alignment: .leading, spacing: small ? 2 : 3) {
                Text(q.name).font(.archivo(small ? 13 : 14, weight: .black)).tracking(0.3).foregroundStyle(fg).lineLimit(1)
                Text(q.meta).pwCap(8, tracking: 1.2, color: fg.opacity(0.7)).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("›").pwMono(14, color: fg)
        }
        .padding(.horizontal, small ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(first ? PumpTheme.accent : PumpTheme.sunken, in: RoundedRectangle(cornerRadius: 8))
        if let url = PumpWidgetSnapshot.startURL(template: q.name) {
            Link(destination: url) { content }
        } else {
            content
        }
    }
}

extension QuickStartWidget {
    static let blurb = "Tap a tile to start that template. The predicted session is first."
    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("14 · SMALL", .small) { AnyView(QuickStartWidget(family: .small, snap: $0)) },
            PWGalleryItem("14 · MEDIUM", .medium) { AnyView(QuickStartWidget(family: .medium, snap: $0)) },
        ]
    }
}
