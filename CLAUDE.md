# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Pulse Pump

iOS workout logging app. Part of the Pulse ecosystem.

## Build Commands

```bash
# Build (simulator)
xcodebuild -scheme PulsePump -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Run tests
xcodebuild -scheme PulsePump -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Run a single test class
xcodebuild -scheme PulsePump -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:PulsePumpTests/StreakCalculatorTests test

# Build widget extension
xcodebuild -scheme PulsePumpWidget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Xcode version: 26.4. Target: iOS 17+.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Local data:** SwiftData (local-first)
- **Remote data:** Firestore (social features only — feed posts, friendships, challenges)
- **Auth:** Firebase Auth (Apple, Google, Email) via `FirebaseAuthService`
- **Subscriptions:** StoreKit 2 via `PulsePlusService`
- **Live Activity / Dynamic Island:** `PulsePumpWidget` extension + `LiveActivityService`

## Project Structure

```
PulsePump/
├── App/PulsePumpApp.swift   # Entry point; ModelContainer, deep-link handling
├── Models/                  # SwiftData models + value-type structs
│   └── Enums/               # All enum types (Codable + CaseIterable + Identifiable)
├── Views/
│   ├── BodyMap/             # Muscle heatmap tab
│   ├── ExerciseLibrary/     # Browse + search + create exercises
│   ├── Home/                # Widgets, global search, start-workout dock
│   ├── More/                # History, profile, workout detail
│   ├── Onboarding/          # Multi-step onboarding container + step views
│   ├── Programs/            # Template list, detail, create, edit
│   ├── Settings/            # Settings, profile edit, Pulse+, data export
│   ├── Social/              # Feed, friends, comments, challenges
│   ├── Tutorial/            # CoachMark overlay + hint system
│   ├── Utilities/           # Plate calculator, warmup generator, equipment profiles
│   └── Workout/             # Active workout, exercise picker, completion, share card
├── ViewModels/              # WorkoutViewModel, SocialViewModel, OnboardingViewModel, TutorialViewModel
├── Services/                # Business logic (see Service Layer below)
├── Utilities/StreakCalculator.swift
├── Extensions/Color+Theme.swift
└── ContentView.swift        # Tab bar + HomeTabView + ProgramsTabView
PulsePumpWidget/             # Widget + Live Activity extension
```

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
- `StreakCalculator` (Utilities/) is the single source of truth for streak logic — gap-based, 3-day expiry window
- `Color.pumpAccent` is the canonical accent token (`Extensions/Color+Theme.swift` + xcassets `PumpAccent.colorset`). Set to blue `#0A6FC0` (same light/dark — filled surfaces stay this flat value so white text keeps contrast). `Color.accentInk` (xcassets `AccentInk.colorset`) is the text/glyph/border variant, which lifts to `#4DB8FF` on the dark canvas; use it instead of `pumpAccent` for anything that isn't a filled surface. `Color.pumpPrimary` is a deprecated alias — do not use it. Full rationale in `design_handoff_pulse_color_system/README.md` (Claude Design project "App color system redesign").

## UI Patterns

- Bottom docked bars use `.safeAreaInset(edge: .bottom)` — Start Workout dock and `WorkoutBottomBar`
- Swipe-to-delete uses `.swipeActions(edge: .trailing, allowsFullSwipe: true)` inside `List` only (not `ScrollView`/`LazyVStack`)
- Program cards use `navigationDestination(item: $selectedTemplate)` + `Button` to suppress the `>` chevron
- Body map uses `TabView(.page)` to swipe between front/back views
- `listRowBackground(.clear)` on program card rows removes the gray reveal on swipe-to-delete

## Key Files Post-V1

| File | Purpose |
|------|---------|
| `Utilities/StreakCalculator.swift` | Shared streak logic |
| `Views/Social/FeedBodyMapView.swift` | Compact front/back silhouette for feed posts |
| `PulsePumpWidget/WorkoutLiveActivity.swift` | Dynamic Island + lock screen Live Activity |
| `Models/Enums/MuscleSubRegion.swift` | 35 anatomical sub-regions |

## Design Refresh (pump and fuel design html files/)

The `pump and fuel design html files/` directory (renamed from `pump-and-fuel/project/`)
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

Design system reference: `pump and fuel design html files/uploads/pulse-design-system.md`
(multi-app master doc). Pump-only reference with the confirmed token values:
`PULSE_PUMP_DESIGN_REFERENCE.md`. Color token rationale and contrast numbers:
`design_handoff_pulse_color_system/README.md` (Claude Design project "App color system
redesign", also covers `Set Row States.dc.html`, the active-row/completed-row/PR states spec).

Key design tokens implemented in Swift:
- **Accent:** `#0A6FC0` blue, flat in both color schemes on filled surfaces (`pumpAccent`);
  lifts to `#4DB8FF` on the dark canvas for text/glyphs/borders (`accentInk`)
- **Canvas bg:** `#f9f8f4` light / `#1a1917` dark
- **Ticker bg:** `#1a1816`, always-dark per spec — but the implemented `TickerStripView`
  switches to a light cream (`#f0ebe0`) in light mode, a deliberate deviation. Its
  up-arrow green follows suit: `#00e07a` in dark mode, `#2a7a4a` in light mode (the
  bright green washes out on the light bg).
- **Fonts:** Archivo (display/headers/body) + Space Mono (all numbers and labels, no
  exception) — both registered and bundled (`Info.plist` `UIAppFonts`,
  `Extensions/Font+Design.swift`). Not Bebas Neue/DM Mono/Inter — that was an earlier,
  superseded plan.
- **No drop shadows.** Elevation via background tint only. (Some pre-existing accent
  shadows remain in the codebase as a known deviation, not yet swept.)
- **Numbers always monospaced** (Space Mono)
- All labels in small caps with letter-spacing
- **PR is a treatment, not a color** — `inkPrimary` text + 1.5px `inkPrimary` underline,
  not amber. Amber (`#c9892e`) is reserved app-wide for Fuel's over-target signal.

## Known Gaps (from spec)

See `pulse-pump-spec.md` §"Known Gaps & Backlog" for the full list. High-priority items:
- Template share-via-link (`pulsepump://template?data=<base64>`) — URL handling exists but Firestore backend not wired
- Challenges not gated behind Pulse+ check
- Friend profile tap destination missing
- Post-workout share card missing body map silhouette
- Widget extension shows streak only — missing predicted workout and weekly volume widgets
- Free trial uses `UserDefaults` install date instead of StoreKit introductory offer
