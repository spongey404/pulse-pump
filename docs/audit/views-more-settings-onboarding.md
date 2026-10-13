# Audit: views-more-settings-onboarding

Scope: PulsePump/Views/More/** (incl. Widgets/), Views/Settings/**, Views/Onboarding/** + OnboardingViewModel. Read-only; no builds run. Paths below are relative to /Users/vasanth.santosh/Documents/Apps/Pump/PulsePump unless noted.

## Summary
- 3 CRITICAL, 9 HIGH, 11 MEDIUM, 6 LOW (plus the setting table below).
- Biggest theme: Settings is mostly decorative. Of ~20 stored preferences, 9 are never consumed (smart suggestions, simple body map, all 4 privacy levels, social/challenge notifications, post-workout summary toggles, plus the whole body profile: height/age/gender/experience). The unit preference (kg/lbs) is consumed in exactly one display spot and is inconsistent with how weight is stored.
- Onboarding is bypassed on a fresh install by an unguarded demo-data seeder, and a returning-user sign-in creates a blank local User and overwrites Firestore stats.
- WeeklyRecap (new code) is mostly correct (ISO Monday weeks, warm-ups excluded, PR vs prior bests), but has a partial-week comparison flaw, drops shoulder/back sub-muscles, and hard-codes "KG".
- Widget builder grid logic is sound and unit-tested; the builder view has a piece-id collision on re-edit, and custom-widget pieces fall back to hard-coded fake sample data even when real data exists.
- Privacy & Legal screen: every action is an empty closure (no privacy policy, no ToS, no data download, Delete Account does nothing).

## Setting -> stored where -> consumed where

| Setting | Stored | Consumed | Verdict |
|---|---|---|---|
| Weight unit (kg/lbs) | `User.unitPreference` (SwiftData) | Display only: ProfileView.swift:246 (multiplies by 2.20462), EditProfileView.swift:31 (label), PulsePlusView.swift:123 (label) | INCONSISTENT. See findings 4, 5. Active workout, history, detail, recap, widgets, export, import, plate calc all hard-code kg. |
| Body weight | `User.weight` (raw number typed in the chosen unit) | CalorieEstimation (as kg, WorkoutViewModel.swift:251/411), BodyweightLog (as kg), widget snapshot `bodyweight` (WidgetDataService.swift:88) | WRONG for lbs users (finding 4) |
| Height | `User.height` (cm) | nowhere (only EditProfile) | STORED, NEVER CONSUMED (onboarding copy claims "baseline metabolism") |
| Age | `User.age` | nowhere | STORED, NEVER CONSUMED |
| Gender | `User.gender` | ProfileView display only | STORED, NEVER CONSUMED in logic |
| Experience level | `User.experienceLevel` | TutorialPromptStepView copy, Profile display | Not used for any behaviour (no defaults/suggestions) |
| Training split | `User.selectedSplit` -> `Split` (days always empty) | Notifications, WeeklyRecap target, widget goal, predictNextWorkout, all read `split.days` | EFFECTIVELY DEAD (finding 6) |
| Calorie formula | `@AppStorage calorieFormula` | WorkoutViewModel.swift:249,412 | HONOURED for `.basic`; `.met` never takes effect (finding 3) |
| Rest timer mode | `restTimerMode` | RestTimerService.swift:15, WorkoutViewModel.swift:226 | Honoured; `autoStartWithDismiss` behaves identically to `autoStart` |
| Timer alert | `restTimerAlertType` | RestTimerService.swift:20, playAlert | Honoured |
| Smart weight suggestions | `smartWeightSuggestions` | NOWHERE. `smartWeightSuggestion()` (WorkoutViewModel.swift:535) is never called; ActiveWorkoutView `smartSuggestion` param is never passed | DEAD toggle AND dead feature (finding 7) |
| Theme | `appTheme` | PulsePumpApp.swift:47-50 `preferredColorScheme` | Honoured |
| Simple body map | `simpleBodyMap` | NOWHERE | STORED, NEVER CONSUMED |
| Auto-share to feed | `autoShareToFeed` | WorkoutViewModel.swift:469; toggled off in WorkoutCompletionView.swift:522 | Honoured |
| Profile visibility | `privacy_profile` | NOWHERE (also the other 3 PrivacyRow keys in ActivityView) | STORED, NEVER CONSUMED (finding 8) |
| Workout reminders | `workoutReminders` | NotificationService.swift:36 | Honoured in code, but split.days is empty so nothing is ever scheduled |
| Rest-day alerts | `restDayAlerts` | NotificationService.swift:74 | Honoured in code, but with empty split.days it schedules an alert on all 7 days |
| Social notifications | `socialNotifications` | NOWHERE (NotificationService header: "stored for future use") | STORED, NEVER CONSUMED |
| Challenge notifications | `challengeNotifications` | NOWHERE | STORED, NEVER CONSUMED |
| Post-workout summary toggles (5x `summary_show*`) | `PostWorkoutCustomizationView` (SettingsView.swift:242) | View is never presented; keys never read | DEAD CODE |
| Equipment profiles | `EquipmentProfile` | Only EquipmentProfilesView; not read by plate calc/exercise logic; hub shows `.first` as "active" though the model has no active flag | Stored, effectively unused elsewhere |
| wantsTutorial | `UserDefaults` set in completeOnboarding (OnboardingViewModel.swift:142) | ContentView.swift:92 starts tutorial; TutorialViewModel.complete() resets it | Honoured |
| tutorialCompleted | TutorialViewModel.swift:125 | NOWHERE | Written, never read |
| Onboarding name | `User.name` + Firestore profile | Profile, feed `username: user.name` | Honoured; local `User.username` never set (Profile derives it) |

## Findings

[CRITICAL] Services/WorkoutDemoDataService.swift:7 + Views/RootView.swift:22 — demo user + 5 weeks of fake workouts seeded in production, onboarding skipped
`RootView` shows onboarding only when `users.isEmpty`. Its `.task` runs `WorkoutDemoDataService.seedIfNeeded` with no `#if DEBUG`. On a fresh install the seeder inserts `User(name: "Jordan", username: "jordan_lifts", weight: 81...)` plus ~weeks of workouts and saves (line 211), flipping `users.isEmpty` so `OnboardingContainerView` is replaced by `ContentView` almost immediately (the commit "move demo data seed to RootView" introduced this). Expected: real user goes through onboarding with empty data. Actual: new user lands in the app as "Jordan" with a 13-day streak, fake PRs, fake weights; every onboarding field (name, units, weight, split, tutorial) is never collected. Same task also calls `requestPermission()` at launch, before onboarding. Fix: wrap the seed in `#if DEBUG` (or a launch argument) and move the notification prompt to the settings toggle/after onboarding.

[CRITICAL] ViewModels/WorkoutViewModel.swift:81 — `injectTestData` runs on every `startWorkout` (cross-area, found while tracing demo data)
Only `showPreviewCompletion` (line 526) is inside `#if DEBUG`; `injectTestData` is called unconditionally at the end of `startWorkout`. It sets `exerciseEntries = []` (discarding the template's exercises that were just built) and fills 10 hard-coded exercises with completed sets, and inserts fake "previous" workouts dated 7 days ago for PR comparison into SwiftData. Expected: starting "Push Day" gives that template's blank sets. Actual: fake pre-completed bench/OHP sets and fabricated history polluting stats/PRs. Verify by starting any workout. Fix: delete the call or guard with `#if DEBUG` + launch flag. (Belongs to the workout area; flagging because it makes everything downstream of Settings/Recap untrustworthy.)

[CRITICAL] Views/Onboarding + ViewModels/OnboardingViewModel.swift:141/130 vs Views/More/ProfileView.swift:246 — weight unit stored raw, treated as kg elsewhere, converted again in Profile
Onboarding lets the user pick LBS and stores `Double(weightText)` verbatim in `User.weight` (line 113/126). `BodyweightLog.record(kg: user.weight)` (line 141), `EditProfileView.save()` (line 65), calorie estimation (`bodyWeightKg: user.weight`, WorkoutViewModel.swift:251,411) and the widget `bodyweight` all treat the number as kg. ProfileView then multiplies by 2.20462 when unit == lbs. Worked example: user enters 180 lbs: stored 180; Profile shows `Int(180*2.20462)` = "396 LBS"; the MET calorie formula would use 180 "kg" (2.2x too high); the bodyweight widget/log shows 180 kg. Changing "Weight Unit" in Settings (SettingsView.swift:108) just flips the label, never converts `user.weight`. Fix: store kg canonically (convert at onboarding/EditProfile by unit), add one `Weight.display(kg:unit:)` helper and use it everywhere.

[HIGH] ViewModels/WorkoutViewModel.swift:249,412 / Services/CalorieEstimationService.swift:52-59 — MET formula can never be applied
`estimate(... isSubscribed: Bool = false)` falls back to the basic formula unless `isSubscribed` is true, and neither call site in WorkoutViewModel passes it (grep: `isSubscribed` appears only in CalorieEstimationService and PulsePlusService). Settings offers "MET-Based" to Pulse+ and trial users (SettingsView.swift:122). Expected: selecting MET changes kcal. Actual: kcal is always the set-count estimate for everyone, including paying users. Fix: pass `isSubscribed` (or drop the gate) at both call sites.

[HIGH] Models/Split.swift + OnboardingViewModel.swift:135 + SettingsView.swift:307 — `Split.days` is never populated, which kills reminders, weekly goal and predictions
`SplitDay(` is only declared in Models/Split.swift; onboarding (`Split(type:)`) and `SplitConfigView` ("Save Split") both create splits with `days = []`. Consequences (all verified by reading): `scheduleWorkoutReminders` returns at `!split.days.isEmpty` (NotificationService.swift:37) so "Workout Reminders" never schedules anything; `scheduleRestDayAlerts` treats all 7 days as rest days; WeeklyRecap target is always `max(week.count, 5)` (WeeklyRecapView.swift:47-48); widget goal falls back to 5; `predictNextWorkout` reads `split.days` (WorkoutViewModel.swift:626). Onboarding says "This sets up your first program template" but no template is created. Also `SplitConfigView` inserts a new `Split` each save and orphans the old one (nullify rule), and does not call `NotificationService.reschedule`. Fix: generate `SplitDay`s from `SplitType` on creation, delete/replace the old split, reschedule notifications.

[HIGH] Views/Settings/SettingsView.swift:129 — "Smart Weight Suggestions" toggle is dead and the feature is unwired
See table. `smartWeightSuggestion(for:setIndex:modelContext:)` has no callers, the `smartSuggestion` parameter in ActiveWorkoutView.swift:1886 defaults to nil and is never supplied, and no code reads `smartWeightSuggestions`. Fix: wire the call (gated on the setting + Pulse+) or remove the row.

[HIGH] Models/Enums/PrivacyLevel.swift + Views/Settings/SettingsView.swift:133 + Views/Social/ActivityView.swift:58 — all privacy levels are cosmetic
Four `privacy_*` keys (profile, workoutPosts, bodyMap, globalLeaderboards) are stored but no code reads them: `shareWorkoutToFeed`, FirestoreService reads and friend/profile fetches ignore them. A user choosing "Only me" for workout posts still posts to the feed whenever auto-share is on (WorkoutViewModel.swift:469 checks only `autoShareToFeed`). The source comment admits server enforcement is a TODO, but the UI promises "YOUR PROFILE IS PRIVATE" / "BODY MAP NEVER SHOWS ON A POST". Fix: at minimum honour them client-side in the share path and store them on the Firestore profile; otherwise label as not yet active.

[HIGH] Views/More/PrivacyLegalView.swift:20-26,51,58 — Privacy & Legal actions are all empty
`openLegal()` is `{ }` (Privacy Policy, Terms, Licenses do nothing), "Download My Data" is `{ }`, and the Delete confirm button is `{ }` (alert text admits "isn't available"). In-app account deletion is an App Store requirement for apps with account creation (Guideline 5.1.1(v)); this is a submission blocker. Fix: link real URLs; wire "Download My Data" to `DataExportService`; implement `Auth.currentUser.delete()` + Firestore doc cleanup + local wipe.

[HIGH] Views/More/MoreTabView.swift:129 and Views/Settings/SettingsView.swift:78,236 — Sign Out does not sign the user out of the app
`FirebaseAuthService().signOut()` only calls `Auth.auth().signOut()`. `RootView` gates on `users.isEmpty` (SwiftData) and nothing observes auth state (grep for `addStateDidChangeListener`/auth observers outside onboarding: none). After "Sign Out" the user stays in `ContentView` with all data; the alert text ("You'll need to sign back in") is false. Subsequent Firestore calls run unauthenticated (`Auth.auth().currentUser?.uid ?? ""` posts with empty userId at WorkoutViewModel.swift:473). A new `FirebaseAuthService()` instance is also created per tap. Fix: observe auth state in RootView; on sign-out, route to onboarding/sign-in and clear or detach local user.

[HIGH] ViewModels/OnboardingViewModel.swift:187-190,112-155 — returning user (sign-in) path creates a blank local User and clobbers the Firestore profile
For an existing account, `shouldSkipToComplete = true` triggers `completeOnboarding` (OnboardingContainerView.swift:50) with empty fields: `User(name: <maybe ""> , weight: 0, height: 0, age: 0, ...)` and a new `FirestoreUserProfile(uid:, username: name-derived, displayName:)` with `totalWorkouts/currentStreak/longestStreak = 0` and `createdAt = Date()`, written with `setData(from:merge:true)` (FirestoreService.swift:18). `merge:true` merges at field level but the encoded struct contains every field, so the user's existing social stats, createdAt and possibly username/displayName (Apple returning users often have no `displayName`, so name = "") are overwritten. The local profile is never restored from Firestore either, so a reinstall loses weight/units/split. Fix: for returning users fetch the profile and skip the write (or write only fields that are non-empty); collect body data if local User is missing.

[HIGH] Services/DataImportService.swift (used by Views/Settings/DataExportView.swift:96-100) — importer duplicates on re-import, ignores units/warm-ups, mostly fails to match exercises
(a) No dedupe: importing the same CSV twice doubles every workout. (b) Strong exports in the user's unit; weights are saved verbatim as kg-equivalent (no conversion); Hevy `weight_kg` is fine. (c) Exercise matching is exact-name `$0.name == name` (e.g. Strong "Bench Press (Barbell)" vs seed "Barbell Bench Press"): unmatched logs get `exercise = nil`, so they vanish from PRs, muscle maps and appear as "Unknown" in export; no custom exercise is created. (d) Warm-up rows (Strong "W" set order) become `.standard` sets, inflating volume/PRs. (e) `workout.duration` stays 0, so recap TIME and calories ignore imports. (f) `parseCSV` splits on newlines before handling quotes, so quoted notes with newlines corrupt rows, and `""` escapes are dropped. (g) Strong workouts are keyed by the date string alone. (h) The import never calls `save()` (relies on autosave) and `handleImport` returns silently when `startAccessingSecurityScopedResource()` fails or when `user` is nil (DataExportView.swift:89,94), so the user gets neither success nor error. (items a, c, d, e, f verified by reading; match-rate against real Strong files is unverified.)

[MEDIUM] Views/More/WeeklyRecapView.swift:34-35,194-196 — current-week deltas compare a partial week against a full previous week
For `weeksBack == 0` on a Wednesday, `week` covers Mon-Wed while `prev` is the entire previous Mon-Sun. Example: 2 sessions / 18 sets this week vs 4 sessions / 40 sets last week shows VOLUME, SETS, TIME and every muscle row as "down". Expected (same-window comparison): `prev` truncated to the same elapsed offset (prevStart ..< prevStart + (now - weekStart)). Past weeks (weeksBack >= 1) are fine. Fix: when `weeksBack == 0` clamp the prev range upper bound.

[MEDIUM] Views/More/WeeklyRecapView.swift:69-78 — muscle bucketing drops sub-regions
`bucket()` handles back/lats/traps/chest/quads/hamstrings/glutes/calves/shoulders/biceps/triceps/forearms only. `.sideDelts`, `.frontDelts`, `.rearDelts`, `.upperBack`, `.lowerBack`, `.abs`, `.obliques`, `.neck`, `.hipFlexors`, adductors/abductors map to nil. `muscleSets` uses only `primaryMuscleGroups.first`. From the seed list: all 5 lateral-raise-style `[.sideDelts]`, 3 `[.rearDelts]`, 3 `[.frontDelts]`, 2 `[.lowerBack]`, `[.rearDelts,.upperBack]` exercises contribute 0 to Shoulders/Back. Hand check: a session of 4 sets lateral raise + 3 sets face pull shows Shoulders = 0. Also "Shoulders" and "Arms" rows will under-count. Fix: add sideDelts/frontDelts/rearDelts -> Shoulders, upperBack/lowerBack -> Back, or use a shared muscle->region map (WidgetDataService already has one).

[MEDIUM] Views/More/WeeklyRecapView.swift:224 — "VS WK n-1" wrong at the start of the ISO year
`weekNumber - 1` yields "WK 0" in week 1 (should be 52/53). Use `calendar.component(.weekOfYear, from: prevStart)`.

[MEDIUM] Views/More/WeeklyRecapView.swift:267-273 — PR value always labelled "KG"; PR rules narrow
Label is the hard-coded string "KG" for lbs users (also see finding on units). PR logic (lines 91-109) requires `bestBefore[n] != nil`, so a first-ever log of an exercise is never a PR, bodyweight movements (weight 0) never register, and rep-only improvements are ignored; exercises are keyed by `exercise.name` (a rename splits history). `for (n, s) in top` iterates a Dictionary so multiple PRs within one workout come out in nondeterministic order, and the displayed reps come from the first-max set rather than the best reps at that weight. Acceptable design choices, but mismatch with the live-PR check in WorkoutViewModel.checkPR (which counts all sets incl. unfinished history) means the recap count can disagree with the completion screen.

[MEDIUM] Views/More/WeeklyRecapView.swift:34,35,60-66,89-110 — repeated full scans in view body
`week`, `prev`, `records` (flatMaps every workout/set before weekStart) are computed properties re-evaluated several times per render (bars: 7x `week`; `records` read twice in prSection). With a few hundred workouts this is thousands of relationship faults per frame. Fix: compute once in a local `let` per body or cache with `onChange`.

[MEDIUM] Views/More/WorkoutHistoryView.swift:160-163,26-28 — calendar cells recompute the whole date set 42x per render
`calCell` calls `workoutDateSet` (formats every workout date) for each of 42 cells, so cost = 42 x N DateFormatter calls per body pass; also `workoutsOn` formats all dates again. Noticeable at 500+ workouts. Fix: compute the set once in `calendarGrid`.

[MEDIUM] Views/More/WorkoutDetailView.swift:68-71 — delete then immediate dismiss while view still reads the deleted model (unverified at runtime)
`modelContext.delete(workout); dismiss()` leaves `statsStrip`/`detailHeader` bound to a deleted `@Bindable workout` for the pop animation; reading properties of a deleted/saved-away SwiftData model can trap. Safer: dismiss first, delete in `onDisappear`/after the pop, or capture needed values.

[MEDIUM] Views/More/WorkoutDetailView.swift:194-219 — "Duplicate" silently inserts a second draft
It creates `Workout(isDraft: true)` with copied logs and no feedback/navigation. Drafts are what `StartWorkoutDock` treats as an in-progress/crashed session (@Query isDraft), so one tap on Duplicate (or two taps) adds draft(s), potentially next to a real active draft. Whether resume correctly rebuilds `exerciseEntries` from those logs is unverified. Also the copy gets `date = now` but copies all sets including warm-ups.

[MEDIUM] Views/More/WorkoutDetailView.swift:303-316 — set editing cannot clear a value and breaks on comma decimals
`setLog.weight = Double(v) ?? setLog.weight`: clearing the field (v == "") or typing "62,5" in a comma-decimal locale keeps the old weight, so a value can never be set to 0/blank and the visible text diverges from the stored value. Also editing never refreshes `calorieBurnEstimate`, widget snapshot or the Firestore feed post, and no PR/volume summary exists on this screen (stats strip shows only duration/exercises/sets/kcal; no charts).

[MEDIUM] Views/More/Widgets/WidgetBuilderView.swift:29,426,449 — piece ids collide after re-editing a saved widget
`@State private var seq = 1` generates ids `"n1","n2"...` per builder session, but saved user widgets keep those ids. Re-open a saved widget containing `n1`, add a piece: new id `n1` duplicates the existing one. `ForEach(draft.pieces)` gets duplicate ids, `selected`/drag state target both, and `removeAll { $0.id == id }` (lines 416, 483) deletes both. Preset ids (a1, b2...) don't collide. Fix: UUID ids, or initialise `seq` above the max existing numeric suffix.

[MEDIUM] PumpShared/PumpWidgetSnapshot.swift:94-117 (via WidgetBuilderView/WidgetsView snapshot hand-off) — fake sample data shown as real when `hasData == true`
`metric(for:)` starts from the catalog sample and only overrides some fields: (a) spark `bw` ("Bodyweight, 30 days") is never overridden, so it always plots the hard-coded 83.6->82.4 series and "82.4 KG" even though `BodyweightLog` has real data; (b) spark e1rm shows the sample series/value when fewer than 2 weekly points exist; (c) prog `program` ("PPL WEEK 3/8") is never computed; (d) `.next` keeps "PUSH DAY / 6 EX" when no prediction exists; (e) `.num` unknown metric and `.pr` unit are hard-coded. Users with real data can therefore see invented numbers on their home-screen widget. Fix: when hasData and the real value is missing, blank the piece ("—") instead of falling through to sample.

[MEDIUM] Services/WidgetDataService.swift:77-99 (snapshot built from WidgetsView.load, WidgetsView.swift:41-43) — O(n^2) snapshot build on the main thread
For each workout in the current week `improvements(w, history: workouts)` re-computes `topWeights` for every earlier workout; plus `predictNextWorkout` and per-set loops. Runs on every scene activation and every WidgetsView appear, synchronously. Fine for tens of workouts; slow for hundreds.

[MEDIUM] Views/Settings/PulsePlusView.swift:19-25 — paywall advertises features that don't exist
"Cloud Sync: Sync across all your devices" (no sync layer exists; CLAUDE.md says local-first), "Weekly Recaps: Automated Monday summaries" (recap is a free, manual screen with no automation), "Import / Export" (free, ungated: DataExportView has no Pulse+ check), "AI-powered workout suggestions" (the prediction is a template heuristic). Misleading marketing in a paid purchase flow is an App Review/refund risk. Also `matchedProduct` (line ~418) falls back to `availableProducts.first` if the chosen period's product is missing, so tapping "ANNUAL" can purchase the monthly plan while showing the annual price UI.

[MEDIUM] Views/Settings/PulsePlusView.swift:477-496,326-337 — purchase/restore give no feedback for pending/cancelled/restore
`purchaseProduct` ignores the `false` result (`if !success { }`), so Ask-to-Buy "pending" shows nothing; "Restore Purchases" swallows errors (`try? await AppStore.sync()`) and shows no confirmation or "nothing to restore". `Transaction.updates` listener skips unverified transactions silently. The trial is `UserDefaults("appInstallDate")` based and reinstall/clear resets it; `isInFreeTrial` writes to defaults inside a getter (documented gap in CLAUDE.md).

[MEDIUM] Views/Settings/DataExportView.swift:8 vs Services/DataExportService.swift:36,66 — export includes drafts and unlabelled units; CSV not escaped
Header counts finished workouts (`!isDraft`) but exports `FetchDescriptor<Workout>` with no filter, so drafts (including the test/duplicate drafts above) leak into JSON/CSV and the count shown ("N WORKOUTS") disagrees with the file. Weights are exported with no unit column (kg vs lbs ambiguity). Exercise names are quoted but embedded quotes are not escaped. Exports are written to a fixed tmp filename (fine) and errors are surfaced via alert.

[MEDIUM] Views/Settings/SettingsView.swift:199-231 — notification toggles ignore denied permission and split changes
When permission is denied and the user turns the toggle ON, the toggle stays on with nothing scheduled and no prompt to open Settings. `RootView` also calls `requestPermission()` at every launch.

[LOW] Views/Onboarding/WeightStepView / HeightStepView / OnboardingViewModel.swift:72-80 — loose validation
Weight accepts any positive number (0.1, 9999), no upper bound; height cm likewise; lbs-height path `Int(heightFeet) > 0` allows 9 ft; comma decimals ("72,5") fail `Double()` so Continue is disabled with no message in comma locales. Progress labels in views ("02 / BODY", "07 / PROGRAM", "08 / ALMOST DONE") don't match the 8-step counter. `.unitPreference` step is dead code (UnitPreferenceStepView unused).

[LOW] Views/More/ProfileView.swift:143-144 and MoreTabView.swift:184-185 — FOLLOWERS and FOLLOWING both show `friends.count`
There is no follower/following distinction in the data model; the second number is a duplicate of the first. Profile "FOLLOWING" rows all show a fake "FOLLOWING" pill.

[LOW] Views/More/MoreTabView.swift:145-147 vs WeeklyRecapView.swift:51 — hub "WK n" uses `Calendar.current.weekOfYear` (locale, Sunday-start in US) while Recap uses ISO; they disagree on Sundays (e.g. Sun 4 Oct 2026: hub 41, recap 40).

[LOW] Views/More/WorkoutHistoryView.swift:237,350 — set counts include warm-ups
List/calendar cards count all `SetLog`s while WeeklyRecap excludes warm-ups, so the same session shows different set totals. Same in WorkoutDetailView stats strip.

[LOW] Views/Settings/EditProfileView.swift:63-69 — name change not synced; no validation
Editing the name updates SwiftData only (Firestore `displayName` stays stale); weight/height/age accept negatives or 0 (only `BodyweightLog` guards `> 0`). Height shows "cm" for imperial-onboarded users.

[LOW] Views/More/Widgets/WidgetBuilderGrid.swift:11-17 — `occupancy` traps on out-of-range stored pieces
`for y in p.y..<min(p.y + p.h, size.rows)` crashes ("Range requires lowerBound <= upperBound") if a stored piece has `p.y > rows` (or x > cols), e.g. a hand-edited/corrupt App Group blob or a future size change. Normal builder flows can't produce it (setSize runs tidy). Clamp the lower bound.

[LOW] Views/More/Widgets/WidgetBuilderView.swift:68-75 — back button discards unsaved edits without confirmation; WidgetGalleryView draws `PumpWidgetSnapshot.sample` (design sample data) while its header comment says "what ships"; gallery is a preview only.

## Verified OK
- Theme: `appTheme` -> `preferredColorScheme` (App/PulsePumpApp.swift:47-50, wired).
- Rest timer mode/alert: SettingsView bindings write the same keys RestTimerService reads (RestTimerService.swift:15,20), `restTimer.mode` gates auto-start (WorkoutViewModel.swift:226); alert type switch in `playAlert` covers all four cases.
- Auto-share: key read at WorkoutViewModel.swift:469 and "never post automatically" correctly writes it (WorkoutCompletionView.swift:522).
- WeeklyRecap: ISO calendar with Monday start (lines 18-22); week range is half-open [weekStart, weekStart+7d), no off-by-one or overlap with `prev`; drafts excluded via @Query; warm-ups excluded from volume/sets/muscle sets; volume = sum(weight*reps)/1000 tonnes; delta guards `b > 0` (no divide by zero); past-week navigation (`weeksBack`) arithmetic is DST-safe (calendar date math); PR detection uses only workouts strictly before `weekStart`, updates `bestBefore` as it walks the week chronologically so a second heavier set in the same week isn't double counted.
- WorkoutHistory calendar: Monday-offset formula `(weekday + 5) % 7` correct for Sun..Sat; 42-cell grid always large enough (max offset 6 + 31 days = 37); month navigation via `Calendar.date(byAdding: .month)`; list stats (this month / streak) use the shared StreakCalculator and a drafts-excluded @Query; swipe-to-delete lives in a `List` per project convention and asks for confirmation.
- WidgetBuilderGrid: occupancy/isFree/best/fit/tidy logic traced by hand: bounds checks correct, reading-order tie-break (`y*100+x`) correct, nearest-spot Euclidean distance, size fallback via `sizes(for:first:)`, tidy drops body-map on lock; covered by WidgetBuilderGridTests (empty grid, snap, fallback, full grid, skip, tidy, lock drop, presets fit, PR variant lookup).
- Widget library save/load: `PumpWidgetStore` JSON round-trips through the App Group; first-run seeds presets; builder `save()` refuses empty widgets, republishes and calls `WidgetCenter.reloadAllTimelines()`.
- Widget snapshot data that is computed correctly: streak, sessions-this-week (ISO Monday), per-day sets/volume (warm-ups excluded), PR map, Epley weekly e1RM series, body-heat regions, template list, goal fallback.
- Paywall price maths: monthly/annual per-month price, "/YR" label and saving % (`1 - (annual/12)/monthly`) use `Decimal` prices and `priceFormatStyle` correctly; entitlement check only counts verified, current entitlements for the two product ids.
- Onboarding data flow for new sign-ups: name/weight/height (feet+inches -> cm: `ft*30.48 + in*2.54`)/age/gender/units/experience/split persisted into `User` + `Split`; tutorial flag `wantsTutorial` persisted and consumed (ContentView.swift:92) and cleared on completion (TutorialViewModel.swift:124); `shouldSkipToComplete` fires once.
- Navigation: all MoreTabView hub rows route to a real screen; `screen == .pulsePlus` uses a full-screen cover with a close path; tutorial sync of Settings/Equipment screens works through `syncTutorialScreen`.

## Not verifiable
- Runtime behaviour (SwiftData deleted-model access in WorkoutDetail, draft-resume after Duplicate, Ask-to-Buy, App Group widget refresh): no build/simulator allowed.
- Real-world Strong/Hevy CSV compatibility (column variants, locale, exercise-name match rate): no sample files in the repo.
- StoreKit product configuration (product ids `com.pulse.PulsePump.monthly/.yearly`, introductory offer) lives in App Store Connect / a .storekit file not examined.
- Widget extension rendering (PulsePumpWidget/CustomWidget.swift) and whether the extension's intent lists the same library: out of scope here; only the app-side hand-off was checked.
- EquipmentProfilesView internals and the Social privacy screen beyond how they use the settings keys.

## Tests
Covered: WidgetBuilderGrid placement/tidy/PR-name lookup (WidgetBuilderGridTests), widget fixed data (WidgetFixedDataTests), calorie formulas (CalorieEstimationServiceTests), rest timer (RestTimerServiceTests), tutorial VM, enums.
Not covered: WeeklyRecap bucketing/PR/comparison, WorkoutHistory calendar, OnboardingViewModel (height conversion, canContinue, completeOnboarding), unit conversion, DataImport/Export, PulsePlus, notification scheduling, BodyweightLog, snapshot fallbacks. PumpTests.swift is only the template `example()` test.
