# 02 Home tab

Scope: the Home tab (tab index 2, the default tab) and everything launched from it: KPI tiles, streak, predicted workout, the Start/Continue dock, the friend banner, global search and the avatar menu. Sources: `PulsePump/Features/Home/*` (`HomeTabView`, `StartWorkoutDock`, `FriendActivityBanner`, `GlobalSearchView`, `ProfileMenuSheet`), `Core/Utilities/StreakCalculator.swift`, `Core/Utilities/WeekMath.swift`, `Core/Models/Workout+Stats.swift`, `Features/Workout/Services/WorkoutPredictor.swift`, `WorkoutViewModel.predictNextWorkout`, `WidgetDataService+Fixed.predictionConfidence`, `Features/Programs/WorkoutDayPickerSheet.swift`.

Global rules that apply to every number on this screen: only finished (`isDraft == false`) and non-deleted (`deletedAt == nil`) workouts count; warm-up sets are saved but never counted in sets, volume, PRs or improved (`Workout+Stats.swift`); "this week" is Monday-based via `WeekMath.mondayWeekStart` whatever the device locale says; weights are stored in kg, so every comparison is unit-agnostic and lb users see the same counts as kg users.

Extra flow prefixes used in this file (unique to area 02): RCT (RECENT table and ticker), DOK (start dock), GSR (global search), PMN (avatar menu).

## HOM  Home layout and weekly tiles

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| HOM-03 | User opens the app (signed in, onboarded) → App lands on Home, the middle tab (`selectedTab = 2`, `ContentView.swift:12`) | ✅ | [ ] | — |
| HOM-06 | User views Home → App stacks, top to bottom: ticker strip (only if it has items), masthead, predicted-workout block (only if a prediction exists), 4-up KPI row, weekly volume bars, friend banner (only if friends trained today), RECENT table (only if at least 1 workout), and the Start/Continue dock pinned at the bottom via `safeAreaInset` | ✅ | [ ] | — |
| HOM-09 | User looks at the masthead → App shows a small accent square, the text "PULSE/PUMP", a magnifier button and a square avatar tile with the first letter of the user's name uppercased ("?" if no name) | ✅ | [ ] | — |
| HOM-12 | User reads the KPI row → App shows four cells, left to right: STREAK (sub-label "DAYS"), IMPROVED ("THIS WK"), PRs ("THIS WK"), SETS ("THIS WK"). Numbers are Space Mono, STREAK in accent ink | ✅ | [ ] | — |
| HOM-15 | User logs a workout and returns to Home → App updates the tiles live (SwiftData `@Query`); there is no pull-to-refresh | ✅ | [ ] | — |
| HOM-18 | User reads the SETS tile → App shows the sum of working sets (warm-ups excluded) of finished workouts whose `date >= this Monday 00:00`. There is no upper bound, so a workout re-dated into the future also counts (`HomeTabView.swift:28-35`) | ✅ | [ ] | — |
| HOM-21 | User reads the IMPROVED tile → App counts exercises whose best single working set by volume (weight x reps) this week is greater than the best single-set volume in the previous Monday-week (`HomeTabView.swift:58-74`). An exercise absent last week counts as improved if this week's best is above 0. Exercises with weight 0 (bodyweight, reps-only) have volume 0 and can never count | ✅ | [ ] | — |
| HOM-24 | User compares IMPROVED on Home with the workout-completion screen and the RECENT table → App uses a different rule on each (Home: set-volume vs last week; completion: Epley e1RM vs the previous sessions; RECENT: set-volume vs all-time). Same word, three definitions | 🐞 `HomeTabView.swift:58` vs `WorkoutViewModel.swift:280`. Expected one shared definition (audit finding "IMPR semantics inconsistent"), actual three | [ ] | — |
| HOM-27 | User reads the PRs tile → App counts exercises whose heaviest working-set weight this week exceeds the heaviest weight in every earlier workout (`HomeTabView.swift:37-56`). One exercise counts once however many PR sets. First-ever log of an exercise counts as a PR (previous max defaults to 0). Weight 0 never counts. Rep PRs and e1RM PRs are not counted | 🟡 First-ever counts here and rep PRs are ignored; the completion screen requires a previous weight above 0 and also counts rep PRs (`WorkoutViewModel.swift:270-297`). See PRR in file 05 | [ ] | — |
| HOM-30 | User looks at the weekly bars → App draws 7 bars Mon..Sun showing working sets per weekday of the current Monday-week; height = sets / max day x 40pt, minimum 4pt for a day with sets and a 3pt stub for an empty day | ✅ | [ ] | — |
| HOM-33 | User looks at bar colours → App fills today's bar solid accent, past days with sets at 70% accent, everything else (rest days, future days) faint ink at 15%. Day letters M T W T F S S, today's letter bold accent | ✅ | [ ] | — |
| HOM-36 | User reads the bars header → App shows "WEEKLY VOLUME · SETS" left and "WK n · t TOTAL" right, t = sum of the 7 bars | ✅ | [ ] | — |
| HOM-39 | User reads "WK n" → App shows elapsed 7-day periods since the user's join date (`user.createdAt`, else oldest workout, else now) via `dateComponents(.weekOfYear)` plus 1, minimum 1 (`HomeTabView.swift:160-164`). It is not a calendar week number | 🐞 Four different "WK n" meanings exist: Home (since join), More hub (`Calendar.weekOfYear`, `MoreTabView.swift:150`), Body tab (locale `weekOfYear` of the Monday), Weekly Recap (ISO). Expected one meaning; owner to decide | [ ] | — |
| HOM-42 | User opens Home right after install (no workouts) → App shows STREAK 0, IMPROVED 0, PRs 0, SETS 0, 7 faint stub bars, "WK 1 · 0 TOTAL", no RECENT table, no ticker, no friend banner. The predicted block appears only if the user picked a split (see PRD) | ✅ | [ ] | — |
| HOM-45 | User long-presses the PULSE/PUMP logo in a Release build → App does nothing. In a DEBUG build it opens the completion screen preview (`#if DEBUG`, `HomeTabView.swift:332`) | ✅ | [ ] | — |

