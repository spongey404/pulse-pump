# Ore behaviour spec

The single source of truth for what Ore does (and should do). The product owner walks through it on a device and corrects it; unit/UI tests and CI reference step IDs later. It describes what the app REALLY does today, read from the code at commit `bd28578` (branch `feature/social-tab-redesign`), not what older docs claimed. Where docs and code disagree, both are stated.

## How to read it

- One file per area (index below). Each file has flows. A flow has a heading `## XX  Flow name`, a numbered steps table and a `### XX edge cases` table.
- Step rows: `| ID | User does → App does | Status | Manual check | Tests |`. System-initiated rows start `System:`.
- Edge rows: `| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |`.
- **IDs are stable and never renumbered.** Step IDs `XX-NN` leave gaps (usually steps of 3) so new rows can be inserted; edge IDs are `XX-Enn`. Cite IDs in tests and issues. Flow prefixes are globally unique.
- **Manual check** `[ ]`: tick it when you have verified the row on a device. If the app disagrees with the row, change the row (or the Status) and say so.
- **Tests** is `—` everywhere; a later script fills it with test names that cover the row.
- Weights are stored in kg and only displayed in the user's unit; rows say "kg/lb" where display differs.

## Status legend

| Tag | Meaning |
|---|---|
| ✅ | Implemented and verified by reading the code (file:line often cited). Not yet verified on a device unless ticked. |
| 🟡 | Partial: works but something is missing or unverified (the note says what). |
| ❌ | Not built (promised by the spec or design, absent in code). |
| 🐞 | Known bug: expected vs actual, with a `path:line` citation. |
| 🧭 | PROPOSED: behaviour not decided anywhere. The row states a sensible default; the owner must confirm or change it. Never read a 🧭 row as fact. |
| 🚧 | IN PROGRESS: used only in `04-smart-suggestions.md` for the feature that is being built (agreed design). |

Counts below are rows (steps + edge cases) per status. Nothing here was run on a device; "verified in code" means read, not executed. The flows that touch OS behaviour (Live Activity buttons after a kill, small-widget taps, offline Firestore) are 🟡 or 🧭 on purpose.

## Index

| Area | Scope | Steps | Edges | ✅ | 🟡 | 🐞 | ❌ | 🧭 | 🚧 |
|---|---|---|---|---|---|---|---|---|---|
| [01 Account and onboarding](01-account-onboarding.md) | AUTH, HND, ONB, RST, SOUT, DEL: sign-in (Apple/Google/Email), username, onboarding, restore, sign-out, delete | 96 | 52 | 120 | 17 | 2 | 0 | 9 | 0 |
| [02 Home](02-home.md) | HOM, STK, PRD, DRF, FBN, RCT, DOK, GSR, PMN: tiles, streak, predicted workout, draft card, banner, search | 93 | 50 | 97 | 30 | 13 | 0 | 3 | 0 |
| [03a Logging: lifecycle](03a-lifecycle.md) | WK, EXA, DSC, CRS: start, add exercises, discard, drafts, crash recovery | 57 | 29 | 62 | 14 | 4 | 2 | 4 | 0 |
| [03b Logging: sets and tools](03b-sets-tools.md) | SET, STY, PLT, WUG, RTM, SUP, NTE | 97 | 46 | 94 | 28 | 4 | 7 | 10 | 0 |
| [03c Logging: finish and share](03c-finish-share.md) | FIN, KCL, FSM, PST, SHR: finish, summary, calories, post, share card | 60 | 31 | 65 | 13 | 4 | 2 | 7 | 0 |
| [04 Smart suggestions](04-smart-suggestions.md) | SGB (today), SUG, SGS, SGT: progression suggestions (in progress) | 58 | 42 | 11 | 4 | 0 | 2 | 44 | 39 |
| [05 History and exercise detail](05-history-exercise-detail.md) | HIS, CAL, WDT, EDT, XCH, PRR, WRC, PFV | 91 | 53 | 97 | 36 | 4 | 4 | 3 | 0 |
| [06 Body tab](06-body-tab.md) | BDY, BDC, BMS | 50 | 25 | 44 | 21 | 7 | 2 | 1 | 0 |
| [07 Programs and templates](07-programs-templates.md) | PRG, TPL, TSH, SPL, DPK | 61 | 24 | 56 | 14 | 6 | 3 | 6 | 0 |
| [08 Exercise library](08-exercise-library.md) | LIB | 23 | 11 | 24 | 6 | 0 | 2 | 2 | 0 |
| [09a Social: feed and friends](09a-social-feed-friends.md) | FED, POS, CMT, LKE, FRD, PRF, PRV, RPT, SFX | 136 | 83 | 180 | 23 | 3 | 6 | 7 | 0 |
| [09b Social: challenges and activity](09b-social-challenges-activity.md) | CHL, CHC, CHS, CHG, CHP, ACT, CTR | 100 | 63 | 126 | 24 | 4 | 5 | 4 | 0 |
| [10 More and Settings](10-more-settings.md) | MOR, SCF, UNT, NTS, EQP, IMP, EXP, PLS, TUT, WGE, PLG, TOL | 106 | 37 | 95 | 25 | 5 | 13 | 5 | 0 |
| [11 Widgets and Live Activity](11-widgets-live-activity.md) | WGD, WGT, WGP, WGU, WGB, WGG, LIV | 128 | 38 | 114 | 35 | 13 | 0 | 4 | 0 |
| [12 Cloud sync and data](12-cloud-sync-data.md) | SYN, SYC, SYA, SYS, SYR, SYX | 85 | 40 | 100 | 16 | 2 | 1 | 6 | 0 |
| [13 Supernova and gating](13-supernova-gating.md) | GAT, TRL, RPU | 36 | 10 | 18 | 14 | 6 | 6 | 2 | 0 |
| [14 Notifications and reminders](14-notifications-reminders.md) | NTF | 27 | 25 | 35 | 8 | 2 | 3 | 4 | 0 |
| **Total** | | **1304** | **659** | **1338** | **328** | **79** | **58** | **121** | **39** |

