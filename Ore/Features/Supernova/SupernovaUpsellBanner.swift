import SwiftUI

struct SupernovaUpsellBanner: View {
    let feature: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.display(20))
                .foregroundStyle(Color.accentInk)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature)
                    .font(.spaceMono(14, weight: .bold))
                Text(description)
                    .font(.archivo(11))
                    .foregroundStyle(Color.inkMuted)
            }

            Spacer()

            NavigationLink {
                SupernovaView()
            } label: {
                Text("UNLOCK")
                    .font(.spaceMono(11, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background { AccentFill() }
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Blurred overlay paywall for premium content
struct SupernovaBlurOverlay: View {
    let feature: String

    var body: some View {
        ZStack {
            Color.canvasBg.opacity(0.85)
                .blur(radius: 3)

            VStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.display(34))
                    .foregroundStyle(Color.accentInk)

                SupernovaWordmark(size: 16, face: .mono(bold: true), tracking: 1, color: Color.inkPrimary, prefix: "UNLOCK WITH ")

                Text(feature)
                    .font(.archivo(14))
                    .foregroundStyle(Color.inkMuted)

                NavigationLink {
                    SupernovaView()
                } label: {
                    Text("LEARN MORE")
                        .font(.spaceMono(14, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background { AccentFill() }
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
