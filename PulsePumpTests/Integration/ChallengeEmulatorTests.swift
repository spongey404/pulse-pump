import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// Challenges end to end: the iOS client creates, invites and joins; workouts reach Firestore through the real sync
/// engine; the `onMemberWritten` / `onWorkoutWritten` Cloud Functions score and rank the entries.
@Suite("Challenges against the emulator", .emulator, .serialized)
@MainActor
struct ChallengeEmulatorTests {
    private func create(_ owner: TestAccount, _ draft: ChallengeDraft? = nil) async throws -> String {
        try await owner.social.createChallenge(draft ?? IntegrationData.challenge())
    }

    private func invite(_ id: String, from owner: TestAccount, to guest: TestAccount, name: String = "Volume Week") async throws {
        try await owner.social.sendInvite(challengeId: id, challengeName: name, fromUsername: owner.handle, toUid: guest.uid)
    }

    private func entry(_ id: String, of account: TestAccount, as viewer: TestAccount) async -> ChallengeEntry? {
        guard let e = try? await viewer.social.fetchLeaderboard(challengeId: id, isGlobal: false, limit: 50) else { return nil }
        return e.first { $0.uid == account.uid }
    }

    // MARK: Create, join, leave

    @Test func aCreatedChallengeIsReadBackWithItsRulesAndTheCreatorOwnsIt() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await create(ada, IntegrationData.challenge(metric: .heaviestLift, name: "Bench Club", exerciseName: "Barbell Bench Press"))
            let c = try await ada.social.fetchChallenge(id: id)
            #expect(c.name == "Bench Club" && c.metric == .heaviestLift && c.exerciseName == "Barbell Bench Press")
            #expect(c.creatorUid == ada.uid && c.status == .active && !c.isGlobal && c.visibility == .invite)
            #expect(try await ada.social.fetchMyChallenges().map(\.id) == [id])
        }
    }

    @Test func theCreatorJoiningMakesTheMemberCountOne() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await create(ada)
            try await ada.social.joinChallenge(id: id, username: ada.handle)
            #expect(try await ada.social.isMember(challengeId: id))
            #expect(await Emulator.eventually { (try await ada.social.fetchChallenge(id: id)).memberCount == 1 })
        }
    }

    @Test func leavingRemovesTheEntryAndLowersTheMemberCount() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await create(ada)
            try await ada.social.joinChallenge(id: id, username: ada.handle)
            #expect(await Emulator.eventually { await entry(id, of: ada, as: ada) != nil }, "joining places the member on the board")

            try await ada.social.leaveChallenge(id: id)
            #expect(await Emulator.eventually { await entry(id, of: ada, as: ada) == nil })
            #expect(await Emulator.eventually { (try await ada.social.fetchChallenge(id: id)).memberCount == 0 })
            #expect(try await ada.social.isMember(challengeId: id) == false)
        }
    }

    @Test func joiningWithoutAnInviteIsRefused() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let sid = try await world.account("sid", profile: true)
            let id = try await create(ada)
            await #expect(throws: SocialError.permissionDenied) { try await sid.social.joinChallenge(id: id, username: sid.handle) }
            await #expect(throws: SocialError.permissionDenied) { _ = try await sid.social.fetchChallenge(id: id) }
        }
    }

    @Test func myChallengesListsCreatedAndJoinedOnes() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let mine = try await create(ada, IntegrationData.challenge(name: "Mine"))
            let theirs = try await create(bea, IntegrationData.challenge(name: "Theirs"))
            try await invite(theirs, from: bea, to: ada)
            try await ada.social.joinChallenge(id: theirs, username: ada.handle)

            let listed = try await ada.social.fetchMyChallenges()   // creator query + members collection-group query
            #expect(Set(listed.map(\.id)) == [mine, theirs])
        }
    }

    // MARK: Invites

    @Test func anInviteUsesTheChallengeAndRecipientIdAndLetsTheGuestJoin() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let id = try await create(ada)
            try await invite(id, from: ada, to: bea)

            let pending = try await bea.social.fetchPendingInvites()
            let received = try #require(pending.first)
            #expect(pending.count == 1 && received.id == "\(id)_\(bea.uid)")
            #expect(received.fromUid == ada.uid && received.challengeName == "Volume Week" && received.status == .pending)
            #expect(await ada.exists("invites/\(id)_\(bea.uid)"))

            #expect(try await bea.social.fetchChallenge(id: id).id == id, "an invite makes a private challenge readable")
            try await bea.social.respondToInvite(received, accept: true)
            try await bea.social.joinChallenge(id: id, username: bea.handle)
            #expect(try await bea.social.fetchPendingInvites().isEmpty)
            #expect(await Emulator.eventually { (try await ada.social.fetchChallenge(id: id)).memberCount == 1 })
        }
    }

    @Test func sendingTheSameInviteTwiceIsHarmless() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let id = try await create(ada)
            try await invite(id, from: ada, to: bea)
            try await invite(id, from: ada, to: bea)
            #expect(try await bea.social.fetchPendingInvites().count == 1)
        }
    }

    @Test func decliningAnInviteRemovesItFromThePendingList() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let id = try await create(ada)
            try await invite(id, from: ada, to: bea)
            let received = try #require(try await bea.social.fetchPendingInvites().first)
            try await bea.social.respondToInvite(received, accept: false)
            #expect(try await bea.social.fetchPendingInvites().isEmpty)
        }
    }

    @Test func aGuestWhoIsNotTheCreatorOrAMemberCannotInviteOthers() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let cat = try await world.account("cat", profile: true)
            let id = try await create(ada)
            try await invite(id, from: ada, to: bea)   // bea is invited but has not joined
            await #expect(throws: SocialError.permissionDenied) { try await invite(id, from: bea, to: cat) }
        }
    }

    // MARK: Scoring from synced workouts

    @Test func joiningScoresTheWorkoutsAlreadyLoggedInTheWindow() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let volume = try await IntegrationData.logWorkout(for: ada)
            let id = try await create(ada)
            try await ada.social.joinChallenge(id: id, username: ada.handle)

            let scored = await Emulator.eventually(timeout: 20) { await entry(id, of: ada, as: ada)?.score == volume }
            #expect(scored, "expected \(volume) kg of working volume (the warm-up never counts)")
            #expect(await entry(id, of: ada, as: ada)?.rank == 1)
        }
    }

    @Test func aWorkoutLoggedAfterJoiningUpdatesTheScore() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await create(ada)
            try await ada.social.joinChallenge(id: id, username: ada.handle)
            #expect(await Emulator.eventually { await entry(id, of: ada, as: ada) != nil })

            let volume = try await IntegrationData.logWorkout(for: ada)
            #expect(await Emulator.eventually(timeout: 20) { await entry(id, of: ada, as: ada)?.score == volume })
        }
    }

    @Test func twoMembersAreRankedByScoreAndReranked() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let bea = try await world.account("bea", profile: true)
            let id = try await create(ada)
            try await invite(id, from: ada, to: bea)
            try await ada.social.joinChallenge(id: id, username: ada.handle)
            try await bea.social.joinChallenge(id: id, username: bea.handle)

            let adaVolume = try await IntegrationData.logWorkout(for: ada, sets: [(60, 8), (100, 5)])          // 500
            let beaVolume = try await IntegrationData.logWorkout(for: bea, sets: [(60, 8), (120, 5), (120, 5)]) // 1200
            #expect(adaVolume == 500 && beaVolume == 1_200)

            let ranked = await Emulator.eventually(timeout: 20) {
                let board = try await ada.social.fetchLeaderboard(challengeId: id, isGlobal: false, limit: 10)
                return board.map(\.uid) == [bea.uid, ada.uid] && board.map(\.rank) == [1, 2]
            }
            #expect(ranked)
            let board = try await ada.social.fetchLeaderboard(challengeId: id, isGlobal: false, limit: 10)
            #expect(board.map(\.score) == [1_200, 500])
            #expect(try await ada.social.fetchMyEntry(challengeId: id)?.rank == 2)

            // Ada overtakes Bea with a second session.
            try await IntegrationData.logWorkout(for: ada, sets: [(60, 8), (140, 6), (140, 6)], daysAgo: 2)
            let overtaken = await Emulator.eventually(timeout: 20) {
                try await ada.social.fetchMyEntry(challengeId: id)?.rank == 1
            }
            #expect(overtaken)
            #expect(try await bea.social.fetchMyEntry(challengeId: id)?.previousRank == 1)
        }
    }

    @Test func heaviestLiftScoresTheBestEstimatedOneRepMaxOfTheNamedExercise() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            try await IntegrationData.logWorkout(for: ada, sets: [(60, 8), (100, 5), (102.5, 3)])
            let id = try await create(ada, IntegrationData.challenge(metric: .heaviestLift, name: "Bench", exerciseName: "Barbell Bench Press"))
            try await ada.social.joinChallenge(id: id, username: ada.handle)

            // Epley: 100 x 5 -> 116.67 beats 102.5 x 3 -> 112.75; the 60 kg warm-up never counts.
            #expect(await Emulator.eventually(timeout: 20) { abs((await entry(id, of: ada, as: ada)?.score ?? 0) - 116.67) < 0.01 })
        }
    }

    @Test func aWorkoutOutsideTheWindowDoesNotScore() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            try await IntegrationData.logWorkout(for: ada, daysAgo: 30)
            let id = try await create(ada)
            try await ada.social.joinChallenge(id: id, username: ada.handle)
            #expect(await Emulator.eventually { await entry(id, of: ada, as: ada) != nil })
            try? await Task.sleep(for: .seconds(1))
            #expect(await entry(id, of: ada, as: ada)?.score == 0)
        }
    }

    @Test func softDeletingASyncedWorkoutRemovesItFromTheScore() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let id = try await create(ada)
            try await ada.social.joinChallenge(id: id, username: ada.handle)

            let phone = try SyncDevice.phone(for: ada)
            phone.user()
            let workout = phone.workout(exercise: phone.exercise())
            try phone.ctx.save()
            await phone.sync()
            let volume = 100.0 * 5 + 102.5 * 3
            #expect(await Emulator.eventually(timeout: 20) { await entry(id, of: ada, as: ada)?.score == volume })

            try phone.edit(workout) { $0.softDelete() }
            await phone.sync()
            #expect(await Emulator.eventually(timeout: 20) { await entry(id, of: ada, as: ada)?.score == 0 })
        }
    }

    @Test func aMemberOutsideTheChallengeCannotReadTheLeaderboard() async throws {
        try await Emulator.isolated { world in
            let ada = try await world.account("ada", profile: true)
            let sid = try await world.account("sid", profile: true)
            let id = try await create(ada)
            try await ada.social.joinChallenge(id: id, username: ada.handle)
            await #expect(throws: SocialError.permissionDenied) {
                _ = try await sid.social.fetchLeaderboard(challengeId: id, isGlobal: false, limit: 10)
            }
        }
    }
}
