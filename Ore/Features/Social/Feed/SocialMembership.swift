import SwiftUI

/// How a post's author looks on Social when they are a Supernova member: their worked muscles carry Stardust in their accent
/// (`BodyMapPair`), and their name carries the SUPERNOVA* tag.
struct SocialMemberStyle: Equatable {
    var palette: StarPalette
    /// The member's accent (the body map's heat colour); nil = Ore's blue.
    var accentHex: String? = nil
}

/// Whether a post's author is a Supernova member, and in which accent.
///
/// Today only the signed-in user's own membership is known on this device (`AccentStore`). `FirestoreUserProfile` and
/// `WorkoutFeedItem` carry no membership field, so other people's posts show no Stardust. When the data exists, set `remote` to read
/// it (the field needed: the author's membership flag and their accent hex on the post, e.g. `authorSupernova: Bool` and
/// `authorAccent: "#RRGGBB"`, or the same on `users/{uid}`); nothing else in the Social screens changes.
@MainActor
enum SocialMembership {
    /// Membership of another user, from synced data. `nil` = unknown or not a member. Stays `{ _ in nil }` until the field exists.
    static var remote: (_ uid: String) -> SocialMemberStyle? = { _ in nil }

    static func style(for uid: String, currentUid: String?) -> SocialMemberStyle? {
        if let currentUid, uid == currentUid {
            let store = AccentStore.shared
            return store.isMember ? SocialMemberStyle(palette: store.starPalette, accentHex: store.active.hexString) : nil
        }
        return remote(uid)
    }
}

/// Compact age for comments and activity: "2H", "30M", "1D" (Space Mono 8 labels in the design).
enum SocialAge {
    static func short(_ date: Date, now: Date = Date()) -> String {
        let s = max(0, Int(now.timeIntervalSince(date)))
        switch s {
        case ..<60: return "NOW"
        case ..<3600: return "\(s / 60)M"
        case ..<86_400: return "\(s / 3600)H"
        case ..<(86_400 * 7): return "\(s / 86_400)D"
        default: return "\(s / (86_400 * 7))W"
        }
    }
}

/// A body map with the member's Stardust over the worked muscles (a free author's post has none).
struct SocialBodyMap: View {
    let muscleSets: [String: Int]
    var style: SocialMemberStyle?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        BodyMapPair(levels: BodyMapLevels.levels(BodyHeat.Intensities(muscleSets: muscleSets)), member: style != nil,
                    accentHex: style?.accentHex, height: height)
        .frame(width: width, height: height)
    }
}
