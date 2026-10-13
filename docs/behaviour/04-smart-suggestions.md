# 04 Smart weight suggestions (progression)

Scope: the agreed design for Smart Weight Suggestions, which is being built, plus the current baseline it replaces. Baseline rows describe what the code does today. Feature rows describe the agreed design and carry `🚧 IN PROGRESS`.
Baseline sources: `Features/Workout/WorkoutViewModel.swift` (`ghostText`, `applyGhostValues`, `smartWeightSuggestion`), `Features/Workout/Views/Logger/SetRowViews.swift`, `Features/Settings/SettingsView.swift`, `Features/PulsePlus/PulsePlusService.swift`, `PumpShared/WeightUnit.swift`, `firebase/firestore.rules`, `docs/sync-architecture.md`.
Logging itself is in `03a`, `03b`, `03c`; sync in `12`; gating in `13`.

Status legend (six tags in this file only): ✅ implemented and verified in code | 🟡 partial | ❌ not built | 🐞 known bug | 🧭 PROPOSED (not decided; default proposed in text) | 🚧 IN PROGRESS (agreed design, being built).

## The agreed design in one paragraph

For each exercise the user has a rep threshold R. During a session the app finds the highest weight W among that exercise's completed working sets. When a completed working set at W reaches R reps, the next set shows a ghost weight of W plus the user's increment, and the user only types reps. The increment is set in Settings, stored in kg, default 2.5 kg or 5 lb. Warm-ups are ignored. The feature is Pulse+ only, has a toggle in Settings, and the thresholds sync to the cloud. Everything else below is edge-case detail; items that the design does not settle are marked 🧭.

## SGB  Baseline today (what the app does now)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SGB-03 | User opens a set row for an exercise done before → App shows the previous finished session's weight and reps at the same row position as faint ghost text (see SET-18 in `03b`) | ✅ `WorkoutViewModel.swift:218-227` | [ ] | — |
| SGB-06 | User ticks a set whose fields are empty but show ghosts → App saves the ghost values as the logged set (see SET-33) | ✅ `WorkoutViewModel.swift:179-190` | [ ] | — |
| SGB-09 | System: ghost value → App never raises weight; it only repeats last session's number at that row position (warm-ups included in the position count) | ✅ `WorkoutViewModel.swift:218-227` | [ ] | — |
| SGB-12 | System: `smartWeightSuggestion(for:setIndex:)` → App has this function (last 3 sessions, needs at least 2; if last weight beat the one before it suggests last plus the same gap, else the same weight; returns a kg string; ignores set type) but nothing calls it | ❌ dead code `WorkoutViewModel.swift:428-453`; to be removed or replaced when the feature ships | [ ] | — |
| SGB-15 | System: legacy `SetRowView` has a `smartSuggestion` parameter → App never passes it and never reads it | ❌ dead `SetRowViews.swift:236-259` | [ ] | — |
| SGB-18 | User opens Settings › Workout → App shows "Smart Weight Suggestions" with the value "COMING SOON" and no switch (honest placeholder instead of a dead toggle) | ✅ `SettingsView.swift:140` | [ ] | — |
| SGB-21 | System: Pulse+ feature list → App has the case `smartWeightSuggestions` ("Smart Weight Suggestions", brain icon). `hasAccess(to:)` ignores which feature is asked and returns true for subscribers and for the 14-day trial counted from install date | ✅ `PulsePlusService.swift:12,145-147,129-143` | [ ] | — |
| SGB-24 | System: Pulse+ paywall list → App lists "Smart Predictions / AI-powered workout suggestions" (workout prediction), with no weight-suggestion line | 🟡 marketing does not name this feature `PulsePlusView.swift:22` | [ ] | — |
| SGB-27 | System: increment constant → App has `UnitPreference.stepperIncrement` (2.5 kg, 5 lb) used only by the warm-up generator, which is unreachable. No stored user increment exists | 🟡 `WeightUnit.swift:65` | [ ] | — |
| SGB-30 | System: settings storage → App keeps rest timer mode, alert, calorie formula, auto-share and per-exercise rest overrides in this device's UserDefaults. None of them sync | ✅ `SettingsView.swift:43-47`, `SyncMapper.swift:148-160` | [ ] | — |
| SGB-33 | System: cloud contract → The `users/{uid}` rules accept an optional `settings` map (document capped at 40 keys) but the client writes none; no per-exercise settings collection exists in rules, mapper or applier | ✅ `firestore.rules:63-76` | [ ] | — |
| SGB-36 | System: other consumers of ghost → App feeds the same ghost weight to the inline plate strip and to the Live Activity "next weight", so any new ghost source flows into both | ✅ `ExerciseCardView.swift:55-57`, `WorkoutViewModel.swift:535-549` | [ ] | — |
| SGB-39 | System: session sets → App holds the live session in memory (`exerciseEntries`) and persists only ticked sets, so "highest weight so far this session" must be computed from the in-memory entries | ✅ `WorkoutViewModel+Draft.swift:35-93` | [ ] | — |
| SGB-42 | System: rep goal → App has no concept of a per-exercise rep goal in the logger; template `targetReps` is carried but only used for the Live Activity | 🟡 `WorkoutViewModel.swift:547` | [ ] | — |

