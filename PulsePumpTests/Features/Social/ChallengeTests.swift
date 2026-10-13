import Testing
import Foundation
@testable import PulsePump

/// Challenges: join/leave, invites (`{challengeId}_{toUid}`), boards from function-written entries, windows.
@MainActor
struct ChallengeTests {
    private typealias T = SocialTestData
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(_ uid: String, _ score: Double, rank: Int, prev: Int? = nil, scoreAtDays: Double = 0, hidden: Bool = false) -> ChallengeEntry {
        ChallengeEntry(uid: uid, username: uid, score: score, rank: rank, previousRank: prev ?? rank,
                       scoreAt: base.addingTimeInterval(scoreAtDays * 86_400), hidden: hidden)
    }

    // MARK: Leaderboard ordering, ties, movement

    @Test func rowsFollowTheRanksTheFunctionsWrote() {
        let rows = Leaderboard.rows(from: [entry("c", 80, rank: 3), entry("a", 120, rank: 1), entry("b", 100, rank: 2)], me: "b")
        #expect(rows.map(\.entry.uid) == ["a", "b", "c"])
        #expect(rows.map(\.rank) == [1, 2, 3])
        #expect(rows.map(\.isMe) == [false, true, false])
    }

    @Test func tiesShareARankAndListEarliestScoreFirst() {
        let rows = Leaderboard.rows(from: [entry("late", 100, rank: 1, scoreAtDays: 2), entry("early", 100, rank: 1, scoreAtDays: 1), entry("low", 50, rank: 3)], me: nil)
        #expect(rows.map(\.entry.uid) == ["early", "late", "low"])
        #expect(rows.map(\.rank) == [1, 1, 3])                         // competition ranking: 1, 1, 3
    }

    @Test func unrankedBoardsGetCompetitionRanksLocally() {
        let unranked = [ChallengeEntry(uid: "a", username: "a", score: 100, scoreAt: base), ChallengeEntry(uid: "b", username: "b", score: 100, scoreAt: base.addingTimeInterval(5)),
                        ChallengeEntry(uid: "c", username: "c", score: 10, scoreAt: base)]
        let rows = Leaderboard.rows(from: unranked, me: nil)
        #expect(rows.map(\.rank) == [1, 1, 3] && rows.map(\.entry.uid) == ["a", "b", "c"])
        #expect(rows.allSatisfy { $0.movement == 0 })
    }

    @Test func movementArrowsComeFromPreviousRank() {
        #expect(Leaderboard.movement(rank: 2, previousRank: 5) == 3)    // up 3
        #expect(Leaderboard.movement(rank: 5, previousRank: 2) == -3)   // down 3
        #expect(Leaderboard.movement(rank: 4, previousRank: 4) == 0)    // unchanged
        #expect(Leaderboard.movement(rank: 4, previousRank: 0) == 0)    // new entry
        let rows = Leaderboard.rows(from: [entry("a", 9, rank: 1, prev: 3), entry("b", 8, rank: 2, prev: 1), entry("c", 7, rank: 3, prev: 3)], me: nil)
        #expect(rows.map(\.movement) == [2, -1, 0])
    }

    @Test func hiddenEntriesAreDroppedUnlessTheyAreMine() {
        let entries = [entry("a", 9, rank: 1), entry("me", 8, rank: 2, hidden: true), entry("x", 7, rank: 3, hidden: true)]
        #expect(Leaderboard.rows(from: entries, me: "me").map(\.entry.uid) == ["a", "me"])
        #expect(Leaderboard.rows(from: entries, me: nil).map(\.entry.uid) == ["a"])
    }

    @Test func gapToNextAndOrdinals() {
        let rows = Leaderboard.rows(from: [entry("a", 120, rank: 1), entry("b", 100, rank: 2), entry("c", 70, rank: 3)], me: "c")
        #expect(Leaderboard.gapToNext(rows: rows, mine: rows[2]) == 30)
        #expect(Leaderboard.gapToNext(rows: rows, mine: rows[0]) == nil)
        #expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 101].map(Leaderboard.ordinal) == ["1ST", "2ND", "3RD", "4TH", "11TH", "12TH", "13TH", "21ST", "22ND", "101ST"])
    }

    @Test func condensedBoardKeepsTopFiveAndTheNeighbourhood() {
        let entries = (1...60).map { entry("u\($0)", Double(1000 - $0), rank: $0) }
        let rows = Leaderboard.rows(from: entries, me: "u47")
        let kept = Leaderboard.condensed(rows: rows, mine: rows.first { $0.isMe })
        #expect(kept.map(\.row.rank) == [1, 2, 3, 4, 5, 45, 46, 47, 48, 49])
        #expect(kept.map(\.gapBefore) == [false, false, false, false, false, true, false, false, false, false])
    }

    // MARK: Boards through the view model

