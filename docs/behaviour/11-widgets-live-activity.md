# 11 Widgets and Live Activity

Scope: home-screen and lock-screen widgets (fixed set + legacy streak widget + "Ore Custom"), the widget builder and gallery, and the workout Live Activity / Dynamic Island. Source: `OreShared/Widgets/*.swift` (layouts), `OreShared/OreWidgetSnapshot*.swift` (data contract), `OreShared/OreWidgetCatalog.swift` (+ `OreWidgetStore`), `Ore/Features/Widgets/*` (data service, builder, gallery), `OreWidget/*` (WidgetKit providers/bundle), `Ore/Features/Workout/Services/LiveActivityService.swift`, `OreShared/WorkoutActivityAttributes.swift`, `OreShared/WorkoutLiveActivityIntents.swift`, `OreShared/Widgets/LiveActivityViews.swift`, and the `WorkoutViewModel` live-activity glue.

**CLAUDE.md claim vs reality.** CLAUDE.md "Known Gaps" says "Widget extension shows streak only - missing predicted workout and weekly volume widgets". That is stale. The extension bundle (`OreWidget/OreWidgetBundle.swift`) registers 16 widgets: the legacy streak-only `OreWidget` ("Ore", kept), the configurable "Ore Custom", 14 fixed widgets (Next workout, Streak, Weekly volume, Body map, Muscle balance, PR watch, Deload and recovery, Last session, Program, Weekly goal, Bodyweight, Friends, Quick start, Pulse) plus the `WorkoutLiveActivity`. Predicted workout and weekly volume both exist. Mark the CLAUDE.md line for removal (see WGD-45).

Vocabulary: "snapshot" = `OreWidgetSnapshot` JSON in the App Group (`group.com.pulse.PulsePump`, key `widget_snapshot`); "fixed" = `snap._fixed` (`PWFixedData`). Family sizes are drawn at design points (small 170x170, medium 364x170, large 364x382) and scaled by `PWHost`.

## WGD  Data pipeline: snapshot, App Group, refresh

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WGD-03 | System: app is active on the main route → App rebuilds the snapshot from all non-draft, non-deleted workouts (`WidgetDataService.updateWidgetData`) and writes it to the App Group, then calls `WidgetCenter.reloadAllTimelines()` (`RootView.swift:84`) | ✅ | [ ] | — |
| WGD-06 | System: first time the route becomes `.main` (launch / after onboarding / restore) → App rebuilds the snapshot once (`RootView.swift:94`) | ✅ | [ ] | — |
| WGD-09 | User finishes a workout → App rebuilds the snapshot before showing the completion summary (`WorkoutViewModel.swift:378`), so the Recap, Streak, Next workout widgets reflect the session | ✅ | [ ] | — |
| WGD-12 | User changes the weight unit (kg/lbs) → App rebuilds the snapshot (`RootView.swift:80`); `snapshot.weightUnit` flips and all widgets relabel on next reload. Stored numbers stay kg | ✅ | [ ] | — |
| WGD-15 | System: StoreKit entitlement refreshes → `setSubscribed` writes `widget_isPlusSubscribed` and patches only `fixed.isPlus` into the stored snapshot, then reloads timelines (no full rebuild) | ✅ | [ ] | — |
| WGD-18 | System: the social feed loads a non-empty page → `writeFriends` stores the 3 most recent friend sessions (own posts excluded, warm-ups excluded) under `widget_friends` and patches `fixed.friends`; empty/failed fetch does not overwrite (`SocialViewModel.swift:477`) | ✅ | [ ] | — |
| WGD-21 | System: the user saves their profile or finishes onboarding with a weight → One bodyweight point per calendar day is appended to the App Group `BodyweightLog` (also on every snapshot rebuild) (same day: last write wins; max 400 entries) | ✅ | [ ] | — |
| WGD-24 | System: snapshot is built → `hasData` is true only if at least one finished workout exists; `updated` = build time; `weekNumber` = ISO week; week starts Monday (ISO-8601 calendar); `sessionGoal` = number of days of the selected split, else 5 | ✅ | [ ] | — |
| WGD-27 | System: widget timeline requested → Provider reads the stored snapshot only (never SwiftData/Firebase) and schedules the next reload `.after` 30 minutes. WidgetKit may delay this; a reload also happens whenever the app calls `reloadAllTimelines` | ✅ | [ ] | — |
| WGD-30 | System: the stored snapshot has `hasData == false` (no workouts, or never written) → Widgets draw a real empty snapshot, not the design sample; only the genuine Plus flag is kept (`OreWidgetSnapshot.resolved`) | ✅ | [ ] | — |
| WGD-33 | System: WidgetKit asks for a placeholder or the widget-gallery preview (`context.isPreview`) → Widgets draw `OreWidgetSnapshot.sample` (numbers from the design, Plus unlocked, 12-day streak) | ✅ | [ ] | — |
| WGD-36 | User signs out / account is wiped → `SyncAccount.wipe` removes `widget_snapshot`, `custom_widget_library`, `widget_friends` and the legacy `widget_*` keys and clears the bodyweight log. It does NOT call `reloadAllTimelines`, so already-rendered widgets keep the old picture until the next timeline refresh (up to ~30 min) | 🟡 | [ ] | — |
| WGD-39 | System: legacy "Ore" widget refresh → `updateWidgetData` also writes the flat keys `widget_streak`, `widget_lastWorkoutName/Date`, `widget_exerciseCount`, `widget_durationMinutes`, `widget_recentWorkouts` (3 items) that only the legacy `OreWidget` reads | ✅ | [ ] | — |
| WGD-42 | User opens More › Widgets → App builds a throw-away snapshot in memory for previews (`WidgetsView.load`, `buildSnapshot`); this does NOT save it to the App Group | ✅ | [ ] | — |
| WGD-45 | Owner edits CLAUDE.md → The "Widget extension shows streak only" known-gap line should be replaced by the real gaps in WGD-51 and WGT-30 | 🐞 CLAUDE.md "Known Gaps" is stale (see intro) | [ ] | — |
| WGD-48 | System: Supernova flag computed for widgets → `isPlus = widget_isPlusSubscribed or SupernovaService().isInFreeTrial` (14 days from `appInstallDate`; first call also records the install date) | ✅ | [ ] | — |
| WGD-51 | System: snapshot freshness → The snapshot is NOT rebuilt after editing/deleting a past workout, discarding a draft, importing history, editing templates/splits, or edit of bodyweight outside the profile editor. Widgets (streak, volume, next workout) stay stale until the app next becomes active | 🟡 stale until next foreground | [ ] | — |
| WGD-54 | System: a day rolls over while the app is closed → Widgets keep the last snapshot's "today" (streak squares, today bar, "NEXT · day", GOAL "n DAYS" line) until the app is next opened; the 30-minute timeline only re-reads the stored snapshot | 🟡 | [ ] | — |

