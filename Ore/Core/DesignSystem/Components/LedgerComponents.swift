import SwiftUI

// Shared building blocks for the More tab and its sub-screens
// (design: More Hub.dc.html / More Screens.dc.html).

/// `--text-ghost` — chevrons and inactive glyphs.
extension Color {
    static var inkGhost: Color { Color.inkPrimary.opacity(0.15) }
}

/// Sub-screen header: 36pt sunken back button, Archivo 900 title, optional trailing content.
struct MoreScreenHeader<Trailing: View>: View {
    let title: String
    var overline: String? = nil
    var titleSize: CGFloat = 24
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("‹")
                        .font(.spaceMono(18))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier(AX.nav.back)

                VStack(alignment: .leading, spacing: 4) {
                    if let overline {
                        Text(overline)
                            .font(.spaceMono(8))
                            .tracking(1.5)
                            .foregroundStyle(Color.inkMuted)
                    }
                    Text(title)
                        .font(.archivo(titleSize, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityIdentifier(AX.nav.title(title))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.canvasBg)
    }
}

extension MoreScreenHeader where Trailing == EmptyView {
    init(title: String, overline: String? = nil, titleSize: CGFloat = 24, onBack: @escaping () -> Void) {
        self.init(title: title, overline: overline, titleSize: titleSize, onBack: onBack) { EmptyView() }
    }
}

/// Space Mono 9 / 1.5 tracked section label.
struct MoreSectionLabel: View {
    let title: String
    var top: CGFloat = 14
    var bottom: CGFloat = 4
    var ruled = false

    var body: some View {
        Text(title)
            .font(.spaceMono(9))
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, top)
            .padding(.bottom, bottom)
            .overlay(alignment: .bottom) {
                if ruled { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
    }
}

/// Ledger row: 32pt icon tile, label, optional mono value, optional toggle / chevron.
struct MoreRow: View {
    let icon: String
    let label: String
    var value: String = ""
    var destructive = false
    var chevron = true
    var minHeight: CGFloat = 52
    /// Small outlined tag before the value, e.g. "SUPERNOVA".
    var tag: String? = nil
    var toggle: Binding<Bool>? = nil
    var action: () -> Void = {}

    var body: some View {
        let fg: Color = destructive ? .signalDown : .inkPrimary
        Button(action: toggle == nil ? action : { toggle?.wrappedValue.toggle() }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(destructive ? Color.signalDown.opacity(0.10) : Color.surf2)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(destructive ? Color.signalDown : Color.inkMuted)
                    }
                HStack(spacing: 10) {
                    Text(label)
                        .font(.archivo(14, weight: .semibold))
                        .foregroundStyle(fg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let tag {
                        Text(tag).font(.spaceMono(7)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ruleStrong, lineWidth: 1))
                    }
                    if !value.isEmpty {
                        Text(value)
                            .font(.spaceMono(10))
                            .tracking(0.8)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
                    if let toggle {
                        MoreToggle(isOn: toggle.wrappedValue)
                    } else if chevron {
                        Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
                    }
                }
                .frame(minHeight: minHeight)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                }
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.row(label))
    }
}

/// 44×26 pill toggle drawn to spec (accent when on, deep surface when off).
struct MoreToggle: View {
    let isOn: Bool
    var body: some View {
        Capsule()
            .fill(isOn ? Color.oreAccent : Color.inkPrimary.opacity(0.18))
            .frame(width: 44, height: 26)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 22, height: 22).padding(2)
            }
            .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

/// Ledger row whose trailing value is a menu picker (Settings option rows).
struct MoreMenuRow<T: Hashable>: View {
    let icon: String
    let label: String
    @Binding var selection: T
    let options: [T]
    let title: (T) -> String

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.self) { Text(title($0)).tag($0) }
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.surf2)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkMuted)
                    }
                HStack(spacing: 10) {
                    Text(label)
                        .font(.archivo(14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(title(selection).uppercased())
                        .font(.spaceMono(10))
                        .tracking(0.8)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                    Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
                }
                .frame(minHeight: 52)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                }
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.menu(label))
    }
}
