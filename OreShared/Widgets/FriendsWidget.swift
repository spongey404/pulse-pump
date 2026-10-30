import SwiftUI

// MARK: - 13 Friends  (Ore Widgets.dc.html · w12)

struct FriendsWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: OreWidgetSnapshot

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FRIENDS").pwCap()
                Spacer()
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { PWHair() }
            ForEach(Array(snap.fixed.friends.prefix(3).enumerated()), id: \.offset) { _, fr in
                HStack(spacing: 10) {
                    Text(fr.initials).pwMono(9, bold: true)
                        .frame(width: 28, height: 28)
                        .background(OreTheme.sunken, in: RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(fr.name + " · ").font(.archivo(13, weight: .semibold))
                         + Text(fr.workout).font(.archivo(13, weight: .regular)))
                            .foregroundStyle(OreTheme.ink).lineLimit(1)
                        Text(fr.meta).pwCap(8, tracking: 1.2).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(fr.ago).pwCap(8, tracking: 1.2)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { PWHair() }
            }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }
}

extension FriendsWidget {
    static let blurb = "Friends' latest sessions from the feed."
    static var gallery: [PWGalleryItem] {
        [PWGalleryItem("13 · MEDIUM", .medium) { AnyView(FriendsWidget(family: .medium, snap: $0)) }]
    }
}
