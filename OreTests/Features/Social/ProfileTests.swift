import Testing
import Foundation
@testable import Ore

/// Profile pages honour privacy and relationship: visible, private, deleted, blocked; lift history is real.
@MainActor
struct ProfileTests {
    private typealias T = SocialTestData

    private func ex(_ name: String, _ sets: [FeedSetLog]) -> FeedExercise { T.exercise(name, sets: sets) }

    // MARK: Access states

    @Test func accessRulesMapReadResults() {
        let p = FirestoreUserProfile(uid: "u", username: "u_u", displayName: "U")
        #expect(ProfileAccessRules.access(for: .success(p)) == .visible)
        #expect(ProfileAccessRules.access(for: .failure(.permissionDenied)) == .restricted)
        #expect(ProfileAccessRules.access(for: .failure(.notFound)) == .unavailable)
        #expect(ProfileAccessRules.access(for: .failure(.unavailable("x"))) == .restricted)
    }

    @Test func aStrangerSeesAPublicProfileAndOnlyPublicPosts() async {
        let h = SocialHarness()
        h.remote.addProfile("s", name: "Sam", handle: "sam")
        h.post("pub", by: "s", audience: .everyone); h.post("fr", by: "s", audience: .friends)
        let page = await h.vm.loadProfilePage(uid: "s")
        #expect(page.access == .visible && page.relationship == .stranger)
        #expect(page.posts.map(\.id) == ["pub"])
        #expect(h.remote.postQueries.last?.audiences == [.everyone])
    }

    @Test func aFanGetsTheSameViewAsAStranger() async {
        let h = SocialHarness()
        h.remote.addProfile("f", name: "Fan", handle: "fan"); h.remote.setFollow("f", follows: "me")
        h.post("pub", by: "f", audience: .everyone); h.post("fr", by: "f", audience: .friends)
        await h.vm.loadGraph()
        let page = await h.vm.loadProfilePage(uid: "f")
        #expect(page.relationship == .fan && page.posts.map(\.id) == ["pub"])
    }

    @Test func aFriendAlsoSeesFriendsOnlyPostsAndTheBodyMap() async {
        let h = SocialHarness()
        h.friend("a", name: "Ann", handle: "ann")
        h.post("pub", by: "a", audience: .everyone, ageMinutes: 2, bodyMap: ["Chest": 6])
        h.post("fr", by: "a", audience: .friends, ageMinutes: 1, bodyMap: ["Back": 4])
        await h.vm.loadGraph()
        let page = await h.vm.loadProfilePage(uid: "a")
        #expect(page.relationship == .friends)
        #expect(Set(page.posts.map(\.id)) == ["pub", "fr"])
        #expect(h.remote.postQueries.last?.audiences == [.everyone, .friends])
        #expect(page.posts.allSatisfy { $0.includesBodyMap })
    }

    @Test func aStrangerDoesNotGetAFriendsOnlyBodyMapOnAPublicPost() async {
        let h = SocialHarness()
        h.remote.addProfile("s", name: "Sam", handle: "sam")
        h.post("pub", by: "s", audience: .everyone, bodyMapAudience: .friends, bodyMap: ["Chest": 6])
        let page = await h.vm.loadProfilePage(uid: "s")
        #expect(page.posts.count == 1 && !page.posts[0].includesBodyMap)
    }

    @Test func aPrivateProfileShowsOnlyTheRestrictedState() async {
        let h = SocialHarness()
        h.remote.addProfile("p", name: "Priv", handle: "priv", visibility: .onlyMe)
        h.post("pub", by: "p", audience: .everyone)
        let page = await h.vm.loadProfilePage(uid: "p")
        #expect(page.access == .restricted && page.profile == nil && page.posts.isEmpty)
        #expect(h.remote.postQueries.isEmpty)                  // no posts are requested for a private profile
    }

    @Test func aFriendsOnlyProfileOpensForFriendsButNotStrangers() async {
        let h = SocialHarness()
        h.remote.addProfile("fo", name: "FO", handle: "fo_user", visibility: .friends)
        #expect(await h.vm.loadProfilePage(uid: "fo").access == .restricted)
        h.remote.makeFriends("me", "fo")
        await h.vm.loadGraph()
        #expect(await h.vm.loadProfilePage(uid: "fo").access == .visible)
    }

    @Test func aDeletedAccountIsUnavailableAndDroppedFromLists() async {
        let h = SocialHarness()
        let page = await h.vm.loadProfilePage(uid: "ghost")        // no profile document any more
        #expect(page.access == .unavailable && page.posts.isEmpty)
        #expect(h.vm.goneUids.contains("ghost"))
    }

    @Test func aBlockedProfileIsNotFetched() async {
        let h = SocialHarness()
        h.remote.addProfile("b", name: "Bee", handle: "bee")
        await h.vm.loadGraph()
        _ = await h.vm.block(uid: "b", name: "Bee", handle: "bee")
        let page = await h.vm.loadProfilePage(uid: "b")
        #expect(page.relationship == .blocked && page.access == .restricted && page.profile == nil)
        #expect(h.remote.postQueries.isEmpty)
    }

    @Test func myOwnProfileRequestsEveryAudience() async {
        let h = SocialHarness()
        await h.vm.loadMyProfile()
        h.post("mine", by: "me", audience: .onlyMe)
        let page = await h.vm.loadProfilePage(uid: "me")
        #expect(page.relationship == .me && page.posts.map(\.id) == ["mine"])
        #expect(h.remote.postQueries.last?.audiences.isEmpty == true)
    }

