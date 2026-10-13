# models-data audit

## Summary
- Scope read in full: all Models/, PulsePumpApp, RootView, StreakCalculator, Import/Export, Exercise/Template/Demo seed services.
- 3 CRITICAL: demo data (fake user "Jordan" + 13 fake workouts) is seeded into every real install and skips onboarding; `startWorkout` injects fake test data into every real workout (outside my scope, found while tracing); seeded/preset templates carry random exercise IDs so logged exercises detach from the library.
- Import/export is weak: Strong/Hevy exercise names rarely match the seed catalog, so exercises detach; no dedupe; warmups, RPE, notes, duration ignored; export omits duration/distance/side and cannot be re-imported.
- StreakCalculator logic verified with a script (DST, duplicates, expiry): correct as specified. No unit tests for it or for anything in this area.
- Schema: no migration plan, `fatalError` on container failure; Exercise->ExerciseLog cascade is a latent history-loss risk (no UI deletes exercises today).
- CLAUDE.md says 84 exercises; seed actually contains 242 (all unique names).

## Findings

[CRITICAL] PulsePump/Views/RootView.swift:23 + Services/WorkoutDemoDataService.swift:7-31,179-211 — demo data seeded into real users' stores, and it skips onboarding
- `.task { WorkoutDemoDataService.seedIfNeeded(...) }` runs unconditionally (no `#if DEBUG`, no flag). Only guard is UserDefaults `demoWorkoutDataSeeded_v5`.
- Fresh install: no User exists, so line 19-31 inserts `User(name:"Jordan", username:"jordan_lifts", weight 81...)`. RootView shows onboarding only when `users.isEmpty` (RootView.swift:13), so onboarding is bypassed or flipped away mid-flow to ContentView. Real user gets 13 fake workouts (streak 13, PRs, volumes), 3 templates, fake body-map/stats.
- Existing real user upgrading (key v5 unset): 13 fake workouts (workout.user = nil) plus "Push/Pull/Leg Day" templates (reuses a real template with the same name) are injected into their history, streak, volume, body map, export. Bumping the key (v6) would re-inject.
- Also if onboarding does finish, `OnboardingViewModel.completeOnboarding` (line ~124) inserts a second User; `users.first` is then ambiguous.
- Fix: delete the call or wrap in `#if DEBUG` behind an explicit launch arg; never create a User there.

