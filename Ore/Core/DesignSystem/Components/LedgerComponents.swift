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
                        .font(.archivo(18))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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

/// Section label, Space Mono 9 / 1.5, muted, with the hairline under it (list pages and the More list).
struct MoreSectionLabel: View {
    let title: String
    var top: CGFloat = 22
    var bottom: CGFloat = 8
    var ruled = true

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
            .accessibilityAddTraits(.isHeader)
    }
}

/// The pressed state of a list row: the elevated surface.
struct OreRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Color.surf : Color.clear)
    }
}

/// A list row (More, Settings and every list page): title 16 bold and a › on the right, an optional description under both
/// (12, muted), an optional data value before the ›, a hairline below, the elevated surface while pressed. No icon box.
/// `toggle` puts an `OreToggleSwitch` where the › would be (the whole row toggles).
struct MoreRow: View {
    let label: String
    var description: String? = nil
    /// Data only (a count, a unit, ACTIVE): Space Mono 10, muted.
    var value: String = ""
    var destructive = false
    var chevron = true
    var minHeight: CGFloat = 44
    /// Small outlined tag before the value, e.g. "SUPERNOVA".
    var tag: String? = nil
    var toggle: Binding<Bool>? = nil
    /// Data only (Version, Email, Last synced…): drawn like a row but not a button.
    var isStatic = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: toggle == nil ? action : { toggle?.wrappedValue.toggle() }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 16) {
                    Text(label)
                        .font(.archivo(16, weight: .bold))
                        .foregroundStyle(destructive ? Color.signalDown : Color.inkPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 10) {
                        if let tag {
                            Text(tag).font(.spaceMono(7)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ruleStrong, lineWidth: 1))
                        }
                        if !value.isEmpty {
                            Text(value).font(.spaceMono(10)).tracking(0.8).foregroundStyle(Color.inkMuted).lineLimit(1)
                        }
                        if let toggle {
                            OreToggleSwitch(isOn: toggle.wrappedValue)
                        } else if chevron {
                            Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
                        }
                    }
                }
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.archivo(12))
                        .foregroundStyle(Color.inkMuted)
                        .cssLineHeight(fontName: "Archivo-Regular", size: 12, multiple: 1.4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 290, alignment: .leading)
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .frame(minHeight: minHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(OreRowPressStyle())
        .allowsHitTesting(!isStatic)
        .accessibilityIdentifier(AX.row(label))
        .accessibilityRemoveTraits(isStatic ? .isButton : [])
        .accessibilityValue(toggle.map { $0.wrappedValue ? "On" : "Off" } ?? "")
        .accessibilityAddTraits(toggle == nil ? [] : .isToggle)
    }
}

/// A row with a rounded-rectangle segmented control under its title (and description): track radius 8 on the sunken surface with
/// 3 pt padding; segments 30 pt tall, at least 64 wide, radius 6, Space Mono bold 9; the selected one is white in light and the
/// elevated surface in dark.
struct OreSegmentedRow<T: Hashable>: View {
    let label: String
    var description: String? = nil
    let options: [(label: String, value: T)]
    @Binding var selection: T
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
            if let description {
                Text(description).font(.archivo(12)).foregroundStyle(Color.inkMuted)
                    .cssLineHeight(fontName: "Archivo-Regular", size: 12, multiple: 1.4)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 280, alignment: .leading)
            }
            HStack(spacing: 2) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                    let on = o.value == selection
                    Button { if !on { selection = o.value; UISelectionFeedbackGenerator().selectionChanged() } } label: {
                        Text(o.label).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                            .foregroundStyle(on ? Color.inkPrimary : Color.inkMuted)
                            .padding(.horizontal, 12).frame(minWidth: 64).frame(height: 30)
                            .background(on ? (scheme == .dark ? Color.surf : Color.white) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier(AX.row(label + " " + o.label))
                }
            }
            .padding(3)
            .background(Color.surf2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 6)
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

/// The line under a page header: Archivo 13 / 1.45, secondary.
struct MorePageIntro: View {
    let text: String
    var body: some View {
        Text(text).font(.archivo(13)).foregroundStyle(Color.inkSecondary)
            .cssLineHeight(fontName: "Archivo-Regular", size: 13, multiple: 1.45)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 16)
    }
}

/// The primary button of a page (SAVE, SYNC NOW): 56 pt, radius 12, the accent, the label left and a › right; with Stardust on
/// when the member has it (`StardustMini` behind the content, 30 fps, mounted only while the page is on screen).
struct OrePageCTA: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                AccentFill(priority: 10, variant: "cta", density: 1600, gold: 0.4, sparkle: 0.55, fps: 30)
                HStack {
                    Text(title).font(.archivo(15, weight: .black)).tracking(1)
                    Spacer()
                    Text("›").font(.archivo(20))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 20)
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(PressOpacityButtonStyle())
        .disabled(disabled)
        .accessibilityIdentifier(AX.row(title))
    }
}

/// The docked area under a page's scrolling list that holds `OrePageCTA` (hairline above, 12 / 16 / 34).
struct OrePageFooter<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)   // the tab bar below carries the home-indicator space
            .frame(maxWidth: .infinity)
            .background(Color.canvasBg)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

/// The push used by the More list and by Settings: the page slides in from the right over 350 ms ease-in-out while the root moves
/// left 24 % underneath; closing reverses it. No spring.
struct OrePushStack<Root: View, Page: View>: View {
    var isOpen: Bool
    @ViewBuilder var root: Root
    @ViewBuilder var page: Page

    static var animation: Animation { .timingCurve(0.42, 0, 0.58, 1, duration: 0.35) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                root
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(x: isOpen ? -geo.size.width * 0.24 : 0)
                    .allowsHitTesting(!isOpen)
                    .accessibilityHidden(isOpen)
                if isOpen {
                    page
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(Color.canvasBg.ignoresSafeArea())
                        .transition(.move(edge: .trailing))
                        .zIndex(1)
                }
            }
            .clipped()
        }
        .animation(Self.animation, value: isOpen)
        // The canvas runs under the status bar and the home indicator (the GeometryReader above sits inside the safe area, so
        // without this the strip above the header shows the shell's black).
        .background(Color.canvasBg.ignoresSafeArea())
    }
}
