# 09a Social: feed, posts, comments, likes, friends, profiles, privacy, report/block

Scope: the FRIENDS half of the Social tab and everything around people. Sources: `PulsePump/Features/Social/*` (`SocialViewModel.swift`, `PrivacyService.swift`, `Feed/`, `Friends/`, `Logic/`), `PulsePump/Core/Services/Firestore/*` (`FirestoreSocialRemote`, `SocialWire`, `SocialRemote`), `PulsePump/Core/Models/Firestore/FirestoreModels.swift`, `PulsePump/Core/Models/Enums/PrivacyLevel.swift`, `PulsePump/Features/Workout/Services/FeedPostBuilder.swift`, `firebase/firestore.rules`, `firebase/functions/src/{follows,counters}.ts`, `docs/sync-architecture.md`. Challenges, scoring and the Activity screen are in `09b-social-challenges-activity.md`.

Model in one paragraph: following is one-way; **friends** = mutual follow, **fan** = they follow me and I do not follow back, **following** = I follow them and they have not followed back. A "friend request" is a fan. ACCEPT = follow back. IGNORE = hide the request locally (no server write). Posts are only ever read per author with an audience the viewer may see (rules cannot authorise a broader query). Counters (likes, comments, friends, fans) are written only by Cloud Functions; the client adjusts the number it shows optimistically.

Note: `docs/audit/social-firestore.md` is STALE for this area (it describes a pre-Firestore-rules app with demo data in production, no privacy enforcement, contacts matching, hardcoded "Earlier" events). None of that is in the code now. This spec follows the code.

---