### HOM edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| HOM-E01 | Device region week starts on Sunday (en_US) | Home still starts the week on Monday, so a Sunday workout belongs to the week ending that Sunday and sits in the SUN bar | `WeekMath.mondayWeekStart` (the old Sunday-start bug in the audit is fixed); Body tab and Home agree | ✅ | [ ] | — |
| HOM-E02 | Device region week starts on Monday (en_GB) | Identical result to Sunday-first regions | Week maths never reads `firstWeekday` | ✅ | [ ] | — |
| HOM-E03 | Sunday workout at 23:50 | Lands in the SUN bar of the current week; the next Monday 00:00 the tiles reset | Day is the workout's start time, not its finish time | ✅ | [ ] | — |
| HOM-E04 | App left open across midnight Sunday to Monday | Tiles and bars keep the old week until the view re-renders (new data, relaunch); no timer is scheduled | `Date()` is read at render time only | 🟡 No midnight refresh found in code | [ ] | — |
| HOM-E05 | Workout started 23:50, finished 00:30 | Counted on the start day (`Workout.date` is set at start and never changed at finish) | Streak and bars use the start day | ✅ | [ ] | — |
| HOM-E06 | User travels across timezones | Day buckets use the current timezone's start-of-day; a workout from 23:00 in the old zone may move to the next day in the new zone and shift bars/streak | Dates are absolute instants, buckets are recomputed on every render | 🟡 Not guarded | [ ] | — |
| HOM-E07 | DST change inside the week | Streak gap uses `dateComponents(.day)` between start-of-day values and previous-week start uses `byAdding: .weekOfYear`, both DST safe | | ✅ | [ ] | — |
| HOM-E08 | User re-dates a workout into the future (History > detail > Edit has an unrestricted date picker) | It counts in SETS and PRs (no upper bound), draws on a future bar in the faint colour, and the streak treats it as "today or later" | See 05 WDT | 🐞 `HomeTabView.swift:28`. Expected: future-dated workouts excluded or date picker capped | [ ] | — |
| HOM-E09 | User switches kg to lb | All four tiles keep the same values (counts, not weights) | Comparisons are done in kg | ✅ | [ ] | — |
| HOM-E10 | User logs only warm-ups for an exercise | SETS, IMPROVED, PRs and bars ignore it; the workout still appears in RECENT | `isWorking` filter | ✅ | [ ] | — |
| HOM-E11 | Workout deleted from History | Tiles, bars, streak and RECENT drop it immediately | Soft delete (`deletedAt`) | ✅ | [ ] | — |
| HOM-E12 | Years of history | Every tile, `improvedExercises` per RECENT row and the ticker re-scan all workouts on each render; the prediction fetches all workouts several times per render | Audit flagged; no windowing | 🟡 Perf | [ ] | — |

