import Foundation
import Testing
@testable import PulsePump

/// Searching the workout itself: the exercise you want next is far down the list, and its name finds it.
struct WorkoutJumpMatchTests {
    private let names = ["Barbell Bench Press", "Overhead Press", "Lat Pulldown", "Leg Press", "Barbell Row", "Lateral Raise"]

    @Test func anyWordOfTheNameFindsItsPosition() {
        #expect(ExerciseSearch.workoutMatches(names: names, query: "row") == [4])
        #expect(ExerciseSearch.workoutMatches(names: names, query: "press") == [0, 1, 3])
        #expect(ExerciseSearch.workoutMatches(names: names, query: "lat") == [2, 5])
    }

    @Test func aWordMustStartAWordNotJustAppearInsideOne() {
        #expect(ExerciseSearch.workoutMatches(names: names, query: "ow").isEmpty, "\"ow\" is inside Row and Pulldown, but starts no word")
        #expect(ExerciseSearch.workoutMatches(names: names, query: "bench") == [0])
    }

    @Test func everyTypedWordMustMatchAndOrderDoesNotMatter() {
        #expect(ExerciseSearch.workoutMatches(names: names, query: "barbell row") == [4])
        #expect(ExerciseSearch.workoutMatches(names: names, query: "row barbell") == [4])
        #expect(ExerciseSearch.workoutMatches(names: names, query: "barbell raise").isEmpty)
    }

    @Test func caseAndExtraSpacesDoNotMatter() {
        #expect(ExerciseSearch.workoutMatches(names: names, query: "  BARBELL   row ") == [4])
    }

    @Test func nothingTypedMatchesNothing() {
        #expect(ExerciseSearch.workoutMatches(names: names, query: "").isEmpty)
        #expect(ExerciseSearch.workoutMatches(names: names, query: "  ").isEmpty)
        #expect(ExerciseSearch.workoutMatches(names: [], query: "row").isEmpty)
    }

    @Test func aNameThatRepeatsMatchesAtEveryPosition() {
        #expect(ExerciseSearch.workoutMatches(names: ["Curl", "Row", "Curl"], query: "curl") == [0, 2])
    }
}