    @Test func memberBoardIsLoadedFromEntriesAndMarksMe() async {
        let h = SocialHarness()
        let c = T.challenge("c1", creator: "bob", start: base.addingTimeInterval(-86_400), end: base.addingTimeInterval(86_400 * 10))
        h.remote.challenges["c1"] = c
        h.remote.members["c1"] = ["me", "bob"]
        h.remote.entries["c1"] = [entry("bob", 200, rank: 1, prev: 2), entry("me", 150, rank: 2, prev: 1)]
        await h.vm.loadBoard(c)
        let board = h.vm.boards["c1"]
        #expect(board?.rows.map(\.entry.uid) == ["bob", "me"])
        #expect(board?.mine?.rank == 2 && board?.mine?.movement == -1)
        #expect(board?.isMember == true)
    }

    @Test func globalBoardNeverIncludesHiddenEntriesButShowsMyOwn() async {
        let h = SocialHarness()
        let c = T.challenge("g", creator: "pulse", global: true, start: base.addingTimeInterval(-86_400), end: base.addingTimeInterval(86_400))
        h.remote.challenges["g"] = c
        h.remote.members["g"] = ["me"]
        h.remote.entries["g"] = [entry("a", 100, rank: 1), entry("me", 50, rank: 2, hidden: true)]
        await h.vm.loadBoard(c)
        #expect(h.vm.boards["g"]?.rows.map(\.entry.uid) == ["a", "me"])      // my hidden entry comes from my own doc
        #expect(h.vm.boards["g"]?.mine?.rank == 2)
    }

    // MARK: Join / leave

    @Test func joiningAGlobalChallengeAddsMeAsAMember() async {
        let h = SocialHarness()
        let g = T.challenge("g", creator: "pulse", global: true, start: base.addingTimeInterval(-86_400), end: base.addingTimeInterval(86_400))
        h.remote.challenges["g"] = g
        #expect(await h.vm.join(g))
        #expect(h.remote.members["g"]?.contains("me") == true)
        #expect(h.vm.isJoined(g))
        #expect(await h.vm.leave(g))
        #expect(h.remote.members["g"]?.contains("me") == false && !h.vm.isJoined(g))
    }

    @Test func joiningAPrivateChallengeWithoutAnInviteIsRefused() async {
        let h = SocialHarness()
        let c = T.challenge("p", creator: "bob", start: base.addingTimeInterval(-86_400), end: base.addingTimeInterval(86_400))
        h.remote.challenges["p"] = c
        #expect(await h.vm.join(c) == false)
        #expect(h.remote.members["p"]?.contains("me") != true)
        #expect(h.vm.lastError != nil)
    }

    @Test func cannotJoinAnEndedChallenge() async {
        let h = SocialHarness()
        let g = T.challenge("old", creator: "pulse", global: true, start: base.addingTimeInterval(-86_400 * 30), end: base.addingTimeInterval(-86_400))
        h.remote.challenges["old"] = g
        #expect(await h.vm.join(g) == false)
        #expect(h.vm.lastError == "This challenge has ended.")
    }

    // MARK: Create

    @Test func creatingSendsANonGlobalDraftAndJoinsTheCreator() async {
        let h = SocialHarness()
        let draft = ChallengeDraft(name: "August Volume", metric: .totalVolume, startAt: base, endAt: base.addingTimeInterval(86_400 * 28))
        let id = await h.vm.createChallenge(draft)
        #expect(id == "ch1")
        #expect(h.remote.createdChallenges.count == 1)
        #expect(h.remote.challenges["ch1"]?.isGlobal == false)
        #expect(h.remote.members["ch1"]?.contains("me") == true)          // the creator is on the board
        #expect(h.vm.myChallenges.map(\.id) == ["ch1"])
    }

    @Test func aFailedCreateReportsAnErrorAndLeavesNothingBehind() async {
        let h = SocialHarness()
        h.remote.fail("createChallenge")
        #expect(await h.vm.createChallenge(ChallengeDraft(name: "x", metric: .mostReps, startAt: base, endAt: base.addingTimeInterval(1000))) == nil)
        #expect(h.vm.myChallenges.isEmpty && h.vm.lastError != nil)
    }

    // MARK: Invites

    @Test func invitesUseTheChallengeIdAndRecipientAsTheDocumentId() async {
        let h = SocialHarness()
        let c = T.challenge("c1", start: base, end: base.addingTimeInterval(86_400))
        h.remote.challenges["c1"] = c
        #expect(await h.vm.sendChallengeInvite(challenge: c, toUid: "bob"))
        #expect(h.remote.invites.keys.sorted() == ["c1_bob"])
        let invite = h.remote.invites["c1_bob"]
        #expect(invite?.status == .pending && invite?.fromUid == "me" && invite?.challengeName == "Challenge c1")
        #expect(await h.vm.sendChallengeInvite(challenge: c, toUid: "bob"))      // idempotent
        #expect(h.remote.invites.count == 1)
    }

