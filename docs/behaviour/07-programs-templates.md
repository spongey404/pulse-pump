# 07 Programs, templates and template sharing

Scope: the Programs tab (tab 0), preset and custom templates (`WorkoutTemplate`), the template detail/edit screen, share-link import (`pulsepump://template?data=...`), the Settings training split and the Home "NOT TODAY?" day picker. Source: `PulsePump/Features/Programs/*`, `PulsePump/Core/Persistence/TemplateSeedService.swift`, `PulsePump/Core/Persistence/TemplateShareService.swift`, `PulsePump/Core/Persistence/SplitSchedule.swift`, `PulsePump/App/ContentView.swift`, `PulsePump/App/PulsePumpApp.swift`, `PulsePump/Features/Settings/SettingsView.swift` (`SplitConfigView`).

Terminology: a "program" on screen is a group of one or more templates ("days") that share the same `splitDays` array. There is no separate Program model; `ProgramGroup` is computed at render time. A template stores `templateExercises` (name, sets, reps, RIR, rest seconds, notes per exercise) as a JSON struct array.

Unreachable code in this area (compiled, no call site): `TemplateListView`, `EditTemplateView`, `ProgramDayPickerSheet`, `programsTickerItems` in `ProgramsTabView`. The template Share button/sheet in `TemplateDetailView` has state and a sheet but nothing sets `showShareSheet = true`, so the sender side of sharing is not reachable.