## STK  Streak

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| STK-03 | User has never logged a finished workout → App shows STREAK 0 on Home and "0D" on History, More and Profile | ✅ `StreakCalculator.swift:22` | [ ] | — |
| STK-06 | User logs a workout today and has no others → App shows STREAK 1 | ✅ | [ ] | — |
| STK-09 | User's most recent workout was 0, 1, 2 or 3 calendar days ago → App keeps the streak alive. 4 or more calendar days ago → App shows 0 (the "3-day expiry window", `daysSinceLast <= 3`) | ✅ `StreakCalculator.swift:24-25` | [ ] | — |
| STK-12 | User trained on day 1 and day 3 (gap 2) → App computes streak = 1 + 2 = 3. Rule: each gap of at most 3 days between consecutive training days adds the gap's length in days | ✅ | [ ] | — |
| STK-15 | User trained Mon, Wed, Fri and today is Sat → App shows 5 (1 + 2 + 2); on the Tuesday after (4 days after Fri) it shows 0 | ✅ | [ ] | — |
| STK-18 | User has a gap of more than 3 days between two earlier workouts → App stops counting at that gap; older history before it is ignored | ✅ | [ ] | — |
| STK-21 | User trains twice on one calendar day → App counts that day once | ✅ | [ ] | — |
| STK-24 | User trains about 5 days a week for 16 weeks → App shows about 111 (calendar days spanned), not 80 (days trained). The label says "DAYS"; the number is the span of a chain of workouts at most 3 days apart | 🧭 Code comment and spec define it this way. Proposed default: keep, but the owner should confirm users understand it is not "consecutive days trained" | [ ] | — |
| STK-27 | User looks at the streak elsewhere → App shows the same function result on History stats ("nD"), More hub and Profile ("nD"), the completion screen (`max(1, streak)`), the social stats sync and widgets | ✅ single source `StreakCalculator` | [ ] | — |
| STK-30 | User deletes the latest workout → App recomputes immediately and the streak can drop or reset to 0 | ✅ | [ ] | — |
| STK-33 | User imports Strong/Hevy history → App counts imported (past-dated) workouts, so an old import only produces a streak if its newest date is within 3 days of today | ✅ | [ ] | — |

### STK edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| STK-E01 | Midnight rolls over while the app is open | Streak is recalculated only at the next render; the drop to 0 on day 4 is not shown until then | No timer | 🟡 | [ ] | — |
| STK-E02 | Workout dated in the future | `daysSinceLast` is negative so the guard passes; the streak counts it | See HOM-E08 | 🟡 | [ ] | — |
| STK-E03 | Timezone change | Days are bucketed by the current calendar's start-of-day; a flight can merge or split two days | | 🟡 | [ ] | — |
| STK-E04 | Workout at 23:50 finished at 00:30 | Counts for the start day only | | ✅ | [ ] | — |
| STK-E05 | Draft (unfinished) workout today | Does not count until finished | `isDraft` filtered by the query | ✅ | [ ] | — |
| STK-E06 | Two devices, one has not synced a workout | Each device shows the streak from its local data until sync merges | See file 12 | 🟡 | [ ] | — |

