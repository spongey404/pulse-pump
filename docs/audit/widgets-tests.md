# Audit: widgets-tests (OreShared/**, OreWidget/**, OreTests/**, OreUITests/**)

Read-only audit. Scratch experiments in `scratchpad/wt/` (compiled the real `OreWidgetSnapshot*.swift` + `OreWidgetCatalog.swift` and the real `StreakCalculator.swift` standalone with `swiftc`; no xcodebuild run). Nothing was compiled/run against the full app target, so test pass/fail statements below are by code reading unless marked "ran".

## Summary

- The fixed-widget data builder (`WidgetDataService+Fixed.swift`) is mostly careful and is the only widget code with tests, but three of its numbers are semantically wrong on real data: PR-watch compares an *estimated* 1RM against a *heaviest-weight* PR (so e1RM usually exceeds "PR", gap/percent are nonsense), Quick Start deep links send an upper-cased template name that the app matches case-sensitively (always starts a blank workout), and the home widgets show the design's SAMPLE data (with `isPlus = true`) whenever the user has no workouts.
- Custom-widget resolver `OreWidgetSnapshot.metric(for:)` silently falls back to the catalog's hard-coded demo values in several real-data paths (bodyweight line chart never uses real data, "program" progress squares always `3/8`, e1RM line with < 2 weeks of data, "next" piece with no prediction, unknown metric ids). Verified by running it.
- Widget content is a static snapshot written only when the app is foregrounded / a workout finishes; every relative/"today" field (today index, "N DAYS AGO", streak squares, friends "1H", nextDay) goes stale at midnight and the streak never expires while the app is closed.
- `Link` is used inside `systemSmall` widgets (Next-workout 1A START, Quick Start small, Locked preview "UNLOCK SUPERNOVA"). WidgetKit ignores `Link` in small widgets (documented; not device-verified), so those buttons just open the app.
- Charts are crash-safe (every `min()!`/`max()!`/`[0]` is guarded; verified by grep) but `WeeklyVolumeWidget` medium bars use a hard-coded `/30*84` scale and BodyHeat is drawn at non-0.625 aspect ratios (distorted).
- Tests: 8 Swift Testing/XCTest files. Widget tests (`WidgetFixedDataTests`, `WidgetBuilderGridTests`) are meaningful but encode the wrong PR semantic. `CalorieEstimationServiceTests.estimateUsesMetFormula` fails against current code. The entire 30-test UI suite is stale (looks for a `UITabBar` and nav-bar titles/strings that no longer exist). No tests exist for streak, prediction, PR detection, volume, plate calc, warm-ups, import/export, `buildSnapshot`, or the resolver.
- Cross-area CRITICALs seen while tracing the widget START path (owned by other audits, listed for completeness): `injectTestData()` is called unconditionally at the end of `startWorkout`, and `WorkoutDemoDataService.seedIfNeeded` runs unconditionally in `RootView`.

## Findings

### CRITICAL

**[CRITICAL] Ore/ViewModels/WorkoutViewModel.swift:81 — (cross-area) `startWorkout` always calls `injectTestData`**
`startWorkout(...)` ends with `injectTestData(modelContext: modelContext)` (no `#if DEBUG`; the only `#if DEBUG` in the file is lines 526-531). That function sets `exerciseEntries = []`, fills 10 pre-completed fake exercises, inserts fake historical `Workout/ExerciseLog/SetLog` rows into SwiftData and backdates `startTime` by 78 min (lines 85-143). Every start path, including the widget deep links (`ContentView.swift:62-68`), therefore starts a fake workout and pollutes history that the widgets then summarise. Expected: empty/template-only session. Fix: delete the call or wrap in `#if DEBUG` behind a launch flag.

**[CRITICAL] Ore/Views/RootView.swift:22-24 + Ore/Services/WorkoutDemoDataService.swift:7-39 — (cross-area) demo user + ~13-day-streak workouts seeded in production**
`.task { WorkoutDemoDataService.seedIfNeeded(...) }` runs unconditionally; guard is only a UserDefaults flag. On a fresh install it inserts user "Jordan" (so `users.isEmpty` becomes false and onboarding is skipped) and demo workouts. Widgets then read this as real data (`hasData == true`, streak 13). Fix: `#if DEBUG` / launch-arg gate.

### HIGH

**[HIGH] OreWidget/FixedWidgets.swift:47-50 — widgets show design SAMPLE data (and `isPlus = true`) when user has no workouts**
```swift
let s = OreWidgetStore.loadSnapshot()
return s.hasData ? s : OreWidgetSnapshot.sample     // widget gallery / first run shows the design's sample
```
`timeline()` of both providers (lines 59, 69) uses `currentSnapshot()`, so a real user with zero workouts (or after deleting all workouts, or when the stored snapshot fails to decode, see MEDIUM below) sees streak 12, "PUSH DAY", Bench PR 100, friends Maya/Jonah/Riya as if real. `sample.fixed.isPlus = true` (`OreWidgetSnapshot+Fixed.swift:148`) means the Plus gate is also bypassed: a free user with no workouts sees Body map / Balance / PR watch / Deload fully unlocked. The real `isPlus` written by `setSubscribed` / `buildFixed` is discarded. Fix: use sample only for `placeholder`/`isPreview`; for real timelines render an empty state, and always overlay the real `fixed.isPlus` on the sample.

