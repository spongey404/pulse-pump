import Foundation

/// 6g's PRIVACY rows (Workout posts, Body map, Global leaderboards, Profile). Local-only
/// (`@AppStorage`) — no Cloud Functions layer exists in this repo to enforce these against
/// other users' reads, so this governs the current user's own share/fetch calls only.
/// TODO: enforce server-side once a functions layer exists.
enum PrivacyLevel: String, Codable, CaseIterable, Identifiable {
    case everyone
    case friendsOnly
    case onlyMe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .everyone: "Everyone"
        case .friendsOnly: "Friends only"
        case .onlyMe: "Only me"
        }
    }

    /// The explanatory note shown under each 6g row.
    func note(for row: PrivacyRow) -> String {
        switch (row, self) {
        case (.workoutPosts, .everyone): "ANYONE ON PUMP CAN SEE YOUR POSTS"
        case (.workoutPosts, .friendsOnly): "ONLY PEOPLE YOU FOLLOW BACK CAN SEE YOUR POSTS"
        case (.workoutPosts, .onlyMe): "POSTS STAY IN YOUR HISTORY, NOBODY ELSE SEES THEM"
        case (.bodyMap, .everyone): "YOUR BODY MAP SHOWS ON EVERY POST"
        case (.bodyMap, .friendsOnly): "FRIENDS SEE YOUR BODY MAP, OTHERS SEE STATS ONLY"
        case (.bodyMap, .onlyMe): "BODY MAP NEVER SHOWS ON A POST"
        case (.globalLeaderboards, .everyone): "YOUR NAME AND RANK ARE PUBLIC ON GLOBAL BOARDS"
        case (.globalLeaderboards, .friendsOnly): "ONLY FRIENDS SEE YOU ON GLOBAL BOARDS"
        case (.globalLeaderboards, .onlyMe): "YOU'RE HIDDEN FROM GLOBAL BOARDS"
        case (.profile, .everyone): "ANYONE CAN VIEW YOUR PROFILE"
        case (.profile, .friendsOnly): "ONLY FRIENDS CAN VIEW YOUR PROFILE"
        case (.profile, .onlyMe): "YOUR PROFILE IS PRIVATE"
        }
    }
}

enum PrivacyRow: String, CaseIterable, Identifiable {
    case workoutPosts, bodyMap, globalLeaderboards, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workoutPosts: "Workout posts"
        case .bodyMap: "Body map"
        case .globalLeaderboards: "Global leaderboards"
        case .profile: "Profile"
        }
    }

    var storageKey: String {
        "privacy_" + rawValue
    }
}