## PRD  Predicted workout and confidence

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PRD-03 | User opens Home with a prediction available → App shows the block "PREDICTED TODAY · {split tag}", the workout name in 28pt uppercase, a "last done" caption, an estimated-duration caption, 5 confidence squares with "HIGH/MED/LOW CONF", and exercise chips | ✅ | [ ] | — |
| PRD-06 | System: Home renders → App asks `WorkoutPredictor.predict` with the last 14 finished workouts' template names (newest first; workouts without a template are skipped), all live template names, the user's selected split and today's weekday | ✅ `WorkoutViewModel.swift:493-508` | [ ] | — |
| PRD-09 | System: at least 2 history names exist → App looks at every earlier occurrence of the most recent template name and takes the session that followed it. The most frequent follower wins; ties go to the most recent follower | ✅ `WorkoutPredictor.swift:23-38` | [ ] | — |
| PRD-12 | System: the last template name has no earlier occurrence → App falls back to keywords: push gives a pull template (or "Pull Day"), pull gives leg (or "Leg Day"), leg gives push (or "Push Day"), upper gives lower (or "Lower"), lower gives upper (or "Upper"), full body repeats the same name; anything else gives no pattern | ✅ | [ ] | — |
| PRD-15 | System: a pattern name is found → App uses it only if it resolves to a real template: exact name (case-insensitive), then equal after stripping " day"/" workout"/" body", then containment, then a shared keyword among push/pull/leg/upper/lower/full/torso/limb/chest/back/shoulder/arm. If nothing resolves it falls through to the split | ✅ `WorkoutPredictor.swift:56-70` | [ ] | — |
| PRD-18 | System: no usable pattern and the user has a split with days → App takes the day after the last workout in the split's Monday-first cycle (matching by label or workout type), wrapping at the end; with no matching history it takes the first scheduled day on or after today's weekday. The label is resolved to a template when possible, else shown raw | ✅ `WorkoutPredictor.swift:85-97` | [ ] | — |
| PRD-21 | System: split has no days but a type other than none → App shows the split type name. No split and no pattern gives no prediction, so the whole block is hidden and the dock says "WORKOUT" | ✅ | [ ] | — |
| PRD-24 | User trains the predicted workout today and returns to Home → App moves on to the next day in the rotation but still labels it "PREDICTED TODAY". Rest days and "already trained today" are not modelled; the weekday is only used when there is no history | 🧭 Proposed default: keep (rotation based), optionally relabel to "NEXT UP" once a workout exists today | [ ] | — |
| PRD-27 | User reads the split tag → App shows "PPL" when the last 9 workouts' template names contain push, pull and leg; "U/L" for upper and lower; "FULL BODY" if any contains "full"; otherwise the selected split type name; otherwise "PROGRAM" | ✅ `HomeTabView.swift:126-138` | [ ] | — |
| PRD-30 | User reads the dock's split tag → App uses the same keyword rules but falls back only to "PROGRAM" (never the split type name), so the Home block can show the split type name while the dock says "TODAY · PROGRAM" | 🐞 `StartWorkoutDock.swift:166-180` vs `HomeTabView.swift:137`. Expected the same label | [ ] | — |
| PRD-33 | User reads the confidence squares → App fills round(confidence x 5) accent squares. Confidence: 0 when nothing predicted; 0.5 (split set) or 0.3 (no split) when fewer than 3 history names; 0.4 when the last session has no earlier occurrence; otherwise bestFollowerCount / totalFollowers x min(1, totalFollowers / 3), clamped to 0.2..0.95 and rounded to 2 decimals | ✅ `WidgetDataService+Fixed.swift:476-486` | [ ] | — |
| PRD-36 | User reads the confidence label → App shows "HIGH CONF" at 0.75 or more, "MED CONF" at 0.45 or more, otherwise "LOW CONF". Examples: 1 observed follower = 0.33, 2 squares, LOW; 2 followers both the same = 0.67, 3 squares, MED; 3 or more all the same = 0.95, 5 squares, HIGH; split-only fallback 0.5 = 3 squares, MED | ✅ | [ ] | — |
| PRD-39 | User reads the design reference → Docs say confidence under 0.5 should show "What do you want to do?" instead of a prediction and that scoring uses day-of-week, recency and muscle freshness (`docs/PULSE_PUMP_DESIGN_REFERENCE.md` sections 6.2 and 8). The app always shows its best guess and uses none of those inputs | 🟡 Design reference and code disagree; code is successor-frequency only | [ ] | — |
| PRD-42 | User reads "last done" → App finds the latest workout with the same template name (case-insensitive) and shows "TODAY", "YESTERDAY" or "{n} DAYS AGO". Hidden if the template was never done | 🐞 `HomeTabView.swift:143` counts whole 24-hour periods, not calendar days, so a session at yesterday 20:00 seen at today 08:00 reads "TODAY". Expected calendar-day difference (the Body tab does it correctly) | [ ] | — |
| PRD-45 | User reads the duration estimate → App shows "~{minutes} MIN" from the last workout of that template (duration over 60 s, minutes truncated), else "~55 MIN" | ✅ | [ ] | — |
| PRD-48 | User reads the exercise chips → App lists the matched live template's exercises in template order, uppercased. If the predicted name matches no live template (a raw split label), no chips appear | ✅ | [ ] | — |
| PRD-51 | User taps "NOT TODAY? ›" → App opens the "WHAT'S TODAY?" sheet ("PICK YOUR WORKOUT FOR TODAY") listing every live template A to Z, each with an initial, uppercase name and "{n} EXERCISES"; with no templates it says "NO PROGRAMS YET" / "Create a program first" | ✅ | [ ] | — |
| PRD-54 | User picks a template in the sheet → App closes the sheet and replaces the title, chips and the dock's target with that template. Confidence squares still reflect the original prediction, not the override | 🟡 `HomeTabView.swift:110` ignores the override | [ ] | — |
| PRD-57 | User finishes the overridden workout and returns → App keeps showing the override as the prediction until the app is relaunched (`manualOverrideTemplate` is never cleared) | 🐞 `HomeTabView.swift:16`. Expected: override cleared when a workout starts or finishes, or the day changes | [ ] | — |
| PRD-60 | User has a prediction that matches no template → App hides "NOT TODAY? ›" (the button lives inside the chip layout that only renders for a matched template), so the user cannot override | 🐞 `HomeTabView.swift:406-427`. Expected: link always available | [ ] | — |

