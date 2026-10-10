# 03a Workout logging: lifecycle (start, exercises, discard, drafts)

Scope: how a session starts (template, predicted, blank, widget link), the active-session shell, adding and changing exercises, discarding, saving a draft and recovering after a crash. Sets, tools and timers are in `03b-sets-tools.md`; finishing and posting are in `03c-finish-share.md`.
Key sources: `PulsePump/Features/Workout/WorkoutViewModel.swift`, `WorkoutViewModel+Draft.swift`, `Views/ActiveWorkoutView.swift`, `Views/ExercisePickerView.swift`, `Views/Logger/ExerciseCardView.swift`, `Features/Home/StartWorkoutDock.swift`, `App/ContentView.swift`, `App/PulsePumpApp.swift`.

Status legend: ✅ implemented and verified in code | 🟡 partial | ❌ not built | 🐞 known bug | 🧭 proposed (owner decides).

## WK  Workout lifecycle (start and session shell)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WK-03 | User taps the "START WORKOUT ›" dock on Home (no draft exists) → App starts a session from the predicted template and covers the screen with the active workout (full-screen cover). The dock reads "TODAY · <split label>", the predicted name in capitals and "~N MIN" | ✅ `StartWorkoutDock.swift:130`, `ContentView.swift:52` | [ ] | — |
| WK-06 | System: dock builds its "~N MIN" estimate → App uses the duration of the last finished workout with the same template name if longer than 60 s, else 55 | ✅ `StartWorkoutDock.swift:112-121` | [ ] | — |
| WK-09 | User taps a template's start button in Programs → App starts a session pre-filled from that template | ✅ `ContentView.swift:120` | [ ] | — |
| WK-12 | User changes the predicted day on Home (day picker) and taps START → App starts the picked template. Prediction itself is specified in `02` (PRD) | ✅ `HomeTabView.swift:216-219` | [ ] | — |
| WK-15 | User opens `pulsepump://start-workout?template=<name>` (widget tap) → App starts the template whose name matches exactly (`==`, case-sensitive) | 🟡 name match is exact, so a renamed template silently falls through to WK-18 `ContentView.swift:63-67` | [ ] | — |
| WK-18 | User opens `pulsepump://start-workout` with no or an unknown template → App starts a blank workout (no exercises) | ✅ `ContentView.swift:68-70` | [ ] | — |
| WK-21 | User taps START when the predicted name matches no saved template → App starts a blank workout titled "WORKOUT" while the dock showed the predicted name | 🟡 dock shows a name the session then ignores `StartWorkoutDock.swift:98-100` | [ ] | — |
| WK-24 | System: a session starts → App inserts a `Workout` with `isDraft = true`, sets `user` and `template`, zeroes the elapsed clock, clears notes, saves immediately | ✅ `WorkoutViewModel.swift:49-62,86` | [ ] | — |
| WK-27 | System: session starts from a template → App builds one card per template exercise in template order with `targetSets` empty rows (negative counts become 0), carrying template `targetReps`, `targetRIR` and `restSeconds` | ✅ `WorkoutViewModel.swift:63-79` | [ ] | — |
| WK-30 | System: template exercise id is not in the catalogue → App links by normalised name (case, spaces and punctuation ignored); if still unknown it keeps the template's id and name, and the exercise logs without catalogue traits (barbell, compound, weighted defaults) | ✅ `WorkoutViewModel.swift:90-97`, `ExerciseEntry` defaults | [ ] | — |
| WK-33 | User looks at the masthead → App shows "SESSION" then "<TEMPLATE NAME or WORKOUT> · m:ss" (h:mm:ss after one hour), plus the REST pill | ✅ `ActiveWorkoutView.swift:241-283`, `WorkoutViewModel.swift:654` | [ ] | — |
| WK-36 | System: every second → App recomputes elapsed from `startTime` (not by counting ticks), so the clock stays right after backgrounding | ✅ `WorkoutViewModel.swift:516` | [ ] | — |
| WK-39 | User logs sets → App fills the FINISH WORKOUT bar left to right with the accent colour in proportion `done / total` sets (including warm-ups) and shows "N LEFT", or "DONE ›" when none are left | ✅ `ActiveWorkoutView.swift:39-42,339-357` | [ ] | — |
| WK-42 | User taps the header of an exercise card (not the drag handle or "···") → App collapses or expands the card (chevron rotates). Collapse state is not saved | ✅ `ExerciseCardView.swift:316` | [ ] | — |
| WK-45 | User looks at a card header → App shows "NN" index, NAME in capitals, equipment, then "PR <w>×<reps> · 1RM ~<n> · ▲/▼ <delta>" or "PR — · 1RM —" when no history, and "done/total" sets | ✅ `ExerciseCardView.swift:238-285` | [ ] | — |
| WK-48 | System: header loads history → App takes the best working set by Epley 1RM (weight x (1 + reps/30), weight and reps both above 0) as the PR chip, and the delta as best weight of the last session minus the session before (shown only when above 0.01 kg and the session before had a weight) | ✅ `ExerciseCardView.swift:186-215` | [ ] | — |
| WK-51 | System: app moves to the background mid-session → App persists the draft (completed sets, order, notes, elapsed). On return to the foreground it refreshes the rest timer | ✅ `ActiveWorkoutView.swift:233-236` | [ ] | — |
| WK-54 | User watches the calorie estimate during the session → App computes `liveCalories` after every log and un-log but shows it nowhere | ❌ spec asks for a live calorie display; value is computed but no view reads it `WorkoutViewModel.swift:36,192` | [ ] | — |
| WK-57 | User starts a session while Live Activities are enabled → App starts a Live Activity named after the template (or "Workout"). Details in `11` (LIV) | ✅ `WorkoutViewModel.swift:85` | [ ] | — |
| WK-60 | User starts a workout from Programs or a widget link while a draft already exists → App starts a second draft without deleting or asking about the first | 🐞 expected: single active workout rule, old draft deleted after confirmation (spec Phase 4); actual: `startWorkout` has no draft guard, old draft is left orphaned in the store and the dock keeps showing `drafts.first` by `updatedAt` `WorkoutViewModel.swift:49`, `ContentView.swift:120-128` | [ ] | — |

