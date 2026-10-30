# 09b Social: challenges, scoring, leaderboards, Supernova gating, Activity and counters

Scope: the CHALLENGES half of the Social tab, how scores and ranks are produced, the Activity ("bell") screen and the server counters. Sources: `Ore/Features/Social/Challenges/*`, `Features/Social/Friends/{ActivityView,InviteFriendsView}.swift`, `Features/Social/Logic/{ChallengeWindow,Leaderboard}.swift`, `Features/Social/SocialViewModel.swift`, `Core/Models/Challenge.swift` (`ChallengeMetric`, `ChallengeWinCondition`), `Core/Models/Firestore/FirestoreModels.swift`, `Core/Services/Firestore/*`, `firebase/firestore.rules`, `firebase/functions/src/{challenges,scoring,ranking,counters,follows,accountDeletion,index}.ts`. People, feed and privacy are in `09a-social-feed-friends.md`.

Model in one paragraph: a challenge is a Firestore document with a metric and a window (`startAt` to `endAt`). People join by writing a `members/{uid}` document. **The client never computes or writes a score**: Cloud Functions rescore a member from their synced workouts (`users/{uid}/workouts`, see 12 SYN) whenever a workout changes and write `entries/{uid}` with score, rank, previous rank and `scoreAt`. The app only orders and displays those entries. Clients can create only private (invite-only) challenges; global challenges are created with the Admin SDK (no in-app admin screen). Status flips to `ended` in a daily job; the app also treats a challenge as ended as soon as `endAt` has passed.

The old `Challenge` / `LeaderboardEntry` SwiftData models in `Core/Models/Challenge.swift` are unused by the Social tab (only the metric and win-condition enums are used).

`docs/audit/social-firestore.md` (challenge scoring "does not exist", demo global challenge, 28-day window ignored, accept does not join) is STALE; all of those are fixed in code.

---