### PRD edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PRD-E01 | Brand new user, no split | No prediction block; dock reads "WORKOUT" | | ✅ | [ ] | — |
| PRD-E02 | One workout in history | Pattern needs 2 names; falls to the keyword fallback or the split; confidence 0.3 or 0.5 | | ✅ | [ ] | — |
| PRD-E03 | Two followers tie | The most recent follower wins deterministically (the old audit note about random order is fixed) | | ✅ | [ ] | — |
| PRD-E04 | Template renamed or deleted | Old history names no longer resolve; prediction falls back to the split or hides | Names are matched as strings, not ids | 🟡 | [ ] | — |
| PRD-E05 | Two templates share a name | The first in name order is used for chips and starting | | 🟡 | [ ] | — |
| PRD-E06 | Prediction is a non-template split label | Dock shows the label but starts a blank workout (no template) | `startWorkout(template: nil)` | 🐞 `StartWorkoutDock.swift:112-116`. Expected: start the split day or say it is blank | [ ] | — |
| PRD-E07 | Free vs Pulse+ | Prediction is free for everyone (spec: smart prediction is not paywalled) | | ✅ | [ ] | — |
| PRD-E08 | Some past workouts were blank (no template) | They are skipped when building history, so they do not break the pattern | | ✅ | [ ] | — |

## RCT  RECENT table and ticker

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| RCT-03 | User scrolls to RECENT → App shows a header "RECENT / SETS / IMPR / VOL▲" and up to 3 most recent finished workouts | ✅ | [ ] | — |
| RCT-06 | User reads a row → App shows the template name uppercased ("WORKOUT" if none), an abbreviated relative date uppercased from `RelativeDateTimeFormatter` (wording comes from iOS), SETS (working sets), IMPR "x/y" and VOL▲ | ✅ | [ ] | — |
| RCT-09 | User reads IMPR "x/y" → App counts, among the workout's exercises, those whose best single-set volume beats the best single-set volume of that exercise in every earlier workout; y = number of exercise logs (minimum 1). A first-ever exercise counts as improved; an exercise with only warm-ups counts in y but never in x | 🟡 Semantics differ from the IMPROVED tile (HOM-24) | [ ] | — |
| RCT-12 | User reads VOL▲ → App compares total working volume (weight x reps, kg) with the most recent earlier workout of the same template name (case-insensitive) and shows "▲ n%" (green) or "▼ n%" (red) | ✅ | [ ] | — |
| RCT-15 | User sees a workout with no template, no volume, no earlier same-name workout, or zero previous volume → App shows "—" in grey | ✅ | [ ] | — |
| RCT-18 | User sees a tiny change (for example 1000 to 996) → App truncates toward zero (`Int(...)`), so -0.9% to +0.9% reads "▲ 0%" in green | 🐞 `HomeTabView.swift:653-658`. Expected rounding and a neutral display under 0.5%; the Body tab rounds | [ ] | — |
| RCT-21 | User taps a RECENT row → App does nothing (rows are plain views) | 🟡 No tap destination; proposed: open the workout detail | [ ] | — |
| RCT-24 | User has no workouts → App hides the whole RECENT table | ✅ | [ ] | — |
| RCT-27 | User has workouts in the last 14 days → App shows a ticker strip above the masthead, one item per primary muscle group: label = first 6 letters of the muscle name, value = working-set count when the prior 7 days had none, otherwise the absolute percent change (truncated), arrow up when the change is zero or positive. Windows are rolling (now-7d and now-14d to now-7d), not Monday weeks | 🟡 `HomeTabView.swift:678-710`. Different windows and no generic/specific dedupe compared with the Body tab | [ ] | — |
| RCT-30 | User has no data in either window → App hides the ticker | ✅ | [ ] | — |