    // MARK: Stats windows

    @Test func profileStatsUseThirtyDayAndSevenDayWindows() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func post(_ id: String, daysAgo: Int, prs: Int, sets: [FeedSetLog], muscles: [String: Int] = [:]) -> WorkoutFeedItem {
            let d = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            return WorkoutFeedItem(id: id, userId: "u", username: "U", exerciseCount: 1, durationSeconds: 0, prCount: prs, date: d,
                                   exercises: [T.exercise("Bench", sets: sets)], muscleSets: muscles)
        }
        let posts = [
            post("today", daysAgo: 0, prs: 1, sets: [T.set(100, 5), T.set(50, 10, "warmup")], muscles: ["Chest": 4]),
            post("three", daysAgo: 3, prs: 2, sets: [T.set(80, 10)], muscles: ["Chest": 3, "Back": 2]),
            post("old", daysAgo: 45, prs: 5, sets: [T.set(200, 10)], muscles: ["Chest": 50]),
        ]
        let stats = ProfileStats(posts: posts, now: now, calendar: cal)
        #expect(stats.volumeKg30d == 500 + 800)                       // warm-up and the 45-day-old session excluded
        #expect(stats.prs30d == 3)
        #expect(stats.muscleSets30d == ["Chest": 7, "Back": 2])
        #expect(stats.week.count == 7 && stats.trainedDaysThisWeek == 2)
        #expect(stats.week.last?.post?.id == "today")
        #expect(Set(stats.week.map(\.day)).count == 7)                // stable, distinct day ids
    }

    // MARK: Lift history (real posts only)

    @Test func liftHistoryOnlyFlagsARealPersonalBest() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func post(_ id: String, daysAgo: Int, _ sets: [FeedSetLog]) -> WorkoutFeedItem {
            WorkoutFeedItem(id: id, userId: "u", username: "U", exerciseCount: 1, durationSeconds: 0,
                            date: cal.date(byAdding: .day, value: -daysAgo, to: now)!, exercises: [T.exercise("Bench Press", sets: sets), T.exercise("Row", sets: [T.set(60, 8)])])
        }
        let sessions = LiftHistory.sessions(from: [post("c", daysAgo: 1, [T.set(105, 3)]),
                                                   post("a", daysAgo: 20, [T.set(40, 8, "warmup"), T.set(100, 5)]),
                                                   post("b", daysAgo: 10, [T.set(95, 6)])], exerciseName: "bench press")
        #expect(sessions.map(\.id) == ["a", "b", "c"])                // oldest first
        #expect(sessions.map(\.isPR) == [false, false, true])         // the first session is the baseline, never a PR
        #expect(sessions[0].bestWeight == 100)                         // warm-up ignored
    }

    @Test func liftHistoryIsEmptyWhenTheyNeverPostedThatLift() {
        let item = WorkoutFeedItem(userId: "u", username: "U", exerciseCount: 1, durationSeconds: 0, date: Date(), exercises: [T.exercise("Squat", sets: [T.set(100, 5)])])
        #expect(LiftHistory.sessions(from: [item], exerciseName: "Lateral Raise").isEmpty)
    }

    @Test func oneRepMaxUsesEpleyAndTreatsASingleAsTheWeight() {
        func session(_ sets: [FeedSetLog]) -> LiftSession { LiftSession(id: "s", date: Date(), sets: sets, isPR: false) }
        #expect(LiftHistory.estimatedOneRepMax(sessions: [session([T.set(100, 1)])]) == 100)
        let epley = LiftHistory.estimatedOneRepMax(sessions: [session([T.set(90, 8)])])
        #expect(abs((epley ?? 0) - 114) < 0.001)                       // 90 x (1 + 8/30)
        // The best across sets wins: 90x8 (114) beats 100x1 (100).
        #expect(abs((LiftHistory.estimatedOneRepMax(sessions: [session([T.set(100, 1), T.set(90, 8)])]) ?? 0) - 114) < 0.001)
        #expect(LiftHistory.estimatedOneRepMax(sessions: [session([T.set(0, 12)])]) == nil)   // bodyweight: no external load
    }

    @Test func weightChangeNeedsTwoSessions() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func s(_ days: Int, _ w: Double) -> LiftSession { LiftSession(id: "\(days)", date: now.addingTimeInterval(Double(-days) * 86_400), sets: [T.set(w, 5)], isPR: false) }
        #expect(LiftHistory.weightChange(sessions: [s(1, 100)], now: now) == nil)
        #expect(LiftHistory.weightChange(sessions: [s(90, 80), s(40, 90), s(1, 100)], now: now) == 20)   // closest to 12 weeks ago is day 90
    }

    @Test func viewModelLiftHistoryComesFromRealPostsAndFailsHonestly() async {
        let h = SocialHarness()
        h.friend("a")
        h.post("p1", by: "a", audience: .friends, exercises: [ex("Bench Press", [T.set(100, 5)])])
        await h.vm.loadGraph()
        let ok = await h.vm.loadLiftHistory(ownerUid: "a", exerciseName: "Bench Press")
        #expect(ok?.count == 1)
        #expect((await h.vm.loadLiftHistory(ownerUid: "a", exerciseName: "Lateral Raise"))?.isEmpty == true)   // empty, not invented
        h.remote.fail("fetchPosts")
        #expect(await h.vm.loadLiftHistory(ownerUid: "a", exerciseName: "Bench Press") == nil)
    }
}
