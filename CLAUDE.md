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
- `Color.pumpAccent` is the canonical accent token (`Extensions/Color+Theme.swift` + xcassets `PumpAccent.colorset`). Set to terracotta `#c8553d` light / `#dc7d4a` dark. `Color.pumpPrimary` is a deprecated alias — do not use it.

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

## Design Refresh (pump-and-fuel/)

The `pump-and-fuel/project/` directory contains HTML prototype files from Claude Design that define the target UI. These are the reference screens for the ongoing UI/UX update:

| File | Screen |
|------|--------|
| `Pump Home Screen.html` | Home (3 variants: Dense, Calm, Balanced) + draft state |
| `Pump Muscle Map.html` | Body Map tab with thermal heatmap + day scrubber |
| `Pump Workout Logging v2.html` | Active workout card stack + set rows + plate calc |
| `Pump Post-Workout Summary.html` | Completion screen + share card + caption composer |
| `Pump Social Feed.html` | Feed, post detail, friend profile |
| `Pump Programs Exercise Library.html` | Programs list, template detail, exercise picker |

Design system reference: `pump-and-fuel/project/uploads/pulse-design-system.md`

Key design tokens to implement in Swift:
- **Accent:** `#c8553d` light / `#dc7d4a` dark
- **Canvas bg:** `#fbf8f2` light / `#1a1816` dark
- **Ticker bg (always dark):** `#1a1816`
- **Fonts:** Bebas Neue for display/headers, DM Mono for labels/numbers, Inter for body (currently using SF Pro system fonts — will need custom font registration)
- **No drop shadows.** Elevation via background tint only.
- **Numbers always monospaced** (DM Mono / SF Mono)
- All labels in small caps with letter-spacing

## Known Gaps (from spec)

See `pulse-pump-spec.md` §"Known Gaps & Backlog" for the full list. High-priority items:
- Template share-via-link (`pulsepump://template?data=<base64>`) — URL handling exists but Firestore backend not wired
- Challenges not gated behind Pulse+ check
- Friend profile tap destination missing
- Post-workout share card missing body map silhouette
- Widget extension shows streak only — missing predicted workout and weekly volume widgets
- Free trial uses `UserDefaults` install date instead of StoreKit introductory offer