## PRG  Programs list, grouping, delete, quick start

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PRG-03 | User taps the Programs tab (leftmost) → App shows header "PROGRAMS", a blue "+" square at top right, one row per program group, a dashed "NEW PROGRAM" button, and (if any finished workout exists) a "QUICK START" list. Nav bar is hidden. | ✅ ProgramsTabView.swift:77-104 | [ ] | — |
| PRG-06 | System: first launch after sign-in → App seeds 7 preset templates once (Push Day, Pull Day, Leg Day, Upper Body, Lower Body, Full Body A, Full Body B) so three program rows appear. Seeding runs in `ContentView.onAppear` and only when the template table is empty (tombstones count). Preset ids are derived from the name so every device seeds the same ids. | ✅ TemplateSeedService.swift:11-28, ContentView.swift:108 | [ ] | — |
| PRG-09 | System: templates load → App sorts templates alphabetically by name, then buckets them by `splitDays.joined()`. Templates with empty `splitDays` are never grouped (each is its own row). | ✅ ProgramsTabView.swift:8,17-37 | [ ] | — |
| PRG-12 | System: a group has more than one template → App derives the row title from the day names: push+pull+leg = "Push Pull Legs"; push+leg = "Push Legs"; pull+leg = "Pull Legs"; push+pull = "Push Pull"; upper+lower = "Upper Lower"; any "full" = "Full Body"; otherwise names joined with " / ". A single-template group uses the template name. Matching is lowercase substring. | ✅ ProgramsTabView.swift:39-55 | [ ] | — |
| PRG-15 | User views a row → App shows the title uppercased, a sub-line "N DAYS/WK · M EXERCISES · LAST USED", and one small square chip per entry of `splitDays` (letters such as P, P, L), then a chevron. DAYS/WK = `splitDays.count` (or template count when no split days, minimum 1). M = total exercises across all templates in the group. | ✅ ProgramGroupRowView.swift:12-40, ProgramGroup.swift:10-12 | [ ] | — |
| PRG-18 | System: row last-used text → App shows "NEVER" when no logged workout references any template of the group, otherwise a relative abbreviated time uppercased (for example "3D AGO"). Based on `liveWorkouts` of every template in the group. | ✅ ProgramGroup.swift:14-20 | [ ] | — |
| PRG-21 | User taps a program row → App pushes `TemplateDetailView` with the group's templates as day tabs (see TPL-33). | ✅ ProgramsTabView.swift:90,107-114 | [ ] | — |
| PRG-24 | User swipes a row left → App reveals a red 72pt trash button. Dragging must be mostly horizontal. Tapping the row content does not close the reveal (resetReveal is never passed). | 🟡 reveal stays open until swiped back; SwipeToDeleteRow.swift | [ ] | — |
| PRG-27 | User taps the trash → App shows a full-bleed destructive modal: kicker "▲ DELETE PROGRAM", tag "IRREVERSIBLE", title "Delete {program name}?", body "The program template will be removed. Workouts you've already logged using it will be kept in your history.", a "WHAT YOU'LL LOSE" block with three numbers (workout days, exercises, "past sessions kept"), and buttons "KEEP" and "DELETE". | ✅ ProgramsTabView.swift:137-161; the "IRREVERSIBLE"/"WHAT YOU'LL LOSE" header sits above a "past sessions kept" line (misleading wording, DestructiveModal.swift:53,85) | [ ] | — |
| PRG-30 | User taps "DELETE" → App soft-deletes every template of the group (sets `deletedAt`, bumps `updatedAt` so the delete syncs) and the row disappears. Logged workouts remain in History. | ✅ ProgramsTabView.swift:146-148 | [ ] | — |
| PRG-33 | User taps "KEEP" → App closes the modal, nothing changes. | ✅ | [ ] | — |
| PRG-36 | System: user deletes every program → App shows empty state "NO PROGRAMS" and "Tap + to add a preset or build your own." (the NEW PROGRAM button still shows below). Presets are NOT re-seeded on next launch because the seed check counts tombstoned rows. | ✅ ProgramsTabView.swift:201-215, TemplateSeedService.swift:14 (older audit claim of re-seeding is stale) | [ ] | — |
| PRG-39 | System: at least one finished workout exists → App shows "QUICK START" with the 3 most recent finished workouts: template name uppercased ("WORKOUT" when no template), relative date, and an accent "START" button. | ✅ ProgramsTabView.swift:246-295 | [ ] | — |
| PRG-42 | User taps a Quick Start "START" → App calls `onStartFromTemplate(workout.template)` and the active workout opens full screen. Button is disabled and 40% opaque when `workout.template == nil`. | ✅ ProgramsTabView.swift:268-284 | [ ] | — |
| PRG-45 | User taps Quick Start "START" for a workout whose program was deleted → App starts a workout from the deleted template. Soft delete only sets `deletedAt`; the `workout.template` link is kept, so the button is enabled. Expected: disabled like the nil case. | 🐞 ProgramsTabView.swift:269,283 (`workout.template` is not checked for `deletedAt`); verify on device | [ ] | — |
| PRG-48 | User taps "START" in Quick Start or template detail while a draft workout already exists → App starts a second draft; no discard prompt (Home shows "DISCARD + START NEW" confirmation, Programs does not). | 🟡 ContentView.swift:120-123 vs HomeTabView.swift:224-232; behaviour of the orphaned first draft not verified | [ ] | — |
| PRG-51 | System: Quick Start list vs repeats → App lists the last 3 workouts by date, so the same template can appear three times. | ✅ ProgramsTabView.swift:256 | [ ] | — |

### PRG edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PRG-E01 | Two programs share identical `splitDays` (for example the user adds the Push Pull Legs preset twice, or a custom program with 6 days and "PPL" collides with the preset) | The templates merge into one group (6 days, doubled day tabs). | Grouping key is only `splitDays.joined()`, not the program identity. Preset copies from the picker get new random ids, so duplicates are possible. | 🐞 ProgramsTabView.swift:21 | [ ] | — |
| PRG-E02 | Custom program with no split type, name "Chest" and 3 days vs another program named "Core" with 3 days | Both generate `["C","C","C"]` and merge into one group. | `generateSplitDays` falls back to the first letter of the name. | 🐞 CreateTemplateView.swift:357 | [ ] | — |
| PRG-E03 | Offline | Everything on this tab works; deletes sync when online. | Local-first SwiftData. | ✅ | [ ] | — |
| PRG-E04 | Delete a program while another device edits it | Last writer by `updatedAt` wins (sync rules). | See 12-cloud-sync-data.md. | 🧭 exact merge rule is owned by the sync spec | [ ] | — |
| PRG-E05 | Group order and day order | Both alphabetical by template name (so "Leg Day", "Pull Day", "Push Day"), not training order. | `@Query(sort: \.name)`. Day tabs are labelled by that order. | 🟡 likely unexpected for PPL | [ ] | — |
| PRG-E06 | Template soft-deleted on another device and synced here | Row disappears; its `templates` @Query filters `deletedAt == nil`. | | ✅ ProgramsTabView.swift:8 | [ ] | — |

