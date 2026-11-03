# Audit: services-core

Scope: WidgetDataService(+Fixed), BodyweightLog, CalorieEstimationService, RestTimerService, LiveActivityService, NotificationService, SupernovaService, OreShared/WorkoutActivityAttributes + WorkoutLiveActivityIntents (plus the call sites in WorkoutViewModel, SettingsView, RootView needed to judge wiring).
Scratch scripts: scratchpad/svc_scripts (BodyweightLog compiled standalone, Calorie service compiled standalone, ISO calendar + PR maths).

## Summary
- Most widget maths (weekly buckets Mon-Sun, same-weekday comparison, balances, deload detection, block-week/next-deload, bodyweight series, recap, friends formatting) is correct and matches the design sample numbers. The ISO calendar behaves as assumed (Monday start, weekday 1 = Sunday).
- The PR-watch widget compares an Epley e1RM against an all-time best WEIGHT, so its gap/percentage/selection are wrong for almost every multi-rep lift. A unit test encodes the wrong behaviour.
- The rest timer is a 1 Hz decrementing `Timer` (no end-date), so it freezes in background and loses ticks while the user scrolls. Nothing schedules a local notification for rest end.
- Splits are always created with `days = []`, so workout reminders never schedule, rest-day alerts fire all 7 days, and the widget "program target / cycle" fall back to defaults.
- MET calorie formula is dead code in practice (no caller passes `isSubscribed`) and its own unit test fails.
- Live Activity: dedupe is defeated (state changes every second), draft-resume never restarts the activity or intents, end state is left on the lock screen.
- Found while tracing (outside scope): `WorkoutViewModel.startWorkout` calls `injectTestData` unconditionally.

## Findings

[CRITICAL] Ore/ViewModels/WorkoutViewModel.swift:81 — `injectTestData` runs on every real workout start (outside scope, reported because it feeds Live Activity + widgets)
`startWorkout` ends with `injectTestData(modelContext: modelContext)`; the function (l.85-146, not under `#if DEBUG`; the only `#if DEBUG` is at l.526) replaces `exerciseEntries` with 10 fake completed exercises, inserts fake historical Workouts/ExerciseLogs/SetLogs (non-draft, 7 days old, so they feed widgets/PRs/volume) and backdates `startTime` by 78 min. Every new workout, including template-based ones, starts with the template exercises wiped and fake data. The Live Activity then shows the fake 78-min elapsed (attributes.startTime is Date() but VM startTime is backdated).
Fix: delete the call or wrap in `#if DEBUG` behind a launch flag.

[HIGH] Ore/Services/WidgetDataService+Fixed.swift:181-182,196,402-411 — PR watch compares e1RM to best weight
`pr = sets.map(\.weight).max()` (all-time heaviest weight) but `e1rm` is `recentBest = max(weight*(1+reps/30))` over 4 weeks. Header comment says "within 5% of the all-time PR weight" but the widgets present them as the same quantity: PRWatchWidget.swift:78 `e1rm/pr*100 %`, :29/:125 `abs(pr - e1rm)` "KG TO PR", LockScreenWidgets.swift:102 ratio sort.
Script: best ever 100x5 (weight PR 100). Recent 100x5 -> e1rm 116.67, gap -16.7% (reads "117% of PR"); recent 80x5 -> e1rm 93.3, gap +6.7% (not "close"), though 80x5 is only 80% of 100x5; recent 90x5 -> e1rm 105, gap -5%. Any lift last done for >1 rep appears above its PR, `abs()` hides the sign (shows "5 KG TO PR" when the user is 5 above it), and "close to PR" selection is meaningless. Test `prLiftsFromHistory` (WidgetFixedDataTests.swift:176-190) asserts pr == 100 with e1rm == 105 and so locks the bug in. The series is e1RM while the PR mark is a weight, so the chart's PR line sits below the data.
Fix: `pr = sets.map(\.e1rm).max()` (and display "PR e1RM"), or compare weight-to-weight; update the test.

