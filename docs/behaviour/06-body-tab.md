# 06 Body tab

Scope: the Body tab (tab index 3): week and day scrubber, hero totals, VS PACE / VS LAST / VS WK comparison, front and back muscle map with the two heat modes, TOP and GAPS columns, cold spots, the CAL calendar sheet and the muscle detail sheet. Sources: `PulsePump/Features/BodyMap/BodyMapTabView.swift`, `BodyMap2DView.swift`, `MuscleDetailSheet.swift`, `Core/Models/Enums/MuscleGroup+Tracked.swift`, `Core/Utilities/WeekMath.swift`, `Core/Models/Workout+Stats.swift`, `PumpShared/BodyHeat.swift` (used by Social, share cards and widgets, not by this tab), `docs/audit/views-body-home.md` (partly stale), `docs/PULSE_PUMP_DESIGN_REFERENCE.md` section 6.5, `docs/pulse-pump-spec.md` Phase 6.

Rules shared by every number on this tab: only finished (`isDraft == false`), non-deleted workouts count (the queries fetch everything and filter in code); only working sets count (warm-ups excluded); only the 17 tracked muscle groups exist (chest, lats, quads, hamstrings, glutes, front/side/rear delts, biceps, triceps, traps, upper back, forearms, lower back, calves, abs, obliques); exercises hitting only hip flexors, adductors, abductors or neck contribute nothing. A generic "back" or "shoulders" tag is folded into upper back or side delts only when no specific child (lats, upper/lower back, traps; front/side/rear delts) is present on the same exercise, and every group is counted once per exercise. Set counts are unit-free, so kg vs lb changes nothing on this tab. All state (week, day, mode, chips) is in-memory and resets on relaunch. Weeks start on Monday regardless of device locale (`mondayOfThisWeek`).

The heat map does not use the BodyHeat 5-stop thermal ramp (cream, peach-blue, blue; stops 0, 0.2, 0.45, 0.7, 1.0) that Social, share cards and widgets use. Here a region is the accent blue drawn at opacity equal to its level (0 to 1) on top of a faint base tint, so there are no discrete thresholds, only a continuous fade. The design reference still describes a cream-to-red scale.

Targets per week (sets): chest 16, lats 16, quads 20, hamstrings 12, glutes 12, front delts 8, side delts 10, rear delts 8, biceps 10, triceps 10, traps 8, upper back 12, forearms 6, lower back 6, calves 8, abs 8, obliques 6; total 176. Daily denominator is a fixed 26. Cadence (days) used by cold spots: 3 for the three delts; 4 for chest, lats, quads, biceps, triceps, upper back, abs; 5 for hamstrings, glutes, traps, forearms, lower back, calves, obliques.

Extra flow prefixes used here (unique to area 06): BDC (CAL calendar sheet), BMS (muscle detail sheet).

