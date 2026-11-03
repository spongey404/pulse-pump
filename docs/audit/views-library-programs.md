# Audit: views-library-programs
Scope: Views/ExerciseLibrary, Views/Programs, Views/Shared, Views/Tutorial, Extensions, Views/Home/GlobalSearchView (+ ProgramsTabView/PresetTemplatePicker in ContentView, because Programs UI lives there). Paths are relative to /Users/vasanth.santosh/Documents/Apps/Ore/Ore.

## Summary
- A large part of this scope is dead code. `ExerciseLibraryView`, `ExerciseFilterSheet`, `CreateExerciseView`, `TemplateListView`, `EditTemplateView`, `SupernovaUpsellBanner`/`SupernovaBlurOverlay`, `OrePillButton`/`OreChipButton`, `InlineHint`, `StartWorkoutView` (the only `HintButton` user) and `programsTickerItems` have no call sites. Result: users cannot create custom exercises, browse or filter the library, remove an exercise from a template, or reorder one.
- Template share-via-link is half built. Encoding works, but nothing observes `.importTemplate`, so a received link does nothing.
- All preset/seeded templates use random `UUID()` exercise ids. Starting a workout from any preset then saves `ExerciseLog.exercise == nil`, which breaks history, PRs, body map and exercise detail for the most common path.
- Per-set type, per-exercise rest and RIR editing in `TemplateDetailView` is mostly cosmetic: set types are `@State` only and rest is never consumed. Editing a template in the live UI keeps sets/reps/RIR/rest.
- Supernova gating is inconsistent (4 different checks, `hasAccess(to:)` unused, MET calories unreachable for everyone, challenges/export/profiles ungated).
- Exercise detail maths (Epley, volume PR) is correct, but it counts warm-ups and the fake history that `injectTestData` writes into the real store.
- Tests: only `TutorialViewModelTests` touches this scope. Nothing covers search, stats, template share, grouping or seeding.

## Findings

[CRITICAL] ViewModels/WorkoutViewModel.swift:75 (cross-area, owned by workout agent) — `injectTestData` runs unconditionally on every `startWorkout`
`startWorkout` ends with `injectTestData(modelContext:)`. That function (lines 79-150) replaces `exerciseEntries` and inserts fake non-draft `Workout`/`ExerciseLog`/`SetLog` rows dated 7 days ago into the real store (lines 108-123). It is not wrapped in `#if DEBUG` and is present in HEAD (`git show HEAD:...:75`). Impact on this scope: ExerciseDetailView Weight PR, Est. 1RM, Volume PR, trend chart and Recent Sessions are polluted with fake sets such as "Barbell Bench Press 105x5". Fix: delete the call or guard it with `#if DEBUG` plus a launch flag.

[CRITICAL] Services/TemplateSeedService.swift:25-100 (consumed at ContentView.swift:1250, ViewModels/WorkoutViewModel.swift:57-66, 322) — seeded and preset templates carry random exercise ids
Every `TemplateExercise(exerciseId: UUID(), exerciseName: "Barbell Bench Press", ...)` gets a fresh random id. `PresetTemplatePicker` also calls the static vars again, so ids are new each time. `startWorkout` copies `templateExercise.exerciseId` into the entry, and on finish `exerciseLog.exercise = exerciseById[entry.exerciseId]` returns nil. A workout started from "Push Day" is saved with exercise-less logs, so:
- PR detection is skipped (`if let exercise = exerciseLog.exercise`).
- History, body map and muscle stats lose the sets.
- ExerciseDetail for "Barbell Bench Press" never shows those sets.
- `TemplatesContainingExercise` never lists seeded templates.
- `entry.exerciseType` / `isUnilateral` / `equipmentType` fall back to defaults.
Evidence: I checked all 21 template exercise names against `ExerciseSeedService`; every one exists (242 seeded exercises), so a name lookup would work.
Fix: when seeding or copying a preset, resolve `exerciseId` by name against `Exercise`. Also repair existing templates once, at start-workout time or in a migration.

[HIGH] ContentView.swift:1137 / App/OreApp.swift:88-92 — template import link is never handled
`handleDeepLink` decodes base64 and posts `.importTemplate` with `object: Data`. `grep importTemplate` finds only the declaration and the post, so there is no observer and no JSON decode. Tapping a `pulsepump://template?data=...` link does nothing. Missing pieces:
- JSON decode of `{name, exercises:[{name,sets,reps,rir}]}`.
- Exercise resolve by name.
- Duplicate-name handling.
- Bounds on size, sets and reps.
- Malformed-input handling. `Data(base64Encoded:)` failure currently falls through silently.
Fix: add a `.onReceive(.importTemplate)` in ContentView that decodes into a `Decodable` struct, validates, resolves exercises by name, and inserts a `WorkoutTemplate` with a name suffix if a duplicate exists.

