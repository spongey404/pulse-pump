# Pump — full codebase logic audit (2026-10-08)

Nine parallel read-only audits covered every Swift file (~33k lines: models, services, view models, every view, PumpShared, widget extension, tests). Each finding below was verified by reading the code or running a standalone script; the detailed per-area reports (file:line, failing scenario, evidence, suggested fix, and a "Verified OK" list of what was actually traced and confirmed) sit next to this file.

| Area | CRIT | HIGH | MED | LOW | Report |
|---|---|---|---|---|---|
| Models, seed/import/export, App, RootView, StreakCalculator | 2 | 3 | 7 | 4 | models-data.md |
| Core services (widget data, rest timer, live activity, notifications, StoreKit, calories) | 1 | 6 | 15 | 7 | services-core.md |
| WorkoutViewModel, onboarding VM | 2 | 7 | 11 | 3 | viewmodels-workout.md |
| Social, Firestore, challenges, privacy | 1 | 14 | 16 | 7 | social-firestore.md |
| Workout screens, plate calc, warm-ups | 2 | 9 | 8 | 9 | views-workout.md |
| Body map, Home, ContentView | 1 | 7 | 17 | 9 | views-body-home.md |
| More, Settings, Onboarding, widget builder | 3 | 8 | 16 | 7 | views-more-settings-onboarding.md |
| Exercise library, programs, shared, tutorial | 2 | 10 | 12 | 6 | views-library-programs.md |
| PumpShared widgets, extension, tests | 2 | 8 | 13 | – | widgets-tests.md |

(Totals count repeats: the same root cause is reported by several agents. Unique CRITICAL issues: 6.)

## The 6 unique CRITICAL issues

1. **Test data is injected into every real workout.** `WorkoutViewModel.swift:81` — `startWorkout` always ends with `injectTestData`: it replaces the template's exercises with 10 fake pre-completed exercises, backdates the timer ~78 min and inserts fake history. Not behind `#if DEBUG`; in HEAD since 2026-05-16. It is why Home's RECENT shows "n/10" improved and 0%/20% volume, and it pollutes PRs, exercise charts, widgets and the feed.
2. **Demo user + ~5 weeks of fake workouts are seeded into production and skip onboarding.** `RootView.swift:22-24` → `WorkoutDemoDataService.seedIfNeeded` (no `#if DEBUG`): a fresh install gets user "Jordan" so `users.isEmpty` is false; existing users get fake workouts injected into their history.
3. **Workout drafts / crash recovery are not implemented.** `WorkoutViewModel.swift:508-513, 147-179` — sets are written only at completion; "Save as draft", a crash or relaunch loses every logged set (Continue card always shows 0 sets).
4. **Preset/seeded templates use random exercise IDs.** `TemplateSeedService.swift:25-100` — a workout started from any preset is saved with no exercise attached, so history, PRs, body map and widgets lose it (all 21 preset names do exist in the library; look-up by name fixes it).
5. **Challenge scoring does not exist.** `FirestoreService.swift:208` / `SocialViewModel.swift:414-484` — `updateLeaderboardEntry` has no callers; every challenge shows score 0 / rank 0; no UI path to join; accepted invites never join.
6. **Weight units are double-converted.** `OnboardingViewModel.swift:113,141` + `ProfileView.swift:246` — lb input stored as kg, converted again in Profile (180 lb shows 396). Settings only flips the label; no screen converts logged weights (`views-workout.md`: lbs ignored in all workout screens, widgets hard-code "KG").

## Charts, graphs and stats — is the logic really there?