Key numbers quoted across the spec (verify against the cited rows): streak expires after a 3-day gap; sync debounce 5 s; feed cache TTL 5 min; free trial is derived from a UserDefaults install date (15 calendar days, see 13); stored weight is always kg.

## Cross-cutting notes

- The audit docs in `docs/audit/` and parts of `CLAUDE.md` / `docs/pulse-pump-spec.md` are stale in places (social is real Firestore now, the widget extension has 14 fixed widgets, `WorkoutActivityAttributes` is in `OreShared`, ~240 exercises are seeded not 84, split days are populated). The spec follows the code.
- Several screens exist in code but are unreachable (see decisions below); they are documented as such rather than as flows users can walk.
- Rule of thumb for fixing a disagreement: edit the row first, then the code or the test. The spec is the contract.

## Headline decisions for the owner

The ten with the widest product impact; the complete per-area lists follow below.

1. **What is Supernova?** The paywall and spec sell cloud sync, challenges, smart predictions, weekly recaps and import/export as Plus; the code gates only MET calories, deload toggle, body-map sub-regions and four widgets (13: GAT-48, GAT-27, GAT-51). Decide the real free/Plus line and the trial rule (14 vs 15 days, UserDefaults date vs StoreKit introductory offer).
2. **Sign-out can silently lose unsynced edits** while the alert says data is safe (01 SOUT-E01, 12 SYA-E01/E02). Warn, block, or accept.
3. **One definition of PR and "improved"** across Home, completion, recap, exercise detail and widgets (05 PRR-30; 02 HOM-24/27) and of "WK n" (02 HOM-39).
4. **Unreachable screens**: Exercise Library / custom exercise creation (08 LIB-54/57), standalone Plate Calculator and Warm-up generator (10 TOL-03/06, 03b PLT-36), PostWorkoutCustomizationView (the earlier-audited AnalyticsView, MuscleBalanceView and BodyModelView no longer exist in code) (10 SCF-69), EquipmentProfiles edit (10 EQP), ProfileMenuSheet (02 PMN-12). Wire in, or delete.
5. **Template sharing**: sender side (Share button) never wired; a share link opened on cold launch is dropped silently (07 TSH-03, TSH-21).
6. **Predicted workout**: when the predicted label matches no template, tapping start begins a blank workout and "NOT TODAY?" is hidden (02 PRD-30/42/54); the design's low-confidence "What do you want to do?" state is not built (PRD-39).
7. **Smart suggestions (04)**: confirm the 🧭 defaults (switch default, increment range, cloud path `users/{uid}/progression/{exerciseId}`, rounding/plate snapping, how drop/failure/unilateral sets count).
8. **Notifications**: permission prompt at launch vs on first enable; denied permission leaves switches ON; reminders survive sign-out; remote push (likes/comments/follows) not built but APNs entitlement present (14 NTF-E02/E05/E12/E21).
9. **Social privacy**: per-post audience override not built; "Only me" posts silently not posted; tightening privacy does not touch past posts; contacts matching removed; shareable invite links not built; moderation process for UGC (09a PRV-E01/E07/36, FRD-69/72, RPT-33).
10. **Settings gaps**: no week-start, default rest time or reminder-time settings; legal links and "Download My Data" are empty actions (App Store risk); Strong/Hevy import error says "Export Error"; MET calories keep working after Plus lapses (10 SCF-69, PLG-06/09).

