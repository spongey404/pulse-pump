import Foundation

/// The wire format of the social collections: builders for every document the client writes and
/// parsers for every document it reads. Pure and free of Firebase types (dates stay `Date`; the
/// Firestore remote converts them to `Timestamp` and back), so it can be tested without Firebase.
///
/// Every builder produces exactly the keys the security rules allow (`hasOnly` lists in
/// `firebase/firestore.rules`) and never a function-owned counter (`likeCount`, `commentCount`,
/// `friendCount`, `fanCount`, `memberCount`, `status` of a challenge, entry scores).
enum SocialWire {
    // MARK: Scalars

    static func int(_ any: Any?) -> Int {
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }

    static func double(_ any: Any?) -> Double {
        if let n = any as? NSNumber { return n.doubleValue }
        return 0
    }

    static func string(_ any: Any?) -> String { any as? String ?? "" }

    static func date(_ any: Any?) -> Date? { any as? Date }

    // MARK: Profiles

    static func profile(from d: [String: Any], uid: String) -> FirestoreUserProfile {
        FirestoreUserProfile(
            uid: uid,
            username: string(d["username"]),
            displayName: string(d["displayName"]),
            totalWorkouts: int(d["totalWorkouts"]),
            currentStreak: int(d["streak"]),
            friendCount: int(d["friendCount"]),
            fanCount: int(d["fanCount"]),
            profileVisibility: PostAudience(rawValue: string(d["profileVisibility"])) ?? .everyone,
            globalLeaderboardVisible: (d["globalLeaderboardVisible"] as? Bool) ?? true
        )
    }

    /// `profiles/{uid}` on create (the rules require visibility fields and forbid non-zero counters).
    static func newProfileDocument(name: String, handle: String, privacy: PrivacySettings, now: Date) -> [String: Any] {
        [
            "displayName": String(name.prefix(100)),
            "username": handle,
            "streak": 0,
            "totalWorkouts": 0,
            "profileVisibility": privacy.profileVisibility.rawValue,
            "globalLeaderboardVisible": privacy.globalLeaderboardVisible,
            "createdAt": now,
            "updatedAt": now,
            "schemaVersion": 1,
        ]
    }

    static func profileUpdateDocument(_ update: ProfileUpdate, now: Date) -> [String: Any] {
        var fields: [String: Any] = ["updatedAt": now]
        if let name = update.displayName { fields["displayName"] = String(name.prefix(100)) }
        if let streak = update.streak { fields["streak"] = max(0, streak) }
        if let total = update.totalWorkouts { fields["totalWorkouts"] = max(0, total) }
        if let visibility = update.profileVisibility { fields["profileVisibility"] = visibility.rawValue }
        if let visible = update.globalLeaderboardVisible { fields["globalLeaderboardVisible"] = visible }
        return fields
    }

    /// `users/{uid}` merge write: ONLY the privacy map (the sync layer owns every other user field),
    /// plus the `schemaVersion` the rules require on any write to that document.
    static func privacyDocument(_ settings: PrivacySettings) -> [String: Any] {
        ["privacy": settings.firestoreMap, "schemaVersion": 1]
    }

    // MARK: Follows, blocks, reports

    static func followId(follower: String, followee: String) -> String { "\(follower)_\(followee)" }

    static func followDocument(follower: String, followee: String, now: Date) -> [String: Any] {
        ["followerUid": follower, "followeeUid": followee, "createdAt": now]
    }

    static func follow(from d: [String: Any]) -> FollowEdge? {
        guard let a = d["followerUid"] as? String, let b = d["followeeUid"] as? String else { return nil }
        return FollowEdge(followerUid: a, followeeUid: b, createdAt: date(d["createdAt"]) ?? .distantPast)
    }

    static func blockedDocument(_ b: BlockedUser) -> [String: Any] {
        ["createdAt": b.createdAt, "username": String(b.username.prefix(40)), "displayName": String(b.displayName.prefix(100))]
    }

    static func blocked(from d: [String: Any], uid: String) -> BlockedUser {
        BlockedUser(uid: uid, username: string(d["username"]), displayName: string(d["displayName"]),
                    createdAt: date(d["createdAt"]) ?? .distantPast)
    }

    static func reportDocument(reporter: String, target: ReportTarget, targetId: String, reason: String,
                               details: String?, now: Date) -> [String: Any] {
        var data: [String: Any] = [
            "reporterUid": reporter,
            "targetType": target.rawValue,
            "targetId": String(targetId.prefix(200)),
            "reason": String(reason.prefix(500)),
            "createdAt": now,
        ]
        if let details, !details.isEmpty { data["details"] = String(details.prefix(1000)) }
        return data
    }

    // MARK: Posts

    static func exerciseData(_ ex: FeedExercise) -> [String: Any] {
        [
            "id": ex.id,
            "name": String(ex.name.prefix(200)),
            "sets": ex.sets.map { s -> [String: Any] in
                var d: [String: Any] = ["weight": s.weight, "reps": s.reps, "duration": s.duration,
                                        "distance": s.distance, "setType": s.setType]
                if let side = s.side { d["side"] = side }
                return d
            },
            "improvementScore": ex.improvementScore,
            "weightDelta": ex.weightDelta,
            "repsDelta": ex.repsDelta,
        ]
    }

