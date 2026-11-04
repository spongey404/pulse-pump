import SwiftUI

// MARK: - Custom tab bar  (matches design: raised accent home button, dots-style more)

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) private var scheme
    /// A workout (logger, rest timer) is running: the Home key's Stardust holds a still frame.
    var workoutActive = false

    private struct Tab {
        let tag: Int
        let label: String
        let icon: String
        let activeIcon: String
    }

    private static let ids = [AX.tab.programs, AX.tab.social, AX.tab.home, AX.tab.body, AX.tab.more]

    private let tabs: [Tab] = [
        Tab(tag: 0, label: "Programs", icon: "list.bullet.clipboard",       activeIcon: "list.bullet.clipboard.fill"),
        Tab(tag: 1, label: "Social",   icon: "person.2",                    activeIcon: "person.2.fill"),
        Tab(tag: 2, label: "Home",     icon: "house",                       activeIcon: "house.fill"),
        Tab(tag: 3, label: "Body",     icon: "figure.stand",                activeIcon: "figure.stand"),
        Tab(tag: 4, label: "More",     icon: "ellipsis",                    activeIcon: "ellipsis"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                if tab.tag == 2 {
                    homeTab(tab)
                } else {
                    regularTab(tab)
                }
            }
        }
        .frame(height: 56)
        .background(Color.canvasBg)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
        }
    }

    // MARK: - Home (raised, accent pill)

    private func homeTab(_ tab: Tab) -> some View {
        let active = selectedTab == tab.tag
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab.tag }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    let store = AccentStore.shared
                    let stardust = store.stardustEnabled
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.oreAccent)
                        .frame(width: 46, height: 46)
                        .overlay {
                            if stardust {
                                StardustView(variant: "homeKey", budget: .more,
                                             overrides: StardustParams.Overrides(palette: store.starPalette, gold: 0.40, sparkle: 0.55, goldPull: 0, fps: 30),
                                             frozen: workoutActive)
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                            }
                        }
                    Image(systemName: active ? tab.activeIcon : tab.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(stardust && Self.isLight(hex: store.active.hexString) ? Color(hex: "#151A21") : .white)
                }
                .offset(y: -10)

                // The key is always raised in the accent; only the SELECTED tab reads as highlighted, so the label is accent on Home
                // and muted everywhere else (it used to stay blue and make Home look selected on Programs).
                Text(tab.label.uppercased())
                    .font(.spaceMono(7, weight: active ? .bold : .regular))
                    .tracking(1)
                    .foregroundStyle(active ? Color.accentInk : Color.inkMuted)
                    .offset(y: -10)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Self.ids[tab.tag])
        .accessibilityLabel(tab.label)
    }

    // MARK: - Regular tab

    private func regularTab(_ tab: Tab) -> some View {
        let active = selectedTab == tab.tag
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab.tag }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: active ? tab.activeIcon : tab.icon)
                    .font(.system(size: 20, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color.inkPrimary : Color.inkMuted)
                    .frame(height: 26)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)

                Text(tab.label.uppercased())
                    .font(.spaceMono(7))
                    .tracking(1)
                    .foregroundStyle(active ? Color.inkPrimary : Color.inkMuted)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Self.ids[tab.tag])
        .accessibilityLabel(tab.label)
    }

    /// Light accents (relative luminance above 0.6) take the ink glyph instead of white.
    static func isLight(hex: String) -> Bool {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let v = Int(h, radix: 16) else { return false }
        func lin(_ c: Int) -> Double { let x = Double(c) / 255; return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        let l = 0.2126 * lin(v >> 16 & 255) + 0.7152 * lin(v >> 8 & 255) + 0.0722 * lin(v & 255)
        return l > 0.6
    }
}
