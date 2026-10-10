import Testing
import Foundation
@testable import PulsePump

/// The `deleteAccount` callable (Functions emulator) driven by the app's own auth provider and session.
@Suite("Account deletion against the emulator", .emulator, .serialized)
@MainActor
struct AccountDeletionEmulatorTests {
    /// An account that has produced every kind of data the function has to clean up.
    private struct Populated {
        let leaver: TestAccount
        let friend: TestAccount
        let postId: String
        let friendPostId: String
        let challengeId: String
    }

    private func populate(_ world: EmulatorWorld) async throws -> Populated {
        let leaver = try await world.account("leaver", profile: true)
        let friend = try await world.account("fay", profile: true)
        try await leaver.befriend(friend)

        let post = IntegrationData.post(by: leaver, audience: .everyone, muscleSets: ["chest": 5])
        try await leaver.social.createPost(post)
        let friendPost = IntegrationData.post(by: friend, audience: .friends)
        try await friend.social.createPost(friendPost)
        try await leaver.social.setLike(postId: friendPost.postId, liked: true)
        _ = try await leaver.social.addComment(postId: friendPost.postId, text: "nice", authorName: "Leaver", authorUsername: leaver.handle)

        let challenge = try await friend.social.createChallenge(IntegrationData.challenge())
        try await friend.social.sendInvite(challengeId: challenge, challengeName: "Volume Week", fromUsername: friend.handle, toUid: leaver.uid)
        try await leaver.social.joinChallenge(id: challenge, username: leaver.handle)

        try await IntegrationData.logWorkout(for: leaver)
        // The follow counters are function-maintained; wait until the pair really are friends before deleting.
        await Emulator.eventually { await friend.profileCount("friendCount") == 1 }
        return Populated(leaver: leaver, friend: friend, postId: post.postId, friendPostId: friendPost.postId, challengeId: challenge)
    }

    @Test func deletingTheAccountRemovesAllOfItsDataAndTheAuthUser() async throws {
        try await Emulator.isolated { world in
            let p = try await populate(world)
            let uid = p.leaver.uid
            let handle = p.leaver.handle

            try await p.leaver.authProvider.callDeleteAccount()

            #expect(await Emulator.adminDocumentExists("users/\(uid)") == false)
            #expect(await Emulator.adminDocumentExists("profiles/\(uid)") == false)
            #expect(await Emulator.adminDocumentExists("usernames/\(handle)") == false, "the handle is released")
            #expect(await Emulator.adminCount("users/\(uid)/workouts") == 0)
            #expect(await Emulator.adminDocumentExists("posts/\(p.postId)") == false)
            #expect(await Emulator.adminDocumentExists("posts/\(p.postId)/extras/bodymap") == false)
            #expect(await Emulator.adminDocumentExists("follows/\(uid)_\(p.friend.uid)") == false)
            #expect(await Emulator.adminDocumentExists("follows/\(p.friend.uid)_\(uid)") == false)
            #expect(await Emulator.adminDocumentExists("challenges/\(p.challengeId)/members/\(uid)") == false)
            #expect(await Emulator.adminDocumentExists("invites/\(p.challengeId)_\(uid)") == false)
            #expect(await Emulator.adminDocumentExists("posts/\(p.friendPostId)/likes/\(uid)") == false)
            #expect(await Emulator.adminCount("posts/\(p.friendPostId)/comments") == 0)

            // The friend's own data is untouched and their counters are repaired.
            #expect(await Emulator.adminDocumentExists("posts/\(p.friendPostId)"))
            #expect(await Emulator.adminDocumentExists("profiles/\(p.friend.uid)"))
            // KNOWN SERVER BUG (firebase/functions/src/accountDeletion.ts): deleteAccount removes both follow edges
            // back to back, so onFollowWritten usually sees the reverse edge already gone, treats the first deletion as a
            // plain fan removal, and the friend keeps friendCount 1. Remove the wrapper once the function repairs counters.
            await withKnownIssue("friend's friendCount is not repaired when the leaver deletes the account", isIntermittent: true) {
                let repaired = await Emulator.eventually(timeout: 8) {
                    let friends = await p.friend.profileCount("friendCount")
                    let fans = await p.friend.profileCount("fanCount")
                    return friends == 0 && fans == 0
                }
                #expect(repaired)
            }
            #expect(await Emulator.eventually {
                let doc = try await p.friend.document("posts/\(p.friendPostId)")
                return doc?["likeCount"] as? Int == 0 && doc?["commentCount"] as? Int == 0
            }, "like and comment counters follow the deleted like and comment")
        }
    }

    @Test func theAuthUserIsGoneSoTheOldCredentialsNoLongerSignIn() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            try await a.authProvider.callDeleteAccount()

            let client = world.anonymousClient()
            let provider = FirebaseAuthProvider(auth: client.auth, functions: client.functions)
            do {
                _ = try await provider.signIn(email: a.email, password: a.password)
                Issue.record("a deleted account must not sign in")
            } catch let failure as AuthFailure {
                #expect(failure == .invalidCredentials || failure == .userNotFound, "got \(failure)")
            }
        }
    }

    @Test func authSessionDeleteAccountWipesLocalDataAndSignsOut() async throws {
        try await Emulator.isolated { world in
            let client = world.anonymousClient()
            let lifecycle = NoOpSyncLifecycle(owner: "someone")
            let session = AuthSession(provider: FirebaseAuthProvider(auth: client.auth, functions: client.functions), lifecycle: lifecycle)
            session.start()
            #expect(await session.signUp(email: "leaving@example.com", password: "secret-pass-1"))
            let uid = try #require(session.user?.uid)

            try await session.deleteAccount(password: "secret-pass-1")
            #expect(session.state == .signedOut)
            #expect(lifecycle.wipeCount == 1)
            #expect(await Emulator.adminDocumentExists("users/\(uid)") == false)
        }
    }

    @Test func deletingWhileSignedOutFailsWithNotSignedIn() async throws {
        try await Emulator.isolated { world in
            let client = world.anonymousClient()
            let provider = FirebaseAuthProvider(auth: client.auth, functions: client.functions)
            await #expect(throws: AuthFailure.notSignedIn) { try await provider.callDeleteAccount() }
        }
    }

    @Test func aChallengeOnlyTheLeaverCreatedAndNobodyJoinedIsDeletedWithThem() async throws {
        try await Emulator.isolated { world in
            let a = try await world.account("ada", profile: true)
            let lonely = try await a.social.createChallenge(IntegrationData.challenge(name: "Lonely"))
            try await a.authProvider.callDeleteAccount()
            #expect(await Emulator.adminDocumentExists("challenges/\(lonely)") == false)
        }
    }
}