[HIGH] Ore/Services/RestTimerService.swift:30-41,107-116 — countdown is tick-counted, not end-date based; nothing alerts in background
`start` schedules `Timer.scheduledTimer(1s)` (default run-loop mode) and `tick()` does `remainingSeconds -= 1`. (a) App backgrounded/locked: the process is suspended (Info.plist UIBackgroundModes = remote-notification only), the timer stops, the in-app value is frozen and resumes where it left off on return; the sound/haptic in `playAlert` never fires. (b) No `UNNotificationRequest` is scheduled anywhere for rest end (grep: only NotificationService does notifications, and only workout/rest-day reminders). (c) Default-mode timers do not fire while a ScrollView is tracking; each missed fire is a lost second (Timer does not catch up), so the rest drifts late whenever the user scrolls the workout screen. The Live Activity countdown (restEndDate pushed at last update) keeps running while the app copy is frozen, so they disagree on return.
Fix: store `endDate`, compute `remaining = ceil(endDate - now)` on each tick and on scenePhase active, add timer in `.common` mode, schedule a `UNTimeIntervalNotificationTrigger` at `start` (cancel in stop/adjust/skip).

[HIGH] Ore/Services/NotificationService.swift:36-37,79-80 (with SettingsView.swift:309, OnboardingViewModel.swift:135-137, Models/Split.swift:21) — reminders depend on `split.days`, which is never populated
`Split(type:name:)` is the only constructor used; `days` defaults to `[]` and `SplitDay(` is never constructed outside the model (grep). Result: `scheduleWorkoutReminders` returns at `!split.days.isEmpty` -> workout reminders never schedule even with the toggle on. `scheduleRestDayAlerts` computes `trainingDays = {}` so `restDays = 1...7` -> a "Rest day" notification EVERY day at 10:00 (also when `split == nil`). Same cause makes widgets use `target = snap.sessionGoal (5)` and the history-derived program cycle (WidgetDataService+Fixed.swift:267-269, 487-497).
Fix: populate `days` when a split is chosen, and skip rest-day alerts when there are no split days.

[HIGH] Ore/Services/CalorieEstimationService.swift:52,59 (callers WorkoutViewModel.swift:252,413) — MET formula can never run; unit test fails
`isSubscribed` defaults to false and neither call site passes it, so `.met` always falls back to `basicEstimate`. Standalone run of the real file: `estimate(.met, 10, 5, 5, 80kg, 60min, .moderate)` = 80.0, but `estimateUsesMetFormula` (CalorieEstimationServiceTests.swift ~l.62) expects 400.0 -> test fails today. Intensity is also hard-coded `.moderate`, so the light/vigorous MET values are unreachable.
Fix: pass `SupernovaService` entitlement (or drop the gate), and have the test pass `isSubscribed: true`.

[HIGH] Ore/ViewModels/WorkoutViewModel.swift:147-180 (resumeDraft) — resumed workouts get no Live Activity and dead intents
`startWorkout` calls `installLiveActivityObservers()` (l.53), sets `liveModelContext` and `liveActivity.startLiveActivity`. `resumeDraft` does none of these: after a crash/relaunch there is no Live Activity, `plannedValues`/`lastTime` get no context (ghost values empty), and the Adjust/Skip/Log-set intents have no observers. `stopDurationTimer` later calls `endLiveActivity` on a nil activity (no-op), so any orphaned activity from before the crash stays on the lock screen (nothing enumerates `Activity<WorkoutActivityAttributes>.activities`).
Fix: share a `beginLiveSession()` between both paths; on launch end stale activities.

[HIGH] Ore/Services/LiveActivityService.swift:39,42 + ViewModels/WorkoutViewModel.swift:677,754-758 — dedupe is ineffective, Live Activity is updated every second
`guard state != lastState` compares the full ContentState, which contains `elapsedSeconds` (changes every tick) and `restSecondsRemaining` (every second while resting). The widget UI never reads either (LiveActivityViews.swift:68 uses `attributes.startTime`; grep finds no use of `elapsedSeconds`/`restSecondsRemaining`). So the "skip when nothing visible changed" comment is false: `activity.update` is called ~1/s for the whole workout, with makeLiveActivityState doing a SwiftData fetch (`lastTime`, cached) and ghost lookups each second.
Fix: compare states with those two fields zeroed (or remove them from ContentState).