## TPL  Add, create, view and edit a program

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| TPL-03 | User taps the blue "+" in the Programs header → App opens a full-height sheet "CHOOSE A TEMPLATE" with caption "All exercises are editable after selecting" and 4 rows: "Blank Program" ("Start from scratch — add your own exercises and structure"), "Push Pull Legs" ("6-day split. Push (chest/shoulders/triceps), Pull (back/biceps), Legs. High frequency."), "Upper Lower" ("4-day split. ..."), "Full Body" ("3-day split. ... Great for beginners."). A "×" closes it. | ✅ PresetTemplatePicker.swift | [ ] | — |
| TPL-06 | User taps a preset row → App closes the sheet, inserts a fresh copy of every template of that preset (new random ids, not the seeded stable ids), and pushes the detail screen on the first copy with all copies as day tabs. | 🟡 duplicates are always created, even if the seeded preset already exists (ProgramsTabView.swift:116-126); copies carry unresolved exercise ids until a later seed/repair or workout start resolves them by name | [ ] | — |
| TPL-09 | User taps "Blank Program" → App dismisses the sheet and, 0.35 s later, pushes `CreateTemplateView`. | ✅ ProgramsTabView.swift:127-132 | [ ] | — |
| TPL-12 | User taps the dashed "NEW PROGRAM" button → App pushes `CreateTemplateView` directly (skips the preset picker). | ✅ ProgramsTabView.swift:219-242 | [ ] | — |
| TPL-15 | User opens the create form → App shows header "NEW PROGRAM" with "‹" and "SAVE", fields "PROGRAM NAME" (placeholder "E.G. MY PPL PROGRAM"), "DAYS PER WEEK" (buttons 1-7), "SPLIT TYPE (OPTIONAL)" chips "PPL", "UPPER / LOWER", "FULL BODY" "BRO SPLIT", "CUSTOM", "EXERCISES  0 ADDED" with an empty card ("No exercises yet", "Add exercises to build your program. You can configure sets, reps and RIR for each."), and "NOTES (OPTIONAL)". | ✅ CreateTemplateView.swift | [ ] | — |
| TPL-18 | User taps a days-per-week number → App selects it; tapping the same number again deselects it. | ✅ CreateTemplateView.swift:117-119 | [ ] | — |
| TPL-21 | User types a name and selects a day count → App enables "SAVE" (accent fill). Without a non-blank name AND a day count SAVE is greyed and disabled. Exercises are not required: a program with zero exercises can be saved. | ✅ CreateTemplateView.swift:17-19 | [ ] | — |
| TPL-24 | User taps "ADD EXERCISE" → App pushes the exercise picker (see LIB-03); on choosing one or more exercises the picker closes and each is appended to the form as 3 sets, no target reps. The same exercise can be added more than once. | ✅ CreateTemplateView.swift:39-49,363-369 | [ ] | — |
| TPL-27 | User taps the red minus on an added exercise → App removes it from the list immediately (no confirm). There is no reorder and no sets/reps editing in the create form despite the empty-state copy promising it. | 🟡 copy says "You can configure sets, reps and RIR" but only the detail screen does (CreateTemplateView.swift:207) | [ ] | — |
| TPL-30 | User taps "SAVE" → App inserts ONE template with the trimmed name and `splitDays` generated from days and split type (PPL cycle P,P,L; UPPER / LOWER cycle U,L; FULL BODY F; BRO SPLIT C,B,L,S,A; otherwise first letter of the name repeated), then closes the form. The new program appears in the list. | ✅ CreateTemplateView.swift:331-360 | [ ] | — |
| TPL-33 | User types in NOTES and saves → App discards the notes. The `notes` state is never read in `save()`. Expected: stored in `template.notes`. | 🐞 CreateTemplateView.swift:12,295-347 | [ ] | — |
| TPL-36 | User taps "‹" with unsaved input → App leaves without confirmation. | 🧭 PROPOSED: add a "Discard program?" confirm when the form has input | [ ] | — |
| TPL-39 | User opens a program → App shows custom header: back "‹", small caption (group name uppercased, or "N EXERCISES · M LOGGED" when opened via preset add/without group name), template name uppercased, and "EDIT" + "START" buttons. | ✅ TemplateDetailView.swift:123-196 | [ ] | — |
| TPL-42 | System: group has more than one template → App shows a pill tab per day labelled "{FIRST WORD OF NAME} {n}" (for example "PUSH 1", "PULL 2", "LEG 3"). Tapping a tab switches the active day and collapses expanded exercises. | ✅ TemplateDetailView.swift:200-233 | [ ] | — |
| TPL-45 | User taps an exercise row → App expands it, showing a column header TYPE / # / REPS / "+ RIR" / "REST" and one row per set. The collapsed row shows stat pills "N SETS × R REPS · RIR". | ✅ TemplateDetailView.swift:254-309 | [ ] | — |
| TPL-48 | User taps "EDIT" → App switches to edit mode: header button becomes accent "DONE"; "ADD EXERCISE" and "+ ADD SET" appear; reps/RIR fields become numeric text fields; type, RIR and REST chips become tappable; NOTES box becomes editable. Edits write straight to the model (no Save button; "DONE" only leaves edit mode). | ✅ TemplateDetailView.swift:152-165,89 | [ ] | — |
| TPL-51 | User types in a REPS field (edit mode) → App changes the target reps for ALL sets of that exercise (one `targetReps` per exercise, shown on every row). Digits only; no clamp (0 or 999 accepted); empty = no target, shown as "—". | 🟡 per-exercise not per-set (TemplateDetailView.swift:452-455) | [ ] | — |
| TPL-54 | User taps "+ ADD SET" → App increments the exercise's `targetSets` (no upper limit). | ✅ TemplateDetailView.swift:527-540 | [ ] | — |
| TPL-57 | User swipes a set row left and taps trash (edit mode) → App decrements `targetSets` by one; refuses when only 1 set is left. Row identity is by index, so the reveal follows the position. No confirmation. | ✅ TemplateDetailView.swift:414-421 | [ ] | — |
| TPL-60 | User taps "+ RIR" (edit mode) → App sets `targetRIR` to 2 and shows a RIR column; tapping "× RIR" clears it. Outside edit mode the chip does nothing. | ✅ TemplateDetailView.swift:337-345 | [ ] | — |
| TPL-63 | User taps the REST chip (edit mode) → App opens a sheet "REST TIMER" with a 4-column grid OFF, 0:30, 1:00, 1:30, 2:00, 2:30, 3:00, 3:30, 4:00, 5:00, 7:00, 10:00, a MIN/SEC wheel (minutes 0-10, seconds in 5 s steps) and a "SAVE" button. OFF stores nil. The chip then shows "m:ss". Rest from templates is used by the workout rest timer after each logged set. | ✅ TemplateDetailView.swift:370-377,621-739; consumer RestTimerService.swift:105-111 | [ ] | — |
| TPL-66 | User taps a set TYPE chip (edit mode) → App opens an inline picker with the 8 set types (see SetType short names). Default shown: first set of an exercise with more than one set is "WU", all others "STD". The choice lives in view `@State` only: it is lost when leaving the screen and never reaches the logger. | 🐞 TemplateDetailView.swift:20,30-40 (cosmetic; expected persisted or hidden) | [ ] | — |
| TPL-69 | User taps "ADD EXERCISE" in edit mode → App opens the exercise picker as a sheet; chosen exercises are appended with 3 sets, no reps. | ✅ TemplateDetailView.swift:101-115 | [ ] | — |
| TPL-72 | User views NOTES → App shows the box only if the template has notes or edit mode is on. Placeholder "Add workout notes, focus cues, reminders…". Notes are shown in quotes in read mode. Template notes are not shown in the active workout. | 🟡 stored and shareable, never surfaced during a workout | [ ] | — |
| TPL-75 | User looks for rename, remove exercise, reorder, change days/split in the detail screen → App offers none of them. The drag-handle bars on each row are decorative. `EditTemplateView` (name + exercise list with minus + steppers) exists but nothing navigates to it. | ❌ rename / remove / reorder / change split days not reachable | [ ] | — |
| TPL-78 | User taps "START" (not in edit mode) → App calls `onStartWorkout(activeTemplate)`: a new draft workout is created with one entry per template exercise (sorted by `order`), N empty sets with target reps/RIR, per-exercise rest seconds, and the active workout opens full screen. Exercises are linked by id, falling back to normalized name. | ✅ WorkoutViewModel.swift:49-87 | [ ] | — |

