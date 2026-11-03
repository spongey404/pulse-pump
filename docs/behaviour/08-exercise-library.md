# 08 Exercise library

Scope: how a user finds, picks, inspects and creates exercises. Source: `Ore/Features/Workout/Views/ExercisePickerView.swift` (the live picker), `Ore/Features/Home/GlobalSearchView.swift` (the only route to exercise detail), `Ore/Features/Exercises/{ExerciseLibraryView,ExerciseFilterSheet,CreateExerciseView,ExerciseDetailView}.swift`, `Ore/Core/Persistence/ExerciseSeedService.swift`, `Ore/Core/Models/Exercise.swift`, `Ore/Core/Utilities/String+Search.swift`.

IMPORTANT reachability summary (verified by grepping call sites, 2026-10):

| Screen | Reachable in the app? | How |
|---|---|---|
| `ExercisePickerView` (search + movement pills + variant groups) | Yes | Active workout "add" and "replace" (ActiveWorkoutView.swift:203,228), template create/edit (CreateTemplateView.swift:40, TemplateDetailView.swift:102), challenge create step 1 (CreateChallengeStep1View.swift:103) |
| `ExerciseDetailView` (info, PRs, chart, recent sessions, templates, notes) | Yes, one route only | Home search icon › GLOBAL SEARCH › tap an exercise result |
| `ExerciseLibraryView` (browse list, filter button, "+" create, pending submissions) | NO | No call site anywhere |
| `ExerciseFilterSheet` (muscle / equipment / movement filters) | NO | Only presented by `ExerciseLibraryView` |
| `CreateExerciseView` (5-step custom exercise creator) | NO | Only presented by `ExerciseLibraryView` |
| `ExerciseSubstitutionView` ("Replace Exercise" with search) | Not used | `ActiveWorkoutView` uses `ExercisePickerView(title: "REPLACE EXERCISE")` instead |
| Standalone plate calculator and warm-up generator | NO | See 10-more-settings.md (TOL flow) |

Consequence: a user cannot create a custom exercise from the UI. Custom exercises only come from Strong/Hevy CSV import and from importing a shared template whose exercise names are unknown. CLAUDE.md says "84 seeded exercises"; the seed file defines roughly 240 `Exercise(name:)` entries (grep count 242 in ExerciseSeedService.swift).

