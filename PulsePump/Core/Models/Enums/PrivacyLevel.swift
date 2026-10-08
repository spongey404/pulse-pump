import Foundation

/// 6g's PRIVACY rows (Workout posts, Body map, Global leaderboards, Profile).
///
/// Enforcement is in the data model, not just the UI: every post carries `audience` and
/// `bodyMapAudience` captured at post time, the body map's muscle data lives in a separate
/// `extras/bodymap` document guarded by `bodyMapAudience`, and `profiles/{uid}` carries
/// `profileVisibility` / `globalLeaderboardVisible` which the security rules and Cloud Functions read.
/// `friends` means a mutual follow.
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

    /// The Firestore value (`everyone` / `friends` / `onlyMe`).
    var audience: PostAudience {
        switch self {
        case .everyone: .everyone
        case .friendsOnly: .friends
        case .onlyMe: .onlyMe
        }
    }

    init(audience: PostAudience) {
        switch audience {
        case .everyone: self = .everyone
        case .friends: self = .friendsOnly
        case .onlyMe: self = .onlyMe
        }
    }

    /// The explanatory note shown under each 6g row.
    func note(for row: PrivacyRow) -> String {
        switch (row, self) {
        case (.workoutPosts, .everyone): "ANYONE ON PUMP CAN SEE YOUR NEW POSTS"
        case (.workoutPosts, .friendsOnly): "ONLY FRIENDS (PEOPLE YOU FOLLOW BACK) SEE YOUR NEW POSTS"
        case (.workoutPosts, .onlyMe): "NEW SESSIONS STAY IN YOUR HISTORY, NOBODY ELSE SEES THEM"
        case (.bodyMap, .everyone): "YOUR BODY MAP SHOWS ON EVERY NEW POST"
        case (.bodyMap, .friendsOnly): "FRIENDS SEE YOUR BODY MAP, OTHERS SEE STATS ONLY"
        case (.bodyMap, .onlyMe): "BODY MAP IS NEVER SHARED"
        case (.globalLeaderboards, .onlyMe): "YOU'RE HIDDEN FROM GLOBAL BOARDS"
        case (.globalLeaderboards, _): "YOUR NAME AND RANK SHOW ON GLOBAL BOARDS"
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

    /// UserDefaults key of the local copy (the source of truth is `users/{uid}.privacy`).
    var storageKey: String {
        "privacy_" + rawValue
    }

    /// Global boards are either shown or hidden (the rules have no friends-only board).
    var options: [PrivacyLevel] {
        self == .globalLeaderboards ? [.everyone, .onlyMe] : PrivacyLevel.allCases
    }

    func label(for level: PrivacyLevel) -> String {
        guard self == .globalLeaderboards else { return level.displayName }
        return level == .onlyMe ? "Hidden" : "Visible"
    }

    var defaultLevel: PrivacyLevel {
        switch self {
        case .workoutPosts, .bodyMap: .friendsOnly
        case .globalLeaderboards, .profile: .everyone
        }
    }
}

/// The four privacy rows as one value. Design defaults: Workout posts = friends, Body map = friends,
/// Global leaderboards = visible, Profile = everyone.
struct PrivacySettings: Equatable {
    var workoutPosts: PrivacyLevel = PrivacyRow.workoutPosts.defaultLevel
    var bodyMap: PrivacyLevel = PrivacyRow.bodyMap.defaultLevel
    /// `.everyone` = visible on global boards, `.onlyMe` = hidden.
    var globalLeaderboards: PrivacyLevel = PrivacyRow.globalLeaderboards.defaultLevel
    var profile: PrivacyLevel = PrivacyRow.profile.defaultLevel

    static let `default` = PrivacySettings()

    subscript(row: PrivacyRow) -> PrivacyLevel {
        get {
            switch row {
            case .workoutPosts: workoutPosts
            case .bodyMap: bodyMap
            case .globalLeaderboards: globalLeaderboards
            case .profile: profile
            }
        }
        set {
            switch row {
            case .workoutPosts: workoutPosts = newValue
            case .bodyMap: bodyMap = newValue
            case .globalLeaderboards: globalLeaderboards = newValue == .onlyMe ? .onlyMe : .everyone
            case .profile: profile = newValue
            }
        }
    }

    var postAudience: PostAudience { workoutPosts.audience }
    var bodyMapAudience: PostAudience { bodyMap.audience }
    var profileVisibility: PostAudience { profile.audience }
    var globalLeaderboardVisible: Bool { globalLeaderboards != .onlyMe }

    // MARK: users/{uid}.privacy

    /// The map stored at `users/{uid}.privacy`:
    /// `workoutPosts` / `bodyMap` / `profile` in `everyone|friends|onlyMe`, `globalLeaderboards` in `visible|hidden`.
    var firestoreMap: [String: String] {
        [
            "workoutPosts": workoutPosts.audience.rawValue,
            "bodyMap": bodyMap.audience.rawValue,
            "globalLeaderboards": globalLeaderboardVisible ? "visible" : "hidden",
            "profile": profile.audience.rawValue,
        ]
    }

    /// Tolerant decoding: unknown or missing keys fall back to the design default.
    init(firestoreMap map: [String: Any]) {
        func level(_ key: String, _ row: PrivacyRow) -> PrivacyLevel {
            guard let raw = map[key] as? String, let audience = PostAudience(rawValue: raw) else { return row.defaultLevel }
            return PrivacyLevel(audience: audience)
        }
        workoutPosts = level("workoutPosts", .workoutPosts)
        bodyMap = level("bodyMap", .bodyMap)
        profile = level("profile", .profile)
        switch map["globalLeaderboards"] as? String {
        case "hidden": globalLeaderboards = .onlyMe
        case "visible": globalLeaderboards = .everyone
        default: globalLeaderboards = PrivacyRow.globalLeaderboards.defaultLevel
        }
    }

    init() {}

    // MARK: Local copy

    static func load(defaults: UserDefaults = .standard) -> PrivacySettings {
        var settings = PrivacySettings()
        for row in PrivacyRow.allCases {
            if let raw = defaults.string(forKey: row.storageKey), let level = PrivacyLevel(rawValue: raw) {
                settings[row] = level
            }
        }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        for row in PrivacyRow.allCases {
            defaults.set(self[row].rawValue, forKey: row.storageKey)
        }
    }
}
