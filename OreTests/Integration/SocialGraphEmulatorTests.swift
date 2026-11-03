import Testing
import Foundation
import FirebaseFirestore
@testable import Ore

/// Follows, friends/fans, blocks, privacy and reports through `FirestoreSocialRemote`; the friend and fan counters
/// are maintained by the `onFollowWritten` Cloud Function (so these tests poll for them).
@Suite("Social graph against the emulator", .emulator, .serialized)
@MainActor
struct SocialGraphEmulatorTests {
    private func counts(_ viewer: TestAccount, of target: TestAccount) async -> (friends: Int?, fans: Int?) {
        (await viewer.profileCount("friendCount", of: target.uid), await viewer.profileCount("fanCount", of: target.uid))
    }

    @Test func followWritesAnEdgeVisibleToBothSides() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await ada.social.follow(uid: bea.uid)

            let following = try await ada.social.fetchFollowing()
            #expect(following.map(\.followeeUid) == [bea.uid])
            let followers = try await bea.social.fetchFollowers()
            #expect(followers.map(\.followerUid) == [ada.uid])
            #expect(await ada.exists("follows/\(ada.uid)_\(bea.uid)"))
        }
    }

    @Test func aOneWayFollowMakesTheFolloweeAFanNotAFriend() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await ada.social.follow(uid: bea.uid)

            let settled = await Emulator.eventually { await counts(ada, of: bea) == (0, 1) }
            #expect(settled, "bea should have 0 friends and 1 fan")
            #expect(await counts(bea, of: ada) == (0, 0))
        }
    }

    @Test func followingBackTurnsTheFanIntoAFriendOnBothProfiles() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await ada.befriend(bea)

            let settled = await Emulator.eventually {
                let onBea = await counts(ada, of: bea), onAda = await counts(bea, of: ada)
                return onBea == (1, 0) && onAda == (1, 0)
            }
            #expect(settled, "both profiles should end with one friend and no fans")
        }
    }

    @Test func unfollowingAFriendMakesThemAFanAgain() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await ada.befriend(bea)
            await Emulator.eventually { await counts(ada, of: bea) == (1, 0) }

            try await ada.social.unfollow(uid: bea.uid)
            // bea still follows ada, so ada has one fan (bea) and no friends; bea has no friends and no fans.
            let settled = await Emulator.eventually {
                let onAda = await counts(bea, of: ada), onBea = await counts(ada, of: bea)
                return onAda == (0, 1) && onBea == (0, 0)
            }
            #expect(settled, "ada keeps bea as a fan; nobody keeps a friend")
            #expect(await ada.exists("follows/\(ada.uid)_\(bea.uid)") == false)
        }
    }

    @Test func unfollowingAStrangerWhoWasAFanDropsTheCounterToZero() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await ada.social.follow(uid: bea.uid)
            await Emulator.eventually { await counts(ada, of: bea) == (0, 1) }
            try await ada.social.unfollow(uid: bea.uid)
            #expect(await Emulator.eventually { await counts(ada, of: bea) == (0, 0) })
        }
    }

    @Test func followingTheSamePersonTwiceDoesNotDoubleCount() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await ada.social.follow(uid: bea.uid)
            try await ada.social.follow(uid: bea.uid)
            await Emulator.eventually { await counts(ada, of: bea).fans == 1 }
            try? await Task.sleep(for: .seconds(1))   // give a spurious second event time to land
            #expect(await counts(ada, of: bea) == (0, 1))
        }
    }

    @Test func followingYourselfIsRefusedBeforeItReachesTheServer() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            await #expect(throws: SocialError.invalid("Can't follow yourself")) { try await ada.social.follow(uid: ada.uid) }
        }
    }

    @Test func aBlockedUserCannotFollowTheirBlocker() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await bea.social.block(BlockedUser(uid: ada.uid, username: ada.handle, displayName: "Ada", createdAt: Date()))
            await #expect(throws: SocialError.permissionDenied) { try await ada.social.follow(uid: bea.uid) }
        }
    }

    @Test func blockAndUnblockRoundTripThroughTheBlockedList() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            try await ada.social.block(BlockedUser(uid: bea.uid, username: bea.handle, displayName: "Bea", createdAt: Date()))
            let blocked = try await ada.social.fetchBlocked()
            #expect(blocked.map(\.uid) == [bea.uid] && blocked.first?.username == bea.handle)
            try await ada.social.unblock(uid: bea.uid)
            #expect(try await ada.social.fetchBlocked().isEmpty)
        }
    }

    @Test func aBlockHidesTheBlockersProfileFromTheBlockedUser() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            #expect(try await ada.social.fetchProfile(uid: bea.uid).username == bea.handle)
            try await bea.social.block(BlockedUser(uid: ada.uid, username: ada.handle, displayName: "Ada", createdAt: Date()))
            await #expect(throws: SocialError.permissionDenied) { _ = try await ada.social.fetchProfile(uid: bea.uid) }
            await #expect(throws: SocialError.permissionDenied) { _ = try await bea.social.fetchProfile(uid: ada.uid) }   // a block hides both ways
        }
    }

    @Test func privacyWritesAreAcceptedAndMirrorTheProfileVisibility() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            var settings = PrivacySettings.default
            settings.profile = .onlyMe
            settings.globalLeaderboards = .onlyMe
            settings.workoutPosts = .everyone
            try await ada.social.savePrivacy(settings)

            #expect(try await ada.social.loadPrivacy() == settings)
            let profile = try #require(try await ada.document("profiles/\(ada.uid)"))
            #expect(profile["profileVisibility"] as? String == "onlyMe")
            #expect(profile["globalLeaderboardVisible"] as? Bool == false)
            await #expect(throws: SocialError.permissionDenied) { _ = try await bea.social.fetchProfile(uid: ada.uid) }
        }
    }

    @Test func aFriendsOnlyProfileIsOpenToFriendsAndClosedToStrangers() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let friend = try await world.account("fay", profile: true)
            let stranger = try await world.account("sid", profile: true)
            try await ada.befriend(friend)
            var settings = PrivacySettings.default
            settings.profile = .friendsOnly
            try await ada.social.savePrivacy(settings)

            #expect(try await friend.social.fetchProfile(uid: ada.uid).username == ada.handle)
            await #expect(throws: SocialError.permissionDenied) { _ = try await stranger.social.fetchProfile(uid: ada.uid) }
            // Search by handle still finds the user, but without the private profile.
            let lookup = try #require(try await stranger.social.lookupUser(handle: ada.handle))
            #expect(lookup.uid == ada.uid && lookup.profile == nil)
        }
    }

    @Test func reportsOfEveryTargetTypeAreAcceptedAndCannotBeReadBack() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            for target in [ReportTarget.post, .comment, .user, .challenge] {
                try await ada.social.report(target: target, targetId: "some-\(target.rawValue)", reason: "spam", details: "details")
            }
            try await ada.social.report(target: .user, targetId: bea.uid, reason: "abuse", details: nil)
            #expect(await Emulator.adminCount("reports") == 5)
            await #expect(throws: (any Error).self) { _ = try await ada.db.collection("reports").getDocuments() }
        }
    }
}
