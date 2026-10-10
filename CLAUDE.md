# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Pulse Pump

iOS workout logging app. Part of the Pulse ecosystem.

## Build Commands

```bash
bin/test.sh               # unit tests exactly as CI runs them (first available iPhone simulator)
bin/test.sh --release     # + Release build, and fails if DEBUG-only DevData code ships
bin/test-integration.sh   # iOS integration tests vs the local Firebase emulators (needs firebase-tools, Java 21, Node 24)
bin/test-integration.sh --only SyncRoundTripEmulatorTests   # a single integration suite
(cd firebase/functions && npm test)     # functions unit tests (npm run test:integration for trigger tests)
(cd firebase/rules-tests && npm test)   # Firestore security rules tests
bin/createdevdata.sh      # build, clean-install and seed fake data (see "Dev data")

# Raw xcodebuild (pick any installed simulator, e.g. iPhone 17 Pro)
xcodebuild -scheme PulsePump -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme PulsePump -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PulsePumpTests/StreakCalculatorTests test
xcodebuild -scheme PulsePumpWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Xcode version: 26.4. Target: iOS 17+. CI: `.github/workflows/ci.yml` runs `bin/test.sh --release` on every PR and on pushes to `main`/`develop`. UI tests (`PulsePumpUITests`) are stale and not run in CI until rewritten.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Local data:** SwiftData (local-first)
- **Remote data:** Firestore (social features only — feed posts, friendships, challenges)
- **Auth:** Firebase Auth (Apple, Google, Email) via `FirebaseAuthService`
- **Subscriptions:** StoreKit 2 via `PulsePlusService`
- **Live Activity / Dynamic Island:** `PulsePumpWidget` extension + `LiveActivityService`

## Project Structure

Feature-first inside the app target; shared code in `Core/`. Targets use Xcode synchronized folders, so adding/moving a file needs no project edit.

```
PulsePump/                      app target
├── App/                        entry point (PulsePumpApp), RootView (onboarding vs app), ContentView (tab shell), deep links
├── Core/
│   ├── DesignSystem/           Color+Theme, Font+Design, Components/ (Avatar, buttons, ticker, tab bar, modals, ledger rows, KPIBlock, FilterChip…)
│   ├── Models/                 SwiftData models, Enums/, Firestore/ (Codable structs mirroring Firestore)
│   ├── Persistence/            exercise/template seeding, Strong/Hevy import, JSON/CSV export
│   ├── Services/               Auth/, Firestore/ (FirestoreService), Notifications/
│   └── Utilities/              StreakCalculator, String+Search
├── Features/                   one folder per feature: its Views + ViewModel + Services together
│   ├── Home/  Workout/ (Views/, Views/Logger/, Tools/, WorkoutViewModel, Services/: rest timer, live activity, calories)
│   ├── Programs/  BodyMap/  Exercises/  Equipment/  Social/ (Feed/, Friends/, Challenges/, SocialViewModel)
│   ├── More/  Settings/  PulsePlus/ (paywall, StoreKit service, upsell banner)  Onboarding/  Tutorial/
│   └── Widgets/                widget builder UI, gallery, WidgetDataService (snapshot for the extension), BodyweightLog
├── DevData/                    DEBUG-only fake-data seeder (see "Dev data")
├── Resources/Fonts/            Archivo + Space Mono
└── Assets.xcassets, Info.plist, entitlements, GoogleService-Info.plist
PumpShared/                     compiled into BOTH app and widget extension (widget layouts, catalog, snapshot, BodyHeat, Live Activity attributes/intents)
PulsePumpWidget/                WidgetKit extension: providers, intents, bundle, Live Activity
PulsePumpTests/                 mirrors the app: Core/, Features/…, DevData/
PulsePumpUITests/               (stale)
bin/                            test.sh, createdevdata.sh
docs/                           spec, design reference, audit/
design/                         Claude Design handoffs, HTML prototypes, font sources
PumpApp/                        old Expo scaffold (unused)
```

Where things go: a screen and everything only it uses → its `Features/<Name>/`; a view/modifier two or more features use → `Core/DesignSystem/Components/`; a model/enum → `Core/Models/`; cross-feature infrastructure → `Core/Services/`; anything the widget extension also needs → `PumpShared/` (must not import app-only code). One primary type per file; name the file after it.

## Naming

- **Xcode project:** PulsePump
- **Display name (on device):** Pump
- **Bundle ID:** com.pulse.PulsePump

## Branch Strategy

- `main` — stable, release-ready
- `develop` — integration branch
- `feature/*` — feature branches
- `fix/*` — bug fix branches

## Commit Convention

Lowercase prefixes, present tense:
- `feature: add ...`
- `sys: ...`
- `test: ...`
- `refactor: ...`
- `fix: ...`

## Architecture: Data Flow

### Two separate data stores

**SwiftData** (local) holds everything the user creates: `User`, `Exercise`, `WorkoutTemplate`, `Workout`, `ExerciseLog`, `SetLog`, `Split`, `EquipmentProfile`, `UserProfile`, `Challenge`. Injected via `.modelContainer` on the root scene and accessed via `@Query` or `@Environment(\.modelContext)`.

**Firestore** (remote) holds only social data: user profiles (`users` collection), friendships (`friendships`), feed posts (`feedPosts`), reactions, comments, challenges. Accessed exclusively via `FirestoreService`. The `FirestoreModels.swift` file defines the Codable structs (`FirestoreUserProfile`, `FeedPost`, `FeedExercise`, `FeedSetLog`, `FriendshipDoc`) that mirror the Firestore schema. These are **separate** from the SwiftData models.

### Auth bridge

`FirebaseAuthService` wraps Firebase Auth. On sign-in it writes/updates a `FirestoreUserProfile`. The `User` SwiftData model stores auth metadata locally. `RootView` decides whether to show onboarding (`users.isEmpty`) or `ContentView`.

### Active workout lifecycle

`WorkoutViewModel` owns the entire active session. It lives in `ContentView` and is passed down to `HomeTabView` and `ActiveWorkoutView`. Key states:
- `isActive = true` → `ActiveWorkoutView` appears as a `fullScreenCover`
- `showCompletionSummary = true` → `WorkoutCompletionView` sheet
- A `Workout` with `isDraft = true` persists through crashes; `StartWorkoutDock` detects it via `@Query(filter: #Predicate<Workout> { $0.isDraft })`

`WorkoutViewModel` also owns `RestTimerService` (injected, not a singleton) and calls into `LiveActivityService` to push Dynamic Island updates.

### Service Layer

| Service | Responsibility |
|---------|---------------|
| `FirebaseAuthService` | Sign-in / sign-out, auth state observation |
| `FirestoreService` | All Firestore reads/writes (profiles, feed, friendships) |
| `RestTimerService` | Rest countdown timer; reads `UserDefaults` for mode/alert settings |
| `LiveActivityService` | Start/update/end workout Live Activity |
| `CalorieEstimationService` | Swappable formula — basic (set-count) or MET-based |
| `PulsePlusService` | StoreKit 2 product fetching, purchase, entitlement check |
| `NotificationService` | Local notification scheduling (workout reminders) |
| `ExerciseSeedService` | Seeds 84 exercises into SwiftData on first launch |
| `TemplateSeedService` | Seeds preset program templates |
| `DataExportService` | Exports workout history as JSON/CSV |
| `DataImportService` | Imports from Strong/Hevy |
| `WidgetDataService` | Writes shared `UserDefaults` (App Group) for widget reads |

## Architecture Decisions

- `@Observable` macro (not `ObservableObject`) throughout — Swift 6 concurrency model
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types implicitly MainActor; no manual `@MainActor` annotations needed on most types
- TemplateExercise, SplitDay, BarConfig, LeaderboardEntry are value-type **structs** stored as JSON in their parent SwiftData models (not separate @Model classes)
- `TemplateExercise.targetReps` is `Int?` — nil means no target; sets are always required
- `WorkoutActivityAttributes` is defined in **both** the main app (`LiveActivityService.swift`) and the widget extension (`WorkoutLiveActivity.swift`) — must be kept in sync manually until a shared framework is added
- Feed caching: `SocialViewModel` stores `lastFeedFetch` timestamp with a 5-min TTL; pull-to-refresh forces a network fetch
- `StreakCalculator` (Core/Utilities/) is the single source of truth for streak logic — gap-based, 3-day expiry window
- `Color.pumpAccent` is the canonical accent token (`Core/DesignSystem/Color+Theme.swift` + xcassets `PumpAccent.colorset`). Set to blue `#1AA7FF` (Pump Design System e68c2807, same light/dark). `Color.accentInk` (xcassets `AccentInk.colorset`) is the same hex today but is the token for text/glyph/border use — use it instead of `pumpAccent` for anything that isn't a filled surface. `Color.pumpPrimary` is a deprecated alias — do not use it. Full rationale in `design_handoff_pulse_color_system/README.md` (Claude Design project "App color system redesign").

## UI Patterns

- Bottom docked bars use `.safeAreaInset(edge: .bottom)` — Start Workout dock and `WorkoutBottomBar`
- Swipe-to-delete uses `.swipeActions(edge: .trailing, allowsFullSwipe: true)` inside `List` only (not `ScrollView`/`LazyVStack`)
- Program cards use `navigationDestination(item: $selectedTemplate)` + `Button` to suppress the `>` chevron
- Body map uses `TabView(.page)` to swipe between front/back views
- `listRowBackground(.clear)` on program card rows removes the gray reveal on swipe-to-delete

## Key Files Post-V1

| File | Purpose |
|------|---------|
| `Core/Utilities/StreakCalculator.swift` | Shared streak logic |
| `Features/Social/Feed/FeedBodyMapView.swift` | Compact front/back silhouette for feed posts |
| `PulsePumpWidget/WorkoutLiveActivity.swift` | Dynamic Island + lock screen Live Activity |
| `Core/Models/Enums/MuscleSubRegion.swift` | 35 anatomical sub-regions |

## Design Refresh (design/pump and fuel design html files/)

The `design/pump and fuel design html files/` directory (renamed from `pump-and-fuel/project/`)
contains HTML prototype files from Claude Design that define the target UI. These are
the reference screens for the ongoing UI/UX update:

| File | Screen |
|------|--------|
| `Pump Home Screen.html` | Home (3 variants: Dense, Calm, Balanced) + draft state |
| `Pump Muscle Map.html` | Body Map tab with thermal heatmap + day scrubber |
| `Pump Workout Logging v2.html` | Active workout card stack + set rows + plate calc |
| `Pump Post-Workout Summary.html` | Completion screen + share card + caption composer |
| `Pump Social Feed.html` | Feed, post detail, friend profile |
| `Pump Programs Exercise Library.html` | Programs list, template detail, exercise picker |

Design system reference: `design/pump and fuel design html files/uploads/pulse-design-system.md`
(multi-app master doc). Pump-only reference with the confirmed token values:
`docs/PULSE_PUMP_DESIGN_REFERENCE.md`. Color token rationale and contrast numbers:
`design_handoff_pulse_color_system/README.md` (Claude Design project "App color system
redesign", also covers `Set Row States.dc.html`, the active-row/completed-row/PR states spec).

Key design tokens implemented in Swift:
- **Accent:** `#1AA7FF` blue, flat in both color schemes (`pumpAccent`, `accentInk`)
- **Canvas bg:** `#F6F7F9` (Cool Paper) light / `#1A1917` dark; elevated `#ECEFF3`/`#252220`, sunken `#E0E5EB`/`#2E2A26`, deep `#D4DAE2`/`#363028`; ink `#151A21`/`#ECE5D6`
- **Ticker bg:** `--ticker-bg` per scheme: `#E0E5EB` light / `#0E0C0A` dark. ▲ `#00AA55` light / `#00E07A` dark; ▼ `#E5281C` light / `#FF3B30` dark.
- **Fonts:** Archivo (display/headers/body) + Space Mono (all numbers and labels, no
  exception) — both registered and bundled (`Info.plist` `UIAppFonts`,
  `Core/DesignSystem/Font+Design.swift`). Not Bebas Neue/DM Mono/Inter — that was an earlier,
  superseded plan.
- **No drop shadows.** Elevation via background tint only. (Some pre-existing accent
  shadows remain in the codebase as a known deviation, not yet swept.)
- **Numbers always monospaced** (Space Mono)
- All labels in small caps with letter-spacing
- **PR is a treatment, not a color** — `inkPrimary` text + 1.5px `inkPrimary` underline,
  not amber. Amber (`#c9892e`) is reserved app-wide for Fuel's over-target signal.

## Widgets (PumpShared + PulsePumpWidget)

- `PumpShared/` is a synchronized folder compiled into **both** the app and the widget extension (`WorkoutActivityAttributes`, `BodyHeat`, the custom-widget catalog/canvas, the fixed widget layouts). Nothing in it may import app-only code; it uses `Color("…")` asset names and the `.archivo` / `.spaceMono` / `Color(hex:)` helpers, which the extension mirrors in `PulsePumpWidget/WidgetSupport.swift`.
- **Fixed widgets** (Pump Widgets.dc.html): every layout is a pure SwiftUI view in `PumpShared/Widgets/*Widget.swift` drawn at the design's point size (`PWFamily.size`: small 170², medium 364×170, large 364×382) and scaled to the real container by `PWHost`. Data comes only from `PumpWidgetSnapshot` (`snap.fixed` = `PWFixedData`); `PumpWidgetSnapshot.sample` mirrors the numbers printed in the design. Add a widget by writing the view + `static var gallery`, registering it in `PWRegistry`, and adding a descriptor in `PulsePumpWidget/FixedWidgets.swift` + the bundle.
- **Widget Gallery** (More › Widgets › Widget gallery) renders every registered widget in light / dark / tinted — what you see is what WidgetKit draws. DEBUG: launch with `-debugGallery <section id|all>` to open it directly.
- **Custom widgets** (Widget Builder): library saved in the App Group (`PumpWidgetStore`); builder in `Features/Widgets/`; "Pump Custom" extension widget picks a saved widget via an App Intent.
- `WidgetDataService` computes the snapshot (app side) after workouts / on launch; the extension never touches SwiftData or Firebase.
- Plus widgets (04-07) show `LockedWidgetPreview` (`PWPlusGate`) when `snap.fixed.isPlus` is false; its button opens `pulsepump://pulse-plus`.

## Units (kg stored, display converts)

**Everything stored or synced is kg** (`User.weight`, `SetLog.weight`, `BarConfig.weightKg`, `EquipmentProfile.availablePlates`, bodyweight log, widget snapshot numbers, Live Activity values, feed payloads, challenge scores); height is cm. `UnitPreference` (`PumpShared/WeightUnit.swift`, alias `WeightUnit`) only changes display and typed input, so changing it must never mutate stored data.
- Views read `@Environment(\.weightUnit)` (injected once in `RootView` from the User). Use `unit.format(kg)` / `number(kg)` / `label` for output and `unit.parseKg(text)` / `kg(fromDisplay:)` for input. Never hard-code "KG"/"LB" or `String(format: "%g", weight)`.
- Logger text fields hold kg strings (`SetEntry.weight`) but edit in the display unit via `KgTextField`. Plate maths goes through `PlateMath` (loads real lb plates in lbs mode).
- Widgets: `PumpWidgetSnapshot.weightUnit`; widget views convert/label via `snap.unit`. Services without a view use `UnitPreference.current` (UserDefaults mirror written by `RootView`).
- Exports are always kg (JSON `weightUnit`, CSV `Unit` column). Imports convert from the file's unit (header, else the unit the user picks).

## Testing

Three tiers, all run in CI (`.github/workflows/ci.yml`):

| Tier | Where | Run |
|---|---|---|
| Unit | `PulsePumpTests/` (Core, Features, DevData) with in-memory fakes (`InMemoryRemoteStore`, `FakeSocialRemote`) | `bin/test.sh` (CI job `test`) |
| Firebase rules + functions | `firebase/rules-tests`, `firebase/functions/test` (vitest, emulators) | `npm test` in each folder (CI job `firebase`) |
| iOS emulator integration | `PulsePumpTests/Integration/`: real Swift auth/sync/social code vs the Auth, Firestore and Functions emulators (project `demo-pump`) | `bin/test-integration.sh` (CI job `ios-integration`) |

The Integration suites are skipped (not failed) unless `PUMP_EMULATOR=1`, so `bin/test.sh` stays emulator-free. `bin/test-integration.sh` builds the functions, starts the emulators with `firebase emulators:exec` and forwards the flag to the test host (`TEST_RUNNER_PUMP_EMULATOR=1`); it builds with ad-hoc signing because Firebase Auth needs a keychain entitlement. Shared helpers are in `Integration/Support/`: `EmulatorKit` (one named FirebaseApp per simulated user, so several accounts are signed in at once and the host's default app is never touched; Auth and Firestore are wiped between tests), `TestAccount`, and `IntegrationData` factories that reuse `SyncDevice` and `DevDataService` for realistic workouts. One test file per feature. Clients are asserted to be on `demo-pump`, never the real project. DEBUG demo fixtures (`DevFlags.socialFixtures`, `FakeSocialRemote` data) are never used by integration tests. CI uploads the xcresult and emulator logs on failure.

## Dev data (fake data for testing)

DEBUG-only seeder in `PulsePump/DevData/` (compiled out of Release) — the iOS counterpart of `manage.py createdevdata`.

```bash
bin/createdevdata.sh                       # build, clean-install on the simulator, seed, launch
bin/createdevdata.sh --scenario lapsed     # busy (default) | lapsed (no sessions in 12 days) | new-user (empty states)
bin/createdevdata.sh --weeks 24 --seed 7 --units lb --plus --draft --help
```

It works through launch arguments (`-createDevData 1 -devDataReset 1 -devDataScenario … -devDataWeeks … -devDataSeed … -devDataUnits … -devDataPlus 1 -devDataDraft 1 -devDataSocialFixtures 1`), so the same flags can be added in the Xcode scheme, `simctl launch`, or XCUITest. Same seed → identical data. Dataset: user "Dev Lifter", PPL split with days populated, Home/Commercial equipment profiles, Push/Pull/Leg templates with real exercise ids, ~5 sessions/week with progressive overload, warm-ups, a deload week, fresh PRs, a 60-day bodyweight log, and (for Firestore-backed screens that can't be seeded locally) the built-in demo friends/feed/challenges via `DevFlags.socialFixtures`. Add new models to `DevDataFactory` / `DevDataService.reset` when you add them to the schema. Demo/fixture data is never reachable in Release.

**Auto sign-in (DEBUG):** `-debugEmail <e> -debugPassword <p> -debugAutoOnboard 1` signs in (or signs up) and completes onboarding with no taps (`DevData/DevDataAutoAccount.swift`); combine with `-createDevData 1 -devDataReset 1` to push a seeded history through sync. Add `-useFirebaseEmulator 1` to stay off the real project. Build with ad-hoc signing (`CODE_SIGN_IDENTITY=-`) or Firebase Auth fails with a keychain error.

## Known Gaps (from spec)

See `docs/pulse-pump-spec.md` §"Known Gaps & Backlog" for the full list. High-priority items:
- Template share-via-link (`pulsepump://template?data=<base64>`) — URL handling exists but Firestore backend not wired
- Challenges not gated behind Pulse+ check
- Friend profile tap destination missing
- Post-workout share card missing body map silhouette
- Widget extension shows streak only — missing predicted workout and weekly volume widgets
- Free trial uses `UserDefaults` install date instead of StoreKit introductory offer
