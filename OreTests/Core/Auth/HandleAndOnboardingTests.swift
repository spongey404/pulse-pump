import Testing
import Foundation
import SwiftData
@testable import Ore

struct HandleValidatorTests {
    @Test func acceptsWellFormedHandles() {
        for ok in ["abc", "alex_smith", "a.b.c", "user123", "x1y2z3", String(repeating: "a", count: 20)] {
            #expect(HandleValidator.validate(ok) == nil, "\(ok)")
        }
    }

    @Test func enforcesLength() {
        #expect(HandleValidator.validate("") == .empty)
        #expect(HandleValidator.validate("ab") == .tooShort)
        #expect(HandleValidator.validate(String(repeating: "a", count: 21)) == .tooLong)
    }

    @Test func rejectsBadCharacters() {
        for bad in ["has space", "dash-ed", "emoji😀x", "at@sign", "sla/sh"] {
            #expect(HandleValidator.validate(bad) == .invalidCharacters, "\(bad)")
        }
    }

    @Test func caseIsNormalisedOrFlagged() {
        #expect(HandleValidator.normalize("  Alex_S ") == "alex_s")
        #expect(HandleValidator.validate("alex_s".uppercased()) == nil)   // lower-cased on the way in
        #expect(HandleValidator.validate("Alex", strictCase: true) == .uppercase)
    }

    @Test func rejectsReservedNames() {
        #expect(HandleValidator.validate("admin") == .reserved)
        #expect(HandleValidator.validate("Ore") == .reserved)
    }

    @Test func punctuationRules() {
        #expect(HandleValidator.validate(".abc") == .edgePunctuation)
        #expect(HandleValidator.validate("abc_") == .edgePunctuation)
        #expect(HandleValidator.validate("a..b") == .repeatedPunctuation)
        #expect(HandleValidator.validate("a_.b") == .repeatedPunctuation)
    }

    @Test func suggestsFromNames() {
        #expect(HandleValidator.suggestion(from: "Alex Smith") == "alex_smith")
        #expect(HandleValidator.suggestion(from: "Zoë") == "zo0")        // non-ascii dropped, padded to min length
        #expect(HandleValidator.suggestion(from: "!!!") == "")
        #expect(HandleValidator.validate(HandleValidator.suggestion(from: String(repeating: "Long ", count: 12))) == nil)
    }
}

@MainActor
struct HandleInputTests {
    private func make(owned: String? = nil) -> (HandleInput, FakeProfileRemote) {
        let remote = FakeProfileRemote()
        return (HandleInput(remote: remote, uid: "me", ownedHandle: owned, debounce: .zero), remote)
    }

    @Test func freeHandleIsAvailable() async {
        let (input, _) = make()
        input.text = "alex_s"
        await input.checkNow()
        #expect(input.status == .available)
        #expect(input.isAvailable)
    }

    @Test func takenHandleIsReported() async {
        let (input, remote) = make()
        remote.handles["alex_s"] = "someone-else"
        input.text = "Alex_S"
        await input.checkNow()
        #expect(input.status == .taken)
        #expect(!input.isAvailable)
    }

    @Test func invalidInputNeverHitsTheNetwork() async {
        let (input, remote) = make()
        input.text = "no way"
        input.textChanged()
        #expect(input.status == .invalid(.invalidCharacters))
        input.text = "ab"
        await input.checkNow()
        #expect(input.status == .invalid(.tooShort))
        #expect(remote.availabilityChecks.isEmpty)
    }

    @Test func ownHandleIsAvailableWithoutAskingTheServer() async {
        let (input, remote) = make(owned: "alex_s")
        input.text = "alex_s"
        await input.checkNow()
        #expect(input.status == .available)
        #expect(remote.availabilityChecks.isEmpty)
    }

    @Test func handleOwnedByMeAlreadyCountsAsFree() async {
        let (input, remote) = make()
        remote.handles["alex_s"] = "me"
        input.text = "alex_s"
        await input.checkNow()
        #expect(input.status == .available)
    }