## LIB  Find, pick, inspect, create

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| LIB-03 | System: app first launches the main shell → App seeds the built-in catalogue once per seed version (`exerciseSeedVersion` in UserDefaults, current 2) by inserting exercises whose name is not already present (non-custom only). | ✅ ExerciseSeedService.swift:6-21, ContentView.swift:107 | [ ] | — |
| LIB-06 | User taps "Add Exercise" in an active workout → App opens `ExercisePickerView` as a full-screen cover with title "ADD EXERCISE", a back chevron, search field "Search exercises…", a pill row (ALL + one pill per movement pattern: push, pull, hinge, squat, carry, rotation, isolation) and the list. | ✅ ExercisePickerView.swift:132-243 | [ ] | — |
| LIB-09 | System: picker list → App shows only exercises that are `isApproved` or `isCustom` and not already in the workout (`excludedIds`). Soft-deleted exercises are hidden. | ✅ ExercisePickerView.swift:87-89 | [ ] | — |
| LIB-12 | System: picker grouping → App collapses known families into one row (for example "Bench Press" with 4 variants, "Squat", "Lat Pulldown", 41 groups defined by exact name lists). A group row shows "N VARIANTS" and a chevron; a single-exercise row shows the muscle line and an accent "ADD" button. Exercises outside the lists (all customs, many seeded) appear as single rows after the groups. | ✅ ExercisePickerView.swift:6-48,102-130 | [ ] | — |
| LIB-15 | User taps a group row → App pushes "{GROUP} / N VARIANTS" with one row per variant (equipment shown uppercased, for example "BARBELL") each with an "ADD" button. | ✅ ExercisePickerView.swift:259-351 | [ ] | — |
| LIB-18 | User taps "ADD" on a single row or a variant → App calls the screen's add callback with that one exercise and dismisses the picker. Picker is single-select per tap: it adds one exercise (or group row's single) and closes, so adding several requires reopening it. | ✅ ExercisePickerView.swift:228-231 | [ ] | — |
| LIB-21 | User types in the picker search → App filters by case-insensitive SUBSTRING of the name (so "press" matches "Barbell Bench Press") live, combined with the movement pill. The clear "x" resets the text. | ✅ ExercisePickerView.swift:96-98 | [ ] | — |
| LIB-24 | User taps a movement pill → App filters to that pattern; tapping it again, or "ALL", clears the filter. Only one pill active at a time. | ✅ ExercisePickerView.swift:203-216 | [ ] | — |
| LIB-27 | System: nothing matches → App shows "No exercises found" and "TRY A DIFFERENT SEARCH". There is no "Create custom exercise" action here. | ✅ ExercisePickerView.swift:245-256; ❌ no create from the empty state | [ ] | — |
| LIB-30 | User taps the back chevron → App dismisses the picker without adding. | ✅ ExercisePickerView.swift:158 | [ ] | — |
| LIB-33 | User opens Home › search icon → App opens "GLOBAL SEARCH" with category chips ALL / EXERCISES / WORKOUTS / FRIENDS and the prompt state. Typing shows up to 8 exercises whose name has a word starting with the typed text (word-prefix match: "sh" matches "Dumbbell Shoulder Press", "ell" does not). | ✅ GlobalSearchView.swift:33-40, String+Search.swift | [ ] | — |
| LIB-36 | User taps an exercise result → App pushes `ExerciseDetailView` titled with the exercise name. | ✅ GlobalSearchView.swift:117,78-80 | [ ] | — |
| LIB-39 | System: detail screen → App shows sections Info (Equipment, Movement, Type, "Unilateral: Yes" only when true), Primary Muscles, Secondary Muscles (only when any), Progress, Recent Sessions (up to 5, only with history), In Templates, Notes (only with history). | ✅ ExerciseDetailView.swift:9-67 | [ ] | — |
| LIB-42 | System: exercise has no finished history → App shows an empty state "No History Yet" / "Complete a workout with this exercise to see your progress." | ✅ ExerciseDetailView.swift:35-41 | [ ] | — |
| LIB-45 | System: exercise has history → App shows stat cards "Weight PR (kg)" / "(lb)", "Rep PR", "Est. 1RM (kg or lb)" (Epley: weight x (1 + reps/30), reps of 1 = weight), and "Volume PR" (best single-session sum of weight x reps, working sets only), plus a "Weight Over Time" line chart when at least 2 sessions have a top weight above 0. Values convert from stored kg to the user's display unit. | ✅ ExerciseDetailView.swift:72-167 | [ ] | — |
| LIB-48 | System: Recent Sessions → App lists the 5 latest sessions with date and every set as "weight×reps" (all sets, including warm-ups). Notes section lists the 10 latest non-empty exercise notes. | 🟡 includes non-working sets; stats use working sets only (ExerciseDetailView.swift:213) | [ ] | — |
| LIB-51 | System: In Templates → App lists templates (active only) that contain this exercise by `exerciseId`, or "Not used in any templates". Matching is by id only, so a template whose exercise ids dangle will not be listed. | 🟡 ExerciseDetailView.swift:231-235 | [ ] | — |
| LIB-54 | User looks for a browse-all list, a filter by muscle/equipment, or a "+" to add a custom exercise → App has no route to any of them. `ExerciseLibraryView` (list, filter sheet, create, "Pending" section for unapproved customs) is compiled but never presented. | ❌ not reachable (no call site for ExerciseLibraryView) | [ ] | — |
| LIB-57 | (Unreachable) User would tap "+" › 5-step creator → Steps: name ("What's the exercise called?", placeholder "e.g. Barbell Bench Press"), primary muscles (required, at least one), secondary muscles (optional, primaries excluded), details (equipment, movement pattern, tracking type Weighted / Bodyweight / Time Based / Distance Based, unilateral toggle), review with "Submit to community library" toggle. "Save Exercise" inserts a custom exercise; `isApproved = !submitToCommunity`. | ❌ unreachable; also community submission only sets a local flag (no backend queue) | [ ] | — |
| LIB-60 | (Unreachable) User sets a name that already exists (built-in or custom) in the creator → App would allow it; there is no duplicate-name check. | 🧭 PROPOSED: block exact normalized-name duplicates when the creator is wired | [ ] | — |
| LIB-63 | System: custom exercises appear in picker and search → Row shows name; custom ones are flagged "CUSTOM" only in `ExerciseRowView` (the unreachable library). In the picker there is no badge. | 🟡 ExerciseLibraryView.swift:159 vs ExercisePickerView | [ ] | — |
| LIB-66 | System: exercises created by CSV import / shared-template import → App creates `isCustom = true`, `isApproved = false`, no muscles, equipment guessed from words in the name (dumbbell, barbell, cable, machine, kettlebell, band, smith, bodyweight, else other), movement pattern isolation. They appear in the picker and Global Search (because `isCustom`), but contribute nothing to the body map. | ✅ DataImportService.swift:289-303, 319-330 | [ ] | — |
| LIB-69 | User replaces an exercise during a workout → App opens `ExercisePickerView(title: "REPLACE EXERCISE", excludedIds: other exercises in the session)`. Smart suggestions for Supernova users (spec) do not exist; the old `ExerciseSubstitutionView` is unused. | 🟡 manual replacement only; smart alternatives not built | [ ] | — |

