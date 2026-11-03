import Testing
import Foundation
import CoreGraphics
@testable import Ore

@MainActor
struct PostSystemTests {
    private func post(photo: String? = nil, song: PostSong? = nil) -> WorkoutFeedItem {
        var p = WorkoutFeedItem(id: "p1", userId: "u1", username: "Priya", handle: "priya", templateName: "Full Body", exerciseCount: 2, durationSeconds: 4325,
                                prCount: 1, totalExercises: 2, date: Date(), exercises: [
            FeedExercise(id: "e1", name: "Back Squat", sets: [FeedSetLog(weight: 100, reps: 5, duration: 0, distance: 0, setType: "standard", side: nil),
                                                              FeedSetLog(weight: 60, reps: 8, duration: 0, distance: 0, setType: "warmup", side: nil)]),
            FeedExercise(id: "e2", name: "Bench Press", sets: [FeedSetLog(weight: 80, reps: 5, duration: 0, distance: 0, setType: "standard", side: nil)])])
        p.photoURL = photo; p.song = song
        return p
    }

    // MARK: Wire

    @Test func photoSongAndTagsRoundTripThroughTheWireFormat() throws {
        let song = PostSong(title: "Song", artist: "Artist", artworkURL: "https://a/b.jpg", previewURL: "https://a/p.m4a", appleMusicId: "123")
        let payload = PostPayload(postId: "p1", authorUid: "u1", authorName: "Priya", authorUsername: "priya", date: Date(), workoutName: "Full Body",
                                  audience: .friends, bodyMapAudience: .friends, stats: .init(sets: 1, volumeKg: 500, durationSec: 60, prCount: 0),
                                  exercises: [], caption: "hi", taggedUids: ["a", "b"], muscleSets: nil,
                                  photoURL: "https://a/photo.jpg", song: song, taggedNames: ["Sam", "Jordan"], editedAt: Date())
        let doc = SocialWire.postDocument(payload, now: Date())
        #expect(doc["photoURL"] as? String == "https://a/photo.jpg")
        #expect(doc["taggedNames"] as? [String] == ["Sam", "Jordan"])
        #expect(doc["editedAt"] != nil)
        let item = try #require(SocialWire.post(from: doc, id: "p1"))
        #expect(item.song == song)
        #expect(item.taggedNames == ["Sam", "Jordan"])
        #expect(item.photoURL == "https://a/photo.jpg")
        #expect(item.isEdited == true)
    }

