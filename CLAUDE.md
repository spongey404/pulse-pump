# Pulse Pump

iOS workout logging app. Part of the Pulse ecosystem.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Data:** SwiftData (local-first, cloud sync planned for Pulse+)
- **Target:** iOS 17+
- **Xcode:** 26.4

## Project Structure

```
PulsePump/
├── App/                  # App entry point
│   └── PulsePumpApp.swift
├── Models/               # SwiftData models
│   ├── Enums/            # All enum types
│   ├── User.swift
│   ├── Exercise.swift
│   ├── WorkoutTemplate.swift
│   ├── Workout.swift
│   ├── ExerciseLog.swift
│   ├── SetLog.swift
│   ├── Split.swift
│   ├── EquipmentProfile.swift
│   ├── UserProfile.swift
│   └── Challenge.swift
├── Views/                # SwiftUI views
├── ViewModels/           # View models
├── Services/             # Business logic services
├── Utilities/            # Helpers
├── Extensions/           # Swift extensions
├── ContentView.swift     # Root tab view
├── Assets.xcassets/      # App assets
├── Info.plist
└── PulsePump.entitlements
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

## Build Order (from spec)

1. ~~Core Data Models & Local Storage~~ (done)
2. ~~Onboarding Flow~~ (done — Firebase Auth: Apple, Google, Email)
3. ~~Exercise Library~~ (done — 84 seeded exercises, search, filters, create custom)
4. ~~Workout Logging~~ (done — active workout, rest timer, ghost text, PR detection)
5. ~~Programs & Templates~~ (done — 7 seed templates, create/edit/start)
6. ~~Body Map Tab~~ (done — muscle heatmap, volume/recency modes, analytics charts)
7. ~~Home Screen~~ (done — quick analytics, recent workouts, global search)
8. ~~Workout History~~ (done — list/calendar view, detail, duplicate)
9. ~~Social Features~~ (done — activity feed, friends, challenges stubs)
10. ~~Utility Features~~ (done — plate calculator, warmup generator, equipment profiles)
11. ~~Shareable Summary Cards~~ (done — post-workout, weekly/monthly recap, milestone)
12. ~~Settings~~ (done — profile edit, units, rest timer, calorie formula, notifications)
13. ~~Calorie Burn & Ecosystem Integration~~ (done — basic + MET formulas, swappable)
14. ~~Pulse+ Subscription System~~ (done — StoreKit 2, paywall, feature gating)
15. ~~iOS Platform Features~~ (done — data export JSON/CSV, Live Activity service)

## Architecture Decisions

- Using SwiftData over Core Data for modern Swift integration
- All models have UUID identifiers for future cloud sync
- All mutable models have createdAt/updatedAt timestamps
- Enums are `Codable` + `CaseIterable` + `Identifiable` for easy use in SwiftUI
- TemplateExercise, SplitDay, BarConfig, LeaderboardEntry are value types (structs) stored as JSON in their parent models
- Tab bar: Programs | Social | Home (center) | Body Map | More
- `@Observable` macro (not `ObservableObject`) for Swift 6 concurrency
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types implicitly MainActor
- Firebase Auth via SPM (FirebaseAuth, GoogleSignIn)
- StoreKit 2 for subscriptions (no server-side receipt validation yet)
- UserDefaults for lightweight settings (rest timer mode, calorie formula, notifications)
- CalorieEstimationService is swappable between basic (set-based) and MET-based formulas
- `StreakCalculator` (Utilities/) is the single source of truth for streak logic — gap-based, 3-day expiry
- Feed caching via `lastFeedFetch` timestamp in `SocialViewModel` — 5-min TTL, force-refreshable
- `TemplateExercise.targetReps` is `Int?` — nil means no target reps, sets always required
- `WorkoutActivityAttributes` is defined in both the main app (`LiveActivityService.swift`) and widget extension (`WorkoutLiveActivity.swift`) — must be kept in sync manually until a shared framework is added

## Key Files Added Post-V1

| File | Purpose |
|------|---------|
| `Utilities/StreakCalculator.swift` | Shared streak logic (gap-based, 3-day expiry) |
| `Views/Social/FeedBodyMapView.swift` | Compact front/back body silhouette for feed posts |
| `PulsePumpWidget/WorkoutLiveActivity.swift` | Dynamic Island + lock screen Live Activity for workouts |
| `Models/Enums/MuscleSubRegion.swift` | 35 anatomical sub-regions across all muscle groups |

## UI Patterns

- Bottom docked bars use `.safeAreaInset(edge: .bottom)` — used for Start Workout dock (Home) and WorkoutBottomBar (active workout)
- Swipe-to-delete on List rows uses `.swipeActions(edge: .trailing, allowsFullSwipe: true)`
- `.swipeActions` only works inside `List` — not `ScrollView`/`LazyVStack`
- Program cards use `navigationDestination(item: $selectedTemplate)` + `Button` to avoid `NavigationLink`'s `>` chevron
- Body map uses `TabView(.page)` to swipe between front/back views