## CHL  Challenges tab, joining, leaderboard, leaving, ended

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CHL-03 | User taps the CHALLENGES segment → App loads the follow graph, then my challenges (ones I created, newest 50, plus ones I am a member of), the active global challenges (max 10, soonest ending first), my pending invites, and the global board; it then loads boards for up to 10 active friend challenges | ✅ `ChallengesView.load`, `SocialViewModel.loadChallenges` | [ ] | — |
| CHL-06 | System: nothing loaded yet → App shows 3 skeleton rows | ✅ | [ ] | — |
| CHL-09 | Load fails and nothing is cached → App shows "Couldn't load your challenges." or "Couldn't load the global challenge." with RETRY; the two loads are independent so one failure does not blank the other | ✅ | [ ] | — |
| CHL-12 | A global challenge is active → App shows a "Global" card: "Ends 31 Oct", "SET BY PULSE · 1 Oct–31 Oct", the name in caps, a metric subheading (e.g. "EVERY KG LIFTED · ALL SESSIONS COUNT", unit-aware "LB"), and three tiles: Your Total (compact, e.g. 13.4K), Rank with "OF <memberCount>", To Next | ✅ `globalChallengeCard` | [ ] | — |
| CHL-15 | User has not joined the global challenge and taps "JOIN" → App shows "JOINING…", writes the member document and, on success, adds it to my list and loads the board; the function scores the user at once from workouts already in the window | ✅ `join()` | [ ] | — |
| CHL-18 | User has joined → The card's action becomes "VIEW LEADERBOARD ›" which opens the global leaderboard | ✅ | [ ] | — |
| CHL-21 | Several global challenges are active → App shows only one card: the first active one in the list (global list first, then my own global ones) | 🟡 `SocialViewModel.globalChallenge` | [ ] | — |
| CHL-24 | I have pending invites → App shows "Invites" (count) with rows: challenge name, "INVITED BY @HANDLE" (or "A FRIEND"), JOIN and IGNORE | ✅ `inviteRow` | [ ] | — |
| CHL-27 | I have active friend challenges → App shows "Friend Challenges" "N Active" with rows: name, time left ("12D LEFT" or "5H LEFT", minimum 1H), "METRIC · N PARTICIPANT(S)", tiles You (score) and Position, and "›"; the row opens the leaderboard | ✅ | [ ] | — |
| CHL-30 | I have no active friend challenges → App shows "No friend challenges." and a dashed "Create Challenge" | ✅ | [ ] | — |
| CHL-33 | I have active friend challenges → App also shows a dashed "Create Challenge" under the list | ✅ | [ ] | — |
| CHL-36 | I have ended challenges → App shows "Ended" (count) with rows: name, "ENDED 9 OCT", and my final place (e.g. "2ND") | 🟡 place shows only if the board was loaded earlier (the tab preloads boards for active challenges only) | [ ] | — |
| CHL-39 | User pulls down → App reloads graph, challenges, invites and boards | ✅ | [ ] | — |
| CHL-42 | User opens a friend challenge → App shows the name in caps, the line "METRIC [· EXERCISE] · N PEOPLE" ("1 PERSON" when one), "+ INVITE" (only if the challenge is active and I am creator or member), tiles Your Count, Position, Ends, and a table # / ATHLETE / COUNT / MOVE | ✅ `ChallengeLeaderboardView` | [ ] | — |
| CHL-45 | Rows render → App shows rank, avatar, name ("You" for me, highlighted with an accent bar), score in the user's unit (whole numbers), and MOVE as "▲ n", "▼ n" or "—"; ranks 1 to 3 use gold / steel / bronze colours | ✅ | [ ] | — |
| CHL-48 | Board is empty → App shows "NO ONE IS ON THE BOARD YET · SCORES UPDATE AS WORKOUTS ARE LOGGED" | ✅ | [ ] | — |
| CHL-51 | User pulls down on a leaderboard → App reloads that board | ✅ | [ ] | — |
| CHL-54 | User taps "..." (Challenge options) → App offers "Leave challenge" (members who are not the creator) and "Report challenge" | ✅ | [ ] | — |
| CHL-57 | User taps Leave challenge → App asks "Leave <name>?" / "You'll come off the board and your score is removed." (Leave / Cancel); Leave deletes my member document, the function deletes my entry, re-ranks the others and lowers `memberCount`, and the screen closes | ✅ | [ ] | — |
| CHL-60 | Leave fails → App alerts "Couldn't leave the challenge. Try again." and stays | ✅ | [ ] | — |
| CHL-63 | User opens an ended challenge → App shows a chip "ENDED 9 OCT", "METRIC · N PEOPLE", the WINNER band (name in caps, gold, with "BEST" score) only when the top row has a score above 0, tiles You Finished (ordinal, e.g. "2ND"), Your Best, People (the larger of `memberCount` and rows), and the "Final" board | ✅ `ChallengeEndedView` | [ ] | — |
| CHL-66 | Ended board where nobody scored → App shows "NO WINNER · NOBODY SCORED" | ✅ | [ ] | — |
| CHL-69 | User taps "RUN IT AGAIN ›" on an ended friend challenge → App creates a new challenge now with the same name, metric, exercise and visibility, lasting the same number of days ("SAME METRIC, NEW N DAYS"), joins me, and closes the screen; invites are not copied | ✅ `runAgain`; not offered for global challenges | [ ] | — |
| CHL-72 | System: `endAt` passes → App moves the challenge from Active to Ended at the next render, even before the server marks it ended | ✅ `SocialChallenge.isEnded` | [ ] | — |
| CHL-75 | User tries to join after the end → Rules refuse (challenge must be active and `endAt` in the future); App alerts "This challenge has ended." (or "Couldn't join. Try again." if it believes it is still open) | ✅ | [ ] | — |
| CHL-78 | User wants to delete or end their own challenge early → App has no such action (the rules allow the creator to delete or rename, nothing calls it); the creator cannot leave their own challenge | ❌ | [ ] | — |