## FED  Feed (Social tab, FRIENDS segment)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| FED-03 | User taps the Social tab → App shows a header "SOCIAL", a bell (accessibility "Activity"), the user's avatar ("Your profile") and two segments "FRIENDS" and "CHALLENGES"; FRIENDS is selected | ✅ `ActivityFeedView.swift:27-93` | [ ] | — |
| FED-06 | System: Social tab appears → App ensures `profiles/{me}` exists (claims a handle, creates the profile with the privacy defaults) and restores privacy settings from the server | ✅ `SocialTabView.swift:15-21`, `FirestoreSocialRemote.swift:107` | [ ] | — |
| FED-09 | System: number of completed workouts changes → App writes only the changed values among streak, total workouts and display name to `profiles/{me}` (never resets a returning user to zero) | ✅ `SocialViewModel.syncOwnStats` | [ ] | — |
| FED-12 | User opens FRIENDS while nothing is loaded → App shows a skeleton list (`FeedSkeleton`) until the first page arrives | ✅ `ActivityFeedView.swift:114` | [ ] | — |
| FED-15 | System: first feed load → App loads the follow graph, then queries posts: one query per chunk of 10 friends (audience in `everyone`,`friends`) plus one query for my own posts (all audiences); newest first by `createdAt`, 20 per query; blocked users are never queried | ✅ `FeedQueryPlanner.swift`, `SocialViewModel.swift:494` | [ ] | — |
| FED-18 | System: pages from several queries arrive → App merges them: dedupes by post id, drops blocked authors and posts I hid, sorts by (createdAt, id) newest first, keeps the top 20 | ✅ `FeedQueryPlanner.merge` | [ ] | — |
| FED-21 | System: page merged → App adds my like state (one read of `likes/{me}` per post) and the body map (one read of `extras/bodymap` per post whose `bodyMapAudience` is not onlyMe) | ✅ `SocialViewModel.hydrate` (N+1 reads per page) | [ ] | — |
| FED-24 | User leaves the FRIENDS segment and returns within 5 minutes → App does not refetch (in-memory TTL `cacheTTL` = 300 s) | ✅ `SocialViewModel.swift:68,467` | [ ] | — |
| FED-27 | User pulls down on the feed → App forces a refetch of the follow graph and the feed, ignoring the TTL | ✅ `ActivityFeedView.swift:140` | [ ] | — |
| FED-30 | User follows, unfollows, blocks, unblocks, or publishes a post → App clears the TTL so the next feed visit refetches | ✅ `lastFeedFetch = nil` in `follow/unfollow/block/unblock/publish` | [ ] | — |
| FED-33 | User scrolls until 3 posts from the end → App fetches the next page using the oldest shown `createdAt` as cursor and appends it (a small skeleton row shows while loading); more pages exist only if some query returned a full 20 | ✅ `ActivityFeedView.swift:128`, `loadMoreFeed` | [ ] | — |
| FED-36 | User has no friends and no posts → App shows "No friends yet." / "Sessions your friends post appear here. Friends are people you follow who follow you back." and a "FIND FRIENDS" button that opens the Find Friends sheet | ✅ `EmptyStateViews.swift` | [ ] | — |
| FED-39 | User has friends (or graph not known) but no posts → App shows "Nothing posted yet." / "When you or your friends post a session, it shows up here." | ✅ | [ ] | — |
| FED-42 | Feed fails to load and nothing is shown → App shows "Couldn't load your feed." with a RETRY pill that forces a refresh | ✅ `RetryNotice` | [ ] | — |
| FED-45 | A publish failed earlier this session → App shows a banner "YOUR LAST SESSION DIDN'T POST" with RETRY; RETRY republishes the same payload and, on success, force-refreshes the feed | ✅ `SocialViewModel.retryPendingPost` | [ ] | — |
| FED-48 | User looks at a post card → App shows avatar, name (bold), `@handle`, and "TEMPLATE NAME · m:ss · 2H AGO" (abbreviated relative time, uppercase) | ✅ `ActivityFeedView.swift:270` | [ ] | — |
| FED-51 | User taps another user's avatar or name → App opens that person's profile in a sheet; tapping my own does nothing | ✅ | [ ] | — |
| FED-54 | Post has a body map the viewer may see → App shows a 330 pt body-map slide (heat map plus top muscles with set counts) with "FULL SESSION ›"; tapping it opens the post detail | ✅ | [ ] | — |
| FED-57 | Post has no body map visible to the viewer → App shows a row "N EXERCISES" and "FULL SESSION ›" that opens the post detail | ✅ `fullSessionRow` | [ ] | — |
| FED-60 | User reads the stats strip → App shows SETS (working sets), VOLUME (in the user's unit, from kg), IMPROVED "n" with "/total", PRS | ✅ | [ ] | — |
| FED-63 | Post has a caption → App shows "<name> <caption>" under the stats | ✅ | [ ] | — |
| FED-66 | User taps the "..." on someone else's post → App shows "Post options": Steal program, Save workout / Unsave workout, Report post, Block @handle, and Unfollow (only if relationship is not stranger) | ✅ `ActivityFeedView.swift:307-318` | [ ] | — |
| FED-69 | User taps the "..." on their own post → App shows only "Delete post" | ✅ | [ ] | — |
| FED-72 | User taps Delete post → App asks "Delete this post?" / "It's removed for everyone. The session stays in your history."; Delete removes `extras/bodymap` then the post and drops it from the feed | ✅ `deletePost` | [ ] | — |
| FED-75 | User taps Steal program → App matches the post's exercises to the local library by name (case-insensitive), creates a local template "<author>'s <template>" with `targetSets` = number of posted sets (min 1) and alerts "Saved "<name>" to your programs." | ✅ `stealProgram` | [ ] | — |
| FED-78 | User taps Save workout / Unsave workout → App toggles a local bookmark and alerts "Workout saved." / "Removed from saved." | 🟡 bookmark only; no screen lists saved workouts (grep: only these two call sites) | [ ] | — |
| FED-81 | User taps Unfollow in the post menu → App unfollows, drops that author's posts if they are no longer a friend, and alerts "Unfollowed <name>." | ✅ | [ ] | — |
| FED-84 | System: feed page loaded and non-empty → App passes the posts to the widget data service so the Friends widget refreshes | ✅ `onFeedLoaded` → `WidgetDataService.writeFriends` | [ ] | — |
| FED-87 | System: Auth reports a different uid (sign-out, account switch, deletion) → App drops every cache (profile, graph, feed, comments, challenges, hidden posts) before loading | ✅ `syncIdentity()/reset()` | [ ] | — |
| FED-90 | System: a friend posts with audience "Only me" → App never shows it to anyone else (the audience filter excludes it and the rules deny it) | ✅ rules `audienceAllows` | [ ] | — |
| FED-93 | System: a fan or stranger posts → App never shows it in my feed (feed = mutual friends plus me); it is only reachable from their profile if it is public | ✅ | [ ] | — |
| FED-96 | System: the author changes their privacy later → App keeps showing old posts under the audience they carried when posted (audience is captured per post) | ✅ `FeedPostBuilder` | [ ] | — |

### FED edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| FED-E01 | Offline on first load | Fetch throws, `feedError` = "Couldn't load your feed." and RETRY is shown | Memory-only Firestore cache is used only for the emulator; the production SDK default cache may serve cached documents instead, so the error may not appear. Not verified on device | 🟡 | [ ] | — |
| FED-E02 | Offline pull-to-refresh while posts are already shown | Old posts stay; `feedError` is set but only displayed when the list is empty, so the user sees no message | Silent failure | 🟡 `ActivityFeedView.swift:116` | [ ] | — |
| FED-E03 | Follow graph fails to load but the posts query works | Feed is built from `friends = []`: only my own posts appear, and `lastFeedFetch` is set so friends' posts stay missing for 5 minutes (until pull-to-refresh) | `loadGraph` swallows its error | 🐞 `SocialViewModel.swift:470-476`: expected error/retry, actual own-posts-only cached for the TTL | [ ] | — |
| FED-E04 | A friend blocked me | Their chunk query is denied by the rules; app retries that chunk author by author, skips the unreadable author and keeps the rest | `singleAuthorQueries` then latches to true until relaunch (more reads) | ✅ `SocialViewModel.swift:506-517` | [ ] | — |
| FED-E05 | More than 10 friends | Several chunk queries run sequentially; results merged | 20 disjunctions per query, under the limit of 30 | ✅ | [ ] | — |
| FED-E06 | More than 1000 follow edges in one direction | Graph is truncated at 1000 edges (`limit(to: 1000)`) | Unrealistic today | 🟡 | [ ] | — |
| FED-E07 | Friend deleted their account | Their posts are deleted server side; profile read is not-found so they are added to `goneUids` and drop from lists and counts | `deleteAccount` removes posts, follows, comments, likes | ✅ | [ ] | — |
| FED-E08 | Post deleted by the author while it is on screen | Card stays until the next refresh; like and comment attempts fail (rules cannot read the parent post) and roll back with "Couldn't update your like. Try again." / "Couldn't post your comment. Try again." | No live listeners | ✅ | [ ] | — |
| FED-E09 | Kill the app after a failed publish | `pendingPost` lives in memory only, so the RETRY banner and payload are lost; the workout stays in history and there is no way to re-post it later | 🧭 PROPOSED: persist the pending payload in UserDefaults, or offer "Post" from workout detail | 🧭 | [ ] | — |
| FED-E10 | Double-tap RETRY | Second call finds `publishedPostIds` containing the id and does nothing; post id = workout id so a repeat would only rewrite the same document | Idempotent | ✅ | [ ] | — |
| FED-E11 | Posts are ordered by the author's device clock | `createdAt` is set client side (`Date()`), so a wrong clock misorders the feed | Rules only check it is a timestamp | 🟡 | [ ] | — |
| FED-E12 | Post document missing `authorUid` or `date` | Silently skipped (parse returns nil) | | ✅ `SocialWire.post` | [ ] | — |
| FED-E13 | Signed out (no Firebase uid) | Feed methods return at once; empty feed with the "Nothing posted yet." state | Accounts are required elsewhere (01) | ✅ | [ ] | — |
| FED-E14 | Two devices | Hidden posts and ignored requests are stored per device in UserDefaults; a report on one device does not hide the post on the other | | 🟡 | [ ] | — |
| FED-E15 | Weights in lbs mode | VOLUME is converted for display; stored/posted values stay kg | Units invariant | ✅ | [ ] | — |
| FED-E16 | Steal program with no matching exercise names | Alert "None of these exercises matched your library."; nothing created | Custom exercises of the author never match | ✅ | [ ] | — |
| FED-E17 | Rules denial on a multi-author query for a reason other than a block | Same per-author fallback; if every author fails the feed shows only my posts | | ✅ | [ ] | — |
| FED-E18 | Tapping SOCIAL repeatedly / switching segments quickly | Each return runs `loadFeed()`; TTL prevents refetch; an in-flight load is not de-duplicated, two simultaneous loads can run | | 🟡 | [ ] | — |

---

## POS  Post detail (full session sheet)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| POS-03 | User taps the body-map slide or "FULL SESSION ›" → App opens a full-screen sheet with back "‹", the line "NAME · Sat 4 Oct · m:ss" and the template name in large caps | ✅ `FeedSessionSheet` | [ ] | — |
| POS-06 | Sheet opens and some exercises have `improvementScore` > 0 → App shows a ticker strip "EXERCISE +N%" | ✅ | [ ] | — |
| POS-09 | User reads the header block → App shows four stats (SETS, VOLUME, IMPROVED n/total, PRS) and, if a body map is visible, a small heat map | ✅ | [ ] | — |
| POS-12 | User reads the exercise table → App shows columns EXERCISE, SET, BEST, VS LAST; rows sorted by improvement score, highest first | ✅ | [ ] | — |
| POS-15 | System: building PR flags → App marks the top `prCount` exercises (by improvement score) with "PR" because the post stores only a PR count, not which exercise | 🟡 approximation; can flag the wrong exercise | [ ] | — |
| POS-18 | User reads VS LAST → App shows "▲ +<weight in user unit>" when weight beat last time, else "▲ +N REP(S)", else "—" | ✅ | [ ] | — |
| POS-21 | User reads set chips → App shows `weight×reps`, "Ns" for timed sets, "Nm" for distance, "Nr" for bodyweight; warm-ups are never in a post | ✅ | [ ] | — |
| POS-24 | User taps an exercise row → App opens the owner's lift history built from their posted sessions of that exercise (progression chart, history, est. 1RM) | ✅ `LiftHistoryView` | [ ] | — |
| POS-27 | Lift history has no sessions → App shows "NO POSTED SESSIONS FOR THIS LIFT YET"; fetch failure shows "Couldn't load their sessions." with RETRY | ✅ | [ ] | — |
| POS-30 | User taps the heart or bubble in the bottom bar → App likes / opens comments exactly as on the card, using the freshest copy of the post | ✅ | [ ] | — |
| POS-33 | PR styling → App uses the gold PR colour (`prGold`) on PR names and the profile "PRs · 30D" tile | 🧭 design docs say "PR is a treatment, not a color" (inkPrimary + underline); code uses gold. PROPOSED: owner picks one | [ ] | — |

### POS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| POS-E01 | Post deleted or no longer visible while the sheet is open | Sheet keeps showing its copy; like/comment fail and roll back | See FED-E08 | ✅ | [ ] | — |
| POS-E02 | Viewer is not allowed to see the body map | No heat map; the rest of the post is shown | Body map is a separate document guarded by `bodyMapAudience` | ✅ | [ ] | — |
| POS-E03 | Exercise has no working sets in the history | Exercise is skipped in lift history | | ✅ `LiftHistory.sessions` | [ ] | — |
| POS-E04 | Bodyweight exercise lift history | No est. 1RM (nil for weight 0) | | ✅ | [ ] | — |
| POS-E05 | Post opened from a profile while friend relationship changes | Sheet shows data already fetched | | ✅ | [ ] | — |
| POS-E06 | Post with 60+ exercises | Post writes are capped at 60 exercises (rules and `SocialWire`) | Extra exercises silently dropped on publish | ✅ `SocialWire.postDocument` | [ ] | — |
| POS-E07 | Post link / deep link to one post | None exists (no `pulsepump://post`, no https handler) | | ❌ | [ ] | — |

---

## CMT  Comments

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CMT-03 | User taps the bubble (with count) on a card or in post detail → App opens a full-screen comments view with the post's name and template at the top and an X to close | ✅ `CommentsView` | [ ] | — |
| CMT-06 | System: view opens → App loads up to 100 comments, oldest first; a 3-row skeleton shows while loading | ✅ | [ ] | — |
| CMT-09 | Post has no comments → App shows "No comments yet" / "Be the first to say something." | ✅ | [ ] | — |
| CMT-12 | User reads a comment → App shows avatar, name (bold), relative time, text and a "..." (Comment options) | ✅ | [ ] | — |
| CMT-15 | User types in "Add a comment" → App enables the send arrow only when the trimmed text is 1 to 500 characters and no send is in flight; the field grows to 3 lines | ✅ | [ ] | — |
| CMT-18 | User taps send → App increases the shown comment count at once, writes `comments/{id}`, appends the comment and clears the field on success | ✅ `postComment` | [ ] | — |
| CMT-21 | Send fails → App rolls the count back, keeps the typed text and shows an alert "Social": "Couldn't post your comment. Try again." | ✅ | [ ] | — |
| CMT-24 | User taps "..." on their own comment → App offers "Delete comment" | ✅ | [ ] | — |
| CMT-27 | User taps "..." on someone else's comment → App offers "Report comment"; if the viewer owns the post it also offers "Delete comment" | ✅ | [ ] | — |
| CMT-30 | User deletes a comment → App removes it and lowers the count at once; on failure restores both and alerts "Couldn't delete the comment. Try again." | ✅ | [ ] | — |
| CMT-33 | User reports a comment → App writes a report (reason "Inappropriate comment", target `postId/commentId`); no confirmation message, and the comment stays visible | 🟡 no feedback and no local hide (post reports do hide) | [ ] | — |
| CMT-36 | System: a comment is created or deleted → Cloud Function `onCommentWritten` adjusts `commentCount` (idempotent, never below 0); the client only reconciles on the next feed fetch | ✅ `functions/src/index.ts` | [ ] | — |

### CMT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CMT-E01 | Offline when opening comments | `comments[postId]` becomes empty, so "No comments yet" shows even though comments exist | Load failure is indistinguishable from empty | 🟡 `SocialViewModel.swift:587` | [ ] | — |
| CMT-E02 | More than 100 comments | Only the first 100 (oldest) load; no paging | | 🟡 | [ ] | — |
| CMT-E03 | Comment of 501+ characters | Send is disabled; `postComment` also refuses; no counter is shown | | ✅ | [ ] | — |
| CMT-E04 | Whitespace-only comment | Send is disabled; text is trimmed before saving | | ✅ | [ ] | — |
| CMT-E05 | Double tap send | Button disabled while `isPosting`; only one comment | | ✅ | [ ] | — |
| CMT-E06 | A blocked user's comments on a mutual friend's post | Still shown to me; nothing filters comments by block list (the rules only hide the post itself between the two people) | 🧭 PROPOSED: filter comments from users I blocked | 🧭 | [ ] | — |
| CMT-E07 | Post author blocks me after I commented | I lose access to the post and its comments (rules) | | ✅ | [ ] | — |
| CMT-E08 | Comment author's name changes later | Old comments keep the stored `authorName` / `authorUsername` | | ✅ | [ ] | — |
| CMT-E09 | Commenter deletes their account | Their comments are removed by `deleteAccount` and `commentCount` drops via the trigger | | ✅ | [ ] | — |
| CMT-E10 | Rules denial (no read access to the post) | Create is denied: alert "Couldn't post your comment. Try again." | Denial is not distinguished from other errors | ✅ | [ ] | — |
| CMT-E11 | Comment text length counted in characters vs rules `size()` | Client counts Swift characters, rules count code points; an emoji-heavy 500 "character" comment could be refused | Unverified on device | 🟡 | [ ] | — |

---

## LKE  Likes (the only reaction)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| LKE-03 | User taps the heart on a card, post detail or profile post → App fills the heart (accent colour) and adds 1 to the count at once, then writes `posts/{id}/likes/{me}` | ✅ `toggleLike` | [ ] | — |
| LKE-06 | User taps a filled heart → App empties it and subtracts 1 (never below 0), then deletes the like document | ✅ | [ ] | — |
| LKE-09 | Write fails → App restores the heart and count and shows an alert "Social": "Couldn't update your like. Try again." | ✅ | [ ] | — |
| LKE-12 | User taps repeatedly while a write is in flight → App ignores the extra taps for that post | ✅ `likeInFlight` | [ ] | — |
| LKE-15 | System: page loads → App marks hearts from `likes/{me}`; if that lookup fails every heart shows empty | 🟡 failures swallowed (`try?`) | [ ] | — |
| LKE-18 | User likes from post detail → App updates the card and the profile copy of the same post (`mutatePost`) | ✅ | [ ] | — |
| LKE-21 | System: like created/deleted → Cloud Function `onLikeWritten` updates `likeCount`; the client number only reconciles on the next fetch | ✅ | [ ] | — |
| LKE-24 | User looks for who liked a post or other reaction types → App has none (count only; no list of likers, no emoji reactions, no like notification) | ❌ | [ ] | — |

### LKE edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| LKE-E01 | Like own post | Allowed | | ✅ | [ ] | — |
| LKE-E02 | Post deleted or access lost | Create denied, rolled back with the error alert | | ✅ | [ ] | — |
| LKE-E03 | Offline | Rolled back with the error alert (no queued write) | | ✅ | [ ] | — |
| LKE-E04 | Two devices like the same post | Document id is my uid, so one like; counts agree after refresh | | ✅ | [ ] | — |
| LKE-E05 | Like count shown vs server count differ (function lag) | Client shows its optimistic value until the next fetch | | 🟡 | [ ] | — |
| LKE-E06 | Liker deleted account | Their likes are deleted and counts decrement | | ✅ | [ ] | — |

---

## FRD  Friends, fans, follow, follow back, ignore, invite

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| FRD-03 | User opens Find Friends (from the empty feed state, "Find Friends" on their profile, or More > Profile) → App shows a sheet "Find Friends" with a Close button and a search field "Find someone by their @handle" | ✅ `FriendsListView` | [ ] | — |
| FRD-06 | User types a handle → App waits 350 ms, normalises it (trim, strip a leading "@", lowercase) and, if it is 3 to 20 of a-z 0-9 . _, looks up `usernames/{handle}` | ✅ | [ ] | — |
| FRD-09 | Typed text is not a valid handle → App shows "TYPE THE FULL HANDLE · 3 TO 20 LETTERS, NUMBERS, . OR _" | ✅ | [ ] | — |
| FRD-12 | No such handle → App shows "NO ONE WITH THE HANDLE @HANDLE"; while searching it shows one skeleton row | ✅ | [ ] | — |
| FRD-15 | Handle found → App shows a row (name, @handle) with a button by relationship: "FRIENDS" (label), "FOLLOWING", "FOLLOW BACK" (they follow me), or "FOLLOW" | ✅ `resultRow` | [ ] | — |
| FRD-18 | Found user's profile is not readable → App still shows the row as "Private profile" with their handle and FOLLOW | ✅ | [ ] | — |
| FRD-21 | Search finds myself or someone I blocked → App shows no result | ✅ `searchUsers` | [ ] | — |
| FRD-24 | User types a second search before the first returns → App ignores the older answer | ✅ `searchToken` | [ ] | — |
| FRD-27 | User taps FOLLOW → App marks them as following at once and writes `follows/{me}_{them}`; they appear under "Waiting For Follow Back" until they follow back | ✅ | [ ] | — |
| FRD-30 | User taps FOLLOW BACK or ACCEPT on a fan → Same write; the person becomes a friend (feed and tagging open up) | ✅ | [ ] | — |
| FRD-33 | Follow write fails → App rolls the graph back and shows an alert "Couldn't follow. Try again." | ✅ | [ ] | — |
| FRD-36 | User taps FOLLOWING in search results or UNFOLLOW in a list → App unfollows at once with no confirmation; on failure restores and alerts "Couldn't unfollow. Try again." | ✅ | [ ] | — |
| FRD-39 | System: someone follows me → App lists them as a fan; under "Friend Requests" (Find Friends) with "N Waiting" and ACCEPT / IGNORE, and as a bell dot / "Needs You" row | ✅ | [ ] | — |
| FRD-42 | User taps IGNORE on a request → App removes it from the inbox (saved per account in UserDefaults); the person stays a fan, still follows me, and shows under "Fans" with FOLLOW BACK. Nothing is written to the server and they are not told | ✅ `FriendGraph.ignoreFan` | [ ] | — |
| FRD-45 | Ignored fan is followed back later → App clears the ignored mark | ✅ `follow()` removes from `dismissedFans` | [ ] | — |
| FRD-48 | User opens a friend's profile and taps the "FRIENDS" pill → App asks "Unfollow <name>?" with "You'll stop being friends. They stay your fan." and a destructive Unfollow | ✅ | [ ] | — |
| FRD-51 | User taps "FOLLOWING" on a non-friend's profile → App asks "Unfollow <name>?" with "You'll stop following them." | ✅ | [ ] | — |
| FRD-54 | User unfollows a friend → App turns them into a fan, removes their posts from the feed and clears the TTL | ✅ | [ ] | — |
| FRD-57 | User opens their own profile ("YOU") → App lists Friends (UNFOLLOW pill; "N WORKOUTS" detail), Fans ("FOLLOWS YOU", FOLLOW BACK) and "Waiting For Follow Back" (UNFOLLOW); this is the only place a friend can be removed in bulk | ✅ `YourProfileView` | [ ] | — |
| FRD-60 | User reads friend and fan numbers (More tab, profile header) → App shows counts from the loaded graph (excluding deleted and blocked accounts); before the graph loads it shows the function-maintained `friendCount` / `fanCount` | ✅ | [ ] | — |
| FRD-63 | System: any follow edge is created or deleted → Cloud Function recounts both users' `friendCount` / `fanCount` from the edges (transactional, idempotent per event) | ✅ `follows.ts` | [ ] | — |
| FRD-66 | User taps "Share Your Handle" (Find Friends), or SHARE on their profile → App opens the share sheet with "Train with me on Pump. Find me by my handle: @handle" and the caption "FRIENDS FIND YOU BY TYPING YOUR EXACT HANDLE · @HANDLE"; hidden when the handle is not yet known | ✅ | [ ] | — |
| FRD-69 | User looks for "find via phone contacts" → App has no contacts access or matching; it was removed (the old email-vs-username match could never succeed) | ❌ spec `docs/pulse-pump-spec.md:247` still lists it | [ ] | — |
| FRD-72 | User looks for a shareable invite link → App shares only the handle text; no `https` or `pulsepump://` social link is handled | ❌ | [ ] | — |
| FRD-75 | User searches by name or partial handle → App only supports exact handle | ✅ by design (rules forbid listing `usernames`) | [ ] | — |
| FRD-78 | New user signs in → App creates their handle from the typed username or name: lowercase a-z 0-9 . _ (max 16 chars; under 3 chars gets "pumper" appended), then up to 6 numbered variants if taken | ✅ `HandleRules.candidates` | [ ] | — |

### FRD edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| FRD-E01 | Follow myself | Refused (`uid != me`) | Rules also deny | ✅ | [ ] | — |
| FRD-E02 | Follow someone I blocked | Refused with "You can't follow someone you blocked." | | ✅ | [ ] | — |
| FRD-E03 | Follow someone who blocked me | Rules deny the create; app rolls back and shows "Couldn't follow. Try again." | Deliberately not revealed | ✅ | [ ] | — |
| FRD-E04 | Double tap FOLLOW / retry after a lost response | Edge already exists: rules refuse the rewrite, app checks the edge with a query and treats it as success | | ✅ `FirestoreSocialRemote.follow` | [ ] | — |
| FRD-E05 | Offline | Follow/unfollow roll back with an alert; search shows "NO ONE WITH THE HANDLE ..." (error looks like not found) | | 🟡 | [ ] | — |
| FRD-E06 | More than 80 people in friends + fans + following | Only the first 80 profiles (sorted by uid) are fetched per load, the rest do not appear in lists until cached | `loadProfiles` `.prefix(80)` | 🟡 `SocialViewModel.swift:223` | [ ] | — |
| FRD-E07 | A person's account was deleted | Removed from lists and counts (profile not found) | | ✅ | [ ] | — |
| FRD-E08 | A friend set their profile to Only me | They stay in my friends list as "Private profile" (placeholder) | Name unavailable | ✅ | [ ] | — |
| FRD-E09 | Both users follow each other at the same time | Both edges exist, they are friends; counters converge by recount | | ✅ | [ ] | — |
| FRD-E10 | Ignored request on a second device | Reappears there (ignore is local) | 🧭 PROPOSED: keep local; sync only if owner wants | 🧭 | [ ] | — |
| FRD-E11 | Account switch on the same device | Ignored list and hidden posts are keyed by uid; caches reset | | ✅ | [ ] | — |
| FRD-E12 | Handle contains uppercase or "@" typed by user | Normalised before lookup | | ✅ | [ ] | — |
| FRD-E13 | No friends to invite/tag | Empty text "NO FRIENDS YET · FRIENDS ARE PEOPLE YOU FOLLOW WHO FOLLOW YOU BACK" | | ✅ | [ ] | — |
| FRD-E14 | User wants to remove a fan (not block) | Not possible; only block removes them from lists, and their follow edge stays | | ❌ | [ ] | — |

---

## PRF  Profiles

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PRF-03 | User opens another person's profile (card avatar, list row) → App shows a skeleton, then @handle, name, "N FRIENDS · N FANS" and a relationship pill; a "..." (Profile options) appears unless it is me or the account is gone | ✅ `FriendProfileView` | [ ] | — |
| PRF-06 | Profile is visible → App shows tiles Streak ("ND"), This Wk, Volume · 30D (user unit), PRs · 30D | ✅ | [ ] | — |
| PRF-09 | Visible profile has posts with body maps in the last 30 days → App shows a heat map and the top 6 muscles with set counts | ✅ | [ ] | — |
| PRF-12 | User reads "This Week" ("N Of 7 Days") → App lists the last 7 days with weekday and "N SETS ›" or "—"; tapping a day with a post opens its detail | ✅ | [ ] | — |
| PRF-15 | Viewer is not a friend → App adds "YOU SEE THEIR PUBLIC SESSIONS · FRIENDS SEE MORE"; a friend with no posts sees "NO POSTED SESSIONS YET" | ✅ | [ ] | — |
| PRF-18 | System: profile posts are fetched → App asks for up to 30 posts: all audiences for me, everyone+friends for a friend, everyone only for others; stats are derived only from these posted sessions | ✅ `profileQuery` | [ ] | — |
| PRF-21 | Profile is not readable (Friends only and not friends, Only me) → App shows lock icon, title "Private profile" and "Only the handle is visible. Follow @handle to be friends when they follow you back."; FOLLOW remains | ✅ | [ ] | — |
| PRF-24 | Profile is unreadable because they blocked me → App shows the same "Private profile" state (cannot be told apart) | ✅ rules by design | [ ] | — |
| PRF-27 | I blocked this person → App shows "You blocked @handle" / "Their posts and profile are hidden from you." and an UNBLOCK pill | ✅ | [ ] | — |
| PRF-30 | Account deleted → App shows "This account is no longer available." with no pill and no menu | ✅ | [ ] | — |
| PRF-33 | User opens their own profile (avatar on the Social header) → App shows "YOU": avatar, @handle, name, "N FRIENDS · N FANS", SHARE, EDIT (only if a local user exists), stat tiles, heat map, lists, and "Grow Your Circle" > "Find Friends" | ✅ `YourProfileView` | [ ] | — |
| PRF-36 | User taps EDIT → App opens the profile editor sheet (see 10) | ✅ | [ ] | — |
| PRF-39 | Relationship changes while the profile is open (follow, unfollow, unblock) → App reloads the page | ✅ `.task(id: relationship)` | [ ] | — |
| PRF-42 | User opens a profile "..." → App offers "Report @handle" and "Block @handle" (or "Unblock" when blocked) | ✅ | [ ] | — |

### PRF edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PRF-E01 | Offline or any non-permission error while opening a profile | Page is treated as restricted: "Private profile" is shown and a placeholder is cached for that uid, so friend lists also show "Private profile" until relaunch | Expected: "Couldn't load" with RETRY and no caching | 🐞 `SocialViewModel.swift:700-709`, `ProfileAccessRules.access` (only `.notFound` becomes unavailable) | [ ] | — |
| PRF-E02 | Profile has zero posts in 30 days | Tiles show zero; no heat map | Stats come from posts only, not raw workouts | ✅ | [ ] | — |
| PRF-E03 | Workout posted as Only me | Not in anyone's stats, including my own profile tiles (only posts count) | My own "Volume · 30D" can differ from my History | 🟡 | [ ] | — |
| PRF-E04 | Streak tile | Uses the owner's synced `currentStreak`; stale until the owner opens the app | | ✅ | [ ] | — |
| PRF-E05 | Post dated up to 1 day in the future | Still counted in the 30-day window | `ProfileStats.last30Days` | ✅ | [ ] | — |
| PRF-E06 | Day with two posts | The latest post of that day is shown on the row | | ✅ | [ ] | — |
| PRF-E07 | Viewer's week boundaries | "This week" is the last 7 days ending today in the viewer's calendar/timezone, not Monday-based | | ✅ | [ ] | — |
| PRF-E08 | Friend lowers visibility to Friends only while a non-friend has the page open | Next reload shows Private profile | | ✅ | [ ] | — |
| PRF-E09 | Handle not yet known (offline new account) | Share/handle UI hidden | | ✅ | [ ] | — |

---

## PRV  Privacy settings, defaults and audience

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PRV-03 | User opens Social > bell > Activity > Privacy → App shows four rows: "Workout posts", "Body map", "Global leaderboards", "Profile", each with an explanatory line and the current value | ✅ `ActivityView.swift` | [ ] | — |
| PRV-06 | New user, nothing chosen → App defaults: Workout posts = Friends only, Body map = Friends only, Global leaderboards = Visible, Profile = Everyone | ✅ `PrivacyRow.defaultLevel`; matches `sync-architecture.md` | [ ] | — |
| PRV-09 | User taps a row → App shows a choice dialog: Everyone / Friends only / Only me (Global leaderboards: Visible / Hidden) | ✅ | [ ] | — |
| PRV-12 | Workout posts note → App shows "ANYONE ON PUMP CAN SEE YOUR NEW POSTS", "ONLY FRIENDS (PEOPLE YOU FOLLOW BACK) SEE YOUR NEW POSTS" or "NEW SESSIONS STAY IN YOUR HISTORY, NOBODY ELSE SEES THEM" | ✅ `PrivacyLevel.note` | [ ] | — |
| PRV-15 | Body map note → "YOUR BODY MAP SHOWS ON EVERY NEW POST", "FRIENDS SEE YOUR BODY MAP, OTHERS SEE STATS ONLY", "BODY MAP IS NEVER SHARED" | ✅ | [ ] | — |
| PRV-18 | Global leaderboards / Profile notes → "YOUR NAME AND RANK SHOW ON GLOBAL BOARDS" / "YOU'RE HIDDEN FROM GLOBAL BOARDS"; "ANYONE CAN VIEW YOUR PROFILE" / "ONLY FRIENDS CAN VIEW YOUR PROFILE" / "YOUR PROFILE IS PRIVATE" | ✅ | [ ] | — |
| PRV-21 | User changes a row → App applies it locally at once (UserDefaults `privacy_<row>`) and saves `users/{me}.privacy` plus `profiles/{me}.profileVisibility` / `globalLeaderboardVisible`. A footer reads "CHANGES APPLY TO POSTS YOU MAKE FROM NOW ON · SAVED TO YOUR ACCOUNT" | ✅ `PrivacyService.set/push` | [ ] | — |
| PRV-24 | Save fails (offline) → App keeps the value locally, flags it pending and shows "PRIVACY CHANGES ARE SAVED ON THIS DEVICE AND WILL SYNC WHEN YOU'RE BACK ONLINE." in red; it retries the next time the Social tab or Activity opens | ✅ | [ ] | — |
| PRV-27 | User signs in on a new device → App replaces local values with the stored ones; a first-time user's defaults are published so the profile mirror matches | ✅ `restore()` | [ ] | — |
| PRV-30 | User changes Profile in Settings > Privacy > "Profile Visibility" → Same service and same effect as the Activity row (Settings exposes only this one row) | ✅ `SettingsView.swift:145` | [ ] | — |
| PRV-33 | User publishes a session → App stamps the post with `audience` (from Workout posts) and `bodyMapAudience` (from Body map); later setting changes do not alter old posts | ✅ `FeedPostBuilder.makePayload` | [ ] | — |
| PRV-36 | Workout posts is "Only me" and the user taps POST → App builds no post and writes nothing; the composer closes without telling the user nothing was shared | 🟡 `FeedPostBuilder.swift:35`; no feedback | [ ] | — |
| PRV-39 | Body map is "Only me", or the user chose "Post without body map" → App writes no `extras/bodymap` document | ✅ | [ ] | — |
| PRV-42 | Body map is "Friends only" and Workout posts is "Everyone" → Strangers see stats and exercises but no body map; friends see both (rules read `bodyMapAudience` separately) | ✅ | [ ] | — |
| PRV-45 | Auto-Share to Feed toggle (Settings, default ON) → ON: the completion screen's primary button is "POST"; OFF: it is "DONE" and posting needs the "..." menu | ✅ `WorkoutCompletionView.swift:139` | [ ] | — |
| PRV-48 | User looks for a per-post audience choice (e.g. "post this one to Everyone / Only me") → App has none; the composer overflow offers only "Post without body map" | ❌ | [ ] | — |
| PRV-51 | Server enforcement → Rules enforce audience on posts, comments, likes, body map, profile and global-board entries; the UI is not the only gate | ✅ `firestore.rules` | [ ] | — |

### PRV edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PRV-E01 | Per-post override wanted | Not built. 🧭 PROPOSED: an audience chip in the composer pre-set to the global privacy value, only able to narrow (never widen beyond) the privacy rows | | 🧭 | [ ] | — |
| PRV-E02 | Stored privacy map has missing or unknown keys | Each falls back to its design default | | ✅ `PrivacySettings(firestoreMap:)` | [ ] | — |
| PRV-E03 | Unsaved change on this device vs different value on the server | The unsaved local change wins and is pushed | | ✅ | [ ] | — |
| PRV-E04 | Offline at first launch | Local defaults are used; restore failure is silent | | ✅ | [ ] | — |
| PRV-E05 | Changing Profile visibility while someone has the profile cached | They see the new state next load | No push | ✅ | [ ] | — |
| PRV-E06 | Global leaderboards set to Hidden after already being on a board | Entry flips to hidden only the next time a score is written (no function reacts to the profile change), so the old entry can stay visible until the next workout | Expected: hidden at once | 🐞 `firebase/functions/src/challenges.ts` `applyScore` reads `globalLeaderboardVisible` only at score time; `index.ts` has no profile trigger | [ ] | — |
| PRV-E07 | Past posts when the user tightens privacy | Remain visible to the old audience; the footer says changes apply "FROM NOW ON" | 🧭 PROPOSED: offer "Apply to past posts" | 🧭 | [ ] | — |
| PRV-E08 | Tagged friends on a post (`taggedUids`, max 20) | Stored on the post; no extra visibility and no notification | | ✅ | [ ] | — |
| PRV-E09 | Two devices change privacy at once | Last write wins | | ✅ | [ ] | — |

---

## RPT  Report and block

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| RPT-03 | User taps "Report post" in the card menu → App immediately writes a report (reason "Inappropriate content", no reason picker, no confirmation), hides the post for this account and alerts "Reported. This post is hidden for you." | ✅ `reportPost` | [ ] | — |
| RPT-06 | Report fails → App keeps the post and alerts "Couldn't send the report. Try again." | ✅ | [ ] | — |
| RPT-09 | User taps "Report @handle" in a profile menu → App writes a report (reason "Inappropriate profile or behaviour") and alerts "Reported. Thanks for letting us know." | ✅ | [ ] | — |
| RPT-12 | User reports a comment or a challenge → App writes a report; no confirmation is shown | 🟡 comment: `CommentsView`; challenge: reason "Inappropriate challenge" | [ ] | — |
| RPT-15 | User taps "Block @handle" (card menu or profile menu) → App asks "Block @handle?" with "They disappear from your feed, search and lists, and can't follow you." and Block / Cancel | ✅ | [ ] | — |
| RPT-18 | User confirms Block → App writes `users/{me}/blocked/{uid}` (with name and handle so the list can show them), tries to delete my follow edge, removes them from graph, feed and search, clears the TTL; the card shows "Blocked. You won't see their posts." and a profile screen closes | ✅ `SocialViewModel.block` | [ ] | — |
| RPT-21 | Block fails → App alerts "Couldn't block. Try again." and changes nothing | ✅ | [ ] | — |
| RPT-24 | System: block exists in either direction → Rules hide profiles, posts, comments, likes and body maps between the two, and reject new follows towards the blocker | ✅ `blockedBetween` | [ ] | — |
| RPT-27 | User opens Activity > Safety > "Blocked people" (count shown) → App lists blocked people (name, @handle from block time) each with UNBLOCK; empty text "YOU HAVEN'T BLOCKED ANYONE" | ✅ `BlockedUsersView` | [ ] | — |
| RPT-30 | User taps UNBLOCK → App deletes the block, reloads the graph, clears the TTL. My earlier follow is not restored unless the edge still existed | ✅ | [ ] | — |
| RPT-33 | System: report received → App stores a write-only `reports` document (rules forbid reading); there is no moderation queue or admin tool in the repo | 🟡 App Store UGC rules expect a response process | [ ] | — |
| RPT-36 | User receives a challenge invite from someone they blocked → App hides it (filtered by `fromUid`); rules also stop a blocked user inviting the blocker | ✅ `loadInvites`, rules `hasBlocked` | [ ] | — |

### RPT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| RPT-E01 | Block succeeds but the follow delete fails | Block is kept; my follow edge may remain on the server, so unblocking later silently restores the friendship | `try? await remote.unfollow` | 🟡 `SocialViewModel.swift:376` | [ ] | — |
| RPT-E02 | The blocked person already followed me | Their edge stays; they vanish from my fans/friends; server `fanCount` for me still counts them | `countFollows` ignores blocks | 🟡 | [ ] | — |
| RPT-E03 | Block myself | Refused | | ✅ | [ ] | — |
| RPT-E04 | Report the same item twice | Two report documents; no dedupe | | ✅ | [ ] | — |
| RPT-E05 | Hidden (reported) posts on a second device | Reappear there (local only) | See FED-E14 | 🟡 | [ ] | — |
| RPT-E06 | Offline block / report | Fails with the alerts above; nothing queued | | ✅ | [ ] | — |
| RPT-E07 | Blocked person's posts from before the block when I unblock | Reappear after a refresh | | ✅ | [ ] | — |
| RPT-E08 | Reason choice | Reasons are fixed strings; 🧭 PROPOSED: add a short reason sheet (Spam / Abusive / Other) | | 🧭 | [ ] | — |
| RPT-E09 | Block stores name/handle at block time | Blocked list shows those even if they rename later | | ✅ | [ ] | — |

---

## SFX  Social demo fixtures (DEBUG only)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SFX-03 | Developer launches a DEBUG build with `-devDataSocialFixtures 1` (and not `-useFirebaseEmulator 1`) → App swaps the Firestore remote for an in-memory seeded remote: friends Priya, Jay, Marc, a fan (Sanne), a follow-only person (Tom, friends-only profile), two posts, a comment, a global "Monthly Volume" challenge and a friend challenge | ✅ `SocialFixtures.swift`, `DevFlags.swift` | [ ] | — |
| SFX-06 | Anyone runs a Release build → App never reaches fixtures: `DevFlags.socialFixtures` is a constant false and the fixture file is compiled out | ✅ `#if DEBUG` | [ ] | — |
| SFX-09 | Developer uses the Firebase emulator → App uses the real Firestore remote against the emulator; fixtures are forced off | ✅ | [ ] | — |
| SFX-12 | Real signed-in user with an empty network result → App shows real empty or error states, never invented posts or friends | ✅ | [ ] | — |

---

## Open decisions for the owner (09a)

- PRV-E01 / PRV-48: per-post audience override is not built. Proposed default: a composer chip that can only narrow the global setting.
- PRV-E07: should tightening privacy apply to past posts? Proposed default: no (current), maybe add an explicit "Apply to past posts" action.
- PRV-36: tell the user when "Workout posts = Only me" means nothing was posted. Proposed default: a short toast "Kept private".
- PRV-E06 (bug): hiding from Global leaderboards does not take effect on existing entries until the next score write. Needs a function trigger on profile change (or hide client-side).
- FED-E09: a failed publish is lost on app kill. Proposed default: persist the payload and offer re-post.
- FED-E03 (bug): graph failure caches an own-posts-only feed for 5 minutes. Proposed default: do not set the TTL when the graph failed, and show the error.
- FED-78: Save workout has no "saved" list. Either build the list or remove the menu item.
- POS-15: PR flag in post detail is derived from improvement order; store a per-exercise PR flag in the post if exactness matters.
- POS-33: gold PR colour vs the "PR is a treatment, not a color" design rule.
- CMT-E06: filter comments from users I blocked. Proposed default: yes.
- CMT-E01 / PRF-E01 (bug): load failures render as "empty" or "Private profile". Proposed default: show an error with RETRY and never cache the placeholder on network errors.
- FRD-E10: ignored requests are per device. Proposed default: keep local.
- FRD-E14: no way to remove a fan without blocking. Proposed default: leave as is.
- FRD-69 / FRD-72: contacts matching and shareable invite links are not built; spec line 247 still lists them. Decide whether to update the spec or build them.
- FRD-E06: lists load only 80 profiles at a time. Proposed default: page the profile fetch.
- RPT-03 / RPT-E08: report reasons are fixed strings, no confirmation for post reports. Proposed default: reason sheet.
- RPT-33: no moderation tooling or SLA (App Store UGC requirement). Needs an owner process.
- RPT-E01: block should confirm the follow was removed (or delete both directions server side).
