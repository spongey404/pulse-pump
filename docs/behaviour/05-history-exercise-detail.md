# 05 History, workout detail, exercise detail, PR rules, weekly recap, profile stats

Scope: everything reached from More > History (list, calendar, workout detail, edit, duplicate, delete), the exercise detail screen (reached from the Exercise Library and Global Search), the rules that decide what counts as a PR on every surface, the Weekly Recap screen and the More > Profile stats screen. Sources: `Ore/Features/More/WorkoutHistoryView.swift`, `WorkoutDetailView.swift`, `WeeklyRecapView.swift`, `ProfileView.swift`, `MoreTabView.swift`, `Features/Exercises/ExerciseDetailView.swift`, `Core/Models/Workout+Stats.swift`, `Core/Sync/SyncRecord.swift`, `Features/Workout/WorkoutViewModel.swift` (`checkPR`, `finishWorkout`), `OreShared/WeightUnit.swift`.

Shared rules: History lists only finished (`isDraft == false`), non-deleted workouts; "sets" always means working sets (warm-ups excluded) except where a row says otherwise; stored weights are kg and every screen converts for display (`@Environment(\.weightUnit)`); a delete is a soft delete (`deletedAt` tombstone) so it syncs.

Reachability: History, Weekly Recap and Profile are reachable from the More hub. Unreachable or dead in this area: `HistoryWorkoutRow` / `WorkoutHistoryRow` (legacy row view and typealias at the bottom of `WorkoutHistoryView.swift`, referenced nowhere), and the PR-history and e1RM/volume chart views the spec describes (never built, see XCH). The Monday weekly-recap notification and the monthly recap modal from the spec are not built.

Extra flow prefixes used here (unique to area 05): WRC (Weekly Recap), PFV (Profile screen under More).

## HIS  History list

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| HIS-03 | User opens More and reads the "History" row → App shows the count of finished workouts as the row value (for example "42") | ✅ `MoreTabView.swift:97` | [ ] | — |
| HIS-06 | User taps "History" → App swaps the More tab content to "HISTORY" with a back chevron and a two-button toggle (list icon, calendar icon); list mode is the default | ✅ | [ ] | — |
| HIS-09 | User taps the back chevron → App returns to the More hub | ✅ | [ ] | — |
| HIS-12 | User views list mode with at least one workout → App shows a stats strip: WORKOUTS (all finished workouts), THIS MONTH (workouts whose start date is in the current calendar month and year), STREAK ("nD", from `StreakCalculator`) | ✅ `WorkoutHistoryView.swift:315-333` | [ ] | — |
| HIS-15 | User reads the list → App shows a "RECENT" label then every finished workout, newest first, one row each, no month grouping and no paging | ✅ | [ ] | — |
| HIS-18 | User reads a row → App shows a date column (weekday abbreviation, day number, month abbreviation, all from the device locale), the template name uppercased ("WORKOUT" when none), "{n} SETS · {m}M" (working sets, duration in whole minutes, truncated) and a "›" | ✅ | [ ] | — |
| HIS-21 | User taps a row → App pushes the workout detail (WDT) | ✅ | [ ] | — |
| HIS-24 | User swipes a row left → App reveals a red "Delete" action; a full swipe triggers it | ✅ | [ ] | — |
| HIS-27 | User triggers Delete → App shows a confirmation dialog titled "Delete Workout?" with a destructive "Delete" button and the message "This workout will be permanently deleted." | ✅ | [ ] | — |
| HIS-30 | User confirms Delete → App soft-deletes the workout (tombstone, syncs to other devices) and the row disappears; there is no undo | ✅ `WorkoutHistoryView.swift:57` | [ ] | — |
| HIS-33 | User cancels the dialog → App keeps the workout | ✅ | [ ] | — |
| HIS-36 | User has no workouts and is in list mode → App shows "NO WORKOUTS YET" and "Complete your first workout to see it here." and no stats strip | ✅ | [ ] | — |
| HIS-39 | User deletes a workout that was already posted to the feed → App removes only the local workout; the feed post is not touched | 🧭 Proposed default: keep the post (it is a separate social record) but warn in the delete dialog if the workout was posted | [ ] | — |
| HIS-42 | User deletes or edits a workout and looks at widgets → App does not refresh widget data; widgets update on next launch, route change or workout finish (`WidgetDataService.updateWidgetData` is not called from History) | 🐞 `WorkoutHistoryView.swift:57`, `WorkoutDetailView.swift:69`. Expected widgets refresh after edit/delete | [ ] | — |