### CHL edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CHL-E01 | Offline | Lists keep their last state; errors show only when empty; leaderboard shows skeleton rows forever because a failed board load leaves the board unset | Expected: an error with RETRY | 🐞 `SocialViewModel.swift:812` (`guard let fetched = try? ... else { return }`), views show `SkeletonRows` while `board == nil` | [ ] | — |
| CHL-E02 | Creator deleted the challenge (outside the app) | It disappears from my list; the unreadable document is skipped | | ✅ `fetchMyChallenges` | [ ] | — |
| CHL-E03 | Challenge created by someone I do not know and I am not a member/invitee | Rules deny reading it | | ✅ | [ ] | — |
| CHL-E04 | More than 50 challenges created by me | Only the newest 50 show | | 🟡 | [ ] | — |
| CHL-E05 | Member count shown vs actual | Count is function-maintained and may lag; the Position tile uses entries, the participant line uses `memberCount` | | 🟡 | [ ] | — |
| CHL-E06 | Two taps on JOIN | Button disabled while "JOINING…"; a repeat member write is refused by the rules (update false) and would show "Couldn't join. Try again." | | 🟡 | [ ] | — |
| CHL-E07 | Time left near the end | "5H LEFT", then moves to Ended; day count uses the device calendar | | ✅ | [ ] | — |
| CHL-E08 | Dates in the card use the device timezone and locale | e.g. "9 Oct" | Server flips status at 03:00 Sydney, the app uses the absolute `endAt` | ✅ | [ ] | — |
| CHL-E09 | Tie for first place on an ended challenge | Both rows show rank 1; the WINNER band names only the first-listed (earliest `scoreAt`) | 🧭 PROPOSED: show "TIED" and both names | 🧭 | [ ] | — |
| CHL-E10 | Winner is hidden from a global board | Hidden entries are not readable by others, so the winner band shows the next visible row | | 🟡 | [ ] | — |
| CHL-E11 | I left after the end | Challenge stays in Ended only while I can still read it (creator, or member); after leaving I lose access | | 🟡 | [ ] | — |
| CHL-E12 | Report challenge | Writes a report (reason "Inappropriate challenge"); no confirmation | | 🟡 | [ ] | — |
| CHL-E13 | Weights in lbs | Weight-based scores (volume, heaviest lift) display converted; hold, reps and sessions do not | Stored scores are kg | ✅ | [ ] | — |

---

## CHC  Creating a challenge and inviting friends

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CHC-03 | User taps "Create Challenge" → App pushes "NEW CHALLENGE" with a name field "Name your challenge", the "Measured By" list, "Runs For" chips and a docked "NEXT ›" bar labelled "STEP 2 · INVITE FRIENDS" | ✅ `CreateChallengeStep1View` | [ ] | — |
| CHC-06 | User reads Measured By → App lists 5 metrics (Custom is not offered), each with its unit label and rule: Total volume (KG LIFTED · "Every working set, summed"), Heaviest lift (BEST 1RM · "Top estimated single, one exercise"), Most reps (REPS · "Every rep logged, summed"), Longest hold (TIME HELD · "Best single hold — plank, dead hang, wall sit"), Sessions logged (WORKOUTS · "Any session over 10 minutes"); the default is Total volume | ✅ | [ ] | — |
| CHC-09 | User selects Heaviest lift → App shows an EXERCISE row that must be filled ("Choose one" in red) and opens the exercise picker full screen | ✅ | [ ] | — |
| CHC-12 | User selects Most reps or Longest hold → App shows an optional EXERCISE row ("Any exercise") | ✅ | [ ] | — |
| CHC-15 | User picks Total volume or Sessions logged → App shows no exercise row (the backend could filter volume by exercise, the app does not offer it) | 🟡 | [ ] | — |
| CHC-18 | User picks Runs For → App offers 1 WEEK (7 days), 4 WEEKS (28 days, default), REST OF <MON> (until the last second of the current month), 1 YEAR, CUSTOM (a date picker "Ends" from tomorrow, default +14 days); the challenge always starts now | ✅ `ChallengeWindow` | [ ] | — |
| CHC-21 | System: end date would not be after the start (e.g. REST OF month on the last second) → App uses start + 1 day | ✅ `endDate` guard | [ ] | — |
| CHC-24 | User has typed a name (1 to 100 characters after trimming) and, for Heaviest lift, chosen an exercise → App enables NEXT; otherwise it is dimmed and disabled | ✅ `canCreate` | [ ] | — |
| CHC-27 | User taps NEXT → App shows "…", creates the challenge (visibility invite, win condition highest, status active), joins the creator, reloads the lists and pushes "INVITE FRIENDS" | ✅ `createChallenge` | [ ] | — |
| CHC-30 | Create fails → App alerts "Couldn't create the challenge. Try again." and stays on step 1 | ✅ | [ ] | — |
| CHC-33 | Helper text → App shows "SCORED FROM LOGGED SESSIONS · NOTHING TO ENTER BY HAND · ONLY PEOPLE YOU INVITE CAN JOIN" | ✅ | [ ] | — |
| CHC-36 | User reaches step 2 → App shows "INVITE FRIENDS" with SKIP, the line "NAME · METRIC · ENDS 28 OCT", a "Search your friends" field (matches name or handle), "Your Friends" (count) and rows: name, @handle, "ND STREAK", INVITE | ✅ `InviteFriendsView` | [ ] | — |
| CHC-39 | User taps INVITE → App writes `invites/{challengeId}_{uid}` (status pending) and the pill becomes a disabled "INVITED"; the bottom bar counts "N INVITED" | ✅ | [ ] | — |
| CHC-42 | Invite write fails → App alerts "Couldn't send the invite. Try again." and the pill stays INVITE | ✅ | [ ] | — |
| CHC-45 | User taps "Share Invite" → App opens the share sheet with "I started a challenge on Ore: <name>. Get the app and add me (@handle) to join." (a text hint only; no join link) | ✅ | [ ] | — |
| CHC-48 | User taps SKIP or "DONE ›" → App dismisses step 2; the challenge already exists | ✅ | [ ] | — |
| CHC-51 | Invitee opens the Challenges tab or Activity → App shows the invite (see CHL-24 and ACT-15) | ✅ | [ ] | — |
| CHC-54 | Invitee taps JOIN / ACCEPT → App writes the member document first (the rules require the invite), then marks the invite accepted, removes it from the inbox and reloads challenges | ✅ `respond(accept: true)` | [ ] | — |
| CHC-57 | Accept fails (e.g. challenge ended or deleted) → App alerts "Couldn't join. The challenge may have ended." and the invite stays pending | ✅ | [ ] | — |
| CHC-60 | Invitee taps IGNORE → App marks the invite declined and removes it; failure alerts "Couldn't update the invite. Try again." | ✅ | [ ] | — |
| CHC-63 | Existing member invites more people from the leaderboard "+ INVITE" → Same screen and rules (creator or member may invite) | ✅ | [ ] | — |
| CHC-66 | InviteFriendsView copy → App says "PEOPLE YOU INVITE CAN JOIN UNTIL THE CHALLENGE ENDS · LATE JOINERS ARE SCORED FROM THE DAY THEY JOIN" but the backend scores a joiner from the challenge start (all their workouts inside the window, including ones before they joined) | 🐞 copy: `InviteFriendsView.swift:59`; behaviour: `functions/src/challenges.ts` `recomputeUserInChallenge`, `index.ts` `onMemberWritten`. Design README marks this as an open product question | [ ] | — |