### SGB edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SGB-E01 | Free user taps the placeholder row | Nothing happens | row has no action | ✅ | [ ] | — |
| SGB-E02 | Pulse+ user | Same placeholder; no difference | feature not wired | ✅ | [ ] | — |
| SGB-E03 | Warm-up in last session | Ghost for later rows is shifted by one position | positional ghost (SET-21) | 🟡 | [ ] | — |

## SUG  Suggestion behaviour in the logger (agreed design)

Terms. W = highest weight among this exercise's ticked, non-warm-up sets in the current session, in kg. R = the exercise's rep threshold. inc = user increment in kg. A "qualifying set" is a ticked working set with weight W and reps at least R.

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SUG-03 | User ticks a working set at W with reps >= R → App shows a ghost weight of W + inc in the weight field of the next not-done set, in the display unit | 🚧 IN PROGRESS | [ ] | — |
| SUG-06 | User types only reps in that row and ticks → App logs the suggested weight with the typed reps (the existing "ghost is saved when the field is empty" rule in SGB-06 does the saving) | 🚧 IN PROGRESS | [ ] | — |
| SUG-09 | User types a different weight in that row → App uses the typed weight; the suggestion disappears for that row | 🚧 IN PROGRESS | [ ] | — |
| SUG-12 | User ticks a set at W with reps below R → App shows no suggestion; the next row keeps the baseline ghost (last session's value, SGB-03) | 🚧 IN PROGRESS | [ ] | — |
| SUG-15 | System: warm-up sets → App ignores them completely: they never set W, never qualify, and a warm-up row never receives a suggestion | 🚧 IN PROGRESS | [ ] | — |
| SUG-18 | System: W is session-only → App computes W from sets ticked in this session; history from earlier sessions does not set W | 🚧 IN PROGRESS | [ ] | — |
| SUG-21 | System: the suggested row shows reps → App leaves the reps field empty with no ghost, so the user must enter reps ("only types reps"). Baseline reps ghost is suppressed on a suggested row | 🧭 proposed: suppress the reps ghost so the previous session's reps are not saved by accident | [ ] | — |
| SUG-24 | User ticks the set that was suggested and reaches R again at the new weight → App suggests W' + inc for the next set (chain continues, no cap) | 🧭 proposed: no cap on the chain within a session | [ ] | — |
| SUG-27 | User un-ticks the qualifying set, deletes it, or changes its weight or reps so it no longer qualifies → App removes the suggestion at once (recomputed from current entries) | 🚧 IN PROGRESS | [ ] | — |
| SUG-30 | System: which row gets the suggestion → App puts it only on the next not-done set (the active row); later rows keep baseline ghosts until their turn | 🧭 proposed: active row only | [ ] | — |
| SUG-33 | System: which set triggers → App evaluates the most recently ticked working set: it must be at W and reach R. A later lighter set (back-off) cancels the suggestion | 🧭 proposed: latest ticked working set decides | [ ] | — |
| SUG-36 | System: look of the suggestion → App shows it as ghost text like SGB-03, visually distinguishable from last-session ghosts (for example accent colour and a small "+inc" tag) | 🧭 proposed: accent-tinted ghost plus a "▲ +2.5" micro-tag | [ ] | — |
| SUG-39 | System: inline plate strip → App shows plates for the suggested weight on the active row (follows SGB-36) | 🚧 IN PROGRESS | [ ] | — |
| SUG-42 | System: Live Activity next weight and LOG SET → App uses the suggested weight as "next weight"; LOG SET logs it only if reps were typed in the app | 🧭 proposed: show the suggestion on the Live Activity; LOG SET logs weight plus planned reps | [ ] | — |
| SUG-45 | System: nothing about the suggestion is stored → App saves only what is logged; no "suggested" flag on `SetLog` | 🚧 IN PROGRESS | [ ] | — |
| SUG-48 | System: PRs → App shows no PR marker mid-session even when the suggested weight beats the old max (PRs stay a surprise, SET-51) | 🚧 IN PROGRESS | [ ] | — |
| SUG-51 | System: exercise types → App suggests only for weighted exercises and for bodyweight exercises with added weight above 0. Time-based and distance-based exercises never get suggestions | 🧭 proposed as written | [ ] | — |
| SUG-54 | User resumes a draft → App recomputes W and the suggestion from the restored ticked sets | 🚧 IN PROGRESS | [ ] | — |

### SUG edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SUG-E01 | No history for the exercise | Works: W comes from this session; first set has no suggestion | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E02 | First set of the session | No W yet, so baseline ghost only | session-only W (SUG-18) | 🚧 IN PROGRESS | [ ] | — |
| SUG-E03 | First set may use last session's top set (a cross-session start) | Not part of the agreed design | would change SUG-18 | 🧭 proposed: no | [ ] | — |
| SUG-E04 | Equal weights: three sets at W, only the second reached R | Suggestion shows only if the latest ticked set is at W and reached R, so the third set at W with fewer reps cancels it | follows SUG-33 | 🧭 | [ ] | — |
| SUG-E05 | Equal weights: all sets at W reach R | Suggestion after each ticked set | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E06 | Drop set | A set typed DROP counts for W only if it is the heaviest, never triggers a suggestion, and the set after a drop set gets none | drop weights are lighter by intent | 🧭 proposed as written | [ ] | — |
| SUG-E07 | To-failure or AMRAP set with reps >= R | Qualifies like a standard set | | 🧭 proposed: yes | [ ] | — |
| SUG-E08 | Rest-pause or superset-typed set | Treated as a standard working set | no distinct behaviour exists (03b STY, SUP) | 🧭 | [ ] | — |
| SUG-E09 | Failure set with reps < R | No suggestion; baseline ghost | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E10 | Bodyweight exercise with weight 0 | No W, so no suggestion | | 🧭 proposed: off at 0 | [ ] | — |
| SUG-E11 | Bodyweight with added weight | Works like weighted: W + inc | | 🧭 | [ ] | — |
| SUG-E12 | Unilateral exercise (L/R chip) | Side logging is not built (STY-30), so each ticked row is treated as one set | | 🧭 revisit when sides exist: evaluate per side | [ ] | — |
| SUG-E13 | W + inc is not loadable with the user's plates (e.g. no 1.25 kg plate) | App still shows W + inc rounded to the display unit; no plate snapping | user picks the increment to suit their plates | 🧭 proposed: no snapping; the plate strip shows "+x OFF" | [ ] | — |
| SUG-E14 | Rounding of the displayed value | kg shows two decimals trimmed, lb rounds to the nearest 0.5 (existing `roundedDisplay`) | 5 lb from kg storage is 2.26796 kg | 🧭 proposed: reuse `roundedDisplay`; the stored weight is the unrounded kg of what the user logs | [ ] | — |
| SUG-E15 | Unit switch between sessions | W and inc are kg; suggestion shows in the new unit (a 2.5 kg increment shows as 5.5 lb) | no data mutates | 🚧 IN PROGRESS | [ ] | — |
| SUG-E16 | Weight typed in lbs mid-session | W is the stored kg of what was typed (4-decimal kg string), so lb math stays exact | `kgString(displayText:)` | 🚧 IN PROGRESS | [ ] | — |
| SUG-E17 | Decimal comma | Reps and weights parse with `parseDecimal` | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E18 | Replace exercise on a card with ticked sets | Threshold switches to the new exercise; W recomputed from the card's ticked sets | sets stay on the card (EXA-33) | 🧭 proposed: recompute, do not clear | [ ] | — |
| SUG-E19 | Two exercises with the same weight progress | Each exercise has its own R and W | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E20 | Reps typed 0 or empty on the trigger set | Does not qualify | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E21 | Weight above a sane limit after many chain steps | Shown as computed | no cap | 🧭 propose cap 1000 kg (same as SET-E03) | [ ] | — |
| SUG-E22 | Double-tap the check on the trigger | Toggles tick (SET-E09); suggestion appears and disappears with it | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E23 | Free user | No suggestions (see SGS) | | 🚧 IN PROGRESS | [ ] | — |
| SUG-E24 | Toggle off | No suggestions; baseline ghost only | | 🚧 IN PROGRESS | [ ] | — |

## SGS  Settings, increment and gating (agreed design)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SGS-03 | User opens Settings › Workout as a Pulse+ or trial user → App replaces the "COMING SOON" row with a "Smart Weight Suggestions" on/off switch | 🚧 IN PROGRESS | [ ] | — |
| SGS-06 | User looks at the switch for the first time → App shows its default state | 🧭 proposed: ON for entitled users, so the feature is discoverable | [ ] | — |
| SGS-09 | User sees "Weight Increment" under the switch → App shows the current value as "2.5 KG" or "5 LB" and opens a picker or stepper on tap | 🚧 IN PROGRESS | [ ] | — |
| SGS-12 | User never changes the increment → App uses 2.5 kg for kg users and 5 lb for lb users | 🚧 IN PROGRESS | [ ] | — |
| SGS-15 | User picks an increment → App converts from the display unit to kg and stores kg (a 5 lb pick is stored as 2.26796 kg) | 🚧 IN PROGRESS | [ ] | — |
| SGS-18 | User picks a value out of range or 0 or negative → App rejects it and keeps the previous value | 🧭 proposed range: 0.25 kg to 25 kg (0.5 lb to 55 lb) | [ ] | — |
| SGS-21 | User switches the weight unit with the default untouched → App follows the new unit's default (5 lb) | 🧭 proposed: store nothing until the user picks, so the default tracks the unit | [ ] | — |
| SGS-24 | User switches the weight unit after explicitly picking 2.5 kg → App keeps 2.5 kg and shows about 5.5 lb | 🧭 proposed: explicit value is a kg quantity | [ ] | — |
| SGS-27 | User turns the switch off → App stops suggestions at once, even in a live session; thresholds and increment are kept and still sync | 🚧 IN PROGRESS | [ ] | — |
| SGS-30 | Free user opens Settings › Workout → App shows the row locked with "PULSE+" and tapping opens the paywall | 🧭 proposed: locked row plus paywall, not hidden | [ ] | — |
| SGS-33 | System: entitlement check → App allows the feature when the user is subscribed or inside the 14-day trial (existing `hasAccess(to: .smartWeightSuggestions)`) | 🚧 IN PROGRESS | [ ] | — |
| SGS-36 | System: the trial ends or the subscription lapses mid-session → App stops suggesting on the next render; logged data is untouched | 🧭 proposed as written | [ ] | — |
| SGS-39 | System: where the toggle and increment live → App stores them with the user's synced settings, not only in this device's UserDefaults | 🧭 proposed: `users/{uid}.settings` map (rules already allow it): `smartWeightSuggestions` (bool) and `weightIncrementKg` (number) | [ ] | — |
| SGS-42 | System: the paywall feature list → App names the feature on the Pulse+ screen | 🧭 proposed: add "Smart Weight Suggestions" with the one-line explanation | [ ] | — |

### SGS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SGS-E01 | Offline | Suggestions are computed locally from in-memory sets, local threshold and local settings; entitlement uses the cached StoreKit state and local install date | no network needed | 🚧 IN PROGRESS | [ ] | — |
| SGS-E02 | Offline entitlement unknown at cold start | Feature stays off until entitlement resolves | `isSubscribed` starts false | 🧭 proposed: wait for the first check, do not flicker | [ ] | — |
| SGS-E03 | Two devices change the increment | Last write wins by `updatedAt` for the settings document; the other device picks it up on its next pull | sync contract | 🧭 | [ ] | — |
| SGS-E04 | Settings changed on device B during a live session on A | A keeps using the old value until the session ends or the app is next foregrounded after a pull | avoids numbers jumping under the user | 🧭 proposed | [ ] | — |
| SGS-E05 | New device or reinstall | Increment, toggle and thresholds are restored from the cloud before the main UI (sync step 5) | | 🧭 depends on SGT sync | [ ] | — |
| SGS-E06 | Account switch | Local settings and thresholds are wiped with the other user data | `SyncAccount.wipe` must include them | 🧭 to add | [ ] | — |
| SGS-E07 | Locale decimal comma in the increment field | Accepted via `parseDecimal` | | 🚧 IN PROGRESS | [ ] | — |
| SGS-E08 | Downgrade after setting a custom increment | Values are kept; feature inactive | | 🚧 IN PROGRESS | [ ] | — |

## SGT  Rep thresholds (storage, defaults, sync)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SGT-03 | System: threshold meaning → App stores one whole number of reps per exercise (R); there is no per-weight or per-set threshold | 🚧 IN PROGRESS | [ ] | — |
| SGT-06 | User wants to set R for an exercise → App offers a way to edit it | 🧭 proposed: a "Rep Goal" row in the exercise card "···" menu during a session, and the same field in the exercise detail screen | [ ] | — |
| SGT-09 | User edits R → App accepts a whole number and rejects the rest | 🧭 proposed range 1 to 50 | [ ] | — |
| SGT-12 | System: R is missing for an exercise → App has to choose between no suggestion and a default | 🧭 proposed: use the template exercise's `targetReps` when the session came from a template, otherwise no suggestion and a one-time hint "Set a rep goal to get suggestions" | [ ] | — |
| SGT-15 | System: where R lives locally → App stores it as a synced record keyed by exercise id with `updatedAt`, `deletedAt`, `syncedAt`, `schemaVersion` like other records | 🚧 IN PROGRESS | [ ] | — |
| SGT-18 | System: where R lives in the cloud → App writes it to the user's private data | 🧭 proposed: `users/{uid}/progression/{exerciseId}` with `repThreshold`, `schemaVersion`, `updatedAt`, `deletedAt`; needs a rules entry (owner only, `repThreshold` int 1..50), a mapper and an applier | [ ] | — |
| SGT-21 | System: conflict between devices → App keeps the record with the newer `updatedAt` per exercise (last write wins) | 🚧 IN PROGRESS | [ ] | — |
| SGT-24 | System: edits while offline → App marks the record dirty and pushes it on the next sync trigger, like workouts | 🚧 IN PROGRESS | [ ] | — |
| SGT-27 | System: exercise is deleted → App soft-deletes its threshold with the exercise | 🧭 proposed | [ ] | — |
| SGT-30 | System: template target reps change → App leaves R unchanged | 🧭 proposed: independent, R is not copied from a template once set | [ ] | — |
| SGT-33 | System: account deletion → App's `deleteAccount` function removes the new sub-collection with the rest of `users/{uid}` | 🧭 verify the function deletes unknown sub-collections | [ ] | — |
| SGT-36 | System: import (Strong or Hevy) → App creates no thresholds | 🧭 proposed | [ ] | — |

### SGT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SGT-E01 | Threshold missing and no template | No suggestion; one-time hint | SGT-12 | 🧭 | [ ] | — |
| SGT-E02 | Threshold present for a deleted exercise | Ignored | | 🧭 | [ ] | — |
| SGT-E03 | R edited on two devices at once | Newer `updatedAt` wins; the older value is lost | accepted by the sync design | 🚧 IN PROGRESS | [ ] | — |
| SGT-E04 | Cloud has a newer R than the live session | Live session keeps the value it started with | same rule as SGS-E04 | 🧭 | [ ] | — |
| SGT-E05 | Sync fails | Local R keeps working; push retried with backoff | sync design | 🚧 IN PROGRESS | [ ] | — |
| SGT-E06 | Huge number of exercises with thresholds | One small document each, within the 255 per publish / 400 per batch sync limits | | 🚧 IN PROGRESS | [ ] | — |
| SGT-E07 | Free user edits R | Not possible if the row is gated; if reached, stored but inactive | | 🧭 proposed: row hidden for free users | [ ] | — |

## Open decisions for the owner (04)

- SUG-21 (🧭): suppress the reps ghost on a suggested row. Proposed: suppress.
- SUG-24 (🧭): chain of suggestions has no cap within a session.
- SUG-30 (🧭): suggestion on the active row only.
- SUG-33 (🧭): the latest ticked working set decides; a lighter later set cancels.
- SUG-36 (🧭): distinguishing look for suggestions (accent-tinted ghost plus a "+inc" tag).
- SUG-42 (🧭): show the suggestion in the Live Activity; LOG SET behaviour.
- SUG-51, SUG-E10, SUG-E11 (🧭): exercise types and bodyweight with weight 0 (off) or added weight (on).
- SUG-E03 (🧭): first set may not use last session's top set (design says session-only).
- SUG-E04 (🧭): equal weights: latest set decides.
- SUG-E06, SUG-E07, SUG-E08 (🧭): how drop, failure, AMRAP, rest-pause and superset sets count.
- SUG-E12 (🧭): unilateral sets until side logging exists (STY-30); per-side evaluation later.
- SUG-E13, SUG-E14 (🧭): no snapping to plate increments; rounding via `roundedDisplay`.
- SUG-E18 (🧭): replacing an exercise recomputes from the card's ticked sets.
- SUG-E21 (🧭): cap suggested weight at 1000 kg.
- SGS-06 (🧭): default state of the switch (proposed ON for entitled users).
- SGS-18 (🧭): increment range 0.25 to 25 kg.
- SGS-21, SGS-24 (🧭): default increment tracks the unit until the user picks one; explicit value is stored in kg.
- SGS-30 (🧭): free users see a locked row that opens the paywall.
- SGS-36 (🧭): behaviour when entitlement lapses mid-session.
- SGS-39 (🧭): store toggle and increment in the synced `users/{uid}.settings` map (rules already allow it).
- SGS-42 (🧭): add the feature to the Pulse+ paywall copy.
- SGS-E02, SGS-E03, SGS-E04, SGS-E05, SGS-E06 (🧭): offline cold start, two-device settings, mid-session settings changes, new-device restore, wipe on account switch.
- SGT-06 (🧭): where the user edits R (card menu and exercise detail).
- SGT-09 (🧭): range 1 to 50 reps.
- SGT-12, SGT-E01 (🧭): default when R is missing (template target reps, else none with a hint).
- SGT-18 (🧭): cloud path `users/{uid}/progression/{exerciseId}`; rules, mapper and applier needed.
- SGT-27, SGT-30, SGT-33, SGT-36, SGT-E02, SGT-E04, SGT-E07 (🧭): lifecycle details (deleted exercise, template independence, account deletion coverage, import, hidden row for free users).
- Housekeeping: delete the dead `smartWeightSuggestion` function (SGB-12) and the unused `smartSuggestion` parameter (SGB-15) when the feature lands.