### HIS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| HIS-E01 | Offline | History is fully local and works; a delete is queued for sync | | ✅ | [ ] | — |
| HIS-E02 | Workout with zero duration (imported or duplicated) | Row shows "0M" | `Int(duration) / 60` | ✅ | [ ] | — |
| HIS-E03 | Workout has only warm-ups | Row shows "0 SETS" | | ✅ | [ ] | — |
| HIS-E04 | Two devices, workout deleted on the other | Row vanishes after sync pulls the tombstone | See file 12 | ✅ | [ ] | — |
| HIS-E05 | Thousands of workouts | Rendered in a lazy `List`; the stats strip filters the whole array on every render | | 🟡 Perf | [ ] | — |
| HIS-E06 | Month boundary / timezone change | THIS MONTH uses the device's current calendar and timezone at render time | | ✅ | [ ] | — |
| HIS-E07 | Locale uses non-Latin digits or a non-Gregorian calendar | Dates in the row follow the locale; the calendar-mode key (CAL) uses a fixed "yyyy-MM-dd" format consistently on both sides | | 🟡 Not exercised | [ ] | — |
| HIS-E08 | Draft in progress | Not listed (drafts are not history) | | ✅ | [ ] | — |
| HIS-E09 | Supernova vs free | History is free and unlimited | | ✅ | [ ] | — |

## CAL  History calendar

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CAL-03 | User taps the calendar icon → App shows the current month in capitals ("OCTOBER 2026") with "‹" and "›", the header row M T W T F S S and a fixed 6-row, 42-cell grid; today is selected | ✅ | [ ] | — |
| CAL-06 | User reads the grid → App always starts weeks on Monday, even if the device region starts on Sunday, padding the first row with blanks | ✅ `WorkoutHistoryView.swift:414-433` | [ ] | — |
| CAL-09 | User reads a day cell → App tints days that have a finished workout and adds a dot; the selected day is solid accent with white text; today's number is accent ink; other days are muted with a hairline border | ✅ | [ ] | — |
| CAL-12 | User taps any day (with or without a workout, past or future) → App selects it and shows what happened that day below the grid | ✅ | [ ] | — |
| CAL-15 | User selects a day with workouts → App lists one card per workout: date "EEE d MMM", template name, "{n} SETS · m:ss" | ✅ | [ ] | — |
| CAL-18 | User taps a card → App opens the workout detail | ✅ | [ ] | — |
| CAL-21 | User selects a day without workouts → App shows "NO WORKOUT" and "No workout logged on this date." | ✅ | [ ] | — |
| CAL-24 | User taps "‹" or "›" → App moves one month; there is no lower or upper bound, so the user can browse empty past and future months | ✅ | [ ] | — |
| CAL-27 | User switches list to calendar and back → App keeps the selected date and shown month while the screen stays open | ✅ | [ ] | — |
| CAL-30 | User wants to delete from the calendar → App offers no swipe or delete there; deletion needs the list or the detail screen | 🟡 | [ ] | — |

