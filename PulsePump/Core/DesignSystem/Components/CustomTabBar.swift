import SwiftUI

// MARK: - Custom tab bar  (matches design: raised accent home button, dots-style more)

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) private var scheme

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
        .background(.regularMaterial)
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
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.pumpAccent)
                        .frame(width: 46, height: 46)
                    Image(systemName: active ? tab.activeIcon : tab.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: -10)

                Text(tab.label.uppercased())
                    .font(.spaceMono(7, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.accentInk)
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
}
