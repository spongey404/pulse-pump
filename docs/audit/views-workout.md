# Audit: views-workout (PulsePump/Views/Workout/** + Views/Utilities/**)

Paths are relative to PulsePump/. WVM = ViewModels/WorkoutViewModel.swift (read in full because every number on these screens originates there). AWV = Views/Workout/ActiveWorkoutView.swift. Scratch scripts: scratchpad/views-workout/t.swift.

## Summary
- Counts: 2 CRITICAL, 10 HIGH, 9 MEDIUM, 8 LOW.
- Two CRITICAL data problems come from the workout view model, not the views. `startWorkout` always calls `injectTestData`, which replaces the real workout with 10 fake exercises and writes fake history into SwiftData. In-progress workout data is also never persisted, so "drafts survive crashes" is false.
- The numbers on the completion screen are only partly trustworthy. Warm-up sets count towards volume, sets, best set, PRs, body heat and calories, although the UI says warm-ups are "Excluded from volume".
- Ghost values shown in grey are not saved when the user taps the check. The set is stored as 0 x 0.
- The "Don't post" and "Never post" options are wrong. `completeWorkout` has already auto-posted a caption-less duplicate before the composer appears. The attached photo is never uploaded.
- The unit setting (lbs) is ignored everywhere in the workout flow, which is hard-coded KG.
- `PlateCalculatorView` and `WarmupGeneratorView` are unreachable. `EquipmentProfilesView` is display-only: no data flows from profiles into the plate calculator, exercise picker or workout, and two of its buttons are no-ops.
- The inline plate math (greedy per side, 25/20/15/10/5/2.5/1.25) is correct for every reachable kg weight I tried. The warm-up math (linear, 2.5 rounding) is arithmetically consistent but not plate-aware or lb-aware, and it produces duplicate sets near the bar weight.
- No unit tests cover any of this. Only `RestTimerServiceTests` touches the workout flow.

## Findings

[CRITICAL] ViewModels/WorkoutViewModel.swift:81 (body 85-145) — `injectTestData` runs on every real workout start
- Wrong: `startWorkout` ends with `injectTestData(modelContext:)`, which sets `exerciseEntries = []`. It then fills 10 hard-coded pre-completed exercises (Bench 107.5x5 etc.) and backdates `startTime` by 4680s (78 min).
- Side effects: for each exercise it inserts a fake non-draft `Workout` dated 7 days ago, owned by the user, with an `ExerciseLog` and `SetLog`. These are persisted. They feed history, streak, PR comparison, ghost text, body map, widgets and export.
- Scenario: start "Leg Day" from a template. Expected: the template's exercises with empty sets. Actual: Bench/OHP/etc., all sets already completed, and the timer reads about 1:18:00. Each start adds roughly 10 more fake workouts.
- Evidence: `startWorkout`: `...startDurationTimer(); liveActivity.startLiveActivity(...); injectTestData(modelContext: modelContext)`. The same call is in HEAD (`git grep injectTestData HEAD`), so it is committed, not just a working-tree edit.
- Fix: delete the call (or wrap it in `#if DEBUG` with an explicit launch flag). Add a one-off cleanup of the fake workouts already inserted.

[CRITICAL] ViewModels/WorkoutViewModel.swift:508-513, 147-179, 284-344 — In-progress sets are never persisted, so drafts do not survive a crash or relaunch
- Wrong: `ExerciseLog`/`SetLog` rows are created only inside `completeWorkout`. `saveDraft()` only writes `duration`, `notes` and `updatedAt`. `resumeDraft` rebuilds entries from `workout.exerciseLogs`, which are always empty for a draft.
- Scenarios:
  - Kill the app mid-workout and tap CONTINUE. You get an empty workout.
  - The "SAVE AS DRAFT" option (AWV:246-247) keeps the sets only in the in-memory view model. They are lost on any relaunch.
  - The dock's "N SETS DONE" and progress bar (ContentView:921-933) read `draft.exerciseLogs.sets.count`, which is always 0.