### WGD edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| WGD-E01 | App Group container unavailable (misconfigured entitlement) | `updateWidgetData` returns silently; widgets show the empty state | Both targets carry `group.com.pulse.PulsePump` | ✅ | [ ] | — |
| WGD-E02 | Free trial expires on day 15 while the app is closed | Locked widgets stay unlocked until the app refreshes the snapshot; then Plus widgets flip to the locked preview | `isPlus` is baked into the snapshot at build time | 🟡 | [ ] | — |
| WGD-E03 | Older stored snapshot without `weightUnit` / `_fixed` | Decodes (both optional); unit defaults to KG, fixed defaults to empty | Forward-compatible by design | ✅ | [ ] | — |
| WGD-E04 | Snapshot JSON fails to decode | `loadSnapshot` returns an empty `OreWidgetSnapshot()` (`hasData == false`) so widgets show the empty state | | ✅ | [ ] | — |
| WGD-E05 | Large history (hundreds of workouts) | Snapshot build is O(n^2) on the main thread at every foreground (`improvements()` per week workout) | Known perf finding, docs/audit | 🟡 | [ ] | — |
| WGD-E06 | Draft workout in progress | Drafts (`isDraft`) and soft-deleted workouts are excluded from every figure | | ✅ | [ ] | — |
| WGD-E07 | Warm-up sets | Excluded from sets, volume, PR watch, e1RM, body-map sets | `setType != .warmup` | ✅ | [ ] | — |
| WGD-E08 | Phone offline | No effect; the widget never touches the network. Friends widget shows the last stored friends | | ✅ | [ ] | — |
| WGD-E09 | Fuel / Stride rows | Read from App Group keys `pulse_eco_fuel` / `pulse_eco_stride` written by those (not yet shipped) apps; absent → `—` | See WGT-147 | ✅ | [ ] | — |

## WGT  Fixed widgets (home and lock screen)

