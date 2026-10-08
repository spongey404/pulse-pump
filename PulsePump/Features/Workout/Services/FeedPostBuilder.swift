import Foundation

/// Builds the one feed payload for a finished workout. The post id is the workout's id, so
/// posting is idempotent: even if the composer fired twice, Firestore would hold a single doc.
/// The privacy rows are not enforced here (backend job); the chosen audience just travels in
/// the payload.
enum FeedPostBuilder {
    /// The "Workout posts" privacy row (default friends only). `.onlyMe` means nothing is posted.
    static func audience(defaults: UserDefaults = .standard) -> PrivacyLevel {
        PrivacyLevel(rawValue: defaults.string(forKey: PrivacyRow.workoutPosts.storageKey) ?? "") ?? .friendsOnly
    }

    static func makeItem(
        data: WorkoutCompletionData,
        userId: String,
        username: String,
        caption: String,
        taggedFriendUids: [String],
        includeBodyMap: Bool,
        defaults: UserDefaults = .standard,
        date: Date = Date()
    ) -> WorkoutFeedItem {
        let audience = Self.audience(defaults: defaults)
        let bodyMapLevel = PrivacyLevel(rawValue: defaults.string(forKey: PrivacyRow.bodyMap.storageKey) ?? "") ?? .friendsOnly
        return WorkoutFeedItem(
            id: data.workoutId?.uuidString ?? UUID().uuidString,
            userId: userId,
            username: username,
            templateName: data.workoutName,
            exerciseCount: data.exerciseCount,
            durationSeconds: Int(data.duration),
            caloriesBurned: Int(data.calories),
            musclesWorked: data.musclesWorked.map(\.displayName),
            prCount: data.prCount,
            improvedCount: data.improvedCount,
            totalExercises: data.totalExercises,
            date: date,
            caption: caption,
            exercises: data.exercises,
            taggedFriendUids: taggedFriendUids,
            includesBodyMap: includeBodyMap && bodyMapLevel != .onlyMe,
            audience: audience.rawValue
        )
    }
}