- Contradicts: the CLAUDE.md claim "A Workout with isDraft = true persists through crashes", and the AWV:242 message "Drafts auto-save for 7 days". I found no 7-day purge or auto-save code (grep).
- Fix: create or update ExerciseLog/SetLog on each `logSet` (or in `saveDraft`) and restore `isCompleted = true` in `resumeDraft` (the restored `SetEntry` never sets it).

[HIGH] AWV:993-995, 715, 1765, 1795; Views/Utilities/* — Unit preference (lbs) is ignored in all workout screens
- `User.unitPreference` can be set to lbs (Settings, onboarding), but the grid headers ("KG"), the plate panel ("PLATES · 100KG", "KG · BAR 20"), the PR strings ("KG") and the completion stats are fixed to kg. No conversion happens anywhere.
- Scenario: an lbs user types 225, and it is saved and displayed as 225 kg. Plates are computed with 20 kg bar and kg plates (script: 225 -> [25,25,25,25,2.5] per side).
- `PlateCalculatorView` and `WarmupGeneratorView` have `@State unit = .kg` with no toggle and no read of the user preference.
- Fix: read `user.unitPreference`, store kg canonically and convert at the edges, or at minimum label correctly.

[HIGH] Views/Workout/WorkoutCompletionView.swift:282-285, 289, 369-374, 421-424; WVM:324-344, 353, 399, 404, 430, 456; Views/Shared/BodyHeat+Exercises.swift:15 — Warm-up sets count everywhere, despite "Excluded from volume"
- The set-type sheet says Warmup is "Excluded from volume" (AWV:1253). Nothing filters `setType == .warmup`, and warm-up sets are included in all of the following:
  - volume (`volString`: sum weight x reps over `data.exercises.flatMap(\.sets)`)
  - SETS KPI (`totalSets`)
  - the per-exercise set count
  - `bestWeight` and previous-best for PR detection
  - the live PR check
  - calories (`totalSets`)
  - `muscleSetCounts` (`exercise.sets.count`)
  - the AWV header PR/1RM (`loadAnalytics`)
  - the feed post
- Scenario: warm-up 40x20 plus working 100x5 gives "BEST SET 40x20", because `bestSetText` maximises weight x reps (800 > 500).
- Scenario: a warm-up heavier than any previous set counts as a weight PR.
- Fix: filter `setType != .warmup` in these aggregates, or drop the "Excluded from volume" claim.

[HIGH] AWV:960-978 (onLog), 689-691, 1182-1195; WVM:218-231, 325 — Ghost (previous-session) values are displayed but not saved when the user taps the check
- The row shows last session's values in grey via `ghostText`, and the plate panel uses them (`weightStr = set.weight.isEmpty ? ghost.weight : set.weight`). `onLog` calls `checkPR` then `logSet`, and neither copies the ghost into `SetEntry.weight/reps`. `completeWorkout` parses `setEntry.weight`/`reps`.
- Scenario: ghost shows "100 / 5". Tap the check without typing. Expected: logged 100x5 (as the Live Activity LOG SET path does in `logNextSetFromLiveActivity`, WVM:805-811). Actual: saved as weight 0, reps 0 and counted as a completed set (SETS +1, volume +0).
- Intent is unverified (ghost may be meant to be typed over), but the UI treats the ghost as the value and the two logging paths disagree.
- Fix: in `onLog`, fill empty weight/reps from the ghost (as `plannedValues` does), or block completion when empty.

[HIGH] WVM:469-488 vs Views/Workout/WorkoutCompletionView.swift:561-583 — Every workout is posted twice, and "Don't post" does not prevent posting
- `completeWorkout` auto-posts to the feed if `autoShareToFeed` (default true when the key is absent), with no caption, tags or photo, and `Task { try? await FirestoreService().shareWorkoutToFeed }`.
- The completion screen then offers POST, which creates a second `WorkoutFeedItem` with a fresh UUID id (so a second doc), a different `date` (`Date()` vs `workout.date`) and a different `username` (`displayName ?? "User"` vs `user.name`).
- "Don't post — nobody sees it" (:515) and "Never post automatically" (:521) only call `onDismiss()` and set the pref. The post already went out.
- Privacy impact: the user is told nobody will see the session while a post is already live. Posts are also written with `userId ""` when signed out (errors swallowed by `try?`).
- Fix: do not post in `completeWorkout`. Post only from the composer, or auto-post there and make the composer an edit of that doc id.

[HIGH] Views/Workout/WorkoutCompletionView.swift:12-14, 51-65, 561-583 — The attached photo is never uploaded
- `thumbnailUIImage` is used only for local display. `WorkoutFeedItem.photoURL` is never set anywhere on this path, so there is no storage upload.
- The composer's camera button and the photo slide imply the photo is shared. It is dropped.
- Failures of the post are also swallowed (`try?`) after `onDismiss()` runs immediately, so the user is never told.

[HIGH] Views/Utilities/EquipmentProfilesView.swift (whole file); Models/EquipmentProfile.swift — Equipment profiles are display-only
- `grep` shows `EquipmentProfile`, `availablePlates`, `barTypes` and `BarConfig` are read only by this view. The exercise picker, plate calculator (inline and standalone), warm-up generator and active workout never use them.
- Specific problems:
  - `ACTIVE PROFILE` (:103) is shown for whichever tab is selected. No "active" state is stored or consumed.
  - Pencil icon (:146) is decorative.
  - `DashedAdd("Add Equipment") { }` (:269) is a no-op.
  - Plates and bar types cannot be edited, and a profile cannot be deleted or renamed.
  - Plate chips hard-code "KG" (:215).
  - `profile.user` is never set on create (:376-380), so profiles are orphaned from `User.equipmentProfiles` (cascade).
  - `.unlimitedEquipmentProfiles` (PulsePlusService) is never checked, so there is no free-tier limit.
- Fix: wire the active profile's plates and bar into `InlinePlateCalculatorView`, filter the picker by `availableEquipment`, and implement the editors.

[HIGH] Views/Utilities/PlateCalculatorView.swift, WarmupGeneratorView.swift — Both screens are unreachable
- `grep -rn "PlateCalculatorView\|WarmupGeneratorView"` finds no references outside their own files (Settings and More route only to `EquipmentProfilesView`).
- They duplicate logic that has diverged from the live code:
  - Standalone bar options are 20/10/25/15 kg. The inline calculator uses 20/15/7.5/25/32.
  - Standalone plate set comes from the `customPlates` UserDefaults key, which nothing else writes except this dead view. The inline calculator hard-codes the plates.
- Fix: either mount them (and share one plate engine) or delete them.

[HIGH] AWV:975; Services/RestTimerService.swift:72-82; WVM:228 — Rest is always "compound"; the isolation rest setting, template `restSeconds` and superset "no rest" are dead
- `onLog` passes `isCompound: true` unconditionally. `restDuration` therefore returns `compoundRestSeconds` (default 180) or the per-exercise override. `isolationRestSeconds` is never reached.
- There is no Settings UI for `compoundRestSeconds`/`isolationRestSeconds` (only the `restTimerMode` row exists). `TemplateExercise.restSeconds` is stored by Programs views and never read when a workout starts.
- The Superset set type claims "Paired with next exercise, no rest" (AWV:1254), but `logSet` always starts the rest timer. No set type has any behaviour beyond the label. `.leftRight`/`Side` is never set from the UI (`side` is always `.both`).
- The rest-override modal defaults to 90s (AWV:471) while the real default is 180s.
- Fix: derive `isCompound` from `exercise.movementPattern.isCompound`, honour template `restSeconds`, and either implement superset behaviour or remove the claim.

[HIGH] WVM:325, 327-329, 432-435 (parsing of `weight`/`reps`/`duration`/`distance`) + AWV `.decimalPad` keyboards — Comma decimals become 0
- `Double("62,5")` is `nil` (verified: `Double("62,5") -> nil`; `"6.2.5" -> nil`). In comma-decimal locales the decimalPad types ",", so `Double(setEntry.weight) ?? 0` stores weight 0 with no warning. The PR/plate paths use the same pattern (AWV:691).
- Fix: normalise "," to "." (or use a locale-aware `NumberFormatter`) before parsing, and validate on entry.

[MEDIUM] AWV:226-227 — Replace Exercise only swaps id and name
- `exerciseType`, `equipmentType` and `isUnilateral` stay from the original, and the existing set values are kept.
- Scenario: replace a barbell exercise with a timed plank. The rows still use weight/reps fields and the barbell plate panel. Replace dumbbell with barbell: no plate panel, since `isBarbellType` reads the old `equipmentType`.
- Fix: copy the type fields from the new `Exercise` (and clear the sets or ghost state).

[MEDIUM] AWV:658, 706, 1697-1704, 1765, 1795 — Inline plate calculator: bar weight is not tied to the equipment
- `plateBarWeight` defaults to 20 for every card, including EZ-bar (should be about 10; the legacy `InlinePlateView` did 10), trap bar (25) and smith machine. EZ is 7.5 kg here, 10 kg in `EquipmentProfilesView`/`BarConfig.ezCurl` and in `PlateCalculatorView`.
- The plate panel only shows when `weightVal > plateBarWeight`, so a trap-bar user at 22 kg sees nothing, and the "BAR ONLY" branch is unreachable for weights under or equal to the bar.
- The remainder text "+0.50KG OFF" is per side, but unlabeled. Total off is double. Verified: 101 kg on a 20 kg bar -> [25,15] per side, 0.5 per side left over (loaded 100, 1 kg short).
- Plates are fixed [25,20,15,10,5,2.5,1.25], so the user's plate inventory is ignored (see the profiles finding).

[MEDIUM] WVM:381-383, 360-380, 352-353; AWV (header PR strip) vs WorkoutCompletionView:373, 38, 308 — "Improved" and PR definitions are inconsistent
- `improvedCount` increments when `bestWeight >= previousBestWeight`, so ties count (same weight, even fewer reps). The table's up-arrow uses `improvementScore > 0` (1RM gain). The headline "IMPROVED 6/10" and the number of arrows can disagree.
- Rep-PR at completion compares the maximum reps of any set against previous max reps at weights <= `bestWeight` (the top weight). The live `checkPR` compares per set at that set's own weight. Example: previous 100x5. Today 100x5 plus 60x12. Completion flags a rep PR (+7), while per-set logic would not.
- Header "PR" in `ExerciseCardView` shows the best-1RM set, not the heaviest set, so it can differ from the completion PR.
- `totalExercises` includes entries with zero completed sets.

[MEDIUM] WVM:463, 833-844 — "Muscles worked" includes exercises with no completed sets
- `collectMusclesWorked` iterates all `exerciseEntries` and does not check for completed sets. A skipped exercise lights up its muscles on the share card and the feed post.

[MEDIUM] AWV:689 + WVM:265-280 — Ghost lookup is run for every set row in `body`, unbounded
- `ghostText` runs a SwiftData fetch with no `fetchLimit` inside `ForEach` in `ExerciseCardView.body`. That is one fetch per set row, each loading all historical logs and sets of that exercise.
- It re-runs on every keystroke or state change (including the 1-second `elapsedSeconds` tick, since the view reads the observable view model), which risks jank on a long history. Add `fetchLimit = 1`, or cache per exercise in `.task`.

[MEDIUM] AWV:246-247; WVM:41-52, 147-179, 508-513, 671-681 — State leaks around SAVE AS DRAFT / resume / new workout
- "SAVE AS DRAFT" sets `isActive = false` but does not stop the duration timer or Live Activity, and does not reset `exerciseEntries`. `resumeDraft` then starts a second timer (the first is overwritten and leaks, so two timers write `elapsedSeconds`).
- `startWorkout`/`discardDraftAndStart` do not clear `exerciseEntries` (and `reset()` isn't called), so a new template workout started after a saved draft appends to the old entries.
- `elapsedSeconds` is not reset on resume until the next tick.

[MEDIUM] Views/Utilities/WarmupGeneratorView.swift:9-32 — Warm-up generator: duplicate/short plans, no plate or unit awareness
- Verified with a script (bar 20, steps = Stepper value):

| Working | Steps | Plan (kg x reps) |
|---|---|---|
| 100 | 4 | 20x10, 40x8, 60x6, 80x4 |
| 100 | 6 | 20x10, 32.5x8, 47.5x6, 60x4, 72.5x3, 87.5x3 |
| 102.5 | 4 | 20x10, 40x8, 62.5x6, 82.5x4 |
| 62.5 | 4 | 20x10, 30x8, 42.5x6, 52.5x4 |
| 25 | 4 | 20x10, 22.5x8, 22.5x6, 25x4 |
| 30 | 6 | 20x10, 22.5x8, 22.5x6, 25x4, 27.5x3, 27.5x3 |

- Duplicated weights appear near the bar weight. A set whose rounded weight is at or below the bar is silently dropped, so the plan can have fewer rows than the stepper says.
- A warm-up at 25 kg or more (the 25 kg row above: 25x4) is the working weight itself.
- Rounding is to a fixed 2.5 regardless of the profile's smallest plate or lb (5 lb). Reps drop 10/8/6/4/3/3. Working weight at or under the bar returns an empty plan with no message. "Working Set" echoes the raw typed string.
- Bar options are 20/10/25 (no 15 kg), unlike the plate calculator.

[MEDIUM] AWV:87-91, 688-703 (index-based Bindings captured in ForEach) — Possible index-out-of-range on removal (unverified)
- `Binding(get: { viewModel.exerciseEntries[idx] })` and `entry.sets[setIdx]` capture an index. Removing the last exercise/set can invoke an old binding's getter with a stale index during the removal animation, a known SwiftUI crash pattern. Not reproduced because the simulator was off-limits.

[LOW] Views/Utilities/PlateCalculatorView.swift:114-124 — Standalone plate maths without epsilon, and greedy-only
- `while remaining >= plate` without tolerance and no rounding: 142.3 on a 20 kg bar leaves 1.1500000000000057. The inline version uses `- 0.001` and `.rounded(toPlaces: 3)`.
- Greedy can miss exact solutions with a custom plate set (plates {20,15}, per side 30: greedy 20 + 10 left; 15+15 is exact). The default plate set is canonical, so greedy is fine there.
- Impossible weights are not flagged in the standalone view (it shows "Achievable Weight" only if the target is above the bar); the inline view shows "+x.xxKG OFF".

[LOW] Views/Workout/WorkoutCompletionView.swift:330-343 — Only the first PR is shown
- `prDetails.first` is the only PR rendered (the highest impressiveness score). The remaining PRs only get a "PR" tag in the table, and only for the 7 rows shown. No PR list view.

[LOW] Views/Workout/WorkoutCompletionView.swift:22-29 — Dates use `Date()`, not the workout date
- `shortDate`/`shortDateBrief` use `Date()`, so a session spanning midnight is labelled with the next day, and the composer post uses `Date()` while the auto-post uses `workout.date`.

[LOW] Views/Workout/ShareCardView.swift (whole file), StartWorkoutView.swift — Dead code
- `ShareCardView`, `ShareCardType` and `renderShareCard` have no callers. The completion "share card" is an on-screen view only. There is no image export or system share.
- `StartWorkoutView` has no callers. `RestTimerExpandedView`, `RestTimerBanner`, `WorkoutBottomBar`, `InlinePlateView`, `ExerciseSubstitutionView` and `SetRowView` are legacy stubs.

[LOW] AWV:772-782 — RIR toggle: OFF wipes already-entered RIR values; ON sets a target of 3 on every set. The "target" is shown nowhere.

[LOW] AWV:1405-1415, 1441, 1368 — Rest modal adjustments
- The adjust buttons set `remainingSeconds` directly. They never update `totalSeconds`, so the ring can go negative (empty) after +30 and +1m beyond the original total. They also skip the completion alert if −15s reaches 0.
- Start timer is hard-coded to 90s rather than the user's rest setting. `targetSeconds = 150` is a dead fallback.

[LOW] AWV:107-120, 65-77 — Reorder drag assumes a fixed 190pt card height, but real cards vary with the number of sets, so the drop target is approximate.

[LOW] Views/Shared/BodyHeat+Exercises.swift:34-41 — The comment says posterior groups are "dropped from the peak", but `peak = counts.values.max()` includes them. A back/leg session dims the front-view muscles relative to a hidden posterior peak.

[LOW] Views/Workout/TagFriendsSheet.swift:70-76 — N+1 sequential profile fetches, one per friend, with no cap. Tagging only stores uids (no notification code on this path).

## Verified OK
- Inline plate maths (AWV:1706-1728). Standalone script gives:
  - 100 kg / bar 20 -> [25,15] per side
  - 102.5 / 20 -> [25,15,1.25]
  - 62.5 / 20 -> [20,1.25]
  - 62.5 / 15 -> [20,2.5,1.25]
  - 60 / 25 -> [15,2.5]
  - 100 / 7.5 -> [25,20,1.25]
  - 101 / 20 -> [25,15] + 0.5/side off (correctly reported)
  - 20 / 20 -> bar only
- Standalone `PlateCalculatorView` gives identical stacks and "achievable" totals for the same cases.
- The warm-up generator formula is internally consistent: `bar + (work-bar) * i/(n+1)`, rounded to 2.5, reps `max(3, 10-2i)`. Worked table above.
- Plate-bar drawing order is correct in `EquipmentProfilesView`: smallest outermost, largest inner.
- Epley 1RM matches the formula. A 1-rep set gives w x 1.033 (e.g. 103.33 for 100), so the 1RM is overestimated by 3.3%, and `Int()` truncates the display.
- Unlogged-set handling: only `isCompleted` sets are saved (WVM:313, 324), and the finish dialog correctly counts incomplete sets/exercises (AWV:54-59). The count in the dialog and the "N LEFT" label come from the same view-model state.
- Set order is re-indexed 0..n on save (WVM:324); `moveExercise` offset math is correct (AWV:114).
- Streak at completion uses `StreakCalculator` over non-draft workouts, with `max(1, ...)` (WVM:448-451).
- Rest timer service durations/formatting are covered by `RestTimerServiceTests` (compound 180, isolation 90).
- `ExercisePickerView` group definitions: all 136 names in `exerciseGroupDefinitions` exist in `ExerciseSeedService`, so no group is empty. The picker excludes already-added ids and filters by `isApproved || isCustom`.
- Live Activity LOG SET path fills ghost/planned values correctly (WVM:693-711, 805-812).

## Not verifiable
- Runtime behaviour: the simulator and xcodebuild were off-limits, so crash behaviour (index-based bindings), SwiftData relationship timing after `delete(log)` in `completeWorkout`, and rendering were checked by reading only.
- Whether the missing ghost-to-value copy on check is intended (design intent is not documented).
- Firestore security rules and whether the double-posted docs are rejected server-side (rules are not in the repo).
- Locale behaviour of `.decimalPad` on device (the parsing failure itself is verified by script).
- `liveCalories` / `updateLiveCalories` display: its UI consumer is outside my scope. The live compound detection (name keywords) differs from the final one (`movementPattern.isCompound`), so the two calorie values can disagree.

## Tests
- No test covers `WorkoutViewModel` (ghost text, PR detection, `completeWorkout`, draft save and resume), completion statistics (volume, best set, improved count), the plate calculator, the warm-up generator or `EquipmentProfile`. Only `RestTimerServiceTests`, `CalorieEstimationServiceTests`, `FirestoreModelTests`, `EnumTests` and `TutorialViewModelTests` exist.