Also decide: lost failed posts and workout photo dropped on post (03c PST-12/69); live widgets staleness (11 WGD-51/54); restore screen with no timeout or sign-out escape (01 RST-E01, 12 SYA-09).

# Open decisions for the owner (complete, per area)

Every 🧭 row and every product decision already surfaced, verbatim from each area file. Delete bullets as you decide and reflect the decision in the rows.

## 01 Account and onboarding

- AUTH-09: Terms of Service and Privacy Policy are plain text; URLs must be hosted and set in `LegalLinks` before release.
- AUTH-84: No account linking when the same email exists under another provider; decide if Apple/Google/Email should merge.
- HND-E06 (🧭): rename cooldown; proposed unlimited for now, consider 30 days.
- ONB-E07 (🧭): bounds for weight/height; proposed weight 20-500 kg, height 80-260 cm.
- ONB-E12 (🧭): minimum age gate; proposed block under 13.
- ONB-E09: "We've set up a basic template" copy but only a split schedule is created.
- RST-E01 (🧭): add a timeout and escape to the restore screen (proposed 30 s).
- RST-E06 (🧭): warn before wiping when a different account signs in over unsynced data.
- SOUT-E01 (bug): sign-out can silently drop unsynced edits while the alert says data is safe.
- SOUT-E02 (🧭): block sign-out during an active workout.
- SOUT-E03 (bug): sign-out does not cancel local notifications or clear reminder toggles.
- DEL-E06 (🧭): orphaned challenges with other members.
- DEL-E07 (🧭): Apple token revocation on delete.
- DEL-E08 (🧭): subscription warning on delete.
- No guest/offline-first mode: the app cannot be used before signing in and onboarding needs network (ONB-E01).
## 02 Home tab

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
## 03a Workout logging: lifecycle (start, exercises, discard, drafts)

- WK-60 / WK-E07 / CRS-E07: enforce the single-active-workout rule for Programs and widget starts (confirm then delete the old draft). Proposed: reuse the Home confirmation dialog.
- DSC-21: "Drafts auto-save for 7 days" has no purge behind it. Choose: implement a 7-day delete, or reword to "Drafts are kept until you finish or discard them".
- WK-54: live calorie display is computed but not shown. Decide whether to show it in the masthead or drop the spec line.
- WK-03 vs spec: the spec describes a "Resume Workout" button with "how long ago it was started"; the app shows "CONTINUE ... N SETS DONE". Decide which is right.
- WK-E03 (🧭): ignore START while a session is active.
- WK-E04 (🧭): keep the workout date at session start (current behaviour) versus finish time.
- CRS-E06 (🧭): rest timer is not restored after a crash (current behaviour).
- EXA-E02 (🧭): allow adding the same exercise twice.
- EXA-45: smart (Supernova) substitutions are promised by the spec and `ExerciseSubstitutionView` is dead code; build or remove.
- EXA-18: multi-select in the picker is not offered; decide if wanted.
- EXA-39: reorder uses a fixed 190 pt card height; replace with measured heights or a list reorder.
## 03b Workout logging: sets, set types, plate tools, rest timer, supersets, notes

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
## 03c Workout logging: finish, completion summary, calories, caption and post, share card