### RCT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| RCT-E01 | lb mode | Percentages are unit-free; nothing changes | | ✅ | [ ] | — |
| RCT-E02 | Two workouts the same day with the same template | The second compares against the first | Strict `date <` ordering | ✅ | [ ] | — |
| RCT-E03 | Bodyweight-only workout | Volume 0 so VOL▲ shows "—" | | ✅ | [ ] | — |
| RCT-E04 | Ticker change of exactly 0% | Shown as a green up arrow with "0%" | `pct >= 0` | 🟡 | [ ] | — |

## DRF  Draft and Continue card

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| DRF-03 | User starts a workout → App inserts a draft `Workout` immediately and keeps updating it on each completed set, exercise change, app backgrounding and "Save as draft" (`WorkoutViewModel+Draft.swift`) | ✅ | [ ] | — |
| DRF-06 | User returns to Home while a draft exists → App replaces the START button with the draft dock: a small "START NEW WORKOUT" link above a Continue bar | ✅ | [ ] | — |
| DRF-09 | User reads the Continue bar → App shows "CONTINUE", the template name uppercased ("WORKOUT" if none), "{n} SETS DONE" and "TAP TO RESUME ›". n counts every persisted set including warm-ups; only completed sets are persisted | ✅ | [ ] | — |
| DRF-12 | User reads the bar fill → App fills accent at 18% across min(1, persisted sets / sum of template target sets); no fill when the draft has no template | ✅ | [ ] | — |
| DRF-15 | User taps the Continue bar → App rebuilds the session (completed sets with types and sides, notes, elapsed time, template rows padded back to the planned set count) and opens the logger full screen | ✅ | [ ] | — |
| DRF-18 | User taps "START NEW WORKOUT" → App shows a modal "Discard current workout?" with the message "Your progress on {template name or 'this workout'} will be lost. Drafts auto-save for 7 days." and a destructive button "DISCARD + START NEW" | ✅ | [ ] | — |
| DRF-21 | User confirms "DISCARD + START NEW" → App hard-deletes the draft and starts a new blank workout (no template), not the predicted or overridden one | 🟡 `HomeTabView.swift:229-231` passes no template; proposed: start the predicted template to match the START button | [ ] | — |
| DRF-24 | User cancels the discard modal → App leaves the draft untouched | ✅ | [ ] | — |
| DRF-27 | User reads "Drafts auto-save for 7 days" → App has no expiry code; a months-old draft keeps showing CONTINUE forever | 🐞 `HomeTabView.swift:225`, `ActiveWorkoutView.swift:220`. Expected: drafts older than 7 days removed, or the copy changed | [ ] | — |
| DRF-30 | User force-quits mid-workout and relaunches → App shows CONTINUE with the sets completed so far; un-ticked rows are rebuilt from the template; time while the app was dead is not added | ✅ | [ ] | — |
| DRF-33 | User has several drafts (for example after "Duplicate" in workout detail, which inserts a draft copy) → App shows only the one with the newest `updatedAt`; the others are invisible and never cleaned up | 🐞 `StartWorkoutDock.swift:11-13`. Expected: one draft at a time or a draft list | [ ] | — |
| DRF-36 | User resumes a duplicated draft → App shows every copied set as already completed (resume marks all persisted sets done) | 🟡 See 05 EDT | [ ] | — |

### DRF edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| DRF-E01 | Double-tap START WORKOUT quickly | `startWorkout` has no `isActive` guard, so two taps before the cover appears could create two drafts | | 🟡 Not guarded in code | [ ] | — |
| DRF-E02 | Offline | Everything is local; no difference | | ✅ | [ ] | — |
| DRF-E03 | Draft has zero completed sets | CONTINUE shows "0 SETS DONE" and no fill | | ✅ | [ ] | — |
| DRF-E04 | Draft's template was deleted | Name falls back to "WORKOUT"; fill 0 | | ✅ | [ ] | — |
| DRF-E05 | No `User` row yet | The whole dock is hidden | `if let user` | ✅ | [ ] | — |
| DRF-E06 | Widget or deep link starts a workout while a draft exists | Handled in files 03 and 11; Home only reflects the newest draft | | 🟡 | [ ] | — |
| DRF-E07 | Two devices | Drafts are never synced (only finished workouts are) | `isHistory` | ✅ | [ ] | — |