### CHC edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CHC-E01 | Name of 101+ characters | NEXT stays disabled; no counter shown | | ✅ | [ ] | — |
| CHC-E02 | Duplicate names | Allowed | | ✅ | [ ] | — |
| CHC-E03 | Double tap NEXT | Button disabled while creating; one challenge | | ✅ | [ ] | — |
| CHC-E04 | Challenge document is created but the creator-join then fails | Error alert is shown and the user stays on step 1, but the challenge exists and appears in the list; the creator is not a member, so has no entry | 🧭 PROPOSED: retry the join, or delete the orphan | 🟡 | [ ] | — |
| CHC-E05 | Create offline | Error alert; nothing created | | ✅ | [ ] | — |
| CHC-E06 | Heaviest lift with the picker closed without a choice | NEXT stays disabled | | ✅ | [ ] | — |
| CHC-E07 | Changing metric away from exercise-capable metrics | Chosen exercise is cleared | | ✅ | [ ] | — |
| CHC-E08 | Custom end date | Date picker starts tomorrow, so a past or same-day end cannot be chosen | | ✅ | [ ] | — |
| CHC-E09 | Month end in a different timezone | The end is computed with the device calendar; scoring compares absolute instants | | ✅ | [ ] | — |
| CHC-E10 | Invitee blocked the inviter | Rules refuse the invite; app alerts "Couldn't send the invite. Try again." | | ✅ | [ ] | — |
| CHC-E11 | Invite sent twice | Existing invite is detected and not rewritten (success) | | ✅ | [ ] | — |
| CHC-E12 | Invite sent to someone who is already a member | Allowed; harmless | | ✅ | [ ] | — |
| CHC-E13 | Invite after the challenge ended | "+ INVITE" is hidden; the rules do not check the end for invites | | ✅ | [ ] | — |
| CHC-E14 | Invitee opens an invite to a deleted challenge | JOIN fails with "Couldn't join. The challenge may have ended."; IGNORE still works | | ✅ | [ ] | — |
| CHC-E15 | More than 25 pending invites | Only the newest 25 show | | 🟡 | [ ] | — |
| CHC-E16 | Visibility values "friends" and "public" | Exist in the model and rules; the app only ever creates "invite" | | 🟡 | [ ] | — |
| CHC-E17 | Invite candidates | Only mutual friends are listed in the app; the rules would allow inviting anyone who has not blocked the inviter | | ✅ | [ ] | — |

---

