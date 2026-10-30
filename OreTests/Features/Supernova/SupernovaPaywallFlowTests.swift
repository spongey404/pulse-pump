import Foundation
import Testing
@testable import Ore

/// The paywall is the end of first-run onboarding: once, after the tutorial (or straight after onboarding), never for
/// a member, never after a replay. These tests use an isolated UserDefaults suite where they can; the tutorial ones
/// go through `UserDefaults.standard` (what the view model reads), so they run serially and put the flags back.
@Suite(.serialized)
struct SupernovaPaywallFlowTests {
    private func suite() -> UserDefaults {
        let name = "paywall-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func theRulesShowItOnceAndNeverToAMember() {
        #expect(SupernovaPaywallGate.shouldShow(isMember: false, pending: true, alreadyShown: false))
        #expect(!SupernovaPaywallGate.shouldShow(isMember: true, pending: true, alreadyShown: false), "a member skips it")
        #expect(!SupernovaPaywallGate.shouldShow(isMember: false, pending: true, alreadyShown: true), "only once")
        #expect(!SupernovaPaywallGate.shouldShow(isMember: false, pending: false, alreadyShown: false), "only after onboarding")
    }

    @Test func finishingOnboardingMakesItDueAndShowingItUsesItUp() {
        let d = suite()
        #expect(!SupernovaPaywallGate.shouldShowNow(d))
        SupernovaPaywallGate.markPending(d)
        #expect(SupernovaPaywallGate.shouldShowNow(d))
        SupernovaPaywallGate.markShown(d)
        #expect(!SupernovaPaywallGate.shouldShowNow(d))
        SupernovaPaywallGate.markPending(d)   // a second onboarding (sign out, sign in as someone new) doesn't bring it back
        #expect(!SupernovaPaywallGate.shouldShowNow(d))
    }

    @Test func aSubscriberIsAMember() {
        let d = suite()
        #expect(!SupernovaPaywallGate.isMember(d))
        d.set(true, forKey: SupernovaService.subscribedMirrorKey)
        #expect(SupernovaPaywallGate.isMember(d))
    }

    // MARK: tutorial end

    @MainActor private func finishTheLastStep(firstRun: Bool, due: Bool, member: Bool = false) async -> (shown: Bool, vm: TutorialViewModel) {
        let d = UserDefaults.standard
        let saved = [SupernovaPaywallGate.pendingKey, SupernovaPaywallGate.shownKey, SupernovaService.subscribedMirrorKey, "devDataPlus"].map { ($0, d.object(forKey: $0)) }
        defer { saved.forEach { d.set($0.1, forKey: $0.0) } }
        d.set(due, forKey: SupernovaPaywallGate.pendingKey)
        d.set(false, forKey: SupernovaPaywallGate.shownKey)
        d.set(member, forKey: SupernovaService.subscribedMirrorKey)
        d.set(false, forKey: "devDataPlus")   // the simulator may be seeded as a member

        let vm = TutorialViewModel()
        vm.didSucceed = { _ in true }
        var posted = false
        let token = NotificationCenter.default.addObserver(forName: .showSupernovaPaywall, object: nil, queue: .main) { _ in posted = true }
        defer { NotificationCenter.default.removeObserver(token) }
        vm.start(firstRun: firstRun)
        vm.currentStep = .discard
        vm.advance()
        return (posted, vm)
    }

    @Test @MainActor func theFirstRunTutorialEndsOnThePaywallInsteadOfTheAllSetScreen() async {
        let r = await finishTheLastStep(firstRun: true, due: true)
        #expect(r.shown)
        #expect(!r.vm.isFinished, "the old \"You're all set\" screen is not shown")
        #expect(!r.vm.isActive)
    }

    @Test @MainActor func aMemberGetsTheNormalDoneScreen() async {
        let r = await finishTheLastStep(firstRun: true, due: true, member: true)
        #expect(!r.shown)
        #expect(r.vm.isFinished)
        r.vm.skip()
    }

    @Test @MainActor func aReplayEndsOnTheDoneScreenNotThePaywall() async {
        let r = await finishTheLastStep(firstRun: false, due: true)
        #expect(!r.shown)
        #expect(r.vm.isFinished)
        r.vm.skip()
    }

    @Test @MainActor func skippingTheFirstRunTutorialAlsoLeadsToThePaywall() async {
        let d = UserDefaults.standard
        let saved = [SupernovaPaywallGate.pendingKey, SupernovaPaywallGate.shownKey, SupernovaService.subscribedMirrorKey, "devDataPlus"].map { ($0, d.object(forKey: $0)) }
        defer { saved.forEach { d.set($0.1, forKey: $0.0) } }
        d.set(true, forKey: SupernovaPaywallGate.pendingKey); d.set(false, forKey: SupernovaPaywallGate.shownKey); d.set(false, forKey: SupernovaService.subscribedMirrorKey); d.set(false, forKey: "devDataPlus")
        var posted = false
        let token = NotificationCenter.default.addObserver(forName: .showSupernovaPaywall, object: nil, queue: .main) { _ in posted = true }
        defer { NotificationCenter.default.removeObserver(token) }
        let vm = TutorialViewModel()
        vm.start(firstRun: true)
        vm.skip()
        #expect(posted)
    }
}
