import SwiftUI

/// Docked primary button of the post screens: 60 pt, radius 12, label LEFT-aligned (Archivo 900 19) with › at the right.
struct DockedPrimaryButton: View {
    let title: String
    var disabled = false
    var id: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.archivo(19, weight: .black)).tracking(0.5)
                Spacer()
                Text("›").font(.archivo(24))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 60).frame(maxWidth: .infinity)
            .background { AccentFill() }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(PressOpacityButtonStyle())
        .disabled(disabled)
        .axID(id)
    }
}

/// A single-choice segmented control: 8 pt rounded rectangle (pills are for filter chips only).
struct SegmentedChoice<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                let on = o.value == selection
                Button { selection = o.value } label: {
                    Text(o.label).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                        .foregroundStyle(on ? Color.inkPrimary : Color.inkMuted)
                        .padding(.horizontal, 12).frame(minWidth: 64, minHeight: 30)
                        .background(on ? (scheme == .dark ? Color.surf : Color.white) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier(AX.row(o.label))
            }
        }
        .padding(3)
        .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Small caps label over a section (Space Mono 9, muted).
struct ComposerLabel: View {
    let text: String
    var body: some View { Text(text).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted) }
}

/// A friend chip with a ×: tagged friends above the search field (pills are for multi-select chips).
struct TaggedChip: View {
    let name: String
    let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            Text(name.prefix(1).uppercased()).font(.archivo(10, weight: .black)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Color.oreAccent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(name).font(.archivo(13, weight: .semibold)).foregroundStyle(Color.inkPrimary)
            Button(action: onRemove) {
                Text("×").font(.archivo(16)).foregroundStyle(Color.inkMuted).frame(width: 24, height: 28)
            }
            .buttonStyle(.plain).accessibilityLabel("Remove \(name)")
        }
        .padding(.leading, 6).padding(.trailing, 2).frame(height: 32)
        .background(Capsule().fill(Color.surf2))
    }
}
