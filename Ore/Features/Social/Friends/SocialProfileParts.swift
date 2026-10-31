import SwiftUI

// Pieces shared by the three people screens (friend profile, your profile, add friends), from the design "Ore Social Final" 5a-5c.

// MARK: Who is a Supernova member

/// Whether a friend is a Supernova member and what their accent is.
///
/// There is NO such field today: `FirestoreUserProfile` (and `users/{uid}` in Firestore) carries no membership or accent, and
/// the rules only let a user write their own profile. So the default source says "nobody", and the Stardust body map and the
/// SUPERNOVA* tag on other people stay off until the data exists. To turn them on, publish on `users/{uid}`
/// `supernova: Bool` and `accentHex: String` (e.g. "#FD4A9F"), decode them in `FirestoreUserProfile`, and replace
/// `FriendMembership.source` with one that reads them. Nothing else in the screens has to change.
protocol FriendMembershipSource {
    /// The member's accent as `#RRGGBB`, or nil when this person is not a member (or it is not known).
    func accentHex(forUid uid: String) -> String?
}

struct NoMembershipData: FriendMembershipSource {
    func accentHex(forUid uid: String) -> String? { nil }
}

enum FriendMembership {
    static var source: FriendMembershipSource = NoMembershipData()

    static func accentHex(forUid uid: String) -> String? { source.accentHex(forUid: uid) }

    /// The Stardust palette for a member's accent.
    static func palette(hex: String) -> StarPalette? {
        guard let c = AccentMath.hsl(fromHex: hex) else { return nil }
        let pick = AccentPick(h: c.h, s: c.s, l: c.l, hex: AccentMath.normalizeHex(hex))
        return AccentMath.palette(for: pick, rule: SupernovaMemberConfigStore.shared.current.picker.palette)
    }
}

// MARK: Buttons

// MARK: Tiles, tags, headers

/// The rounded-square initial: 36 pt in lists, 64 pt on a profile. A member's tile is filled with their accent, everyone else's
/// is sunken with secondary text.
struct PersonTile: View {
    let name: String
    var size: CGFloat = 36
    /// `#RRGGBB` of a member's accent (or your own); nil = the plain sunken tile.
    var accentHex: String?
    /// Your own tile: the app's accent.
    var isMe = false

    var body: some View {
        let filled = isMe || accentHex != nil
        RoundedRectangle(cornerRadius: size == 64 ? 18 : 10, style: .continuous)
            .fill(isMe ? Color.oreAccent : (accentHex.map { Color(hex: $0) } ?? Color.surf2))
            .frame(width: size, height: size)
            .overlay {
                Text(name.prefix(1).uppercased())
                    .font(.archivo(size == 64 ? 27 : 15, weight: .black))
                    .foregroundStyle(filled ? Color.white : Color.inkSecondary)
            }
            .accessibilityHidden(true)
    }
}

/// Page header from the design: overline, big title, a 36 pt sunken square at the right; back arrow before it as on the other
/// pushed screens.
struct SocialProfileHeader<Trailing: View>: View {
    var overline: String
    var title: String
    var onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    if !overline.isEmpty {
                        Text(overline).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
                    }
                    if !title.isEmpty {
                        Text(title).font(.archivo(26, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.top, 4)
                            .accessibilityIdentifier(AX.nav.title(title))
                    }
                }
                Spacer(minLength: 0)
                trailing()
                // The design draws no back arrow (it is shown as a modal); this one is the 36 pt sunken square next to the action.
                Button(action: onBack) {
                    Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36).background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier(AX.nav.back)
            }
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .textCase(.uppercase)
    }
}

/// The sunken 36 pt header button (EDIT, ···).
struct HeaderSquareLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.spaceMono(9, weight: .bold)).tracking(1.5)
            .foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, 12)
            .frame(minWidth: 36, minHeight: 36)
            .background(Color.surf2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// One of the four figures under a profile: label Space Mono 8 muted, value Space Mono 700 20. PRs get the gold star + gold value.
struct ProfileFigure: View {
    let label: String
    let value: String
    var isPR = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted).lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                if isPR { PRStar(size: 13) }
                Text(value).font(.spaceMono(20, weight: .bold)).foregroundStyle(isPR ? Color.prGold : Color.inkPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(height: 20)   // CSS line-height: 1
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The two-line list row of the design: tile, title 700 16, description 12 muted, actions at the right, hairline below.
struct PersonListRow<Actions: View>: View {
    let name: String
    var description: String?
    var accentHex: String?
    var onTap: (() -> Void)?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            Button { onTap?() } label: {
                HStack(spacing: 12) {
                    PersonTile(name: name, accentHex: accentHex)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                            .cssLineHeight(fontName: "Archivo-Bold", size: 16, multiple: 1.2)
                        if let description, !description.isEmpty {
                            Text(description).font(.archivo(12)).foregroundStyle(Color.inkMuted).lineLimit(1)
                                .cssLineHeight(fontName: "Archivo-Regular", size: 12, multiple: 1.4)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
            HStack(spacing: 6) { actions() }
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .frame(minHeight: (description ?? "").isEmpty ? 43 : 63, maxHeight: (description ?? "").isEmpty ? .infinity : 63)   // 12 + 19.2 + 3 + 16.8 + 12; the 1 pt rule below is outside it
        .padding(.bottom, 1)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

/// "Trained today" / "Trained yesterday" / "Trained 3 days ago", from the latest post of that person that this device has loaded.
enum LastTrained {
    static func text(for uid: String, in posts: [WorkoutFeedItem], now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let last = posts.filter({ $0.userId == uid }).map(\.date).max() else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "Trained today"
        case 1: return "Trained yesterday"
        default: return "Last trained \(days) days ago"
        }
    }
}

/// 48 pt dashed action (radius 8, 1 pt dashed rule-strong, Space Mono 700 9): "+ FIND FRIENDS", "SHARE INVITE LINK".
struct SocialDashedLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.spaceMono(9, weight: .bold)).tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity).frame(height: 48)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(Rectangle())
    }
}

/// Section label with an optional count/meta at the right: Space Mono 9 / 1.5 muted, 22 above, 8 below, hairline under it.
struct SocialSectionLabel: View {
    let title: String
    var meta: String?
    var top: CGFloat = 22
    var ruled = true

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let meta { Text(meta) }
        }
        .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 16).padding(.top, top).padding(.bottom, ruled ? 9 : 8)   // 8 + the list's 1 pt top border
        .overlay(alignment: .bottom) { if ruled { Rectangle().fill(Color.dsHairLine).frame(height: 1) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
