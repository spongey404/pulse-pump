# 03b Workout logging: sets, set types, plate tools, rest timer, supersets, notes

Scope: everything on an exercise card during a session: set rows, ghost ("previous") text, set types, inline and standalone plate calculators, the warm-up generator, the rest timer and its notification, supersets and notes.
Key sources: `Features/Workout/Views/Logger/{SetRowViews,ExerciseCardView,SetTypeSheetView,SetTypeStyle,InlinePlateViews,RestTimerViews,WorkoutNotesAndBars}.swift`, `Features/Workout/WorkoutViewModel.swift`, `Features/Workout/Services/RestTimerService.swift`, `Features/Workout/Tools/*`, `Core/Utilities/{PlateMath,DecimalParsing}.swift`, `OreShared/WeightUnit.swift`, `Core/Services/Notifications/SystemRestEndNotifier.swift`.
Weights are stored in kg; text fields show and accept the user's unit (`KgTextField`).

Status legend: ✅ implemented and verified in code | 🟡 partial | ❌ not built | 🐞 known bug | 🧭 proposed (owner decides).

## SET  Logging sets (rows, ghost text, ticking, types)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SET-03 | User opens an expanded exercise card → App shows a column header "TYPE  #  KG/LB  REPS  [RIR]  ✓", one row per set and, below the rows, "+ ADD SET" and "RIR ON/OFF" buttons | ✅ `ExerciseCardView.swift:352-380,116-166` | [ ] | — |
| SET-06 | User looks at a row → App shows the type chip (dashed "+" for standard), a two-digit set number ("01"), weight field, reps field, optional RIR field, and a 22 pt circle on the right | ✅ `SetRowViews.swift:49-120` | [ ] | — |
| SET-09 | User taps the weight field → App opens a decimal keypad; reps and RIR open a number pad. Fields are centred, 18 pt bold mono | ✅ `SetRowViews.swift:75-106` | [ ] | — |
| SET-12 | User types "82,5" (comma keyboards) in kg → App stores the text as typed and reads it as 82.5 at save time | ✅ `DecimalParsing.swift:6-25` | [ ] | — |
| SET-15 | User types weight in lbs → App converts to a kg string with 4 decimals as they type (225 lb is stored as 102.0582 kg) and the field keeps showing what they typed | ✅ `WeightUnit.swift` `kgString(displayText:)`, `SetRowViews.swift:265-282` | [ ] | — |
| SET-18 | System: set row is empty and the exercise has a previous finished session → App shows ghost text (faint ink) in the weight and reps fields from the most recent finished session's set at the same index | ✅ `WorkoutViewModel.swift:218-227`, `SetRowViews.swift:174-179` | [ ] | — |
| SET-21 | System: ghost source → App uses only finished, non-deleted workouts (drafts excluded) and the single latest log of that exercise, by set order including warm-ups, so a warm-up in the last session shifts every ghost down one row | 🟡 position-based, not set-type aware `WorkoutViewModel.swift:219-222` | [ ] | — |
| SET-24 | System: previous set had weight 0 or reps 0 → App shows no ghost for that field (blank field with a faint underline) | ✅ `WorkoutViewModel.swift:224-225`, `SetRowViews.swift:194-201` | [ ] | — |
| SET-27 | System: ghost weight → App prints the kg value in the display unit (a 100 kg ghost shows "220.5" for lbs users, trimmed) | ✅ `SetRowViews.swift:80` | [ ] | — |
| SET-30 | User types over a ghost → App shows the typed value in full ink and hides the ghost | ✅ | [ ] | — |
| SET-33 | User taps the check circle on a set whose fields are empty but show ghosts → App saves the ghost values as the logged weight and reps (only for the empty field), then marks the set done | 🟡 works as the code comment intends; spec Phase 4 says ghost is passive and "Do NOT auto-fill". Decide which wins (see Open decisions) `WorkoutViewModel.swift:147-190` | [ ] | — |
| SET-36 | User taps the check on a set with empty fields and no ghost (first time doing the lift) → App marks it done with weight 0 and reps 0 | 🟡 no empty-set guard; counts toward SETS and the progress bar `WorkoutViewModel.swift:149-167` | [ ] | — |
| SET-39 | User taps the check on a valid set → App (1) fills ghosts, (2) runs the hidden PR check, (3) marks done, (4) computes calories, (5) persists the draft, (6) starts the rest timer when the mode is auto | ✅ `ExerciseCardView.swift:337-342`, `WorkoutViewModel.swift:149-167` | [ ] | — |
| SET-42 | User taps the check on a completed set → App un-completes it, recomputes calories and removes it from the persisted draft. The rest timer is not stopped | ✅ `WorkoutViewModel.swift:170-176` | [ ] | — |
| SET-45 | System: set is the first not-done set of its card → App tints that one row (accent soft background, 2 pt accent bar, ringed circle) so only one row per card is "active" | ✅ `SetRowViews.swift:34-46,217-220` | [ ] | — |
| SET-48 | System: a set is completed → App fills the circle with the accent colour and a white tick; the row returns to the plain background (never tinted green) | ✅ `SetRowViews.swift:209-216` | [ ] | — |
| SET-51 | System: a PR is detected on tick → App marks `isPR` on the set but shows nothing during the session ("PRs stay a surprise"). PRs appear on the completion screen | ✅ `WorkoutViewModel.swift:457-487`, `SetRowViews.swift:76-77` | [ ] | — |
| SET-54 | User taps "+ ADD SET" → App appends one empty row at the end (it does not copy the previous set's values) | ✅ `WorkoutViewModel.swift:133-137` | [ ] | — |
| SET-57 | User swipes a row left → App slides it to reveal a red 72 pt trash button (snaps open past 40%); tapping the trash deletes the row with an animation. There is no full-swipe delete and no confirmation | ✅ `SwipeToDeleteRow.swift`, `ExerciseCardView.swift:60-69` | [ ] | — |
| SET-60 | User deletes a completed set → App removes it and re-saves the draft; deleting an unticked row changes nothing on disk | ✅ `WorkoutViewModel.swift:139-145` | [ ] | — |
| SET-63 | User taps "RIR OFF" → App shows the RIR column and sets a target RIR of 3 on every set (used only to reveal the column; no 3 is displayed) | 🟡 `ExerciseCardView.swift:138-148` | [ ] | — |
| SET-66 | User taps "RIR ON" → App hides the column and erases every RIR value and target on the card | ✅ `ExerciseCardView.swift:139-143` | [ ] | — |
| SET-69 | System: template set has target RIR, or any set has an RIR value → App shows the RIR column automatically | ✅ `ExerciseCardView.swift:29` | [ ] | — |
| SET-72 | System: template set has target reps → App does not show the target in the row (no placeholder); it is used only as the Live Activity's planned reps | 🟡 `WorkoutViewModel.swift:547` | [ ] | — |
| SET-75 | User opens a time-based exercise → App shows a single numeric field (seconds) in the weight slot, no reps field, and no ghost; the column header still reads "KG"/"LB" and "REPS" | 🐞 expected: header "SEC" (and no REPS) for time exercises; actual: weight headers `ExerciseCardView.swift:362-365` | [ ] | — |
| SET-78 | User opens a distance-based exercise → App shows a single decimal field in the weight slot with no ghost; the unit of the distance is not shown anywhere | 🟡 `SetRowViews.swift:69-74` | [ ] | — |
| SET-81 | User logs a bodyweight exercise (e.g. pull-ups) → App uses the normal weight and reps fields; weight means added load and may stay empty or 0. No bodyweight is added | ✅ `SetRowViews.swift:75-84` | [ ] | — |
| SET-84 | System: completed sets are saved → App stores order by position among the completed sets (gaps from unticked rows close up), weight (kg double), reps, RIR, duration, distance, type, side | ✅ `WorkoutViewModel+Draft.swift:68-88` | [ ] | — |

### SET edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SET-E01 | Type "abc" or "1.2.3" in weight | Field accepts it; at save the value parses to nil and stores 0 | No input filter beyond keypad | 🟡 | [ ] | — |
| SET-E02 | Negative weight ("-5", via paste or external keyboard) | Stored as -5 kg; volume, PR and 1RM maths use it | No clamp | 🐞 expected: reject or clamp at 0 | [ ] | — |
| SET-E03 | Very large weight (99999) or reps (1000) | Accepted and saved; volume and the feed post carry it | No upper bound | 🧭 propose: cap weight at 1000 kg and reps at 999 | [ ] | — |
| SET-E04 | Reps typed "8.5" (paste) | `parseWholeNumber` fails; reps stored 0 | | 🟡 | [ ] | — |
| SET-E05 | Reps "8,0" | Parses to 8 | | ✅ | [ ] | — |
| SET-E06 | Locale decimal comma with thousands ("1.234,5") | Reads 1234.5 | | ✅ | [ ] | — |
| SET-E07 | User switches kg to lbs mid-session (Settings is out of the session, so on return) | Rows re-render in lbs from the kg strings; nothing stored changes | `.onChange(of: unit)` | ✅ | [ ] | — |
| SET-E08 | lbs entry like "22." (trailing dot) | Passed through unconverted until valid, so typing is not interrupted | `kgString(displayText:)` | ✅ | [ ] | — |
| SET-E09 | Double-tap the check | First tap completes, second tap un-completes (toggle) | No debounce | 🟡 | [ ] | — |
| SET-E10 | Tick on a set while another set above is still empty | Allowed; active highlight stays on the first not-done set | | ✅ | [ ] | — |
| SET-E11 | Exercise has no history | No ghosts; empty fields show an underline dash | | ✅ | [ ] | — |
| SET-E12 | History exists but fewer sets than today | Rows beyond the previous count show no ghost | `setIndex < sorted.count` | ✅ | [ ] | — |
| SET-E13 | Exercise replaced mid-session | Ghosts follow the new exercise id at once | | ✅ | [ ] | — |
| SET-E14 | Previous session was logged on another device and synced | Ghost uses it once pulled (same store) | | ✅ | [ ] | — |
| SET-E15 | Free vs Supernova | Ghost text and logging identical | `spec` lists ghost text as free | ✅ | [ ] | — |

## STY  Set types

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| STY-03 | User taps the type chip on a row → App slides up a "SET TYPE" sheet with eight rows (chip, name, description) and a dot on the current type | ✅ `SetTypeSheetView.swift:17-100` | [ ] | — |
| STY-06 | User taps a row in the sheet → App sets that type on the set, closes the sheet. Tapping outside closes without a change | ✅ `ActiveWorkoutView.swift:160-172` | [ ] | — |
| STY-09 | System: sheet rows → App lists: Standard "Normal working set", Warmup "Excluded from volume", Superset "Paired with next exercise, no rest", Dropset "Multiple weight drops in one set", Rest-Pause "Short rest, continue same set", AMRAP "As many reps as possible", To Failure "Last possible rep", Unilateral "Log left and right sides separately" | ✅ copy as shown | [ ] | — |
| STY-12 | System: chip labels → App shows STD (dashed "+"), WU, SS, DROP, RP, AMRAP, FAIL, L/R in type colours | ✅ `SetTypeStyle.swift:10-19` | [ ] | — |
| STY-15 | User changes a set's type → App does not persist the draft at that moment; the type is saved with the next set tick or exercise change | 🟡 `ActiveWorkoutView.swift:164` | [ ] | — |
| STY-18 | User marks a set Warmup → App dims the row to 65% and from then on excludes it from set totals, volume, best set, PRs (live and final), calories, muscle counts and the feed post. The set is still saved and visible in history | ✅ `WorkoutViewModel.swift:197,262,463`, `FeedPostBuilder.swift:37-44` | [ ] | — |
| STY-21 | System: warm-up still counts for the FINISH progress bar and the "N LEFT" counter and for the card's "done/total" | ✅ `ActiveWorkoutView.swift:30-35` | [ ] | — |
| STY-24 | User marks a set Dropset → App only changes the chip. Each drop must be its own row (add set, type the lower weight, mark DROP). One row cannot hold several weights despite the description | 🟡 description over-promises `SetTypeSheetView.swift:21` | [ ] | — |
| STY-27 | User marks a set To Failure, AMRAP or Rest-Pause → App only changes the chip; rest-pause does not shorten the timer, AMRAP does not require reps | 🟡 label only | [ ] | — |
| STY-30 | User marks a set Unilateral (L/R) → App only changes the chip. There is no left/right toggle; `side` stays "both" and the feed post sends no side | ❌ side picker not built; the sheet description says "Log left and right sides separately" `WorkoutViewModel.swift:714,342` | [ ] | — |
| STY-33 | User logs an exercise flagged unilateral in the catalogue → App shows the normal rows; there is no per-side rows or automatic duplication | ❌ `Exercise.isUnilateral` is copied onto the entry but no view reads it | [ ] | — |
| STY-36 | System: any non-warm-up type → App treats it as a working set in PR checks and volume, including Drop, Failure and Rest-Pause | ✅ `Workout+Stats.swift:13` | [ ] | — |

### STY edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| STY-E01 | Drop set heavier than the preceding set | Accepted; PR logic sees the heaviest | | ✅ | [ ] | — |
| STY-E02 | Failure set with 0 reps | Saved with reps 0 | no guard | 🟡 | [ ] | — |
| STY-E03 | All sets of an exercise are warm-ups | Exercise is saved but is skipped from the completion counts, PRs and the feed post | `completeWorkout` skips exercises with no working set | ✅ | [ ] | — |
| STY-E04 | Type change on a completed set | Applies; takes effect on the next reconcile and on completion | | ✅ | [ ] | — |
| STY-E05 | Imported Hevy/Strong set types | Mapped on import (see `10` IMP); unknown types fall back to standard | not re-verified here | 🧭 | [ ] | — |

## PLT  Plate calculator (inline in the logger and standalone)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PLT-03 | System: exercise equipment is barbell, EZ bar, trap bar or smith machine, the set is the next not-done one, and its weight (typed or ghost) is greater than the bar → App shows a strip under the row "PLATES · 100KG  ▾ SHOW" | ✅ `ExerciseCardView.swift:30-32,72-95` | [ ] | — |
| PLT-06 | User taps the strip → App expands a panel (spring animation) and the strip changes to "▴ CLOSE"; tapping again collapses it | ✅ `ExerciseCardView.swift:75-103` | [ ] | — |
| PLT-09 | System: panel opens → App shows "PLATE CALCULATOR", the target in the display unit in large type, "KG · BAR 20" (or "LB · BAR 45"), a drawing of the bar with plates both sides, and plate chips per side from heaviest | ✅ `InlinePlateViews.swift:96-146` | [ ] | — |
| PLT-12 | System: plates are chosen → App fills each side greedily with the heaviest plate that still fits, using the saved plate set (default kg: 1.25, 2.5, 5, 10, 15, 20, 25; default lb: 2.5, 5, 10, 25, 35, 45) | ✅ `PlateMath.swift:29-42`, `WeightUnit.swift:148-153` | [ ] | — |
| PLT-15 | System: the plate set cannot make the exact weight → App shows what it can load and a "+0.5KG OFF" style note for the per-side remainder (only when at least one plate is loaded) | 🟡 note says KG without saying "per side" `InlinePlateViews.swift:139-143` | [ ] | — |
| PLT-18 | User taps a bar chip (BARBELL 20/45, WOMEN'S 15/35, EZ 7.5/15, TRAP 25/55, SAFETY 32/65) → App recalculates for that bar and highlights the chip | ✅ `PlateMath.swift:55-61`, `InlinePlateViews.swift:150-177` | [ ] | — |
| PLT-21 | System: each exercise card starts on the Olympic bar (20 kg or 45 lb) regardless of equipment. An EZ-bar or trap-bar exercise does not preselect its own bar | 🟡 `ExerciseCardView.swift:182` | [ ] | — |
| PLT-24 | User changes weight unit → App resets the card's bar to the new unit's Olympic bar | ✅ `ExerciseCardView.swift:183` | [ ] | — |
| PLT-27 | System: lb user loads 225 lb → App uses real lb plates (45 lb = 20.4117 kg stored) and shows nominal numbers (45, 45, 45) | ✅ `PlateMath.swift:24-42` | [ ] | — |
| PLT-30 | System: plate chip colours → App colours by size tier (red 24 kg+, blue 18-24, yellow 12-18, green 9-12, black 4.5-9, grey 2.2-4.5, light below) so lb plates colour like their kg twins | ✅ `PlateMath.swift:82-93` | [ ] | — |
| PLT-33 | User edits plates (Equipment profile plates) expecting the logger to follow → App ignores profile plates; the logger and the standalone tool read a separate device-local list (`customPlates` / `customPlatesLbs`) | 🟡 `EquipmentProfile.availablePlates` is synced but unused here `PlateMath.swift:66-79` | [ ] | — |
| PLT-36 | User wants the standalone Plate Calculator → App has the screen (target, bar picker, per-side list, "Achievable Weight", editable "Available Plates", "Add plate" with an Add button) but no menu, tab or link opens it | ❌ unreachable `PlateCalculatorView.swift` has no caller | [ ] | — |
| PLT-39 | User (if reachable) enters a target at or below the bar → App shows no per-side section | ✅ `PlateCalculatorView.swift:16-19` | [ ] | — |
| PLT-42 | User (if reachable) adds a plate → App stores it in kg for that unit and ignores duplicates within 0.001 kg and values at or below 0 | ✅ `PlateCalculatorView.swift:84-93` | [ ] | — |
| PLT-45 | System: legacy "PER SIDE:" chips view (`InlinePlateView`) → App never shows it | 🟡 dead code `InlinePlateViews.swift:4-58` | [ ] | — |

### PLT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PLT-E01 | Target barely above bar (e.g. 21 kg on 20 kg) | Per-side 0.5 kg fits no plate; panel shows "BAR ONLY" and hides the remainder | misleading | 🐞 expected: "+0.5 OFF"; actual: "BAR ONLY" `InlinePlateViews.swift:121-126` | [ ] | — |
| PLT-E02 | Target equals the bar | Strip is not shown (needs weight greater than bar) | | ✅ | [ ] | — |
| PLT-E03 | Machine, cable or dumbbell exercise | No strip | equipment check | ✅ | [ ] | — |
| PLT-E04 | Weight cleared after expansion | Strip disappears | | ✅ | [ ] | — |
| PLT-E05 | Smith machine | Treated as a 20 kg bar though smith bars vary | | 🧭 propose: keep, allow bar choice (already available) | [ ] | — |
| PLT-E06 | Only odd plate set (user removed 1.25) | Greedy fill leaves a remainder note | | ✅ | [ ] | — |
| PLT-E07 | Decimal comma in standalone target | `unit.parseKg` accepts "," | | ✅ | [ ] | — |
| PLT-E08 | Bar choice is per card and per session | Not remembered next time | `@State` | 🧭 propose: remember per equipment type | [ ] | — |

## WUG  Warm-up generator (standalone tool)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WUG-03 | User wants to open the Warmup Generator → App has the screen but nothing links to it | ❌ unreachable `WarmupGeneratorView.swift` | [ ] | — |
| WUG-06 | User (if reachable) types a working weight above the bar → App lists a plan: bar x 10, then evenly spaced steps rounded to 2.5 kg / 5 lb, reps `max(3, 10 - 2i)`, then "Working Set" with the typed weight | ✅ `WarmupGeneratorView.swift:10-34` | [ ] | — |
| WUG-09 | User changes "Warmup Sets" (stepper 2-6, default 4) → App recomputes the plan; steps at or below the bar are dropped | ✅ | [ ] | — |
| WUG-12 | User picks a bar (Olympic 20/45, EZ Curl 10/25, Trap 25/55) → App recomputes. The EZ bar here is 10 kg while the plate tool uses 7.5 kg | 🟡 inconsistent bar weights | [ ] | — |
| WUG-15 | User wants to add the plan to the session → App cannot; the plan is display-only and not saved | ❌ | [ ] | — |

### WUG edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| WUG-E01 | Working weight at or below bar | No plan | | ✅ | [ ] | — |
| WUG-E02 | Unit changes | Bar resets to 20 / 45; typed number is not converted | | 🟡 | [ ] | — |

## RTM  Rest timer, alerts and notification

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| RTM-03 | System: no rest running → App shows the masthead pill "REST  —:—  ›" | ✅ `ActiveWorkoutView.swift:287-325` | [ ] | — |
| RTM-06 | System: rest running → App shows "m:ss" counting down with a progress ring that fills as time passes | ✅ `ActiveWorkoutView.swift:301-317` | [ ] | — |
| RTM-09 | User ticks a set with Rest Timer Mode "Auto-Start" or "Auto-Start with Dismiss" → App starts a countdown. In "Manual" nothing starts | ✅ `WorkoutViewModel.swift:161-166` | [ ] | — |
| RTM-12 | System: "Auto-Start with Dismiss" → App behaves exactly like "Auto-Start" (no dismiss behaviour exists) | 🟡 `SettingsEnums.swift:6` | [ ] | — |
| RTM-15 | System: duration choice → App uses, in order: the exercise's override, the template exercise's rest if above 0, then 180 s for compound movement patterns (push, pull, hinge, squat, carry) or 90 s for rotation/isolation | ✅ `RestTimerService.swift:106-115` | [ ] | — |
| RTM-18 | System: global compound/isolation defaults → App reads `compoundRestSeconds` / `isolationRestSeconds` from device settings but Settings has no row to change them | 🟡 no UI `RestTimerService.swift:112-113` | [ ] | — |
| RTM-21 | User taps the REST pill → App opens a centred modal with a ring, large time, "REST · TGT m:ss", four buttons "−15s", "+15s", "+30s", "+1m" and "SKIP REST" or "START TIMER" | ✅ `RestTimerViews.swift:17-100` | [ ] | — |
| RTM-24 | User taps +15s, +30s or +1m while running → App moves the end time by that amount, updates the notification time and raises the target if needed | ✅ `RestTimerService.swift:84-95` | [ ] | — |
| RTM-27 | User taps −15s so remaining reaches 0 or less → App ends the rest at once as completed and plays the alert | ✅ `RestTimerService.swift:87-89` | [ ] | — |
| RTM-30 | User taps an adjust button while no rest is running → App starts a new rest of `max(15, delta)` seconds: "−15s" and "+15s" give 15 s, "+30s" 30 s, "+1m" 60 s | 🟡 −15s starting a timer is odd `RestTimerViews.swift:55-62` | [ ] | — |
| RTM-33 | User taps "START TIMER" → App starts a fixed 90 s rest regardless of exercise | 🟡 ignores the exercise default `RestTimerViews.swift:88` | [ ] | — |
| RTM-36 | User taps "SKIP REST" → App stops the timer without a sound, cancels the notification and closes the modal | ✅ `RestTimerViews.swift:84-87` | [ ] | — |
| RTM-39 | User taps outside the modal → App closes the modal; the rest keeps running | ✅ `RestTimerViews.swift:21` | [ ] | — |
| RTM-42 | User opens "···" then "Rest Timer Override" → App shows "REST TIMER OVERRIDE / Custom rest for <exercise>" with −15 and +15 steppers (minimum 15 s, no maximum), starting from the saved override or 90 | ✅ `ActiveWorkoutView.swift:491-554` | [ ] | — |
| RTM-45 | User taps SAVE in the override → App stores the seconds for that exercise on this device; later ticks of that exercise rest that long, beating the template value | ✅ `ActiveWorkoutView.swift:558`, `RestTimerService.swift:117-123` | [ ] | — |
| RTM-48 | User taps RESET → App removes the override; CANCEL or tapping outside closes with no change | ✅ `ActiveWorkoutView.swift:573-603` | [ ] | — |
| RTM-51 | System: rest reaches zero in the foreground → App clears the pill, records `completedAt`, and plays the alert chosen in Timer Alert: Sound (system sound 1005), Vibration, Sound & Vibration, or Silent (Visual Only) | ✅ `RestTimerService.swift:145-163` | [ ] | — |
| RTM-54 | System: a rest starts → App schedules one local notification "Rest done" / "Log your next set" (time-sensitive, with sound unless alert is Silent) for the end time, replacing any earlier one | ✅ `SystemRestEndNotifier.swift:11-24` | [ ] | — |
| RTM-57 | System: app is in the foreground when the notification fires → App shows no banner (no presentation delegate); only the in-app alert plays | ✅ `SystemRestEndNotifier.swift:3-6` | [ ] | — |
| RTM-60 | System: app returns from the background after the rest ended → App finishes the rest silently if more than 2 s have passed (the notification already alerted); within 2 s it also plays the alert | ✅ `RestTimerService.swift:72-81` | [ ] | — |
| RTM-63 | System: rest stops (skip, discard, finish, save-as-draft, new rest) → App cancels the pending and delivered rest notification | ✅ `RestTimerService.swift:61-68` | [ ] | — |
| RTM-66 | User ticks another set during a rest → App restarts the rest from that exercise's duration and clears the "rest over" mark | ✅ `RestTimerService.swift:41-43`, `WorkoutViewModel.swift:156` | [ ] | — |
| RTM-69 | User changes Rest Timer Mode or Timer Alert in Settings → App reads the stored value on the next tick (no restart needed) | ✅ `SettingsView.swift:133-136`, `RestTimerService.swift:14-22` | [ ] | — |
| RTM-72 | System: rest timer controls on the lock screen / Dynamic Island (−15, +15, skip, log set) → App routes them to the same service. See `11` LIV | ✅ `WorkoutViewModel.swift:610-623` | [ ] | — |

### RTM edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| RTM-E01 | Notification permission denied | No background alert; Live Activity (if on) still shows rest-over; foreground sound still plays | permission is requested at launch in `RootView.swift:95` (see `14`) | ✅ | [ ] | — |
| RTM-E02 | Phone ringer off | Sound uses system sound 1005; whether it plays under mute follows iOS behaviour | not device-verified | 🧭 | [ ] | — |
| RTM-E03 | Rest duration 0 from an override | `start` returns without a timer | `seconds > 0` guard | ✅ | [ ] | — |
| RTM-E04 | Timer hits zero while the user is typing | Alert plays, pill resets; no focus change | | ✅ | [ ] | — |
| RTM-E05 | Kill app during a rest | Pending notification still fires once; timer is gone on relaunch | notification is not cancelled on crash | 🟡 | [ ] | — |
| RTM-E06 | Override set on one device | Not synced, other devices use template/global value | UserDefaults only | 🧭 propose: leave device-local | [ ] | — |
| RTM-E07 | Clock changes (DST, manual) | Countdown uses an end `Date`; a manual clock jump shifts it | | 🟡 | [ ] | — |
| RTM-E08 | Rest overlaps with discard / finish | Timer and notification are stopped | | ✅ | [ ] | — |
| RTM-E09 | Override minutes huge (taps +15 many times) | Allowed, no cap | | 🧭 propose: cap at 30 min | [ ] | — |
| RTM-E10 | Free vs Supernova | Same for everyone | | ✅ | [ ] | — |

## SUP  Supersets

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SUP-03 | User marks a set "Superset" in the type sheet → App shows a violet "SS" chip on that set | ✅ `SetTypeStyle.swift:13` | [ ] | — |
| SUP-06 | User wants to pair two exercises → App has no way to link exercises, group cards or show "paired with" | ❌ | [ ] | — |
| SUP-09 | User ticks an "SS" set → App starts the normal rest timer, although the sheet says "no rest" | 🐞 expected (per sheet copy): no rest after a superset set; actual: same rest as any set `SetTypeSheetView.swift:20`, `WorkoutViewModel.swift:161` | [ ] | — |
| SUP-12 | System: "SS" sets in totals → App counts them as working sets everywhere | ✅ | [ ] | — |
| SUP-15 | User imports Hevy data with superset ids → App ignores the superset grouping | 🟡 `DataImportService.swift:129` lists the column; grouping not used | [ ] | — |
| SUP-18 | 🧭 proposed design: User taps "Superset with next" in the card menu → App links the two cards (shared group id), alternates focus A1, B1, A2, B2, and starts rest only after the last exercise of the group | 🧭 owner decides; propose rest after the last member only | [ ] | — |

### SUP edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SUP-E01 | Reorder or remove a card in a superset | No pairing exists, so no effect | | ✅ | [ ] | — |
| SUP-E02 | Superset with unequal set counts | Not applicable until grouping exists | | 🧭 | [ ] | — |

## NTE  Notes

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| NTE-03 | User looks at the bottom of an exercise card → App shows a note row: a note icon and "Add exercise note..." in faint ink | ✅ `WorkoutNotesAndBars.swift:43-84` | [ ] | — |
| NTE-06 | System: the exercise had a note last session → App changes the placeholder to "Last: <note>" (not prefilled) | ✅ `ExerciseCardView.swift:170,206` | [ ] | — |
| NTE-09 | User taps the note row → App expands a multi-line field (2 to 6 lines, focused) and a "DONE" button; DONE collapses it | ✅ `WorkoutNotesAndBars.swift:54-67` | [ ] | — |
| NTE-12 | User types a note → App keeps it in memory and saves it with the next draft save (tick, exercise change, background, finish) | 🟡 `+Draft.swift:62` | [ ] | — |
| NTE-15 | User sees a collapsed note → App shows one line of it and a filled note icon | ✅ | [ ] | — |
| NTE-18 | User wants a note for the whole workout → App has no field; `workoutNotes` is saved but nothing sets it | ❌ spec asks for per-workout notes; `WorkoutNotesRow` is not used `WorkoutNotesAndBars.swift:10`, `WorkoutViewModel.swift:11` | [ ] | — |
| NTE-21 | System: notes on finish → App stores exercise notes on each `ExerciseLog` and shows them in workout detail (see `05`) | ✅ `+Draft.swift:62` | [ ] | — |

### NTE edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| NTE-E01 | Very long note | Accepted, no length cap; synced as typed | | 🧭 propose: cap at 2000 chars | [ ] | — |
| NTE-E02 | Note with emoji / newlines | Kept | | ✅ | [ ] | — |
| NTE-E03 | Replace exercise with a note | Note stays on the card (now the new exercise) | | 🟡 | [ ] | — |
| NTE-E04 | Note on an exercise with no ticked set | Dropped at finish with the empty exercise | | ✅ | [ ] | — |

## Open decisions for the owner (03b)

- SET-33: ghost values are saved when a user ticks an empty row; spec says never auto-fill. Proposed: keep current behaviour (it is what the Live Activity LOG SET does too) and update the spec.
- SET-36: ticking a fully empty set logs 0 x 0. Proposed: block the tick (shake) when both weight and reps are empty and there is no ghost.
- SET-21 (🟡): ghost is positional and includes warm-ups. Proposed: match working sets to working sets and warm-ups to warm-ups.
- SET-72: show the template's target reps as a placeholder in the row.
- SET-75 (🐞): fix column headers for time and distance exercises.
- SET-E02 (🐞), SET-E03 (🧭): clamp negative values; propose caps 1000 kg and 999 reps.
- STY-24, STY-27: Drop, Rest-Pause, AMRAP and Failure are labels only. Decide how much behaviour each should have.
- STY-30, STY-33: left/right logging is promised but not built. Decide a UI (side toggle per row, or auto-paired rows for unilateral exercises).
- PLT-21: preselect the bar by equipment (EZ bar to 7.5 kg, trap bar to 25 kg).
- PLT-33: logger plates should follow the active equipment profile.
- PLT-36, WUG-03: standalone Plate Calculator and Warmup Generator are unreachable. Decide where to link them (More hub, card menu).
- WUG-12: reconcile EZ bar weight (10 vs 7.5 kg).
- PLT-E01 (🐞): "BAR ONLY" shown when a remainder exists.
- RTM-12, RTM-18: "Auto-Start with Dismiss" has no distinct behaviour and compound/isolation rest times have no Settings UI.
- RTM-30, RTM-33: adjust buttons starting a timer and START TIMER's fixed 90 s. Proposed: START TIMER uses the current exercise's default.
- RTM-E06 (🧭): per-exercise overrides stay device-local; RTM-E09 (🧭): cap at 30 min.
- SUP-06, SUP-09, SUP-18 (🧭): supersets are label-only. Decide whether to build pairing, and the rest rule.
- NTE-18: workout-level notes have no UI. Build or drop from spec.
- NTE-E01 (🧭): note length cap.
- PLT-E05, PLT-E08 (🧭): smith bar and remembering the chosen bar.
- STY-E05 (🧭), RTM-E02 (🧭): confirm on device.