## BDY  Body tab

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| BDY-03 | User opens the Body tab → App shows a masthead (accent square, "PULSE/PUMP", a "CAL" button), the ticker, the hero block, the week row, the day scrubber, the SHOW chips with the map, TOP and GAPS columns, and the cold spots section. The current week is selected with "ALL WEEK" active | ✅ | [ ] | — |
| BDY-06 | User reads the hero label → App shows "WEEK n · MMM D–D" (or "MMM D–MMM D" when the week crosses a month) for the whole-week view, and "MON · OCT 5 · PUSH DAY" style (weekday, date, template name uppercased, "WORKOUT" if none, "REST" if no workout) for a selected day | ✅ `BodyMapTabView.swift:656-671` | [ ] | — |
| BDY-09 | User reads the big number → App shows working sets in the selected scope over a denominator: "/ 176" (sum of weekly targets) for the whole week, "/ 26" for a single day | ✅ | [ ] | — |
| BDY-12 | User reads the line under the number → App shows "SETS · k/17 GROUPS", k = tracked groups hit as a primary muscle in the scope (each group once) | ✅ | [ ] | — |
| BDY-15 | User taps "‹" in the week row → App moves one week back and resets to "ALL WEEK"; the arrow greys out after 3 weeks back (4 weeks visible: this one and three earlier) | ✅ | [ ] | — |
| BDY-18 | User taps "›" → App moves one week forward and resets to "ALL WEEK"; greyed on the current week, so future weeks cannot be viewed | ✅ | [ ] | — |
| BDY-21 | User reads the week pill → App shows "WK n" (locale `weekOfYear` of that Monday) and "ALL WEEK"; tapping it clears any selected day | ✅ | [ ] | — |
| BDY-24 | User reads the day scrubber → App shows 7 buttons (M..S) with the day number and a small accent underline under days that have a finished workout | ✅ | [ ] | — |
| BDY-27 | User taps a day → App selects it (inverted pill) and the hero, map, TOP/GAPS and VS box switch to that day; tapping the same day again returns to "ALL WEEK". Future days and rest days are selectable and just show zeros / "REST DAY" | ✅ | [ ] | — |
| BDY-30 | User reads the VS box on the current week with no day selected → App shows "VS PACE", a percentage and "{n} DUE BY {MON..SUN}". n = round(176 x elapsed/7) where elapsed counts days from Monday through today inclusive (minimum 1), and the percentage = round((sets - n) / n x 100). Arrow up and green above 0, down and red below, "● 0%" grey at 0 | ✅ `BodyMapTabView.swift:236-244` | [ ] | — |
| BDY-33 | User reads VS PACE on Monday morning with no sets yet → App shows "▼ -100%" in red against 25 due, even though today has barely begun | 🧭 Proposed default: pro-rate by the fraction of today elapsed, or show "—" until the first workout of the week | [ ] | — |
| BDY-36 | User views a past week (no day selected) → App shows "VS WK {n-1}" with the change against the previous Monday-week's total sets and "{prev} SETS" below; "—" and "0 SETS" when the previous week had none | ✅ | [ ] | — |
| BDY-39 | User views week 1 of a year → App prints "VS WK 0" because it subtracts 1 from the week number | 🐞 `BodyMapTabView.swift:245`. Expected the real previous week number | [ ] | — |
| BDY-42 | User selects a day with a finished workout → App shows "VS LAST {FIRST WORD OF TEMPLATE}" (for example "VS LAST PUSH"), the percentage change in total sets against the most recent earlier workout with the identical template name, and "MMM D · n SETS" for that earlier one | ✅ | [ ] | — |
| BDY-45 | User selects a day whose workout has no template, or no earlier same-name workout → App shows "VS LAST" "—" "FIRST SESSION" | ✅ | [ ] | — |
| BDY-48 | User selects a rest day → App shows "VS LAST" "—" "REST DAY", hero 0 / 26, all groups 0 | ✅ | [ ] | — |
| BDY-51 | User taps the VOLUME chip (default) → App colours each of the 17 groups by level: for the whole week, min(1, sets / weekly target); for a single day, sets / the largest group-total of that day, so the most-worked group is always full strength and the rest are relative to it | ✅ `BodyMapTabView.swift:728-733` | [ ] | — |
| BDY-54 | User reads the legend under the map in VOLUME mode → App shows a gradient with "0%" to "100% OF TARGET", which is wrong in day view where 100% means "busiest group that day" | 🐞 `BodyMapTabView.swift:143-148`. Expected a day-specific legend or day view normalised to the daily target | [ ] | — |
| BDY-57 | User taps the LAST 48H chip → App colours each group by recency of its last primary-muscle workout (across all history, not just the shown week): level = max(0, 1 - hoursSince / 48), measured from a reference time of 21:00 on the selected day (or, for the whole-week view, on the later of the week's Sunday and today's date, capped at today). Legend: "48H+ AGO" to "JUST TRAINED" | 🟡 The reference is an assumed 21:00, not the real time (`BodyMapTabView.swift:712-726`) | [ ] | — |
| BDY-60 | User trained at 08:00 today and views LAST 48H today → App shows level about 0.73 (13 of 48 hours elapsed against the 21:00 reference), not 1.0 | 🟡 Follows from BDY-57 | [ ] | — |
| BDY-63 | User trained at 22:30 today and views LAST 48H today → App ignores that workout (its time is after the 21:00 reference) so the groups look untouched until tomorrow | 🐞 `BodyMapTabView.swift:721` `w.date <= now`. Expected: use the real current time for the current week | [ ] | — |
| BDY-66 | User reads the map → App shows FRONT and BACK silhouettes side by side (not a swipeable pager), each labelled; front covers traps, chest, front/side delts, biceps, forearms, abs, obliques, quads, calves; back covers traps, upper back, lats, lower back, rear/side delts, triceps, forearms, glutes, hamstrings, calves. A group on both sides (traps, side delts, forearms, calves) shows the same level on both | 🐞 `CLAUDE.md` says the Body tab uses `TabView(.page)` to swipe between front and back; code shows both figures at once (`BodyMap2DView.swift:114-119`). Doc is stale or design intent was swipe; owner to decide | [ ] | — |
| BDY-69 | User taps a muscle region → App opens the muscle detail sheet for that group (BMS). Taps on empty space do nothing; left and right limbs are one group | ✅ | [ ] | — |
| BDY-72 | User reads "▲ TOP" → App lists the 3 groups with the highest sets/target ratio in scope: abbreviation (CHEST, LATS, QUADS, HAMS, GLUTE, F.DELT, S.DELT, R.DELT, BICEPS, TRICEPS, TRAPS, U.BACK, FOREARM, L.BACK, CALVES, ABS, OBLIQ), "sets/target" and "▲ n%" (n = ratio x 100, truncated, may exceed 100) in green | ✅ | [ ] | — |
| BDY-75 | User reads "▼ GAPS" → App lists the 3 lowest ratios, lowest first, each with "▼ n%" in red even when n is 0 | ✅ | [ ] | — |
| BDY-78 | User selects a single day → App still divides that day's sets by the weekly target for TOP/GAPS (for example 4 chest sets read "4/16, 25%") | 🟡 Mixed with the 26-set daily denominator in the hero | [ ] | — |
| BDY-81 | System: TOP/GAPS ties (for example all zero) → App picks among tied groups in an unspecified order | 🟡 Not deterministic by design | [ ] | — |
| BDY-84 | User scrolls to the cold spots → App shows a title and 3 cards, with chips FREQ (default) and VOL | ✅ | [ ] | — |
| BDY-87 | User reads FREQ ("COLD SPOTS · n STALE") → App shows the 3 groups with the highest daysSinceLastTrained / cadence ratio, each as "nD / cD" with a red bar when days >= floor(1.5 x cadence). Days are calendar days since the last finished workout that hit the group as primary or secondary (all history, independent of the selected week). A never-trained group shows 99D | ✅ `BodyMapTabView.swift:416-431` | [ ] | — |
| BDY-90 | User taps VOL ("UNDER TARGET · n LOW") → App shows the 3 groups with the lowest sets / weekly target over the rolling last 7 days from now (primary sets count in full, secondary-only sets count half using integer division), flagged red when under 50% | ✅ `BodyMapTabView.swift:432-446` | [ ] | — |
| BDY-93 | User compares cold spots with the rest of the tab → App uses different windows and rules (rolling 7 days and secondary credit versus Monday weeks and primary only), so one muscle can read differently in two places | 🟡 Documented in the audit as intentional but undocumented in UI | [ ] | — |
| BDY-96 | User reads the ticker (shown when any non-deleted workout exists) → App scrolls items: VS PACE or VS LAST with its value, "WK{n}" with the absolute percent change of last week versus the week before, the top 3 and bottom 3 groups with percentages, and PUSH, PULL, LEGS with days since the last workout whose template name contains that word ("—" if none). The item list is doubled before display | 🟡 `BodyMapTabView.swift:746-765`. Label "WK{n}" ignores the browsed week and the "VS WK" label is shown as "VS LAST" | [ ] | — |
| BDY-99 | User with Pulse+ vs free uses the main tab → App behaves identically; there is no gating on the map, hero, TOP/GAPS, cold spots or calendar | ✅ | [ ] | — |
| BDY-102 | User looks for the spec's extras → App has no Pulse+ muscle sub-region zones on the silhouette, no neglected-muscle nudge badges, no push/pull balance analysis, no volume sparkline, no skin tone or body type customisation, no colour scheme presets, and Settings shows "Simple Body Map" as "COMING SOON" | ❌ Not built (spec Phase 6; design reference 6.5 lists a 12-week sparkline) | [ ] | — |

