# Audit: social-firestore

Scope read in full: SocialViewModel, FirestoreService (+ FirestoreChallenge/ChallengeInvite DTOs), FirebaseAuthService, AuthService, FirestoreModels, Challenge, all of Views/Social/** (incl. Components), plus the call sites that feed them (OnboardingViewModel, WorkoutViewModel.completeWorkout, WorkoutCompletionView composer, ProfileView/MoreTabView, PulsePumpApp deep links, PrivacyLevel/SettingsView). No firestore.rules or firestore.indexes.json exists in the repo, so security rules and indexes are unverifiable.

## Summary
- Challenge scoring does not exist. Nothing ever writes `LeaderboardEntry.score` or `rank`; `updateLeaderboardEntry` has zero callers. Every real challenge shows 0 / rank 0 for everyone. Custom-metric entry, "first to goal", lowest-wins and tie rules are all unimplemented.
- Demo data leaks into production in four places: feed, friends, challenges (including a fake global "August Volume" with 2,412 participants), and LiftHistory. Demo friends inflate the More-tab FOLLOWERS/FOLLOWING counts, and inviting them writes real invite docs.
- Privacy levels are `@AppStorage` only. They are never written to Firestore, never read when fetching, and never applied when posting. The code comments admit this, but the UI claims enforcement.
- Profile stats (`totalWorkouts`, streaks) are written once at onboarding with 0 and never updated, so every friend profile shows 0D streak / 0 workouts. Re-running onboarding on a new device resets them (`merge:true` with a full struct).
- Many wiring gaps: accepting a challenge invite never joins the challenge, joinChallenge has no UI, AdminChallengeView is unreachable, contacts matching searches emails against a username field, https invite/post/profile links have no handler, the ActivityView "Earlier" list is hardcoded, and "Don't post" does not stop the auto-share.
- Tests: only Codable round-trips of the Firestore models (FirestoreModelTests) and FriendshipStatus raw values. None of the VM, ranking, feed cache or challenge logic is covered.

## Findings

### CRITICAL

[CRITICAL] FirestoreService.swift:208 / SocialViewModel.swift:414-484 — Challenge scoring is never computed; leaderboards are permanently empty or zero
- `updateLeaderboardEntry` is the only code that sets rank/previousRank, and a repo-wide grep shows no caller. Nothing computes a score from workouts for any metric (totalVolume, heaviestLift, mostReps, longestHold, sessionsLogged, custom). `WorkoutViewModel.completeWorkout` never touches challenges.
- Scenario: create "Bench 100", join, log workouts. Expected: score and rank update. Actual: `LeaderboardEntry(userId:username:)` is created with score 0, rank 0 (Challenge.swift:140), and that is what is stored (FirestoreService.swift:173-176). ChallengesView shows "Position 0", `ChallengeEndedView` shows the winner as `board.first` with a score of 0, and "Gained" is 0.
- The per-metric rules (`ChallengeMetric.rule`, "Any session over 10 minutes", "Top estimated single, one exercise", "Best single hold") are only UI strings. No tie-break rule exists (ranks are `index+1` after an unstable-by-contract sort, :211-215). `.first` (first-to-goal) has no goal field at all and is ranked as `.highest` (:210 only special-cases `.lowest`). `.custom` has no entry UI, although the copy says "everyone types their own number".
- Fix: add a scorer (workout completion, or a Cloud Function) per metric, filtered to `startDate...endDate` and `joinedAt`, excluding warm-up sets. Call a transactional leaderboard update. Add a goal field for `.first`.

### HIGH

[HIGH] SocialViewModel.swift:260-271, 290-316, 416-440 — Demo feed, friends and challenges are shown to real signed-in users in production
- `loadFeed`: signed-in users with no friends and no own posts get `demoFeedItems` (:266), and also on any network error (:270). `loadFriends`: `friends = loadedFriends.isEmpty ? demoFriends` (:311) and `friends = demoFriends` on error (:314). `loadChallenges`: the demo global challenge is always injected if Firestore has none (:437), and demo friend challenges are injected if the user has no real data (:439-440). There is no `#if DEBUG` and no flag.
- Effects:
  - A new user sees fake posts from "alex_lifts" etc. and can like, comment on and report them. Those writes go to Firestore against nonexistent docs `demo-1` (`likePost` updateData fails silently, `reportPost` writes a `reports` doc for `demo-1`).
  - A real user sees a global "AUGUST VOLUME" card with rank 47 of 2,412, in October.
  - ProfileView.swift:143-144,177,186-221 and YourProfileView "Following" show 6 fake friends with fake workout counts.
  - A transient network error masks as demo data instead of an error state.
- Unfollowing the last real friend makes `loadFriends` return the demo friends again (:311), which look like new follows.
- Fix: gate all demo data behind `#if DEBUG` or a debug flag. Use real empty and error states.

[HIGH] SocialViewModel.swift:500-504 — Accepting a challenge invite never joins the challenge
- `respondToChallengeInvite` only sets the invite doc's `status` (FirestoreService.swift:242-246). It does not call `joinChallenge`, so `participantIds` and `leaderboard` are unchanged. Then `loadChallenges()` is called, which shows nothing new. Also, nothing ever uses `challengeInvites.status == accepted`.
- Expected: after ACCEPT the challenge appears in the user's list. Actual: the invite disappears and the user is not in the challenge.
- Fix: on accept, call `joinChallenge(id: invite.challengeId, ...)`.

[HIGH] SocialViewModel.swift:479 / views — No UI path to join a challenge (global or friend)
- `joinChallenge(id:username:)` has no callers outside the VM. The "6e" empty-state comment mentions "a JOIN action" on the global card, but ChallengesView.globalChallengeCard has none. The only entry into a challenge is creating one. For a real global challenge, nobody can ever appear on the leaderboard.

[HIGH] ChallengesView.swift:6-10 + FirestoreService.swift:179-190 — Every user sees every other user's non-global challenges in "Friend Challenges"
- `fetchActiveChallenges` is `isActive == true`, limit 50, with no participant or friend filter. `friendChallenges = myChallenges + activeChallenges.filter { !$0.isGlobal }`. Any user's private friend challenge (name, participants, leaderboard) is listed for all users, up to 50 most recent. The data is also readable by any client.
- Fix: only show `fetchUserChallenges` plus global ones; query globals with `isGlobal == true`.

[HIGH] CreateChallengeStep1View.swift:178-190 — "Runs for" window is ignored; custom exercise choice is wrong
- `endDate` is always now + 28 days regardless of `runsFor` (1week, restOfMonth, 1year, custom). The window picker only stores a label string. Scenario: pick "1 WEEK": it ends in 28 days.
- `.heaviestLift` ("one exercise") has no exercise picker; `customExercise` is only passed for `.custom`. For `.custom`, the row displays the placeholder "Bench Press" (:~66) while `customExercise` remains "", so `""` is stored.
- ChallengeEndedView.swift:129-136 "Run it again" also hardcodes 28 days and drops `customExercise/countBy/unit/winCondition`.
- Fix: compute `endDate` from `runsFor` (calendar-aware for restOfMonth), and add an exercise picker for heaviestLift.

[HIGH] ChallengesView.swift:35-38 — Ended challenges are listed as "Active" and `isActive` is never cleared
- Nothing sets `isActive = false`. `fetchUserChallenges` has no end filter, so ended challenges stay in the list and the header counts them: "N Active". The row is routed by `endDate < Date()` to the ended view, but the count is wrong. `isActive == true` global and friend queries also keep returning expired challenges (there is a 50 cap, so old ones will crowd out new ones).

[HIGH] AdminChallengeView.swift (whole file) — Unreachable, not gated, and ignores its own toggles
- No view references `AdminChallengeView` (grep: definition only). If it were reachable, there is no `isAdmin` check, so any user could create `isGlobal: true` challenges.
- Hardcoded copy "Announce on 1 Sep" and "STARTS 1 SEP"; start date is now + 1 month, end is now + 2 months (not the 1st of the month).
- `announceOnStart` and `leaderboardVisibleToAll` @State values are never passed to `createChallenge` (which has no params for them); the "top 50 + own rank" enforcement claimed on `FirestoreChallenge.leaderboardVisibleToAll` (FirestoreService.swift:274) exists nowhere (grep).
- It also calls `createChallenge`, which joins the admin as a participant and leaderboard entry (SocialViewModel.swift:470-474).

[HIGH] Privacy levels are not enforced anywhere (PrivacyLevel.swift, ActivityView.swift:91-125, SettingsView.swift:51)
- Four privacy rows are `@AppStorage("privacy_*")` only. grep shows no reader other than the display rows: not `shareWorkoutToFeed`, not `fetchFeed`, not `FriendProfileView`, not leaderboards, not `includesBodyMap`. The user-facing notes say "ONLY FRIENDS CAN VIEW YOUR PROFILE", "YOU'RE HIDDEN FROM GLOBAL BOARDS".
- Any signed-in user can read any `users/{uid}` and `feed` doc by query. `fetchFeed(friendUids:[anyUid])` in FriendProfileView.swift:140 and LiftHistoryView.swift:~252 does not check friendship. Spec gap (CLAUDE.md) "private mode shows only username, avatar, streak" is not implemented.
- Fix: write privacy fields to `users/{uid}` and enforce them in rules, or at least apply them client-side on post/fetch, and say "not enforced yet" if not.

[HIGH] Profile stats never synced; onboarding overwrites them — OnboardingViewModel.swift:147-153, FirestoreService.swift:17-19
- `createOrUpdateUserProfile` is called only at onboarding, with `totalWorkouts/currentStreak/longestStreak` = 0. Nothing updates them afterwards (grep: no other writer). All friend UI (FriendProfileView streak KPI :~92, YourProfileView :~63, ProfileView friend rows :200, InviteFriendsView streak) reads these, so they always show 0.
- `setData(from: profile, merge: true)` encodes every field, so a returning user who goes through onboarding on a new device (RootView: `users.isEmpty`) overwrites an existing remote profile's counts, `createdAt`, and `username` with defaults. CLAUDE.md claims "on sign-in it writes/updates profile"; there is no such code in FirebaseAuthService.
- Fix: update stats after `completeWorkout`, `merge` only changed fields (`setData(["totalWorkouts": n], merge: true)`), and don't rewrite `createdAt`.

[HIGH] WorkoutViewModel.swift:469-487 + WorkoutCompletionView.swift:516-587 — Auto-share posts before the composer; "Don't post" does not stop it; POST double-posts
- With `autoShareToFeed` defaulting to true, `completeWorkout` fire-and-forgets `shareWorkoutToFeed` immediately, with a random UUID and no caption. The composer then offers "Don't post — STAYS IN YOUR HISTORY, NOBODY SEES IT" and "Post without body map". Neither deletes or edits the already-published doc. `postAndDismiss` creates a second `WorkoutFeedItem()` with a new UUID, so friends see two posts.
- The two paths also use different usernames: `user.name` (auto) vs `Auth.displayName ?? "User"` (composer). Both use `userId: ... ?? ""` if signed out, which attempts a write with an empty userId.
- Fix: do not auto-post before the composer; or reuse a deterministic doc id per workout so the composer overwrites it, and make "Don't post" delete it.

[HIGH] LiftHistoryView.swift:259-262, 283-310 — Fabricated lift history shown as the friend's real data
- If no matching post is found (new lift, fetch error, the friend not having posted that lift, or a demo user), `sessions = demoSessions()`: six invented sessions (90 to 105 kg, with PR flags) under the friend's name for any exercise, e.g. Lateral Raise. The footer then says "SHOWING THIS YEAR · 6 SESSIONS".
- Fix: show the empty state ("NO LOGGED SESSIONS...", which already exists) instead.

[HIGH] FriendsListView.swift:~170-185 / SocialViewModel.swift:380-393 — Contacts matching can never match
- `findFriendsFromContacts` passes each email to `searchUsers`, which does a prefix query on the lowercase `username` field. The user profile has no email field (FirestoreUserProfile), and usernames are derived from names (no `@`). Result: always empty. Only the first 50 email addresses are sent (`prefix(50)` over emails, not contacts), each as a separate query.
- Also "Search by name or handle" only searches `username`; `displayName` is never queried.

[HIGH] ActivityView.swift:8-12 — Hardcoded fake notification history
- `earlierEvents = [("Priya liked your post","2H"), ("Jay joined Bench 100 Club","1D")]` is shown to every user under "Earlier". The TODO is in a comment only. There are no real likes/comments/joins notifications at all.

[HIGH] ActivityFeedView.swift:353-368 + PulsePumpApp.swift:66-72 — Comment count never updates; https share links are dead
- Comments: `CommentsView` creates its own `@State SocialViewModel()` (CommentsView.swift:12). `postComment` increments `feedItems[index].commentCount` on that private VM's empty array, so the feed card's count never changes locally. `FeedPostCard.item` is a `let`. Server-side count is only updated by the second, non-atomic write (see MEDIUM). In-sheet, the comment heart ("0") and "REPLY" are non-functional.
- Share links `https://pulsepump.app/post?id=`, `/invite?...`, `/u/<uid>` have no handler: `onOpenURL` routes non-`pulsepump` schemes to `GIDSignIn.handle`, and no associated-domains entitlement was found. The `ref` and `challenge` params are never consumed.

### MEDIUM

[MEDIUM] SocialViewModel.swift:334-336 / FriendProfileView.swift:70-81 / FirestoreService.swift:38-42 — Friend requests: no dedupe, no self-guard, no feedback, no rollback
- `sendFriendRequest` creates a new doc each time, without checking existing docs in either direction. A reciprocal request does not auto-accept. Double taps and re-follows create duplicates; `fetchFriendships` will then return multiple docs for the pair.
- No guard for `targetUid == uid`: the feed card's avatar opens FriendProfileView for your own post, which shows FOLLOW (and `isFollowing` false), so you can send a request to yourself.
- FriendProfileView flips to "FOLLOWING" immediately (optimistic) although the request is only pending. `try?` hides failures, so there is no rollback. In FriendsListView the FOLLOW button gives no state change at all. Outgoing pending requests are not listed anywhere.
- Fix: deterministic doc id (sorted uid pair), check existing, guard self.

[MEDIUM] SocialViewModel.swift:275-286 — Like toggle: no rollback, racy
- The optimistic mutation happens first, `try?` swallows failure, and there is no revert. Rapid taps spawn unordered tasks, so the final server state can disagree with the UI. Likes on demo posts and signed-out likes silently do nothing (`guard currentUid` returns without UI feedback). `likePost` writes to another user's doc, so it needs a rule that allows non-owners to modify `likes` only. Unverifiable (no rules in repo); likewise `commentCount`.

[MEDIUM] FirestoreService.swift:143-149 + SocialViewModel.swift:401-410 — Comment write is non-atomic; failures silent; username is not the handle
- Comment doc is `setData` (non-awaited sync-throwing overload, fire and forget) then a separate `updateData` increment. If the second fails (rules: non-owner cannot update the feed doc) the comment exists with the count unchanged. Use a batch or a transaction. The text field is cleared before success (CommentsView.swift:122), so a failed comment is lost silently. Signed-out: `postComment` returns silently.
- `username = Auth.displayName ?? "User"`: for Apple Sign-In with hidden name this yields "User", while the profile handle exists. Same for leaderboard entries ("You", SocialViewModel.swift:472) and invites ("A friend").
- `fetchComments` has limit 50, with no paging or ordering of newest.

[MEDIUM] SocialViewModel.swift:240-273 — Feed cache TTL logic
- The cache guard requires `!feedItems.isEmpty`; since demo items count as non-empty, a new user who posts their first workout keeps seeing demo items for up to 5 min (and own post is not shown). The cache is not invalidated after posting, accepting a friend, or unfollowing. `lastFeedFetch` is also not reset on sign-out/sign-in as a different user, and `feedItems/friends/pendingRequests` are not cleared (SocialTabView holds the VM in `@State`), so the previous account's data can show.
- `loadFeed` calls `fetchFriendUids` (two queries) on every refresh. `loadFriends` (two queries plus N sequential `fetchUserProfile` reads) is a separate, repeated fetch; ProfileView, MoreTabView, SocialTabView, CommentsView each create their own `SocialViewModel()`, so there are 3 independent caches and duplicate N+1 loads.
- `.task { await viewModel.loadFeed() }` in ActivityFeedView is on the ScrollView and reruns when the tab switches back. This is fine thanks to the TTL.

[MEDIUM] FirestoreService.swift:84-103 — Feed query shape
- `userId in [batch of 30]` + `order(by: date)` + `limit(50)` requires a composite index (userId, date) and returns up to 50 per batch of 30 friends; with more than 30 friends the merged result is not truncated (up to 50 x batches items decoded and held) and the sort is client-side. No pagination (`startAfter`); a feed can never go past 50 items. The `in` limit of 30 is correct only for the current Firestore limit. Own feed limit is 20 vs 50. Posts that fail to decode are silently dropped (`compactMap try?`).
- `fetchActiveChallenges` (isActive + order startDate), `fetchUserChallenges` (arrayContains + order startDate, **no limit**), `fetchPendingChallengeInvites` (toUid + status + order createdAt) also each need composite indexes. Unverified whether they exist (no indexes file in the repo); if missing, they throw and `loadChallenges` swallows it (`catch { active = []; mine = [] }`), which then shows demo challenges. Note `active` and `mine` share one do/catch: one failure wipes both.

[MEDIUM] FirestoreModels.swift:35-51,55-107 / FirestoreService.swift:250-303 — Newly added non-optional fields break decoding of older documents
- Verified with a standalone script: synthesized Codable does not use stored-property defaults. A doc missing `improvementScore` throws `keyNotFound`. FeedExercise (improvementScore, weightDelta, repsDelta, primaryMuscles, secondaryMuscles), WorkoutFeedItem (taggedFriendUids, includesBodyMap), FirestoreChallenge (runsFor, isGlobal, announceOnStart, leaderboardVisibleToAll) and LeaderboardEntry (joinedAt, previousRank) were all added in the redesign. Any doc written earlier is silently dropped by `compactMap { try? ... }`. Only matters if pre-redesign docs exist (unverified).
- Fix: custom `init(from:)` with `decodeIfPresent`.

[MEDIUM] FirestoreService.swift:166-177 + 205-222 — Challenge writes
- `joinChallenge` does two separate updates (participantIds, then leaderboard). Joining twice appends a duplicate `LeaderboardEntry`, because arrayUnion compares entire map values, and UUID/updatedAt differ. No membership check, no end-date check, and joinedAt is whatever the client says.
- The entire leaderboard lives in one array field of the challenge doc: a "global" challenge with thousands of participants will hit the 1 MiB doc limit and have write contention (each entry ~200 B => ~5k entries). `participantIds` is also in the same doc.
- `updateLeaderboardEntry` (dead code) replaces the whole array from a client-supplied copy (lost updates between concurrent clients), derives `previousRank = entry.rank` from the stale input, reads winCondition with `try?` (silently defaults to highest if decode fails), and with `.lowest` would rank score-0 (not yet participated) users first.

[MEDIUM] ChallengeEndedView.swift:93-112 — "Gained"/"Your Best" semantics wrong
- `gained = score − last place's score` is not progress made during the challenge; it is the gap above last place (so the last-place finisher always shows "+0", and with the demo 112/105/97/90/78 it prints +34 for the winner, not "gained"). Winner = `board.first` even if all scores are 0 or tie. "Ended" state is based only on `endDate < Date()`, not `isActive`.

[MEDIUM] GlobalLeaderboardView.swift:6-40 — Leaderboard presentation
- Friends filter keeps global ranks (OK) but `myEntry` / pinned row uses `board`, which is filtered, so it is hidden if the user isn't in it. When the user is in the top 5 the pinned row duplicates a visible row. Privacy `globalLeaderboards = onlyMe` is not honored (see HIGH). `friendUids` is built from `viewModel.friends`, which may be the demo list. Rank gap detection `entry.rank - lastRank > 1` assumes distinct ranks (ties are impossible by construction, see CRITICAL).

[MEDIUM] FriendProfileView.swift:140-143, YourProfileView.swift:~37-64 — Profile stats are mislabeled/unbounded
- `fetchFeed` returns up to 50 posts of all time. "30-day body map", "This Wk", "PRs", "Volume" are computed over all of them, not 30 days or a week. YourProfileView labels "PRs · 30D" but sums `fetchOwnFeed` (20 latest, any age). "This Wk" in Your profile uses `.weekOfYear` (locale-dependent week start, not Monday); in the friend view `last7Days` is a rolling 7 days.
- `last7Days` is a computed property built from `Date()` and used as `ForEach(id: \.date)`, so ids change on every body evaluation (view identity churn, repeated filter work). Only the first post of a day is shown (`first`), and the "›" affordance on day rows does nothing.
- When opened from a feed card, the profile is synthesized with `displayName = username` and zero stats, then replaced by `fetchUserProfile` (OK), but the pre-fetch state shows `0D` streak. `try?` on the fetch means a failed fetch silently stays at zeros.
- Volume sums include warm-up sets (`FeedSetLog.setType` is available but not filtered): ActivityFeedView.swift:417-420, YourProfile/FriendProfile volumeLabel, and `muscleSetCounts` (BodyHeat+Exercises.swift:12-26) count every set, including warm-ups. (`WidgetDataService.friendSessions` does exclude "warmup", so the two disagree.)

[MEDIUM] LiftHistoryView.swift:23-65, 252-279 — Lift history formulas
- `est1RM`: derived from the heaviest set only, not max e1RM across sets/sessions (a 100x1 beats 90x8 = 114, so a rep-set can be the true best). It truncates with `Int()` instead of rounding (Epley 100x1 = 103.33 -> 103; some apps treat 1 rep as the weight itself). For weight 0 (bodyweight/timed) it returns `Double(reps)` and presents it as "EST 1RM" in kg. Time-based/distance sets have `weight 0` and show "BEST EVER —/0" and a flat chart.
- `isPR` is computed from `runningBest = 0` over only the fetched window (the latest 50 posts across all exercises), so the oldest visible session is always flagged "PR" even if the friend lifted heavier earlier. Warm-up sets are not excluded from `bestWeight` or volume.
- `twelveWeekDelta` uses the first session inside the 12-week window as baseline (not "closest to 12 weeks ago"), and falls back to all-time first session when none is in the window, still labeled "12 WK". The footer "SHOWING THIS YEAR" is static, and "History · N Sessions" counts all sessions while the table shows only 6.
- `equipmentLabel` (:26-30) runs `modelContext.fetch(FetchDescriptor<Exercise>())` (the full exercise table) on every body evaluation (perf).
- Chart baseline (min − 2.5 kg) was traced: equal values draw full-height bars; single session fine; range 0 handled by the `guard heaviest > baseline`. OK.

[MEDIUM] FeedSessionSheet (ActivityFeedView.swift:493-496) — PR flags are a heuristic
- `isPR` = the top `item.prCount` exercises by `improvementScore`. If improvementScores are all 0 (first sessions, which is when PRs are most common), arbitrary exercises (stable-sort order) are labeled PR. `FeedExercise` carries no per-exercise PR flag.

[MEDIUM] FirestoreService.swift:26-34 — User search
- Prefix query on `username` only; no debounce or cancellation in FriendsListView (`onChange` spawns a `Task` per keystroke), so out-of-order responses can show stale results. Already-friends and pending users are shown with FOLLOW. Uniqueness of `username` is never enforced (derived from name by lowercasing and removing spaces, OnboardingViewModel.swift:~147): two "John Smith" users get the same handle and the same search result. Anyone can query all users (privacy "Profile" row not applied).

[MEDIUM] SocialViewModel.swift:343-359 — Remove/unfollow semantics
- Friendship is symmetric (`accepted` doc between two users, `userId1/userId2/requestedBy`) but the UI uses follow/following/followers vocabulary. "UNFOLLOW" deletes the friendship for both sides. "IGNORE" on a request and Unfollow use the same `removeFriend` delete. ProfileView.swift:143-144 shows `friends.count` for both FOLLOWERS and FOLLOWING: semantically consistent only because it's mutual, but it also counts demo friends (HIGH above) and ignores pending requests.
- `unfollow(uid:)` runs `fetchFriendships` in `try?`; on error it falls to the else-branch, removing the friend from the local list only, while the doc remains. Feed menu shows Unfollow and Report on your own posts ("Unfollowed <you>" message).

[MEDIUM] SocialViewModel.swift:361-363 / ActivityFeedView.swift:258-261 — Report post
- "Post reported." is shown unconditionally; failure is swallowed; reason is constant; no dedupe per reporter/post; the post is not hidden locally. Works as a write to `reports` (OK), signed-out: silent no-op.

[MEDIUM] Auth edge cases (SocialViewModel.swift:29, FirebaseAuthService.swift)
- Signed-out (uid nil): feed/friends/challenges return demo data; like, comment, friend request, invite, join, create silently return (createChallenge returns nil, so NEXT does nothing; comment text already cleared). No "sign in" prompt anywhere in Social.
- `currentUid` reads `Auth.auth().currentUser` on each access (no auth-state listener); there is no `addStateDidChangeListener`, so VMs aren't reset on sign-out/switch. `FirebaseAuthService.isSignedIn` is a cached bool set only by its own calls, and a new instance is created at every call site (ContentView:386, SettingsView:236), so the property is meaningless; the Apple flow stores `currentNonce` on the instance, which is fine as the same OnboardingViewModel instance is used.
- `signInWithApple()` (no-arg) is `fatalError` but is declared in the protocol; calling it through `AuthServiceProtocol` crashes (FirebaseAuthService.swift:19-21).
- `signInWithEmail` maps only `wrongPassword`/`userNotFound` to `invalidCredentials`; with email enumeration protection on, Firebase returns `invalidCredential`, which falls into `.unknown(message)`. (unverified against project config)
- Apple sign-in returns `displayName` nil on repeat sign-ins and `fullName` is only used the first time; no `updateProfile` call is made, so `Auth.displayName` is often nil, feeding the "User"/"You" fallbacks above.

### LOW

[LOW] ActivityFeedView.swift:80 — Header avatar is hardcoded `Avatar(initial: "Y")`.
[LOW] ActivityFeedView.swift:289 — Handle shown on each post is `@` + first 8 chars of the Firebase uid, not the username; the same uid-prefix handle is shown for everyone.
[LOW] ActivityFeedView.swift:356-369 — `photoURL` is never uploaded or loaded anywhere: the photo slide is a gray placeholder with a system icon, and the composer's photo has no upload path (WorkoutCompletionView creates items with `photoURL` nil). Saved posts (`savedPostIds`) have no screen that lists them, so "Save workout" is write-only.
[LOW] FriendsListView.swift:67-70 — Invite link `DashedAdd(action: {})` with `allowsHitTesting(false)` is fine (ShareLink wraps it), but the shared URL is dead (see HIGH).
[LOW] FirebaseAuthService.swift:156 — Nonce charset is missing "W" ("...TUVXYZ..."); harmless to security, but the character set is nonstandard.
[LOW] Challenge.swift:4-46 — The SwiftData `@Model Challenge` is not used by the Social code (it uses `FirestoreChallenge`); it only appears in schemas. Dead model carrying schema weight.
[LOW] AuthService.swift:33-60 — `LocalAuthService` is a TODO stub issuing random UUIDs as signed in; no references found in the scope read (unverified whether it is used under `#if`/previews).

## Verified OK
- Firestore `in` batching: `stride(0, count, 30)` slicing is correct, with no empty batch (guard on empty) — FirestoreService.swift:84-103.
- Friendship query: two `whereField` queries (userId1, userId2) merged; the other uid is derived correctly (`userId1 == uid ? userId2 : userId1`) in `fetchFriendUids` and `loadFriends`; pending requests list only incoming (`requestedBy != uid`) — SocialViewModel.swift:300-309. Accept/decline paths exist.
- Like uses `arrayUnion`/`arrayRemove` (idempotent on the server); `isLiked` is derived from `likes.contains(currentUid)`.
- Comment ordering (date ascending, limit 50) and increment of `commentCount` via `FieldValue.increment`.
- Feed carousel/session sheet derivations (sets count, volume label `K` threshold, muscle set weighting primary 1 / secondary 0.5, top-3 muscles) are internally consistent: ActivityFeedView.swift:12-17, 406-420, BodyHeat+Exercises.swift. Heatmap intensity = muscle / peak, capped at 1.
- Widget friends data is written only from real (non-empty) fetched feed (SocialViewModel.swift:268), excluding own posts and warm-ups.
- LeaderboardView layouts: GlobalLeaderboardView top-5 + neighborhood excludes the user's own duplicate row (:21-29); ordinal suffix logic (11/12/13 -> TH); `moveLabel` = previousRank − rank with previousRank 0 meaning "—". These render correctly given correct data (which the CRITICAL finding shows doesn't exist).
- Chart baseline logic in LiftHistoryView (min − 2.5, ratio, min bar height 4) re-derived: no divide-by-zero; equal values draw full height.
- Standalone script: sorting descending/ascending and Epley 100x1 = 103.33 (truncated to 103) as described.
- FriendshipStatus/Codable round trips for the models are covered by FirestoreModelTests.

## Not verifiable
- Firestore security rules and composite indexes: neither `firestore.rules` nor `firestore.indexes.json` exist in the repo. Whether non-owners may update `likes`/`commentCount`, whether users can read others' profiles/feeds, whether a user can write friendship docs naming another uid, and whether the indexes exist cannot be determined. Client-side, `acceptFriendRequest` does not check that the caller is the recipient, and `removeFriend` does not check membership, so correctness depends fully on rules.
- Whether pre-redesign Firestore documents exist (impact of the non-optional Codable fields).
- Runtime behavior (no xcodebuild/simulator allowed per brief); everything above is from reading code plus one standalone Swift decoding script.
- Associated Domains for pulsepump.app (entitlements not examined beyond a grep of PulsePump/ for `applinks` which found nothing).
- Test coverage beyond PulsePumpTests listing: no tests reference SocialViewModel, FirestoreService, challenges, leaderboards, feed caching or lift history.