## DOK  Start workout dock

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| DOK-03 | User has no draft → App shows a full-width accent button with "TODAY · {split tag}", the predicted name uppercased ("WORKOUT" if none), "~{n} MIN" and "START WORKOUT ›" | ✅ | [ ] | — |
| DOK-06 | User taps the button → App starts a workout from the predicted (or overridden) template, or blank if none matches, and presents the logger full screen | ✅ | [ ] | — |
| DOK-09 | User reads the minutes → App uses the last finished workout whose template name is exactly equal (case-sensitive) to the predicted template; over 60 s gives truncated minutes, else 55. Home's caption matches case-insensitively, so the two can differ | 🟡 `StartWorkoutDock.swift:120-125` | [ ] | — |
| DOK-12 | System: dock renders → App runs 3 SwiftData fetches (templates, workouts twice) on every render | 🟡 Perf only | [ ] | — |

## FBN  Friend banner

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| FBN-03 | User opens Home while signed in → App triggers `SocialViewModel.loadFeed()` (5-minute cache, no-op without an identity) | ✅ `SocialViewModel.swift:465-467` | [ ] | — |
| FBN-06 | System: feed holds posts by other users dated today (`isDateInToday`) → App shows a rounded banner with up to 3 overlapping initials and the text "{name} trained today" or "{name} +{n} other(s) trained today" ("other" singular for 1). Name is the author's display name; people are de-duplicated by user | ✅ | [ ] | — |
| FBN-09 | System: nobody posted today, feed empty, offline, or signed out → App shows nothing and reserves no space | ✅ | [ ] | — |
| FBN-12 | User taps the banner → App does nothing, though a chevron suggests navigation | 🐞 `FriendActivityBanner.swift:36` `Button(action: {})`. Expected: open the Social tab or friend profile | [ ] | — |
| FBN-15 | User's own workout posted today → App excludes it (own uid filtered) | ✅ | [ ] | — |

### FBN edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| FBN-E01 | Friend trained today but did not post | Not shown; the banner reads the feed, not workouts | | 🟡 | [ ] | — |
| FBN-E02 | Friend's post audience excludes the user | Server rules hide the post; banner stays empty | See file 09 | ✅ | [ ] | — |
| FBN-E03 | Blocked user | Feed excludes blocked users | Not verified in this scope; see file 09 RPT | 🟡 | [ ] | — |
| FBN-E04 | Only the first feed page is loaded | A friend whose post is beyond page 1 is missed | | 🟡 | [ ] | — |
| FBN-E05 | Release build | No demo people ever appear (the old audit finding about "Marcus/Priya/Jake" is fixed; fixtures are DEBUG only) | | ✅ | [ ] | — |

## GSR  Global search

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| GSR-03 | User taps the magnifier → App opens "GLOBAL SEARCH" as a sheet with a back chevron, a search field (auto-focused after 0.15 s) and chips ALL / EXERCISES / WORKOUTS / FRIENDS | ✅ | [ ] | — |
| GSR-06 | User has typed nothing → App shows hints per active chip: "Search 84+ exercises by name or muscle", "Find past sessions by template name", "Search users by name or username" | 🐞 Copy over-promises: exercise search matches the name only, not muscle; workout search also matches exercise names | [ ] | — |
| GSR-09 | User picks a chip → App changes the placeholder to "Search everything..." or "Search exercises..." / "Search workouts..." / "Search friends..." and limits results to that category | ✅ | [ ] | — |
| GSR-12 | User types → App returns exercises where any word of the name starts with the text (case-insensitive), only approved or custom ones, maximum 8, as rows with a movement icon, name, primary muscles and equipment; tapping opens the exercise detail | ✅ | [ ] | — |
| GSR-15 | User types → App returns finished workouts whose template name or any exercise name has a word starting with the text, maximum 5, newest first, showing name, relative date and "{n} SETS". Rows are not tappable | 🟡 No destination for workout rows | [ ] | — |
| GSR-18 | User types a valid handle → App waits 300 ms, loads the friend graph if needed and looks up that exact handle (leading "@" and spaces stripped, lowercased, 3-20 chars of a-z 0-9 . _). A hit that is not yourself and not blocked is added to the FRIENDS section | ✅ | [ ] | — |
| GSR-21 | User types a name → App also lists existing friends whose display name or handle contains the text (substring, case-insensitive); results are de-duplicated by uid | ✅ | [ ] | — |
| GSR-24 | User taps a friend row → App does nothing (no navigation) | 🟡 Row has a chevron but no action | [ ] | — |
| GSR-27 | User types text with no matches → App shows "NO RESULTS" and `Nothing matches "{text}"` | ✅ | [ ] | — |
| GSR-30 | User taps the clear (x) in the field → App empties the text and returns to the hints | ✅ | [ ] | — |
| GSR-33 | User taps the back chevron → App dismisses the sheet | ✅ | [ ] | — |