### WK edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| WK-E01 | Template has an exercise with `targetSets` 0 | Card appears with zero rows; user must tap "+ ADD SET" | `max(targetSets, 0)` | ✅ | [ ] | — |
| WK-E02 | User starts a blank workout and finishes at once | Finish button shows "DONE ›" (0 left) and finishing saves an empty workout (see FIN-E01) | No minimum-content guard | 🟡 | [ ] | — |
| WK-E03 | Double-tap START quickly | The cover is already presented after the first tap; a second `startWorkout` would reset entries. Only one draft is inserted per call, so two quick calls make two drafts | No debounce in `startWorkout` | 🧭 propose: ignore start while `isActive` | [ ] | — |
| WK-E04 | Midnight passes during a session | Elapsed time keeps counting; the workout keeps the date it was created with (`Workout.date` set at insert) | Date is not recomputed at finish | 🧭 propose: keep start date (current) | [ ] | — |
| WK-E05 | Device clock changed during the session | Elapsed uses `Date()` minus `startTime`, so a backwards jump gives a negative value shown as a malformed clock | Not clamped | 🟡 | [ ] | — |
| WK-E06 | Signed out or no local `User` row | The dock renders nothing (needs a `User`), so a session cannot start from Home | `StartWorkoutDock.swift:33-39` | ✅ | [ ] | — |
| WK-E07 | Widget link arrives while another session is active | Posts the same notification and calls `startWorkout` again (resets in-memory entries of the live session) | Same missing guard as WK-60 | 🐞 `ContentView.swift:63-70` | [ ] | — |
| WK-E08 | Free user vs Pulse+ | Logging, templates and timers are identical | Nothing in this flow is gated | ✅ | [ ] | — |