    @Test func networkFailureIsRetryable() async {
        let (input, remote) = make()
        remote.availabilityError = ProfileRemoteError.offline
        input.text = "alex_s"
        await input.checkNow()
        #expect(input.status == .failed(ProfileRemoteError.offline.message))
        remote.availabilityError = nil
        await input.checkNow()
        #expect(input.status == .available)
    }

    @Test func staleResponseDoesNotOverwriteNewerInput() async {
        let (input, remote) = make()
        remote.handles["first"] = "someone-else"            // first lookup says "taken", slowly
        remote.delays["first"] = .milliseconds(150)
        input.text = "first"
        let slow = Task { await input.checkNow() }
        try? await Task.sleep(for: .milliseconds(20))
        input.text = "second"                               // user kept typing
        await input.checkNow()
        await slow.value
        #expect(input.status == .available)                 // not clobbered by the late "taken"
    }

    @Test func typingLowercasesAndDebouncesIntoACheck() async {
        let remote = FakeProfileRemote()
        let input = HandleInput(remote: remote, uid: "me", debounce: .milliseconds(10))
        input.text = "ALEX"
        input.textChanged()
        #expect(input.text == "alex")
        #expect(input.status == .checking)
        for _ in 0..<100 where input.status == .checking { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(input.status == .available)
    }
}

@MainActor
struct OnboardingAccountTests {
    private func vm(_ remote: FakeProfileRemote, uid: String = "me") -> OnboardingViewModel {
        let model = OnboardingViewModel(uid: uid, prefilledName: "Alex Smith", remote: remote, debounce: .zero)
        model.weightText = "80"
        model.heightText = "180"
        model.ageText = "30"
        model.gender = .male
        model.experienceLevel = .intermediate
        return model
    }

    private func fillHandle(_ model: OnboardingViewModel, _ handle: String) async {
        model.handleInput.text = handle
        await model.handleInput.checkNow()
    }

    @Test func prefillsNameAndSuggestsAHandle() async {
        let model = vm(FakeProfileRemote())
        #expect(model.name == "Alex Smith")
        await model.suggestHandleIfEmpty()
        #expect(model.handleInput.handle == "alex_smith")
        #expect(model.handleInput.isAvailable)
    }

    @Test func handleStepBlocksContinueUntilAvailable() async {
        let remote = FakeProfileRemote()
        remote.handles["alex_s"] = "other"
        let model = vm(remote)
        model.currentStep = .handle
        #expect(!model.canContinue)
        await fillHandle(model, "alex_s")
        #expect(!model.canContinue)
        await fillHandle(model, "alex_s2")
        #expect(model.canContinue)
    }

    @Test func submitCreatesRemoteProfileThenLocalUser() async throws {
        let remote = FakeProfileRemote()
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let model = vm(remote)
        var createdUid: String?
        model.onAccountCreated = { createdUid = $0 }
        await fillHandle(model, "alex_s")

        let ok = await model.submit(modelContext: ctx)

        #expect(ok)
        #expect(createdUid == "me")
        let profile = try #require(remote.createdProfiles.first)
        #expect(profile.uid == "me")
        #expect(profile.handle == "alex_s")
        #expect(profile.displayName == "Alex Smith")
        #expect(profile.unit == "kg")
        #expect(profile.weightKg == 80)
        #expect(profile.heightCm == 180)
        #expect(profile.age == 30)
        #expect(remote.handles["alex_s"] == "me")
        let user = try #require(try ctx.fetch(FetchDescriptor<User>()).first)
        #expect(user.username == "alex_s")
        #expect(user.name == "Alex Smith")
    }

    @Test func accountPayloadCarriesNoStatsOrCounters() {
        let names = Set(Mirror(reflecting: NewAccountProfile(uid: "u", handle: "h", displayName: "n", unit: "kg",
                                                              experienceLevel: "beginner", gender: "male", age: 1,
                                                              heightCm: 1, weightKg: 1)).children.compactMap(\.label))
        for forbidden in ["streak", "totalWorkouts", "friendCount", "fanCount", "currentStreak", "longestStreak"] {
            #expect(!names.contains(forbidden))
        }
    }