- FIN-E01 (🧭): block finishing with zero ticked sets. Proposed: disable the button with "Log at least one set".
- FIN-E03 (🧭): the only chance to post is the composer; proposed: add "Share to feed" in workout detail.
- FIN-E04 (🧭): which date a session after midnight gets (start time today).
- KCL-15 (🐞): free users with a stored MET choice. Proposed: fall back to basic when not entitled.
- KCL-18: calories only appear in the ticker; decide if they belong in the stats row.
- KCL-21 / WK-54: live calories during the session.
- KCL-E03 (🧭): idle time inflates MET calories; proposed: leave.
- FSM-15: best set picked by volume, not weight. Proposed: heaviest weight, then reps.
- PST-12 (🐞): photo is accepted and dropped. Decide: upload with the post, or hide the camera.
- PST-57: silent no-post when "Workout posts" is "Only me". Proposed: show "Saved. Not posted (privacy is Only me)".
- PST-63: caption 500 limit with no counter. Proposed: counter and hard stop at 500.
- PST-69 (🐞), PST-E01: failed posts have no retry and are not persisted. Proposed: persist a pending post and retry on foreground.
- PST-E04, PST-E08 (🧭): tag validity after unfriend; photo downscale.
- SHR-09: external sharing (save image, share sheet) is promised by the spec but not built; decide to build or drop. SHR-12: remove or wire `ShareCardView` recap cards.
- SHR-E04 (🧭): choose one watermark ("ORE" or "Ore").
## 04 Smart weight suggestions (progression)

- SUG-21 (🧭): suppress the reps ghost on a suggested row. Proposed: suppress.
- SUG-24 (🧭): chain of suggestions has no cap within a session.
- SUG-30 (🧭): suggestion on the active row only.
- SUG-33 (🧭): the latest ticked working set decides; a lighter later set cancels.
- SUG-36 (🧭): distinguishing look for suggestions (accent-tinted ghost plus a "+inc" tag).
- SUG-42 (🧭): show the suggestion in the Live Activity; LOG SET behaviour.
- SUG-51, SUG-E10, SUG-E11 (🧭): exercise types and bodyweight with weight 0 (off) or added weight (on).
- SUG-E03 (🧭): first set may not use last session's top set (design says session-only).
- SUG-E04 (🧭): equal weights: latest set decides.
- SUG-E06, SUG-E07, SUG-E08 (🧭): how drop, failure, AMRAP, rest-pause and superset sets count.
- SUG-E12 (🧭): unilateral sets until side logging exists (STY-30); per-side evaluation later.
- SUG-E13, SUG-E14 (🧭): no snapping to plate increments; rounding via `roundedDisplay`.
- SUG-E18 (🧭): replacing an exercise recomputes from the card's ticked sets.
- SUG-E21 (🧭): cap suggested weight at 1000 kg.
- SGS-06 (🧭): default state of the switch (proposed ON for entitled users).
- SGS-18 (🧭): increment range 0.25 to 25 kg.
- SGS-21, SGS-24 (🧭): default increment tracks the unit until the user picks one; explicit value is stored in kg.
- SGS-30 (🧭): free users see a locked row that opens the paywall.
- SGS-36 (🧭): behaviour when entitlement lapses mid-session.
- SGS-39 (🧭): store toggle and increment in the synced `users/{uid}.settings` map (rules already allow it).
- SGS-42 (🧭): add the feature to the Supernova paywall copy.
- SGS-E02, SGS-E03, SGS-E04, SGS-E05, SGS-E06 (🧭): offline cold start, two-device settings, mid-session settings changes, new-device restore, wipe on account switch.
- SGT-06 (🧭): where the user edits R (card menu and exercise detail).
- SGT-09 (🧭): range 1 to 50 reps.
- SGT-12, SGT-E01 (🧭): default when R is missing (template target reps, else none with a hint).
- SGT-18 (🧭): cloud path `users/{uid}/progression/{exerciseId}`; rules, mapper and applier needed.
- SGT-27, SGT-30, SGT-33, SGT-36, SGT-E02, SGT-E04, SGT-E07 (🧭): lifecycle details (deleted exercise, template independence, account deletion coverage, import, hidden row for free users).
- Housekeeping: delete the dead `smartWeightSuggestion` function (SGB-12) and the unused `smartSuggestion` parameter (SGB-15) when the feature lands.
## 05 History, workout detail, exercise detail, PR rules, weekly recap, profile stats

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
## 06 Body tab