**[HIGH] Ore/Services/WidgetDataService+Fixed.swift:181-196,402-411 + OreShared/Widgets/PRWatchWidget.swift:29,78,125 — PR watch compares e1RM (Epley estimate) with heaviest-weight PR**
`pr = sets.map(\.weight).max()` but `e1rm = max(weight*(1+reps/30))` over the last 4 weeks. Any multi-rep set puts e1RM above "PR". Ran: PR 100x1, recent 90x8 -> e1rm 114.0; recent 100x5 -> e1rm 116.7, 6B percent "117%", large "16.7 KG TO PR", gap `String(format:"-%.1f", abs(pr-e1rm))` shows "-16.7" even though the lift is *above* its PR. `selectPRLifts.gap = (pr-cur)/pr` is negative so every such lift passes the "within 5%" filter and sorts first. The design numbers (e1RM 98.5 < PR 100) only make sense if PR is also e1RM-based. The unit test `prLiftsFromHistory` (WidgetFixedDataTests.swift:176-187) asserts `pr == 100, e1rm == 105`, i.e. locks in the incoherent state. Fix: PR = best all-time e1RM (or compare 4-week best *weight* with PR weight); drop `abs` and show nothing/"NEW PR" when e1rm >= pr.

**[HIGH] OreShared/Widgets/QuickStartWidget.swift:48 + Ore/ContentView.swift:62-68 + WidgetDataService+Fixed.swift:343-345 — Quick Start tiles always start a blank workout**
Writer stores `name: $0.name.uppercased()` ("PUSH DAY"); widget link is `pulsepump://start-workout?template=PUSH%20DAY` (ran `startURL`); app handler does `templates.first(where: { $0.name == name })` (case-sensitive) and otherwise `startBlankWorkout()`. For any template not already named in capitals, the tile starts an empty workout. Same risk for Next-workout START (`snap.nextName`, raw case, OK only if prediction casing equals template name; prediction fallbacks "Pull Day"/"Leg Day"/"Push Day" are literals - `WorkoutViewModel.swift:690-694`). Fix: case-insensitive match in `ContentView`, or carry template id in the link.

**[HIGH] OreShared/Widgets/NextWorkoutWidget.swift:50, QuickStartWidget.swift:17-19, LockedPreviewWidget.swift:53-58 — `Link` inside `systemSmall` widgets**
WidgetKit only supports `widgetURL` in small widgets; `Link` is ignored (Apple docs; not verified on device). Affected: Next-workout 1A small START, Quick Start small (both tiles), Locked preview small "UNLOCK SUPERNOVA" (so the "tap opens Supernova" promise in the blurb fails for the small variant), Next 1B small "tap-anywhere" (blurb claims it, but there is no `widgetURL`/Link at all - only 1A has a Link). `CustomWidget.swift:69-70` handles this correctly (`interactive: family != .systemSmall` + `widgetURL`); the fixed widgets don't. Fix: in `PWWidgetView` wrap small families with `.widgetURL(...)` per widget.

**[HIGH] OreShared/OreWidgetSnapshot.swift:94-98 — custom "Line chart" bodyweight never uses real data; e1RM falls back to sample**
```swift
let name = piece.metric == "e1rm_squat" ? "Squat" : "Bench Press"
if piece.metric != "bw", let series = e1rm[name], series.count > 1 { m.data = series; m.v = ... }
```
Ran with `hasData = true`, `fixed.bodyweightSeries = [90,89,88]`, `bodyweight = 88`: `spark/bw` still returns the catalog sample (v=82.4, 26 demo points). `bodyweightSeries` is never read by the resolver. Also with 0 or 1 e1RM points the piece silently draws the demo Bench line (98.5 KG, 12 points) as if it were the user's. Fix: for `bw` use `fixed.bodyweightSeries`/`bodyweight`; when data is insufficient blank the piece (`data = []`, `v = "—"`).

**[HIGH] OreShared/OreWidgetSnapshot.swift:112-117 — custom "Progress squares: Program weeks" always shows demo `3/8`**
`.prog` only handles `goal`; `program` keeps the sample (`PPL · WEEK`, `3/8`, n=8, done=2, cur=2) for every real user. Ran: returns `k=PPL · WEEK v=3/8 n=8 done=2`. `fixed.programWeek/programWeeks` exist but are not used. Fix: fill from `fixed.programWeek/programWeeks`.