## EXA  Adding, replacing, removing and reordering exercises

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| EXA-03 | User taps "+ ADD EXERCISE" (dashed button under the last card) → App opens the exercise picker full screen titled "ADD EXERCISE" | ✅ `ActiveWorkoutView.swift:110,227` | [ ] | — |
| EXA-06 | User types in "Search exercises…" → App filters by name, case-insensitive substring; an "x" button clears the text | ✅ `ExercisePickerView.swift:91-100,182-192` | [ ] | — |
| EXA-09 | User taps a movement pill (ALL, then one per movement pattern) → App filters to that pattern; tapping the active pill again returns to ALL | ✅ `ExercisePickerView.swift:203-217` | [ ] | — |
| EXA-12 | System: picker lists exercises → App shows only approved or custom exercises that are not deleted and not already in the session | ✅ `ExercisePickerView.swift:87-89` | [ ] | — |
| EXA-15 | User sees a group row ("<n> VARIANTS ›", e.g. Bench Press) and taps it → App opens a variants page ("<GROUP> / N VARIANTS") with an ADD button per variant | ✅ `ExercisePickerView.swift:6-48,394-401` | [ ] | — |
| EXA-18 | User taps a single-exercise row or its ADD button → App adds that one exercise and closes the picker. Multi-select is not offered even though the callback takes an array | 🟡 one exercise per open `ExercisePickerView.swift:228-231,395-397` | [ ] | — |
| EXA-21 | System: an exercise is added → App appends a card with one empty set row, copies catalogue traits (type, unilateral, equipment, compound), persists the draft and scrolls to the bottom | ✅ `WorkoutViewModel.swift:101-110`, `ActiveWorkoutView.swift:138-145` | [ ] | — |
| EXA-24 | User opens the picker with a search that matches nothing → App shows "No exercises found" and "TRY A DIFFERENT SEARCH" | ✅ `ExercisePickerView.swift:245-256` | [ ] | — |
| EXA-27 | User taps "···" on a card → App opens a 3-row menu anchored to the button (flips above if there is no room): "Replace Exercise", "Rest Timer Override", "Remove Exercise" (red) | ✅ `ActiveWorkoutView.swift:423-470` | [ ] | — |
| EXA-30 | User taps "Replace Exercise" → App opens the picker titled "REPLACE EXERCISE" excluding exercises already in the session (except the one being replaced) and swaps id, name and traits, keeping the existing sets | ✅ `ActiveWorkoutView.swift:198-210`, `WorkoutViewModel.swift:118-124` | [ ] | — |
| EXA-33 | User replaces an exercise that has logged sets → App keeps those sets (weights and reps) under the new exercise; ghost text switches to the new exercise's history | 🟡 sets are not cleared; may be unintended when moving between very different lifts | [ ] | — |
| EXA-36 | User taps "Remove Exercise" → App removes the card at once with no confirmation, including any logged sets, and persists the draft | ✅ `ActiveWorkoutView.swift:457-460` | [ ] | — |
| EXA-39 | User drags the three-line handle on a card → App follows the finger, snaps to a new slot by 190 pt per step, reorders, and persists the draft | 🟡 uses a fixed 190 pt card height estimate, so tall or collapsed cards land in the wrong slot `ActiveWorkoutView.swift:44-56,88` | [ ] | — |
| EXA-42 | User opens "Rest Timer Override" → See RTM-42 in `03b-sets-tools.md` | ✅ | [ ] | — |
| EXA-45 | User wants smart alternative suggestions when replacing (Pulse+) → App offers the same plain picker for everyone | ❌ spec Phase 4 promises Pulse+ suggestions filtered by muscle and equipment; `ExerciseSubstitutionView` exists but is not used anywhere | [ ] | — |

### EXA edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| EXA-E01 | Exercise already in the session | Hidden from the picker | `excludedIds` | ✅ | [ ] | — |
| EXA-E02 | Same exercise needed twice (e.g. two blocks) | Cannot be added twice | Exclusion is by exercise id | 🧭 propose: allow, as lifters repeat lifts | [ ] | — |
| EXA-E03 | Custom exercise created after the session started | Shows in the picker (query is live) | `@Query` | ✅ | [ ] | — |
| EXA-E04 | Exercise deleted (soft) elsewhere while in a session | Existing card stays; on persist `log.exercise` is looked up from the live catalogue and may become nil, which makes the log orphaned and invisible to history by exercise | `exerciseLookup` fetches all exercises including soft-deleted ones, so the link usually survives | 🟡 | [ ] | — |
| EXA-E05 | Remove the only exercise | Session continues with zero cards; finish saves an empty workout | See FIN-E01 | 🟡 | [ ] | — |
| EXA-E06 | Reorder with one card | Drag gives no change | index clamped | ✅ | [ ] | — |
| EXA-E07 | Picker has an unapproved catalogue exercise | Not listed (unless custom) | `isApproved or isCustom` | ✅ | [ ] | — |