    static func exercise(from d: [String: Any]) -> FeedExercise? {
        guard let name = d["name"] as? String else { return nil }
        let sets = (d["sets"] as? [[String: Any]] ?? []).map { s in
            FeedSetLog(weight: double(s["weight"]), reps: int(s["reps"]), duration: int(s["duration"]),
                       distance: double(s["distance"]), setType: (s["setType"] as? String) ?? "standard",
                       side: s["side"] as? String)
        }
        return FeedExercise(id: (d["id"] as? String) ?? UUID().uuidString, name: name, sets: sets,
                            improvementScore: double(d["improvementScore"]),
                            weightDelta: double(d["weightDelta"]), repsDelta: int(d["repsDelta"]))
    }

    /// `posts/{id}`. Counters are absent: the rules only accept absent/0 on create.
    static func postDocument(_ p: PostPayload, now: Date) -> [String: Any] {
        var data: [String: Any] = [
            "authorUid": p.authorUid,
            "authorName": String(p.authorName.prefix(100)),
            "authorUsername": String(p.authorUsername.prefix(40)),
            "date": p.date,
            "workoutName": String(p.workoutName.prefix(200)),
            "audience": p.audience.rawValue,
            "bodyMapAudience": p.bodyMapAudience.rawValue,
            "stats": [
                "sets": p.stats.sets,
                "volumeKg": p.stats.volumeKg,
                "durationSec": p.stats.durationSec,
                "prCount": p.stats.prCount,
            ] as [String: Any],
            "exercises": p.exercises.prefix(60).map { exerciseData($0) },
            "createdAt": now,
            "workoutId": p.postId,
            "schemaVersion": 1,
        ]
        let caption = String(p.caption.prefix(500))
        if !caption.isEmpty { data["caption"] = caption }
        if !p.taggedUids.isEmpty { data["taggedUids"] = Array(p.taggedUids.prefix(20)) }
        if !p.taggedNames.isEmpty { data["taggedNames"] = p.taggedNames.prefix(20).map { String($0.prefix(60)) } }
        if let url = p.photoURL, !url.isEmpty { data["photoURL"] = String(url.prefix(600)) }
        if let song = p.song { data["song"] = songData(song) }
        if let edited = p.editedAt { data["editedAt"] = edited }
        return data
    }

    static func songData(_ s: PostSong) -> [String: Any] {
        var d: [String: Any] = ["title": String(s.title.prefix(120)), "artist": String(s.artist.prefix(120))]
        if let a = s.artworkURL { d["artworkURL"] = String(a.prefix(600)) }
        if let u = s.previewURL { d["previewURL"] = String(u.prefix(600)) }
        if let id = s.appleMusicId { d["appleMusicId"] = String(id.prefix(40)) }
        return d
    }

    static func song(from d: [String: Any]?) -> PostSong? {
        guard let d, let title = d["title"] as? String, let artist = d["artist"] as? String else { return nil }
        return PostSong(title: title, artist: artist, artworkURL: d["artworkURL"] as? String, previewURL: d["previewURL"] as? String,
                        appleMusicId: d["appleMusicId"] as? String)
    }

    /// `posts/{id}/extras/bodymap`.
    static func bodyMapDocument(_ muscleSets: [String: Int], now: Date) -> [String: Any] {
        ["muscleSets": muscleSets, "schemaVersion": 1, "updatedAt": now]
    }

    static func post(from d: [String: Any], id: String) -> WorkoutFeedItem? {
        guard let author = d["authorUid"] as? String, let date = date(d["date"]) else { return nil }
        let stats = d["stats"] as? [String: Any] ?? [:]
        let exercises = (d["exercises"] as? [[String: Any]] ?? []).compactMap { exercise(from: $0) }
        let improved = exercises.filter { $0.improvementScore > 0 || $0.weightDelta > 0 || $0.repsDelta > 0 }.count
        let name = string(d["workoutName"])
        var item = WorkoutFeedItem(
            id: id,
            userId: author,
            username: string(d["authorName"]),
            handle: string(d["authorUsername"]),
            templateName: name.isEmpty ? nil : name,
            exerciseCount: exercises.count,
            durationSeconds: int(stats["durationSec"]),
            prCount: int(stats["prCount"]),
            improvedCount: improved,
            totalExercises: exercises.count,
            date: date,
            createdAt: Self.date(d["createdAt"]) ?? date,
            caption: string(d["caption"]),
            exercises: exercises,
            taggedFriendUids: d["taggedUids"] as? [String] ?? [],
            audience: d["audience"] as? String,
            bodyMapAudience: d["bodyMapAudience"] as? String,
            likeCount: int(d["likeCount"]),
            commentCount: int(d["commentCount"])
        )
        item.photoURL = d["photoURL"] as? String
        item.song = song(from: d["song"] as? [String: Any])
        item.taggedNames = d["taggedNames"] as? [String]
        item.isEdited = d["editedAt"] != nil ? true : nil
        return item
    }

