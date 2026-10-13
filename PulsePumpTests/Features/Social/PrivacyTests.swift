import Testing
import Foundation
@testable import PulsePump

/// Privacy rows: defaults, persistence to users/{uid}.privacy, the profile mirror, and restore on a new device.
@MainActor
struct PrivacyTests {
    @Test func designDefaults() {
        let s = PrivacySettings.default
        #expect(s.workoutPosts == .friendsOnly && s.bodyMap == .friendsOnly)
        #expect(s.globalLeaderboardVisible && s.profile == .everyone)
        #expect(s.postAudience == .friends && s.bodyMapAudience == .friends && s.profileVisibility == .everyone)
    }

    @Test func firestoreMapUsesTheContractValues() {
        var s = PrivacySettings()
        s.workoutPosts = .onlyMe; s.bodyMap = .everyone; s.profile = .friendsOnly; s[.globalLeaderboards] = .onlyMe
        #expect(s.firestoreMap == ["workoutPosts": "onlyMe", "bodyMap": "everyone", "globalLeaderboards": "hidden", "profile": "friends"])
        #expect(PrivacySettings(firestoreMap: s.firestoreMap) == s)
    }

    @Test func decodingToleratesMissingAndUnknownValues() {
        let s = PrivacySettings(firestoreMap: ["workoutPosts": "bogus", "profile": "onlyMe", "extra": 1])
        #expect(s.workoutPosts == .friendsOnly)       // unknown -> default
        #expect(s.profile == .onlyMe)
        #expect(s.globalLeaderboardVisible)
    }

    @Test func globalBoardsAreVisibleOrHiddenOnly() {
        var s = PrivacySettings()
        s[.globalLeaderboards] = .friendsOnly         // not a real option: treated as visible
        #expect(s.globalLeaderboardVisible)
        #expect(PrivacyRow.globalLeaderboards.options == [.everyone, .onlyMe])
        #expect(PrivacyRow.globalLeaderboards.label(for: .onlyMe) == "Hidden")
        #expect(PrivacyRow.workoutPosts.options.count == 3)
    }

    @Test func localCopyRoundTrips() {
        let suite = UserDefaults(suiteName: "p-\(UUID().uuidString)")!
        var s = PrivacySettings(); s.bodyMap = .onlyMe; s.profile = .friendsOnly
        s.save(to: suite)
        #expect(PrivacySettings.load(defaults: suite) == s)
        #expect(PrivacySettings.load(defaults: UserDefaults(suiteName: "p-\(UUID().uuidString)")!) == .default)
    }

    @Test func changingARowSavesLocallyAndToTheAccount() async {
        let h = SocialHarness()
        await h.privacy.set(.bodyMap, to: .onlyMe)
        #expect(h.privacy.settings.bodyMap == .onlyMe)
        #expect(PrivacySettings.load(defaults: h.defaults).bodyMap == .onlyMe)
        #expect(h.remote.privacyDocument?.bodyMap == .onlyMe)
        #expect(h.remote.writtenPrivacy.count == 1)
        #expect(!h.privacy.needsPush)
    }

    @Test func profileVisibilityAndLeaderboardFlagAreMirroredToThePublicProfile() async {
        let h = SocialHarness()
        await h.privacy.set(.profile, to: .friendsOnly)
        #expect(h.remote.profiles["me"]?.profileVisibility == .friends)
        await h.privacy.set(.globalLeaderboards, to: .onlyMe)
        #expect(h.remote.profiles["me"]?.globalLeaderboardVisible == false)
        await h.privacy.set(.globalLeaderboards, to: .everyone)
        #expect(h.remote.profiles["me"]?.globalLeaderboardVisible == true)
    }

    @Test func viewModelPrivacySetterUpdatesItsOwnProfileState() async {
        let h = SocialHarness()
        await h.vm.loadMyProfile()
        await h.vm.setPrivacy(.profile, .onlyMe)
        #expect(h.vm.privacy.profile == .onlyMe)
        #expect(h.vm.myProfile?.profileVisibility == .onlyMe)
    }

    @Test func restoringOnANewDeviceAppliesTheStoredValues() async {
        let h = SocialHarness()
        var stored = PrivacySettings(); stored.workoutPosts = .onlyMe; stored.profile = .friendsOnly; stored[.globalLeaderboards] = .onlyMe
        h.remote.privacyDocument = stored
        #expect(h.privacy.settings == .default)               // fresh device
        await h.privacy.restore()
        #expect(h.privacy.settings == stored)
        #expect(PrivacySettings.load(defaults: h.defaults) == stored)
        #expect(h.remote.writtenPrivacy.isEmpty)              // restoring does not write back
    }

    @Test func firstSignInPublishesTheDefaultsAndCreatesTheProfile() async {
        let h = SocialHarness()
        await h.privacy.restore()
        #expect(h.remote.privacyDocument == .default)
        #expect(h.remote.profiles["me"]?.profileVisibility == .everyone)
    }

    @Test func anOfflineChangeIsKeptAndWinsOverTheServerLater() async {
        let h = SocialHarness()
        var older = PrivacySettings(); older.bodyMap = .everyone
        h.remote.privacyDocument = older
        h.remote.fail("savePrivacy")
        await h.privacy.set(.bodyMap, to: .onlyMe)
        #expect(h.privacy.settings.bodyMap == .onlyMe && h.privacy.needsPush)
        #expect(h.privacy.lastError != nil)

        h.remote.healAll()
        await h.privacy.restore()                              // must push the pending change, not overwrite it
        #expect(h.privacy.settings.bodyMap == .onlyMe)
        #expect(h.remote.privacyDocument?.bodyMap == .onlyMe)
        #expect(!h.privacy.needsPush)
    }

    @Test func nothingIsWrittenWhenSignedOut() async {
        let h = SocialHarness(signedIn: false)
        await h.privacy.set(.profile, to: .onlyMe)
        await h.privacy.restore()
        #expect(h.remote.writtenPrivacy.isEmpty && h.remote.privacyDocument == nil)
        #expect(h.privacy.settings.profile == .onlyMe)         // still applied locally
    }

    @Test func newPostsPickUpTheCurrentPrivacy() async {
        let h = SocialHarness()
        await h.privacy.set(.workoutPosts, to: .everyone)
        await h.privacy.set(.bodyMap, to: .onlyMe)
        let data = SocialTestData.completion(exercises: [SocialTestData.exercise("Bench", sets: [SocialTestData.set(100, 5)], primary: ["Chest"])])
        _ = await h.vm.publishWorkoutPost(data: data, caption: "", taggedUids: [], includeBodyMap: true)
        let p = h.remote.createdPosts.first
        #expect(p?.audience == .everyone && p?.bodyMapAudience == .onlyMe && p?.muscleSets == nil)
    }
}