### TPL edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| TPL-E01 | Program name blank or only spaces | SAVE stays disabled. | | ✅ | [ ] | — |
| TPL-E02 | Very long program name | Row title is single line (`lineLimit(1)`), truncated. No max length. | | 🧭 PROPOSED: cap at 40 characters | [ ] | — |
| TPL-E03 | Duplicate program names | Allowed. Home prediction and widget start-by-name use the first match by name. | `templates.first { name == }` in ContentView.swift:64 and HomeTabView.swift:105. | 🟡 | [ ] | — |
| TPL-E04 | Template exercise points to a missing/renamed exercise id | At start the logger falls back to the normalized name; if nothing matches it keeps the stored id and name. | WorkoutViewModel.swift:67-71, TemplateSeedService repair. | ✅ | [ ] | — |
| TPL-E05 | Targets: 0 sets via data | `max(targetSets, 0)` creates no sets for that exercise. | UI never lets sets go below 1 (swipe guard) but import payload is clamped to at least 1. | ✅ | [ ] | — |
| TPL-E06 | Double-tap SAVE on create | `save()` then `dismiss()` run once per tap; a fast second tap could insert a second template before the screen leaves. | No guard flag. | 🟡 not reproduced | [ ] | — |
| TPL-E07 | lbs user | Programs store no weights, so units do not apply here. | | ✅ | [ ] | — |
| TPL-E08 | Offline | All of this is local. | | ✅ | [ ] | — |
| TPL-E09 | Kill the app mid-edit in detail | Edits were already written to the model on each change; they survive. | No explicit `save()`; SwiftData autosave. | 🟡 relies on autosave timing | [ ] | — |
| TPL-E10 | Edit saved through the detail screen does not call `markUpdated()` | Sync still picks it up through the `ModelContext.didSave` change tracker (digest comparison). | SyncChangeTracker.swift. | 🟡 depends on safety-net path | [ ] | — |

