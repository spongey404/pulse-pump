import Foundation
import Testing
@testable import Ore

/// The picker rebuilt every row on each pass because each entry got a fresh random id, which made taps on
/// the first row unreliable (and a tutorial spotlight on it flicker).
struct ExercisePickerIdentityTests {
    private func bench() -> Exercise {
        Exercise(name: "Barbell Bench Press", primaryMuscleGroups: [.chest], equipmentType: .barbell, movementPattern: .push)
    }

    @Test func aGroupKeepsTheSameIdAcrossRebuilds() {
        let first = ExerciseGroupEntry(groupName: "Bench Press", exercises: [bench()])
        let second = ExerciseGroupEntry(groupName: "Bench Press", exercises: [bench()])
        #expect(first.id == second.id)
        #expect(first == second)
    }

    @Test func differentGroupsHaveDifferentIds() {
        let a = ExerciseGroupEntry(groupName: "Bench Press", exercises: [bench()])
        let b = ExerciseGroupEntry(groupName: "Incline Bench Press", exercises: [bench()])
        #expect(a.id != b.id)
        #expect(Set([a, b]).count == 2)
    }
}