### CAL edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CAL-E01 | Workout at 23:50 | Appears on its start day | Key is the start date in the current timezone | ✅ | [ ] | — |
| CAL-E02 | Timezone changes after logging | The workout may move to the neighbouring day because the key is computed with the current timezone | | 🟡 | [ ] | — |
| CAL-E03 | Two workouts the same day | Both cards are shown, in query (newest first) order | | ✅ | [ ] | — |
| CAL-E04 | Re-dated future workout | Appears on the future day in the grid | See HOM-E08 in file 02 | 🟡 | [ ] | — |
| CAL-E05 | Months with 31 days starting Sunday (needs 6 rows) | Fits the 42 cells | | ✅ | [ ] | — |
| CAL-E06 | The Body tab has its own calendar sheet with different rules (blocks future days, only taps days with workouts, can jump to the week) | Behaviour differs from this one | See file 06 BDC | 🟡 | [ ] | — |

## WDT  Workout detail

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WDT-03 | User opens a workout → App shows a header with a back chevron, the date as "EEE D MMM YYYY" uppercased, the template name uppercased ("WORKOUT" if none) and a "⋯" menu | ✅ | [ ] | — |
| WDT-06 | User reads the stats strip → App shows DURATION ("{h}H {m}M" or "{m}M"), EXERCISES (number of exercise logs, including any with only warm-ups), SETS (working sets) and KCAL (stored calorie estimate, whole number) | ✅ | [ ] | — |
| WDT-09 | User scrolls → App lists one section per exercise in saved order, titled with the exercise name ("Exercise" if the exercise record is gone) | ✅ | [ ] | — |
| WDT-12 | User reads a set row → App shows "S{n}", then "{weight} {KG or LB} × {reps}" and, when recorded, "RIR {n}". Weight is converted from kg and rounded to 0.01 kg or 0.5 lb. A set with weight 0 and reps 0 shows only "S{n}" | ✅ | [ ] | — |
| WDT-15 | User reads a workout containing warm-ups → App lists the warm-up rows exactly like working sets, with no marker, while the SETS tile excludes them | 🟡 `WorkoutDetailView.swift:325`. Expected a visible "WU" marker | [ ] | — |
| WDT-18 | User reads exercise notes → App shows the note under the sets when not empty | ✅ | [ ] | — |
| WDT-21 | User scrolls to the end → App shows a "Notes" section with the workout notes, or "No notes added." | ✅ | [ ] | — |
| WDT-24 | User is a Supernova subscriber or in the free trial → App also shows a "Deload Week" toggle that writes the workout's `isDeload` immediately, in view and edit mode. Free users do not see it | ✅ (gate: `isSubscribed || isInFreeTrial`) | [ ] | — |
| WDT-27 | User taps "⋯" → App offers Edit, Duplicate and Delete (destructive) | ✅ | [ ] | — |
| WDT-30 | User taps Delete → App shows the same "Delete Workout?" dialog; on confirm it soft-deletes and pops back | ✅ | [ ] | — |
| WDT-33 | User taps Duplicate → App silently inserts a new draft workout dated now with the same template and copies of every exercise log and set (weight, reps, RIR, type, side); workout notes are not copied; the screen does not change and no message appears. The copy shows up on Home as a CONTINUE card | 🟡 `WorkoutDetailView.swift:194-224`. No feedback, can displace a real draft, and a resumed copy shows every set as completed (see DRF-33 and DRF-36 in file 02). Proposed: confirm and open it in the logger | [ ] | — |
| WDT-36 | User looks for PRs or a body map in the detail → App shows neither; PRs are only visible on the completion screen, in the feed and in Weekly Recap | ❌ Spec asks for "PR history" as free analytics | [ ] | — |

### WDT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| WDT-E01 | Workout whose exercise was deleted | Section title falls back to "Exercise" | | ✅ | [ ] | — |
| WDT-E02 | Workout opened while it gets deleted by sync from another device | Screen may show stale content until popped | | 🟡 Not verified | [ ] | — |
| WDT-E03 | lb mode | Weights shown in LB with 0.5 rounding; a stored 100 kg shows "220.5 LB" | `roundedDisplay` | ✅ | [ ] | — |
| WDT-E04 | Free user opens a deload-flagged workout | Flag is kept, toggle hidden | | ✅ | [ ] | — |
| WDT-E05 | Very long notes | Wrap; edit mode limits the visible lines (3-6 workout, 2-4 exercise) but not the length | | ✅ | [ ] | — |