[CRITICAL] PulsePump/ViewModels/WorkoutViewModel.swift:81 (injectTestData, defined 85-148) — every started workout is filled with fake data (cross-area, reported because it feeds data models)
- `startWorkout` ends with `injectTestData(modelContext:)`, not under `#if DEBUG`. It does `exerciseEntries = []` (discarding the template's exercises built at 56-72), appends 10 pre-completed fake exercises, inserts fake historical Workouts/ExerciseLogs/SetLogs for the user (lines 108-125, dated 7 days ago), and backdates startTime by 4680s (~78 min). Finishing saves those fake sets as real. Several test names do not exist in the catalog ("Incline Dumbbell Press", "Cable Fly", "Dumbbell Lateral Raise", "Chest Dip") so their `exerciseId` is a random UUID.
- Fix: remove the call or `#if DEBUG`.

[HIGH] PulsePump/Services/TemplateSeedService.swift:26-97 — seeded/preset templates use random exercise IDs
- Every `TemplateExercise(exerciseId: UUID(), exerciseName: "...")`. `startWorkout` (WorkoutViewModel.swift:58-72) fetches Exercise by `exerciseId` -> nil, so exerciseType/isUnilateral/equipmentType fall back to weighted/false/barbell (timed and bodyweight lifts treated as weighted). `finishWorkout` line 321 does `exerciseLog.exercise = exerciseById[entry.exerciseId]` -> nil, so the saved ExerciseLog has no Exercise. Those logs vanish from body map (BodyModelView.swift:59 `guard let exercise = log.exercise`), PR/ghost values (`log.exercise?.id == exerciseId`), analytics, and export shows "Unknown". Applies to all 7 seeded templates and the "Choose a template" presets copied at ContentView.swift:1250 (copies keep the random IDs; EditTemplateView.swift:16 preserves them). Currently masked only because injectTestData clears entries.
- Fix: resolve IDs by name at insert time (fetch Exercise by name), or fall back to name lookup in startWorkout/finishWorkout.

[HIGH] PulsePump/Services/DataImportService.swift:85-87,159-161 — imported exercises mostly unlinked
- Matches only by exact `name ==` against the catalog; no normalising, no creation of a custom Exercise on miss. Strong names ("Bench Press (Barbell)", "Squat (Barbell)") do not equal catalog names ("Barbell Bench Press", "Barbell Squat"). Unmatched -> `exerciseLog.exercise = nil` -> invisible to body map, PRs, stats, and exported as "Unknown". Unit/behaviour inferred from code; real Strong naming is from memory (unverified).
- Fix: on miss create `Exercise(isCustom: true, ...)` (or alias map) so history is attached.

[HIGH] DataImportService.swift:71,147 — unparseable dates silently become "now"
- `dateFormatter.date(from:) ?? altFormatter... ?? Date()`. Hevy real exports use e.g. "29 Aug 2023, 10:36" (from memory, unverified), which neither ISO8601-with-fractional nor "yyyy-MM-dd HH:mm:ss" parses; all workouts would land on today (also polluting streak). ISO formatter requires fractional seconds, so plain "2024-01-05T10:00:00Z" also fails. DateFormatters lack `locale = en_US_POSIX` (lines 63-66, 141-142), so non-Gregorian/12h-locale devices can misparse.
- Fix: count and skip unparseable rows; set POSIX locale; add more formats.

[MEDIUM] DataImportService.swift:46-48,90,164 — fields dropped, units not handled
- Notes read (line 48) but never stored (SetLog has no notes; tuple field discarded). Hevy `set_type` (warmup/dropset/failure), `rpe`, `distance_km`, `duration_seconds`, end_time (workout duration), Strong `RPE`, `Seconds`, `Distance`, `Set Order` ("W" warmup), Workout Notes/Duration all ignored: warmups imported as standard working sets (inflates volume/PRs), timed lifts import as 0 reps, Workout.duration = 0 so calorie/duration stats read 0.
- Strong exports in the user's own unit; no lb->kg conversion anywhere (the app stores raw numbers; unitPreference is display-only in ProfileView.swift:246).
- `Double("82,5")` -> nil -> weight 0 for comma-decimal locales.

[MEDIUM] DataImportService.swift:51,127-130,178-196 — grouping and CSV parser
- Strong workouts grouped by the date string only; two sessions with the same timestamp merge. Hevy grouped by `title_start_time` (ok).
- parseCSV splits on newlines first (line 179), so quoted fields containing newlines (workout notes) break rows; doubled quotes `""` are dropped by the toggle (line 186); quoted header names with BOM (UTF-8 BOM before "Date" -> `firstIndex(of:"Date")` nil -> falls back to index 0 silently). Rows shorter than required are skipped silently; no error/skip count surfaced.
- No `modelContext.save()` (relies on autosave), no transaction: a throw mid-import is impossible here, but a crash mid-import leaves partial data.

[MEDIUM] DataImportService.swift (whole) — duplicate import not prevented
- Importing the same file twice doubles every workout (no external id/date+name check). Verified by reading; nothing checks existing Workouts.

[MEDIUM] PulsePump/Services/DataExportService.swift:37,76 — drafts exported
- Fetch has no `isDraft` predicate, so an in-progress draft is exported, while the UI count uses `!isDraft` (DataExportView.swift:8). Fix: add predicate.

[MEDIUM] DataExportService.swift:26-32,55-61,89 — export loses data and cannot round-trip
- ExportedSet omits `duration`, `distance`, `side`, and workout `template`/`isDeload`; plank/carry/cardio sets (stored in duration/distance) export as weight 0 reps 0. CSV also omits notes. CSV exercise name is wrapped in quotes but inner quotes are not escaped (line 89), breaking rows for names containing `"`. Duration truncated `Int(duration/60)`, calories truncated.
- Own CSV fed to `importStrongCSV`: header "Exercise" not found, so index fallback 2 -> "Set" column used as exercise name, weight index 4 -> "RIR". Garbage. No JSON importer exists. Dates are ISO8601 UTC, which the importers cannot parse (see above). Unlabelled weight unit (raw stored value).

[MEDIUM] PulsePump/App/PulsePumpApp.swift:25-45 — schema and migration risk
- No `VersionedSchema`/`SchemaMigrationPlan`; any non-lightweight schema change makes `ModelContainer(...)` throw and the app `fatalError`s at launch with no recovery (users with data can never open the app). Git status shows models (Challenge, FirestoreModels) modified on this branch: ensure only additive default-valued changes. Enum-typed stored properties (ChallengeMetric, SetType, etc.) will fail to decode if a case is ever removed/renamed.
- Fix: introduce a versioned schema now; on failure fall back to a backup/rename of the store instead of fatalError.

[MEDIUM] Models/Exercise.swift:21 — cascade delete of logs
- `@Relationship(deleteRule: .cascade) logs`: deleting an Exercise deletes every ExerciseLog (and sets) of it, silently removing history from past workouts. No UI deletes exercises today (grep of `.delete(` shows none), so latent. Should be `.nullify`. Related: seeded + custom exercises can share a name (ExerciseSeedService.swift:13 compares only against non-custom), so duplicate names appear in picker and import picks arbitrary first.

[LOW] Services/ExerciseSeedService.swift:8-21 — no explicit save, version-gated by UserDefaults
- Relies on autosave; if UserDefaults survives but the store is wiped (e.g. container reset) the catalog is never re-seeded (version key already 2). Inserts happen on three entry points (ContentView:90, ExerciseLibraryView:135, Demo) - harmless due to the guard. Better to gate on actual count/names.

[LOW] Services/TemplateSeedService.swift:9 + Views/Programs/TemplateListView.swift:50 — re-seeds after user deletes all
- `count > 0` guard only; a user who deletes every template gets all 7 back on next appearance. Also the demo service creates 3 templates first so on devices that ran demo the real starter set is never seeded. PPL `splitDays` rotation ["P","P","L","P","P","L"] is not Push/Pull/Legs (should be P,L,Lg...) - value looks wrong (unverified how it is consumed).

[LOW] Seed catalog tagging (ExerciseSeedService.swift)
- Verified programmatically: 242 exercises, 0 duplicate names, every name used by TemplateSeedService/Demo exists. Sane overall. Oddities: many entries list both `.shoulders` and a specific delt (`Overhead Press: [.shoulders,.frontDelts]`, `.back` + `.lats`/`.upperBack`) - per-group aggregation may double count if code sums per MuscleGroup (unverified, belongs to body-map audit). Jump Rope/Treadmill movementPattern `.carry`; "Conventional Deadlift" primary includes `.back`. CLAUDE.md "84 exercises" is stale.

[LOW] Models/Workout.swift / SetLog.swift — no model-level invariants
- `Workout.isDraft` defaults to true, so any `Workout()` created without setting it is hidden from every `!isDraft` query (e.g. injectTestData sets it explicitly). `SetLog.weight` has no unit/kg contract. Not a bug now.

## Verified OK
- StreakCalculator.swift:11-34: ran /scratchpad/sc.swift (TZ America/New_York). DST spring-forward Mar 7/8/9 -> 3 (expected 3); days 1&3 -> 3; two workouts same day -> 1; last workout 3 days ago still alive (1), 4 days ago -> 0; chain of 3-day gaps 1,4,7,10 -> 10; 4-day gap breaks -> 1; demo's 7 workouts every 2 days -> 13 (matches comment). Uses startOfDay + day components so DST-safe. Note by design a 3-day gap adds 3 "days". Future-dated workouts pass the guard (negative days) - harmless.
- Relationship wiring: User->Workout cascade/inverse, Workout->ExerciseLog cascade, ExerciseLog->SetLog cascade, WorkoutTemplate->Workout nullify (deleting a template keeps history, matches the UI copy at ContentView.swift:1278). Schema list in PulsePumpApp includes all 10 @Model types.
- Draft-vs-final: all history/analytics @Queries filter `!isDraft` (checked ~15 sites via grep).
- Exercise seed names unique; template and demo exercise names all resolve against the catalog; time/distance-based types set for Plank, Dead Hang, Jump Rope, Treadmill, carries.
- Demo templates (WorkoutDemoDataService 217-251) use real exercise IDs (unlike TemplateSeedService).
- Deep link `template` handling posts base64 data (PulsePumpApp.swift:87-92); nothing there crashes (Data optional-chained).

## Not verifiable
- Real Strong/Hevy CSV layouts (no sample files in repo; format claims above marked unverified/from memory).
- Whether anything consumes TemplateSeedService `splitDays` letters as designed.
- Actual SwiftData migration behaviour of the uncommitted model edits (did not run the app/xcodebuild per brief).
- Test coverage: grep of PulsePumpTests shows no tests for StreakCalculator, DataImport/Export, seed services, or ModelContainer; only EnumTests, FirestoreModelTests, CalorieEstimation, RestTimer, Tutorial, Widget tests exist. CLAUDE.md's StreakCalculatorTests example does not exist.