## CHS  Scoring windows, metrics, ranking and ties (Cloud Functions)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CHS-03 | User finishes, edits or deletes a workout (after it syncs to `users/{uid}/workouts`) → Function `onWorkoutWritten` rescores the user in every active, scored challenge they belong to where the old or new workout date is inside the window; the entry updates and the app shows it on the next load or pull-to-refresh | ✅ `functions/src/index.ts`, `challenges.ts` `handleWorkoutChange` | [ ] | — |
| CHS-06 | System: window rule → A workout counts when `startAt <= workout date <= endAt` (both inclusive, absolute instants). A challenge starts when created, so earlier workouts that day do not count | ✅ `scoring.ts` `inWindow` | [ ] | — |
| CHS-09 | System: eligibility → Soft-deleted workouts (`deletedAt`) are ignored; warm-up sets never count; exercise name filters are case and whitespace insensitive | ✅ `eligibleWorkouts`, `isWorkingSet` | [ ] | — |
| CHS-12 | Metric Total volume → Score = sum of weight(kg) x reps over working sets (only the named exercise when one is set), rounded to 2 decimals | ✅ | [ ] | — |
| CHS-15 | Metric Heaviest lift → Score = best estimated one-rep max (Epley: weight x (1 + reps/30); one rep counts as the weight) over working sets of the named exercise, 2 decimals; the board shows it rounded to a whole number in the user's unit | ✅ | [ ] | — |
| CHS-18 | Metric Most reps → Score = total reps over working sets (optionally one exercise) | ✅ | [ ] | — |
| CHS-21 | Metric Longest hold → Score = longest single set duration in seconds; the app shows the raw seconds as a whole number under "TIME HELD" (e.g. "95"), not as m:ss | 🟡 formatting: `ChallengeMetric.formatScore` | [ ] | — |
| CHS-24 | Metric Sessions logged → Score = number of workouts of at least 600 seconds (10 minutes; exactly 600 counts) | ✅ `MIN_SESSION_SECONDS`; the UI text says "over 10 minutes" | [ ] | — |
| CHS-27 | Metric Custom ("Everyone types their own score") → Functions never touch it; a joiner gets a 0 placeholder; the app has no way to enter a score and the rules forbid client writes to entries | ❌ create screen hides Custom; a global custom challenge would stay at 0 | [ ] | — |
| CHS-30 | Win condition → Only "highest" is created by the app; the ranker supports "lowest" (ascending) but no screen sets it; "First to Reach Goal" exists as an enum case with no goal field and ranks as highest | ❌ / 🟡 | [ ] | — |
| CHS-33 | System: ranking → Better score first; equal scores share a rank (competition ranking 1, 1, 3) and are listed by earliest `scoreAt` (when the score last changed to its current value), then uid; `previousRank` becomes the old rank whenever the rank changes | ✅ `ranking.ts`, `Leaderboard.rows` | [ ] | — |
| CHS-36 | System: movement → App shows ▲ n / ▼ n from `previousRank - rank`; "—" for new or unchanged entries | ✅ | [ ] | — |
| CHS-39 | User joins an active challenge → Function scores them at once from existing workouts in the window; a Custom challenge gets a 0 entry | ✅ `onMemberWritten` | [ ] | — |
| CHS-42 | System: score did not change → Entry and `scoreAt` are not rewritten, so an earlier tie-break is preserved | ✅ `applyScore` | [ ] | — |
| CHS-45 | System: member leaves → Entry deleted, others re-ranked | ✅ | [ ] | — |
| CHS-48 | System: window ends → Workouts after `endAt` no longer change the score even before status flips; once status is `ended` no rescoring happens | ✅ `activeScoredMemberships` filters active; window excludes later workouts | [ ] | — |
| CHS-51 | System: daily at 03:00 Sydney time (and by an admin callable) → Every active challenge with `endAt` passed becomes `ended` | ✅ `closeEndedChallengesNow` | [ ] | — |
| CHS-54 | System: client has fresh entries but not all ranked → App ranks locally with the same competition rule so a brand-new board reads correctly; movement is 0 in that case | ✅ `Leaderboard.rows` | [ ] | — |
| CHS-57 | Board larger than 450 changes in one go → The user's entry is written in the transaction; the rest of the rank changes are written afterwards in bulk | ✅ | [ ] | — |

