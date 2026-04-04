import SwiftUI

struct PulsePlusUpsellBanner: View {
    let feature: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(Color.pumpPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            NavigationLink {
                PulsePlusView()
            } label: {
                Text("Unlock")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.pumpPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Blurred overlay paywall for premium content
struct PulsePlusBlurOverlay: View {
    let feature: String

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.8)
                .blur(radius: 3)

            VStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.pumpPrimary)

                Text("Unlock with Pulse+")
                    .font(.headline)

                Text(feature)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    PulsePlusView()
                } label: {
                    Text("Learn More")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.pumpPrimary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