- BDY-33 (🧭): VS PACE shows -100% on Monday morning. Proposed: pro-rate by time of day or hide until the first workout.
- BDY-66: front and back are side by side, while `CLAUDE.md` says swipeable pages; decide which is intended and update the doc or the UI.
- BDY-54: legend says "100% OF TARGET" in day view where it means "busiest group".
- BDY-57 / BDY-60 / BDY-63: LAST 48H uses an assumed 21:00 reference and drops later workouts; proposed: use the real time for the current week.
- BDY-39: "VS WK 0" in week 1. BDC-12: next-month arrow blocked near month starts.
- BDY-E07: same-day second workout is invisible in label, VS LAST and calendar.
- BDY-93: cold spots use a different window and secondary credit than the rest of the tab.
- BDY-102: unbuilt spec items (sub-region zones, nudge badges, push/pull balance, sparkline, customisation, Simple Body Map, colour presets).
- BMS-12: Supernova gate excludes the free trial here but not elsewhere. BMS-15: sheet has no trend graphs. BMS-18: generic-group mismatch.
- BDY-E01: no empty state for new users.
- BDY-E02: week-number label differs by locale (also see file 02 HOM-39).
## 07 Programs, templates and template sharing

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
## 08 Exercise library

- LIB-54 / LIB-57: custom exercise creation and library browse/filter are not reachable. Decide: wire `ExerciseLibraryView` into More or the picker (add "Create exercise" in the picker empty state), or delete the dead code. Spec requires custom exercises (Phase 3).
- LIB-60: PROPOSED duplicate-name block for custom exercises.
- LIB-E02: PROPOSED single search rule across picker and global search.
- Community submissions (LIB-57): no backend; decide whether to keep the "Submit to community library" toggle.
- CLAUDE.md says 84 seeded exercises; actual ~240. Update docs.
- `ExerciseSubstitutionView` is dead; Supernova smart substitutions are not built (see GAT).
## 09a Social: feed, posts, comments, likes, friends, profiles, privacy, report/block

- PRV-E01 / PRV-48: per-post audience override is not built. Proposed default: a composer chip that can only narrow the global setting.
- PRV-E07: should tightening privacy apply to past posts? Proposed default: no (current), maybe add an explicit "Apply to past posts" action.
- PRV-36: tell the user when "Workout posts = Only me" means nothing was posted. Proposed default: a short toast "Kept private".
- PRV-E06 (bug): hiding from Global leaderboards does not take effect on existing entries until the next score write. Needs a function trigger on profile change (or hide client-side).
- FED-E09: a failed publish is lost on app kill. Proposed default: persist the payload and offer re-post.
- FED-E03 (bug): graph failure caches an own-posts-only feed for 5 minutes. Proposed default: do not set the TTL when the graph failed, and show the error.
- FED-78: Save workout has no "saved" list. Either build the list or remove the menu item.
- POS-15: PR flag in post detail is derived from improvement order; store a per-exercise PR flag in the post if exactness matters.
- POS-33: gold PR colour vs the "PR is a treatment, not a color" design rule.
- CMT-E06: filter comments from users I blocked. Proposed default: yes.
- CMT-E01 / PRF-E01 (bug): load failures render as "empty" or "Private profile". Proposed default: show an error with RETRY and never cache the placeholder on network errors.
- FRD-E10: ignored requests are per device. Proposed default: keep local.
- FRD-E14: no way to remove a fan without blocking. Proposed default: leave as is.
- FRD-69 / FRD-72: contacts matching and shareable invite links are not built; spec line 247 still lists them. Decide whether to update the spec or build them.
- FRD-E06: lists load only 80 profiles at a time. Proposed default: page the profile fetch.
- RPT-03 / RPT-E08: report reasons are fixed strings, no confirmation for post reports. Proposed default: reason sheet.
- RPT-33: no moderation tooling or SLA (App Store UGC requirement). Needs an owner process.
- RPT-E01: block should confirm the follow was removed (or delete both directions server side).
## 09b Social: challenges, scoring, leaderboards, Supernova gating, Activity and counters