### CHS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CHS-E01 | Two members have the same score | Both show rank 1; the next member shows 3; order follows earliest `scoreAt`; both rows display "1ST" on the ended screen | | ✅ | [ ] | — |
| CHS-E02 | Tie in the middle: the lower tied member reads "To next" | Gap uses the nearest better-ranked row, so the second of a tie at rank 2 gets the gap to rank 1 | `gapToNext` | ✅ | [ ] | — |
| CHS-E03 | Tied for first | "To Next" shows "—" (no better rank) | | ✅ | [ ] | — |
| CHS-E04 | Someone overtakes a tied pair | Tie members keep a shared rank; both get `previousRank` = old rank | | ✅ | [ ] | — |
| CHS-E05 | Scores compared for equality after 2-decimal rounding | Different raw values rounding to the same score tie | | ✅ | [ ] | — |
| CHS-E06 | Everyone has score 0 | All rank 1; ended screen says "NO WINNER · NOBODY SCORED" | | ✅ | [ ] | — |
| CHS-E07 | Workout is edited into or out of the window | Both the old and the new dates are checked, so the score is recomputed either way | | ✅ | [ ] | — |
| CHS-E08 | Workout edited after the challenge ended | No change (status ended, or date outside the window) | | ✅ | [ ] | — |
| CHS-E09 | Workout not yet synced (offline) | Score lags until the sync layer pushes it (see 12 SYN) | | 🟡 | [ ] | — |
| CHS-E10 | Workout dated in the future | Counts only once the window includes that instant; a future date inside the window counts immediately | | 🟡 | [ ] | — |
| CHS-E11 | Exercise renamed or custom exercise | Match is by exercise name text, so a rename drops it from per-exercise challenges | | 🟡 | [ ] | — |
| CHS-E12 | Negative or non-numeric values in a workout | Treated as 0 for non-finite values; Epley ignores weight or reps <= 0 | | ✅ | [ ] | — |
| CHS-E13 | Timezone / DST | All comparisons are absolute UTC instants; no calendar-day logic in scoring | | ✅ | [ ] | — |
| CHS-E14 | Concurrent workout writes by the same user | The recompute re-reads all workouts, so it converges | | ✅ | [ ] | — |
| CHS-E15 | Account deleted | Entry and membership removed and the board re-ranked; challenges created by them are deleted only when empty | | ✅ `accountDeletion.ts` | [ ] | — |

---

## CHG  Global leaderboard

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CHG-03 | User taps "VIEW LEADERBOARD ›" on the global card → App shows the challenge name, filter chips "Global" and "Friends", and a table # / ATHLETE / SCORE | ✅ `GlobalLeaderboardView` | [ ] | — |
| CHG-06 | System: board loads → App fetches the top 50 visible entries ordered by rank, plus my own entry; if my rank is beyond 50 it also fetches ranks mine-2 to mine+2 | ✅ `loadBoard` | [ ] | — |
| CHG-09 | Board has more than 8 other rows → App shows ranks 1 to 5 and the rows within 2 places of me, with a "· · ·" separator where ranks skip | ✅ `Leaderboard.condensed` | [ ] | — |
| CHG-12 | User taps "Friends" → App keeps global ranks but shows only me and my friends; the empty text is "NONE OF YOUR FRIENDS ARE ON THIS BOARD YET" | ✅ | [ ] | — |
| CHG-15 | I am on the board → App pins my row above the tab bar: rank, "You", "<gap> TO <ordinal>" (e.g. "1,250 TO 2ND") and score | ✅ `pinnedRow` | [ ] | — |
| CHG-18 | I am not on the board and not a member → App shows the dock "YOU'RE NOT ON THIS BOARD" and "JOIN ›" | ✅ | [ ] | — |
| CHG-21 | I set Global leaderboards to Hidden and I am on the board → App shows "YOU'RE HIDDEN FROM OTHERS ON THIS BOARD · CHANGE IT IN ACTIVITY › PRIVACY" | ✅ | [ ] | — |
| CHG-24 | Another member is hidden → Their entry is not returned (rules and `hidden == false` query); ranks still count them, so the visible list can skip numbers | ✅ | [ ] | — |
| CHG-27 | Board is empty → App shows "NO ONE IS ON THE BOARD YET" | ✅ | [ ] | — |
| CHG-30 | A hidden entry belongs to me → The server omits my username from it, so my row reads "You" in the pinned bar | ✅ | [ ] | — |