## EDT  Edit and delete

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| EDT-03 | User taps Edit → App switches the header "⋯" to a "DONE" button and makes the screen editable: a date picker, weight/reps fields, add/delete set, exercise notes and workout notes | ✅ | [ ] | — |
| EDT-06 | User changes the "Date" picker → App rewrites the workout date (date part only; the time of day is kept). The picker has no minimum or maximum, so past and future dates are allowed | 🐞 `WorkoutDetailView.swift:24`. Expected: cap at today (see HOM-E08) | [ ] | — |
| EDT-09 | User edits a weight → App parses the text in the display unit (decimal comma or point accepted) and stores kg immediately on each valid keystroke; the field is pre-filled with the exact value (2 decimals, never snapped) so opening and closing does not change data | ✅ `EditableSetRow` | [ ] | — |
| EDT-12 | User clears the weight or reps field → App keeps the previous stored value (an empty or invalid entry is ignored), so a value cannot be reset to 0 by blanking | 🟡 Expected: blank means 0 | [ ] | — |
| EDT-15 | User edits reps → App accepts whole numbers only (number pad) | ✅ | [ ] | — |
| EDT-18 | User taps "Add Set" → App appends a standard set after the highest order, pre-filled with the previous set's weight and reps (0 and 0 if none) | ✅ | [ ] | — |
| EDT-21 | User swipes a set row left → App deletes it (hard delete of the set), renumbers the remaining sets from S1 and marks the workout updated. No confirmation | ✅ `WorkoutDetailView.swift:249-264` | [ ] | — |
| EDT-24 | User deletes the last set of an exercise → App leaves an empty exercise section; exercises cannot be removed, added, reordered or swapped from this screen | 🟡 | [ ] | — |
| EDT-27 | User wants to change set type, RIR, template, or duration → App offers no control for them | ❌ Not built | [ ] | — |
| EDT-30 | User edits exercise notes or workout notes → App saves as typed (multi-line fields) | ✅ | [ ] | — |
| EDT-33 | User taps DONE → App marks the workout updated (dirty for sync) and leaves edit mode | ✅ | [ ] | — |
| EDT-36 | User taps back while still editing → App leaves immediately; there is no Cancel/revert (edits are already written) and the explicit `markUpdated()` is skipped, so syncing depends on the change tracker safety net | 🟡 `WorkoutDetailView.swift:105` | [ ] | — |
| EDT-39 | User edits a set and checks PRs → App does not recompute or retract PR flags already used for the feed post or completion screen; Home, Weekly Recap and exercise detail recompute live | 🟡 | [ ] | — |

### EDT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| EDT-E01 | Typing "82,5" with a comma locale | Parsed as 82.5 | `parseDecimal` | ✅ | [ ] | — |
| EDT-E02 | Negative or very large weight | No clamp; accepted if it parses | | 🟡 Not guarded | [ ] | — |
| EDT-E03 | lb mode | Typed lb values are converted to kg at full precision; a re-open shows the typed number back to 2 decimals | | ✅ | [ ] | — |
| EDT-E04 | Edit on two devices | Last write by `updatedAt` wins at workout level (the sync unit embeds sets) | See file 12 | 🟡 | [ ] | — |
| EDT-E05 | Kill app while editing | Edits already written to SwiftData persist | | ✅ | [ ] | — |
| EDT-E06 | Double-tap Add Set | Adds two sets | | ✅ | [ ] | — |

## XCH  Exercise detail and charts

