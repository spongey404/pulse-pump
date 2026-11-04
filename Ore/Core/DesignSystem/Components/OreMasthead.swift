import SwiftUI

/// The masthead shared by Home and Body (Ore Home Final / Ore Body Final): the accent square and "ORE" on the left, whatever the screen
/// needs on the right. The ticker strip sits directly under it.
struct OreMasthead<Trailing: View>: View {
    var markID: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Rectangle().fill(Color.oreAccent).frame(width: 14, height: 14)
                Text("ORE").font(.spaceMono(10, weight: .bold)).tracking(2).foregroundStyle(Color.inkPrimary)
                    .accessibilityIdentifier(markID ?? "ore.mark")
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 10)
    }
}