### CHG edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CHG-E01 | Offline or fetch error | Skeleton rows remain | See CHL-E01 | 🐞 | [ ] | — |
| CHG-E02 | Toggling hidden after joining | Entry changes only on the next score write | See PRV-E06 in 09a | 🐞 | [ ] | — |
| CHG-E03 | Global challenge ends | Moves to Ended (not re-runnable); the daily job closes it | | ✅ | [ ] | — |
| CHG-E04 | Rank neighbourhood fetch fails | Silently skipped; the pinned row still shows | | 🟡 | [ ] | — |
| CHG-E05 | Creating global challenges | Not possible in the app or by clients (rules require Admin SDK); seeded via `firebase/seed/seed.mjs` for the emulator | 🧭 PROPOSED: owner needs an operator process (script or console) for monthly challenges | 🧭 | [ ] | — |
| CHG-E06 | "SET BY PULSE" label | Hard-coded on the card for every global challenge | | ✅ | [ ] | — |

---

## CHP  Supernova gating of challenges

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CHP-03 | Free user taps "Create Challenge" → App lets them create (no subscription check anywhere in Social) | ❌ spec `docs/pulse-pump-spec.md:255` says "Challenges (Supernova only): Any Supernova user can create"; known gap at spec line 424 | [ ] | — |
| CHP-06 | Free user joins a global challenge or accepts an invite → App allows it | 🧭 PROPOSED: joining stays free; only creation requires Supernova (matches the spec sentence) | [ ] | — |
| CHP-09 | Free user taps "Create Challenge" (once gated) → 🧭 PROPOSED: open the Supernova paywall (see 10 PLS / 13 GAT); existing challenges remain usable after a lapse | 🧭 | [ ] | — |
| CHP-12 | Developer launches a DEBUG build with `-devDataPlus 1` → App treats the user as Supernova for gated features (no effect on challenges today) | 🟡 | [ ] | — |

---

## ACT  Activity (bell) screen

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| ACT-03 | User looks at the Social header → App shows a bell with a small accent dot when anything needs attention (friend requests + challenge invites > 0); there is no number | ✅ `inboxCount` | [ ] | — |
| ACT-06 | User taps the bell → App pushes "ACTIVITY" with a back arrow and loads the graph, invites and privacy | ✅ | [ ] | — |
| ACT-09 | Section "Needs You" with a count → App lists friend requests first, then challenge invites | ✅ | [ ] | — |
| ACT-12 | Nothing waiting → App shows "NOTHING NEEDS YOU RIGHT NOW" | ✅ | [ ] | — |
| ACT-15 | A fan is waiting → App shows "<name> wants to be friends" with "@HANDLE FOLLOWS YOU" and ACCEPT / IGNORE (follow back / dismiss locally) | ✅ | [ ] | — |
| ACT-18 | A challenge invite is waiting → App shows "<from> invited you to <challenge>" ("Someone" if unknown) with "CHALLENGE INVITE" and ACCEPT (joins) / IGNORE (declines) | ✅ | [ ] | — |
| ACT-21 | User handles an item → App removes the row and lowers the badge | ✅ | [ ] | — |
| ACT-24 | User scrolls to Privacy → App shows the four rows described in PRV-03 to PRV-27 (09a) | ✅ | [ ] | — |
| ACT-27 | User scrolls to Safety → App shows "Blocked people" with the count and a chevron to the blocked list (RPT-27 in 09a) | ✅ | [ ] | — |
| ACT-30 | User looks for likes, comments, joins or past events → App has no history: only open requests and invites (the old hardcoded "Earlier" list was removed) | 🟡 spec `docs/pulse-pump-spec.md:257` expects configurable social notifications | [ ] | — |
| ACT-33 | User expects a push for friend requests, likes, comments or invites → App sends none (no push pipeline for social; invites live in this screen by design) | ❌ see 14 NTF | [ ] | — |
| ACT-36 | System: bell state at launch → Dot reflects fan requests once the graph loaded (Social tab) but includes invites only after Challenges tab or Activity has loaded invites | 🟡 `SocialViewModel.inboxCount` | [ ] | — |

### ACT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| ACT-E01 | Invite from someone I blocked | Hidden | | ✅ | [ ] | — |
| ACT-E02 | Fan whose account was deleted | Dropped from the count | | ✅ | [ ] | — |
| ACT-E03 | Accept on a friend request offline | Rolls back; alert "Couldn't follow. Try again." | | ✅ | [ ] | — |
| ACT-E04 | Ignored fan | Row disappears and does not return, even after relaunch (stored per account); not synced to other devices | | ✅ | [ ] | — |
| ACT-E05 | Privacy save failure | Red line under the privacy rows (see PRV-24 in 09a) | | ✅ | [ ] | — |
| ACT-E06 | Many pending items | Fan list unbounded, invites limited to 25 | | 🟡 | [ ] | — |
| ACT-E07 | Not signed in | Screen loads nothing; both lists empty | | ✅ | [ ] | — |