Reached from Exercise Library rows and from Global Search results. Not reachable from History, the Body tab sheet (its exercise rows are plain text) or workout detail.

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| XCH-03 | User opens an exercise → App shows a list with the exercise name as an inline title and sections Info, Primary Muscles, optional Secondary Muscles, Progress, optional Recent Sessions, In Templates, optional Notes | ✅ | [ ] | — |
| XCH-06 | User reads Info → App shows Equipment, Movement and Type, plus "Unilateral: Yes" only for unilateral exercises | ✅ | [ ] | — |
| XCH-09 | User has never completed this exercise → App shows an empty state "No History Yet" / "Complete a workout with this exercise to see your progress." and hides Recent Sessions and Notes | ✅ | [ ] | — |
| XCH-12 | User has history → App shows stat cards. "Weight PR (kg or lb)" is the heaviest working-set weight ever; "Rep PR" is the most reps in any single working set at any weight; "Est. 1RM (kg or lb)" is the best Epley estimate over working sets; "Volume PR" is the best total working volume (weight x reps summed) of one session for this exercise, shown only when above 0, with thousands separators | ✅ `ExerciseDetailView.swift:70-120` | [ ] | — |
| XCH-15 | System: Epley on this screen → App uses weight x (1 + reps/30) for 2 or more reps and plain weight for 1 rep (or 0). The workout logger and completion screen use weight x (1 + reps/30) even for 1 rep, so a single at 100 kg reads 100 here and 103.3 there | 🐞 `ExerciseDetailView.swift:95` vs `WorkoutViewModel.swift:385`. Expected one formula | [ ] | — |
| XCH-18 | User reads the trend → App shows "Weight Over Time (kg or lb)": one point per finished session of this exercise at its heaviest working-set weight, connected by a line; the y axis does not start at zero | ✅ | [ ] | — |
| XCH-21 | User has only one session, or all sessions at weight 0 → App hides the chart (needs at least 2 points above 0) | ✅ | [ ] | — |
| XCH-24 | User looks for an e1RM chart, volume chart, rep chart or a PR history list → App has none; only the single weight line exists | ❌ Spec §3 asks for trend graphs of progress; e1RM and volume are shown only as numbers | [ ] | — |
| XCH-27 | User reads Recent Sessions → App lists the 5 most recent sessions by workout date, each with the date and every set of that session as "{weight}×{reps}" separated by double spaces | 🟡 Uses all sets including warm-ups, and the stored array order rather than set order | [ ] | — |
| XCH-30 | User reads In Templates → App lists the names of live templates containing the exercise (matched by exercise id), else "Not used in any templates" | ✅ | [ ] | — |
| XCH-33 | User reads Notes → App lists up to 10 latest non-empty exercise notes with dates, else "No notes yet" | ✅ | [ ] | — |
| XCH-36 | User views stat numbers in lb → App converts from kg and rounds to 0.5 lb, so a PR 0.2 lb above the previous one can look identical | ✅ | [ ] | — |

### XCH edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| XCH-E01 | Bodyweight exercise (weight 0) | Weight PR "0", e1RM "0", Volume PR hidden, chart hidden; Rep PR is the useful number | | 🟡 Proposed: show reps-based chart | [ ] | — |
| XCH-E02 | Cardio-style sets (duration/distance, weight 0, reps 0) | All numbers 0; sessions show "0×0" | Duration/distance are not shown here | 🟡 | [ ] | — |
| XCH-E03 | Workout containing the exercise is deleted | Its points, PRs and sessions disappear immediately | `finalLogs` excludes deleted workouts | ✅ | [ ] | — |
| XCH-E04 | Draft in progress | Draft sets are excluded from every number | `isFinal` | ✅ | [ ] | — |
| XCH-E05 | Warm-up sets | Excluded from PRs, e1RM, volume and the chart; included in Recent Sessions text | | 🟡 | [ ] | — |
| XCH-E06 | Same exercise twice in one workout | Counted as two logs, so two chart points at the same date | | 🟡 | [ ] | — |
| XCH-E07 | Supernova vs free | The screen is free; nothing is gated | | ✅ | [ ] | — |
| XCH-E08 | Imported exercise merged by name | Uses the matched Exercise record; history from imports is included | | ✅ | [ ] | — |

## PRR  What counts as a PR (all surfaces)