| Component | Verdict |
|---|---|
| Home STREAK / IMPROVED / PRS / SETS tiles, RECENT table (SETS · IMPR · VOL▲) | Formulas exist but were fed fake data (#1). "This week" uses the locale week start while the bars/Body tab assume Monday → wrong buckets for non-Monday locales. |
| Home predicted workout + HIGH CONF dots | Prediction logic correct (PPL, U/L, bro, full-body verified by script) but the dots are **hard-coded**, and a predicted name matching no template silently starts a blank workout. |
| Friend activity banner | **Demo friends** shown to real/signed-out users; banner button is an empty closure. |
| Body tab (v3): VS PACE / VS WK, TOP/GAPS, cold spots, heat levels, calendar grid | Maths verified (176-set target, pace table, Monday offsets, ÷0 guards). Defects: generic `.shoulders`/`.back` fold into side-delts/upper-back → double counting; calendar "VIEW ›" lands on the wrong week for workouts older than 3 weeks. |
| `AnalyticsView`, `MuscleBalanceView`, `BodyModelView`, 3D scene, `QuickAnalyticsView` | **Dead code** — compiled but unreachable. |
| Exercise detail charts (e1RM/volume PR, trend) | Epley/volume maths correct and real-data driven, but the whole Exercise Library + custom-exercise creation is **unreachable** from the UI. |
| Weekly Recap, History list + calendar | Verified correct (ISO weeks, half-open ranges, warm-ups excluded). |
| Social: lift history chart | Baseline logic correct, but when real data is missing it shows **fabricated history as the friend's**. Activity notifications are hard-coded. |
| Social: leaderboards / challenges | Rendering correct; **scores never computed** (#5); ended challenges stay "Active"; every user sees every non-global challenge. |
| Plate calculator (inline in the logger) | Maths correct (100/102.5/62.5 kg, bars 15/20/25, off-by-0.5 reported). Standalone `PlateCalculatorView` / `WarmupGeneratorView` are unreachable; equipment profiles are display-only (the logger's calculator ignores them). |
| Calories | Basic formula correct; **MET can never run** (no caller passes the subscription flag; its unit test fails). |
| Widgets (fixed set) | Weekly buckets, same-weekday comparison, balances, deload, recap, bodyweight, friends verified correct. **PR watch compares an estimated 1RM to the heaviest *weight* PR** (a test locks this in); with no workouts widgets show design **sample data with Plus unlocked**; Quick Start tiles start a blank workout; custom "Line chart"/"Program weeks" use sample data. |
| Rest timer | Tick-counted: freezes in background, no end-of-rest notification; ignores isolation/template/superset rest settings. |
| Notifications | `Split.days` is never populated → workout reminders never schedule, rest-day alerts fire daily. |

## Other cross-cutting HIGH themes
- **Workouts are posted to the feed twice, before the user can caption or decline** (`WorkoutViewModel.swift:468` + `WorkoutCompletionView.swift:561`); the attached photo is never uploaded.
- **Warm-up sets count everywhere** (completion stats, body heat, volume) despite being "excluded" in copy; ghost values are shown but not saved when the user taps ✓; comma-decimal input becomes 0.
- **Settings stored but never consumed** (nine): all privacy levels, Smart Weight Suggestions, template rest, set-type chips, superset behaviour, etc. (`views-more-settings-onboarding.md` has the full setting → stored → consumed table). Sign Out does not sign the user out; returning-user sign-in creates a blank local User and can clobber the Firestore profile.
- **Import**: Strong/Hevy CSV importer duplicates on re-import, ignores units/warm-ups, mostly fails to link exercises, turns unparseable dates into "now".
- **Share-via-link** import is never handled (`.importTemplate` has no listener); template sharing payload is lossy.
- **Live Activity**: updated every second (dedupe defeated), not restarted on draft resume, lingering end state.
- **Pulse+ gating** is inconsistent (challenges ungated per the known gap; others gated only in UI).
- **Tests**: PulsePumpUITests is entirely stale; no tests for streak, prediction, PR detection, calories (one failing), plate/warm-up maths, import/export, snapshot builder (the new `WidgetFixedDataTests` cover widget maths but encode the PR-watch bug).

## Suggested fix order
1. Gate/delete `injectTestData` and `WorkoutDemoDataService` (`#if DEBUG` or remove) — one change removes the biggest source of wrong numbers; then re-verify Home/Body/widgets on a clean store.
2. Persist in-progress sets (write draft SetLogs as they are logged) and fix the double feed post.
3. Link preset/imported exercises by name; fix unit handling (store kg, convert at the edges) in onboarding/profile/logger/widgets.
4. Decide on challenges: implement scoring + join, or hide the tab behind a flag until built; remove demo social data from production paths.
5. Populate `Split.days` (or derive schedule from history) so reminders, goals and programs work; make the rest timer end-date based with a local notification.
6. Fix the PR-watch definition (best e1RM vs best e1RM) and sample-data-with-Plus-unlocked fallback; wire MET calories and the unreachable screens or delete them.
