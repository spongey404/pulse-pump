# Audit: viewmodels-workout
Scope: Ore/ViewModels/WorkoutViewModel.swift, TutorialViewModel.swift, OnboardingViewModel.swift (+ call sites read for wiring).
Scratch scripts: scratchpad/predict.swift, scratchpad/pr.swift (ported verbatim logic, outputs quoted below).

## Summary
- WorkoutViewModel.startWorkout unconditionally calls `injectTestData` (committed in HEAD), so every new workout is wiped of its template exercises and replaced by 10 fake, pre-completed exercises, and fake historical workouts are written to SwiftData. This is the worst issue.
- Draft persistence does not work. Only duration/notes are saved. ExerciseLogs/SetLogs are created only in completeWorkout, so "Save as draft", backgrounding and crash recovery lose all entered sets. The "Continue" card always shows 0 sets done.
- Completion posts to the feed twice (auto-share in the VM plus the completion screen's own post). The auto-post happens before the user can choose caption, "don't post", or "no body map".
- PR logic: live `checkPR` and completion PR logic differ. Warm-ups, drop sets and set types are ignored throughout (PR, ghost text, calories, set counts). "improved" counts equal weight as improved. Bodyweight rep PRs are missed live.
- Units: there is no kg/lb handling anywhere in logging. Onboarding stores the typed weight raw even when LBS is chosen, and Profile then multiplies by 2.2 again.
- Prediction (`detectNextByPattern`) is correct for clean PPL/UL/bro cycles. It is non-deterministic on ties and can return names that match no template ("Leg Day", "Pull Day"), which silently start a blank workout. Smart weight suggestions and superset behaviour are dead features.
- Onboarding: the returning-user sign-in path creates an empty User (weight 0, name "") and a Firestore merge that resets stats. No equipment profile is ever created. The demo seed in RootView creates a "Jordan" user and likely bypasses onboarding in production (cross-area, see F11).

## Findings

[CRITICAL] WorkoutViewModel.swift:81 (+85-145) — `injectTestData` runs on every `startWorkout`
- What: `startWorkout` ends with `injectTestData(modelContext:)`. It does `exerciseEntries = []` (line 86), which discards the template exercises just built at lines 55-74. It then appends 10 hard-coded exercises ("Barbell Bench Press" 107.5x5 ...), each with every set `isCompleted = true`. It sets `startTime` back 4680s (line 144), so the timer starts at about 78 min. For each name that exists in the catalog it also inserts a fake historical `Workout` (dated -7 days, isDraft=false, attached to the user) with an ExerciseLog and SetLog (lines 108-125).
- Scenario: the user taps START WORKOUT with the "Push Day" template. Expected: template exercises, 0 sets done, 0:00 timer. Actual: 10 unrelated exercises, all sets complete, 1:18:00 elapsed. Tapping finish saves this fake workout, computes PRs/calories from it, and auto-posts it to friends' feeds (line 470-488). Fake history rows also pollute history, streaks, body map, ghost text and PRs. `Workout()` default isDraft is true and the fake workouts set it false, so they count as real.
- Evidence: `injectTestData(modelContext: modelContext)` at line 81. Doc comment line 84: "Populates exerciseEntries with realistic pre-completed test data for UI development." Not wrapped in `#if DEBUG`. `git show HEAD:...` also contains it (HEAD line 75).
- Fix: delete the call (and the function), or wrap both in `#if DEBUG` behind an explicit launch flag.

[CRITICAL] WorkoutViewModel.swift:508-513 / 147-179 / 316 — draft persistence and crash recovery are not implemented
- What: `saveDraft()` only writes duration/notes/updatedAt. Nothing creates ExerciseLog/SetLog until `completeWorkout` (the only `ExerciseLog(` in the VM besides the test seed is line 316). The in-progress `exerciseEntries` live only in memory. `resumeDraft` rebuilds from `workout.exerciseLogs`, which are empty for any real draft.
- Scenario: log 3 exercises, background the app, iOS kills it. Relaunch: a draft Workout exists, so the dock shows CONTINUE. Tapping it opens an empty workout. The card says "0 SETS DONE" because `draftSetsDone` (ContentView.swift:923) counts `draft.exerciseLogs.flatMap(\.sets)`, which is empty. `draftProgress` is always 0.
- Only `WorkoutDetailView.duplicateWorkout` (line 195-218) creates a draft with real logs. In that path `resumeDraft` restores sets with `isCompleted = false` (never set), and ignores `ExerciseEntry.id` and the ghost cache.
- Other gaps:
  - UI copy "Drafts auto-save for 7 days" (ActiveWorkoutView.swift:242, ContentView.swift:318) has no expiry code (grep isDraft: none). Stale drafts live forever and block the dock.
  - `modelContext.save()` is never called in the VM. It relies on SwiftData autosave, which is not guaranteed before a kill.
- Fix: in `saveDraft`, snapshot entries into ExerciseLog/SetLog (replace existing draft logs), mark completed ones, and call `try? context.save()`. Make `resumeDraft` restore `isCompleted`, and add a purge for drafts older than 7 days.

[HIGH] WorkoutViewModel.swift:468-488 vs WorkoutCompletionView.swift:561-581 — workout is posted to the feed twice, and before user consent
- What: `completeWorkout` fires `shareWorkoutToFeed` immediately when `autoShareToFeed` is true (default true, line 469). The completion screen's `postAndDismiss` builds a second `WorkoutFeedItem` with a new random id and posts it again (caption, tags, includesBodyMap). Item ids default to `UUID().uuidString`, so these are two distinct docs.
- Scenario: user finishes, writes a caption and taps POST. The feed shows two posts, one without the caption. If the user taps "Don't post", the auto-post has already gone out. The auto post also uses `user.name` while the manual one uses `Auth...displayName ?? "User"`, so usernames differ. With no signed-in user, `userId` is "" and it posts anyway.
- Fix: remove the auto-share from the VM (or move it into the completion view as "post on dismiss unless declined" with a deterministic doc id).

[HIGH] WorkoutViewModel.swift:535-566 — Smart Weight Suggestion is dead code, and its Settings toggle is unused
- What: `smartWeightSuggestion` has no callers (grep). The `smartWeightSuggestions` AppStorage toggle (SettingsView.swift:43,129) is never read. The Supernova feature `.smartWeightSuggestions` (SupernovaService.swift:12) therefore delivers nothing.
- Logic note (unverified at runtime): it compares the last two sessions and doubles the increment, e.g. 100 -> 105 suggests 110. It ignores set type, so warm-ups skew it. It needs >= 2 logs.

[HIGH] WorkoutViewModel.swift:218-231 / ActiveWorkoutView.swift:1254 — Superset (and other set types) have no behaviour
- What: `SetType.superset` is only a label. The picker text says "Paired with next exercise, no rest" (ActiveWorkoutView.swift:1254), but no pairing or grouping model exists. `ExerciseEntry` has no superset id, and `logSet` starts the rest timer for every set type. Warm-up, drop, rest-pause and superset sets all trigger a full compound-length rest.
- Also: `isCompound: true` is hard-coded at ActiveWorkoutView.swift:975 and WorkoutViewModel.swift:810, so the isolation rest default (`isolationRestSeconds`) is never used, except via per-exercise overrides.
- Fix: skip or shorten the rest timer for `.warmup`/`.superset`/`.dropset`. Pass `exercise.movementPattern.isCompound`.

[HIGH] OnboardingViewModel.swift:113,124 — lbs weight stored as kg (double conversion downstream)
- What: the unit toggle (WeightStepView.swift:50) only sets `unitPreference`. `completeOnboarding` stores `Double(weightText)` unchanged in `User.weight`. Every consumer treats `User.weight` as kg: ProfileView.swift:246-247 multiplies by 2.20462 for lbs users, `BodyweightLog.record(kg:)` is called with it (line 141), and the MET calories use it as `bodyWeightKg` (WorkoutViewModel.swift:251,410).
- Scenario: user picks LBS and types 180. Stored 180. Profile shows "396 LBS". The bodyweight widget series is in "kg" = 180. The MET estimate is inflated 2.2x. EditProfileView.swift:65 has the same issue (shows "lbs" next to the field, stores raw as kg).
- Fix: convert at the boundary (`kg = lbs / 2.20462`) in both places, or store the unit with the value.

[HIGH] WorkoutViewModel.swift (whole file) / SetLog.swift — no unit handling for logged weights
- What: `SetLog.weight` has no unit and the VM never converts. The Settings unit picker (SettingsView.swift:107-108) simply flips `user.unitPreference`. Flipping kg -> lbs relabels every historical number (100 "kg" becomes 100 "lbs") without converting it. The same goes for feed `FeedSetLog.weight`, which is shared with friends who may use the other unit. The PR / `weightDelta` / calorie numbers are unit-agnostic raw numbers.
- Fix: store canonical kg and convert for display/input, or lock the unit after onboarding.

[HIGH] OnboardingViewModel.swift:112-156 + OnboardingContainerView.swift:50-52 — returning-user sign-in runs `completeOnboarding` with empty form data
- What: for an existing account, `shouldSkipToComplete = true` triggers `completeOnboarding` with `name=""`, `weightText=""`, `ageText=""`, so User(name: "", weight: 0, height: 0, age: 0, gender .preferNotToSay, beginner). (When Apple/Google supply a display name it is used; email sign-in has none.) It then writes a `FirestoreUserProfile(uid, username: "", displayName: "", totalWorkouts: 0, currentStreak: 0, longestStreak: 0, createdAt: now)` with `setData(from:, merge: true)` (FirestoreService.swift:17-19). `merge: true` still overwrites every encoded field, so the server profile's username, displayName, stats and createdAt are reset. Local history is not restored (no pull), and the MET calorie fallback sees weight 0.
- Fix: for existing accounts, fetch the Firestore profile and hydrate the User, and do not write a profile with empty fields.

[HIGH] ContentView.swift:1018-1036 + WorkoutViewModel.swift:659-663 — predictor can return names that match no template, and the dock silently starts a blank workout
- What: fallbacks return hard-coded "Pull Day", "Leg Day", "Push Day", "Lower", "Upper". `startDock` resolves the template by exact lowercase name match. `predictedTemplate = nil` means `startWorkout(template: nil)` starts an empty workout while the dock text promises the prediction. Script output: PPL history [Push, Pull] gives "Leg Day"; if the user's template is named "Legs" no template matches.
- Also the first branch can return the name of a deleted template (history keeps names via `$0.template?.name`; `template` is nullified on delete, so those workouts are skipped from names, which silently shortens the sequence).

[MEDIUM] WorkoutViewModel.swift:651-654 — tie-breaking in `detectNextByPattern` is non-deterministic
- Script: history oldest-first [A,B,A,C,A] (A is followed once by B and once by C) gave B in 2 of 8 runs and C in 6 of 8 (Swift dictionary order is randomised per process). Real-life cases: any program where a day has two different successors equally often (e.g. alternating A/B weeks: Push,Pull,Legs,Push,Legs,Pull,...). The dock prediction can flip between app launches.
- Fix: tie-break by recency (most recent occurrence of the successor), sort candidates deterministically.

[MEDIUM] WorkoutViewModel.swift:613-630 — split fallback always returns the first day, and it is reached only when pattern detection fails
- What: `days.first?.label` after sorting by `dayOfWeek`. It ignores today's weekday and the user's actual last session. Onboarding creates `Split(type:)` with `days: []`, so the fallback returns `split.type.displayName` (e.g. "Push/Pull/Legs"). That is not a template name, so ContentView resolves no template (blank workout) and the dock shows the split name as "today's workout".
- Also: a single-session history (`names.count < 2`) returns nil from the pattern and falls to this fallback. With 2 sessions of a "new last" name (e.g. Push,Pull,Arms) the pattern returns nil and the fuzzy keywords miss, so it falls through to the split label.
- Window: only the 14 most recent workouts are considered. Workouts with no template (blank/ad-hoc) are dropped from `names` (compactMap) instead of breaking the sequence.

[MEDIUM] WorkoutViewModel.swift:659-665 — fuzzy keyword fallback is order-biased and substring-based
- "Upper Push" or "Shoulders & Legs" hit the push/leg branches first. `lower.contains("leg")` matches "Legacy ...", "Pull" returns Legs even for Pull-then-Push programs, etc. For "full" it returns the same workout again (`return last`). Verified with script: `["Upper Push","Lower","Upper Push"]` -> "Pull Day".

[MEDIUM] WorkoutViewModel.swift:351-380 / 570-609 — PR detection: ignores set type and mixes semantics
Script outputs (pr.swift):
- `20kg x 25` warm-up vs history [20x10 WU, 100x5]: live PR = true (warm-up flagged). `checkPR` has no `setType` check.
- `80x10` vs history [60x15 WU, 80x8]: not a PR (false). A lighter set's 15 reps raises `previousMaxReps` ("this weight or lighter", line 604), so real rep PRs at a heavier weight are blocked.
- `70x9` vs [100x5, 60x8]: PR = true (beats the lighter 60x8 despite being under the 100x5 e1RM). `110x1` vs [100x8]: PR = true (weight PR) even though e1RM is lower (113.7 vs 126.7). e1RM is used only for `improvementScores`, not for PR flags.
- Bodyweight: `0x12` vs [`0x10`]: live false (requires `weight > 0`, line 603), but completion marks it a rep PR (lines 370-379). Live flag and completion count disagree.
- Completion: today `100x5` + a 40x20 warm-up, history [100x5, 60x12]: `bestRepsThisWorkout`=20 > `previousMaxReps`=12 gives a rep PR (true). Warm-up reps counted.
- First ever session (no history): no PR (`previousBestWeight > 0` required). Defensible, but live and completion are consistent here.
- `isPR` is never cleared (no un-complete path), and the live check ignores sets earlier in the same session. A second 105x5 against history max 100 is also flagged.
- Completion `prCount` counts per exercise, whereas the live flags are per set, so the in-workout stars and the summary number can differ.
- Fix: exclude `.warmup` (and optionally drop sets) from both history and current; compute rep PR at equal-or-heavier comparison; share one function between live and completion.

[MEDIUM] WorkoutViewModel.swift:381-383 — `improvedCount` counts "same" as improved and also counts PRs
- `bestWeight >= previousBestWeight && previousBestWeight > 0` increments for an unchanged top weight even with fewer reps. Test-data comments (lines 96-99, "same", "worse (fewer reps)") and the preview (`improved 6`) imply equal/worse should not count. Expected for "Face Pull 25kg same": improved = false. Actual: true. This inflates the "improved" statistic shown in the summary and the feed.
- Fix: use `current1RM > previous1RM` (already computed).

[MEDIUM] WorkoutViewModel.swift:351-358,385-393 — "vs last" deltas compare to best-ever, not last session
- Comment at 387-389 says "VS LAST", but `previousBestWeight`/`previous1RM` are maxima across all history (`exercise.logs`). A user who deadlifted 200 once and 180 last time shows a negative/0 delta for 185. `improvementScores` uses `max(0, ...)`, so regressions show 0 (never negative), unlike the preview data (-3, -5). The ghost text uses the latest session, so two different baselines appear.
- Also `repsDeltas` compares to max reps at weights <= bestWeight, not reps at the same weight.

[MEDIUM] WorkoutViewModel.swift:265-280 — ghost text lookups
- Which exercise: correct (`log.exercise?.id == exerciseId`). Latest session only: yes (`.first` of `createdAt` descending; `createdAt` = log creation time, not `workout.date`). Imported (Strong/Hevy) or duplicated logs have `createdAt` = import/duplicate time, so they are treated as the "latest session" regardless of the actual workout date.
- Set index: raw positional index over all sets including warm-ups. If last time had 1 warm-up + 3 working sets and this time there is none, set 1 shows the warm-up weight. If this session has more sets than last time, `setIndex >= count` returns nil (no fall back to the last set).
- Draft logs from `duplicateWorkout` (isDraft=true, createdAt now) count as "latest".
- No `isDraft` filter and no filter on completed `Workout`.
- Perf: called in the view body per set row per render (ActiveWorkoutView.swift:689): a full SwiftData fetch of every log of the exercise for every row on every redraw (the timer ticks each second and `elapsedSeconds` is observable). `lastTimeCache` exists for Live Activity but ghost text is uncached.

[MEDIUM] WorkoutViewModel.swift:284-296,447-451 — completion edge cases
- No guard for empty workouts: finishing with zero completed sets sets `isDraft=false`, saves an empty workout, increments streak (`max(1, ...)` at 451), counts toward history, and auto-posts a 0-exercise item. Uncompleted sets that contain typed values are silently discarded.
- `Double(setEntry.weight)`: a decimal-comma locale ("62,5") parses to nil -> 0 stored. Weight "62,5" becomes a 0 kg set (also in PR logic). No `replacingOccurrences(",", ".")` anywhere.
- `rir` is `Int(setEntry.rir)` (nil if empty): fine. `duration` is set only via `Double(...)`: ok.
- Volume: `WorkoutCompletionData` carries no total-volume figure. Warm-ups are included in `totalSets`, `compoundSets/isolationSets`, calories, and the muscle list. (If volume is computed elsewhere, other agents should check warm-up exclusion.)
- `exerciseCount` counts only entries with completed sets; `totalExercises` counts all entries (including empty ones), which the feed also stores.
- `streakCount` uses `max(1, currentStreak)`, so a streak of 0 displays 1.
- `workout.date` is the creation time (start); OK. `calorieBurnEstimate` uses `workout.duration` (includes rest), fine for MET, but MET falls back to basic unless `isSubscribed` (the call omits `isSubscribed`, default false, so MET is never used even for Supernova users: CalorieEstimationService.estimate line 52/59, called at WorkoutViewModel.swift:252 and 413).

[MEDIUM] WorkoutViewModel.swift:233-261 vs 399-409 — live vs final calorie classification differs
- Live uses name keywords ("press" matches "leg press", "chest press machine", but also "Tricep Press..."; "row" matches "Upright Row"), final uses `movementPattern.isCompound`. The live number and final number can differ. `liveCalories` is not read anywhere outside the VM (grep), so it is wasted work. Warm-up sets count fully.

[MEDIUM] WorkoutViewModel.swift:508-513,497-524,671-681 — lifecycle leaks and inconsistencies
- "Save as draft" (ActiveWorkoutView.swift:247) calls `saveDraft(); isActive = false` and does NOT stop the duration timer, end the Live Activity or remove the observers (only `stopDurationTimer` does). The Live Activity keeps running and the timer keeps ticking in the background.
- `resumeDraft` calls `startDurationTimer()` without invalidating an existing `durationTimer` (duplicate timers, double Live Activity pushes), does not set `liveModelContext`, does not install the observers, and does not start the Live Activity. After a cold start, the Dynamic Island/LOG SET intents don't work and `plannedValues` has no ghost fallback.
- `resumeDraft` does not reset `exerciseEntries`, so resuming in the same process appends logs onto stale in-memory entries.
- `discardDraftAndStart` deletes the draft but does not stop a previous timer. `reset()` doesn't stop the timer; it relies on a prior `stopDurationTimer`.
- `Timer.scheduledTimer` runs in `.default` run-loop mode, so ticks (and Live Activity pushes) pause during scroll tracking. Elapsed time is recomputed from `startTime`, so the value stays correct but updates stall.
- `startTime` for resumed drafts is `now - workout.duration`, which only counts time up to the last `saveDraft` and excludes time while the app was dead, so duration is understated.

[MEDIUM] OnboardingViewModel.swift:134-140 / 84 — collected data not fully persisted or consumed
- `selectedSplitType` creates a `Split` with `days = []`. Nothing in onboarding populates days, so notifications (`NotificationService.reschedule(split:)`, RootView.swift:26) and the prediction fallback have no schedule to work from.
- No `EquipmentProfile` is created in onboarding (the only `EquipmentProfile(` is in EquipmentProfilesView.swift:376). Tutorial steps 1-3 (Gym Profile/Plates) therefore point at a screen that may have nothing to show for a new user.
- `experienceLevel` is stored and only displayed (ProfileView / Settings); nothing uses it (no programming defaults).
- `gender` is optional but nil defaults silently to `.preferNotToSay`. The `.unitPreference` step is dead (`flow` skips it) but OnboardingContainerView still has a case for it.
- Validation: weight accepts any positive Double (0.1, 99999); the imperial path requires feet > 0 but inches are unvalidated ("99" in = +251 cm); the cm path has no upper/lower bounds; no check that the username is unique or non-empty. `Double("80,5")` = nil blocks "continue" in decimal-comma locales (a typical European keyboard), with no message.
- Username derivation `name.lowercased().replacingOccurrences(" ", "")` can yield duplicates or non-alphanumeric usernames. The local `User.username` is not set here, so local vs Firestore usernames differ (verify in User model).
- `completeOnboarding` also never calls `try modelContext.save()` (autosave only).

[MEDIUM, cross-area] RootView.swift:23 + WorkoutDemoDataService.swift:7-33 — demo seed creates user "Jordan" on first launch, probably bypassing onboarding
- `RootView.task` calls `WorkoutDemoDataService.seedIfNeeded` unconditionally (no `#if DEBUG`). It inserts `User(name: "Jordan", ...)` if no user exists. `RootView` shows onboarding only while `users.isEmpty`, so on a fresh install the user is created within the first task run and onboarding is replaced by ContentView with demo data. It would also seed demo PPL history that feeds the predictor. Reported by the services area presumably, listed here because it makes the OnboardingViewModel flow unreachable. Unverified at runtime (not run).

[LOW] WorkoutViewModel.swift:195-216 — `removeSet`/`removeExercise` don't renumber `order`
- `addSet` uses `sets.count` for `order` after a removal, producing duplicates. Harmless on save (completion renumbers `j`), but `resumeDraft` sorts by `order` and could give unstable order.

[LOW] TutorialViewModel.swift:99 / 102-126 — minor
- `progress` = rawValue/(count-1): step 1 shows 0%. `skip()` and `complete()` are identical (skip marks `tutorialCompleted` true, so the user can never be re-prompted, though Settings could restart via `start()`). `wantsTutorial` is read once in `ContentView.onAppear` (line 92) and cleared only by `complete()`, so if the user kills the app mid-tutorial it restarts from step 0 each launch (no step persistence). `target` is nil for 7 of 10 steps (acknowledged in comment). `requiredTab: 2` for Home vs `0` for Programs: relies on the tab index scheme in ContentView (unverified).

[LOW] WorkoutViewModel.swift:30,709-731 — `lastTimeCache` is never invalidated; caches the empty result for exercises with no history, and `lastTime` shows only the first 4 sets, and warm-ups are included.

## Verified OK
- Set-type persistence: `setType`/`side` copy into `SetLog` at completion (lines 331-340) and round-trip in `resumeDraft`.
- `completeWorkout` deletes the old logs first (lines 296-298) and excludes the current log from "previous" via `$0.id != exerciseLog.id`; cascade rules (`Workout`->`ExerciseLog`->`SetLog`, `Exercise.logs`) mean `cancelWorkout`'s `modelContext.delete(workout)` removes child logs, so cancel leaves no orphans. `isDraft=false` is set at completion only; cancel deletes the draft entirely.
- Index guards in `logSet`, `addSet`, `removeSet`, `removeExercise`, `checkPR` use `indices.contains`.
- `exerciseById` reuse avoids N fetches at completion.
- `detectNextByPattern` (script `predict`): correct for
  - PPL cycle P,Pu,L,P,Pu,L -> Push; ends on Pull -> next "Legs" when seen (4 sessions) -> Pull/Push correct
  - Upper/Lower alternation U,L,U,L -> Upper; U,L,U,L,U -> Lower
  - Bro 5-split over 10 sessions -> Chest
  - Full Body A/B alternation -> B
  - one off-pattern session (PPL with a skipped day) still resolves by majority
  - history with a single session -> nil (falls to the split fallback). Chest,Back -> nil (unseen successor)
- `StreakCalculator.currentStreak` is used for the completion streak (not re-audited here).
- TutorialViewModel step transitions and the finish flag are covered by TutorialViewModelTests; `advance()` past the last step sets `isFinished`.
- Rest timer integration: `logSet` clears the completion state and only auto-starts in the `autoStart*` modes. Per-exercise overrides are honoured through `restDuration(exerciseId:)`.
- Live Activity: state dedupe (`cachedRestEnd`) logic is sound; the observers are installed once (`guard liveObservers.isEmpty`) and removed in `stopDurationTimer`.
- Onboarding step flow (`flow`, `progressSteps`, `canContinue`, `goBack`) is internally consistent; `advance()` stops at the end.

## Not verifiable
- Runtime behaviour of the Live Activity / App Intents (LOG SET, skip/adjust rest) and Dynamic Island: needs a device/simulator (not run per brief).
- Whether SwiftData autosave flushes the draft state before a force-kill (platform behaviour).
- Firestore rules for `feed` writes (not in repo scope here).
- `NewSetRowView` and exercise picker internals (set-type UI, per-set `isPR` display) were only read at the call sites.
- Whether the demo seed (F11) really skips onboarding on a fresh install: conclusion from reading RootView; not run.

## Tests
- Covered: TutorialViewModel (TutorialViewModelTests), RestTimerService, CalorieEstimationService (pure formula).
- Not covered (no test files exist): WorkoutViewModel (start/complete/cancel, PR detection, ghost text, prediction, draft), OnboardingViewModel (validation, completeOnboarding, unit conversion). The pure functions `detectNextByPattern` and the PR comparisons are private/inline and untestable without refactoring them into value-type helpers.
