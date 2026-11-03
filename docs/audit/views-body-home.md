# Audit: views-body-home
Scope: Views/BodyMap/**, Views/Home/**, ContentView.swift. Read-only; scratch scripts in scratchpad/bodyhome (t.swift, u.swift).

## Summary
- Body tab v3 (BodyMapTabView + BodyMap2DView) is wired to real SwiftData (@Query ExerciseLog/Workout, drafts excluded), and the front/back maps cover all 17 tracked groups. Several core numbers are still wrong: generic `.shoulders`/`.back` fold into one specific group, which gives wrong and double-counted set totals (seeded exercises hit this).
- The Home RECENT "n/10" IMPR values and "0%" VOL values trace to `WorkoutViewModel.startWorkout` calling `injectTestData` unconditionally. Every workout start fabricates 10 exercises and up to 10 fake history workouts. The "0%" is also a truncation artefact (see H-2 / M-9).
- Demo "friends trained today" banner (Marcus/Priya/Jake) shows to any user with no friends, no network or no auth. The banner button is a no-op. The prediction "HIGH CONF" dots are hardcoded.
- Home "this week" uses the locale week start (Sunday in en_US), but the Body tab and `weekDayBars` assume Monday. The two tabs disagree on weekly sets.
- Dead code: AnalyticsView, MuscleBalanceView/BalanceBar, QuickAnalyticsView, RecentWorkoutsWidget, BodyModelView, Body3DSceneView (+ FinalBaseMesh.obj), HeatmapColorScheme/HeatmapLegend, ProgramDayPickerSheet, ProfileMenuSheet, programsTickerItems. None is referenced.
- No unit tests cover any of this (tests: Calorie, Enum, Firestore, RestTimer, Tutorial, Widget*; OreTests is the empty template; StreakCalculator is untested).
- Warm-up sets are counted as sets and volume everywhere.

## Findings

### CRITICAL
[CRITICAL] Ore/ViewModels/WorkoutViewModel.swift:81 (called from ContentView startFromTemplate/startBlankWorkout/StartWorkoutDock) — `injectTestData` runs on every workout start (not `#if DEBUG`; also in HEAD)
- `startWorkout` ends with `injectTestData(modelContext: modelContext)`. That function (line ~85) does `exerciseEntries = []`, replaces the template's exercises with 10 hardcoded exercises ("Barbell Bench Press"…"Pec Deck") with pre-completed sets, and backdates `startTime` by 78 min.
- For each of those exercises it inserts a fake historical `Workout` (`date = now - 7d`, `isDraft = false`, user attached, `modelContext.insert`) with a fake ExerciseLog and SetLog. Up to 10 fake non-draft workouts are persisted per start.
- Scenario: user taps START WORKOUT on "PUSH DAY". The session opens with the 10 hardcoded exercises, not the template. History gains up to 10 phantom workouts 7 days ago, per tap.
- Fake data leaks into the streak (StreakCalculator input), IMPROVED/PRs tiles, the Body calendar dots, the Body hero totals when browsing last week, and "improvedExercises" in RECENT. The "n/10" in RECENT's IMPR column (exercises = 10 always) and the odd "0%" / "20%" VOL values come from this fake session.
- Fix: delete the call (or gate with `#if DEBUG` plus a launch flag). Purge existing phantom workouts (non-draft, `template == nil`, `duration == 0`, exactly 7 days before another workout).

### HIGH
[HIGH] ContentView.swift:812-840 — FriendActivityBanner shows DEMO friends in production
- `demoItems` (Marcus/Priya/Jake) are assigned to `trainedToday` in four cases:
  - no Firebase user (line 830)
  - no friends (835)
  - `try?` swallowing a Firestore error, i.e. offline (`?? []`, then `uids.isEmpty`)
  - friends exist but none posted today (840: `real.isEmpty ? Self.demoItems : real`)
- Expected: hidden banner (`trainedToday` empty). Actual: "Marcus +2 others trained today" for every new or offline user.
- Fix: delete `demoItems`, or gate it with `#if DEBUG`; leave the array empty otherwise.

[HIGH] ContentView.swift:852 — banner is `Button(action: {})` with a chevron
- The tap does nothing, although the chevron suggests navigation (feed or friend profile). Wire it to the Social tab or remove the chevron.

[HIGH] ContentView.swift:485-489 — prediction confidence is fake
- `.fill(i < 4 ? Color.oreAccent : Color.inkFaint)` always fills 4 of 5 dots, and the label is always "HIGH CONF".
- `predictNextWorkout` returns only a String; there is no confidence value anywhere. The same applies to the fallback "~55 MIN" (line 245) and `?? 55` in the dock (line 1033).
- Fix: have `detectNextByPattern` return (name, support/total) and map it to dots, or remove the widget.

[HIGH] BodyMapTabView.swift:121-127 and 752-759 (also 489, 503-504, 739, 784) — generic `.shoulders`/`.back` fold into `sideDelts`/`upperBack`, giving wrong and double-counted sets
- The seed data uses generic groups heavily (ExerciseSeedService: 34 `.back`, 30 `.shoulders`).
- Overhead Press (and 18 other presses) is `[.shoulders, .frontDelts]`. The loop credits `log.sets.count` to sideDelts (via `.shoulders`) AND frontDelts. A 3-set OHP gives S.DELT +3, which is wrong.
- Arnold Press `[.shoulders, .frontDelts, .sideDelts]` credits sideDelts twice (6 sets for 3). Chest Supported Row `[.back, .upperBack]` credits upperBack twice.
- Barbell Row `[.back, .lats]` credits upperBack and lats fully; the `.back` fold-in means lowerBack and traps never get it.
- Expected: a Set-based dedupe per exercise, and a sensible mapping or distribution for generic groups. Actual: per-primary-group `+= count` with no dedupe.
- Effects: hero "n/17 GROUPS" is fine (Set), but TOP/GAPS, the VOLUME heat map and the ticker inflate S.DELT/U.BACK.
- Fix: map each exercise's primaries to a `Set<MuscleGroup>` of tracked groups first, then add once per group. Drop `.shoulders`/`.back` when a specific child group is also present.

[HIGH] BodyMapTabView.swift:675-683 (with 85 `numWeeks = 4`, 344, 348) — calendar "VIEW ›" jump lands on the wrong week for workouts older than 3 weeks
- The calendar enables any past day with a workout, back to the earliest workout (`canGoPrev` uses the earliest workout). But `weekOffset = max(-(numWeeks - 1), -weekDiff)` clamps to -3 while `selectedDayIndex` is still set to the tapped weekday.
- Scenario: tap a workout 6 weeks ago (a Wednesday). The view jumps to 3 weeks ago and shows that week's Wednesday, with that week's data, under the wrong date. Wrong workout or "REST".
- Fix: remove the 4-week cap (derive `numWeeks` from the earliest workout), or disable the VIEW button / dim cells older than the cap.

[HIGH] ContentView.swift:138-141, 119-126 (weekPRs), 151-166 (weekImproved), 168-176 (weekDayBars) — Home "this week" uses `Calendar.current` locale week start, but the bar mapping and the Body tab assume Monday
- Script output: `en_US` week start = weekday 1 (Sunday); `en_AU`/`en_GB` = Monday. Body tab uses explicit Monday math (`mondayOfThisWeek`).
- Scenario (en_US, today Thu 8 Oct 2026): `weekWorkouts` starts Sun 4 Oct. A Sunday 4 Oct workout is counted in SETS/PRs/IMPROVED and drawn on the SUN bar (idx 6), which is a future day (not past/today), so it renders faint. The Body tab calls that Sunday part of the previous week.
- The Home SETS tile and Body-tab WK hero then disagree for the same week.
- Fix: use one shared Monday-based `weekStart(for:)` helper (the Body tab's `mondayOfThisWeek`) in both places, or set `cal.firstWeekday = 2`.

[HIGH] Views/BodyMap/AnalyticsView.swift (whole file) and others — shipped but unreachable
- `grep` shows zero references to `AnalyticsView`, `MuscleBalanceView`/`BalanceBar` (BodyMapTabView.swift:832-909), `QuickAnalyticsView`/`QuickStatTile`, `RecentWorkoutsWidget`, `BodyModelView`, `Body3DSceneView` (+ 100s KB `FinalBaseMesh.obj`, SceneKit import), `HeatmapColorScheme`/`HeatmapLegend` (only used by the dead 3D path), `HeatmapMode.recency` raw strings, `ProgramDayPickerSheet`, `ProfileMenuSheet`, `ProgramsTabView.programsTickerItems` (ContentView:1194), and the `ProgramRowView`/`TemplateCard` typealiases.
- The Supernova "analytics / muscle balance" feature has no entry point. The Body tab does not gate on Supernova, and Challenges are not gated either (known gap).
- Fix: either surface AnalyticsView/MuscleBalanceView from the Body or More tab (after fixing the bugs below), or delete the dead code and mesh.

### MEDIUM
[MEDIUM] BodyMapTabView.swift:608 — calendar cannot navigate to the current month on the first days of a month
- `calendarMonth = weekMonday` on open (line 161); `canGoNext = calendarMonth + 1 month <= Date()`.
- Script: today Thu 1 Oct 2026, Monday = 28 Sep, calendar opens on September, `canGoNext = false`. October (where today's workouts are) is unreachable from the Monday-in-prior-month case (up to 6 days each month, and any time while browsing a week that straddles months).
- Fix: compare month starts (`startOfMonth(next) <= startOfMonth(today)`), and open on the month of today / selected week.

[MEDIUM] BodyMapTabView.swift:288, 663, 724, 384 — day-level lookups use `workouts.first` (one workout per day), but hero totals sum all logs that day
- Two workouts on the same day (e.g. AM/PM): hero sets = both, but VS LAST, the label (`selectedDayLabel`), the calendar detail (sets/duration) and the "VS LAST" comparison use only the first-matching workout, in unsorted `@Query` order.
- Fix: sum or list all workouts for the day.

[MEDIUM] BodyMapTabView.swift:316, 313, 814, 816 — week-number and ticker labels
- `weekNum - 1` yields 0 in week 1 (script: Mon 4 Jan 2027, `en_GB` weekOfYear = 1, so "VS WK 0"; same for ticker "WK0").
- Ticker label is `vs.label.hasPrefix("VS PACE") ? "VS PACE" : "VS LAST"`, so a past week's "VS WK 40" shows as "VS LAST" with the week-over-week value.
- Fix: use `Calendar.date(byAdding: .weekOfYear, -1)` and compute the number from that date; pass the label through.

[MEDIUM] BodyMapTabView.swift:480-514 — cold-spot maths mixes definitions with the rest of the tab
- FREQ counts secondary muscles (line 489); the recency heat (784), VOLUME heat (756), TOP/GAPS and musclesWorked count primary only.
- VOL mode uses a rolling `now - 7d` window (482), while every other metric in the tab is a Monday–Sunday calendar week and ignores `weekOffset` / selected day.
- The same exercise's secondary credit is `log.sets.count / 2` (integer; 1 or 2 sets give 0, 3 give 1). Never-trained muscles show "99D / 4D" (line 492).
- Not wrong per se, but two screens can show different numbers for the same muscle. Document or unify.

[MEDIUM] BodyMapTabView.swift:772-797 — heat map semantics vs legend
- Day mode normalises by the day's peak (`v / peak`) but the legend says "100% OF TARGET" (211-216). The week view clamps to `min(1, v/target)`.
- Recency mode (LAST 48H) with "ALL WEEK" uses `now = min(Sunday, today)+21:00`, i.e. a fixed 21:00, so a workout at 22:00 today is excluded (`w.date <= now`) and a workout "just now" at 08:00 shows ≈ 0.7 intensity. Past weeks use Sunday 21:00.
- The 48 h fade is correct as a formula, but the reference time is an assumption. (Acknowledge or use real `Date()` for the current week.)

[MEDIUM] Warm-ups, drafts and units across Body/Home — all totals count `sets.count`
- `SetType.warmup` exists but is never excluded: Body hero, TOP/GAPS, heat, Home SETS tile, RECENT SETS, volume deltas (`weight*reps` includes warm-ups), PR/improved tiles, the ticker.
- Fix: filter `setType != .warmup` in a shared helper (and `reps > 0`).
- Tiles ignore the user's kg/lb setting (not verified; no unit conversion seen in this scope).

[MEDIUM] ContentView.swift:236 — `lastDoneLabel` uses 24h periods, not calendar days
- Script: yesterday 20:00 -> today 08:00 gives `days = 0`, so the label shows "TODAY" for yesterday's session.
- The Body tab correctly uses `startOfDay` (line 805). Fix the same way.

[MEDIUM] ContentView.swift:209-216 — predicted template chips only come from past workouts' templates
- `predictedTemplate` = `workouts.compactMap(\.template).first { name matches }`, not `templates`. A brand-new user (or a split day never logged) gets the name but no exercise chips. The dock (`startDock`) uses all templates.
- If the predicted name is a split-day label without a template (`user.selectedSplit.days.first?.label` returned at WorkoutViewModel:629), the dock shows the name but `startWorkout(template: nil)` starts a blank workout.

[MEDIUM] WorkoutViewModel.swift:637-667 (`detectNextByPattern`) — prediction is non-deterministic on ties and ignores timing
- `candidates.max(by: { $0.value < $1.value })` on a Dictionary: tied successors resolve by random per-launch hash order, so the prediction can flip between launches.
- The fallback (no history) returns `days.first?.label` regardless of weekday. It doesn't consider how many days since the last workout.

[MEDIUM] ContentView.swift:318 (and ActiveWorkoutView:242) — "Drafts auto-save for 7 days" is not implemented
- No cleanup or expiry code exists (grep). A months-old draft keeps showing CONTINUE in the dock and blocks the normal START state. Only `drafts.first` (latest `updatedAt`) is shown; older drafts are orphaned and invisible.
- Fix: delete or prompt on drafts older than 7 days at launch.

[MEDIUM] ContentView.swift:62-68 + OreApp.swift:76-83 — widget / deep-link start handling
- `startWorkoutFromWidget` is a NotificationCenter post; on a cold launch from the URL the post can happen before ContentView's `.onReceive` exists (RootView/onboarding first). Notifications are not buffered (unverified at runtime).
- If a draft or an active workout already exists, `startWorkout` is called anyway: it creates a second draft and replaces the active session's `workout` pointer (the first draft is orphaned).
- `guard let user` silently does nothing when no user. A template name not found silently starts a blank workout. `.importTemplate` is posted but never observed anywhere (dead; known gap).
- Fix: check `workoutViewModel.isActive` / existing draft first; queue the pending start in a shared router (like `MoreRouter`).

[MEDIUM] ContentView.swift:733-757 (volumeDelta), 785-805 (ticker) — percentages truncate instead of round, and equal values show as green up
- `Int(((cur - prev)/prev)*100)` truncates toward zero. Script: 1000->996 gives "▲ 0%" (green), 1000->1009 gives "▲ 0%", 1000->990 gives "▼ 1%". So the RECENT "0%" cells include small drops and small gains (the Body tab uses `.rounded()`, so the two tabs also disagree).
- Ticker (798): same truncation; `pct >= 0` marks 0% as up (green).
- Fix: `.rounded()`, and treat |pct| < 0.5 as neutral (no arrow).

[MEDIUM] ContentView.swift:259-277 (improvedExercises) — IMPR column semantics inconsistent with the IMPROVED tile and Analytics
- Row: exercise improved if its best single-set weight*reps beats the all-time best across ALL earlier workouts, and a first-ever exercise counts as improved (prevBest = 0 < thisVol). Denominator `max(exerciseLogs.count, 1)` includes exercises with 0 sets.
- Tile `weekImproved` (151-166): best set volume this week vs previous calendar week only; absent previous = 0, so new exercises count. Analytics (dead): requires `prevBest > 0`.
- Cost: O(rows × workouts × logs × sets) on every body evaluation.
- Fix: share one helper (`ImprovementCalculator`) used by all three; decide first-time semantics.

[MEDIUM] ContentView.swift:119-126 — PRs tile is max-weight only, counts first-time exercises, counts warm-ups
- `weekMax > (prevMax ?? 0)`: the first time an exercise is ever logged counts as a PR; bodyweight (weight 0) can never PR; no rep PRs or e1RM. CLAUDE.md says PR is a treatment elsewhere, but no PR service is shared: `grep` shows each screen re-derives PRs.

[MEDIUM] Performance — heavy work in view bodies
- BodyMapTabView: `@Query` fetches ALL ExerciseLog and ALL Workout (no predicate/date window). In one body evaluation: `tickerItems` -> `vsInfo` + 4× `setsInWeek` (each filters all workouts and sums sets); `filteredLogs` recomputed 5+ times (selectedTotalSets, musclesWorkedCount, setsByMuscle×3 via topMuscles/gapMuscles/heatLevels); `coldSpotsData` is 17 × logs × muscles; recency heat 17 × logs; `calCell` runs `workouts.contains` per cell (42/render); `DateFormatter()` allocated per render.
- HomeTabView: `basePredictedName` performs a SwiftData fetch of all workouts on each access and is read ~5× per body (`predictedTemplateName`, `predictedTemplate`, `lastDoneLabel`, `estDuration`, `overrideName`). `StartWorkoutDock.startDock` does 3 more fetches (all templates, all workouts ×2) per body.
- Fix: memoise via `@State` + `.onChange`/`.task`, compute once per body into a local struct, and window the queries.

[MEDIUM] BodyMapTabView.swift:93, 146 / MuscleDetailSheet.swift:9, 96 — unused/StoreKit refresh on every appearance
- `supernovaService` in BodyMapTabView is never read (dead state + StoreKit round trip each time the tab is shown).
- MuscleDetailSheet: `subRegion` is always nil (sheet created with `subRegion: nil`), so the highlight dot (`subRegion == sub`) never lights up. "Performed"/"sessions" use `exercise.logs.count` (includes ExerciseLogs of draft workouts and counts exercises, not sessions); the sheet doesn't show the muscle's actual volume.

[MEDIUM] Views/BodyMap/AnalyticsView.swift (dead but buggy; fix before wiring)
- :248-252 `workoutsPerWeek` sorts week keys as strings ("W10" < "W9") and keys only by week-of-year (collides across years for the 3-month range spanning New Year).
- :254-268 `improvementData` compares against `exercise.logs` of ALL sessions including later ones and drafts; excludes only itself.
- :270-286 `muscleVolumeData` counts generic and specific groups separately, secondary `/2` truncation, warm-ups included, top-10 only; label "Weekly Volume" but it's the range total.
- :55-56 custom end date `Date()` captured at init is stale; `<= effectiveEndDate` excludes same-day workouts later than the picker's time.
- :296 `currentStreak` ignores the range; weight trend (`maxWeight`) has no unit handling; no Supernova gate.

### LOW
[LOW] BodyMapTabView.swift:826 — `return items + items` doubles the ticker content, but `TickerStripView` already tiles its own items (TickerStripView:~60-80), so every entry repeats twice per tile.
[LOW] BodyMapTabView.swift:118, 261 — `dailyTarget = 26` is hardcoded (weeklyTarget 176 is the sum of `targets`; 26 ≈ 176/7 rounded). TOP/GAPS in single-day mode still use weekly targets (ratio `sets/weeklyTarget`).
[LOW] BodyMapTabView.swift:411-447 — no-data weeks show three arbitrary muscles at "▲ 0%" under TOP and three under GAPS (tie order of `sorted`). Hide TOP when `sets == 0`.
[LOW] BodyMapTabView.swift:437 — `Int(m.ratio*100)` floating error (e.g. 23/10 shows 229%, only >100%); use `Int((ratio*100).rounded())`.
[LOW] ContentView.swift:254 vs BodyMapTabView:343 — "WK n" means weeks since signup on Home but ISO week-of-year on the Body tab.
[LOW] ContentView.swift:771-805 — Home ticker lists every `MuscleGroup.allCases` with data, including both generic and specific groups (BACK and LATS and U.BACK…), unsorted, label `prefix(6)` gives "LOWER " / "UPPER " / "FRONT " / "SIDE D" / "REAR D"; rolling 7d window differs from the Body ticker's calendar-week numbers.
[LOW] BodyMapTabView.swift:801-806 — PUSH/PULL/LEGS "days since" matches `template.name.contains` only; custom-named templates give "—"; non-template workouts are never counted.
[LOW] ContentView.swift:846 — banner label counts posts, not people: `others = trainedToday.count - 1`, while names use `uniqueNames`. One friend with 3 posts gives "Marcus +2 others".
[LOW] ContentView.swift:376, 450 — sign-out uses `try? FirebaseAuthService().signOut()` (error swallowed; a new service instance each time). Failure leaves the user signed in silently. (Further behaviour is outside scope: unverified.)

## Verified OK
- BodyMapTabView weekly targets/tracking: `targets` sum 176 = `weeklyTarget`; all 17 tracked groups have target, cadence and abbreviation entries; every tracked group appears in front or back path lists (BodyMap2DView:50-96), taps map to `MuscleGroup` and open MuscleDetailSheet. Path parser handles the M/L/Q/Z subset.
- Week math: `mondayOfThisWeek` (331-336) correct for Sunday (-6) and Mon-Sat (script-checked via `(weekday+5)%7` equivalence); `weekMonday` offset via `.weekOfYear` is DST-safe; `setsInWeek` uses [mon, mon+7d) half-open ranges; draft workouts excluded in `filteredLogs`, `setsInWeek`, dayScrubber dots, cold spots.
- Week navigation: ‹ disabled at offset -3 (the 4-week cap, see HIGH), › disabled at 0; changing week resets the day to ALL WEEK.
- VS PACE: expected = round(176·elapsed/7) → 25, 50, 75, 101, 126, 151, 176 for Mon..Sun (script); elapsed uses `startOfDay` so inclusive of today; `max(1,…)` prevents ÷0; `prevTotal > 0` guard prevents ÷0 in VS WK.
- Calendar grid offset for Monday start: `(weekday+5)%7` (Sun 1→6, Mon 2→0) correct; 42 cells always ≥ offset+days (max 37); future days and non-workout days disabled; selection toggles and detent changes work.
- Heat level VOLUME for week: `min(1, sets/target)`; division guards (`max(…,1)`).
- ColdSpots FREQ day-diff uses `startOfDay` both sides; flagged at `days >= 1.5*cadence`; VOL flags `<50%` of target; bar width clamped to 1.0.
- ContentView draft detection: `StartWorkoutDock` `@Query(filter: #Predicate { $0.isDraft })` sorted by `updatedAt` desc; CONTINUE state uses it and START NEW goes through discard confirmation; `draftProgress` guarded for `target == 0` and clamped to 1.0.
- Tab bar/tutorial wiring: five tabs tagged 0-4 match `TutorialStep.requiredTab`; only 3 of 10 steps have anchors (others show a dim card alone by design); `.openSupernova` routes to More; debug launch args are `#if DEBUG`.
- Streak tile calls `StreakCalculator.currentStreak(from:)` with non-draft dates (single source of truth, same function in Analytics/RecentWorkoutsWidget).
- GlobalSearchView: only fetches non-draft workouts, exercises limited to approved/custom, results `.prefix(8/5)`; friend search is async via `searchUsers` with `try?` fallback (no stale-result cancellation: latest-wins race possible, minor and unverified).
- volumeDelta divides only after `prevVol > 0` guard; uses most recent earlier same-named workout (query is date-desc so `first` is correct).

## Not verifiable
- Runtime behaviour (cold-start notification race, SwiftData fetch counts, locale behaviours beyond the script) — no simulator/xcodebuild per brief.
- `Calendar.current` locale on the user's device; the script used en_US/en_AU/en_GB. HIGH finding on week start depends on device region.
- `FirestoreService.fetchFeed(friendUids:)` limits/indexes, `searchUsers`, `signOut` effect on RootView — outside this scope.
- Whether the PNG/ticker visual duplication (LOW) is visible: inferred from TickerStripView's own tiling.
- Unit handling (kg/lb) for volumes: no conversion seen here; settings code not reviewed.
- Active-workout persistence of sets into the draft (whether `draftSetsDone` counts blank target sets) — in WorkoutViewModel, not read in full.