### BDY edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| BDY-E01 | Brand-new user, no workouts | Ticker hidden; hero "0 / 176", "SETS · 0/17 GROUPS"; VS PACE reads "▼ -100%" with the day's due count; map shows only the base tint; TOP/GAPS all 0%; cold spots FREQ shows three delt groups as "99D / 3D" flagged ("COLD SPOTS · 3 STALE") | There is no dedicated empty state or onboarding hint | 🟡 Proposed: add an empty-state message | [ ] | — |
| BDY-E02 | Device region starts weeks on Sunday | Body tab still builds Monday-to-Sunday weeks; the "WK n" label comes from the locale's `weekOfYear` of the Monday, so it can differ by one from other regions and from the Weekly Recap (ISO) around year boundaries | | 🟡 | [ ] | — |
| BDY-E03 | Midnight passes while the tab is open | Elapsed days, "today" and the VS PACE target refresh only on the next render; no timer | | 🟡 | [ ] | — |
| BDY-E04 | Workout started 23:50 and finished 00:30 | Counted on the day it started | | ✅ | [ ] | — |
| BDY-E05 | Timezone change | Day buckets and the 21:00 reference use the current timezone | | 🟡 | [ ] | — |
| BDY-E06 | DST day | 21:00 reference built with `byAdding: .hour` from start of day, week arithmetic with `byAdding: .weekOfYear`; no known drift | | ✅ | [ ] | — |
| BDY-E07 | Two workouts on the same day | Hero, map and TOP/GAPS include both; the day label, VS LAST and the calendar card use only the first one found (query order is not sorted) | Audit flagged | 🐞 `BodyMapTabView.swift:220,662,596`. Expected: combine or list both | [ ] | — |
| BDY-E08 | Draft workout in progress | Excluded from sets, groups and VS; but it still makes the ticker appear because the empty check counts drafts | `workouts.isEmpty` at line 747 | 🟡 | [ ] | — |
| BDY-E09 | Deleted workout | Excluded everywhere (query predicate) | | ✅ | [ ] | — |
| BDY-E10 | Exercise with only untracked muscles (hip flexors, adductors, abductors, neck) | Adds nothing to the map, hero groups or TOP/GAPS; its sets still count in the hero total | | 🟡 Total can exceed the sum of groups | [ ] | — |
| BDY-E11 | Exercise tagged with both generic and specific groups (Overhead Press: shoulders + front delts) | Counted once on the specific group; generic dropped | `MuscleGroup.trackedGroups` (fixes the audit's double counting) | ✅ | [ ] | — |
| BDY-E12 | Exercise tagged only "back" or only "shoulders" | Credited to upper back or side delts respectively | Fallback group | ✅ | [ ] | — |
| BDY-E13 | Secondary muscles | Do not affect hero, map, TOP/GAPS; only cold spots use them | | 🟡 Spec says secondary muscles get reduced heat intensity | [ ] | — |
| BDY-E14 | Offline | Everything is local; no difference | | ✅ | [ ] | — |
| BDY-E15 | Warm-up only exercise | Contributes 0 sets and no group | | ✅ | [ ] | — |
| BDY-E16 | Very large history | The queries load all logs and workouts; heat, cold spots and ticker recompute several times per render | Audit perf finding | 🟡 | [ ] | — |
| BDY-E17 | Dark mode | Base tint switches to a warm light at 10% opacity; accent stays the same blue | | ✅ | [ ] | — |

## BDC  CAL calendar sheet

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| BDC-03 | User taps "CAL" → App opens a sheet (heights 440 or 560) with a drag indicator, opening on the month of the Monday of the week currently shown | ✅ | [ ] | — |
| BDC-06 | User reads the grid → App shows "MONTH YYYY" in capitals, "‹ ›", M T W T F S S and a fixed 42-cell Monday-first grid; days with finished workouts are tinted with a dot, today has a 1.5pt accent border, future days are faint and never marked | ✅ | [ ] | — |
| BDC-09 | User taps "‹" → App goes one month back unless that month starts before the month of the earliest workout (then greyed) | ✅ | [ ] | — |
| BDC-12 | User taps "›" → App goes forward only if (shown month + 1 month, same day-of-month) is not after now | 🐞 `BodyMapTabView.swift:541`. When the sheet opens on a Monday that is in the previous month (for example Monday 28 Sep, today 1 Oct) October cannot be reached. Expected a month-start comparison | [ ] | — |
| BDC-15 | User taps a day with no workout, a future day or a blank cell → App ignores the tap (cell disabled) | ✅ | [ ] | — |
| BDC-18 | User taps a day with a workout → App selects it, grows the sheet to 560 and shows a card: "EEE D MMM", the template name ("Workout" if none), "{n} SETS · m:ss" for the first workout of that day only | 🟡 Same-day second workout is not shown (BDY-E07) | [ ] | — |
| BDC-21 | User taps the same selected day again → App deselects it and shrinks the sheet to 440 | ✅ | [ ] | — |
| BDC-24 | User taps "VIEW ›" on a day within the last 4 Monday-weeks → App closes the sheet, sets the week offset and selects that weekday in the scrubber | ✅ `BodyMapTabView.swift:608-625` | [ ] | — |
| BDC-27 | User selects a day older than 4 weeks → App shows "OLDER THAN 4 WEEKS" instead of the VIEW button | ✅ | [ ] | — |

### BDC edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| BDC-E01 | No workouts at all | Calendar shows the current month with no marks; earlier months blocked; no tappable days | | ✅ | [ ] | — |
| BDC-E02 | Sunday-first locale | Grid still starts on Monday | | ✅ | [ ] | — |
| BDC-E03 | Workout at 23:50 | Appears on its start day | | ✅ | [ ] | — |
| BDC-E04 | Different from History calendar | This one blocks future months/days and only lets workout days be tapped; History allows any day | See file 05 CAL | 🟡 | [ ] | — |

## BMS  Muscle detail sheet

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| BMS-03 | User taps a region → App opens a sheet titled with the muscle name ("Chest", "Rear Delts") and a "Done" button | ✅ | [ ] | — |
| BMS-06 | User reads "Performed" → App lists exercises (approved or custom, with this muscle as primary or secondary) that have at least one finished log, A to Z, each with "{n} sessions" where n counts exercise logs (two logs in one workout count twice) | 🟡 Wording says sessions; `finalLogs.count` counts logs | [ ] | — |
| BMS-09 | User reads "Not Yet Tried" → App lists the remaining matching exercises in muted text | ✅ | [ ] | — |
| BMS-12 | User is a paying Pulse+ subscriber and the muscle has sub-regions → App shows a "Sub-Regions" section with "{n} exercises" per sub-region and sub-region labels under exercise names. A free user, and a user only in the free trial, do not see these | 🟡 `MuscleDetailSheet.swift:29,48`. Gate is `isSubscribed` only; other Plus gates (widgets, deload) also accept the trial. Proposed: include `isInFreeTrial` | [ ] | — |
| BMS-15 | User looks for trend graphs, volume or last-trained info in the sheet → App shows none; rows are not tappable and do not open the exercise detail | ❌ Spec: trend graphs at the top and coloured/greyed exercises | [ ] | — |
| BMS-18 | User taps a back or shoulder region → App matches exercises by exact tag, so an exercise tagged only with the generic "back" or "shoulders" does not appear under Upper Back or Side Delts although the Body tab credits it there | 🐞 `MuscleDetailSheet.swift:13-16` vs `MuscleGroup+Tracked.swift`. Expected the same folding rule | [ ] | — |
| BMS-21 | User sees the highlighted sub-region dot → App never lights it (the sheet is always opened with no sub-region) | 🟡 Dead parameter | [ ] | — |

### BMS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| BMS-E01 | No exercise has been done for the muscle | Only "Not Yet Tried" appears; with no matching exercises the sheet is empty | | 🟡 No empty-state text | [ ] | — |
| BMS-E02 | Workout containing the exercise deleted | Exercise moves to "Not Yet Tried" if it has no other logs | | ✅ | [ ] | — |
| BMS-E03 | Pulse+ status check fails offline | StoreKit status is cached locally; sub-region sections follow the last known state | | 🟡 Not verified | [ ] | — |
| BMS-E04 | Draft sets | Excluded (`finalLogs`) | | ✅ | [ ] | — |

## Open decisions for the owner (06)

- BDY-33 (🧭): VS PACE shows -100% on Monday morning. Proposed: pro-rate by time of day or hide until the first workout.
- BDY-66: front and back are side by side, while `CLAUDE.md` says swipeable pages; decide which is intended and update the doc or the UI.
- BDY-54: legend says "100% OF TARGET" in day view where it means "busiest group".
- BDY-57 / BDY-60 / BDY-63: LAST 48H uses an assumed 21:00 reference and drops later workouts; proposed: use the real time for the current week.
- BDY-39: "VS WK 0" in week 1. BDC-12: next-month arrow blocked near month starts.
- BDY-E07: same-day second workout is invisible in label, VS LAST and calendar.
- BDY-93: cold spots use a different window and secondary credit than the rest of the tab.
- BDY-102: unbuilt spec items (sub-region zones, nudge badges, push/pull balance, sparkline, customisation, Simple Body Map, colour presets).
- BMS-12: Pulse+ gate excludes the free trial here but not elsewhere. BMS-15: sheet has no trend graphs. BMS-18: generic-group mismatch.
- BDY-E01: no empty state for new users.
- BDY-E02: week-number label differs by locale (also see file 02 HOM-39).