## TSH  Share link and import

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| TSH-03 | User looks for a way to share a template → App shows no Share button in the detail header (only EDIT and START). The share sheet is wired in `TemplateDetailView` (`ShareSheet(items: [URL])`) but `showShareSheet` is never set to true. | ❌ sender UI unreachable (TemplateDetailView.swift:15,97-100) | [ ] | — |
| TSH-06 | System: `TemplateShareService.shareURLString(for:)` is called → App builds `pulsepump://template?data=<percent-encoded base64 of JSON>`. JSON carries name, notes (omitted if empty) and ordered exercises with name, sets, reps, rir, rest, notes. Exercise ids and split days are not included, and only the active day is shared (not the whole program). | ✅ TemplateShareService.swift:27-44 (service only; no UI calls it) | [ ] | AuditFixesTests.swift:81-118 |
| TSH-09 | User opens a `pulsepump://template?data=...` link while the app is already running on the main tab shell → App posts `.importTemplate`; `ContentView` decodes, creates a new template and shows an alert titled "Shared template" with message `Added "{name}" (N exercises) to your programs.` and an "OK" button. | ✅ PulsePumpApp.swift:84-110, ContentView.swift:70-85 | [ ] | — |
| TSH-12 | System: import creates the template → App matches each shared exercise to the catalogue by normalized name (also tries "Equipment Name" ordering for names like "Bench Press (Barbell)"); built-ins win over same-named customs. Unknown names become new custom exercises (`isCustom = true`, `isApproved = false`, no muscles). Sets are clamped to at least 1. The new template has no split days, so it appears as its own program row. | ✅ TemplateShareService.swift:62-81, DataImportService.swift:268-303 | [ ] | AuditFixesTests.swift |
| TSH-15 | User opens a link with a missing/garbled `data` value (not base64, empty JSON, blank name, or zero exercises) → App shows the same alert with "That template link couldn't be read." Nothing is created. A link with no `data` query item at all is ignored silently (no alert). | ✅ ContentView.swift:70-77; PulsePumpApp.swift:106-110 | [ ] | AuditFixesTests.swift:117-118 |
| TSH-18 | User opens the same valid link twice → App imports twice: no duplicate detection, two identical programs appear. | 🟡 TemplateShareService.swift:62-81 | [ ] | — |
| TSH-21 | User taps a template link while the app is not running (cold launch), or while signed out/onboarding/restoring → App drops the import silently. `NotificationCenter` is not buffered and `ContentView` (the only observer) is not on screen yet. | 🐞 PulsePumpApp.swift:84-110 vs ContentView.swift:70; expected: queue the link and import once the main shell appears | [ ] | — |
| TSH-24 | System: link opened by a user who does not have the app → iOS cannot open the custom scheme (nothing to open it); no App Store fallback text is shared (the spec asked for a plain-text fallback). | ❌ spec (docs/pulse-pump-spec.md:420) not met | [ ] | — |
| TSH-27 | System: `pulsepump://start-workout?template=NAME` (widget) → App starts that template by exact name match on active templates; unknown name starts a blank workout. | ✅ PulsePumpApp.swift:88-91, ContentView.swift:62-69 | [ ] | — |