    @Test func aPostWithoutExtrasHasNoExtraFields() {
        let payload = PostPayload(postId: "p", authorUid: "u", authorName: "n", authorUsername: "h", date: Date(), workoutName: "w", audience: .friends,
                                  bodyMapAudience: .friends, stats: .init(sets: 0, volumeKg: 0, durationSec: 0, prCount: 0), exercises: [], caption: "",
                                  taggedUids: [], muscleSets: nil)
        let doc = SocialWire.postDocument(payload, now: Date())
        for k in ["photoURL", "song", "taggedNames", "editedAt"] { #expect(doc[k] == nil) }
    }

    @Test func onlyMeComposerPostsWithTheOnlyMeAudience() throws {
        let data = WorkoutCompletionData.preview
        let author = FeedPostBuilder.Author(uid: "u", name: "N", handle: "h")
        var privacy = PrivacySettings.default
        privacy.workoutPosts = .onlyMe
        #expect(FeedPostBuilder.makePayload(data: data, author: author, caption: "", taggedUids: [], includeBodyMap: true, privacy: privacy) == nil)
        let p = try #require(FeedPostBuilder.makePayload(data: data, author: author, caption: "", taggedUids: [], includeBodyMap: true, privacy: privacy,
                                                         extras: PostExtras(onlyMe: true)))
        #expect(p.audience == .onlyMe)
    }

    // MARK: Composer

    private func friend(_ uid: String, _ name: String) -> FirestoreUserProfile { FirestoreUserProfile(uid: uid, username: name.lowercased(), displayName: name) }

    @Test func friendSearchShowsNothingUntilTypedAndNeverOffersTaggedFriends() {
        let friends = [friend("1", "Sam"), friend("2", "Jordan"), friend("3", "Samantha")]
        #expect(PostComposerModel.matches(friends, query: "", excluding: []) == nil)
        #expect(PostComposerModel.matches(friends, query: "  ", excluding: []) == nil)
        #expect(PostComposerModel.matches(friends, query: "sam", excluding: [])?.map(\.uid) == ["1", "3"])
        #expect(PostComposerModel.matches(friends, query: "sam", excluding: [friends[0]])?.map(\.uid) == ["3"])
        #expect(PostComposerModel.matches(friends, query: "zzz", excluding: [])?.isEmpty == true)
    }

    @Test func taggingClearsTheFieldAndDedupes() {
        let m = PostComposerModel()
        m.friendQuery = "sam"
        m.tag(friend("1", "Sam")); m.tag(friend("1", "Sam"))
        #expect(m.tagged.count == 1 && m.friendQuery.isEmpty)
        m.untag(m.tagged[0])
        #expect(m.tagged.isEmpty)
        m.onlyMe = true
        #expect(m.extras.onlyMe)
    }

    // MARK: Edit post

    @Test func editingSetsRecalculatesStatsAndPRs() {
        let edit = EditPostModel(post: post())
        #expect(edit.workingSetCount == 2)
        edit.addSet(to: "e1")
        #expect(edit.exercises[0].sets.last?.isNew == true && edit.exercises[0].sets.last?.weightKg == 60)   // copies the last set
        edit.exercises[0].sets[0].weightKg = 120
        let r = edit.recalculate { name in
            name == "Back Squat" ? .init(sets: [(weight: 100, reps: 5)]) : .init(sets: [])
        }
        #expect(r.prCount == 1)                          // 120 beats the earlier 100; bench has no history, so it is a baseline
        #expect(r.sets == 3)                             // warm-up excluded: squat 120 + the new set, plus bench 80
        #expect(r.exercises[0].weightDelta == 20)
        #expect(r.improved == 1)
    }

    @Test func removingTheLastSetRemovesTheExerciseAndNeedsOneLeft() {
        let edit = EditPostModel(post: post())
        edit.removeSet(edit.exercises[1].sets[0].id, from: "e2")
        #expect(edit.exercises.count == 1)
        edit.removeSet(edit.exercises[0].sets[0].id, from: "e1"); edit.removeSet(edit.exercises[0].sets[0].id, from: "e1")
        #expect(edit.exercises.isEmpty && !edit.isValid)
    }

    @Test func onlyTheAuthorCanUpdateAPostOnTheFakeRemote() async throws {
        let remote = FakeSocialRemote(meUid: "u1")
        let item = post()
        try await remote.createPost(PostPayload(postId: item.id, authorUid: "u1", authorName: "P", authorUsername: "p", date: Date(), workoutName: "W", audience: .friends,
                                                bodyMapAudience: .friends, stats: .init(sets: 1, volumeKg: 1, durationSec: 1, prCount: 0), exercises: item.exercises,
                                                caption: "a", taggedUids: [], muscleSets: nil))
        var edit = PostPayload(postId: item.id, authorUid: "u1", authorName: "P", authorUsername: "p", date: Date(), workoutName: "W", audience: .friends,
                               bodyMapAudience: .friends, stats: .init(sets: 1, volumeKg: 1, durationSec: 1, prCount: 0), exercises: item.exercises,
                               caption: "edited", taggedUids: [], muscleSets: nil, editedAt: Date())
        try await remote.updatePost(edit)
        #expect(remote.posts.first?.caption == "edited" && remote.posts.first?.isEdited == true)
        remote.meUid = "intruder"
        edit.authorUid = "intruder"
        await #expect(throws: (any Error).self) { try await remote.updatePost(edit) }
    }

    // MARK: Challenge

    @Test func beatAPRRulesAndTargets() {
        var m = DirectChallengeModel()
        #expect(m.canSend)                                   // volume needs no lift
        m.count = .beatPR
        #expect(!m.canSend)                                  // SEND disabled until a lift is picked
        m.toggle("Back Squat"); m.toggle("Bench Press"); m.toggle("Bench Press")
        #expect(m.lifts == ["Back Squat"] && m.canSend)
        m.increment = 5
        #expect(m.target(for: "Back Squat", mine: ["Back Squat": 140], theirs: ["Back Squat": 150]) == 145)
        m.beat = .theirs
        #expect(m.target(for: "Back Squat", mine: ["Back Squat": 140], theirs: ["Back Squat": 150]) == 150)
        let rows = m.vsRows(mine: ["Back Squat": 140], theirs: ["Back Squat": 150])
        #expect(rows[0].themHigher && !rows[0].youHigher)
    }

    @Test func strongestLiftsComeFirstAndDraftsMapToMetrics() {
        #expect(DirectChallengeModel.strongest(["A": 50, "B": 120, "C": 80, "Z": 0]).map(\.name) == ["B", "C", "A"])
        var m = DirectChallengeModel(); m.length = .month
        let d = m.draft(me: "Me", them: "Priya", now: Date(timeIntervalSince1970: 0))
        #expect(d.metric == .totalVolume && d.endAt.timeIntervalSince(d.startAt) >= 29 * 86_400 && d.visibility == .invite)
        m.count = .sessions
        #expect(m.draft(me: "a", them: "b").metric == .sessionsLogged)
        m.count = .beatPR; m.lifts = ["Deadlift"]
        #expect(m.draft(me: "a", them: "b").exerciseName == "Deadlift")
        #expect(DirectChallengeModel.pendingLine(length: .week, name: "Priya") == "PENDING · 1 WEEK · WAITING FOR PRIYA")
    }

    @Test func pendingChallengeIsRememberedPerFriend() {
        let d = UserDefaults(suiteName: "pending-\(UUID().uuidString)")!
        PendingDirectChallenges.record(uid: "x", length: .twoWeeks, challengeId: "c1", defaults: d)
        #expect(PendingDirectChallenges.pending(uid: "x", defaults: d)?.length == .twoWeeks)
        #expect(PendingDirectChallenges.pending(uid: "y", defaults: d) == nil)
        PendingDirectChallenges.clear(uid: "x", defaults: d)
        #expect(PendingDirectChallenges.pending(uid: "x", defaults: d) == nil)
    }

    // MARK: Share card + drafts

    @Test func shareCardLoopIsSeamless() {
        let s = ShareTwinkle.stars(count: 20, seed: 1)
        for star in s { #expect(abs(ShareTwinkle.level(star, t: 0) - ShareTwinkle.level(star, t: ShareCardModel.loopSeconds)) < 1e-9) }
        #expect(abs(ShareTwinkle.tickerOffset(t: 0, tile: 500)) < 1e-9)
        #expect(abs(ShareTwinkle.tickerOffset(t: 3, tile: 500) + 250) < 1e-9)
        #expect(ShareCardModel.frameCount == 180)
    }

    @Test func freeUsersGetOnlyTheClassicCard() {
        #expect(ShareCardModel.styles(member: false) == [.classic])
        #expect(ShareCardModel.styles(member: true) == [.ticker, .classic])
    }

    @Test func draftsAreSavedAndDiscarded() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PostDraftStore(defaults: UserDefaults(suiteName: "drafts-\(UUID().uuidString)")!, folder: dir)
        let payload = PostPayload(postId: "abc", authorUid: "u", authorName: "n", authorUsername: "h", date: Date(), workoutName: "w", audience: .friends,
                                  bodyMapAudience: .friends, stats: .init(sets: 1, volumeKg: 1, durationSec: 1, prCount: 0), exercises: [], caption: "later",
                                  taggedUids: [], muscleSets: nil)
        store.save(payload, photoJPEG: Data([1, 2, 3]))
        let d = try #require(store.draft(forWorkout: "ABC"))
        #expect(d.payload.caption == "later" && store.photo(of: d) == Data([1, 2, 3]))
        store.discard(workout: "abc")
        #expect(!store.hasDraft(forWorkout: "abc"))
    }

    @Test func summaryDecidesBetweenShrinkAndSlide() {
        let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)
        #expect(WorkoutSummaryPage.mapIsVisible(map: CGRect(x: 0, y: 100, width: 400, height: 500), viewport: viewport))
        #expect(WorkoutSummaryPage.mapIsVisible(map: CGRect(x: 0, y: -450, width: 400, height: 500), viewport: viewport))     // partly on screen
        #expect(!WorkoutSummaryPage.mapIsVisible(map: CGRect(x: 0, y: -600, width: 400, height: 500), viewport: viewport))    // fully scrolled off
    }

    @Test func documentExercisesFlagPRsAndVsLast() {
        let e = post().exercises[0]
        #expect(WorkoutDocumentExercises.bestSetIndex(e) == 0)
        var up = e; up.weightDelta = 5
        #expect(WorkoutDocumentExercises.vsLast(up, unit: .kg).tone == .up)
        var down = e; down.weightDelta = -2.5
        #expect(WorkoutDocumentExercises.vsLast(down, unit: .kg).tone == .down)
        #expect(WorkoutDocumentExercises.vsLast(e, unit: .kg).text == "—")
    }
}