**[HIGH] OreShared/Widgets/RecapWidget.swift:26 — hard-coded "ROW" label on small recap**
`if family == .small { Text("ROW").pwCap(...) }` — whatever lift set the PR (`recapPRName` = Squat, Bench...), the small widget says ROW. Fix: `Text(f.recapPRName.uppercased())` with truncation.

**[HIGH] (units) OreShared/** widgets hard-code "KG"; `WorkoutActivityAttributes.ContentState.weightUnit` is never set — lbs users get mislabeled numbers**
Widgets print "KG" literally (`PRWatchWidget.swift:52,80`, `BodyweightWidget.swift:23`, `OreWidgetCatalog` units, `LockScreenWidgets.swift:113`). The app stores weights as typed in the user's unit (`OnboardingViewModel.swift:~113` `Double(weightText)`, `EditProfileView.swift:65`; the only conversion in the codebase is `ProfileView.swift:246` which wrongly treats `user.weight` as kg) and `grep weightUnit Ore/` returns nothing, so the Live Activity always shows "KG" (`LiveActivityViews.swift:237,287`). `BodyweightLog.record(kg:)` and `buildSnapshot.bodyweight` log the raw lbs number as "kg". Fix: store canonical kg and convert at display, or write the user's unit into the snapshot / `weightUnit`.

### MEDIUM

**[MEDIUM] Ore/Services/WidgetDataService.swift:15-40 + WidgetDataService+Fixed.swift:66-110 — snapshot is static; "today"-relative fields go stale**
Written only on app foreground (`RootView.swift:20,24`), workout finish (`WorkoutViewModel.swift:491`), builder save, Plus change, friends refresh. Providers emit one entry and refresh every 30 min (`FixedWidgets.swift:51`, `CustomWidget.swift:58`) but only re-read the stored snapshot. Stale after midnight / week rollover / without opening the app: `todayIndex` (accent bar), `weekSetsPerDay` / `weekDone` (Monday doesn't clear), `streakLogged`/`streakLetters`, `lastWorkoutDaysAgo`, `recentSessions` "N DAYS AGO", `nextDay`, `nextDate`, `goalLeftLine`, friends `ago` ("1H" forever, `WidgetDataService+Fixed.swift:550`), and `snap.streak` never hits the 3-day expiry (`StreakCalculator` runs only at write time). Only the custom `PR` piece computes `ago()` at render time (`OreWidgetSnapshot.swift:54`). Fix: build a multi-entry timeline (midnight entry) and store dates instead of strings; recompute relative text in the extension.

**[MEDIUM] OreShared/Widgets/WeeklyVolumeWidget.swift:110,113 — bar height uses fixed `/30 * 84`**
`max(v.lastWeek / 30 * 84, 3)` / `max(v.thisWeek / 30 * 84, 3)`: a 40-set day draws 112pt in an 84pt box (overflows into the legend/header), a 6-set day is a stub. Should scale to `max(thisWeek+lastWeek)` like `PWWeekBars` does.

**[MEDIUM] OreShared/Widgets/BodyMapWidget.swift:49,74,89,135 — BodyHeat drawn at wrong aspect ratio**
`BodyHeat` is a 200x320 viewBox (0.625) and scales x/y independently (`BodyHeat.swift:50-51`; its doc says "Always give this an explicit width/height matching 0.625"). Frames used: 64x142 (0.45), 72x118 (0.61), 84x142 (0.59), 140x320 (0.44) in the large widget: silhouette is squeezed ~30%. `OreWidgetCanvas.bodyMap` correctly uses 0.625. Fix: derive width = height*0.625.

**[MEDIUM] Ore/Services/WidgetDataService.swift:139-159 — custom body-map volume counts warm-ups and double counts regions**
`sets7[r] += Double(log.sets.count)` includes warm-up sets (everything else in this file uses `workingSets`), and loops `ex.primaryMuscleGroups` mapping `.shoulders`, `.frontDelts`, `.sideDelts` -> "shoulders" and `.abs`, `.obliques` -> "core" without de-duplicating (the Fixed builder does `Set(...)`, line 139). An exercise listing both gets 2x. Result: 7-day "volume" can hit the 1.0 cap early. `bodyRecency` is a 48h fade only (line 156) while the picker calls it "Days since trained" (`OreWidgetCatalog.swift:141`, `FixedWidgets.swift:22`), so anything trained >2 days ago is blank on the "Recency" map. Back/lats/triceps/hamstrings have no region (BodyHeat is front-only), so a pull/leg-only week renders an empty body.

**[MEDIUM] Ore/Services/WidgetDataService.swift:117-120 vs WidgetDataService+Fixed.swift:413-427 — two different "big lift" classifiers and two e1RM formulas**
Custom snapshot: `bench` excluding only "incline" (so Dumbbell/Decline/Close-grip/Smith bench count), `squat` excluding only "split" (Hack/Goblet/Front/Overhead squats count); `est = w*(1+reps/30)` even for 1 rep (103.3 for 100x1). Fixed builder: strict `bigLift()` with exclusions and `reps <= 1 ? weight`. The same lift shows different e1RM in custom vs fixed widgets. Also `snap.e1rm` keys are hard-wired "Bench Press"/"Squat" so `spark` can only ever show those two.

**[MEDIUM] Ore/Services/WidgetDataService.swift:166-167 — `nextDay` is today's weekday, not the day of the next workout**
`df.dateFormat = "EEE"; snap.nextDay = df.string(from: now)` (also non-POSIX locale). `buildFixed` correctly bumps to tomorrow if trained today (`+Fixed.swift:300-301`) but small widgets / lock rect / inline use `nextDay` -> "NEXT · FRI" right after finishing Friday's session while `nextDate` says "SAT 10 OCT". `nextEstMinutes = max(10, sets*3)` is a flat 3 min/set heuristic, not history (line 171).

**[MEDIUM] OreShared/OreWidgetCatalog.swift:221-225,232-236 + OreWidgetSnapshot.swift:9-47 — any schema change wipes widget data silently**
`OreWidgetSnapshot`/`PWFixedData` are synthesized `Codable` with non-optional stored properties (defaults don't help decoding). Ran: decoding a snapshot JSON missing one key -> throws -> `loadSnapshot()` returns an empty `OreWidgetSnapshot()` (hasData false) -> widgets show SAMPLE data (see HIGH above) until the app is next opened. Same for `loadLibrary()` (`try?` -> `[]`; a new `OrePieceType` case written by a newer build kills the whole library). Fix: custom `init(from:)` with `decodeIfPresent`, or version field.

**[MEDIUM] OreWidget/FixedWidgets.swift:182,197,211,... — Plus gate gaps and no-op "Layout" option**
(a) `PRWatchDesc` renders `LockRectPR` for `.accessoryRectangular` without `PWPlusGate` (line 241) so the Plus PR-watch widget is free on the lock screen. (b) Custom widgets (`CustomWidget.swift`, builder pieces `.body`, `.pr`, `.spark`) are not gated at all although `SupernovaFeature.additionalWidgets` exists (product intent unverified). (c) Every fixed widget uses `PWVariantIntent` (Layout A/B in "Edit Widget") but Recap, Program, Goal, Bodyweight, Friends, Quick start, Pulse ignore `variant` (`RecapWidget.swift:18`, etc.), Balance/Deload/WeeklyVolume medium/large also ignore it - dead setting. (d) `setSubscribed`/`isInFreeTrial` are only re-evaluated when the app runs: an expired trial keeps Plus widgets unlocked until next app open.

**[MEDIUM] Ore/ContentView.swift:62-68 — widget START has no active-workout guard; cold-launch delivery unverified**
`startWorkoutFromWidget` unconditionally calls `startWorkout` -> second draft `Workout` inserted and `exerciseEntries` of the running session replaced/merged (`WorkoutViewModel.swift:46-81`; no `isActive` guard). The URL is converted to `NotificationCenter.post` in `OreApp.handleDeepLink`, and the only subscribers are `.onReceive`s inside `ContentView`: on a cold launch from a widget tap the post can happen before `ContentView` exists (unverified, needs device) and the start / "supernova" intent would be dropped. Also the "supernova" route needs `MoreRouter` (`MoreTabView.swift:43-57`) - fine when warm.

**[MEDIUM] Ore/Services/LiveActivityService.swift:38-40 + WorkoutViewModel.swift:~757 — Live Activity update dedupe is defeated, pushes every second**
`guard state != lastState` compares `ContentState` including `elapsedSeconds` and `restSecondsRemaining`, which change every tick; the 1 s duration timer (`WorkoutViewModel.swift:~708-716`) pushes each time. Neither field is read by any view (grep of `OreShared`/`OreWidget`: only the attributes file), the views use `startTime`/`restEndDate` timers. Result: ~3600 `activity.update` calls/hour (ActivityKit throttles/drops and drains battery). Fix: exclude those two fields from equality (or stop sending them).

**[MEDIUM] OreShared/Widgets/LockScreenWidgets.swift:56,132 — lock-screen accessory views use fixed gallery sizes**
`LockRectFrame` is a hard `172x76`, circular is `72x72`, inline is `.frame(height: 76)`. Real accessory sizes differ per device (e.g. 160x72 on small phones); content is clipped/overflows, and an inline accessory is a single text line (custom fonts/frames there are unverified). Prefer flexible frames.

**[MEDIUM] Ore/Services/WidgetDataService.swift:23-27,30-35 — legacy streak widget keys never cleared**
`widget_lastWorkoutName/Date/exerciseCount/durationMinutes` are written only `if let last = workouts.first`. If the user deletes all workouts the keys keep the old values (streak resets to 0 but "last workout" persists). Also the legacy `OreWidget` (orange flame, `.orange` colours) still ships next to the new Streak widget (redundant, off-design).

**[MEDIUM] Ore/Services/WidgetDataService.swift:7-100 — heavy main-actor rebuild on every foreground**
`updateWidgetData` fetches all non-draft workouts with relationships and builds both the custom snapshot and `buildFixed` (many full passes: `flat.filter` per big lift, `improvements()` rescans history per week-workout with `topWeights` recomputed) on the main actor at every `scenePhase == .active` plus in `.task`. Cost scales with history; magnitude unverified (no profiling run).

### LOW

- **[LOW] OreShared/Widgets/PRWatchWidget.swift:13-18 — "PR line" is not the PR.** `PWPRSpark` draws the dashed line at `y = 2` = top of the plotted range (max of the 12-week series), not at the PR value; it is correct only when the series max equals the PR.
- **[LOW] OreShared/Widgets/PWKit.swift:213-216 — `signedPct`/`trimmed`.** `signedPct(-0.0)` -> "+-0.0%" (ran), `signedPct(-0.04)` -> "-0.0%"; `trimmed`/`fmt` call `Int(v)` (traps on +/-inf; not reachable from current writers). Steady-state sets-delta shows "▲ +0.0%" when last week has no sets (`pctDelta` returns 0 for `before == 0`, `WeeklyVolumeWidget.swift:15`).
- **[LOW] OreShared/OreWidgetSnapshot.swift:133-141 — `shortCaption` truncates mid-word** ("BENCH PRES PR", ran). `goal` piece shows "x/0" when `sessionGoal == 0` while drawing 1 square (line 114-115).
- **[LOW] OreShared/Widgets/StreakWidget.swift:88 + RecapWidget.swift:11 — "1 DAYS AGO"/"0 DAYS AGO" grammar** (Recap handles 1, Streak medium does not; neither says "TODAY").
- **[LOW] Long names:** `RecapWidget.swift:72` (`lastWorkoutName`) and `ProgramWidget.swift:67` (`programName`) have no `lineLimit`; `NextWorkoutWidget.swift:94` shows "+0 MORE" when <=4 exercises.
- **[LOW] Ore/Services/WidgetDataService+Fixed.swift:294 — `goalLeftLine` "N DAYS" = 6 - todayIdx** ("0 DAYS" on Sunday; does not count today).
- **[LOW] OreShared/Widgets/LiveActivityViews.swift:366 — no-op `replacingOccurrences(of: "×", with: "×")`.**
- **[LOW] OreShared/Widgets/LockScreenWidgets.swift:39 — `LockCircularGoal` draws `sessionGoal` squares at 5pt+2 spacing**; goals >= 10 overflow the 72pt circle.
- **[LOW] Ore/Views/More/Widgets/WidgetsView.swift:127-130,38-40 — deleting the last custom widget re-seeds presets on next open; delete doesn't call `reloadAllTimelines`.** `WidgetBuilderGrid.occupancy` (`WidgetBuilderGrid.swift:14`) would trap on a persisted piece with `y > rows` (range `p.y..<min(...)`); unreachable through the builder (size changes call `tidy`), only with corrupt App Group data.
- **[LOW] OreWidget/OreWidget.xcodeproj settings:** `ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground` and `...GLOBAL_ACCENT_COLOR_NAME = AccentColor` (pbxproj 668-669, 698-699) name colorsets that don't exist in `OreWidget/Assets.xcassets` (build warning only; real background is set in code).
- **[LOW] CLAUDE.md is stale:** says `WorkoutActivityAttributes` is duplicated in app and widget (now single file `OreShared/WorkoutActivityAttributes.swift`), and lists `-only-testing:OreTests/StreakCalculatorTests`, which does not exist.
- **[LOW] Ore/Utilities/StreakCalculator.swift:20-26 — future-dated workouts accepted** (ran: dates [+2d, today] -> streak 3; `daysSinceLast` is negative so the `<= 3` guard passes).

## Tests: what each file really asserts

### Unit tests (OreTests)
| File | Assertions | Verdict |
|---|---|---|
| `OreTests.swift` | empty `example()` | Tautological, delete. |
| `CalorieEstimationServiceTests` (11 tests) | basic formula constants (10/6/8 per set), MET maths (`5.0*80*1.0`), dispatcher, fallbacks | **Stale/failing:** `estimateUsesMetFormula` (lines 66-73) expects 400 but `estimate(...)` only uses MET when `isSubscribed == true` (`CalorieEstimationService.swift:54-58`, default false) -> returns 80. `estimateMetFallsBackToBasicWhenZeroWeight/Duration` pass for the wrong reason (free-user fallback fires first). Related app bug: `WorkoutViewModel.swift:413` and `:252` never pass `isSubscribed`, so the Supernova MET formula is unreachable in the app. |
| `EnumTests` (~13) | `isCompound`, `bodyRegion` mapping, `SplitType.daysPerWeek`, MET values, `displayName` non-empty loops | Valid vs current enums (cross-checked), but mostly "not empty" smoke checks. |
| `RestTimerServiceTests` (8) | default 180/90, `formattedTime`, `progress`, `stop()` | Valid; `restDurationForCompound` reads `UserDefaults.standard` ("compoundRestSeconds") so it depends on device state. No test of `start/tick/adjust/skip/completedAt`; timer is tick-based, not wall-clock (background drift unverified). |
| `TutorialViewModelTests` (12) | step order/phase/CTA, 10 steps, finish/skip/restart | Updated to the 10-step flow in the working tree; valid. Tests UI-state only. |
| `FirestoreModelTests` (7) | Codable round-trips of `FirestoreUserProfile`, `WorkoutFeedItem`, `FeedComment`, `FriendshipDoc`, export DTOs | Valid but only serialization; no Firestore service/rules coverage. `exportDTOsCodableRoundtrip` doesn't touch `DataExportService`. |
| `WidgetBuilderGridTests` (9) | grid `fit/tidy/best`, presets fit their size, `bestPR(for:)` variant lookup | Good. Doesn't test `OreGrid` frame math, `metric(for:)`, `OreWidgetStore`, or out-of-range pieces. |
| `WidgetFixedDataTests` (11) | weekly sets vs last week same-day, warm-ups skipped, balance rows, deload detection, PR lifts, `bigLift`, bodyweight log, friend formatting | Best-quality tests in the repo (in-memory SwiftData, injected `now`/UserDefaults). Gaps: no streak strip, recap/PR set, program/quick-start, next-workout list, confidence, tonnes delta; `prLiftsFromHistory` and `prWatchSortsByGapAndFilters` encode the e1RM>PR problem (HIGH finding). `bodyweightSeriesAndDelta` uses `Calendar.current` vs iso8601 elsewhere (timezone-consistent today). |

### UI tests (OreUITests/OreUITests.swift, 30 tests + 1 launch test)
Entire suite is stale against the current UI:
- Uses `app.tabBars.buttons[...]` (lines 25-44, 65, 311, 520...). `ContentView.swift:49` hides the system tab bar and uses `CustomTabBar` (an `HStack` of `Button`s with labels "Programs/Social/Home/Body/More", text upper-cased, no accessibility ids). `tapTab` fails at the first `XCTAssertTrue(tab.waitForExistence)` so every test using it fails; "Body Map" is now "Body".
- Looks for navigation bars "Home", "Programs", "Social", "Workout", "Customize Home", "Choose a Program" and strings "Start New Workout", "Discard and Start New", "Resume Workout", "Save as Draft", "Discard Workout", "Blank template", "No programs yet", "No Activity", "Finish", "Cancel": none of these strings exist in `Ore/` (grep, case-insensitive); the logger now says "FINISH WORKOUT", "ADD EXERCISE", etc., and the only `navigationTitle`s are sub-screens (e.g. "Templates", "Exercises", "Plate Calculator").
- Tautological/vacuous: `test15_SocialFeed` asserts `noActivity || hasItems || true` (line 502); tests 04, 11, 12, 13, 14, 16-19, 22, 29 wrap everything in `if x.waitForExistence {...}` with no `else` assertion, so they pass without testing anything once the first call doesn't crash; `test08/09` have no assertion about the result of finishing/cancelling a workout. `test06/07/08/09/27/29` chain via `try test05_...()` (order coupling, shared state).
- No launch arguments / test fixtures: tests depend on a signed-in Firebase session (comment "Firebase Auth to restore session") and on whatever state the demo seed leaves behind; Social tests hit the network. `OreUITestsLaunchTests.testLaunch` only screenshots.

## Coverage map: important logic with NO test

| Area | Where | Test status |
|---|---|---|
| Streak (gap-based, 3-day expiry) | `Utilities/StreakCalculator.swift` | None (CLAUDE.md names a non-existent `StreakCalculatorTests`). Ran ad-hoc: today only=1, 3d ago=1, 4d ago=0, every-2-days x7=13, same-day x3=1, future date=3. |
| Next-workout prediction | `WorkoutViewModel.predictNextWorkout/detectNextByPattern` (`:613-662`), `WidgetDataService.predictionConfidence`, `programCycle`, `detectedSplitName` | None (no-history fallback sorts `dayOfWeek` Sun-first at `:621`, while `programCycle` sorts Monday-first). |
| PR detection (weight PR, rep PR) | `WorkoutViewModel.swift:~560-607` | None. |
| Volume / sets / e1RM / improvement score | `WorkoutViewModel` completion, `WidgetDataService.improvements`, `FSet.e1rm` | None for completion; `FSet.e1rm` only via PR widget test. |
| Calories (app path) | `WorkoutViewModel.swift:252,413` | Unit-tested in isolation only; the integration bug (never subscribed) is undetected. |
| Custom-widget snapshot builder | `WidgetDataService.buildSnapshot` (streak, sessionsThisWeek, setsPerDay, volumePerDay, improvements, prs, e1rm series, bodyVolume/Recency, next, templates) | None. |
| Snapshot resolver | `OreWidgetSnapshot.metric(for:)`, `bestPR`, `ago` | Only `bestPR` (1 test). |
| Fixed builder gaps | streak strip, recent sessions, volume tonnes/hours deltas, muscle rows/neglected, recap + PR set, program/goal, next exercise list, quick starts, eco rows, `writeFriends/setSubscribed` patching | Not covered. |
| Widget canvas / PWKit math | `OreGrid.frame`, `OrePieceView` scaling, `PWSpark`, `PWWeekBars`, `BodyHeat` thermal | None (I verified `OreGrid` identities by script: `cols*uw + 2*pad == width` and `rows*uh + 2*pad == height` for all four sizes). |
| Deep links | `handleDeepLink` (`start-workout`, `supernova`, `template`) | None. |
| Plate calculator | `PlateCalculatorView.calculatePlates` (private func inside a View, `:114`) | None, and untestable until extracted. |
| Warm-up generator | `WarmupGeneratorView.swift` (logic inline in the View) | None. |
| Import / export | `DataImportService.importStrongCSV/importHevyCSV/parseCSV`, `DataExportService.exportWorkouts/generateCSV` | None (only DTO Codable round-trip). CSV parser edge cases (quoted commas, CRLF, unit conversion) untested. |
| Seeds | `ExerciseSeedService` (84 exercises), `TemplateSeedService` | None. |
| Social | `SocialViewModel` (feed cache TTL), `FirestoreService`, challenge scoring/leaderboard | None. |
| Billing | `SupernovaService` (entitlement, trial window, `isInFreeTrial` side-effect of writing install date) | None. |
| Onboarding / User model | `OnboardingViewModel.completeOnboarding`, unit handling | None. |
| Live Activity | `LiveActivityService` dedupe, `makeLiveActivityState`, intents | None. |
| Draft recovery / `StartWorkoutDock` | `Workout.isDraft` crash persistence | None. |

## App Group contract (`group.com.pulse.PulsePump`; entitlement present in `Ore.entitlements:13` and `OreWidget.entitlements:7`)

| Key | Type | Writer | Reader | Notes |
|---|---|---|---|---|
| `widget_streak` | Int | `WidgetDataService.swift:19` | legacy `OreWidget.swift:51` | not recomputed by widget (no expiry) |
| `widget_lastWorkoutName` / `widget_lastWorkoutDate` / `widget_exerciseCount` / `widget_durationMinutes` | String / Date / Int / Int | `WidgetDataService.swift:23-26` (only if a last workout exists) | legacy `:52-55` | never cleared |
| `widget_recentWorkouts` | JSON `[WidgetWorkoutDTO]` (name?, date, exercises) | `:30-35` | legacy `[WidgetWorkoutData]` same shape (`OreWidget.swift:59,79`) | shapes match, default Date coding both sides |
| `widget_snapshot` | JSON `OreWidgetSnapshot` | `OreWidgetStore.saveSnapshot` via `updateWidgetData` (`:38`) and `patchStoredSnapshot` (`+Fixed.swift:555-559`) | extension `loadSnapshot()` (`FixedWidgets.swift:48`, `CustomWidget.swift:47`) | strict Codable (see MEDIUM) |
| `custom_widget_library` | JSON `[OreCustomWidget]` | `WidgetsView.swift:40,129`, `WidgetBuilderView.swift:490` | extension `CustomWidgetQuery` + provider (`CustomWidget.swift:20,45`) | seeded with presets on first open of Widgets screen; before that the Custom widget shows "Build a widget" |
| `widget_isPlusSubscribed` | Bool | `setSubscribed` (`+Fixed.swift:515-520`), from `SupernovaService.refreshSubscriptionStatus` (`:126`) | `currentIsPlus` (app only); extension gets it through `fixed.isPlus` | trial OR flag |
| `widget_friends` | JSON `[PWFriendSession]` | `writeFriends` (`+Fixed.swift:523-529`, called from `SocialViewModel.swift:268`) | `buildFixed` (`:334`) and patched into snapshot | `ago` strings frozen at write time |
| `widget_bodyweight_log` | JSON `[BodyweightLog.Entry]` | `BodyweightLog.record` (onboarding, EditProfile, every `buildFixed`) | `BodyweightLog.summary` (app) | logs profile weight only (no weigh-in feature) |
| `pulse_eco_fuel`, `pulse_eco_stride` | JSON `PWEcoRow` | **no writer in this repo** (Fuel/Stride apps) | `buildFixed` eco rows (`:350-356`) | Pulse widget shows "—" for FUEL/STRIDE until those apps exist |

Deep links emitted by widgets and their handling in `OreApp.handleDeepLink` (`:78-95`): `pulsepump://start-workout[?template=]` handled (name match is case-sensitive, see HIGH); `pulsepump://supernova` handled (-> `MoreRouter.pendingSupernova`, tab 4); `pulsepump://home` (legacy widget) falls into `default: break` (just opens the app); `pulsepump://template?data=` handled (outside widget scope).

## Verified OK

- Crash safety of widget layouts: grep for `.first!`, `.last!`, `[0]`, `min()!`, `max()!`, `try!`, `as!` over `OreShared/**` and `OreWidget/**` -> every hit is guarded (`OreWidgetCanvas.swift:249` and `PWKit.swift:199` behind `count > 1`; `OreWidgetSnapshot.swift:62` `metrics[0]` safe since all 8 `OrePieceType` have non-empty metric lists; `OrePieceType.info` force unwrap covers all cases; `DeloadWidget.headline[0]` is a 2-element literal; `LockInlineNext` checks `parts.count >= 2`). Empty `snap.fixed` arrays just render nothing (e.g. `BalanceWidget.smallA` empty, `PWWeekBars` empty).
- Single-point and flat series: `PWSpark`/`OrePieceView.line` draw nothing for count 1 and a flat baseline for all-equal values (range floored at 0.0001). `bars` floor `mx` at 0.0001 and draw 2pt stubs for zeros. Division by zero guarded in `setsDeltaPct`, `pctDelta`, `PWPRSpark`, `PWSplitBar` clamp, `progress` (`max(n,1)`), `Deload.maxLoad`, `LockRectPR` (filters `pr > 0`); `PRWatchWidget` 6B `e1rm/pr` is safe because the writer only emits lifts with `pr > 0` (`+Fixed.swift:179-181`).
- `OreGrid` math: ran for all four sizes, cell size x cols + 2 x pad equals the design width/height exactly (small 33.5x33.5, medium 39.25x33.5, large 39.25x41.25, lock 38x32).
- `OreWidgetCatalog.sizes(for:in:first:)` + `WidgetBuilderGrid.fit/tidy/best` logic, and that all four presets fit their own size (test + read).
- Resolver correct paths (ran): `num` streak/sessions/improved/topgain/bw; `pr` exact + variant matching with exclusion list; `bars` data/today; `quick` template meta; `prog/goal`; negative top-gain prints "-2.5"; "N D AGO"/"NW AGO" threshold at 14 days.
- Widget extension resources: `OreWidgetInfo.plist` (root, outside the synchronized group) declares all 7 `UIAppFonts` and `NSExtension`; the 7 `.ttf` files exist in `OreWidget/Fonts/`; the 9 colorsets in `OreWidget/Assets.xcassets` are byte-identical to the app's (`cmp`); PostScript font names in `WidgetSupport.swift` mirror the app's; `OreShared` is a synchronized group member of both app and extension targets (pbxproj 181-184, 255-258); `WorkoutActivityAttributes` is a single shared definition (CLAUDE.md is stale); App Group id identical in 3 places.
- Live Activity wiring: intents post notifications that `WorkoutViewModel.installLiveActivityObservers` (installed in `startWorkout`, removed in `stopDurationTimer`) consumes; rest bar uses `ProgressView(timerInterval:)`; stale handling flips to rest-over via `staleDate = restEndDate` (`LiveActivityService.swift:42`, `LiveActivityViews.swift:76`).
- `WidgetDataService+Fixed` maths I re-derived: week bucketing (iso8601, Monday start, `todayIdx` clamp), last-week same-weekday cutoff, `pctDelta` rounding, deload detection incl. current-week exemption, load-ratio window alignment, balance row ratio/flag/share (matches the design example 48:34 -> "1.41", "▼ PULL -14 SETS"), `friendSessions` ago/initials; warm-ups excluded consistently in the Fixed builder (`fsets`) and in `workingSets`.
- Plus gating for the four Plus home widgets goes through `PWPlusGate` -> `snap.fixed.isPlus` (modulo the sample/lock-screen holes above); `supernova` deep link target exists.

## Not verifiable

- Anything requiring a device/simulator: whether `Link` in `systemSmall` is truly inert on the current iOS, cold-launch delivery of the `NotificationCenter` post from `onOpenURL`, accessory inline/rectangular real sizes, Live Activity throttling, widget timeline refresh budget, font registration at runtime in the extension.
- Whether the test targets currently compile and which tests pass: I did not run `xcodebuild` (per brief). Pass/fail statements are from reading code; initializer signatures used by `WidgetFixedDataTests` (`Workout(date:duration:isDraft:isDeload:)`, `Exercise(...)`, `FeedExercise`, `FeedSetLog`) were only spot-checked.
- Rebuild performance of `updateWidgetData` for large histories (no profiling).
- Product intent for Plus-gating of custom widgets and for the "sample on first run" behaviour (the comment says it is deliberate).
