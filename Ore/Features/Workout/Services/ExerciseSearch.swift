import Foundation

/// The matching behind the logger's pull-down search: every typed word must start a word in an exercise
/// name ("barbell row", "row", "bar r" all find "Barbell Row"), so a search can jump straight to an
/// exercise that is already far down the workout.
enum ExerciseSearch {
    /// Which of the workout's exercise names match, by position.
    static func workoutMatches(names: [String], query: String) -> [Int] {
        let words = query.split(whereSeparator: { $0 == " " }).map(String.init)
        guard !words.isEmpty else { return [] }
        return names.indices.filter { i in words.allSatisfy { names[i].hasWordPrefix($0) } }
    }
}