Common to every fixed widget: background = `OreTheme.canvas` via `containerBackground`; content margins disabled; Layout A/B chosen in the widget's Edit Widget sheet (`PWVariantIntent`, default A); numbers in Space Mono, headers in Archivo; no drop shadows.

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WGT-03 | User adds "Next workout" (small/medium/large, lock rectangular, lock inline) → Shows the predicted session: name (uppercased), "NEXT · {today's weekday}", 5-square confidence, exercises/sets/est. minutes. Data: `snap.nextName/nextDay/nextExercises/nextEstMinutes/nextFirst`, `fixed.nextConfidence/nextDate/nextSplitLine/nextSets/nextExerciseList/nextLastSameDays/nextLastSameName`; written by `buildSnapshot` + `buildFixed` | ✅ | [ ] | — |
| WGT-06 | User views Next workout small A → Name, "{n} EX · {sets} SETS · ~{min}M", confidence dots, full-width "START ›" button | ✅ | [ ] | — |
| WGT-09 | User views Next workout small B → "NEXT WORKOUT", name, "FIRST UP", first lift name, "{sets}x{reps} · {kg} {KG/LB}", dots with HIGH, MED or LOW CONF label (>=0.7 / >=0.4 / below) | ✅ | [ ] | — |
| WGT-12 | User views Next workout medium A → Left: "NEXT · PREDICTED", name, "{n} EX · ~{m} MIN", dots, "START WORKOUT ›". Right: first 4 exercises with target "4x6" and "+{n} MORE" | ✅ | [ ] | — |
| WGT-15 | User views Next workout medium B → Header "LAST {PUSH} · {n} DAYS AGO" and three stat cells EXERCISES / SETS / EST MIN | ✅ | [ ] | — |
| WGT-18 | User views Next workout large → "NEXT · {FRI 9 OCT}" (tomorrow's date once trained today), split line ("{SPLIT NAME or detected PUSH PULL LEGS / UPPER LOWER / FULL BODY / PROGRAM} · WK {n}"), table of up to 6 exercises with SETS and unit columns, "START WORKOUT ›" | ✅ | [ ] | — |
| WGT-21 | User views lock-screen Next workout (rectangular / inline) → Rectangular: "NEXT · {day}", name, "{n} EX · ~{m} MIN". Inline: "{DAY d} · {NAME} NEXT". Both white-on-clear, no Plus gate | ✅ | [ ] | — |
| WGT-24 | System: Next workout has no prediction (no template history / no split) → Name shows "—", meta "0 EX · 0 SETS · ~0M", dots "LOW CONF" (confidence 0); START still renders | 🟡 no dedicated empty copy (see WGT-E01) | [ ] | — |
| WGT-27 | User taps START on Next workout (medium/large) → Opens `pulsepump://start-workout?template={name}`; app starts that template as a new workout and the logger opens (see WGT-144 and LIV-E03) | ✅ | [ ] | — |
| WGT-30 | User taps START on a SMALL Next workout or SMALL Quick start tile → Layout uses `Link`, but WidgetKit honours only `widgetURL` for systemSmall; no `widgetURL` is set on fixed widgets, so the tap likely just opens the app (home) without starting a workout. Custom widgets do set `widgetURL` for small | 🐞 `OreShared/Widgets/NextWorkoutWidget.swift:174`, `QuickStartWidget.swift:49` (verify on device: expected "starts workout", likely actual "opens app") | [ ] | — |
| WGT-33 | User adds "Streak" small A → "STREAK", count + "DAYS", 7 squares for the last 7 days (oldest left, today right, filled = a workout that day) with weekday letters. Data: `snap.streak` (`StreakCalculator.currentStreak`), `fixed.streakLogged/streakLetters` | ✅ | [ ] | — |
| WGT-36 | User views Streak small B → Big count + "DAY STREAK", "LAST · {NAME} · {WED}", Mon-Sun set bars (done = ink, today = accent, none = faint). Data `fixed.weekSetsPerDay/weekDone/todayIndex/lastWorkout*` | ✅ | [ ] | — |
| WGT-39 | User views Streak medium → Left: count + squares; right: "LAST WORKOUT", name, "{n} DAYS AGO", EX and MIN stats | ✅ | [ ] | — |
| WGT-42 | User views Streak large → Count, "START ›" (opens next workout), week bars, "RECENT / WK n" list of 3 sessions ("WED · 2 DAYS AGO", "6 EX · 58M"; 0 → "TODAY", 1 → "1 DAY AGO") | ✅ | [ ] | — |
| WGT-45 | User views Streak medium with last workout yesterday → Text reads "1 DAYS AGO" (no singular), unlike Recap which writes "1 DAY AGO" | 🐞 `OreShared/Widgets/StreakWidget.swift` medium ("\(daysAgo) DAYS AGO"); expected "1 DAY AGO" | [ ] | — |
| WGT-48 | User adds the Streak lock-screen circular → Count and "DAYS" on the system accessory disc | ✅ | [ ] | — |
| WGT-51 | User adds "Weekly volume" small A → "SETS · WK n", sets this week, signed % vs last week up to the same weekday (green ▲ / red ▼), "VS LAST {n}". Data `fixed.setsThisWeek/setsLastWeekSameDay` (working sets) | ✅ | [ ] | — |
| WGT-54 | User views Weekly volume small B (ticker surface) → Three quotes: SETS, VOL (T in kg / KLB in lb, from `volumeTonnes`, converted), HRS (`trainingHours` "h:mm"), each with ▲/▼ %. Header "WK n VS n-1" and today's weekday | ✅ | [ ] | — |
| WGT-57 | User views Weekly volume medium → Left big sets + delta + "{n} SAME DAY LAST WK"; right paired Mon-Sun bars this week vs last week (bar scale 30 sets = full height; today in accent) | ✅ | [ ] | — |
| WGT-60 | User adds Weekly volume lock rectangular → "SETS · WK n", sets, delta (hidden when last week is 0), "VS n LAST WK" | ✅ | [ ] | — |
| WGT-63 | User looks for Weekly volume in Large → Not offered (families: small, medium, lock rectangular) | ✅ | [ ] | — |
| WGT-66 | System: last week had 0 sets (first week of use) → Delta shows "+0.0%" in green (`pctDelta` returns 0 when the base is 0). Not hidden except on the lock widget | 🧭 propose "NEW" or hide the delta when there is no comparison | [ ] | — |
| WGT-69 | System: first ISO week of the year → Small B header reads "WK 1 VS 0" | 🐞 `WeeklyVolumeWidget.swift:64` (`weekNumber - 1`, no wrap to 52/53) | [ ] | — |
| WGT-72 | User adds "Body map" (Plus) → Front silhouette shaded by `snap.bodyVolume` (sets in 7 days / per-region target, 0-1) or `snap.bodyRecency` (fade over 48 h) per the "Shows" option (Volume · 7 days / Recency · days since trained); layout A/B | ✅ | [ ] | — |
| WGT-75 | User views Body map small A/B → A: silhouette + "NEGLECTED" list of 3 (muscle, days since, red). B: silhouette + the single most neglected muscle. "Neglected" = longest since trained, never-trained first (`fixed.neglected`, 9 heat groups, shows `—` if never) | ✅ | [ ] | — |
| WGT-78 | User views Body map medium / large → Medium: "TOP · SETS 7D" (top 4, `fixed.topMuscles`) and "NEGLECTED". Large: table of 10 muscles with SETS and LAST; "stale" (red) when 0 sets in 7 days or last trained more than 5 days ago | ✅ | [ ] | — |
| WGT-81 | User adds "Muscle balance" (Plus) small/medium → Push:Pull, Upper:Lower, Anterior:Posterior over the last 28 days of working sets, with ratio, split bar and flag. Flagged when outside 0.80-1.25 (push:pull, ant:post) or 0.67-1.50 (upper:lower): "▼ PULL -14 SETS" else "IN RANGE"; no sets → "NO DATA" and ratio "—" | ✅ | [ ] | — |
| WGT-84 | User views Balance small A / B / medium → A: first ratio hero (e.g. "1.41 : 1") + bar + flag. B: two ratios. Medium: three rows with set counts | ✅ | [ ] | — |
| WGT-87 | System: Balance widget has no data (no workouts) → Small A draws nothing at all (`balances` empty); small B/medium draw only their headers | 🟡 blank widget, no empty copy | [ ] | — |
| WGT-90 | User adds "PR watch" (Plus) small/medium/large → Lifts among Bench Press, Overhead Press, Barbell Row, Squat, Deadlift whose 4-week best e1RM is within 5% of their all-time best e1RM, closest first (max 5); if none are close, the 3 closest. e1RM = Epley `w*(1+reps/30)`; 12 weekly e1RM points (gaps carried forward) | ✅ | [ ] | — |
| WGT-93 | User views PR watch layouts → 6A: closest lift, e1RM, "PR" (underlined, not coloured), gap, sparkline. 6B: three rows "{short} {pct}%" and "e1RM / PR unit". Medium: 3 rows with 12W sparkline, E1RM, PR. Large: sparkline of top lift + table of up to 5 with GAP | ✅ | [ ] | — |
| WGT-96 | User compares widget "PR" with the app's PR rule → The widget's PR figure is the best estimated 1RM, not the heaviest weight lifted, and gets the "PR" label; the app's PR detection (weight PR / rep PR) differs | 🟡 label mismatch; intentional per test `prWatchComparesBestE1RMToBestE1RMNotWeight` | [ ] | — |
| WGT-99 | User adds PR watch lock rectangular on a free account → Shows the lift closest to its record with "e1RM / PR unit" and is NOT locked, although the gallery tier says "FREE · PLUS" and the home sizes of PR watch are Plus | 🧭 propose: gate behind Plus (`PRWatchDesc.view`) | [ ] | — |
| WGT-102 | User adds "Deload and recovery" (Plus) small/medium → Block week "BLOCK · WK n/6" and headline "DELOAD NEXT WEEK / IN n WEEKS / THIS WEEK"; load = sets x RPE (RPE = 10 - RIR, default 7), 8 past weeks + next-week slot; a past week is a deload if weekly load < 60% of the prior-4-week average or any workout flagged `isDeload`. Load ratio = this week so far vs 4-week average over the same elapsed time | ✅ | [ ] | — |
| WGT-105 | User views Deload small A / B / medium → A: headline + mini load bars + ratio. B: ratio "1.18" "VS 4-WK AVG", "DELOAD WK n" and "LAST WK n" (`—` if none). Medium: labelled bars ("D" over deload weeks), ratio and +/- delta vs last week | ✅ | [ ] | — |
| WGT-108 | System: `isDeload` flag on a workout → Forces that week to count as a deload. No in-app UI sets the flag (only sync can); detection effectively relies on the 60% rule | 🟡 | [ ] | — |
| WGT-111 | User adds "Last session" small/medium → Name, weekday, volume (display unit, thousands separator), delta vs the previous session of the same template name (first time: +0.0%), sets, time "mm:ss", and, when an exercise beat every earlier e1RM, a PR row with "weight x reps" in the display unit. Data `fixed.recap*` + `lastWorkout*` | ✅ | [ ] | — |
| WGT-114 | System: Recap small shows a PR → Label on the left is the literal text "ROW" for any exercise (medium shows the real name) | 🐞 `OreShared/Widgets/RecapWidget.swift:26`; expected the PR exercise name (shortened), actual always "ROW" | [ ] | — |
| WGT-117 | User adds "Program" small/medium → Active split name, week "n/8" in an 8-week block (weeks since the first matching template session or split creation, mod 8, +1), tick row, "{done}/{target} SESSIONS THIS WK". Medium: up to 4 day tiles (last done days "✓ MON", then "NEXT", then upcoming "—") | ✅ | [ ] | — |
| WGT-120 | System: no split selected → Name "Program"; target falls back to `sessionGoal` (5); upcoming tiles come from the repeating cycle in history; otherwise only the done tiles | 🟡 | [ ] | — |
| WGT-123 | User adds "Weekly goal" small or circular lock → "GOAL · WK n", "{done}/{goal}" and one square per session (min 1), line "{n} LEFT · {d} DAYS" (d = 6 - today's Monday-index). Lock circular: "{done}/{goal}" and squares (opacity 1 vs 0.3) | ✅ | [ ] | — |
| WGT-126 | System: goal reached (done >= goal) → "0 LEFT · n DAYS", all squares filled; done count above the goal is not capped in the number ("6/5") | 🟡 | [ ] | — |
| WGT-129 | User adds "Bodyweight" small → "BODYWEIGHT", `User.weight` in display unit (1 decimal), "▼/▲/• {+delta} · 7D" in neutral ink (never red/green), 30-day sparkline (gaps carried forward), start date "6 SEP" and "TODAY". Data `snap.bodyweight`, `fixed.bodyweightSeries/Delta7d/Start` from `BodyweightLog` | ✅ | [ ] | — |
| WGT-132 | System: bodyweight never entered → Shows "0.0 KG", "• 0.0 · 7D" and no sparkline | 🟡 no "add your weight" empty state | [ ] | — |
| WGT-135 | User adds "Friends" medium → Up to 3 rows: initials tile, "Name . Workout", meta ("PR . BENCH PRESS 100x5" or "18 SETS . 55 MIN"), age (M / H / D). Data `fixed.friends` written by the feed load | ✅ | [ ] | — |
| WGT-138 | System: feed never loaded / no friends → Friends widget shows only the "FRIENDS" header with no rows | 🟡 | [ ] | — |
| WGT-141 | User adds "Quick start" small/medium → Small: 2 tiles, medium: 4 tiles in a 2x2 grid; first tile is the predicted template (accent fill, "PREDICTED . n EX"), the rest ordered by most recent use then name; up to 6 templates stored. Each tile is a link to `start-workout?template={NAME}` | ✅ | [ ] | — |
| WGT-144 | User taps a Quick start tile (medium) → Link carries the template name UPPERCASED (`q.name`); app matches templates by exact name, so a mixed-case template name does not match and a BLANK workout starts instead | 🐞 `QuickStartWidget.swift:47` (passes `q.name`, uppercased by `buildFixed`) vs `ContentView.swift:64` (`$0.name == name`); expected the chosen template, actual blank workout for any template that is not all caps | [ ] | — |
| WGT-147 | User adds "Pulse" medium → Rows ORE (sessions this week / goal), FUEL (KCAL TODAY), STRIDE (KM THIS WK); Fuel/Stride read from App Group keys written by those apps, else `—` | ✅ | [ ] | — |
| WGT-150 | User views Pulse widget → ORE square in accent, FUEL/STRIDE marks in ink (accents unresolved per design) | ✅ | [ ] | — |
| WGT-153 | User adds the legacy "Ore" widget (small/medium/large) → Flame + streak count, last workout, recent list; plain system fonts, `.fill.tertiary` background; tap opens `pulsepump://home` (a host the app ignores) or `start-workout` button on large | 🟡 legacy, off-design, redundant with Streak | [ ] | — |
| WGT-156 | System: widget picker lists → Display names: Ore (legacy), Ore Custom, Next workout, Streak, Weekly volume, Body map, Muscle balance, PR watch, Deload and recovery, Last session, Program, Weekly goal, Bodyweight, Friends, Quick start, Pulse | ✅ | [ ] | — |

### WGT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| WGT-E01 | Brand-new user, no workouts, widget added | Real empty snapshot: zeros and `—`, empty bars/squares, Plus locked; no "log your first workout" prompt | see Open decisions | 🟡 | [ ] | — |
| WGT-E02 | lbs user | Every weight (next-lift kg column, recap volume, PR watch, bodyweight, 3B volume "VOL KLB") converts via `snap.unit`; labels "LB" | Stored kg; `weightUnit` in snapshot | ✅ | [ ] | — |
| WGT-E03 | Unit changed but app not opened | Widgets keep the old unit until the app next refreshes (the unit change itself triggers a rebuild, WGD-12) | | ✅ | [ ] | — |
| WGT-E04 | Free user, Plus widget (Body map, Balance, PR watch, Deload) added | Shows `LockedWidgetPreview` (see WGP) instead of data | | ✅ | [ ] | — |
| WGT-E05 | Dark mode / light mode | Colours are dynamic (`OreTheme.dyn`), so the widget follows the system appearance; accent `#1AA7FF` in both | | ✅ | [ ] | — |
| WGT-E06 | iOS tinted home-screen mode | No `widgetAccentable` / rendering-mode handling in the code, so the system applies its default tint; the in-app gallery "TINTED" tab is only a grayscale+blue simulation | | 🟡 | [ ] | — |
| WGT-E07 | Template renamed or deleted after the snapshot | START/Quick start tile with the old name starts a blank workout (no match) until the next refresh | | 🟡 | [ ] | — |
| WGT-E08 | Very long workout name | One line, scaled down to 70% (`minimumScaleFactor 0.7`) then truncated | | ✅ | [ ] | — |
| WGT-E09 | Two workouts the same day | Streak squares show one square per day; sets and volume add up; Program "done" count counts sessions (2) | `weekWorkouts.count` | ✅ | [ ] | — |
| WGT-E10 | Monday as week start in a US-locale phone | Widgets always use the ISO calendar (Monday first); weekday letters on the streak strip are the last 7 calendar days (S M T W T F S), not Monday-based | | ✅ | [ ] | — |
| WGT-E11 | Time zone / DST change | Day buckets use the device calendar at build time; not rebuilt until next foreground | See WGD-54 | 🟡 | [ ] | — |
| WGT-E12 | Day label on a day already trained | "NEXT . {weekday}" is today's weekday even after training today, while large shows tomorrow's date (`nextDate`) | `nextDay` vs `nextDate` inconsistent | 🟡 | [ ] | — |

## WGP  Plus-locked state and deep links

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WGP-03 | User (free, trial over) views a Plus widget → `PWPlusGate` renders `LockedWidgetPreview`: lock glyph + "SUPERNOVA", feature title (Muscle heatmap / PR watch / Muscle balance / Deload and recovery), a one-line fact, and a full-width accent "UNLOCK SUPERNOVA" button; ghost silhouette or ghost rows at 0.18 opacity | ✅ | [ ] | — |
| WGP-06 | User taps "UNLOCK SUPERNOVA" (medium/large) → Opens `pulsepump://supernova`; app posts `.openSupernova`, switches to the More tab (tab 4) and presents Supernova full screen | ✅ | [ ] | — |
| WGP-09 | User taps the SMALL locked preview → Same `Link` limitation as WGT-30: a small widget cannot host Link, so the tap probably only launches the app | 🐞 `LockedPreviewWidget.swift:34-40` (verify on device) | [ ] | — |
| WGP-12 | User (trial or subscribed) views a Plus widget → Real content is drawn; `fixed.isPlus` true | ✅ | [ ] | — |
| WGP-15 | User sees locked preview in Large → App: Large gate reuses the medium layout inside the large frame (Body map and PR watch support large) | 🟡 | [ ] | — |
| WGP-18 | User taps the tinted home-screen / lock-screen widget body (not a button) → Opens the app at its last tab; no `widgetURL` on fixed widgets except custom small | ✅ | [ ] | — |
| WGP-21 | User with a built Ore Custom widget loses Plus → The widget keeps rendering (custom widgets are not gated in the extension); only the More › Widgets builder row is Plus/trial gated (`MoreTabView.swift:103`) | 🧭 propose: leave as is or lock custom widgets after trial | [ ] | — |

## WGU  Units and appearance

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WGU-03 | User with kg preference → Widgets print numbers from kg with label "KG"; 1 decimal where used (`%.1f`) | ✅ | [ ] | — |
| WGU-06 | User with lbs preference → `unit.display(kg)` (kg / 0.45359237) with label "LB"; recap PR text uses `number()` (0.5 lb steps) | ✅ | [ ] | — |
| WGU-09 | System: locale uses decimal comma → Widget numbers are formatted with `String(format:)` (always a dot) and `NumberFormatter` for thousands in recap volume (locale separator) | 🟡 mixed separators | [ ] | — |
| WGU-12 | User switches the system to dark appearance → All widgets and the lock-screen card re-theme; the island is always black and uses the dark-mode values | ✅ | [ ] | — |

## WGB  Widget builder ("Ore Custom") and library

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WGB-03 | User opens More › Widgets while free and past the trial → App opens the Supernova screen instead (row tagged "SUPERNOVA") | ✅ | [ ] | — |
| WGB-06 | User opens More › Widgets with Plus or trial → Library screen "WIDGETS" with intro text, "MY WIDGETS n", rows (thumbnail, name, "{SIZE} . {n} PIECES . {TODAY/nD AGO/nW AGO}"), "NEW" button, "+ NEW WIDGET", "PREVIEW > Widget gallery" | ✅ | [ ] | — |
| WGB-09 | System: first visit with an empty library → App seeds 4 presets (Gym glance medium, PR board small, Full board large, Lock glance lock) and saves them | ✅ | [ ] | — |
| WGB-12 | User long-presses a library row → Context menu "Delete" removes it immediately and saves; no confirmation, no timeline reload | 🟡 | [ ] | — |
| WGB-15 | User taps NEW → Builder opens with name "Custom {n+1}", size SMALL, no pieces. There is no rename control | 🟡 name can't be edited | [ ] | — |
| WGB-18 | User taps a size chip (SMALL 4x4, MEDIUM 8x4, LARGE 8x8, LOCK 4x2 cells) → Canvas resizes; pieces are re-packed with "tidy"; pieces that do not fit are dropped with toast "{n} PIECE(S) DIDN'T FIT"; Body map is dropped on LOCK | ✅ | [ ] | — |
| WGB-21 | User taps a tray item → Piece is auto-placed at the first free spot (reading order) at its first allowed size; toasts "NO ROOM . TIDY OR REMOVE A PIECE" when full | ✅ | [ ] | — |
| WGB-24 | User drags a tray item onto the canvas → Snaps to the nearest free cell with a preview; falls back to the piece's other sizes; dropping outside cancels | ✅ | [ ] | — |
| WGB-27 | User drags a placed piece off the canvas (more than 24pt outside) → Piece is removed, toast "PIECE REMOVED" | ✅ | [ ] | — |
| WGB-30 | User taps a placed piece → Config panel: SIZE chips for allowed sizes, "SHOWS" options (or EXERCISE search / TEMPLATE list), "Remove piece", DONE; "NO ROOM AT THAT SIZE" if resize cannot fit | ✅ | [ ] | — |
| WGB-33 | User picks piece types → 8 types: Single stat (streak, sessions this week, lifts improved, biggest gain, bodyweight), Exercise PR (any exercise, top 40 matches), Week bars (sets / volume / improved per day), Line chart (bench e1RM, squat e1RM, bodyweight), Body map (volume / recency), Next workout (with START / first exercise), Start button (a template), Progress squares (weekly goal / program weeks) | ✅ | [ ] | — |
| WGB-36 | User drags Body map onto LOCK size → Toast "BODY MAP ISN'T AVAILABLE ON LOCK SCREEN"; tray item dimmed | ✅ | [ ] | — |
| WGB-39 | User taps TIDY / CLEAR → TIDY packs top-left in reading order (toast "TIDIED"); CLEAR removes all pieces without confirmation | ✅ | [ ] | — |
| WGB-42 | User taps SAVE with no pieces → Toast "ADD A PIECE FIRST", stays in builder | ✅ | [ ] | — |
| WGB-45 | User taps SAVE → Widget stored in the App Group library (`custom_widget_library`), `reloadAllTimelines()` called, builder closes | ✅ | [ ] | — |
| WGB-48 | User taps back without saving → Edits are discarded with no confirmation | 🟡 | [ ] | — |
| WGB-51 | User re-opens a saved widget and adds a piece → New piece id restarts at "n1", colliding with an existing "n1" | 🐞 `WidgetBuilderView.swift:29,426` (`@State seq = 1`); expected unique ids | [ ] | — |
| WGB-54 | User adds "Ore Custom" on the home screen → Edit Widget lists saved widgets (`CustomWidgetQuery`); default = first; supports small, medium, large and lock rectangular; refreshes every 30 min | ✅ | [ ] | — |
| WGB-57 | System: the chosen widget was deleted → Provider silently falls back to the first library widget; empty library → "ORE / Build a widget in More > Widgets" | ✅ | [ ] | — |
| WGB-60 | User taps a Next workout (START) or Start button piece in medium/large → Link opens `start-workout` (+ template name exact as stored, so not uppercased). In SMALL, whole widget uses `widgetURL` of the first start/next piece | ✅ | [ ] | — |
| WGB-63 | System: user has no workouts → Custom pieces render the catalog's fake sample values (streak 12, 4/5, PR 100, etc.) because `metric(for:)` returns the sample when `hasData` is false | 🐞 `OreWidgetSnapshot.swift` `metric(for:)` guard `hasData`; unlike the fixed widgets, no empty state | [ ] | — |
| WGB-66 | System: user has data and uses Line chart "Bodyweight, 30 days" → Always draws the hard-coded sample series and "82.4 KG" | 🐞 `OreWidgetSnapshot.swift:104` (`piece.metric != "bw"`) | [ ] | — |
| WGB-69 | System: Exercise PR piece for an exercise never logged → Shows `—`; matching is exact then "contains" ignoring incline/decline/dumbbell/close/smith variants (`bestPR`) | ✅ | [ ] | — |

### WGB edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| WGB-E01 | Delete every widget, reopen the screen | Library empty on disk, so presets are re-seeded on the next open | `stored.isEmpty` check | 🟡 | [ ] | — |
| WGB-E02 | Template named in a Start button piece is deleted/renamed | Piece keeps the old name; tapping starts a blank workout | | 🟡 | [ ] | — |
| WGB-E03 | Piece stored beyond the grid (corrupt data) | Occupancy loop clamps to the grid but a start index out of range can trap | docs/audit LOW | 🟡 | [ ] | — |
| WGB-E04 | lbs user | Piece values convert from the snapshot (`fmtW`, `unit.display`); the catalog sample strings are KG | | ✅ | [ ] | — |
| WGB-E05 | Edit widget while builder open on another device | Library is local (App Group); it is not synced | | ✅ | [ ] | — |

## WGG  Widget gallery and debug flags

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WGG-03 | User opens More › Widgets › Widget gallery → Full-screen "WIDGET GALLERY" with LIGHT / DARK / TINTED chips; 17 numbered sections (01 Next workout to 17 Locked preview) with tier (FREE / PLUS / FREE . PLUS) and blurb; each variant drawn at design scale on a wall | ✅ | [ ] | — |
| WGG-06 | System: gallery draws content → Always uses `OreWidgetSnapshot.sample` (design numbers, Plus unlocked), never the user's real data | 🟡 header text claims "what WidgetKit draws" but data is sample | [ ] | — |
| WGG-09 | User taps TINTED → Gallery applies grayscale + brightness + blue colour blend as an approximation (not a real WidgetKit tinted render) | 🟡 | [ ] | — |
| WGG-12 | DEBUG only: launch with `-debugGallery <section id or all>` → Root view is the gallery (no onboarding); `-debugGalleryTheme` (light, dark or tinted) picks the theme; `-debugGalleryDump 1` renders each section x theme to PNG in tmp; `-debugWidgetEdit <id>` opens the builder on a saved widget. Compiled out of Release | ✅ | [ ] | — |
| WGG-15 | User views section 08 and 16 → Live Activity / Dynamic Island variants (8A-8H) and lock-screen accessories (circular, rectangular, inline) are drawn as static previews (plain labels, no live clocks) | ✅ | [ ] | — |

## LIV  Live Activity and Dynamic Island

Attributes: `WorkoutActivityAttributes(workoutName, startTime)`; state `ContentState` carries elapsed, current exercise (+ short name), completed/total sets, set index/count, next weight/reps (display unit), unit label, rest start/end dates, `restOverSince`, last-time line and date. `Info.plist`: `NSSupportsLiveActivities` and `NSSupportsLiveActivitiesFrequentUpdates` true.

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| LIV-03 | User starts a workout (blank, template, or widget link) → App requests a Live Activity named after the template (or "Workout") with initial state exercise "Starting...", 0 sets; silently skipped when `areActivitiesEnabled` is false or the request throws | ✅ | [ ] | — |
| LIV-06 | System: workout active → A 1-second timer builds the state and calls `updateLiveActivity`; the call returns early unless something visible changed (`isVisiblyUnchanged` ignores `elapsedSeconds` and `restSecondsRemaining`, since the views run their own clocks from dates) | ✅ | [ ] | — |
| LIV-09 | User views the lock screen while lifting → Card: workout name, "{done}/{total} SETS", hero "ELAPSED" clock, "NOW . SET i/n" with exercise and "{weight} {KG/LB} x {reps}", tick row (done = ink, current = accent), accent "✓ LOG SET" button | ✅ | [ ] | — |
| LIV-12 | User logs a set and auto-rest starts → State gets `restStartDate/EndDate`; lock screen switches to "REST NN:NN" hero (accent), "NEXT . SET", progress bar, buttons "-15S", "+15S", "SKIP >" | ✅ | [ ] | — |
| LIV-15 | User taps "✓ LOG SET" in the Live Activity → `LogSetIntent` posts a notification the active `WorkoutViewModel` observes; it marks the next incomplete set done using planned weight/reps (typed, else ghost from last session, else previous set, else template target) and pushes the new state immediately | ✅ | [ ] | — |
| LIV-18 | User taps "+15S" / "-15S" → `AdjustRestIntent` calls `restTimer.adjust(by:)`; if the new end is in the past the rest completes (alert), else the end date moves and the rest notification is rescheduled; state pushed immediately | ✅ | [ ] | — |
| LIV-21 | User taps "SKIP >" → `SkipRestIntent` calls `restTimer.skip()` (stop, no alert sound); card returns to the lifting layout | ✅ | [ ] | — |
| LIV-24 | System: rest reaches zero while the app is running → State has `restOverSince`; first flip to rest-over issues an alert update (title "Rest done", body "Log your next set", default sound) which auto-expands the island; card shows "REST DONE" and a counting-up "+m:ss" | ✅ | [ ] | — |
| LIV-27 | System: the activity goes stale (`staleDate = restEndDate`) or the end date is past → The views treat it as rest-over (`isStale or end <= now`) even if the app could not push an update | ✅ | [ ] | — |
| LIV-30 | User looks at the compact island → Lifting: accent square + short exercise name (6 chars) on the left, "{weight}x{reps}" on the right. Resting: "REST" left, countdown right. Rest over: "DONE" and next set in accent | ✅ | [ ] | — |
| LIV-33 | User looks at the minimal island → Resting: seconds left in accent; otherwise "x{reps}" (accent when rest is over) | ✅ | [ ] | — |
| LIV-36 | User long-presses the island (expanded) → Leading: hero (REST clock, or NOW exercise/set with big "{weight}x{reps}"); trailing: "{done}/{total} SETS DONE" or "+m:ss OVER REST"; bottom: rest bar with "+15S" and "SKIP >" (no -15S) when resting, otherwise ticks, "LAST TIME . {template . m:ss}" line and "✓ LOG SET" | ✅ | [ ] | — |
| LIV-39 | System: unit is lbs → `nextWeight` converted for display (`displayText(kgString:)`), `weightUnit` "LB"; last-time line uses display numbers. Stored values stay kg | ✅ | [ ] | — |
| LIV-42 | User finishes the workout → `completeWorkout` stops the duration timer, removes observers and ends the activity with final state "Complete" and default dismissal (stays on the lock screen until the system or user dismisses it); widgets get a new snapshot (WGD-09). The final zeroed state renders in the lifting layout (exercise "Complete", "0/0 SETS") | 🟡 | [ ] | — |
| LIV-45 | User discards the workout → `cancelWorkout` stops the timer, ends the activity, deletes the draft | ✅ | [ ] | — |
| LIV-48 | User chooses "Save as draft" → `saveDraftAndClose` persists, stops the timer and ends the Live Activity | ✅ | [ ] | — |
| LIV-51 | User taps Continue on a saved draft → `resumeDraft` starts a fresh Live Activity and a new 1-second timer with elapsed time restored from `workout.duration` | ✅ | [ ] | — |
| LIV-54 | User taps a Live Activity → Opens the app; no custom URL, lands where the app was | ✅ | [ ] | — |
| LIV-57 | System: nothing to do next (all sets complete) → `nextSetPosition` is nil: state is rebuilt with exercise "Rest", set 0/0 and no weight/reps; LOG SET is still shown and tapping it does nothing (`guard` returns) | 🟡 | [ ] | — |

### LIV edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| LIV-E01 | Live Activities disabled in iOS Settings | No activity is created; workout works normally | `areActivitiesEnabled` | ✅ | [ ] | — |
| LIV-E02 | App killed or crashed mid-workout, then user resumes the draft | The old activity is not tracked after relaunch (`currentActivity` nil, no `Activity.activities` lookup), so `resumeDraft` creates a second one; two cards can show for the same workout and the orphan never ends until the system expires it | Dedupe is only the 1 s state-diff, not activity-level | 🐞 `LiveActivityService.swift:12-30` (no `Activity<>.activities` reconcile); expected one card | [ ] | — |
| LIV-E03 | Widget link or Quick start tapped while a session is already active | `startFromTemplate` has no `isActive`/draft guard: a new draft is created, the first draft and its Live Activity reference are replaced (a second activity starts; the first stays orphaned) | `ContentView.swift:120`, `WorkoutViewModel.startWorkout` | 🐞 expected: ignore or confirm | [ ] | — |
| LIV-E04 | LOG SET / rest buttons tapped when the app process was killed | The intent runs in the app process but no `WorkoutViewModel` observers exist (`isActive` false), so the notification is dropped and nothing visible happens | Needs device check | 🟡 | [ ] | — |
| LIV-E05 | Double tap on LOG SET | Each tap logs the next incomplete set (two sets get logged); there is no debounce | | 🟡 | [ ] | — |
| LIV-E06 | App backgrounded for a long set | The timer may be suspended so state pushes pause; the elapsed and rest clocks keep running from dates, and staleness (LIV-27) flips to rest-over at `restEndDate`. The "Rest done" alert update only fires if the app is awake | Rest-end local notification is the background path (see 14) | 🟡 | [ ] | — |
| LIV-E07 | 8-hour system limit | ActivityKit ends the activity after 8 hours of activity; app does not restart it | Elapsed text shows up to 2 days | 🧭 propose: restart/replace at 7h50 or accept | [ ] | — |
| LIV-E08 | Rest timer mode is manual or off | No rest dates, so the card stays in the lifting layout; LOG SET available all the time | `restTimer.mode` | ✅ | [ ] | — |
| LIV-E09 | Empty template (no exercises) | State has no next set: exercise "Rest", 0/0 sets, ticks show one cell | `max(total, 1)` | 🟡 | [ ] | — |
| LIV-E10 | Set logged in the app UI while the card is on screen | Card updates within about 1 second (next timer tick) | LOG SET from the card is instant (`pushLiveActivityNow`) | ✅ | [ ] | — |
| LIV-E11 | Duplicate/unchanged states | Skipped by `isVisiblyUnchanged`, so no more than one ActivityKit call per visible change | Unit-tested in AuditFixesTests | ✅ | [ ] | — |
| LIV-E12 | `WorkoutActivityAttributes` defined in app and extension | Now a single shared definition in `OreShared`; CLAUDE.md says "defined in both... keep in sync" | CLAUDE.md stale | 🐞 doc only | [ ] | — |

## Open decisions for the owner (11)

- WGD-45 / CLAUDE.md: replace the "streak only" known gap with the real list (small-widget links, empty states, Plus gating of lock widgets).
- WGT-24, WGT-E01, WGT-87, WGT-132, WGT-138 (proposed default): add a dedicated empty state per widget ("Log your first workout", "Add your weight", "No friends yet") rather than zeros/blank.
- WGT-66 (🧭): when last week's total is 0, hide the delta or show "NEW" instead of "+0.0%".
- WGT-99 (🧭): lock-screen PR watch is free; either gate it behind Plus or mark the tier as FREE.
- WGP-21 (🧭): decide whether built Ore Custom widgets keep working after Plus/trial ends.
- WGT-30 / WGP-09: small-size widgets cannot host Links; decide on `widgetURL` per fixed widget (or accept "opens app").
- WGT-144: pass the real template name (not the uppercased display name) or match case-insensitively in `ContentView`.
- LIV-E02 / LIV-E03: decide the policy for orphan Live Activities (reconcile on launch) and for a widget start-link while a session or draft exists (ignore, confirm, or resume).
- LIV-E07 (🧭): behaviour at the 8-hour ActivityKit limit.
- WGB-48 / WGB-12 / WGB-15: builder UX gaps (no unsaved-changes prompt, no rename, delete without confirmation, no timeline reload on delete).
- WGD-51 / WGD-54: whether to also refresh the snapshot after history edits/deletes, imports, split changes and at midnight (needs a background refresh or an extension-side recompute of "today").
- WGU-09: locale decimal separators in widget text are mixed.
- WGT-108: deload flag has no in-app UI; decide whether to add a manual "deload week" toggle or drop the flag.
