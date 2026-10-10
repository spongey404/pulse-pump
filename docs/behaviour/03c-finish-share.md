# 03c Workout logging: finish, completion summary, calories, caption and post, share card

Scope: tapping FINISH WORKOUT, how the session is converted into a saved workout, the numbers shown on the completion screen (PRs, improved, streak, calories), the caption and photo composer, tagging friends, posting to the feed and the on-screen share card.
Key sources: `Features/Workout/WorkoutViewModel.swift` (`completeWorkout`), `Features/Workout/Views/WorkoutCompletionView.swift`, `Views/TagFriendsSheet.swift`, `Views/ShareCardView.swift`, `Services/FeedPostBuilder.swift`, `Services/CalorieEstimationService.swift`, `Features/Social/SocialViewModel.swift` (`publishWorkoutPost`), `Core/Services/Firestore/SocialWire.swift`, `App/ContentView.swift`.

Status legend: ✅ implemented and verified in code | 🟡 partial | ❌ not built | 🐞 known bug | 🧭 proposed (owner decides).

## FIN  Finishing a workout and the completion summary

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| FIN-03 | User taps FINISH WORKOUT when every set is ticked ("DONE ›" on the bar) → App finishes at once with no confirmation | ✅ `ActiveWorkoutView.swift:365-370` | [ ] | — |
| FIN-06 | User taps FINISH WORKOUT with unticked sets ("N LEFT") → App shows "Finish with unlogged sets?" and "<N> unlogged set(s) across <M> exercise(s) will be removed." with buttons "CANCEL" and "REMOVE + FINISH" | ✅ `ActiveWorkoutView.swift:211-217` | [ ] | — |
| FIN-09 | User taps "REMOVE + FINISH" → App finishes; unticked rows are not saved and exercises with no ticked set are dropped from the workout | ✅ `WorkoutViewModel+Draft.swift:47-48,91` | [ ] | — |
| FIN-12 | User taps "CANCEL" or the scrim in that dialog → App returns to the session, nothing changed | ✅ | [ ] | — |
| FIN-15 | System: finish runs → App stops the duration clock, rest timer and Live Activity, stores duration (elapsed seconds) and notes, reconciles logs a final time, flips `isDraft` to false and marks the workout dirty for cloud sync | ✅ `WorkoutViewModel.swift:231-246` | [ ] | — |
| FIN-18 | System: after saving → App refreshes widget data and swaps the session cover for the completion cover | ✅ `WorkoutViewModel.swift:377-381`, `ContentView.swift:52-61` | [ ] | — |
| FIN-21 | System: counting sets → App counts only ticked, non-warm-up sets, per exercise that has at least one; warm-ups are saved but never counted in sets, volume, PRs, calories, muscles or the post | ✅ `WorkoutViewModel.swift:260-266` | [ ] | — |
| FIN-24 | System: weight PR rule → App flags a weight PR when this workout's heaviest working weight for the exercise exceeds the heaviest working weight in all earlier finished workouts and that earlier best was above 0 | ✅ `WorkoutViewModel.swift:283` | [ ] | — |
| FIN-27 | System: rep PR rule (checked only when no weight PR) → App flags a rep PR when the best reps this workout beat the best reps ever done at a weight at or below this workout's best weight (0.01 kg tolerance), and that earlier value was above 0 | ✅ `WorkoutViewModel.swift:294` | [ ] | — |
| FIN-30 | System: the first time an exercise is ever done → App flags no PR and no improvement for it | ✅ `previousBestWeight > 0` guard | [ ] | — |
| FIN-33 | System: "improved" → App counts an exercise as improved when its best Epley 1RM (weight x (1 + reps/30); reps-only sets use the rep count) is more than 0.01 above the previous best; equal does not count | ✅ `WorkoutViewModel.swift:307-311,385-387` | [ ] | — |
| FIN-36 | System: streak → App recounts all finished workouts including this one with the 3-day gap rule and shows at least 1 | ✅ `WorkoutViewModel.swift:353-356` | [ ] | — |
| FIN-39 | System: per-exercise "vs last" values → App stores the gained kg for weight PRs and gained reps for rep PRs, plus an improvement percentage, in the post payload | ✅ `WorkoutViewModel.swift:293,305,345-347` | [ ] | — |
| FIN-42 | User sees the completion screen → App shows the header "WORKOUT COMPLETE" with the template name (or "WORKOUT") and the date as "EEE D MMM" in capitals, a back "‹", the share card, the composer and a docked button | ✅ `WorkoutCompletionView.swift:193-226` | [ ] | — |
| FIN-45 | User sees the ticker strip → App scrolls: "<NAME> DONE", "N NEW PR(S) ★" (only if above 0), "IMPROVED i/n", "SETS", "KCAL", "DURATION" | ✅ `WorkoutCompletionView.swift:35-47` | [ ] | — |
| FIN-48 | System: duration text → App shows "N min" below one hour and "Xh Ym" from one hour; under a minute shows "0 min" | ✅ `WorkoutViewModel.swift:763-770` | [ ] | — |
| FIN-51 | User taps "‹" in the completion header → App closes the summary and returns to Home without posting. The workout stays saved | ✅ `ContentView.swift:58-60` | [ ] | — |
| FIN-54 | System: the completed workout → App appears in History, Calendar, Body tab, widgets and sync as in `05`, `06`, `11`, `12` | ✅ | [ ] | — |