### LIB edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| LIB-E01 | Search with leading/trailing spaces | Picker uses `localizedCaseInsensitiveContains` with the raw text, so "bench " (trailing space) matches only names containing "bench ". Global Search is word-prefix and does not trim either. | | 🟡 no trimming in either search | [ ] | — |
| LIB-E02 | Search consistency | Picker = substring; Global Search = word-prefix. The same query can return different sets. | | 🧭 PROPOSED: pick one rule (word-prefix) for both | [ ] | — |
| LIB-E03 | Empty catalogue (seed has not run) | Picker shows "No exercises found". Seeding runs on main-shell appear, so this is transient. | | ✅ | [ ] | — |
| LIB-E04 | Same exercise already in the workout | Hidden from the picker (`excludedIds`). Template pickers pass no exclusions, so duplicates can be added to templates. | | ✅ | [ ] | — |
| LIB-E05 | Exercise soft-deleted on another device | Hidden from picker and search; old logs keep their link. | `deletedAt == nil` predicates. | ✅ | [ ] | — |
| LIB-E06 | Offline | All of this is local. | | ✅ | [ ] | — |
| LIB-E07 | lbs user | Detail PRs, 1RM, volume and chart convert from kg to lb and label "lb". | | ✅ ExerciseDetailView.swift:109-115,152 | [ ] | — |
| LIB-E08 | Seed version bump | Only names that do not exist yet are added; edits to existing seeded exercises are not re-applied. | | ✅ | [ ] | — |
| LIB-E09 | Exercise with one session | No chart (needs 2 points); stat cards still show. | | ✅ | [ ] | — |
| LIB-E10 | Supernova vs free | The library, search and detail are ungated. Sub-region muscle detail for Supernova lives on the body tab (see 13-supernova-gating.md). | | ✅ | [ ] | — |
| LIB-E11 | Time-based / distance-based exercise PRs | Detail screen shows weight and rep PRs only; no time or distance PR. | | 🟡 | [ ] | — |

## Open decisions for the owner (08)

- LIB-54 / LIB-57: custom exercise creation and library browse/filter are not reachable. Decide: wire `ExerciseLibraryView` into More or the picker (add "Create exercise" in the picker empty state), or delete the dead code. Spec requires custom exercises (Phase 3).
- LIB-60: PROPOSED duplicate-name block for custom exercises.
- LIB-E02: PROPOSED single search rule across picker and global search.
- Community submissions (LIB-57): no backend; decide whether to keep the "Submit to community library" toggle.
- CLAUDE.md says 84 seeded exercises; actual ~240. Update docs.
- `ExerciseSubstitutionView` is dead; Supernova smart substitutions are not built (see GAT).