[MEDIUM] Ore/Services/LiveActivityService.swift:53-67 — end leaves a "Complete" card with zeros; start never ends an existing activity
`end(... dismissalPolicy: .default)` keeps the activity on the lock screen up to 4 h with `completedSets: 0, totalSets: 0` (it shows "0/0 sets"); `.immediate` or the real final counts would be correct. `startLiveActivity` does not end a previous `currentActivity` (e.g. discardDraftAndStart), leaking one activity per restart. `Activity.request` errors are swallowed silently.

[MEDIUM] OreShared/WorkoutLiveActivityIntents.swift:13-50 + WorkoutViewModel.swift:779-800 — intents are fire-and-forget over NotificationCenter
If the app was terminated (or resumed via resumeDraft, see above) there are no observers, so Adjust/Skip/Log taps are silently dropped. LOG SET uses `logNextSetFromLiveActivity` -> `logSet(..., isCompound: true)` for every exercise, so isolation lifts get the compound rest (180 s) and a set with empty planned weight/reps is logged as 0x0; nothing saves the draft afterwards (only scenePhase .background saves).

[MEDIUM] Ore/Views/Workout/ActiveWorkoutView.swift:1409-1415 (uses RestTimerService) — modal +/- buttons mutate `remainingSeconds` directly
Bypasses `adjust(by:)`: `totalSeconds` is not raised (so `progress = 1 - remaining/total` goes negative after +60 on a short rest), the Live Activity isn't pushed, and `max(0, ..)` leaves `isRunning` true at 0 until the next tick. `RestTimerService.adjust` (l.54-63) is correct but only used by the Live Activity intent.

[MEDIUM] Units — OreShared/WorkoutActivityAttributes.swift:21, WidgetDataService+Fixed.swift (volumeTonnes/recap/kg), BodyweightLog.swift, OnboardingViewModel.swift:107-125, EditProfileView.swift:65
`weightUnit` defaults to "KG" and is never set anywhere (grep), so lbs users get "KG" in the Live Activity. `User.weight` stores the raw typed number in the user's unit (ProfileView.swift:246 then multiplies it by 2.20462 as if kg), and BodyweightLog.record(kg:) / MET `bodyWeightKg` / widget "KG" labels all treat it as kg. Volumes/"kg" in widgets assume SetLog weights are kg. For an lbs user: profile shows double-converted weight, MET calories (if ever enabled) over-estimate by 2.2x, bodyweight widget is labelled kg with lb numbers.

[MEDIUM] Ore/Services/WidgetDataService+Fixed.swift:146,150,156 — stale/neglected lists hide the most neglected muscles
`heatGroups` (neglected tiles) omits BACK, TRICEPS and HAMSTRINGS, so an untrained hamstring never appears as neglected. `muscleRows = ranked.prefix(10)` of 12 groups, ranked by sets desc then recency, so the two groups with zero sets and longest absence are exactly the ones dropped (a user who never trains calves + hamstrings sees neither row). Expected: stale rows should survive the cut.

[MEDIUM] Ore/Services/WidgetDataService+Fixed.swift:272-276 — programWeek is not tied to the split's start
`originDate` = oldest workout ever whose template name matches a split day label/type (else oldest workout, else split.createdAt). With empty `days` (see HIGH above) `splitLabels` is empty so it is simply the first workout ever; the value is `weeksSince % 8 + 1`, so it never resets when the user changes split. A user who has trained 20 weeks sees "WK 5" regardless of when the program began.
Fix: anchor on `split.createdAt` (or an explicit program start date).

