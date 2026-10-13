import SwiftUI

/// Section header used throughout the Social redesign. Matches the design system's
/// `SectionLabel` component exactly: title is Space Mono 9px/1.5px-tracked/uppercase,
/// `--text-muted` by default — `accent` switches it to `--accent-text`. `meta` (an optional
/// trailing value, e.g. "3 ACTIVE") is always muted, never a link — accent-coloured
/// tappable rows like "VIEW LEADERBOARD ›" or "+ INVITE" are separate elements below a
/// plain SectionLabel in the mockups, not part of this component.
struct SectionLabel: View {
    let title: String
    var meta: String? = nil
    var accent: Bool = false

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.spaceMono(9))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(accent ? Color.accentInk : Color.inkMuted)
            Spacer(minLength: 12)
            if let meta {
                Text(meta)
                    .font(.spaceMono(9))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        SectionLabel(title: "Tag Friends", meta: "Friends Only ›")
        SectionLabel(title: "Friend Challenges", meta: "3 Active")
        SectionLabel(title: "Following")
    }
    .padding()
}