### FIN edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| FIN-E01 | Finish with no exercises or no ticked set at all | Saves an empty workout (zero exercises), shows the summary with 0 sets and "0 min", counts toward the streak and History | `completeWorkout` has no minimum guard | 🧭 propose: block with "Log at least one set" | [ ] | — |
| FIN-E02 | Offline | Finish works fully offline; posting may fail (see PST-E01) | local-first | ✅ | [ ] | — |
| FIN-E03 | Kill the app on the completion screen | Workout is already saved; the summary and the chance to post are lost, and there is no later "post this workout" | Posting lives only in the composer | 🧭 propose: add "Share to feed" from workout detail | [ ] | — |
| FIN-E04 | Finish just after midnight | Workout dated by its start time; streak uses that date | | 🧭 | [ ] | — |
| FIN-E05 | Double-tap FINISH | First tap hides the session; second has no target | | ✅ | [ ] | — |
| FIN-E06 | Exercise not in the catalogue (deleted) | Sets count toward totals but PR/improved checks are skipped | `guard let exercise` | 🟡 | [ ] | — |
| FIN-E07 | Time- or distance-based exercise only | Weight and reps parse to 0; no PRs or volume; sets still counted | | 🟡 | [ ] | — |
| FIN-E08 | Bodyweight exercise with weight 0 | Rep PR logic applies only if earlier reps exist; weight PR never | `previousBestWeight > 0` | ✅ | [ ] | — |
| FIN-E09 | Weight typed in lbs | Stored kg; PR deltas are kg and shown in the user's unit | kg invariant | ✅ | [ ] | — |
| FIN-E10 | Two workouts logged for the same exercise on the same day | Second compares against the first as "previous" | | ✅ | [ ] | — |
| FIN-E11 | Free vs Pulse+ | Same flow and numbers (only MET calories differ, see CAL) | | ✅ | [ ] | — |

## KCL  Calorie estimate

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| KCL-03 | System: "Basic (set-based)" formula (default) → App estimates 10 kcal per working compound set and 6 per working isolation set (compound = push, pull, hinge, squat or carry pattern) | ✅ `CalorieEstimationService.swift:27-32` | [ ] | — |
| KCL-06 | System: "MET-Based" formula → App estimates 5.0 (moderate, fixed) x body weight in kg x duration in hours | ✅ `CalorieEstimationService.swift:36-40,83-89` | [ ] | — |
| KCL-09 | System: MET chosen but body weight is 0 or duration is 0 → App falls back to the basic formula | ✅ `CalorieEstimationService.swift:60-62` | [ ] | — |
| KCL-12 | User opens Settings › Workout › Calorie Formula as a free user → App offers only "Basic (set-based)"; Pulse+ and trial users also get "MET-Based" | ✅ `SettingsView.swift:130-132` | [ ] | — |
| KCL-15 | System: a user whose Pulse+ or trial ended while "met" is stored → App still uses MET at finish (the gate is only in the Settings list) | 🐞 expected: fall back to basic when not entitled; actual: `isSubscribed` defaults to true in the call `WorkoutViewModel.swift:318` | [ ] | — |
| KCL-18 | System: result → App stores the value on the workout (`calorieBurnEstimate`) and shows it as "KCAL n" in the ticker only | 🟡 not shown in the stats row or the post | [ ] | — |
| KCL-21 | User watches calories during the session → App shows nothing | ❌ see WK-54 | [ ] | — |