### TSH edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| TSH-E01 | Oversized payload (hundreds of exercises) | Imported in full; no cap on exercises, sets or text length. | | 🧭 PROPOSED: reject above 60 exercises | [ ] | — |
| TSH-E02 | URL-safe base64 or missing `=` padding | Accepted; `-`/`_` are mapped and padding added. | | ✅ TemplateShareService.swift:55-60 | [ ] | — |
| TSH-E03 | Link from a malicious source with huge sets (for example 9999) | Created as-is; the logger will create that many set rows. | Only a lower clamp of 1. | 🧭 PROPOSED: clamp sets to 1...20 | [ ] | — |
| TSH-E04 | Free vs Pulse+ | Template sharing is free (spec) and ungated in code. | | ✅ | [ ] | — |
| TSH-E05 | Imported template has unknown exercise names | Custom exercises are created, listed under their names in the picker (custom shows because `isCustom`), but have no muscle groups so the body map ignores them. | | 🟡 | [ ] | — |

## SPL  Training split (Settings)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SPL-03 | User opens More › Settings › TRAINING › "Training Split" → App pushes a list "Select Split Type" with 9 types: Push/Pull/Legs (6 days/week), Upper/Lower (4), Full Body (3), Bro Split (5), Arnold Split (6), Push/Pull/Legs (6-day) (6), Torso/Limbs (4), Custom, No Split. The current split's type is pre-checked; with none, "Push/Pull/Legs" is pre-selected. | ✅ SettingsView.swift:283-337 | [ ] | — |
| SPL-06 | User selects a type and taps "Save Split" → App writes the default weekly schedule for that type into `Split.days` (for example PPL Mon Push, Tue Pull, Wed Leg, Thu Push, Fri Pull, Sat Leg; Upper/Lower Mon, Tue, Thu, Fri; Full Body Mon, Wed, Fri; Custom Mon/Wed/Fri "Workout A/B/C"), marks the user updated, reschedules reminders, and goes back. "No Split" soft-deletes the split. | ✅ SplitSchedule.swift:11-69, SettingsView.swift:319-325 | [ ] | — |
| SPL-09 | System: split labels → App uses labels equal to preset template names ("Push Day", "Upper Body", "Full Body A") so Home prediction can resolve them to real templates. | ✅ SplitSchedule.swift:5-8 | [ ] | — |
| SPL-12 | System: first main-shell launch with a split that has no days → App fills the default days once (repair). | ✅ RootView.swift:92 | [ ] | — |
| SPL-15 | User changes split → App keeps existing templates untouched; the split and the Programs tab are independent (programs never get rearranged by choosing a split). The More hub header line shows the split name uppercased. | ✅ | [ ] | — |