There is no shared PR service; each surface re-derives PRs. All comparisons run in kg, ignore warm-ups, drafts and deleted workouts, and a tie is never a PR.

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PRR-03 | User ticks a set in the logger → App flags it as a PR live if it is not a warm-up, weight or reps above 0, the exercise already has working-set history, and either its weight is strictly above the heaviest previous weight, or (weight above 0 and reps above 0) its reps exceed the previous best reps at that weight or lighter (tolerance 0.01 kg) and that previous best is above 0. Each qualifying set is flagged, not just the best | ✅ `WorkoutViewModel.swift:457-490` | [ ] | — |
| PRR-06 | User finishes a workout → App counts at most one PR per exercise: weight PR when the session's best weight is strictly above the previous best and the previous best is above 0; otherwise a rep PR when the session's highest rep count in any working set beats the previous best reps at weights up to the session's best weight (previous above 0). Weight takes precedence | ✅ `WorkoutViewModel.swift:270-297` | [ ] | — |
| PRR-09 | System: finish workout "improved" count → App counts an exercise as improved when its best Epley e1RM this session exceeds the previous best e1RM by more than 0.01 and a previous exists; reps-only sets use the rep count as the estimate | ✅ | [ ] | — |
| PRR-12 | System: first time ever doing an exercise → App flags no PR on the completion screen or the live flag (no previous), but Home counts it as a PR | 🟡 Inconsistent with Home (HOM-27 in file 02) | [ ] | — |
| PRR-15 | System: Home PRs tile → App uses the weekly max-weight rule from HOM-27 (first-ever counts, no rep PRs) | 🟡 | [ ] | — |
| PRR-18 | System: Weekly Recap PRs → App lists, per workout in the week in date order, the heaviest working set per exercise name when it beats the best weight of all earlier history (anything before the week plus earlier workouts of the same week) and the exercise had history before the week. First-ever exercise is not a PR there | 🟡 Third variant | [ ] | — |
| PRR-21 | System: exercise detail → App shows maxima (heaviest weight, most reps, best Epley, best session volume), not "did this beat the previous" | 🟡 | [ ] | — |
| PRR-24 | System: widgets → App uses e1RM-based comparisons (PR watch within 5% of all-time e1RM; "best PR set" where e1RM beats everything before that session) | 🟡 See file 11; a fourth rule | [ ] | — |
| PRR-27 | User sees a PR anywhere → App marks it by treatment, not colour: ink text with a 1.5px ink underline (design rule "PR is a treatment, not a color"); amber is reserved for Fuel | ✅ (Weekly Recap verified) | [ ] | — |
| PRR-30 | Owner decision → Which single definition should apply everywhere (proposal: per-exercise, weight PR strictly above previous best > 0, plus rep PR at same-or-lighter weight, plus e1RM "improved"; first-ever is a baseline, not a PR) | 🧭 Proposed default as written; not decided | [ ] | — |

### PRR edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PRR-E01 | Equal weight to the previous best | Not a PR (strict greater-than) | | ✅ | [ ] | — |
| PRR-E02 | lb user enters 225 lb twice | Same kg value both times, so no PR; 225.1 lb is a PR but displays as 225 LB due to 0.5 rounding | | 🟡 Display hides small gains | [ ] | — |
| PRR-E03 | Bodyweight (weight 0) | Weight PR impossible; rep PR needs weight above 0 on the live path | | 🟡 | [ ] | — |
| PRR-E04 | Edited history makes an old session the new best | PR flags already shown/posted are not recomputed | | 🟡 | [ ] | — |
| PRR-E05 | Imported history | Counts as the baseline for later PRs | | ✅ | [ ] | — |
| PRR-E06 | Two PR sets of one exercise in one session | Live flags both; completion counts the exercise once | | ✅ | [ ] | — |
| PRR-E07 | Draft or deleted workout holding the old best | Ignored | | ✅ | [ ] | — |

## WRC  Weekly Recap