- CHC-66 (bug/decision): copy says late joiners are scored from the day they join; the backend scores from challenge start. Design README lists this as an open question. Proposed default: keep scoring from start (simplest, honest total) and change the copy to "ALL WORKOUTS SINCE THE START COUNT".
- CHP-03 / CHP-06 / CHP-09: Supernova gating of challenge creation is in the spec but not built. Proposed default: gate creation only, joining stays free.
- CHS-27: Custom metric has no way to enter scores and is hidden from creation. Proposed default: remove Custom from the product, or add a callable function to submit a score.
- CHS-30: win conditions "lowest" and "First to Reach Goal" have no UI (first has no goal field). Proposed default: drop them from the enum or build a goal field.
- CHS-21: Longest hold shows seconds as a plain number. Proposed default: format as m:ss.
- CHL-78: creators cannot delete or end a challenge, or leave it. Proposed default: add "End challenge" (creator) and keep "Leave" for members.
- CHL-E01 / CHG-E01 (bug): a failed board load leaves skeleton rows forever. Proposed default: show an error with RETRY.
- CHL-36: ended rows show a place only if the board was opened earlier. Proposed default: load boards for the first few ended challenges too.
- CHL-21: only one global challenge card is shown. Proposed default: keep (monthly challenge assumed).
- CHL-E09: ties for first on the ended screen show a single winner. Proposed default: show "TIED" with both names.
- CHC-E04: orphan challenge when the creator join fails. Proposed default: retry the join automatically or delete the orphan.
- CHC-E16: visibility "friends" / "public" are unused. Proposed default: keep invite-only for now.
- CHG-E05: no in-app or documented operator process to create the monthly global challenge. Proposed default: a documented script using the Admin SDK.
- PRV-E06 (see 09a): hiding from global boards does not update existing entries until the next score write.
- ACT-30 / ACT-33: no activity history and no social push notifications (spec wants configurable ones). Decide scope; see 14 NTF.
- ACT-36: bell dot may miss invites until the Challenges tab or Activity loads. Proposed default: load invites together with the graph at Social tab open.
- CTR-E02: server friend/fan counters ignore blocks. Proposed default: accept the difference.
## 10 More hub, Settings, units, equipment, import/export, Supernova screen, tutorial

- MOR-18: during the trial the hub says "FREE" and shows the upgrade banner. Decide whether to show "TRIAL · n DAYS".
- SCF-24: MET calorie formula keeps working after Plus lapses (bug) — enforce the gate in the estimator or drop the gate.
- SCF-33, SCF-45, SCF-51: three "COMING SOON" rows (Smart Weight Suggestions, Simple Body Map, Social Activity, Challenge Updates). Keep, hide or build.
- SCF-69: missing settings (week start, default rest times, reminder times, summary fields, change email/password). `PostWorkoutCustomizationView` is dead.
- NTS-03: permission prompt fires at launch, not when the user enables a reminder. NTS-15: denied permission leaves the toggle on. NTS-21 (PROPOSED): reminder time picker.
- EQP-15 / EQP-18 / EQP-21: equipment profiles cannot be edited or deleted, "Add Equipment" is a no-op, and no feature consumes the data (plate calc, substitutions). Decide scope.
- IMP-27: import errors are titled "Export Error". IMP-E08 (PROPOSED): confirm imported history should count toward streak/PR.
- PLS-33: annual selection can buy monthly if the annual product is missing. PLS-36: Restore has no feedback. PLS-E03 (PROPOSED): Plus tied to Apple ID only.
- PLG-06 / PLG-09: legal links and "Download My Data" are empty actions (App Store review risk).
- TOL-03 / TOL-06: standalone Plate Calculator and Warm-up generator are unreachable.
- TUT-15: tutorial steps 4-10 are placeholders and block the interaction they describe; no week-start setting exists.
## 11 Widgets and Live Activity

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
## 12 Cloud sync and data ownership

