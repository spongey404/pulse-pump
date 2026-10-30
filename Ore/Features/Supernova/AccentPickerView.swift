import SwiftUI

/// Supernova members choose the accent colour the whole app draws with (More › Accent colour). Ore's own blue is the first
/// choice, so it can always be put back. Everyone else keeps Ore's accent.
struct AccentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    private var store: AccentStore { AccentStore.shared }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ACCENT COLOUR")
                    .font(.spaceMono(10, weight: .bold)).tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                Spacer()
                Button("DONE") { dismiss() }
                    .font(.spaceMono(10, weight: .bold)).tracking(1.5)
                    .foregroundStyle(Color.accentInk)
            }
            .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 12)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(AccentChoices.all) { choice in swatch(choice) }
                }
                .padding(16)
                Text("Used for buttons, highlights and charts across the app. Your glitter follows it too.")
                    .font(.archivo(12))
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func swatch(_ choice: AccentChoice) -> some View {
        let selected = store.picked == choice
        let color = Color(hex: choice.hex)
        return Button { store.select(choice) } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(height: 56)
                    .overlay {
                        if selected { Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white) }
                    }
                Text(choice.name.uppercased())
                    .font(.spaceMono(9, weight: selected ? .bold : .regular)).tracking(1)
                    .foregroundStyle(selected ? Color.inkPrimary : Color.inkMuted)
            }
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? color : Color.dsHairLine, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.supernova.accentSwatch(choice.name))
        .accessibilityLabel(choice.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
