import Testing
import Foundation
@testable import Ore

@MainActor
struct SignupConfigTests {
    @Test func theBundledJSONEqualsTheFallback() throws {
        let url = try #require(Bundle.main.url(forResource: "signup.config", withExtension: "json"))
        let decoded = try #require(SignupConfig.load(from: Data(contentsOf: url)))
        #expect(decoded == SignupConfig.fallback)
    }

    @Test func theStepsAreTheDesignsInOrderPlusConfirm() {
        #expect(SignupConfig.fallback.steps.map(\.key) == ["email", "password", "confirm", "name", "username", "weight", "height", "age", "gender", "exp", "split"])
        #expect(SignupConfig.fallback.step("gender")?.choices.map(\.label) == ["Male", "Female", "Non-binary", "Other", "Prefer not to say"])
        #expect(SignupConfig.fallback.step("split")?.choices.map(\.meta) == ["6 DAYS/WK", "4 DAYS/WK", "3 DAYS/WK", "5 DAYS/WK", "YOUR OWN", "LOG FREELY"])
    }

    @Test func everyChoiceValueIsAKnownEnumCase() {
        let c = SignupConfig.fallback
        #expect(c.step("gender")!.choices.allSatisfy { Gender(rawValue: $0.value) != nil })
        #expect(c.step("exp")!.choices.allSatisfy { ExperienceLevel(rawValue: $0.value) != nil })
        #expect(c.step("split")!.choices.allSatisfy { SplitType(rawValue: $0.value) != nil })
    }

    @Test func remoteJSONThatLacksARequiredStepIsIgnored() throws {
        var broken = SignupConfig.fallback
        broken.steps.removeAll { $0.key == "username" }
        let data = try JSONEncoder().encode(broken)
        let store = SignupConfigStore()
        #expect(!store.applyRemote(json: data))
        #expect(!store.applyRemote(json: Data("{}".utf8)))
        #expect(store.current == store.base)
        var tuned = SignupConfig.fallback
        tuned.typing.msPerChar = 10
        #expect(store.applyRemote(json: try JSONEncoder().encode(tuned)))
        #expect(store.current.typing.msPerChar == 10)
    }
}
