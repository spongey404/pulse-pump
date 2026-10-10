import Testing
import Foundation
import FirebaseFirestore
import SwiftData
@testable import PulsePump

/// Negative cases with the iOS client as the actor: the security rules must refuse, and the app's error mapping
/// must turn the refusal into the right `RemoteError` / `SocialError`.
@Suite("Permission denied against the emulator", .emulator, .serialized)
@MainActor
struct PermissionDeniedEmulatorTests {
    private func isDenied(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == FirestoreErrorDomain && ns.code == FirestoreErrorCode.permissionDenied.rawValue
    }

    @Test func anotherUsersWorkoutsCannotBeReadThroughTheSyncStore() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada")
            let mallory = try await world.account("mal")
            let phone = try SyncDevice.phone(for: ada)
            phone.user(); phone.workout(exercise: phone.exercise())
            try phone.ctx.save()
            await phone.sync()

            let spy = FirestoreRemoteStore(uid: ada.uid, db: mallory.db)   // Mallory pointing the sync store at Ada's uid
            do {
                _ = try await spy.fetchChanged(.workouts, sinceMs: 0, limit: 50, after: nil)
                Issue.record("reading another user's workouts must be refused")
            } catch let error as RemoteError {
                #expect(error.isPermanent, "got \(error)")
            }
            do {
                _ = try await spy.fetchDoc(.profile, id: ada.uid)
                Issue.record("reading another user's users/{uid} must be refused")
            } catch let error as RemoteError {
                #expect(error.isPermanent)
            }
        }
    }

    @Test func anotherUsersSyncDataCannotBeWritten() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada")
            let mallory = try await world.account("mal")
            let intruder = FirestoreRemoteStore(uid: ada.uid, db: mallory.db)
            let write = RemoteWrite(collection: .templates, id: UUID().uuidString.lowercased(),
                                    fields: ["name": "Hijacked", "exercises": [[String: Any]](), "updatedAt": 1, "schemaVersion": 1])
            do {
                try await intruder.batchWrite([write])
                Issue.record("writing into another user's account must be refused")
            } catch let error as RemoteError {
                #expect(error.isPermanent)
            }
            #expect(try await ada.store.allDocs(.templates).isEmpty)
        }
    }

    @Test func aSignedOutClientCanReadNothing() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let anon = world.anonymousClient()
            let remote = FirestoreSocialRemote(user: FirebaseCurrentUser(auth: anon.auth), db: anon.db)
            await #expect(throws: SocialError.self) { _ = try await remote.fetchProfile(uid: ada.uid) }
            do { _ = try await anon.db.document("usernames/\(ada.handle)").getDocument(); Issue.record("usernames need a signed-in user") }
            catch { #expect(isDenied(error)) }
        }
    }

    @Test func aFriendsOnlyPostCannotBeReadDirectlyByAStranger() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let fay = try await world.account("fay", profile: true)
            let sid = try await world.account("sid", profile: true)
            try await ada.befriend(fay)
            let post = IntegrationData.post(by: ada, audience: .friends)
            try await ada.social.createPost(post)

            #expect(await fay.exists("posts/\(post.postId)"))
            do { _ = try await sid.db.document("posts/\(post.postId)").getDocument(); Issue.record("stranger read a friends-only post") }
            catch { #expect(isDenied(error)) }
        }
    }

    @Test func aClientCannotPublishAPostAsSomeoneElse() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let mal = try await world.account("mal", profile: true)
            var forged = IntegrationData.post(by: ada, audience: .everyone)
            forged.authorUid = ada.uid
            // The app refuses locally...
            await #expect(throws: SocialError.invalid("Author mismatch")) { try await mal.social.createPost(forged) }
            // ...and the rules refuse a raw write that bypasses the app's guard.
            let data = SocialWire.postDocument(forged, now: Date()).mapValues { $0 is Date ? Timestamp(date: $0 as! Date) : $0 }
            do { try await mal.db.document("posts/forged").setData(data); Issue.record("forged post accepted") }
            catch { #expect(isDenied(error)) }
        }
    }

    @Test func serverOwnedCountersCannotBeSetByTheClient() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            do { try await ada.db.document("profiles/\(ada.uid)").updateData(["friendCount": 999]); Issue.record("friendCount is function-owned") }
            catch { #expect(isDenied(error)) }

            let post = IntegrationData.post(by: ada, audience: .everyone)
            try await ada.social.createPost(post)
            do { try await ada.db.document("posts/\(post.postId)").updateData(["likeCount": 50]); Issue.record("likeCount is function-owned") }
            catch { #expect(isDenied(error)) }
        }
    }

    @Test func challengeEntriesAreNotWritableByClients() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await ada.social.createChallenge(IntegrationData.challenge())
            try await ada.social.joinChallenge(id: id, username: ada.handle)
            do {
                try await ada.db.document("challenges/\(id)/entries/\(ada.uid)").setData(["uid": ada.uid, "score": 1_000_000])
                Issue.record("a client wrote its own score")
            } catch { #expect(isDenied(error)) }
        }
    }

    @Test func globalChallengesCannotBeCreatedByClients() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            var data = SocialWire.challengeDocument(IntegrationData.challenge(), creator: ada.uid, now: Date())
            data["isGlobal"] = true
            data = data.mapValues { $0 is Date ? Timestamp(date: $0 as! Date) : $0 }
            do { try await ada.db.document("challenges/sneaky").setData(data); Issue.record("client created a global challenge") }
            catch { #expect(isDenied(error)) }
        }
    }

    @Test func theUsernameCollectionCannotBeListedOrOverwritten() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let mal = try await world.account("mal", profile: true)
            do { _ = try await mal.db.collection("usernames").getDocuments(); Issue.record("usernames were listed") }
            catch { #expect(isDenied(error)) }
            do { try await mal.db.document("usernames/\(ada.handle)").setData(["uid": mal.uid, "createdAt": Timestamp(date: Date())]); Issue.record("handle stolen") }
            catch { #expect(isDenied(error)) }
            do { try await mal.db.document("usernames/\(ada.handle)").delete(); Issue.record("handle released by a stranger") }
            catch { #expect(isDenied(error)) }
            #expect(try await mal.document("usernames/\(ada.handle)")?["uid"] as? String == ada.uid)
        }
    }

    @Test func anotherUsersInvitesAreInvisible() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let cat = try await world.account("cat", profile: true)
            let id = try await ada.social.createChallenge(IntegrationData.challenge())
            try await ada.social.sendInvite(challengeId: id, challengeName: "Volume Week", fromUsername: ada.handle, toUid: bea.uid)
            do { _ = try await cat.db.document("invites/\(id)_\(bea.uid)").getDocument(); Issue.record("cat read Bea's invite") }
            catch { #expect(isDenied(error)) }
            #expect(try await cat.social.fetchPendingInvites().isEmpty)
        }
    }

    @Test func aBlockedUsersContentMapsToPermissionDeniedNotNotFound() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let post = IntegrationData.post(by: bea, audience: .everyone)
            try await bea.social.createPost(post)
            try await bea.social.block(BlockedUser(uid: ada.uid, username: ada.handle, displayName: "Ada", createdAt: Date()))
            // The app must not be able to tell "blocked" from "private": both are one error.
            await #expect(throws: SocialError.permissionDenied) {
                _ = try await ada.social.fetchPosts(PostQuery(authorUids: [bea.uid], audiences: [.everyone], before: nil, limit: 5))
            }
        }
    }
}