    static func muscleSets(from d: [String: Any]) -> [String: Int]? {
        guard let map = d["muscleSets"] as? [String: Any] else { return nil }
        return map.mapValues { int($0) }
    }

    // MARK: Likes and comments

    static func likeDocument(uid: String, now: Date) -> [String: Any] { ["uid": uid, "createdAt": now] }

    static func commentDocument(authorUid: String, authorName: String, authorUsername: String, text: String, now: Date) -> [String: Any] {
        [
            "authorUid": authorUid,
            "authorName": String(authorName.prefix(100)),
            "authorUsername": String(authorUsername.prefix(40)),
            "text": text,
            "createdAt": now,
            "schemaVersion": 1,
        ]
    }

    static func comment(from d: [String: Any], id: String) -> FeedComment? {
        guard let author = d["authorUid"] as? String, let text = d["text"] as? String else { return nil }
        let handle = string(d["authorUsername"])
        let name = string(d["authorName"])
        return FeedComment(id: id, userId: author, username: name.isEmpty ? (handle.isEmpty ? Brand.defaultUserName : handle) : name,
                           handle: handle, text: text, date: date(d["createdAt"]) ?? Date())
    }

    // MARK: Challenges

    /// `challenges/{id}` on create. `isGlobal` is always false and `status` "active"; `memberCount` is
    /// absent (functions own it).
    static func challengeDocument(_ draft: ChallengeDraft, creator: String, now: Date) -> [String: Any] {
        var data: [String: Any] = [
            "creatorUid": creator,
            "name": draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            "metric": draft.metric.rawValue,
            "startAt": draft.startAt,
            "endAt": draft.endAt,
            "isGlobal": false,
            "visibility": draft.visibility.rawValue,
            "status": ChallengeStatus.active.rawValue,
            "winCondition": draft.winCondition.rawValue,
            "schemaVersion": 1,
            "createdAt": now,
        ]
        if let exercise = draft.exerciseName, !exercise.isEmpty { data["exerciseName"] = String(exercise.prefix(100)) }
        if let unit = draft.unit, !unit.isEmpty { data["unit"] = String(unit.prefix(30)) }
        if let label = draft.customLabel, !label.isEmpty { data["customLabel"] = String(label.prefix(60)) }
        return data
    }

    static func challenge(from d: [String: Any], id: String) -> SocialChallenge? {
        guard let name = d["name"] as? String, let start = date(d["startAt"]), let end = date(d["endAt"]) else { return nil }
        return SocialChallenge(
            id: id,
            creatorUid: string(d["creatorUid"]),
            name: name,
            metric: ChallengeMetric(rawValue: string(d["metric"])) ?? .totalVolume,
            exerciseName: d["exerciseName"] as? String,
            startAt: start,
            endAt: end,
            isGlobal: (d["isGlobal"] as? Bool) ?? false,
            visibility: ChallengeVisibility(rawValue: string(d["visibility"])) ?? .invite,
            status: ChallengeStatus(rawValue: string(d["status"])) ?? .active,
            memberCount: int(d["memberCount"]),
            winCondition: ChallengeWinCondition(rawValue: string(d["winCondition"])) ?? .highest,
            unit: d["unit"] as? String,
            customLabel: d["customLabel"] as? String
        )
    }

    /// `challenges/{id}/members/{uid}` (join).
    static func memberDocument(uid: String, username: String, now: Date) -> [String: Any] {
        ["uid": uid, "username": String(username.prefix(40)), "joinedAt": now, "schemaVersion": 1]
    }

    static func entry(from d: [String: Any], id: String) -> ChallengeEntry {
        ChallengeEntry(uid: (d["uid"] as? String) ?? id,
                       username: string(d["username"]),
                       score: double(d["score"]),
                       rank: int(d["rank"]),
                       previousRank: int(d["previousRank"]),
                       scoreAt: date(d["scoreAt"]),
                       hidden: (d["hidden"] as? Bool) ?? false)
    }

    // MARK: Invites

    /// `invites/{challengeId}_{toUid}`; status is always "pending" on create.
    static func inviteDocument(_ invite: ChallengeInvite) -> [String: Any] {
        [
            "challengeId": invite.challengeId,
            "fromUid": invite.fromUid,
            "toUid": invite.toUid,
            "status": ChallengeInviteStatus.pending.rawValue,
            "createdAt": invite.createdAt,
            "challengeName": String(invite.challengeName.prefix(100)),
            "fromUsername": String(invite.fromUsername.prefix(40)),
            "schemaVersion": 1,
        ]
    }

    static func invite(from d: [String: Any], id: String, me: String) -> ChallengeInvite? {
        guard let challengeId = d["challengeId"] as? String, let from = d["fromUid"] as? String else { return nil }
        var invite = ChallengeInvite(challengeId: challengeId, challengeName: string(d["challengeName"]),
                                     fromUid: from, fromUsername: string(d["fromUsername"]),
                                     toUid: (d["toUid"] as? String) ?? me,
                                     status: ChallengeInviteStatus(rawValue: string(d["status"])) ?? .pending,
                                     createdAt: date(d["createdAt"]) ?? Date())
        invite.id = id
        return invite
    }
}