    @Test func remoteFailureLeavesNoLocalUser() async throws {
        let remote = FakeProfileRemote()
        remote.createError = ProfileRemoteError.offline
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let model = vm(remote)
        await fillHandle(model, "alex_s")

        let ok = await model.submit(modelContext: ctx)

        #expect(!ok)
        #expect(model.submitError == ProfileRemoteError.offline.message)
        #expect(try ctx.fetch(FetchDescriptor<User>()).isEmpty)
        #expect(remote.createdProfiles.isEmpty)
    }

    @Test func handleRaceReturnsToTheHandleStep() async throws {
        let remote = FakeProfileRemote()
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let model = vm(remote)
        model.currentStep = .tutorialPrompt
        await fillHandle(model, "alex_s")
        #expect(model.handleInput.isAvailable)
        remote.beforeCreate = { $0.handles["alex_s"] = "faster-user" }   // someone claims it between check and write

        let ok = await model.submit(modelContext: ctx)

        #expect(!ok)
        #expect(model.currentStep == .handle)
        #expect(model.handleInput.status == .taken)
        #expect(model.submitError == ProfileRemoteError.handleTaken.message)
        #expect(try ctx.fetch(FetchDescriptor<User>()).isEmpty)
        #expect(remote.handles["alex_s"] == "faster-user")
    }

    @Test func invalidHandleIsRejectedBeforeAnyWrite() async throws {
        let remote = FakeProfileRemote()
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let model = vm(remote)
        model.handleInput.text = "x"
        let ok = await model.submit(modelContext: ctx)
        #expect(!ok)
        #expect(remote.createdProfiles.isEmpty)
        #expect(model.currentStep == .handle)
    }

    @Test func renameReleasesTheOldHandle() async throws {
        let remote = FakeProfileRemote()
        remote.handles["old_one"] = "me"
        try await remote.changeHandle(uid: "me", from: "old_one", to: "new_one", displayName: "Alex")
        #expect(remote.handles["old_one"] == nil)
        #expect(remote.handles["new_one"] == "me")
        await #expect(throws: ProfileRemoteError.handleTaken) {
            remote.handles["busy"] = "other"
            try await remote.changeHandle(uid: "me", from: "new_one", to: "busy", displayName: "Alex")
        }
        #expect(remote.handles["new_one"] == "me")   // failed rename keeps the old handle
    }

    @Test func stepFlowIsNameThenHandleAndHasNoWelcomeOrAuthStep() {
        #expect(OnboardingStep.flow.first == .name)
        #expect(OnboardingStep.flow.dropFirst().first == .handle)
        #expect(OnboardingStep.flow.last == .tutorialPrompt)
    }
}

struct FirebaseEmulatorConfigTests {
    @Test func offByDefault() {
        #expect(FirebaseEmulatorConfig.parse(useEmulator: false, host: "10.0.0.5") == nil)
    }

    @Test func defaultsToLoopbackWithRepoPorts() {
        let config = FirebaseEmulatorConfig.parse(useEmulator: true, host: nil)
        #expect(config == FirebaseEmulatorConfig(host: "127.0.0.1", authPort: 9099, firestorePort: 8085, functionsPort: 5001))
    }

    @Test func hostIsOverridable() {
        #expect(FirebaseEmulatorConfig.parse(useEmulator: true, host: " 192.168.1.20 ")?.host == "192.168.1.20")
        #expect(FirebaseEmulatorConfig.parse(useEmulator: true, host: "  ")?.host == "127.0.0.1")
    }

    @Test func readsLaunchArgumentsFromUserDefaults() throws {
        let suite = try #require(UserDefaults(suiteName: "emulator-config-test-\(UUID().uuidString)"))
        #expect(FirebaseEmulatorConfig.from(defaults: suite) == nil)
        suite.set(true, forKey: "useFirebaseEmulator")
        suite.set("10.1.1.1", forKey: "firebaseEmulatorHost")
        #expect(FirebaseEmulatorConfig.from(defaults: suite)?.host == "10.1.1.1")
    }
}