### CAL edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| KCL-E01 | Warm-ups only | 0 kcal on basic | warm-ups excluded | ✅ | [ ] | — |
| KCL-E02 | User weight stored in lbs | Stored kg; the formula uses kg | | ✅ | [ ] | — |
| KCL-E03 | Very long session (idle for hours) | MET scales with elapsed time | no idle detection | 🧭 | [ ] | — |

## FSM  Completion stats, body map and exercise table (what the card shows)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| FSM-03 | User looks at the stats row → App shows four blocks: SETS, "VOL · KG/LB" (weight x reps of working sets, compact like "13.4K"), STREAK "nD", PRS (gold) | ✅ `WorkoutCompletionView.swift:288-303` | [ ] | — |
| FSM-06 | User looks at the hero row → App shows a mini body map shaded by sets worked, a large "<improved>" count with "OF <n> IMPROVED", and, when PRs exist, "N NEW PR(S)" with the top PR's exercise and its gain (weight gain in the unit, or "N REP(S)") | ✅ `WorkoutCompletionView.swift:307-357` | [ ] | — |
| FSM-09 | User looks at the exercise table → App lists up to 7 exercises sorted by improvement score (largest first), each with name, set count, best set (highest weight x reps, "w×r", or "Nr" when weight is 0) and "▲" if improved else "—"; PR exercises are gold with a "PR" tag | ✅ `WorkoutCompletionView.swift:361-430` | [ ] | — |
| FSM-12 | System: more than 7 exercises → App adds "+N MORE" | ✅ `WorkoutCompletionView.swift:415-422` | [ ] | — |
| FSM-15 | System: table "best set" → App picks by volume (weight x reps), not by weight, so a light high-rep set can outrank a heavier set | 🟡 `WorkoutCompletionView.swift:428` | [ ] | — |
| FSM-18 | System: units → App shows volume, best set and PR gains in the user's unit | ✅ | [ ] | — |