---

## CTR  Server-owned counters

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CTR-03 | System: a like is created or deleted → `onLikeWritten` adds or subtracts 1 on `posts/{id}.likeCount` (never below 0, idempotent per event id; event ids expire after 7 days) | ✅ `counters.ts` | [ ] | — |
| CTR-06 | System: a comment is created or deleted → `onCommentWritten` does the same for `commentCount` | ✅ | [ ] | — |
| CTR-09 | System: a follow edge is created or deleted → `onFollowWritten` recomputes `friendCount` and `fanCount` for both people from the edges that exist now, so out-of-order events converge | ✅ `follows.ts` | [ ] | — |
| CTR-12 | System: a member joins or leaves → `onMemberWritten` adjusts `memberCount` | ✅ | [ ] | — |
| CTR-15 | User tries to change a counter from the client → Rules reject creates with non-zero counters and updates that change them | ✅ `zeroOrAbsent`, `unchanged` | [ ] | — |
| CTR-18 | System: delivery is at-least-once → Duplicate events do nothing (`_events` marker in the same transaction) | ✅ | [ ] | — |
| CTR-21 | System: counters shown in the app → Client shows server values on fetch and its own +1/-1 in between; no live listeners | ✅ | [ ] | — |

### CTR edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CTR-E01 | Function delayed or failing | Counts lag; client shows the optimistic value, then the server value on refresh | | 🟡 | [ ] | — |
| CTR-E02 | Blocks | `friendCount` / `fanCount` ignore blocks; the app's own lists subtract blocked people, so the profile header (server counter) and the lists can differ | | 🟡 | [ ] | — |
| CTR-E03 | Deleted account | `deleteAccount` removes their follows, likes, comments, posts, memberships, invites and handles; the triggers fix the other side's counters; their profile and `users/{uid}` tree go last; safe to rerun | | ✅ | [ ] | — |
| CTR-E04 | Challenge created by a deleted account | Deleted only when nobody else is in it; otherwise kept for the other members | | ✅ | [ ] | — |
| CTR-E05 | Creator deletes a challenge document directly | Subcollections (members, entries) are not removed by any function; members stop seeing it | Not reachable from the app | 🟡 | [ ] | — |

---

## Open decisions for the owner (09b)

- CHC-66 (bug/decision): copy says late joiners are scored from the day they join; the backend scores from challenge start. Design README lists this as an open question. Proposed default: keep scoring from start (simplest, honest total) and change the copy to "ALL WORKOUTS SINCE THE START COUNT".
- CHP-03 / CHP-06 / CHP-09: Supernova gating of challenge creation is in the spec but not built. Proposed default: gate creation only, joining stays free.
- CHS-27: Custom metric has no way to enter scores and is hidden from creation. Proposed default: remove Custom from the product, or add a callable function to submit a score.
- CHS-30: win conditions "lowest" and "First to Reach Goal" have no UI (first has no goal field). Proposed default: drop them from the enum or build a goal field.
- CHS-21: Longest hold shows seconds as a plain number. Proposed default: format as m:ss.
- CHL-78: creators cannot delete or end a challenge, or leave it. Proposed default: add "End challenge" (creator) and keep "Leave" for members.
- CHL-E01 / CHG-E01 (bug): a failed board load leaves skeleton rows forever. Proposed default: show an error with RETRY.
- CHL-36: ended rows show a place only if the board was opened earlier. Proposed default: load boards for the first few ended challenges too.
- CHL-21: only one global challenge card is shown. Proposed default: keep (monthly challenge assumed).
- CHL-E09: ties for first on the ended screen show a single winner. Proposed default: show "TIED" with both names.
- CHC-E04: orphan challenge when the creator join fails. Proposed default: retry the join automatically or delete the orphan.
- CHC-E16: visibility "friends" / "public" are unused. Proposed default: keep invite-only for now.
- CHG-E05: no in-app or documented operator process to create the monthly global challenge. Proposed default: a documented script using the Admin SDK.
- PRV-E06 (see 09a): hiding from global boards does not update existing entries until the next score write.
- ACT-30 / ACT-33: no activity history and no social push notifications (spec wants configurable ones). Decide scope; see 14 NTF.
- ACT-36: bell dot may miss invites until the Challenges tab or Activity loads. Proposed default: load invites together with the graph at Social tab open.
- CTR-E02: server friend/fan counters ignore blocks. Proposed default: accept the difference.