    @Test func acceptingAnInviteJoinsTheChallenge() async {
        let h = SocialHarness()
        let c = T.challenge("c1", creator: "bob", start: base.addingTimeInterval(-3600), end: base.addingTimeInterval(86_400 * 7))
        h.remote.challenges["c1"] = c
        let invite = ChallengeInvite(challengeId: "c1", challengeName: c.name, fromUid: "bob", fromUsername: "bob", toUid: "me", createdAt: base)
        h.remote.invites[invite.id] = invite
        await h.vm.loadInvites()
        #expect(h.vm.pendingChallengeInvites.map(\.id) == ["c1_me"])
        #expect(await h.vm.respond(to: invite, accept: true))
        #expect(h.remote.members["c1"]?.contains("me") == true)               // the old code only flipped the status
        #expect(h.remote.invites["c1_me"]?.status == .accepted)
        #expect(h.vm.pendingChallengeInvites.isEmpty)
        #expect(h.vm.myChallenges.map(\.id) == ["c1"])
    }

    @Test func ignoringAnInviteDeclinesWithoutJoining() async {
        let h = SocialHarness()
        let invite = ChallengeInvite(challengeId: "c1", challengeName: "C", fromUid: "bob", fromUsername: "bob", toUid: "me", createdAt: base)
        h.remote.invites[invite.id] = invite
        #expect(await h.vm.respond(to: invite, accept: false))
        #expect(h.remote.invites["c1_me"]?.status == .declined)
        #expect(h.remote.members["c1"]?.contains("me") != true)
    }

    @Test func aFailedJoinKeepsTheInvitePending() async {
        let h = SocialHarness()
        let c = T.challenge("c1", creator: "bob", start: base.addingTimeInterval(-86_400 * 30), end: base.addingTimeInterval(-86_400))   // ended
        h.remote.challenges["c1"] = c
        let invite = ChallengeInvite(challengeId: "c1", challengeName: c.name, fromUid: "bob", fromUsername: "bob", toUid: "me", createdAt: base)
        h.remote.invites[invite.id] = invite
        await h.vm.loadInvites()
        #expect(await h.vm.respond(to: invite, accept: true) == false)
        #expect(h.remote.invites["c1_me"]?.status == .pending)
        #expect(h.vm.pendingChallengeInvites.count == 1)
    }

    @Test func invitesFromBlockedUsersAreHidden() async {
        let h = SocialHarness()
        let invite = ChallengeInvite(challengeId: "c1", challengeName: "C", fromUid: "bad", fromUsername: "bad", toUid: "me", createdAt: base)
        h.remote.invites[invite.id] = invite
        h.remote.addProfile("bad", name: "Bad", handle: "bad")
        await h.vm.loadGraph()
        _ = await h.vm.block(uid: "bad", name: "Bad", handle: "bad")
        await h.vm.loadInvites()
        #expect(h.vm.pendingChallengeInvites.isEmpty)
    }

    // MARK: Active / ended

    @Test func activeAndEndedAreDecidedByStatusAndEndDate() async {
        let h = SocialHarness()
        let now = h.clock.date
        let live = T.challenge("live", start: now.addingTimeInterval(-86_400), end: now.addingTimeInterval(86_400))
        let pastEnd = T.challenge("past", start: now.addingTimeInterval(-86_400 * 9), end: now.addingTimeInterval(-60))               // status still "active": the daily function hasn't run
        let flagged = T.challenge("flagged", start: now.addingTimeInterval(-86_400), end: now.addingTimeInterval(86_400), status: .ended)
        for c in [live, pastEnd, flagged] { h.remote.challenges[c.id] = c; h.remote.members[c.id] = ["me"] }
        await h.vm.loadChallenges()
        #expect(h.vm.activeFriendChallenges.map(\.id) == ["live"])
        #expect(Set(h.vm.endedChallenges.map(\.id)) == ["past", "flagged"])
        #expect(live.isActive(now: now) && pastEnd.isEnded(now: now) && flagged.isEnded(now: now))
    }

    @Test func oneFailingChallengeCallDoesNotBlankTheOthers() async {
        let h = SocialHarness()
        let now = h.clock.date
        h.remote.challenges["g"] = T.challenge("g", creator: "pulse", global: true, start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(86_400))
        h.remote.fail("fetchMyChallenges")
        await h.vm.loadChallenges()
        #expect(h.vm.globalChallenge?.id == "g")
        #expect(h.vm.challengesError != nil)
    }

    // MARK: Windows

    @Test func windowsDecideTheEndDate() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 12))!
        #expect(ChallengeWindow.oneWeek.endDate(from: start, calendar: cal) == cal.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        #expect(ChallengeWindow.fourWeeks.endDate(from: start, calendar: cal) == cal.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12)))
        #expect(ChallengeWindow.oneYear.endDate(from: start, calendar: cal) == cal.date(from: DateComponents(year: 2027, month: 10, day: 8, hour: 12)))
        #expect(ChallengeWindow.restOfMonth.endDate(from: start, calendar: cal) == cal.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59, second: 59)))
        let custom = cal.date(from: DateComponents(year: 2026, month: 12, day: 25))!
        #expect(ChallengeWindow.custom.endDate(from: start, customEnd: custom, calendar: cal) == custom)
    }

    @Test func aWindowIsNeverZeroLength() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ChallengeWindow.custom.endDate(from: start, customEnd: start.addingTimeInterval(-500)) > start)
        #expect(ChallengeWindow.allCases.allSatisfy { $0.endDate(from: start) > start })
    }
}