## PST  Caption, photo, tag friends and posting

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PST-03 | User sees the composer → App shows the user's avatar (profile photo if loaded, else initial), a multi-line field with the placeholder "Add a caption" and a camera button | ✅ `WorkoutCompletionView.swift:434-473` | [ ] | — |
| PST-06 | User taps the camera → App opens the photo picker (images only); the chosen photo appears above the share card in a swipeable carousel with a "REMOVE" chip and two page dots | ✅ `WorkoutCompletionView.swift:55-119,162-176` | [ ] | — |
| PST-09 | User taps REMOVE → App removes the photo and the camera button returns | ✅ `WorkoutCompletionView.swift:67-76` | [ ] | — |
| PST-12 | User posts after adding a photo → App posts the stats and caption only; the photo is not uploaded or attached | 🐞 expected: photo goes with the post (or the camera is hidden); actual: image stays in local state `WorkoutCompletionView.swift:577-587` | [ ] | — |
| PST-15 | User taps "+ ADD" under "TAG FRIENDS" (hint "Friends Only ›") → App opens a "Tag Friends" sheet with a spinner, then a list of friends, or "No friends to tag yet" | ✅ `TagFriendsSheet.swift:14-72`, `WorkoutCompletionView.swift:476-505` | [ ] | — |
| PST-18 | System: who can be tagged → App lists only friends (mutual follows) | ✅ `TagFriendsSheet.swift:67-70` | [ ] | — |
| PST-21 | User taps a friend row → App toggles a checkmark; "Done" returns the selection, "Cancel" discards it | ✅ `TagFriendsSheet.swift:26-62` | [ ] | — |
| PST-24 | System: selected friends → App shows them as pills (avatar and name) before the "+ ADD" pill. To remove one the user reopens the sheet and unticks; pills have no remove button | 🟡 `WorkoutCompletionView.swift:481-490` | [ ] | — |
| PST-27 | User with auto-share on (default) taps "POST" → App publishes once and closes the summary immediately without waiting for the result | ✅ `WorkoutCompletionView.swift:139-144,577-587` | [ ] | — |
| PST-30 | User with auto-share off sees "DONE" instead of POST and taps it → App closes without posting | ✅ `WorkoutCompletionView.swift:139,590-592` | [ ] | — |
| PST-33 | User taps the "···" next to the main button → App slides up a sheet titled "SESSION SAVED EITHER WAY" with rows described in PST-36 to PST-45 | ✅ `WorkoutCompletionView.swift:514-544` | [ ] | — |
| PST-36 | User taps "Don't post" (note "STAYS IN YOUR HISTORY, NOBODY SEES IT") → App closes the summary without posting | ✅ | [ ] | — |
| PST-39 | User taps "Post without body map" ("STATS ONLY, NO BODY MAP") → App posts without the body-map document | ✅ `FeedPostBuilder.swift:46-49` | [ ] | — |
| PST-42 | With auto-share on, user taps "Never post automatically" ("POSTING BECOMES OPT-IN") → App turns auto-share off, closes without posting; next time the button reads DONE | ✅ `WorkoutCompletionView.swift:528-532` | [ ] | — |
| PST-45 | With auto-share off, user taps "Post to feed" ("SHARE THIS SESSION ONCE") → App posts this session once and leaves the setting off | ✅ `WorkoutCompletionView.swift:533-537` | [ ] | — |
| PST-48 | User taps the scrim behind the sheet → App closes the sheet and stays on the screen | ✅ | [ ] | — |
| PST-51 | User re-enables Settings › Privacy › Auto-Share to Feed → App sets the same stored flag (`autoShareToFeed`, default on) and POST returns | ✅ `SettingsView.swift:47,146` | [ ] | — |
| PST-54 | System: payload → App builds one post: id = the workout's id in lower case, author name and handle, workout name (or "Workout"), working sets only (muscle tags removed), stats (sets, volume kg, duration seconds, PR count), the trimmed caption and tagged uids | ✅ `FeedPostBuilder.swift:25-69` | [ ] | — |
| PST-57 | System: audience → App takes post audience and body-map audience from the privacy settings (defaults: friends and friends). If "Workout posts" is "Only me", nothing is posted and the user sees no message | 🟡 silent skip `FeedPostBuilder.swift:34-35` | [ ] | — |
| PST-60 | System: body map → App writes a separate `extras/bodymap` document with weighted sets per muscle (primary 1, secondary 0.5 per working set), unless the body-map audience is "Only me" or "Post without body map" was used | ✅ `FeedPostBuilder.swift:71-85` | [ ] | — |
| PST-63 | System: wire limits → App cuts the caption to 500 characters and tags to 20 when writing the document; the composer shows no counter | 🟡 `SocialWire.swift:160-162` | [ ] | — |
| PST-66 | System: the same workout is posted twice (double tap, retry) → App writes the same document id again (merge) and ignores a post already published in this run | ✅ `WorkoutCompletionView.swift:578-579`, `SocialViewModel.swift:638`, `FirestoreSocialRemote.swift:254-257` | [ ] | — |
| PST-69 | System: the post fails (offline, rules, not signed in) → App stores the post in memory as pending and sets the error "Your session didn't post. Try again from the Social tab." | 🐞 expected: retry available as the message says; actual: nothing calls `retryPendingPost` and the pending post is lost on relaunch `SocialViewModel.swift:651-660` | [ ] | — |
| PST-72 | System: the user is signed out or has no uid → App skips posting without a message | 🟡 `SocialViewModel.swift:633` | [ ] | — |