## DSC  Discard and save-as-draft

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| DSC-03 | User taps "‹" in the masthead → App shows a modal "Discard current workout?" / "Your progress will be lost. Drafts auto-save for 7 days." with buttons "SAVE AS DRAFT" (left) and "DISCARD WORKOUT" (right). There is no separate Cancel button | ✅ `ActiveWorkoutView.swift:218-226` | [ ] | — |
| DSC-06 | User taps the dim scrim outside the modal → App closes the modal and stays in the session (this is the only way to cancel) | ✅ `WorkoutModal.swift:15-21` | [ ] | — |
| DSC-09 | User taps "DISCARD WORKOUT" → App stops the clock and rest timer, ends the Live Activity, deletes the draft `Workout` and all its logs, clears state and returns to Home. No undo | ✅ `WorkoutViewModel.swift:394-403` | [ ] | — |
| DSC-12 | User taps "SAVE AS DRAFT" → App persists completed sets, stops clocks and Live Activity, clears in-memory state and returns to Home where the dock shows CONTINUE | ✅ `WorkoutViewModel+Draft.swift:27-32` | [ ] | — |
| DSC-15 | User taps "START NEW WORKOUT" (small link above CONTINUE) on Home → App shows "Discard current workout?" / "Your progress on <name> will be lost. Drafts auto-save for 7 days." with "DISCARD + START NEW" | ✅ `HomeTabView.swift:222-234` | [ ] | — |
| DSC-18 | User confirms "DISCARD + START NEW" → App deletes the draft and immediately starts a fresh session from the predicted template (not from the draft's template) | ✅ `WorkoutViewModel.swift:44-47` | [ ] | — |
| DSC-21 | System: modal copy says drafts auto-save for 7 days → App never deletes or expires drafts; a draft lives until continued, discarded or replaced | 🐞 copy promises a 7-day window, no purge exists (grep finds no expiry code). Either implement a purge or reword the copy | [ ] | — |
| DSC-24 | User discards a session in which sets were already logged → App also removes any rest timer notification (`cancelRestEnd`) via `restTimer.stop()` | ✅ `WorkoutViewModel.swift:395-396`, `RestTimerService.swift:61-68` | [ ] | — |

### DSC edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| DSC-E01 | Double-tap DISCARD | Modal closes on the first tap; second tap hits nothing | modal removed | ✅ | [ ] | — |
| DSC-E02 | Discard when the draft was already synced | Drafts are never synced, so nothing remote to delete | `sync-architecture.md`: drafts stay on device | ✅ | [ ] | — |
| DSC-E03 | Discard with zero logged sets | Same modal; discards an empty draft | No special-casing | ✅ | [ ] | — |
| DSC-E04 | Kill the app while the discard modal is open | Draft is still there; Home shows CONTINUE | Nothing deleted until the tap | ✅ | [ ] | — |
| DSC-E05 | Swipe down on the full-screen cover | Cover is bound to `isActive`; the system gesture does not dismiss it (no `interactiveDismissDisabled`, but fullScreenCover is not swipe-dismissible) | | ✅ | [ ] | — |

## CRS  Draft persistence and crash recovery (isDraft)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| CRS-03 | User ticks a set → App writes the completed set to SwiftData at once (an `ExerciseLog`/`SetLog` keyed by stable ids, no duplicates) | ✅ `WorkoutViewModel.swift:158-159`, `+Draft.swift:35-93` | [ ] | — |
| CRS-06 | User unticks a set → App removes that set from the persisted draft | ✅ `WorkoutViewModel.swift:170-176`, `+Draft.swift:89` | [ ] | — |
| CRS-09 | User adds, removes, replaces or reorders an exercise → App persists the draft immediately | ✅ `WorkoutViewModel.swift:109,115,123,128` | [ ] | — |
| CRS-12 | User types a weight or reps but has not ticked the set, then the app is killed → App loses that typed value (only ticked sets persist; typing does not trigger a save) | 🟡 by design ("Nothing here runs per keystroke") `+Draft.swift:10` | [ ] | — |
| CRS-15 | User edits an exercise note then the app is killed before any other save → App loses the note unless a save ran after it | 🟡 notes persist only on the next reconcile | [ ] | — |
| CRS-18 | User relaunches the app after a crash or kill → Home shows the CONTINUE bar: "CONTINUE", the template name in capitals (or "WORKOUT"), "<n> SETS DONE", "TAP TO RESUME ›", with a progress fill of persisted sets over the template's total target sets (capped at 100%) | ✅ `StartWorkoutDock.swift:20-31,60-115` | [ ] | — |
| CRS-21 | User taps CONTINUE → App rebuilds the session: exercises in order, ticked sets with weight, reps, RIR, duration, distance, set type and side restored, notes restored, and unlogged rows re-created up to the template's target (at least 1 row) | ✅ `+Draft.swift:98-155` | [ ] | — |
| CRS-24 | System: resume → App restores the elapsed time from the saved duration (the clock continues from there, not from zero), restarts the Live Activity and recomputes calories | ✅ `+Draft.swift:149-154` | [ ] | — |
| CRS-27 | User resumes → App shows ghost text and PR chips again from history; unlogged rows show ghost values, not the previous typed values | ✅ | [ ] | — |
| CRS-30 | System: Home draft query → App takes the newest draft by `updatedAt`; history, calendar and sync exclude drafts (`isDraft` filtered) | ✅ `StartWorkoutDock.swift:11-12`, `Workout+Stats.swift:46-53` | [ ] | — |
| CRS-33 | System: draft exists and user opens another tab → App keeps the draft untouched; it never appears in History, Body map stats, streaks or the feed | ✅ | [ ] | — |
| CRS-36 | System: workout is finished → App converts the same draft in place (`isDraft = false`), drops exercises with no ticked set and marks it dirty for cloud sync | ✅ `WorkoutViewModel.swift:241-245` | [ ] | — |
| CRS-39 | User resumes a draft whose template was deleted → App resumes with exercises from the logs; unlogged rows are not rebuilt (no template targets) and each exercise has at least one row | ✅ `+Draft.swift:109-140` | [ ] | — |
| CRS-42 | User resumes a draft with an exercise whose catalogue record is gone (`log.exercise == nil`) → App skips that exercise and its logged sets disappear from the session | 🟡 `guard let exercise = log.exercise else { continue }` `+Draft.swift:116` | [ ] | — |

### CRS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| CRS-E01 | Kill the app between ticking a set and the save finishing | Save is synchronous on the main actor right after the tick, so the window is tiny | `try? modelContext.save()` ignores errors | 🟡 save failure is silent | [ ] | — |
| CRS-E02 | Two devices | Drafts are device-local; the second device shows no CONTINUE card | `sync-architecture.md` | ✅ | [ ] | — |
| CRS-E03 | Draft is days old | Resumes normally; elapsed shows the saved duration, not wall time | No expiry (see DSC-21) | 🟡 | [ ] | — |
| CRS-E04 | User resumes then immediately discards | Draft deleted as DSC-09 | | ✅ | [ ] | — |
| CRS-E05 | Resume called while another session is in memory | Entries and timers are reset before restoring ("never stack") | `+Draft.swift:99-102` | ✅ | [ ] | — |
| CRS-E06 | Rest timer was running when the app was killed | Not restored; the pill shows "—:—" after resume | Timer is in memory only | 🧭 propose: do not restore (current) | [ ] | — |
| CRS-E07 | Two drafts exist (WK-60) | Dock shows only the newest; older one is invisible and never cleaned | Consequence of WK-60 | 🐞 | [ ] | — |
| CRS-E08 | Unit changed between save and resume | Stored kg values restore unchanged; display converts | kg invariant | ✅ | [ ] | — |
| CRS-E09 | Draft restored with a warm-up chip | Set type is restored, warm-up styling returns | | ✅ | [ ] | — |

## Open decisions for the owner (03a)

- WK-60 / WK-E07 / CRS-E07: enforce the single-active-workout rule for Programs and widget starts (confirm then delete the old draft). Proposed: reuse the Home confirmation dialog.
- DSC-21: "Drafts auto-save for 7 days" has no purge behind it. Choose: implement a 7-day delete, or reword to "Drafts are kept until you finish or discard them".
- WK-54: live calorie display is computed but not shown. Decide whether to show it in the masthead or drop the spec line.
- WK-03 vs spec: the spec describes a "Resume Workout" button with "how long ago it was started"; the app shows "CONTINUE ... N SETS DONE". Decide which is right.
- WK-E03 (🧭): ignore START while a session is active.
- WK-E04 (🧭): keep the workout date at session start (current behaviour) versus finish time.
- CRS-E06 (🧭): rest timer is not restored after a crash (current behaviour).
- EXA-E02 (🧭): allow adding the same exercise twice.
- EXA-45: smart (Pulse+) substitutions are promised by the spec and `ExerciseSubstitutionView` is dead code; build or remove.
- EXA-18: multi-select in the picker is not offered; decide if wanted.
- EXA-39: reorder uses a fixed 190 pt card height; replace with measured heights or a list reorder.