[MEDIUM] Ore/Services/WidgetDataService+Fixed.swift:228-239 — loadRatioDelta mixes partial and full weeks
`ratio` = this week so far / avg of prior-4 over the same elapsed time; `prevRatio` = last FULL week / avg of full weeks 2-5. Their difference is a delta between differently-normalised numbers. Early in the week (or with zero sessions yet) `prior4` can be 0 -> ratio 0 -> delta = -prevRatio (shown as a large drop). Fix: compute prevRatio with the same elapsed cut-off for weeks 1 and 2-5.

[MEDIUM] Ore/Services/WidgetDataService+Fixed.swift:523-553 and ViewModels/SocialViewModel.swift:268 — friends data goes stale and survives sign-out
`ago` ("1H") is baked in at write time and never recomputed, so the widget shows the same "1H" until the next feed fetch. `writeFriends` runs only when `fetched` is non-empty, and nothing clears `widget_friends` on sign-out/unfriend, so the previous account's friends' names/workouts remain in the shared App Group (privacy leak across accounts).
Fix: store dates, format in the widget; clear on sign-out.

[MEDIUM] Ore/Services/WidgetDataService.swift:8-41 + RootView.swift:19-26 — widgets refresh only when app becomes active / a workout finishes
Not refreshed on workout edit/delete/import, template/split change, profile weight change (BodyweightLog.record at EditProfileView:65 doesn't trigger), or when the app goes to background. Edits made in-app are invisible on the home screen until the next foreground. Also `isPlus` can stay true after the 14-day trial lapses until the next app open.

[MEDIUM] Ore/Services/WidgetDataService.swift:73-180 + Fixed:58-76 — unbounded main-thread work on every foreground
`updateWidgetData` is main-actor, fetches ALL workouts, walks every relationship (`fsets` over full history, `flat.filter` per big lift/muscle/exercise, `improvements()` called once per workout of the week and each scans prior workouts, l.98) and instantiates a full `WorkoutViewModel()` (l.164; also creates RestTimerService/LiveActivityService) just for `predictNextWorkout`. Cost grows linearly+ with history (1,000+ workouts will hitch each foreground). Unverified timing; structure is verified by reading.

[MEDIUM] Ore/Services/WidgetDataService.swift:140-159 — legacy bodyVolume counts warm-ups and double-counts regions
`sets7 += Double(log.sets.count)` includes warm-up sets (the fixed set excludes them), and one exercise with several primary muscles mapping to the same region (`.shoulders`+`.frontDelts` -> "shoulders", `.back`/`.lats` are unmapped but e.g. `.chest,.frontDelts`) adds the sets once per muscle. Heat can exceed target faster than real. `snap.e1rm` (l.111-131) buckets by `dateComponents(.weekOfYear)` (rolling 7-day, not ISO weeks as in the fixed data) and keys "Bench Press"/"Squat" by loose substring (includes Dumbbell/Decline/Smith bench, Hack/Goblet/Front squat), inconsistent with `bigLift`.

[MEDIUM] Ore/Services/NotificationService.swift + RootView.swift:25-26 + SettingsView.swift:200-230 — scheduling lifecycle
(a) `reschedule` is only called at launch (RootView `.task`); changing the split (SettingsView:309) never reschedules. (b) `requestPermission()` is called at every cold start, so the permission prompt appears on the first launch/after onboarding with no context, even if the user never enabled reminders. (c) In the toggle bindings `requestPermission()` is also called when turning a toggle OFF; when permission is denied and the user turns it ON the toggle stays on and nothing is scheduled (no feedback / Settings deep link). (d) Reminder times are fixed to 8:00/10:00 (the `reminderHour` params are never exposed). (e) `restDays.enumerated()` iterates a `Set`, so message assignment is nondeterministic.

[MEDIUM] Ore/Services/SupernovaService.swift:63-68,114-127 — no app-wide transaction listener; per-view instances
`startListening()` is only called from SupernovaView (stopped at onDisappear, l.63), so `Transaction.updates` (renewals, refunds, Ask-to-Buy approvals, purchases on other devices) is not observed app-wide as StoreKit recommends; entitlement only refreshes when one of the five screens that each create their own `@State SupernovaService()` (SettingsView:33, MoreTabView:20, WorkoutDetailView:10, BodyMapTabView:93, MuscleDetailSheet:9) runs `.task`. Each instance starts with `isSubscribed = false` until its async refresh completes, so subscribers see locked/paywall UI briefly. `currentSubscription` is never reset to nil when no entitlement is found (l.115-125) and is nil if `availableProducts` is not loaded yet (refresh before loadProducts).
Fix: single shared service in the environment, started at app launch.

[MEDIUM] Ore/Services/SupernovaService.swift:129-143 — trial boundary inconsistent; trial is client-side only
`isInFreeTrial` is `daysSinceInstall <= 14` (15 calendar-day windows: day 0..14) but `trialDaysRemaining = max(0, 14 - days)` shows 0 on day 14 while access is still granted. The getter has a write side-effect (sets `appInstallDate` on first call, including from the widget path via `currentIsPlus`). Trial resets on reinstall and can be extended by moving the device clock (known gap in CLAUDE.md; unverified exploit, verified by reading).

[MEDIUM] Ore/Services/WidgetDataService+Fixed.swift:371-384 — balanceRow when one side is 0
`a=0,b=34` -> `ratioText = 34/1 = "34.00"` and `a>0,b=0` -> "—". Flag text is right ("▼ PUSH -34 SETS") but the displayed ratio is misleading. Expected "0.00"/"∞" or "—".

[LOW] Ore/Services/RestTimerService.swift:19-22 / ViewModels/WorkoutViewModel.swift:226 — `autoStartWithDismiss` is behaviourally identical to `autoStart` in the service/VM; only `.manual` differs (any dismiss behaviour would have to be in views; unverified).

[LOW] Ore/ViewModels/WorkoutViewModel.swift:249-262 vs 398-418 — live calories classify "compound" by name keywords ("press" matches Leg Press/Tricep press-downs, etc.) while the final value uses `movementPattern.isCompound`, so the live number can jump on completion.

[LOW] Ore/Services/WidgetDataService+Fixed.swift:294 — `"\(6 - todayIdx) DAYS"` gives "1 DAYS", and on Sunday "0 DAYS" (excludes today by design to match the sample).

[LOW] Ore/Services/WidgetDataService+Fixed.swift:364-367 — `pctDelta` returns 0 when there is no baseline, indistinguishable from a real 0.0% change.

[LOW] Ore/Services/WidgetDataService+Fixed.swift:449-471 — classification uses only `muscles.first`; `.sideDelts` missing from `isAnterior`; deadlift (primary `.back`) counts as PULL and LOWER; leg exercises with `.push` pattern would count as PUSH (none found in the seed list: Leg Press is `.squat`).

[LOW] Ore/Services/WidgetDataService.swift:166-171 — `nextDay` is always today's weekday, `nextEstMinutes = max(10, sets*3)` is a fixed heuristic, not derived from history.

[LOW] Ore/Services/WidgetDataService+Fixed.swift:413-427 — `bigLift` includes Front Squat/Sumo Deadlift/"Bench Dip" (any "bench" name not in the exclusion list, e.g. "Bench Dip", "Reverse Bench"), merged with the main lift.

## Verified OK
- ISO calendar (Calendar(identifier:.iso8601)): firstWeekday = 2, Sunday weekday = 1, week start/ISO week number correct (script; Sun 11 Oct 2026 -> weekStart Mon 5 Oct, week 41). `todayIdx`, `(weekday+5)%7`, streak letters (Fixed:84-88) correct.
- Weekly buckets: weekSetsPerDay/weekDone (Fixed:97-104), setsThisWeek vs setsLastWeekSameDay cut-off = lastWeekStart + (todayIdx+1) days inclusive of the same weekday (Fixed:113-120), volumeTonnes (sets x reps / 1000, warm-ups excluded, drafts excluded), hours, volDays last-week full-week bars; `daysBetween` uses startOfDay (DST-safe).
- 7-day body-map window (today-6), neglected ordering, stale rule (0 sets or >5 days) matches the documented thresholds; balance windows (28 days incl. today), bands, reciprocal band symmetry, share/ratio text reproduce the sample (48/34 -> 1.41, 0.585; 82/30 -> 2.73, 0.732; 61/51 -> 1.20, 0.545).
- Deload: `detectDeloadWeeks` (current week excluded, flagged weeks honoured, >=2 priors, <60% of avg), blockWeek / sinceAnchor / nextDeloadWeek reproduce sample (block 5/6, next WK 42); isoWeek labels across year boundary use date arithmetic, fine; loadWeeks = 8 weeks + next.
- Recap: volume, sets, mm:ss, delta vs previous same-template session, PR detection against all earlier sets (same-workout sets excluded, first-ever lift not flagged).
- Next-workout exercise list (last-session top weight, reps fallback), nextLastSameDays, quick-start ordering, prediction confidence formula (successor-frequency x min(1,total/3), clamped 0.2-0.95), session tiles (done suffix(3) + NEXT + later), eco ORE row.
- BodyweightLog: compiled standalone; same-day last-write-wins, gap carry-forward, delta7d = latest vs point 7 days earlier (21 points, delta -1.5 correct), start label, 400-entry cap, non-positive ignored.
- friendSessions formatting (initials, "PR · LIFT w x r", sets/min, ago buckets) and sign handling.
- CalorieEstimation basic and MET maths (10/6/8 per set; MET x kg x hours) correct and matching tests (except the gate issue above); MET fallback for zero weight/duration.
- RestTimer: restDuration override > global > default, formattedTime, progress, stop()/completion semantics (`completedAt` set only on natural finish), `adjust(by:)` raises total and completes at <= 0; Live Activity rest-over alert fires once per flip (`lastRestOver`).
- NotificationService: weekday numbering (1 = Sunday) consistent with `(dayOfWeek+5)%7` used elsewhere; identifiers unique per weekday; cancel-before-schedule; authorization check before adding.
- Supernova: purchase flow verifies transactions, finishes them, refreshes; `currentEntitlements` excludes expired/revoked and includes billing-grace subscriptions; restore calls `AppStore.sync` then refresh; widget flag patching (`setSubscribed`) guarded against redundant writes.
- ContentState is Codable/Hashable, shared once in OreShared; intents post the three notifications the VM observes with matching names/userInfo key ("delta").

## Not verifiable
- Actual device behaviour of Live Activity throttling, ActivityKit alert delivery in background, or timer behaviour during scroll (no simulator/Xcode allowed; findings based on code and documented platform behaviour).
- StoreKit sandbox behaviour (grace period, billing retry, refunds) and product IDs existing in App Store Connect.
- Whether SetLog weights are consistently stored in kg (no conversion code found; treated as unverified/likely user-entered units).
- Performance numbers for `updateWidgetData` with large histories.
- Test results: I did not run the XCTest/Testing suites; `estimateUsesMetFormula` failure was shown by compiling the real service file standalone.
- Views that consume the widget fields beyond the PR widgets (covered by other areas).

## Test coverage
- Covered: Calorie basic/MET maths and dispatcher (one test currently fails), RestTimer formatting/progress/stop/default durations, widget pure helpers (balanceRow, detectDeloadWeeks, selectPRLifts, bigLift, bodyweight series, friendSessions) and several buildFixed scenarios (WidgetFixedDataTests: weekly sets, warm-ups skipped, balances, deload fields, PR lifts, bodyweight).
- Not covered: `RestTimerService.start/tick/adjust/skip` behaviour, LiveActivityService, intents/observer wiring, NotificationService scheduling, SupernovaService (trial boundary, entitlement), buildFixed pieces: body-map muscleRows/neglected, loadRatio/delta, program week/tiles, recap PR/delta, next-workout list, quick starts, `WidgetDataService.buildSnapshot` (legacy fields).