### GSR edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| GSR-E01 | Offline | Exercise and workout results work; the friend lookup fails silently and only local friends show | `searchResults = []` on error | ✅ | [ ] | — |
| GSR-E02 | Text is a mid-word fragment | Search is by word prefix: "press" finds "Bench Press", "ench" does not | `hasWordPrefix` | ✅ | [ ] | — |
| GSR-E03 | Deleted exercise or workout | Excluded (`deletedAt == nil`) | | ✅ | [ ] | — |
| GSR-E04 | Draft workouts | Excluded | | ✅ | [ ] | — |
| GSR-E05 | Typing quickly | Earlier lookups are superseded by token; only the last result applies | | ✅ | [ ] | — |
| GSR-E06 | WORKOUTS chip active | No remote lookup is made | | ✅ | [ ] | — |

## PMN  Avatar menu

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PMN-03 | User taps the avatar tile → App dims the screen (20% black) and shows a card with the user's name uppercased ("ATHLETE" if none), "@username" or "Tap sign out to switch accounts" when there is no username, and buttons CANCEL and SIGN OUT | ✅ | [ ] | — |
| PMN-06 | User taps the dimmed area or CANCEL → App closes the card | ✅ | [ ] | — |
| PMN-09 | User taps SIGN OUT → App signs out immediately with no confirmation. The More hub's Sign Out asks first ("This removes your data from this device. It stays safe in your account and comes back when you sign in.") | 🧭 Proposed default: add the same confirmation to the Home menu | [ ] | — |
| PMN-12 | User expects a menu sheet (`ProfileMenuSheet`) → App never presents it; the file is dead code and the inline card above is what ships | 🟡 Unreachable `ProfileMenuSheet.swift` | [ ] | — |
| PMN-15 | User has a profile photo → App still shows only the initial letter on the Home avatar | 🟡 Photo is shown on More and Profile only | [ ] | — |

### PMN edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PMN-E01 | Sign out while offline or with unsynced changes | Same as file 01 SOUT; Home adds no warning | | 🟡 | [ ] | — |
| PMN-E02 | Active workout exists | Menu cannot be reached; the logger is full screen | | ✅ | [ ] | — |

## Open decisions for the owner (02)

- STK-24 (🧭): streak counts days spanned, not days trained. Proposed: keep, confirm the "DAYS" label.
- PRD-24 (🧭): prediction rotates to the next day right after training. Proposed: relabel "NEXT UP" when a workout already exists today.
- PMN-09 (🧭): Home SIGN OUT has no confirmation. Proposed: add the More-hub alert.
- HOM-24 / HOM-27 / RCT-09: three definitions of IMPROVED and two of PR; decide one shared rule (audit suggests an `ImprovementCalculator`).
- HOM-39: four different "WK n" definitions; decide one.
- PRD-39: design reference promises a "What do you want to do?" state under 0.5 confidence and day-of-week scoring; code does neither.
- PRD-30, PRD-42, PRD-54, PRD-57, PRD-60, PRD-E06: label, calendar-day, override and "NOT TODAY?" bugs.
- DRF-21: discard-and-start begins a blank workout. DRF-27: the "7 days" promise has no implementation. DRF-33: extra drafts are orphaned.
- RCT-18, RCT-21: percent truncation and non-tappable RECENT rows.
- FBN-12, GSR-15, GSR-24: tappable-looking rows with no action (banner, workout results, friend results).
- GSR-06: hint copy over-promises muscle search.
- HOM-E08: allow future-dated workouts or cap the date picker.
- PMN-12: delete or wire `ProfileMenuSheet`.
