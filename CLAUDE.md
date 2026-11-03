# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Ore

iOS strength-training app (formerly Pump, part of the Pulse family). Siblings: Tare (calorie tracker, not built here) and Drift (steps and routes, provisional name).

## Build Commands

```bash
bin/test.sh               # unit tests exactly as CI runs them (first available iPhone simulator)
bin/test.sh --release     # + Release build, and fails if DEBUG-only DevData code ships
bin/test-integration.sh   # iOS integration tests vs the local Firebase emulators (needs firebase-tools, Java 21, Node 24)
bin/test-integration.sh --only SyncRoundTripEmulatorTests   # a single integration suite
bin/test-ui.sh            # end-to-end XCUITests: taps through the app vs the Firebase emulators (see "Testing")
bin/test-ui.sh --only WorkoutUITests            # one class (or Class/testName); --device "iPhone 17e" picks the simulator
(cd firebase/functions && npm test)     # functions unit tests (npm run test:integration for trigger tests)
(cd firebase/rules-tests && npm test)   # Firestore security rules tests
bin/createdevdata.sh      # build, clean-install and seed fake data (see "Dev data")

# Raw xcodebuild (pick any installed simulator, e.g. iPhone 17 Pro)
xcodebuild -scheme Ore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Ore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:OreTests/StreakCalculatorTests test
xcodebuild -scheme OreWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Xcode version: 26.4. The project's deployment target is currently **iOS 26.4** (`IPHONEOS_DEPLOYMENT_TARGET`); lowering it (the app was written for iOS 17+) means checking the iOS 26 APIs the sign-up and member screens use. CI: `.github/workflows/ci.yml` runs `bin/test.sh --release` on every PR and on pushes to `main`/`develop`. UI tests (`OreUITests`) run through `bin/test-ui.sh` (CI job `ios-ui`, non-blocking until stable); `bin/test.sh` skips them.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Local data:** SwiftData (local-first)
- **Remote data:** Firestore (social features only — feed posts, friendships, challenges)
- **Auth:** Firebase Auth (Apple, Google, Email) via `FirebaseAuthService`
- **Subscriptions:** StoreKit 2 via `SupernovaService`
- **Live Activity / Dynamic Island:** `OreWidget` extension + `LiveActivityService`

## Project Structure

Feature-first inside the app target; shared code in `Core/`. Targets use Xcode synchronized folders, so adding/moving a file needs no project edit.

```
Ore/                      app target
├── App/                        entry point (OreApp), RootView (onboarding vs app), ContentView (tab shell), deep links
├── Core/
│   ├── DesignSystem/           Color+Theme, Font+Design, Components/ (Avatar, buttons, ticker, tab bar, modals, ledger rows, KPIBlock, FilterChip…)
│   ├── Models/                 SwiftData models, Enums/, Firestore/ (Codable structs mirroring Firestore)
│   ├── Persistence/            exercise/template seeding, Strong/Hevy import, JSON/CSV export
│   ├── Services/               Auth/, Firestore/ (FirestoreService), Notifications/
│   └── Utilities/              StreakCalculator, String+Search
├── Features/                   one folder per feature: its Views + ViewModel + Services together
│   ├── Home/  Workout/ (Views/, Views/Logger/, Tools/, WorkoutViewModel, Services/: rest timer, live activity, calories)
│   ├── Programs/  BodyMap/  Exercises/  Equipment/  Social/ (Feed/, Friends/, Challenges/, SocialViewModel)
│   ├── More/  Settings/  Supernova/ (paywall, StoreKit service, upsell banner)  Signup/ (the sign-up console)  Onboarding/ (profile model only)  Tutorial/
│   └── Widgets/                widget builder UI, gallery, WidgetDataService (snapshot for the extension), BodyweightLog
├── DevData/                    DEBUG-only fake-data seeder (see "Dev data")
├── Resources/Fonts/            Archivo + Space Mono
└── Assets.xcassets, Info.plist, entitlements, GoogleService-Info.plist
OreShared/                     compiled into BOTH app and widget extension (widget layouts, catalog, snapshot, BodyHeat, Live Activity attributes/intents)
OreWidget/                WidgetKit extension: providers, intents, bundle, Live Activity
OreTests/                 mirrors the app: Core/, Features/…, DevData/
OreUITests/               XCUITests (see "Testing")
bin/                            test.sh, createdevdata.sh
docs/                           spec, design reference, audit/
design/                         Claude Design handoffs, HTML prototypes, font sources
OreApp/                        old Expo scaffold (unused)
```

Where things go: a screen and everything only it uses → its `Features/<Name>/`; a view/modifier two or more features use → `Core/DesignSystem/Components/`; a model/enum → `Core/Models/`; cross-feature infrastructure → `Core/Services/`; anything the widget extension also needs → `OreShared/` (must not import app-only code). One primary type per file; name the file after it.

## Naming

The app was renamed from Pulse Pump to **Ore** (strength training). The Pulse family is replaced by independent names.

| Was | Is | Notes |
|---|---|---|
| Pump / Pulse Pump | **Ore** | project, targets, module, folders (`Ore/`, `OreTests/`, `OreUITests/`, `OreWidget/`, `OreShared/`), display name |
| Pulse Fuel | **Tare** | sibling app, not built here |
| Pulse Stride | **Drift** | **provisional**, may change |
| Pulse+ | **Supernova\*** | one membership across the apps; plans: 1 app, 2 apps, all 3 (monthly/yearly) |
| company name | **not final** | never hardcode one (`Brand.companyName` is nil) |

- Every brand string lives in `OreShared/Brand/Brand.swift` (`Brand.appName`, `.membershipName`, `.tareName`, `.driftName`, `.urlScheme`, …). Add or change names there, not at call sites.
- **Supernova\* rules.** In code the name is always "Supernova"; the gold asterisk is a separate drawn element (`SupernovaWordmark`, `SupernovaAsterisk` in `OreShared/Brand/`). The asterisk is on branded surfaces only: the paywall wordmark, the More banner ("GO SUPERNOVA\*"), locked/blurred inline sections ("UNLOCK WITH SUPERNOVA\*"), the member profile tag, locked widgets. Never in plain text: notifications, share-sheet text, emails, StoreKit display names, App Store copy. The gold is the `SupernovaGold` colour token. The share-card watermark says "Ore" only. VoiceOver reads "Supernova".
- Product ids for the three tiers are placeholders in `SupernovaTier` (`supernova.1app.monthly` … `supernova.allapps.yearly`); the live subscription still uses `SupernovaService.monthlyProductId/yearlyProductId`.
- URL scheme: `ore://` (links we generate); the old `pulsepump://` still opens (`Brand.isOwnScheme`, host `pulse-plus` is still accepted next to `supernova`).
- **Deliberately unchanged** (renaming would orphan data or break installs): bundle ID `com.pulse.PulsePump` (and `…Tests`, `…UITests`, `….widget`), App Group `group.com.pulse.PulsePump`, notification identifiers `com.pulse.PulsePump.*`, StoreKit product ids `com.pulse.PulsePump.monthly/.yearly`, SwiftData models and store, UserDefaults keys (`pulsePlusSubscribedMirror`, `pulse_eco_fuel`, `pulse_eco_stride`, …), widget `kind` strings (`PumpStreak`, `PulsePumpWidget`, …: renaming removes widgets people already placed), the deterministic template-id seed `pump.preset.template.*`, Firebase config (`GoogleService-Info.plist`, project `pulsepump-81986`, `demo-pump`), the `PUMP_EMULATOR*` test env vars, `Notification.Name("pump.liveActivity.*")`, and the GitHub remote `pulse-pump` (repo rename pending). **Open decision: the bundle ID.** If the app was never uploaded to App Store Connect/TestFlight it can still change (also needs a new App Group, entitlements, Firebase app/plist, notification and StoreKit ids); decide before the company name is final.

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
| `SupernovaService` | StoreKit 2 product fetching, purchase, entitlement check |
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
- `Color.oreAccent` is the canonical accent token (`Core/DesignSystem/Color+Theme.swift`). Default blue `#1AA7FF` (Ore Design System e68c2807, same light/dark; catalogue colour `OreAccentDefault`). `Color.accentInk` is the same hex and is the token for text/glyph/border use — use it instead of `oreAccent` for anything that isn't a filled surface. Both (and `accentSoft`) are **dynamic**: they read `AccentStore`, so a Supernova member's chosen colour (membership page › Account › Accent) replaces Ore's blue everywhere; free users and lapsed members always get Ore's. Widgets keep Ore's blue. Full rationale in `design_handoff_pulse_color_system/README.md` (Claude Design project "App color system redesign").

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
| `OreWidget/WorkoutLiveActivity.swift` | Dynamic Island + lock screen Live Activity |
| `Core/Models/Enums/MuscleSubRegion.swift` | 35 anatomical sub-regions |