Reached from More > "Weekly Recap" (row value "WK n"). Free for everyone in the code even though the Supernova screen lists "Weekly Recaps: Automated Monday summaries".

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WRC-03 | User opens Weekly Recap → App shows "WEEKLY RECAP" with an overline "WK n · MMM D–MMM D" for the current week (ISO calendar, Monday to Sunday) and "‹ ›" arrows | ✅ | [ ] | — |
| WRC-06 | User taps "‹" → App goes one week back with no limit; "›" returns forward and is disabled on the current week | ✅ | [ ] | — |
| WRC-09 | User reads the hero → App shows SESSIONS as "{finished workouts in the week} / {target}". Target is the number of days in the user's split, else the larger of this week's count and 5 | ✅ | [ ] | — |
| WRC-12 | User reads the hero bars → App draws M..S bars of working sets per day (accent when at least one workout that day), heights relative to the busiest day, minimum 3pt | ✅ | [ ] | — |
| WRC-15 | User reads KPIs → App shows VOLUME (in tonnes as "VOLUME T" for kg; thousands of lb as "VOLUME K LB" for lb; one decimal), SETS (working) and TIME (total minutes as h:mm) | ✅ | [ ] | — |
| WRC-18 | User reads KPI deltas → App compares with the previous week and shows "▲ +x.x%" / "▼ -x.x%" for volume, "▲ +n" for sets and "+h:mm" for time (green up, red down); nothing is shown when the previous week had none | ✅ | [ ] | — |
| WRC-21 | User reads "SETS BY MUSCLE" → App lists five rows (Back, Chest, Legs, Shoulders, Arms) with this week's working sets and a "VS LAST" delta ("0", "▲ +n", "▼ -n"). Each exercise counts toward the bucket of its first primary muscle only; abs, core and other groups are not shown | 🟡 Buckets are a coarse design choice; proposed: note it in the UI | [ ] | — |
| WRC-24 | User reads the section header → App shows "VS WK {n-1}" using the ISO week number minus 1 | 🐞 `WeeklyRecapView.swift:226`. In ISO week 1 this prints "VS WK 0". Expected the previous week's real number (52/53) | [ ] | — |
| WRC-27 | User reads "PERSONAL RECORDS" → App shows the count and a row per PR (name, "EEE D MMM · TEMPLATE", "{weight}×{reps}" with the unit) per PRR-18; with none it shows "NO NEW RECORDS THIS WEEK" | ✅ | [ ] | — |
| WRC-30 | User reads the footer → App shows "NEXT RECAP · MON {d MMM}" for the Monday after the current week, even when browsing older weeks | 🟡 No notification is scheduled; the text promises a recap that is not delivered | [ ] | — |
| WRC-33 | User expects the Monday push notification or the monthly recap modal (spec "Known gaps") → App delivers neither | ❌ Not built | [ ] | — |

### WRC edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| WRC-E01 | Device week starts Sunday | Recap still runs Monday to Sunday (ISO calendar with `firstWeekday = 2`) | | ✅ | [ ] | — |
| WRC-E02 | Week with no workouts | SESSIONS "0/target", zero bars, zeros, "NO NEW RECORDS THIS WEEK"; no deltas | | ✅ | [ ] | — |
| WRC-E03 | Browsing weeks before the first workout | Same empty view; there is no stop | | 🟡 | [ ] | — |
| WRC-E04 | Midnight Sunday to Monday while open | The current week is recomputed at next render only | | 🟡 | [ ] | — |
| WRC-E05 | lb user | Volume is converted before dividing by 1000 and labelled K LB; weights in PRs use LB | | ✅ | [ ] | — |
| WRC-E06 | Exercise renamed | PR matching is by exercise name string, so a rename splits its history | | 🟡 | [ ] | — |
| WRC-E07 | Supernova vs free | Not gated in code; the paywall copy implies it is a Plus feature | | 🧭 Proposed: decide and gate in file 13 | [ ] | — |