### SPL edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SPL-E01 | "Push/Pull/Legs" vs "Push/Pull/Legs (6-day)" | Two entries with identical schedules. | Legacy enum cases `.ppl` and `.pushPullLegs` both kept. | 🧭 PROPOSED: hide the duplicate | [ ] | — |
| SPL-E02 | Reminders are on and split changes | Reminders are cancelled and re-created for the new training days. | NotificationService.reschedule. | ✅ | [ ] | — |
| SPL-E03 | Saving split with no user | Row is only shown when a local user exists. | | ✅ | [ ] | — |

## DPK  Home "NOT TODAY?" day picker

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| DPK-03 | User taps "NOT TODAY? ›" on the Home predicted-workout card → App opens a sheet "WHAT'S TODAY?" / "PICK YOUR WORKOUT FOR TODAY" listing every active template alphabetically with a circle initial, uppercased name, and "N EXERCISES". | ✅ WorkoutDayPickerSheet.swift, HomeTabView.swift:216-221,418 | [ ] | — |
| DPK-06 | User taps a template → App closes the sheet and sets the Home prediction override to that template (the card now shows that template's exercise chips). It does not start a workout. | ✅ HomeTabView.swift:217-220 | [ ] | — |
| DPK-09 | System: user has no templates → App shows "NO PROGRAMS YET" / "Create a program first". | ✅ WorkoutDayPickerSheet.swift:51-60 | [ ] | — |
| DPK-12 | System: the override is `@State` → App forgets it when Home is re-created. | 🟡 HomeTabView.swift:16 | [ ] | — |

## Open decisions for the owner (07)

- TPL-36: PROPOSED confirm dialog when leaving the create form with input.
- TPL-E02: PROPOSED name length cap (40).
- TSH-E01 / TSH-E03: PROPOSED import limits (60 exercises, 1...20 sets).
- SPL-E01: PROPOSED hide the duplicate "Push/Pull/Legs (6-day)" split type.
- Share UI is unreachable (TSH-03): decide whether to add a Share button to the detail header (and fix cold-launch link drop TSH-21, and the App Store fallback TSH-24).
- Missing rename / remove exercise / reorder / change split days in detail (TPL-75); `EditTemplateView` is dead code that would also drop RIR/rest/notes on save.
- Program notes on create are discarded (TPL-33) and never shown in the workout (TPL-72).
- Per-set type chips and per-set reps in detail are cosmetic (TPL-51, TPL-66): persist or remove.
- Grouping collisions (PRG-E01, PRG-E02) and alphabetical day order (PRG-E05): decide whether a program needs its own identity.
- Quick Start can start a deleted program (PRG-45) and ignores an existing draft (PRG-48).
- Dead code: `TemplateListView`, `ProgramDayPickerSheet`, `programsTickerItems`.