[HIGH] Views/Programs/TemplateDetailView.swift:754-767 — share payload is lossy and one-sided
The payload is `{name, exercises:[{name,sets,reps,rir}]}`. It drops rest seconds, notes, split days, per-set types and exercise ids. In a multi-day program only `activeTemplate` is shared, not the program. The only thing shared is a custom-scheme URL, so a recipient without the app gets a dead link (the spec calls for a plain-text App Store fallback).
I ran a standalone script (scratchpad/lib/share.swift): `Optional.none as Any` is valid JSON, and base64 plus `.urlQueryAllowed` plus `URLComponents` round-trips 200 of 200 names including `+`, `/`, `ü` and `?`. So encode/decode symmetry is fine; the missing import is the problem.

[HIGH] Views/ExerciseLibrary/* — exercise library, filters and custom-exercise creation are unreachable
`grep ExerciseLibraryView` finds only its own declaration, and `CreateExerciseView` is referenced only from it. `ExercisePickerView` (Views/Workout) has no create-exercise entry (no `Exercise(` or `create` in the file). Consequences:
- Users cannot create a custom exercise, filter by muscle, equipment or movement pattern, or browse the library.
- `isCustom` / `isApproved` / "Pending Submissions" can never be set from the UI.
- `ExerciseDetailView` is reachable only through GlobalSearch and LiftHistory.
Fix: present `ExerciseLibraryView` from a tab or More row, and add "Create exercise" to `ExercisePickerView`.

[HIGH] Views/Programs/TemplateDetailView.swift:237-309 and 66-119 — no way to remove or reorder an exercise in a template
The edit mode in the live flow (`TemplateDetailView` via ProgramsTabView) only offers: add exercise, add/remove set, change reps/RIR/rest, edit notes. The three-line "drag handle" at 264-269 is decorative. `EditTemplateView` (which has a minus button) is unused, and it had no reorder either. A mistaken exercise can only be fixed by deleting the whole program. Also not editable: template name, split days.
Fix: add `.onDelete` / `.onMove` (needs `List`) or a trash button, and renumber `order`.

[HIGH] Views/Programs/TemplateDetailView.swift:20,30-40,407-410 — per-set TYPE chips are cosmetic
`setTypesMap` is `@State`, so it is lost on navigation. `startWorkout` builds `SetEntry(order:targetReps:targetRIR:)` and never reads set types. The default is also invented: set 1 of any exercise with more than 1 set displays "WU" (line 32) although nothing marks it as a warm-up. Every template therefore shows a warm-up that the logged workout does not have.
Fix: persist `setTypes: [String]?` on `TemplateExercise` and pass it into `SetEntry`, or remove the column.

[HIGH] Views/Programs/TemplateDetailView.swift:370-377,720 + ViewModels/WorkoutViewModel.swift:57-67 — template rest timer is never used
`TemplateExercise.restSeconds` is saved through the rest sheet, but `grep restSeconds` finds no consumer in WorkoutViewModel or RestTimerService (only live-activity fields). The per-exercise rest feature is dead. Notes (`template.notes`) are likewise never shown in the active workout (unverified for the ActiveWorkout UI, but the VM does not read them).

[HIGH] Extensions/SupernovaUpsellBanner.swift + Services/CalorieEstimationService.swift:52-60 + ViewModels/WorkoutViewModel.swift:252,413 — MET calories unreachable even for subscribers
`CalorieEstimationService.estimate(... isSubscribed: Bool = false)` falls back to basic when `isSubscribed` is false. Both call sites omit the argument. A Supernova user who picks MET in Settings (the picker is unlocked at SettingsView.swift:122) still gets the basic estimate. This is the only calorie feature gated in code.
Fix: pass `SupernovaService().isSubscribed || isInFreeTrial` (or cache the entitlement) at both call sites.

[HIGH] Supernova gating is inconsistent and incomplete (see the audit table below)
Gated:
- Widgets (MoreTabView.swift:103: subscribed or trial).
- Deload toggle (WorkoutDetailView.swift:49: subscribed or trial).
- Calorie formula picker (SettingsView.swift:54,122: subscribed or trial).
- MuscleDetailSheet sub-regions (lines 29,58,78): `isSubscribed` only, so trial users are locked out, unlike the rest.
- MoreTabView.swift:74: `isFree = !isSubscribed`, so trial users see a "FREE" label and a banner while having access.
Ungated but listed in `SupernovaFeature` / the spec:
- Challenges (known gap): `CreateChallenge*` and `ChallengesView` have no Plus check.
- Data export: DataExportView has none, though `.exportData` is a feature.
- Unlimited equipment profiles: `CreateEquipmentProfileView` has no limit.
- Smart weight suggestions, advanced substitutions, advanced analytics, advanced body customization, cloud sync, priority support: no gate found (unverified whether each feature exists).
Dead infrastructure: `SupernovaService.hasAccess(to:)` ignores its argument and has no callers; `SupernovaUpsellBanner` and `SupernovaBlurOverlay` are unused.
Each view creates its own `SupernovaService()`, so `isSubscribed` starts false until `refreshSubscriptionStatus()` finishes; a paying user sees locked UI briefly, or permanently if the view never calls refresh. `startListening()` is called only from SupernovaView.
Fix: a single shared `@Observable` service in the environment, with one `hasAccess(to:)` used everywhere.

[HIGH] Views/Programs/CreateTemplateView.swift:349-360 + ContentView.swift:1147-1153 — user programs merge with unrelated programs
`ProgramsTabView` groups templates by `splitDays.joined()`. `generateSplitDays` produces letter strings:
- "FULL BODY" with 3 days gives "FFF", the same key as the seeded Full Body A/B.
- "PPL" with 6 days gives "PPLPPL", the same key as seeded PPL.
- CUSTOM uses `name.prefix(1)`, so any two 3-day custom programs starting with "C" collide ("CCC").
The new program silently appears as an extra day tab inside another program, `derivedName` renames the group, and deleting that group deletes both. Fix: group by an explicit `programId`, or give new templates a unique key.

[HIGH] Views/Programs/EditTemplateView.swift:15-16,205-217 — editing destroys targets (view currently unused but ready to wire)
Init copies only `exerciseId`, `exerciseName`, `targetSets`, `targetReps`. Save rebuilds `TemplateExercise` and drops `targetRIR`, `restSeconds`, `notes` and the original ids. Any save wipes RIR and rest settings. The reps stepper shows "—" for nil but starts at 10 when touched.

[MEDIUM] Views/Programs/CreateTemplateView.swift:17-19,331-347 — create flow gaps
- `canSave` allows a template with zero exercises (the edit view requires at least one).
- `notes` is collected but never stored (`save()` never sets `template.notes`).
- Sets/reps/RIR cannot be set at creation even though the empty state promises "configure sets, reps and RIR".
- Days per week is required, though it is only used for the badge string.
- No duplicate-name check.
- An unmatched `daysPerWeek` for the cycle (PPL with 4 days gives P,P,L,P) is fine, but "UPPER / LOWER" 3 days gives U,L,U.

[MEDIUM] Services/TemplateSeedService.swift:6-13, ContentView.swift:98, Views/Programs/TemplateListView.swift:49 — presets re-seed after the user deletes everything
`seedIfNeeded` seeds whenever `WorkoutTemplate` count is 0. If a user deletes all programs (via the destructive modal), the next app launch re-creates all 7 presets. The empty state "NO PROGRAMS" is effectively unreachable across launches. There is no "seeded" flag.

[MEDIUM] Views/Programs/TemplateListView.swift:16-22 (dead) — swipe delete without confirmation
It is unused, but the live ProgramsTabView path correctly uses `destructiveModal`. Delete rules verified: `WorkoutTemplate.workouts` is `.nullify`, so logged workouts survive and `workout.template` becomes nil. The "past sessions kept" count is therefore truthful. Side effect: Quick Start rows for workouts whose template was deleted are disabled (ContentView.swift ~1385). The modal header says "IRREVERSIBLE / WHAT YOU'LL LOSE" while listing "past sessions kept" as a consequence, which is misleading (DestructiveModal.swift:46,74).

[MEDIUM] Views/Programs/TemplateDetailView.swift:447-466 — reps column is per-exercise, rendered per-set
Every set row shows the same `ex.targetReps`; editing any row changes all rows. Users will expect per-set reps. RIR has the same behaviour. `targetSets` is unbounded (`+ ADD SET`) whereas the edit view caps at 10. RIR / reps accept `Int(str)` with no clamp (0, 999). Template creation of duplicates is allowed (same exercise twice).

[MEDIUM] Views/ExerciseLibrary/CreateExerciseView.swift:41-79,142-157 — wizard validation can be bypassed (view unreachable today)
`TabView(.page)` lets the user swipe past step 0/1, ignoring `canAdvance`. The Save button on the last page calls `save()` with no validation, so an exercise with an empty name and no primary muscle can be inserted. No uniqueness check (case-insensitive name vs existing exercises), so duplicates are possible. Secondary muscles chosen earlier are not pruned when the same muscle is later added to primary (the `excluded` filter only hides it). Trimming uses `.whitespaces`, not `.whitespacesAndNewlines`. `modelContext.insert` is not followed by `save()` (autosave applies).

[MEDIUM] Extensions/String+Search.swift:8-13 — multi-word and substring search fail
`hasWordPrefix` splits the name on whitespace and requires one word to start with the whole query. Script output (scratchpad/lib/hw.swift): "bench press" -> false, "barbell bench" -> false, "ench" -> false, trailing space "ben " -> false. Users typing the full name of an exercise get no results in GlobalSearch, ExerciseLibrary and MuscleDetail. GlobalSearch's hint says "by name or muscle" (GlobalSearchView.swift:195) but muscle is not searched. Fix: split the query into tokens and require every token to prefix some word.

[MEDIUM] Views/Home/GlobalSearchView.swift:73-91 — friend search has no debounce, no cancellation and returns the user themselves
Each keystroke starts an unstructured `Task`; late responses overwrite newer ones (stale results). Firestore `username` prefix queries run per keystroke. Self is not filtered. The description says "by name" but only `username` is queried. Workout results are non-tappable (known). `matchingWorkouts` walks every workout's logs per body evaluation (O(n) over all history per keystroke).

[MEDIUM] Views/ExerciseLibrary/ExerciseDetailView.swift:75-120,128-137 — stats include warm-ups and are not unit-labelled
`allSets` = all `SetLog`s regardless of `setType`. A 20-rep warm-up at 40 gives Rep PR 20 and (Epley) e1RM 66.7, which can beat or distort real values; the max weight can include a warm-up only if it is the heaviest set (unlikely). WorkoutViewModel's PR check (line 345) uses the same unfiltered set, so the two are consistent but both overstate. Values have no kg/lb label (and `unitPreference` is never applied to logged weights anywhere I looked). The trend chart plots max weight per workout only and skips sessions with 0 weight, so bodyweight / duration exercises show an empty chart and "0.0" PR cards.
Fix: filter `setType != .warmup` and add a unit label.

[MEDIUM] Views/ExerciseLibrary/ExerciseDetailView.swift:210 — set order and number format
`log.sets` (SwiftData relationship array) is not sorted by `order`, so the displayed sequence is not guaranteed. `"\($0.weight)×\($0.reps)"` interpolates a Double, so users see "100.0×5". Notes list uses `ForEach(id: \.date)`; two logs with identical dates collapse or duplicate ids.

[MEDIUM] Views/Shared/TickerStripView.swift:25-98 — per-frame text resolve and measure
`TimelineView(.animation)` plus `Canvas` resolves and measures every label, arrow, value and dot on every frame (60-120 fps) for each item, on four screens. Cache the resolved widths (resolve once when `items` changes) or use a repeating offset with a static layout. Also `startDate` resets on any `items` change, causing a visible jump. Green values use `#00AA55` in light mode, but CLAUDE.md documents `#2a7a4a`.

[MEDIUM] Views/Tutorial/CoachMarkOverlay.swift + ViewModels/TutorialViewModel.swift:62-69 — 7 of 10 steps have no spotlight, and several describe unreachable UI
Only `gymProfile`, `plates` and `restTimerDefaults` have anchors. Steps 4-10 dim the whole screen and show a card, while the dim layer blocks the interaction the text asks for ("Tap the plates row", "Tap the circle to complete", "Tap an exercise to open its variants. Bench Press splits by angle first" — no variants feature found in code). The Programs / Workout steps are placeholders. `tutorialCompleted` is written but never read. After the tutorial ends the More tab stays on whatever sub-screen (equipment/settings) was last shown (`syncTutorialScreen` only drives it while active).
Anchor resolution: `.overlayPreferenceValue(TutorialTargetKey)` on the TabView, resolved through `proxy[anchor]`, merges ids with `$1` winning; there are no id collisions. Whether anchors from the selected tab propagate through `TabView` is unverified (requires a device run). The fixed `cardHeight = 215` is smaller than the real card with long descriptions or large Dynamic Type.

[MEDIUM] Views/Tutorial/HintSystem.swift — 9 of 10 hints unused
Only `HintButton(hint: .startWorkout)` exists, in `StartWorkoutView`, which itself has no call sites, so no hint is ever visible. `InlineHint` is unused. (Spec known gap.)

[LOW] Views/ExerciseLibrary/ExerciseLibraryView.swift:20-77 — pending custom items appear twice
`filteredExercises` accepts `isApproved || isCustom`, so pending submissions (`isCustom && !isApproved`) are listed in both "Pending Submissions" and the main list; the pending section also ignores filters. There is no backend for submissions (known gap), and "Replace Exercise" is the title in selection mode even if used elsewhere.

[LOW] Extensions/SupernovaService (Services/SupernovaService.swift:131-143) — trial boundary
`daysSinceInstall <= 14` gives 15 days of access while `trialDaysRemaining` is 0 on day 14. Reading `isInFreeTrial` has a side effect (writes `appInstallDate` on first read). Reinstall resets the trial (known gap).

[LOW] Extensions/WorkoutModal.swift:12,67-90 — `primaryDestructive` is accepted but never used (the button is always accent). `UIScreen.main.bounds` (deprecated, wrong in split view). Both modals carry accent/red drop shadows, against the "no drop shadows" design rule (DestructiveModal.swift:150, WorkoutModal.swift:79,92, CreateTemplateView.swift:228).

[LOW] ContentView.swift:1194-1204 — `programsTickerItems` / `setCount(for:)` compute over all recent workouts but are never rendered (dead code).

[LOW] Views/Shared/SwipeToDeleteRow.swift — no `accessibilityAction`; the reveal state is stuck open if the user swipes and then taps content (`resetReveal` is never passed by callers). In TemplateDetailView deleting a set has no confirmation. Row identity is index-based (`ForEach(0..<n, id: \.self)`), so reveal state follows the index, not the set.

[LOW] CLAUDE.md says 84 exercises are seeded; `ExerciseSeedService` defines 242 (`grep -c "Exercise("`) and GlobalSearch copy says "84+".

## Verified OK
- `Epley` formula in ExerciseDetailView.swift:94-97: `w*(1+r/30)` for r>1, `w` for r<=1. Script: 100x5 -> 116.67, 100x1 -> 100, 40x20 -> 66.67. Matches the formula used by WorkoutViewModel.
- Volume PR (weight x reps summed per log, max over logs) and Weight/Rep PR are computed from real `ExerciseLog`/`SetLog` data, with no hardcoded values. `ExerciseTrendChart` sorts ascending by workout date and has a >=2 point guard.
- Draft safety: `SetLog`s are created only for completed sets at finish (WorkoutViewModel.swift:313-340), so exercise stats never include in-progress drafts.
- Template deletion: `WorkoutTemplate.workouts` has `.nullify`, `Workout.exerciseLogs` has `.cascade`, so deleting a program keeps history. The destructive modal counts are computed from real relationships.
- Share-link encoding/decoding symmetry (script): 200/200 round-trips with special characters; `Optional.none` serialises as null without crashing.
- Muscle-filter logic (`ExerciseLibraryView.filteredExercises`): primary or secondary intersect is OR across selected muscles, AND with equipment and movement pattern; `activeFilterCount` and Clear behave correctly (though the screen is unreachable).
- `CustomTabBar` tags (0 Programs, 1 Social, 2 Home, 3 Body, 4 More) match ContentView's `TabView` tags and the tutorial's `requiredTab` values.
- Tutorial routing: `requiredTab` -> `CoachMarkOverlay.onChange/onAppear` -> `selectedTab`; `MoreTabView.syncTutorialScreen` runs in `onAppear` and on step/active change, so a lazily-built More tab still lands on the right sub-screen. Tutorial skip/complete clear `wantsTutorial`; replay is available from More > Tutorial and the completion screen.
- `TemplateNavItem.templates.first!` is safe because groups always contain at least one template.
- `Color(hex:)` handles `#RRGGBB` only (other lengths give black); no call site passes 8-digit hex (I did not grep every site, so unverified for the whole app).
- `StepProgressIndicator`, `Avatar`, `PressScaleButtonStyle`, and `DestructiveModal` confirm/cancel wiring are correct (no empty closures).

## Not verifiable
- Whether SwiftUI propagates `anchorPreference` values from non-selected or lazily-built `TabView` pages to `overlayPreferenceValue` on the `TabView` itself (needs a device or simulator run; I was not allowed to build).
- Whether the tutorial dim layer blocks touches to the spotlighted element (hit testing of the `Rectangle` with a reverse mask).
- ActiveWorkoutView consumption of `template.notes` and the remaining Supernova features (smart weight suggestions, advanced substitutions) — outside this scope; presence of gating there was checked only by grepping for `isSubscribed`/`hasAccess`.
- Firestore security rules for the `users` collection used by friend search.