## PFV  Profile screen (More > profile header)

Reached by tapping the user header at the top of the More hub. A different, social profile screen also exists on the Social tab (see file 09).

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PFV-03 | User taps the name/avatar header on More → App opens "PROFILE" with a back chevron and an "EDIT" button | ✅ | [ ] | — |
| PFV-06 | User reads the header card → App shows the avatar (photo or first letter), the name, "@username" (or the lowercased name without spaces if no username) and a subtitle "SPLIT NAME · EXPERIENCE" in capitals | ✅ | [ ] | — |
| PFV-09 | User taps the avatar → App opens the photo picker; the chosen image is stored as the user's avatar data and the record is marked updated | ✅ | [ ] | — |
| PFV-12 | User reads the stats row → App shows WORKOUTS (finished count), STREAK ("nD"), FRIENDS and FANS (counts from the social graph, loaded when the screen appears; 0 until loaded or when offline) | ✅ | [ ] | — |
| PFV-15 | User reads FRIENDS → App lists the first 3 friends with "n WORKOUTS · nD STREAK" (from the friend's synced stats) and a "FRIEND" tag | ✅ | [ ] | — |
| PFV-18 | User taps the bottom row → App opens the friends list as a sheet. Label is "FIND FRIENDS" with no friends, else "SEE ALL n · FIND FRIENDS" | ✅ | [ ] | — |
| PFV-21 | User reads DETAILS → App shows EXPERIENCE, UNITS, GENDER, BODY WEIGHT (hidden when 0; formatted in the preferred unit from kg) and MEMBER SINCE ("MMM YYYY" uppercased from the account creation date, now if missing) | ✅ | [ ] | — |
| PFV-24 | User taps EDIT → App opens the edit profile screen (covered in file 10) | ✅ | [ ] | — |
| PFV-27 | System: no local user row → App shows "NO PROFILE" | ✅ | [ ] | — |

### PFV edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PFV-E01 | Offline | Local stats show; FRIENDS and FANS show the last loaded values or 0 | | 🟡 | [ ] | — |
| PFV-E02 | lb user | BODY WEIGHT shows e.g. "176.4 LB" for a stored 80 kg | | ✅ | [ ] | — |
| PFV-E03 | Very large photo | Stored as raw data with no resize or size limit | | 🟡 Not guarded | [ ] | — |
| PFV-E04 | Photo picker permission denied | The picker is out-of-process and needs no permission; nothing happens if cancelled | | ✅ | [ ] | — |
| PFV-E05 | Two profile screens (More and Social) | They can show different counts until both are refreshed | | 🟡 | [ ] | — |

## Open decisions for the owner (05)

- PRR-30 (🧭): choose one PR/improved definition for the whole app. Proposed: per exercise, strict weight PR over a previous best above 0, plus rep PR at same-or-lighter weight, plus e1RM "improved"; first-ever is a baseline.
- HIS-39 (🧭): deleting a posted workout leaves the feed post. Proposed: keep, and warn in the dialog.
- WRC-E07 (🧭): Weekly Recap is free in code but advertised as a Supernova feature; decide in the gating file.
- WRC-33: Monday recap notification and monthly recap modal are in the spec but not built; WRC-30 text promises "NEXT RECAP".
- WRC-24: "VS WK 0" in ISO week 1.
- XCH-24: no e1RM, volume or rep chart, and no PR history list despite the spec; XCH-15: two Epley formulas.
- EDT-06 / HOM-E08: unrestricted date picker allows future-dated workouts.
- EDT-27: set type, RIR, template and duration cannot be edited after the fact; EDT-24: cannot add or remove exercises.
- EDT-36: no cancel/revert on edit.
- WDT-15: warm-ups are indistinguishable in the detail rows. WDT-33: Duplicate gives no feedback and creates a stray draft.
- HIS-42: widgets are not refreshed after edit or delete.
- Dead code: `HistoryWorkoutRow` / `WorkoutHistoryRow` typealias (delete).