- SYN-E02 (PROPOSED): confirm offline behaviour with airplane mode; proposed default is a 30 s cycle timeout mapped to the Offline status.
- SYN-E06 (PROPOSED): clamp workout exercise list to 100 and skip empty-named custom exercises in the mapper so rules never permanently reject.
- SYN-E05 / SYN-E07 / SYN-E11: permanent-error loops retry forever at 300 s with no way to find the offending item; no local caps for 1000 kg bodyweight or 1 MiB workouts. Decide whether to surface a per-item error list.
- SYN-E09: LWW uses the device clock (by design); decide whether any skew protection is wanted.
- SYC-E04 / SYC-E01: whole-document winner, equal-ms tie keeps each device's copy; confirm acceptable.
- SYC-33: tombstones are never purged; decide on a retention/compaction policy.
- SYA-E01 (bug): sign-out wipes data even when the final push failed (offline); decide between warn-and-confirm, block, or accept.
- SYA-E02 (bug): sign-out during an in-flight cycle can drop the final push.
- SYA-E04 / SYA-09: RESTORING screen has no progress, no timeout and no sign-out escape while waiting.
- SYA-E05 (PROPOSED): accounts whose cloud profile lacks `unit` land on "Couldn't restore your data"; proposed fallback is onboarding prefilled from the cloud profile.
- SYA-E09 (PROPOSED): device settings in UserDefaults (theme, rest timer, reminders, calorie formula, summary toggles, `autoShareToFeed`) neither sync nor clear on account switch; docs/sync-architecture.md says preferences and privacy sync, code does not. Decide: sync them, clear them, or document as per-device.
- SYS-30: no sync on/off, Wi-Fi-only or pending-item list (architecture says sync is always on); confirm no controls are wanted.
- SYX-E02 / SYX-E03 (PROPOSED): import dedupe is local-only; app JSON export is not a restore path.
- Doc/code disagreement: `docs/sync-architecture.md` still says "implementation in progress" and lists `users/{uid}.settings{}` and `privacy{}` in the sync model; the engine writes neither.
## 13 Supernova gating (free vs Plus), trial, restore

- Cloud sync is ungated while the paywall and spec say Plus (GAT-48). Decide: gate (and define free behaviour: local-only, no backup) or remove it from the paywall copy. Strong product implication: free users currently get account restore on a new device.
- Challenges are ungated (GAT-27); decide who may create vs join.
- Paywall copy overstates: Smart Predictions, Weekly Recaps and Import / Export are free in code (GAT-51, table rows 13-16). Either gate them or reword the six modules.
- Trial semantics: GAT-18 (sub-regions exclude trial users), GAT-09/TRL-21 (hub says FREE during trial), GAT-E01 predicate inconsistency. PROPOSED: one helper `hasPlus = isSubscribed || isInFreeTrial` used everywhere.
- TRL-24 (PROPOSED): move to a StoreKit introductory offer; add a "trial ended" notice; define whether the trial is 14 or 15 days (TRL-06).
- GAT-24: MET calories continue after Plus lapses; decide whether the estimator should enforce the gate.
- RPU-09: start the `Transaction.updates` listener at app launch.
- RPU-03 (PROPOSED): show a result toast for Restore ("Supernova restored" / "No purchases found").
- Not built features promised in the spec: smart weight suggestions, smart substitutions, balance / imbalance analytics, advanced analytics and tips, advanced body customization, neglected-muscle badge, upsell blur banners (GAT-54, GAT-21, GAT-60). Decide the V1 Plus line.
- Multi-app pricing tiers (GAT-E07) are not implemented.
- Dead gate scaffolding: `SupernovaFeature`, `hasAccess(to:)`, `SupernovaUpsellBanner`, `SupernovaBlurOverlay`.
## 14 Notifications and reminders

- NTF-42 (🧭): skip a reminder when a workout is already logged that day; proposed to leave for later.
- NTF-E05 (🧭): move the permission prompt from launch to the moment the user first enables a reminder.
- NTF-E21 (🧭): ship remote push (likes/comments/follows/challenges, FCM) in v1 or remove the APNs entitlement and `remote-notification` background mode.
- NTF-E25 (🧭): configurable reminder time (currently 08:00 workout, 10:00 rest day).
- NTF-E02 (bug): denied permission leaves the switches ON with no feedback.
- NTF-E12 (bug): sign-out does not cancel pending reminders or clear the switches (also 01 SOUT-E03).
- NTF-E16: add the time-sensitive notifications entitlement or drop the `.timeSensitive` level.
- NTF-E19: clarify Timer Alert semantics for the background notification (sound follows "not Silent" only).
- NTF-75, NTF-78, NTF-81: social push, weekly recap notification, neglected-muscle nudge are specified in `docs/pulse-pump-spec.md` but not built.
- NTF-E10: reschedule reminders whenever the split changes from any source (Programs, sync).
