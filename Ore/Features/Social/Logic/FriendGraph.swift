import Foundation

/// How another user relates to me, derived from the two follow directions.
///
/// - **friends**: both follow each other (mutual follow).
/// - **fan**: they follow me, I don't follow them back. A "friend request" in the inbox is a fan.
/// - **following**: I follow them, they don't follow back (waiting for them).
enum Relationship: Equatable {
    case me
    case friends
    case fan
    case following
    case stranger
    case blocked
}

/// The follow graph around me. Pure value type: the view model feeds it edges and gets friends,
/// fans and the inbox back, which keeps the friend/fan rules testable.
struct FriendGraph: Equatable {
    /// People I follow.
    var following: Set<String>
    /// People who follow me.
    var followers: Set<String>
    /// People I blocked: they disappear from every list and cannot be followed.
    var blocked: Set<String>
    /// Fans whose request I ignored. They stay fans (and keep following me) but leave the inbox.
    var dismissedFans: Set<String>

    init(following: Set<String> = [], followers: Set<String> = [], blocked: Set<String> = [], dismissedFans: Set<String> = []) {
        self.following = following
        self.followers = followers
        self.blocked = blocked
        self.dismissedFans = dismissedFans
    }

    init(following: [FollowEdge], followers: [FollowEdge], blocked: Set<String> = [], dismissedFans: Set<String> = []) {
        self.init(following: Set(following.map(\.followeeUid)),
                  followers: Set(followers.map(\.followerUid)),
                  blocked: blocked, dismissedFans: dismissedFans)
    }

    /// Mutual follows.
    var friends: Set<String> { following.intersection(followers).subtracting(blocked) }

    /// They follow me, I don't follow back.
    var fans: Set<String> { followers.subtracting(following).subtracting(blocked) }

    /// Fans that still need an answer (the inbox): fans I did not ignore.
    var fanRequests: Set<String> { fans.subtracting(dismissedFans) }

    /// I follow them and they have not followed back yet.
    var pendingOutgoing: Set<String> { following.subtracting(followers).subtracting(blocked) }

    func relationship(with uid: String, me: String?) -> Relationship {
        if uid == me { return .me }
        if blocked.contains(uid) { return .blocked }
        switch (following.contains(uid), followers.contains(uid)) {
        case (true, true): return .friends
        case (false, true): return .fan
        case (true, false): return .following
        case (false, false): return .stranger
        }
    }

    // MARK: Mutations (local mirror of what the remote did)

    /// FOLLOW / ACCEPT (follow back). A fan becomes a friend; a stranger becomes `following`.
    /// Blocked users cannot be followed.
    @discardableResult
    mutating func follow(_ uid: String) -> Bool {
        guard !blocked.contains(uid) else { return false }
        following.insert(uid)
        dismissedFans.remove(uid)
        return true
    }

    /// UNFOLLOW. A friend becomes a fan again.
    mutating func unfollow(_ uid: String) { following.remove(uid) }

    /// IGNORE on a request: dismiss it from the inbox. No data is written; the person stays a fan.
    mutating func ignoreFan(_ uid: String) {
        if fans.contains(uid) { dismissedFans.insert(uid) }
    }

    /// BLOCK removes my follow; their follow of me cannot be deleted by me, but they vanish from my lists.
    mutating func block(_ uid: String) {
        blocked.insert(uid)
        following.remove(uid)
        dismissedFans.remove(uid)
    }

    mutating func unblock(_ uid: String) { blocked.remove(uid) }
}