### PST edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PST-E01 | Offline when tapping POST | Summary closes; post may fail and is kept only in memory | no durable outbox | 🐞 see PST-69 | [ ] | — |
| PST-E02 | Caption longer than 500 chars | Silently cut when saved | | 🟡 | [ ] | — |
| PST-E03 | Caption only whitespace | Trimmed to empty; no caption stored | | ✅ | [ ] | — |
| PST-E04 | Tagged friend later unfriends or blocks | Tag stays in the document | not re-checked | 🧭 | [ ] | — |
| PST-E05 | Friend list fails to load | Sheet shows "No friends to tag yet" | error not distinguished | 🟡 | [ ] | — |
| PST-E06 | Tag sheet opened with spinner and user cancels | Sheet dismisses; selection unchanged | | ✅ | [ ] | — |
| PST-E07 | Photo library permission denied | Picker returns nothing; no message | | 🟡 | [ ] | — |
| PST-E08 | Very large photo | Loaded fully into memory, not downscaled | | 🧭 | [ ] | — |
| PST-E09 | Profile photo fails to download | Initial letter avatar | | ✅ | [ ] | — |
| PST-E10 | Free vs Pulse+ | Posting is not gated | | ✅ | [ ] | — |
| PST-E11 | User changes privacy while on the summary | Post uses the value read at tap time | | ✅ | [ ] | — |
| PST-E12 | Two devices | Post id is the workout id, so it cannot duplicate | | ✅ | [ ] | — |
| PST-E13 | Tapping POST twice quickly | Second tap ignored by `hasPosted` | | ✅ | [ ] | — |

## SHR  Share card

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SHR-03 | User looks at the share card → App shows a card with the ticker strip, date, big workout name, duration, stats row, body map hero, the exercise table and the footer "PULSE/PUMP" | ✅ `WorkoutCompletionView.swift:230-284` | [ ] | — |
| SHR-06 | User swipes between the photo and the card (when a photo is attached) → App pages between them and resizes the area to the active slide | ✅ `WorkoutCompletionView.swift:55-119` | [ ] | — |
| SHR-09 | User wants to share the card as an image or to other apps → App has no Share, Save or Copy action; the card is a preview of the feed post | ❌ spec lists shareable cards; `renderShareCard` and `ShareCardView` exist but nothing calls them | [ ] | — |
| SHR-12 | System: `ShareCardView` (Workout Complete, Weekly Recap, Monthly Recap, Milestone cards) → App never presents them | 🟡 dead code `ShareCardView.swift:10-156` | [ ] | — |
| SHR-15 | System: the card reflects the post → App shows the same numbers as the post, except the exercise table and body map, which respect "Post without body map" only when posting | 🟡 | [ ] | — |

### SHR edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SHR-E01 | Zero PRs | PR block hidden; ticker omits the PR item | | ✅ | [ ] | — |
| SHR-E02 | Name very long | Single line, scaled down to 50% | | ✅ | [ ] | — |
| SHR-E03 | Dark mode | Card uses theme tokens | | ✅ | [ ] | — |
| SHR-E04 | Watermark text | "PULSE/PUMP" while `ShareCardView` says "Pump by Pulse" | inconsistent branding | 🧭 | [ ] | — |

## Open decisions for the owner (03c)

- FIN-E01 (🧭): block finishing with zero ticked sets. Proposed: disable the button with "Log at least one set".
- FIN-E03 (🧭): the only chance to post is the composer; proposed: add "Share to feed" in workout detail.
- FIN-E04 (🧭): which date a session after midnight gets (start time today).
- KCL-15 (🐞): free users with a stored MET choice. Proposed: fall back to basic when not entitled.
- KCL-18: calories only appear in the ticker; decide if they belong in the stats row.
- KCL-21 / WK-54: live calories during the session.
- KCL-E03 (🧭): idle time inflates MET calories; proposed: leave.
- FSM-15: best set picked by volume, not weight. Proposed: heaviest weight, then reps.
- PST-12 (🐞): photo is accepted and dropped. Decide: upload with the post, or hide the camera.
- PST-57: silent no-post when "Workout posts" is "Only me". Proposed: show "Saved. Not posted (privacy is Only me)".
- PST-63: caption 500 limit with no counter. Proposed: counter and hard stop at 500.
- PST-69 (🐞), PST-E01: failed posts have no retry and are not persisted. Proposed: persist a pending post and retry on foreground.
- PST-E04, PST-E08 (🧭): tag validity after unfriend; photo downscale.
- SHR-09: external sharing (save image, share sheet) is promised by the spec but not built; decide to build or drop. SHR-12: remove or wire `ShareCardView` recap cards.
- SHR-E04 (🧭): choose one watermark ("PULSE/PUMP" or "Pump by Pulse").
