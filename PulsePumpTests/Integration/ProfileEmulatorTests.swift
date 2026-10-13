import Testing
import Foundation
import FirebaseFirestore
@testable import PulsePump

/// Account creation and username ownership (`FirestoreProfileRemote`, `FirestoreSocialRemote.ensureOwnProfile`).
@Suite("Profile and username claim against the emulator", .emulator, .serialized)
@MainActor
struct ProfileEmulatorTests {
    @Test func createAccountWritesUserProfileAndUsernameTogether() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            try await a.createProfile(unit: "lbs")

            let user = try #require(try await a.document("users/\(a.uid)"))
            #expect(user["username"] as? String == a.handle)
            #expect(user["unit"] as? String == "lbs")
            #expect(user["weightKg"] as? Double == 68)

            let profile = try #require(try await a.document("profiles/\(a.uid)"))
            #expect(profile["username"] as? String == a.handle)
            #expect(profile["displayName"] as? String == a.displayName)
            #expect(profile["friendCount"] == nil && profile["fanCount"] == nil, "counters belong to functions")

            let handle = try #require(try await a.document("usernames/\(a.handle)"))
            #expect(handle["uid"] as? String == a.uid)
        }
    }

    @Test func cloudProfileExistsIsFalseUntilOnboardingFinishes() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            #expect(try await a.profileRemote.cloudProfileExists(uid: a.uid) == false)
            try await a.createProfile()
            #expect(try await a.profileRemote.cloudProfileExists(uid: a.uid))
        }
    }

    @Test func aTakenHandleIsRejectedAndNothingIsHalfCreated() async throws {
        try await Emulator.isolated { world in
            let first = try await world.account("ada", profile: true)
            let second = try await world.account("bea")
            await #expect(throws: ProfileRemoteError.handleTaken) {
                try await second.createProfile(handle: first.handle)
            }
            #expect(await second.exists("profiles/\(second.uid)") == false)
            #expect(await second.exists("users/\(second.uid)") == false)
            let owner = try #require(try await second.document("usernames/\(first.handle)"))
            #expect(owner["uid"] as? String == first.uid)
        }
    }

    @Test func handleAvailabilityDistinguishesFreeTakenAndOwn() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            let b = try await world.account("bea")
            #expect(try await b.profileRemote.isHandleAvailable("brand.new.handle", for: b.uid))
            #expect(try await b.profileRemote.isHandleAvailable(a.handle, for: b.uid) == false)
            #expect(try await a.profileRemote.isHandleAvailable(a.handle, for: a.uid), "an owner may keep their own handle")
        }
    }

    @Test func retryingCreateAccountAfterAHalfAppliedAttemptIsSafe() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            try await a.createProfile()
            try await a.createProfile()   // e.g. the app was killed after the batch committed, before it noticed
            #expect(await a.exists("profiles/\(a.uid)"))
            let handle = try #require(try await a.document("usernames/\(a.handle)"))
            #expect(handle["uid"] as? String == a.uid)
        }
    }

    @Test func renamingClaimsTheNewHandleAndReleasesTheOldOne() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            let other = try await world.account("bea")
            let newHandle = "renamed" + a.handle.suffix(6)
            try await a.profileRemote.changeHandle(uid: a.uid, from: a.handle, to: newHandle, displayName: "Ada L")

            #expect(await a.exists("usernames/\(a.handle)") == false, "old handle released")
            let claimed = try #require(try await a.document("usernames/\(newHandle)"))
            #expect(claimed["uid"] as? String == a.uid)
            #expect(try await a.document("profiles/\(a.uid)")?["username"] as? String == newHandle)
            #expect(try await a.document("profiles/\(a.uid)")?["displayName"] as? String == "Ada L")
            #expect(try await a.document("users/\(a.uid)")?["username"] as? String == newHandle)
            #expect(try await other.profileRemote.isHandleAvailable(a.handle, for: other.uid), "the old handle is free again")
        }
    }

    @Test func renamingToSomeoneElsesHandleFailsAndKeepsTheCurrentOne() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            let b = try await world.account("bea", profile: true)
            await #expect(throws: ProfileRemoteError.handleTaken) {
                try await b.profileRemote.changeHandle(uid: b.uid, from: b.handle, to: a.handle, displayName: "Bea")
            }
            #expect(try await b.document("usernames/\(b.handle)")?["uid"] as? String == b.uid)
            #expect(try await b.document("profiles/\(b.uid)")?["username"] as? String == b.handle)
        }
    }

    @Test func onboardingStoresTheDefaultPrivacyMapAndSocialCodeReadsItBack() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            let settings = try #require(try await a.social.loadPrivacy())
            #expect(settings == PrivacySettings.default)
        }
    }

    @Test func ensureOwnProfileCreatesOnceAndIsIdempotent() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let first = try await a.social.ensureOwnProfile(displayName: "Ada Lovelace", handleHint: "ada.lifts", privacy: .default)
            #expect(HandleRules.isValid(first.username))
            let second = try await a.social.ensureOwnProfile(displayName: "Someone Else", handleHint: "other", privacy: .default)
            #expect(second.username == first.username && second.displayName == "Ada Lovelace", "an existing profile is never overwritten")
            #expect(try await a.document("usernames/\(first.username)")?["uid"] as? String == a.uid)
        }
    }

    @Test func ensureOwnProfileFallsBackToANumberedHandleWhenTheHintIsTaken() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada")
            let b = try await world.account("bea")
            let first = try await a.social.ensureOwnProfile(displayName: "Sam", handleHint: "samlifts", privacy: .default)
            let second = try await b.social.ensureOwnProfile(displayName: "Sam", handleHint: "samlifts", privacy: .default)
            #expect(first.username == "samlifts")
            #expect(second.username != first.username && second.username.hasPrefix("samlifts"))
        }
    }

    @Test func lookingUpAHandleFindsTheOwnerAndTheirProfile() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            let b = try await world.account("bea")
            let found = try #require(try await b.social.lookupUser(handle: "@" + a.handle.uppercased()))
            #expect(found.uid == a.uid)
            #expect(found.profile?.displayName == a.displayName)
            #expect(try await b.social.lookupUser(handle: "nobody.here") == nil)
        }
    }
}