## Design Refresh (design/pump and fuel design html files/)

The `design/pump and fuel design html files/` directory (renamed from `pump-and-fuel/project/`)
contains HTML prototype files from Claude Design that define the target UI. These are
the reference screens for the ongoing UI/UX update:

| File | Screen |
|------|--------|
| `Ore Home Screen.html` | Home (3 variants: Dense, Calm, Balanced) + draft state |
| `Ore Muscle Map.html` | Body Map tab with thermal heatmap + day scrubber |
| `Ore Workout Logging v2.html` | Active workout card stack + set rows + plate calc |
| `Ore Post-Workout Summary.html` | Completion screen + share card + caption composer |
| `Ore Social Feed.html` | Feed, post detail, friend profile |
| `Ore Programs Exercise Library.html` | Programs list, template detail, exercise picker |

Design system reference: `design/pump and fuel design html files/uploads/pulse-design-system.md`
(multi-app master doc). Ore-only reference with the confirmed token values:
`docs/PULSE_PUMP_DESIGN_REFERENCE.md`. Color token rationale and contrast numbers:
`design_handoff_pulse_color_system/README.md` (Claude Design project "App color system
redesign", also covers `Set Row States.dc.html`, the active-row/completed-row/PR states spec).

Key design tokens implemented in Swift:
- **Accent:** `#1AA7FF` blue, flat in both color schemes (`oreAccent`, `accentInk`)
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

## Widgets (OreShared + OreWidget)

- `OreShared/` is a synchronized folder compiled into **both** the app and the widget extension (`WorkoutActivityAttributes`, `BodyHeat`, the custom-widget catalog/canvas, the fixed widget layouts). Nothing in it may import app-only code; it uses `Color("…")` asset names and the `.archivo` / `.spaceMono` / `Color(hex:)` helpers, which the extension mirrors in `OreWidget/WidgetSupport.swift`.
- **Fixed widgets** (Ore Widgets.dc.html): every layout is a pure SwiftUI view in `OreShared/Widgets/*Widget.swift` drawn at the design's point size (`PWFamily.size`: small 170², medium 364×170, large 364×382) and scaled to the real container by `PWHost`. Data comes only from `OreWidgetSnapshot` (`snap.fixed` = `PWFixedData`); `OreWidgetSnapshot.sample` mirrors the numbers printed in the design. Add a widget by writing the view + `static var gallery`, registering it in `PWRegistry`, and adding a descriptor in `OreWidget/FixedWidgets.swift` + the bundle.
- **Widget Gallery** (More › Widgets › Widget gallery) renders every registered widget in light / dark / tinted — what you see is what WidgetKit draws. DEBUG: launch with `-debugGallery <section id|all>` to open it directly.
- **Custom widgets** (Widget Builder): library saved in the App Group (`OreWidgetStore`); builder in `Features/Widgets/`; "Ore Custom" extension widget picks a saved widget via an App Intent.
- `WidgetDataService` computes the snapshot (app side) after workouts / on launch; the extension never touches SwiftData or Firebase.
- Plus widgets (04-07) show `LockedWidgetPreview` (`PWPlusGate`) when `snap.fixed.isPlus` is false; its button opens `ore://supernova`.

## Units (kg stored, display converts)

**Everything stored or synced is kg** (`User.weight`, `SetLog.weight`, `BarConfig.weightKg`, `EquipmentProfile.availablePlates`, bodyweight log, widget snapshot numbers, Live Activity values, feed payloads, challenge scores); height is cm. `UnitPreference` (`OreShared/WeightUnit.swift`, alias `WeightUnit`) only changes display and typed input, so changing it must never mutate stored data.
- Views read `@Environment(\.weightUnit)` (injected once in `RootView` from the User). Use `unit.format(kg)` / `number(kg)` / `label` for output and `unit.parseKg(text)` / `kg(fromDisplay:)` for input. Never hard-code "KG"/"LB" or `String(format: "%g", weight)`.
- Logger text fields hold kg strings (`SetEntry.weight`) but edit in the display unit via `KgTextField`. Plate maths goes through `PlateMath` (loads real lb plates in lbs mode).
- Widgets: `OreWidgetSnapshot.weightUnit`; widget views convert/label via `snap.unit`. Services without a view use `UnitPreference.current` (UserDefaults mirror written by `RootView`).
- Exports are always kg (JSON `weightUnit`, CSV `Unit` column). Imports convert from the file's unit (header, else the unit the user picks).

## Testing

Four tiers, all run in CI (`.github/workflows/ci.yml`):

| Tier | Where | Run |
|---|---|---|
| Unit | `OreTests/` (Core, Features, DevData) with in-memory fakes (`InMemoryRemoteStore`, `FakeSocialRemote`) | `bin/test.sh` (CI job `test`) |
| Firebase rules + functions | `firebase/rules-tests`, `firebase/functions/test` (vitest, emulators) | `npm test` in each folder (CI job `firebase`) |
| iOS UI (XCUITest) | `OreUITests/`: tap-through flows (sign-up/onboarding, logging, history, programs, body, settings, account lifecycle, social) vs the emulators | `bin/test-ui.sh` (CI job `ios-ui`, `continue-on-error` until stable) |
| iOS emulator integration | `OreTests/Integration/`: real Swift auth/sync/social code vs the Auth, Firestore and Functions emulators (project `demo-pump`) | `bin/test-integration.sh` (CI job `ios-integration`) |

The Integration suites are skipped (not failed) unless `PUMP_EMULATOR=1`, so `bin/test.sh` stays emulator-free. `bin/test-integration.sh` builds the functions, starts the emulators with `firebase emulators:exec` and forwards the flag to the test host (`TEST_RUNNER_PUMP_EMULATOR=1`); it builds with ad-hoc signing because Firebase Auth needs a keychain entitlement. Shared helpers are in `Integration/Support/`: `EmulatorKit` (one named FirebaseApp per simulated user, so several accounts are signed in at once and the host's default app is never touched; Auth and Firestore are wiped between tests), `TestAccount`, and `IntegrationData` factories that reuse `SyncDevice` and `DevDataService` for realistic workouts. One test file per feature. Clients are asserted to be on `demo-pump`, never the real project. DEBUG demo fixtures (`DevFlags.socialFixtures`, `FakeSocialRemote` data) are never used by integration tests. CI uploads the xcresult and emulator logs on failure.

### UI tests (`OreUITests`)

Each test launches the app with DEBUG launch arguments only (`LaunchConfig` builds them): `-useFirebaseEmulator 1`, `-debugEmail/-debugPassword` (a fresh emulator account per test, signed in or created by `DevDataAutoAccount`), `-debugAutoOnboard 1`, `-createDevData 1 -devDataReset 1 -devDataScenario busy|lapsed|new-user -devDataUnits kg|lb -devDataPlus/-devDataDraft`, `-debugStartTab`, `-wantsTutorial`, and `-debugFreshSession 1` (signs out the previous login and clears the SwiftData store before any view exists, so tests are independent). Social tests sign in as the seeded `friend1@example.com` / `password` (`firebase/seed`, run by the script). Under `-useFirebaseEmulator` the default Firebase app is re-targeted to project `demo-pump` (the emulators namespace data by project).
`bin/test-ui.sh` builds the functions, starts auth+firestore+functions with `firebase emulators:exec`, seeds, uninstalls the app and resets the simulator keychain, then runs the UI target with ad-hoc signing; failures keep a screenshot and the UI hierarchy in `build/UITestResults.xcresult`. The target cannot import app code, so it compiles `Core/DesignSystem/AccessibilityIDs.swift` (enum `AX`, strings only) directly via a file reference in the project; add an identifier there, attach it with `.accessibilityIdentifier(AX…)` (or `.axID`) and use the same constant from a page object in `OreUITests/Pages/`. `MoreRow`, `MoreMenuRow`, `MoreScreenHeader` and `SocialPill` derive their identifiers from their labels (`AX.row("Settings")`).
Rules for new tests: wait with `waitForExistence`/predicate expectations (`UITestCase.require`, `waitForLabel`), never sleep; one account per test; quarantine a flaky test with `XCTSkip("reason")` and a note here rather than loosening assertions.

## Tutorial (interactive walkthrough)

`Features/Tutorial/`: a guided first workout on the real screens, nineteen `TutorialStep`s. The practice workout is a fixed six-exercise list (`TutorialMode.presetExercises`, started by `WorkoutViewModel.startTutorialWorkout` when the Home button is tapped during the tutorial), so the next exercise really is far down. Flow: start → add an exercise with the header + and the picker → ··· menu → RIR column on → numbers typed for the user (weight, reps, RIR) on the first exercise → plate calculator → set types → pick Warmup → log the set → swipe to delete → **search**: pull down, "row" is typed straight away (no tap on the bar, no keyboard, so the results stay in view), tap Barbell Row under IN YOUR WORKOUT to jump to it, log its pre-filled set → tap the clock to scroll back to the top → leave → discard. The practice workout is discarded at the end, so nothing reaches History; skipping mid-way cancels it too, and More › Tutorial refuses to start over a real draft.
- Rule for steps: anything the user could do themselves they do (tap, swipe, pull); the tutorial only types text. `.auto` steps show no finger.
- The card always sits right beside the spotlight (above or below, whichever side has more room; `cardSide` can force a side, e.g. the plate diagram opens under its toggle so the card goes above), never pinned to a screen edge.
- Finger placement (`touchAnchor`): dead centre on a small button (including DISCARD WORKOUT); in the blank space beside the text on a big button that has some (START WORKOUT, a picker row).
- Cost: the spotlight is one `Canvas` inside an `Equatable` view (a resting spotlight isn't redrawn) and the finger is one `Canvas`. The spotlight and card close on the clock (0.1s / 0.12s), not frame by frame, so a stalled redraw during a screen change can't leave them behind.
- The overlay is its own `UIWindow` (`TutorialOverlayWindow`, owned by `TutorialPresenter`), so it sits above the logger, picker and exercise page. Everything is dimmed except the target, with a soft falloff and glow; `hitTest` returns nil inside the spotlight (and over the keyboard) so touches reach the real control. The area that counts as a tap is the control's own frame plus 3pt (`TutorialPresenter.hole`), never grown, so a tap can't count while the app ignores it; only the drawn light is grown to fingertip size (`lit`).
- Views mark targets with `.tutorialTarget("tutorial.<id>")` (a background `UIView` registered in `TutorialTargets`, read live every frame so the spotlight follows scrolling and transitions). Rows that belong to one exercise are tagged only for the exercise `TutorialFocus.shared.exerciseName` names (`TutorialStep.focusExercise`). Add a step by adding a case to `TutorialStep` (copy, `gesture`, `target`, optionally `success`, `cardSide`, `touchAnchor`, `focusExercise`) and tagging the control.
- Advancing: `.tap` / `.swipeLeft` / `.swipeDown` steps advance when `TutorialTouchSpy` (a never-recognizing gesture recognizer on the app window) sees the touch land in the spotlight, **and** the screen then shows the step's result (`TutorialStep.success`: the next target appears, or a named target appears/disappears; polled up to 3 s). A miss brings the same card back. `.auto` steps are typed by the tutorial (`fillSet`, `.tutorialFillSearch`); `waitsForEvent` steps wait for what the app posts (`.tutorialExerciseAdded`, `.tutorialSetCompleted`). If the target is off screen the overlay posts `.tutorialRevealTarget` and the screen scrolls to it; the logger also keeps its list where it is while the tutorial runs.
- Hand-over: the card, finger and spotlight fade/close the moment a finger lands (`touchBegan`), because the next screen's work starts at touch-up and can stall the overlay's redraw; the card has no implicit animation (it would cross-dissolve the old title into the new one); a new step opens its spotlight fresh at its own target.
- `TouchHint` draws the finger: a ring closes in on the touch point, presses, ripples (tap) or slides (left for a swipe, down for the pull).
- Tests: `TutorialViewModelTests`, `TutorialGeometryTests` (unit); `OreUITests/Tests/TutorialUITests` (whole walkthrough, including a tap just outside a control that must be ignored) and `TutorialStartUITests` (start from More, draft guard, skip cleans up). They share `SeededUITestCase` (a throw-away emulator account per test, seeds the dev data, relaunches, reseeds once if the save was cut short). Run every UI test through `bin/test-ui.sh`: launched without the emulators a test signs out the simulator's real login. `TEST_RUNNER_TUTORIAL_SHOTS=<dir>` saves a screenshot per step.

## Workout logger: finding and adding exercises mid-workout

Without scrolling: pull the list down past its top (`ScrollPullObserver` watches the `UIScrollView` offset, since SwiftUI frames don't update while scrolling) to open `LoggerSearchOverlay`, a Spotlight-style panel that opens with the keyboard already up. **IN YOUR WORKOUT** lists matching exercises already in the session: tapping one scrolls to its card (slowly, with a brief outline) so the next set can be logged without scrolling. **ADD EXERCISE** lists library matches: tapping one opens that exercise's page (`ExerciseAddSheet` around `ExerciseDetailView`), and only its ADD TO WORKOUT button adds it. BROWSE ALL opens the full picker, as does the **+** in the logger header. Matching is `ExerciseSearch` (every typed word must start a word in the name). The exercise number beside a name that wraps stays vertically centred. The set row's TYPE column is `SetTypeChipLabel`: the dashed "+" and every type tag share one 28 × 22 box (tags grow to the 36pt column at most), so picking a type never shifts the row. Tests: `SetTypeChipTests` (measures the rendered chip), `ExerciseSearchTests`, `ExercisePickerIdentityTests` (unit); `LoggerUITests` (set-type chip and row positions, header number alignment, log circle, search, jump, add from the exercise's page, +).

## Logger (Ore Logger 1a)

Built from `Ore Logger 1a.dc.html`. Pure rules in `Features/Workout/Views/Logger/LoggerMath.swift` (steps, hold-and-drag `ScrubTracker`, plates and take-off/put-on, equipment labels `+KG` / `−KG` / `KG / HAND`, live 1RM, auto-progression prefill, drop/rest-pause/unilateral totals, finish text); behaviour in `WorkoutViewModel+Logger.swift`.
- **Card** `ExerciseCardView`: `≡ 01 NAME … N/M ···`, one-line meta `<EQUIPMENT> · PR … · 1RM …` (1RM turns gold with a star when a logged set's Epley estimate beats the best: the only live result, no ▲/▼ or per-set PR while training), column strip `# · KG · REPS · [RIR] · ✓`, 40 pt rows (`LoggerSetRow`), footer `+ SET` / `+ NOTE`. ··· is an anchored popover (RIR column, Auto progression, Rest timer, Superset, Replace, Remove). One **active** row for the whole workout (the next set to log) with − / + beside its numbers.
- **Numbers:** tap = `LoggerKeypad` (flat grid, "EDITING KG", step strip, NEXT / LOG SET; RIR = 0–5+ chips); hold 0.22 s and drag = scrub (18 pt a step, slide right past 40 pt = fine kg steps, bubble above the finger, haptic per step). Grey = last time's value, solid once typed or stepped, accent when auto progression bumped it. Opening the keypad scrolls the row ~10 pt above it.
- **Set types** (`setSetType`): Drop = D1/D2 lines (80 % and 65 % of the weight), rest-pause = R1/R2 lines, unilateral = LEFT/RIGHT, AMRAP shows MAX, failure locks RIR at 0. They log as ONE set: reps add up, and a drop set is stored with the rep-weighted average weight so volume stays exact (the line split is not stored; a resumed draft shows the total).
- **Sheets** (`LoggerSheets.swift`, dim `rgba(21,26,33,0.35)`, never blur): `RestSheet` (REST pill), `ProgressionSheet` (rep target in the profile as before, step per exercise on this device), `ReplaceSheet` (SWAP when nothing is logged, SWITCH otherwise: logged sets stay, unlogged ones move to the new exercise below; the family stays listed so a swap can be undone), `ReorderList` (hold the grip and drag, or ▲ ▼). Finish uses the Discard modal's `workoutModal` with new text.
- **Finish bar** fills left to right as sets are logged; members with Stardust buttons on get Stardust in the filled part, denser with each set (30 fps, still with Reduce Motion).
- **Plates** (`LoggerPlateSection`, barbell / EZ / trap bar): PLATES · X KG ▴ HIDE, the bar drawn to scale, TAKE OFF / PUT ON against the previous set, bar tiles BARBELL 20 · EZ 7.5 · TRAP 25 · SAFETY 32 · LIGHT 15. Plate colours are the IPF tokens in `Core/DesignSystem/PlatePalette.swift` (`PlateMath.Tier`: red, blue, yellow, green, white, black, chrome).
- Tutorial: the RIR step now opens the ··· menu then taps RIR column (nineteen steps). UI tests type through the keypad (`WorkoutPage.fillSet`). Add exercise still uses the full exercise picker (variants and the (i) page), not the mockup's simple list.
- Tests: `LoggerTests`, `LoggerUITests`; screenshots `LoggerShotsUITests`.

## Exercise detail page

`Features/Exercises/ExerciseDetailView.swift`, laid out from the Claude Design file `Exercise Detail.dc.html` (project 1b1d68d9…, read with `/design-login` + the DesignSync tool): a custom header (`‹ EXERCISES`, `···`), name + `EQUIPMENT · PRIMARY MUSCLE · COMPOUND/ISOLATION`, then ABOUT | HISTORY underline tabs. **About**: records strip (EST 1RM, BEST SET with the PR underline, LAST, SESSIONS), `MuscleLevelMap` (front and back figure, primary muscles full accent, secondary half; geometry transcribed from the design's `BodyMap.dc.html` into `MuscleLevelMapShapes` and drawn through `SVGPathLite`), PRIMARY/SECONDARY, SETUP rows (equipment, pattern, default rest from the compound/isolation settings, progression increment). **History**: range chips (1M 3M 6M 1Y ALL), a metric selector (E1RM / TOP SET / VOLUME), the headline value with the ▲/▼ change since the first point in range, a 150pt trend chart, and session rows with PR-marked sets (`SHOW ALL n SESSIONS ›`).
- The numbers come from `ExerciseDetailModel` (pure: records, PR marking, `series`, `headline`, `TrendChartLayout`); the view only formats them. A set is a PR only if it is its session's best by estimated 1RM, beat everything before it, and isn't in the first session (a baseline).
- **ADD TO WORKOUT is context**: `onAddToWorkout` is passed only by the add-exercise list inside the logger (the (i) on single exercises and on each variant). Opened from Home search or the library it is nil and there is no button, because there is no workout to add to.
- Tests: `ExerciseDetailModelTests`, `BodyMapTests` (unit); `ExerciseDetailUITests` (both tabs, chips and metrics, no button from search, the button from the add list adds the exercise; seeds the `busy` dataset).

## Global search (Home)

`Features/Home/GlobalSearchView.swift`, from Claude Design `Global Search Final.dc.html`: back arrow + sunken field, All/Exercises/Workouts/Friends pills, then RECENT (persisted in `UserDefaults`, `SearchRecents`) + YOUR TOP EXERCISES + FRIENDS when empty, grouped results (`EXERCISES · n`, `SEE ALL ›` past three rows) when typing. Limits and recents rules are pure (`GlobalSearchRules`, `SearchRecents`, tested in `GlobalSearchRulesTests`); `GlobalSearchUITests` drives the screen. Tutorial spotlight look is guarded by `SpotlightLookTests` (smooth fade, shape follows the control).

## Programs (Features/Programs)

A program is a set of `WorkoutTemplate`s sharing a `programId` (`programName`, `programDays` as Calendar weekdays 1=Sun, `programOrder`; `TemplateExercise.targetRepsHigh` for rep ranges). Fields are optional/defaulted and synced by `SyncMapper`/`SyncApplier`; no rules change. Pure logic is in `Features/Programs/Logic/`: `ProgramPlan` (Monday-first week, day assignment, UP NEXT rotation, average minutes from the last 5 sessions, targets text), `ProgramMigration` (idempotent; runs from `TemplateSeedService.seedIfNeeded` and DevData: rotation-token groups and weekday-named templates become one program, loose templates go to "My Workouts"), `ProgramDraft`/`ProgramStore` (create/save/delete), `ProgramPicker`. `ProgramsTabView` owns its NavigationStack. Home's `predictNextWorkout` still uses pattern/split logic, not the program rotation.
- **Stardust limiter:** every accent-filled button draws through `AccentFill(priority:variant:density:gold:sparkle:fps:)`, which asks `StardustLimiter` for a slot: at most 4 animate at once, docked buttons (priority 10) before in-content ones (5), off-screen ones release their slot, Reduce Motion freezes. Do not call `StardustView` directly for a button fill.
- Tests: `ProgramsTests` (unit), `ProgramsExercisesUITests`, `ProgramShotsUITests` (`PROGRAM_SHOTS=<dir>`).

## Supernova (membership visuals)

Built from the Claude Design file `Supernova Final.dc.html` (project 1b1d68d9…, read with `/design-login` + the DesignSync tool).
- **Paywall** (`Features/Supernova/SupernovaPaywallView.swift`): full-screen, always dark; Stardust behind everything melting into the dark free strip, the "SUPERNOVA\*" wordmark (the Stardust's gold attractor), four star bullets, one white CTA ("START 3 MONTHS FREE", yearly preselected), "TRAIN FREE →". `SupernovaPaywallGate` decides when: at the end of first-run onboarding (after the tutorial, or straight after onboarding when the tutorial is declined/skipped), once, and after every tutorial replay; never for a member. It replaces the tutorial's old "You're all set" screen; the end of the tutorial (finished or skipped, first run or a replay from More › Tutorial) always leads to the paywall for someone without Supernova; only a member still gets that done screen. Flags: `supernovaPaywallPending` (set by onboarding) and `supernovaPaywallShown`. From More, a free user's banner opens the same paywall through the shared-element transition below (strip reads "FREE · LOGGING STAYS FREE" / "TRAIN FREE →", the only way out); members get `SupernovaView`.
- **More tab** (`SupernovaMoreSurfaces.swift`): free = "GO SUPERNOVA\*" banner; member = Stardust avatar, "SUPERNOVA\*" profile tag, Stardust row icon ("RENEWS 14 MAR"), Weekly Recap card on Stardust with an eased-edge panel, and the Accent colour row (superseded: see "Supernova member experience").
- **Stardust** (`Core/Stardust/`): `StardustEngine` (pure, seedable particle simulation ported from the design's canvas loop, no SwiftUI types), `StardustView` (batched Canvas drawing: stars of one colour and brightness level are one path/fill; paused off-screen, in the background, in Low Power Mode, with Reduce Motion (one still frame), and a `.more` field keeps moving (`settleAfterMs` is 0 = never freeze; set it above 0 in the config to freeze a field after that many ms); `.paywall` drops to the idle fps after `idleAfterMs`), `StardustConfig`. **Every tunable is in `Ore/Resources/stardust.config.json`** (density, speed, gold, sparkle, goldPull, sway, flash, flare, fps, palettes, variants paywall/banner/tag/avatar/rowIcon/recapCard/button). The JSON is the shared source (an Android build reads the same file); `StardustConfig.fallback` must equal it (a test checks). `StardustConfigStore.override`/`applyRemote(json:)` is the Remote Config hook (no Firebase dependency added yet). Member Stardust palettes are the accent's three design stops (`SupernovaMemberConfig.Accent.palette`). Tests: `StardustTests`, `SupernovaPaywallFlowTests`, `AccentStoreTests`, `BrandTests`.
- DEBUG: `-debugSupernova paywall` opens the paywall on launch.

## Sign-up console (Features/Signup)

Sign-in, sign-up and onboarding are **one continuous console**, built from the Claude Design file `Ore Signup Final.dc.html` (project 1b1d68d9…, read with the DesignSync tool). `RootView` shows `SignupConsoleView` for both the signed-out and the signed-in-without-a-profile routes, so the same view stays up while the account is created. It replaced `SignInView`, the email sheet and the nine onboarding screens (`OnboardingViewModel` stays: it builds the profile and talks to `ProfileRemote`).
- **Flow:** opening screen (flat Ore blue, no stars; Apple / Google / email) → questions typed out one at a time (email, password, **confirm password**, name, username, weight, height, age, gender, experience, program; Apple/Google skip the first three) → setup lines → welcome ("YES, SHOW ME AROUND" → tutorial → paywall, or "SKIP" → paywall). Answered questions collapse into a log; tapping a row reopens it (a password reopens empty, and changing it asks for its confirmation again), later answers are kept and skipped.
- **Nothing is saved until the last answer is in**, so every row, email and password included, stays editable. Then: the Firebase account is created (`createAccount`), the profile API call runs (`OnboardingViewModel.submitRemote`; the setup lines start once it succeeds, a failure shows the error with RETRY, a taken username sends you back to that question), and the local `User` is created only at the tour choice (`completeLocal`), so the console isn't torn down before the welcome. Only Apple / Google / an existing account (and a resumed sign-in) have an account earlier; those rows are locked.
- **Existing email:** found at the email step when the project reveals it (`AuthSession.emailHasAccount`): the question becomes "Enter your password." (no confirmation) and signs in at once. If the project hides it (email-enumeration protection), the account creation at the end fails with `emailInUse`: the password question reopens with "THAT EMAIL ALREADY HAS AN ACCOUNT · ENTER ITS PASSWORD", everything typed is kept, and signing in goes straight on. A weak password or an invalid email reopens that question with the error.
- **Username availability before sign-in** needs `usernames/{handle}` to be readable by anyone (`allow get: if true`, still no list; `firestore.rules` and its test changed). **Deploy the rules before shipping this**, or the live check fails on the real project.
- **Code:** `SignupFlowModel` (state machine, no views, tested in `SignupFlowModelTests`), `SignupValidation` (rules and hint lines), `SignupConsoleView`, `SignupSky` (backdrop, progress bar), `SignupStarEngine` (pure star simulation), `StarBullet` (`Core/DesignSystem/Components`, also the paywall's bullets).
- **Sky theme only**, whatever the system appearance; the rest of the app follows the system until a setting says otherwise. The background starts flat `#1AA7FF` and cross-fades into the paywall's sky as `level` (answered / total, eased) rises; stars appear with the level and surge on each answer (`SignupSurge`: faster, streaks).
- **Config:** every number (typing speed, the step list and copy, validation ranges, star count/mix/motion, background, bar Stardust, bullet dance) is in `Resources/signup.config.json` (shared with Android; `SignupConfig.fallback` must equal it, a test checks). Remote Config key `signup_config` replaces it (`SignupConfigStore.applyRemote`). Gender gained `nonBinary` (Firestore stores the raw string).
- **Tuning:** DEBUG, long-press the ORE mark: `SignupDevPanel` (live sky, level scrubber, SURGE, sliders, Copy JSON).
- **Reduce Motion:** prompts appear whole, no surge, a still sky at the current level, still bullets. DEBUG `-signupInstant 1` (UI tests) shows prompts whole too.
- **Notifications** are asked for after the paywall closes (`ContentView`), not over it.
- UI tests: `SignInPage` / `OnboardingPage` in `OreUITests/Pages/AuthPages.swift` (`AX.signup.*`; the opening buttons keep `AX.auth.apple/google/useEmail`); `SignUpScreenshotsUITests` saves every state.

## Checking a screen against its Claude Design file (how the sign-up and paywall were matched)

Don't eyeball it: measure. The recipe (scripts lived in the session scratchpad; rebuild them in minutes):
1. **Render the design's own markup** (the inline styles in the `.dc.html`, filled for one state) as a static page at the simulator's size (402 × 874) with the bundled fonts, served from `python3 -m http.server`, and screenshot it with headless Chrome (`--headless=new --force-device-scale-factor=3 --window-size=402,874 --screenshot=…`). Put the status bar's height at the simulator's safe-area top (62).
2. **Screenshot the app at 3×** from a UI test (`SignUpScreenshotsUITests` with `SIGNUP_SHOTS=<dir>`; `SIGNUP_NO_STARS=1` / DEBUG `-debugSignupNoStars 1` removes the stars, which the static design doesn't have). The test also saves `app.debugDescription` (every element's frame) next to each PNG.
3. **Compare ink bands**: find the rows where white text pixels (≥ 235) occur in both images and compare their tops/bottoms and left/right extents; compare element frames from the hierarchy with `getBoundingClientRect()` from the page. The sign-up states agree to within 1 pt, the paywall to 0.4 pt.
Things this found: SwiftUI's `lineSpacing` doesn't give CSS line boxes (use `cssLineHeight`, which on iOS 26 uses `.lineHeight(.exact)` plus a measured baseline correction), a CSS `border` takes space but a SwiftUI overlay doesn't, a CSS blur of N px is `blur(radius: N/2)` in SwiftUI, and docked blocks measured from the screen's bottom edge must subtract the safe area. XCUITest screenshots blank `SecureField` text (it does render on screen).

## Remote settings (change without a release)

`Core/Services/RemoteSettings.swift` reads **Firebase Remote Config** at launch (background; skipped under tests and the emulators), so a change made in the Firebase console reaches users on their next launch or two. Only the trial length (`supernova_trial_months`) is persisted between launches; the JSON overrides (Stardust, sign-up, transition, member) are held in memory and apply once the fetch finishes. Every remote JSON is validated (`isUsable`: finite numbers, sane ranges) and ignored if it fails, so a bad console value can't crash the app. Every value has an in-app default, so the app works offline and before the first fetch; a missing or invalid value is ignored.
- `supernova_trial_months` (number, 0–12, default **3**): the free trial, counted in calendar months from `appInstallDate` (`SupernovaTrial`). The paywall copy follows it ("START 3 MONTHS FREE"; 0 = no trial and the copy drops the free offer). This is the in-app trial only: the App Store's own introductory offer is set in App Store Connect and must be kept the same.
- `stardust_config` (JSON string; the old key `starfield_config` is still read for one release when this one is empty): replaces `stardust.config.json` (`StardustConfigStore.applyRemote`); invalid JSON is ignored.
- `signup_config` (JSON string): replaces `signup.config.json` for the sign-up console (`SignupConfigStore.applyRemote`).
- `supernova_transition_config` (JSON string): replaces `supernovaTransition.config.json` (`SupernovaTransitionConfigStore.applyRemote`).
- `supernova_member_config` (JSON string): replaces `supernovaMember.config.json` (`SupernovaMemberConfigStore.applyRemote`).
- Add a setting: a key + default in `RemoteSettings.start()`, a pure apply step in `RemoteSettings.apply`, a unit test. Android reads the same keys.

## Supernova member experience (card, page, transition)

Built from `Supernova Member Flow.dc.html`. For a member the More tab has no profile row, Supernova row, Accent row or Weekly-Recap Stardust card: the **membership card** (`SupernovaMemberCard`: the member's accent as Stardust, "SUPERNOVA\* MEMBER · YEARLY", initial tile, name, @username · program, MEMBER SINCE / RENEWS / MEMBERSHIP ›) takes the profile row's place, and no Stardust appears outside it. Tapping it opens the **membership page** (`SupernovaMemberPage`): full-page Stardust in the accent behind the scroll view, masked to the top 65 % and faded to charcoal (stops in the config), the "SUPERNOVA\*" wordmark, a glass card, sticky OVERVIEW · PERKS · ACCOUNT tabs.
- **Transition:** the same system as the free banner ⇄ paywall (`SupernovaTransition`, now with `Kind` `.paywall` / `.member`; `SupernovaTransitionHost` shows `SupernovaMemberPage` for `.member`). Differences: the card radius is 14, 4 content groups (header row, wordmark, card, tabs + content), 3 card text pieces (label + initial tile, name block, dates row), the flyer starts at the card's "\*" height over 44 (measured), and on close the Stardust morphs to the card's gradient (g0 → g1 at 80 %, diagonal, plus the veil, no glows; `MorphStyle.card`). Opened from anywhere else (a row, a deep link) it cross-fades.
- **Tabs:** OVERVIEW · PERKS · APPEARANCE · ACCOUNT. APPEARANCE holds the accent picker and **Stardust buttons** (`AccentStore.stardustSetting`, per account; `stardustEnabled` is true only for an active member): every button that is filled with the accent by default draws its fill through `AccentFill` (Core/DesignSystem/Components), which lays the `button` star-field variant over the accent colour. Use `.background { AccentFill() }` for a new filled accent button; outlined, text-only and destructive buttons never do. The switch and its hint use the proper name Stardust ("Adds Stardust to every blue button. May use a little more battery."); in user-facing text always write Stardust, capitalised.
- **Accent picker** (Appearance tab, `AccentPickerView`; the rules are pure in `AccentMath`, the numbers in the config's `picker` block): any colour. A swatch, an editable hex (live once six digits are valid, `#abc` accepted on commit, invalid reverts on blur), ADJUST opening HUE / SHADE / SATURATION strips (tap jumps, drag is relative, a finger 60 / 120 pt away scrubs at ¼ / 1/10 speed; − / + repeat while held and accelerate; moving the hue of a grey/black/white also lifts saturation and shade) and one row of 11 presets & recent. `AccentStore` holds the pick (`AccentPick`: h, s, l and the exact hex when it came from a preset or the field) and the row, per account on this device (`setAccount`, called from `RootView`); the page Stardust, the card Stardust and the app follow live (`StardustView` takes a new `palette` without remounting). The Stardust palette is derived from the colour: `[hsl(l−16), the exact hex, hsl(l+22)]`, special stops for very light / very dark colours, blob and veil from the hue. Text on Stardust is always white. When the page closes the colour goes to the front of the recent row. Sky (`#3DB8FF`) is Ore's own blue and is drawn with the catalogue colour. **Not done: syncing the pick and the row with the profile in the cloud** (it would need a field on the SwiftData `User`, the sync mapper/applier and a rules change); today it is local per account.
- **Appearance:** the page follows the system: charcoal / paper canvas, white / ink text, `MemberPageTheme`. The header, wordmark and glass card sit on the Stardust and are white in both. The Stardust is masked and fades into the canvas (stops in the config); it scrolls up with the page and leaves the plain canvas behind (the design keeps it fixed; changed on request).
- **Real data:** plan, price, renewal and "member since" come from StoreKit (`SupernovaService.memberSince`, `planWord`, `planPriceLabel`; Manage subscription and CANCEL MEMBERSHIP open the App Store's subscription page). The Overview numbers are `SupernovaImpact`: suggested weights used and PRs on a suggested weight are counted when a workout is finished (`SetEntry.usedSuggestion`), lagging muscles from the last four weeks' sets, weekly recaps from the weeks trained since membership began. They start at zero on a device, because nothing was counted before.
- **Config / DEBUG:** `Resources/supernovaMember.config.json` (palettes, page Stardust and mask, card, and the full transition numbers); Remote Config key `supernova_member_config`. DEBUG: `-devDataPlus 1 -debugStartTab 4 -debugTransition member-open:400` (or `member-close:300`) holds the transition; `-debugMemberTab 0|1|2|3` (Overview, Perks, Appearance, Account) picks the page tab; `-debugAccentAdjust 1` opens the sliders. A member / free switch for comparing the two is built only into DEBUG and `PREVIEW_TOOLS` builds (`PreviewMembership`, at the foot of More). Tests: `SupernovaMemberTests`, `AccentMathTests`, `AccentStoreTests`, `SupernovaMemberUITests` (`testAccountTabScreenshots` saves both appearances with `MEMBER_SHOTS=<dir>`, `MEMBER_NO_STARS=1` removes the stars for measuring).

## Supernova transition (banner ⇄ paywall)

Built from the Claude Design file `Supernova Transition Final.dc.html`. Tapping the free More tab's "GO SUPERNOVA*" banner grows it into the paywall while the gold asterisk flies from the banner to the end of the wordmark; TRAIN FREE reverses it. No spring, no overshoot.
- **Host:** `SupernovaTransitionHost` wraps the whole app shell in `ContentView` (a `fullScreenCover` can't do this). It pushes the shell back (scale 0.94, opacity 0.35, 44 pt corners), draws `SupernovaPaywallView(context: .more)` clipped to an animated rounded rect (`SupernovaMaskShape`), and the flyer (`SupernovaFlyer`: a 44 pt "*" scaled down to 18/44, never a small glyph scaled up) above everything.
- **One clock:** `SupernovaTransition` (state machine: closed → measuring → opening → open → closing → revealing → closed) owns the start time; `SupernovaTransitionMath` turns (phase, ms, pre-measured geometry) into the mask rect/radius, the six content groups' opacity and offset, the flyer, the Stardust's morph and the banner's text. Geometry is measured before starting: the banner (`SupernovaBanner` reports its frame and asterisk while at rest) and the wordmark's resting asterisk (measured while the content is still 14 pt low, which is subtracted). `CubicBezier` implements CSS curves; the More layer uses the same curves through `withAnimation(.timingCurve)`.
- **Close:** the paywall's `StardustView` draws the banner's own background (gradient from the rect's corner to 40 % of its height, the two glows, the veil) over the paywall's, inside the shrinking rect, at alpha `progress^2.2`, under the particles, so the last frame is the banner and the Stardust never freezes (`\.stardustMorph`). At 590 ms the paywall and flyer go, the banner's asterisk returns and its text comes back staggered (`SupernovaWordmark(nameOpacity:nameOffsetY:asteriskHidden:)`).
- **Rules:** the asterisk is never faded, only swapped in one frame at the same size and spot; taps are ignored while animating (`acceptsInput`); Reduce Motion, or opening from a row rather than the banner: a 200 ms cross-fade, no flyer.
- **Config:** `Resources/supernovaTransition.config.json` (all durations, curves, 0.94 / 0.35, offsets 14 / 10, fades 520 / 180 / 120, stagger 90, start 380, exponent 2.2, flyer 44 and 18/44); `SupernovaTransitionConfig.fallback` must equal it; Remote Config key `supernova_transition_config`.
- DEBUG: `-devDataPlus 0 -debugStartTab 4 -debugTransition open:400` (or `close:300`) holds the transition at that many ms for screenshots. Tests: `SupernovaTransitionTests` (maths, controller), `SupernovaTransitionUITests` (the real animation, twice).

## Body map (front/back figures, heat and member Stardust)

Built from `Body Map Batch 3 Grey.dc.html` and the artwork `body-front.svg` / `body-back.svg` (1640 × 2360), stored compact in `Resources/bodymap.geometry.json` (outline, muscles by id, ink). `Core/BodyMap/`: `BodyFigureView` (three stacked layers: base fill, member Stardust clipped per muscle, ink on top; free users get no star layer), `BodyMapView` (labelled pair, Body tab), `BodyMapPair` (summary, share card, feed, friend profile), `BodyStardustEngine` (pure star simulation), `BodyMapGeometry` (path parser, per-muscle area and point pools from a coverage bitmap), `BodyMapLevels` (muscle group / `BodyHeat.Intensities` → artwork ids). Heat = the accent at (25 + v·75) % over the muscle base, hardest muscle first (150 ms + rank·70 ms, 650 ms ease); a member's heat uses **their chosen accent** (`accentHex`), free users Ore's blue. Stardust follows the poster's membership, not the viewer's. Stars pause off-screen, in the background, in Low Power Mode and with Reduce Motion (one still frame). Every number is in `Resources/bodymap.config.json` (Remote Config `bodymap_config`; `BodyMapConfig.fallback` must equal it). DEBUG: long-press the Body tab figures for the slider panel and the PUSH/PULL/FULL BODY/LEGS samples; `-debugBodyMapPreset 0-3 -debugBodyMapMember 0|1`. Tests: `BodyMapFigureTests`. `BodyHeat` (OreShared) remains only for widgets.

## Posts (feed post, full workout, composer, edit, share, challenge)

Built from `Ore Feed Post Final.dc.html` (project 1b1d68d9…). Every number is in `Resources/social.config.json` (`SocialConfig`, Remote Config-ready; the brief's `social.config.ts` is this JSON on iOS).
- **Feed card** `FeedPostCard` (`Features/Social/Feed/`): header, "Trained with", paging carousel (photo, body map), song row, title + stats, 3-row exercise preview, caption, like/comment. Your own post looks like a friend's; only the ··· popover differs (`PostMenuPopover`, never a sheet). Hide/Mute are local (`SocialViewModel.hide/mute`).
- **Likes:** double-tap on either slide (`BurstController`, `StarBurstEngine`: eight patterns, cycled per tap, stars only, every star ends at opacity 0) draws the big heart where the finger landed; double-tap never unlikes. The like button pops and throws a small ring; unlike has no animation.
- **Song:** `PostSong` (Apple Music via `AppleMusicSearch`/MusicKit; Spotify is link-out only), one shared `PostSongPlayer` (pause keeps position, another post pauses this one, 0:30 resets), `SongLevelMeter` per the spec. Nothing autoplays. Photos go to Storage (`PostPhotoStore`, `firebase/storage.rules`).
- **Body map:** `BodyMapSwapView` shows a side only if a muscle on it was trained (`BodyMapLevels.trainedSides`); the swap tile replays the load animation, a tap on the figure never does.
- **Full workout** `FeedSessionSheet` + `WorkoutDocumentExercises`: document style, no cards; ··· (Edit/Delete) only on your own.
- **Composer:** `WorkoutCompletionView` = summary (`WorkoutSummaryPage`, §3a) then composer (`PostComposerPage`, §3c); shrink-into-place if any of the map is on screen, otherwise the summary slides off left. Drafts: `PostDraftStore`, posted from History (`WorkoutDetailView`).
- **Edit post** `EditPostView`/`EditPostModel`: recalculates stats, PRs and body map on SAVE and writes back to the local workout; rules allow only the author (`firestore.rules`, tested).
- **Share outside Ore** `ShareOutsideSheet`: 9:16, 6 s seamless loop MP4 (`PostShareCardView` is a pure function of time; `ShareVideoExporter`), rendered once per card.
- **Challenge a friend** `DirectChallengeSheet`/`DirectChallengeModel` from a friend's profile. **Not built server-side:** scoring for several lifts or a PR target (the function scores `heaviestLift` on the first lift only).
- Tests: `FeedPostTests`, `PostSystemTests`; rules tests in `firebase/rules-tests`. Needs the MusicKit capability on the App ID before Apple Music search works on device.

## Progression suggestions (Supernova)

`ProgressionRule` (Features/Workout/Services) is the pure double-progression rule; `WorkoutViewModel.ghostText` applies it to the next row. Thresholds live on `User.progressionThresholds` (keyed by `Exercise.normalisedName`), increment in `User.progressionIncrementKg` (kg), master toggle is the `smartWeightSuggestions` UserDefaults key (default on). Warm-up/drop/rest-pause/failure sets are ignored. Synced as `users/{uid}.progression`.

## Dev data (fake data for testing)

DEBUG-only seeder in `Ore/DevData/` (compiled out of Release) — the iOS counterpart of `manage.py createdevdata`.

```bash
bin/createdevdata.sh                       # build, clean-install on the simulator, seed, launch
bin/createdevdata.sh --scenario lapsed     # busy (default) | lapsed (no sessions in 12 days) | new-user (empty states)
bin/createdevdata.sh --weeks 24 --seed 7 --units lb --plus --draft --help
```

It works through launch arguments (`-createDevData 1 -devDataReset 1 -devDataScenario … -devDataWeeks … -devDataSeed … -devDataUnits … -devDataPlus 1 -devDataDraft 1 -devDataSocialFixtures 1`), so the same flags can be added in the Xcode scheme, `simctl launch`, or XCUITest. Same seed → identical data. Dataset: user "Dev Lifter", PPL split with days populated, Home/Commercial equipment profiles, Push/Pull/Leg templates with real exercise ids, ~5 sessions/week with progressive overload, warm-ups, a deload week, fresh PRs, a 60-day bodyweight log, and (for Firestore-backed screens that can't be seeded locally) the built-in demo friends/feed/challenges via `DevFlags.socialFixtures`. Add new models to `DevDataFactory` / `DevDataService.reset` when you add them to the schema. Demo/fixture data is never reachable in Release.

**Real-project guard:** `-createDevData`, `-devDataReset`, `-debugEmail/-debugPassword` and `-debugFreshSession` are ignored (with a log line) unless `-useFirebaseEmulator 1` is also set (`DevFlags.mayRunDevDataFlags`), so a manual launch can never write fake data to the real Firebase project. `bin/createdevdata.sh` and the UI tests pass it.

**Auto sign-in (DEBUG):** `-debugEmail <e> -debugPassword <p> -debugAutoOnboard 1` signs in (or signs up) and completes onboarding with no taps (`DevData/DevDataAutoAccount.swift`); combine with `-createDevData 1 -devDataReset 1` to push a seeded history through sync. Add `-useFirebaseEmulator 1` to stay off the real project. Build with ad-hoc signing (`CODE_SIGN_IDENTITY=-`) or Firebase Auth fails with a keychain error.

## Journey tests (real-user scenarios at the logic level)

`OreTests/Journeys/` drives the same code the screens use (WorkoutViewModel, SwiftData, the pure stats types `HomeStats` / `BodyMapStats` / `WeeklyRecapStats` / `HistoryStats` / `ExerciseProgress`, `WidgetDataService.buildSnapshot`, `WorkoutPredictor`, `FeedPostBuilder`, `SyncDevice`) with an in-memory store and a clock the test moves. Screen maths lives in those stats types (the views just call them), so keep new view maths there, not inline.

- To add a scenario: `let sim = try UserSim(...)` (`JourneyKit.swift`: unit, Monday/Sunday week start, time zone, split), then `sim.startSession(template:)` / `log` / `warmup` / `finish` / `skipToDay(n)` / `restDays(n)`, and read what the user sees via `sim.home()`, `body(weekOffset:day:)`, `recap(weeksBack:)`, `history()`, `progress(of:)`, `widget()`, `prediction()`, `postPayload(of:)`. `sim.ledger` records every set typed, independently of SwiftData: compute expected numbers from it (or hand-derive literals), never by calling the function under test again. The clock only goes forward for sessions; moving it back shows the world as it was (screens only see workouts started by `now`).
- `MarcusJourney.shared` is a 16-week lifter built once and read by the OverTime suite; `MarcusJourney(sim:weeks:)` reuses the plan on any sim (the sync suite).
- Known app bugs are written as the CORRECT behaviour inside `withKnownIssue("<what is wrong / audit ref>", isIntermittent: true)`; remove the wrapper when the bug is fixed. Keep the injectable parameters (`now:`, `calendar:`, `widgetUpdater`) defaulted so app behaviour is unchanged.
- Run only these: `xcodebuild test ... -only-testing:OreTests/OverTimeJourneyTests` (suites: DayOne, DraftAndCrash, OverTime, EditingHistory, PatternDetection, Units, StreakAndCalendar, SettingsAndOnboarding, SyncJourney, SocialPosting).

## Known Gaps (from spec)

See `docs/pulse-pump-spec.md` §"Known Gaps & Backlog" for the full list. High-priority items:
- Template share-via-link (`ore://template?data=<base64>`, old `pulsepump://` links still open) — URL handling exists but Firestore backend not wired
- Challenges not gated behind Supernova check
- Friend profile tap destination missing
- Post-workout share card missing body map silhouette
- Widget extension shows streak only — missing predicted workout and weekly volume widgets
- Free trial is an in-app date (`TrialAnchor`: start and latest-seen date kept in the Keychain so a reinstall or a clock set back doesn't extend it; `UserDefaults` is the fallback), not the StoreKit introductory offer (length is remote: see "Remote settings"). It still needs the App Store's own offer to match, and it is client-side only.
- Entitlements are refreshed by one app-lifetime monitor (`SupernovaService.startAppMonitor()`, from `OreApp`), not only by the screens that show Supernova.
- Sign-up/profile rules: `profiles/{uid}.username` must be a handle the same user owns (`ownsHandle`, `getAfter`), and a handle is only claimed in the same batch as the profile that uses it. `usernames/{handle}` is still readable by anyone (the sign-up check) and so reveals a handle's uid; making that private needs the availability check to move behind a callable function.
- Deleting a Sign in with Apple account asks for a fresh Apple sign-in and revokes the token first (`AuthProviding.revokeAppleToken`).

## Changelog

- The particle system is named **Stardust** everywhere (code, config, copy). It was StarField / "glitter" before: the saved per-account setting moved from `glitterButtons` to `stardustEnabled` (read once and rewritten, `AccentStore`), and the Remote Config key `starfield_config` is read as a fallback for one release. User-facing text never says "glitter", "starfield" or "star field".
