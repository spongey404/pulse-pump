import Foundation

/// Builds the one post payload for a finished workout.
///
/// - The post id is the workout's id (lower-case), so posting is idempotent: a second attempt
///   rewrites the same document instead of creating a duplicate.
/// - Only working sets are posted (warm-ups never count, and never leave the device).
/// - The muscle tags of each exercise are NOT part of the post document. They are summed into
///   `muscleSets`, which goes to `extras/bodymap` and is guarded by `bodyMapAudience`. With the body
///   map set to "Only me" (or "Post without body map") no extras document is written at all.
/// - `audience` / `bodyMapAudience` come from the privacy settings at post time.
enum FeedPostBuilder {
    /// The "Workout posts" privacy row, from the local copy. `.onlyMe` means nothing is posted.
    static func audience(defaults: UserDefaults = .standard) -> PrivacyLevel {
        PrivacySettings.load(defaults: defaults).workoutPosts
    }

    struct Author: Equatable {
        var uid: String
        var name: String
        var handle: String
    }

    /// The payload to publish, or nil when the user's "Workout posts" setting is "Only me".
    static func makePayload(
        data: WorkoutCompletionData,
        author: Author,
        caption: String,
        taggedUids: [String],
        includeBodyMap: Bool,
        privacy: PrivacySettings,
        date: Date = Date()
    ) -> PostPayload? {
        let audience = privacy.postAudience
        guard audience != .onlyMe else { return nil }

        // Working sets only, and only exercises that have at least one.
        let posted: [FeedExercise] = data.exercises.compactMap { ex in
            let working = ex.workingSets
            guard !working.isEmpty else { return nil }
            var copy = ex.forPost
            copy.sets = working
            return copy
        }

        let bodyMapAudience = privacy.bodyMapAudience
        let muscleSets: [String: Int]? = (includeBodyMap && bodyMapAudience != .onlyMe)
            ? muscleSetCounts(for: data.exercises)
            : nil

        let postId = (data.workoutId?.uuidString ?? UUID().uuidString).lowercased()
        let sets = posted.reduce(0) { $0 + $1.sets.count }
        let volume = posted.flatMap(\.sets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return PostPayload(
            postId: postId,
            authorUid: author.uid,
            authorName: author.name,
            authorUsername: author.handle,
            date: date,
            workoutName: data.workoutName ?? "Workout",
            audience: audience,
            bodyMapAudience: bodyMapAudience,
            stats: .init(sets: sets, volumeKg: volume, durationSec: Int(data.duration), prCount: data.prCount),
            exercises: posted,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            taggedUids: taggedUids,
            muscleSets: (muscleSets?.isEmpty == false) ? muscleSets : nil
        )
    }

    /// Weighted working sets per muscle: primary muscles get full credit, secondary half (the same
    /// convention as the Body tab). Keys are `MuscleGroup.displayName`.
    static func muscleSetCounts(for exercises: [FeedExercise]) -> [String: Int] {
        var counts: [String: Double] = [:]
        for ex in exercises {
            let sets = Double(ex.workingSets.count)
            guard sets > 0 else { continue }
            for m in ex.primaryMuscles { counts[m, default: 0] += sets }
            for m in ex.secondaryMuscles { counts[m, default: 0] += sets / 2 }
        }
        return counts.compactMapValues { value in
            let rounded = Int(value.rounded())
            return rounded > 0 ? rounded : nil
        }
    }
}
