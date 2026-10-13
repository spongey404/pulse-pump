# Pulse Pump — Build Specification

You are building **Pulse Pump**, an iOS workout logging app. Read this entire document before writing any code. This is your single source of truth for what to build and how to build it.

---

## Project Setup

Create an Xcode project called `PulsePump` targeting iOS 17.0+, built natively in **Swift** with **SwiftUI**. Use Swift Package Manager for dependency management. Do not use Storyboards or Interface Builder.

Create a `CLAUDE.md` file at the project root and keep it updated as the architecture evolves. It should document the file structure, conventions, and any decisions made during development.

### Git Workflow

Manage version control autonomously throughout development. Do not ask for permission to commit or branch.

- Create feature branches for each module (e.g., `feature/workout-logging`, `feature/body-map`, `feature/social-feed`)
- Commit frequently with descriptive messages using conventional commit format (`feat:`, `fix:`, `refactor:`, `docs:`)
- Keep commits atomic — one logical change per commit

Branch structure:
- `main` — stable, release-ready code
- `develop` — integration branch for features in progress
- `feature/*` — individual feature branches
- `fix/*` — bug fix branches

### Build Verification

After making changes, build the project to verify your work compiles. Use XcodeBuildMCP or `xcodebuild` commands. Fix any compiler errors before committing. Handle `.pbxproj` modifications carefully.

---

## Design Rules

Apply these rules to every screen and component you build:

- Minimal and clean aesthetic inspired by Apple Health. No visual clutter.
- Support both light and dark mode via a user toggle.
- Use a unified Pulse brand color palette. Pump has its own unique primary accent color within that palette.
- No haptic feedback anywhere in the app.
- No exercise demo videos or GIFs.
- PR indicators must be subtle — a small highlight on the number only. No confetti, no animations, no badges, no gamification.
- No ads anywhere, ever.
- No emojis in the UI.

---

## App Architecture

### Tab Bar (5 tabs, left to right)

| Position | Tab | What it contains |
|----------|-----|-----------------|
| 1 | **Programs** | Workout routines, templates, exercise library, create/add exercises |
| 2 | **Social** | Activity feed, friends list, challenges |
| 3 (center) | **Home** | Start workout button, quick analytics, configurable widgets, global search |
| 4 | **Body Map** | Interactive body model, exercise browser per muscle, charts/analytics |
| 5 | **More** | History, Profile, Settings, Equipment Profiles, Tutorial/Help, Pulse+ subscription |

Home must be the center tab for thumb accessibility.

---

## Build Order

Build the app in this order. Complete each phase before moving to the next. Commit and branch appropriately at each phase.

### Phase 1: Core Data Models & Local Storage

Build all data models first. The app is local-first — all data lives on-device by default. Design the models so cloud sync can be added later as a Pulse+ feature.

**Models to create:**

- `User` — name, weight, height, age, gender, unit preference (kg/lbs), experience level (beginner/experienced), selected split, avatar, username
- `Exercise` — name, primary muscle groups, secondary muscle groups, equipment type, movement pattern (push/pull/hinge/squat), exercise type (weighted/bodyweight/time-based/distance-based), isCustom flag, isApproved flag (for community submissions)
- `WorkoutTemplate` — name, ordered list of exercises with sets, reps, and optional RIR targets. No target weights in V1.
- `Workout` — date, duration, exercises performed, associated template (optional), notes, calorie burn estimate, isDraft flag, isDeload flag (Pulse+ only)
- `ExerciseLog` — exercise reference, ordered sets, notes for this exercise in this workout
- `SetLog` — weight, reps, RIR (optional), set type (standard/superset/dropset/restpause/AMRAP), side (left/right/both for unilateral), timestamp
- `Split` — type (preset name or custom), days and assigned workout types
- `EquipmentProfile` — name (e.g., "Home Gym", "Commercial Gym"), available equipment list, available plate sizes, bar types with weights
- `UserProfile` — username, avatar, stats (total workouts, streak)
- `Challenge` — creator, participants, rules, metric, win condition, start/end dates, leaderboard data

### Phase 2: Onboarding Flow

Build the onboarding screens. Three authentication methods: Apple Sign In, Google Sign In, and email + password.

**Data to collect during setup (in this order):**
1. Name
2. Weight
3. Height
4. Age
5. Gender
6. Unit preference (kg or lbs — can be changed later in Settings)
7. Experience level — beginner or experienced
8. Training split selection:
   - Presets: PPL, Upper/Lower, Full Body, Bro Split, and other common splits
   - Custom: user defines their own
   - No split: for users who train without a fixed pattern

**After setup:**
- Ask "Would you like a quick tutorial?" (yes/no)
- Beginner → guided walkthrough explaining core features step by step
- Experienced → quick setup, minimal screens, dropped into the app fast
- Hints are available throughout the app at all times (tap to reveal). Experienced users who skipped the tutorial can use these.
- Tutorial is always re-accessible from Settings.

### Phase 3: Exercise Library

Build the exercise library with a curated set of pre-built exercises. Each exercise must have: name, primary muscle group(s), secondary muscle group(s), equipment type, movement pattern, and exercise type.

**Search and filtering:** Users search by name and apply multiple simultaneous filters: muscle group, equipment type, movement pattern.

**Custom exercises:** Users create their own with name, muscle groups (primary + secondary), and equipment type. Users can submit custom exercises to the community library. Submissions enter a pending queue visible to the submitter but require manual approval before appearing in the public library.

**Exercise detail screen** (when tapping an exercise): trend graph over time, all-time PR (weight, reps), estimated 1RM, volume PRs, recent session history, which templates include this exercise, and notes from previous sessions.

### Phase 4: Workout Logging (Core Feature)

This is the most important feature. Build it to be fast and frictionless.

**Smart workout prediction:** The app learns the user's recurring training pattern from their split and history. When the user taps "Start Workout," suggest today's predicted session (e.g., "Start Push Day?"). User confirms with one tap or declines to choose manually. For users following consistent rotations (full body every other day, upper/lower/rest, PPL repeat), detect the pattern automatically.

**Per-set data capture:**
- Weight (in user's chosen unit — kg or lbs, switchable anytime)
- Reps
- RIR (Reps in Reserve) — optional field
- Rest timer (see below)

**Ghost text:** When logging a repeat exercise, display the previous session's numbers as grey ghost text beside the empty input fields. This is passive — users type over it. Do NOT auto-fill.

**Exercise types supported:**
- Standard weighted (barbell, dumbbell, cable, machine)
- Bodyweight (with optional added weight for weighted dips, pull-ups, etc.)
- Time-based (planks, wall sits — tracked in seconds/minutes)
- Distance-based (farmer carries — tracked in meters/feet)
- Unilateral — each side (left/right) logged separately

**Advanced set types:** Supersets, drop sets, rest-pause, AMRAP, and any other commonly used set type identified during development.

**Rest timer:**
- Three behavior modes (user picks in Settings): auto-start after logging a set, manual start only, or auto-start with dismiss option
- Default rest times: compound exercises get a longer default (e.g., 3 min), isolation exercises shorter (e.g., 90 sec). Users can override per-exercise.
- Alert options (user picks): sound, vibration, both, or silent visual only
- Display on iOS lock screen via Live Activity and in Dynamic Island on supported devices

**Single active workout rule:** Only one workout can be in progress at a time. If a draft exists and the user starts a new workout, the draft is permanently deleted before the new session begins. There is no multi-workout or queued-session concept.

**Draft / resume behaviour:** If the user leaves an active workout without finishing (app close, crash, or explicit cancel), it is auto-saved as a draft. On returning to the Home tab, the Start Workout button transforms into a "Resume Workout" button showing the draft name and how long ago it was started. A secondary "Start New Workout" link below the button lets the user discard the draft and begin fresh — this requires a confirmation dialog and permanently deletes the draft.

**Live workout session UX:**
- Minimal duration timer in the header
- Drag handle to reorder exercises mid-workout
- Swipe to delete sets
- Add exercises on the fly
- Exercise substitution: free users browse and pick any replacement manually. Pulse+ users get smart alternative suggestions filtered by same muscle group + equipment from their equipment profile.
- Notes per exercise and per workout
- Calorie burn estimate displayed live, updating as sets are logged
- Phone handles screen sleep normally — do not force screen awake
- If user accidentally closes the app, auto-save the workout as a draft
- Cancel workout requires a warning confirmation dialog before discarding

**Post-workout completion screen:**
Default display: workout duration, estimated calories burned, body map showing muscles worked, PRs hit (subtle highlight), and number of exercises improved on (e.g., "Improved on 4/6 exercises"). Users can customize what appears here.

Sharing: auto-post to social feed by default (user can disable in Settings). Option to share externally via native iOS share sheet (Instagram Stories, iMessage, etc.). All share cards include subtle Pulse branding (small watermark/logo).

**Editing:** Users can edit any past workout at any time. No time restriction.

### Phase 5: Programs & Templates

**Template structure:** Exercises, sets/reps per exercise, and optional RIR targets. No target weights or percentage-based programming in V1. Users fill in their own weights.

**Creating programs:** Both blank canvas (build from scratch) and pre-made templates for common programs (PPL, Upper/Lower, Full Body, etc.). All templates are free — no paywall.

**Sharing:** Users share templates via a link that opens in Pulse Pump. Recipients must have Pump installed.

Multi-week progression is NOT in V1 — note for future.

### Phase 6: Body Map Tab

**Interactive body model:** A customizable human body with individually separated, tappable muscle groups. Free users get basic customization (skin tone, body type). Pulse+ users get advanced customization options (specifics TBD — design placeholders for now).

**Heatmap:** Muscle groups are color-coded. Two toggleable views:
- Volume view: intensity based on how many sets (more = brighter). Primary muscles get full intensity, secondary muscles get reduced intensity.
- Recency view: intensity based on when last trained (today = bright, days ago = fading). Same primary/secondary distinction.

Color scheme is multi-colored, user-selectable. Include a legend mapping each color to its meaning.

**Neglected muscle group nudges (Pulse+ only):** Quiet badge indicator (not a push notification) when a muscle group hasn't been trained in a while.

**Detailed muscle sub-regions (Pulse+ only):** Free users see general muscle groups on the body map (e.g., "Chest", "Triceps"). Pulse+ users see anatomical sub-regions:
- Large muscle groups (chest, quads, hamstrings, glutes, abs) get separate tappable sub-region zones on the silhouette (e.g., upper/lower chest, rectus femoris/vastus lateralis/vastus medialis).
- Small muscle groups (biceps, triceps, forearms, traps, calves) keep their single zone on the map, but tapping opens a detail sheet with sub-region breakdown (e.g., long/lateral/medial head for triceps).
- Sub-region tagging on exercises is available to ALL users when creating/editing exercises (optional — leaving empty means "general/all").
- All 84 seeded exercises are pre-populated with sub-region tags.
- Free users who don't want to see the Pulse+ upsell can enable "Simple Body Map" in Settings → Appearance.

**Tapping a muscle group shows:**
- Trend graphs at the top
- Exercise list below: colored if the user has done them before, greyed out and at the bottom if they haven't

**Charts & analytics sub-section** (within this tab — navigation method between body map and charts is TBD, build a placeholder toggle for now and note it needs UX testing. Options: swipe, toggle buttons, or iOS segmented control):

Analytics levels:
- Per exercise: individual lift progress over time
- Per muscle group: weekly volume
- Per workout: how many exercises improved on (NOT total tonnage — nobody uses that)

Free analytics: exercise trends, PR history, workout streak/consistency, per-workout improvement score.

Pulse+ analytics: muscle group balance analysis (push vs pull ratio), imbalance detection with quiet badge nudges, detailed analytics with tips.

Visualization: quick glance = numbers with up/down arrows and weekly/monthly percentages (stock-broker style, shown on Home screen). Deep dive = line charts and bar charts (in this analytics sub-section).

All analytics views must support weekly, monthly, and custom date ranges.

### Phase 7: Home Screen

Build the Home screen with these elements:

- **Start Workout button:** Large, prominent, first thing visible. Integrates with smart workout prediction.
- **Quick analytics:** Stock-broker style up/down arrows with weekly and monthly percentage changes.
- **Configurable widgets:** Users choose what they see, can reorder and toggle on/off.

Default widget order (before customization):
1. Predicted workout + quick start button (always pinned at top)
2. Body model heatmap + stats at a glance
3. Recent workouts + streak

**Global search:** Single search bar returning results across exercises, workout history, and friends (by username). Results grouped by category. Spotlight-style UX.

### Phase 8: Workout History

Lives inside the More tab.

- Toggle between calendar view (tap a date to see that workout) and list view (scrollable, newest first)
- Any past workout can be edited at any time
- Deleting a workout requires a confirmation dialog
- Users can duplicate any past workout to start a new session from it

### Phase 9: Social Features

**User profiles:** Username, avatar, stats (total workouts, streak). Friends only — no public profiles.

**Finding friends:** Search by username, find via phone contacts, shareable invite link.

**Activity feed (free):** Chronological. Each post shows: an interactive 3D body model with worked muscles highlighted (friends can orbit, zoom, and pan to inspect what was trained), number of exercises improved on, PRs hit. Tapping into a post reveals full workout details (exercises, sets, reps, weights) but NOT the user's personal notes. The detail sheet also shows the full interactive 3D model. Feed posts are generated from the post-workout summary. Auto-post is on by default (configurable in Settings).

**Reactions:** Like and comments only.

**Template sharing (free):** Via link that opens in Pump.

**Challenges (Pulse+ only):** Any Pulse+ user can create. Anyone in a challenge can invite others. Rules are fully creator-defined. Support both pre-built challenge types (e.g., "most bench volume this week") and fully custom. Real-time leaderboard.

**Notifications:** Fully configurable — user decides exactly what triggers notifications. Options: social activity (likes, comments, friend requests), challenge updates, workout reminders (configurable triggers — can be based on split schedule, custom times, etc.).

### Phase 10: Utility Features

**Plate calculator:** Shows exactly which plates to load per side for a given weight. Users configure available plate sizes (1.25, 2.5, 5, 10, 15, 20, 25 kg etc.). Multiple bar types supported (Olympic, EZ curl, trap bar) with configurable weights. Default bar: 20kg/45lb.

**Warmup set generator (free):** Auto-generates warmup ramp (e.g., bar → 60 → 80 → 90 → working set 100kg). Users can customize their warmup pattern.

**Smart weight suggestions (Pulse+ only, double progression):** Per exercise the user can set an optional rep threshold (chip on the exercise card; off by default). It applies to the highest working weight logged so far in the session: when the latest completed set at that weight reaches the threshold, the next set row shows a ghost (grey, not auto-filled) weight of that weight plus the user's increment (Settings; stored in kg; kg steps 1/1.25/2.5/5, lb steps 2.5/5/10; default 2.5 kg / 5 lb), so only reps need typing. If the threshold is missed, the usual previous-session ghost remains. Warm-up, drop, rest-pause and failure sets are ignored entirely; unilateral sets need both sides at the threshold. Thresholds are keyed by normalised exercise name, stored on the User and synced (`progression`). Master toggle in Settings.

**Equipment profiles:** Users configure available equipment. App remembers and uses it for substitution suggestions. Supports multiple profiles (e.g., "Home Gym" vs "Commercial Gym").

**Deload marking (Pulse+ only):** Users manually mark a week as a deload week.

### Phase 11: Shareable Summary Cards

Cards adapt based on the time period shared:
- Post-workout: exercises, PRs, duration, body map, improvement count
- Weekly recap: trends, highlights, streak
- Monthly recap: broader trends, PRs, consistency
- Milestone cards: triggered by new PRs (subtle, not gamified)

All cards have subtle Pulse branding (small watermark/logo). Shareable to social feed and externally via native iOS share sheet.

### Phase 12: Settings

Build all settings inside the More tab:

- Account management (name, email, password)
- Unit preference (kg/lbs toggle — conversion applies app-wide)
- Theme (light/dark toggle)
- Rest timer behavior (auto-start / manual / auto-start with dismiss)
- Rest timer alert type (sound / vibration / both / silent)
- Default rest times (compound vs isolation, per-exercise overrides)
- Smart suggestions toggle (on/off) — Pulse+ only
- Post-workout auto-share toggle (on/off)
- Post-workout summary customization
- Notification preferences (granular control over every notification type)
- Equipment profiles management
- Split configuration
- Pulse+ subscription management
- Tutorial / Help (re-watch onboarding)

### Phase 13: Calorie Burn & Ecosystem Integration

**Free tier:** Basic calorie burn estimate based on exercise type and volume only.

**Pulse+ tier:** More personalized formula factoring in bodyweight, height, age, gender. Exact formula TBD — build the architecture so different formulas can be swapped in. Note: the difference between free and paid estimates may be marginal; this needs research.

Calorie burn is displayed live during workouts and on the post-workout summary. Data is sent to Pulse Fuel automatically (build the data export interface; Fuel integration will be connected later).

### Phase 14: Pulse+ Subscription System

Build the paywall and subscription management.

**Pricing (for reference — integrate with StoreKit):**

| Plan | 1 App | 2 Apps | All 3 Apps |
|------|-------|--------|------------|
| Monthly | $5 | $8 | $9 |
| Yearly | $45 | ~$76 | ~$86 |

Pulse+ is a unified subscription across the Pulse ecosystem. Users choose how many apps to unlock.

**Free trial:** 14 days of all Pulse+ features for new users.

**Upselling:** Subtle inline banners (e.g., blurred analytics with "Unlock with Pulse+" overlay) AND a dedicated Pulse+ benefits page in the More tab.

**Pulse+ features in Pump (gate these behind the subscription):**
1. Cloud sync across devices
2. Smart weight suggestions (subtle, toggleable)
3. Advanced exercise substitutions (smart alternatives based on muscle group + equipment profile)
4. Challenges / competitions with friends
5. Personalized calorie burn formula
6. Muscle group balance + imbalance detection
7. Deload week marking + tracking
8. Detailed analytics + tips
9. Advanced body model customization
10. Detailed muscle sub-regions on body map (anatomical breakdown for large + small muscle groups)
11. Additional home screen widget options

**Everything else is free.** Do not paywall: core logging, rest timer, exercise library, all templates, template sharing, basic analytics (trends, PRs, improvement score, streaks), body model heatmap (basic customization), social feed/following/likes/comments, plate calculator, warmup generator, exercise substitution (manual), shareable cards, equipment profiles, workout reminders, smart prediction, ghost text, global search, data import, basic widgets, Live Activity/Dynamic Island.

### Phase 15: iOS Platform Features

**Widgets:** Free users get a basic set. Pulse+ users get additional options. Examples: next predicted workout, current streak, weekly volume.

**Live Activity & Dynamic Island:** Rest timer countdown on lock screen and Dynamic Island during active workouts.

**Data import:** Build import functionality for workout history from Strong, Hevy, and other major competitors.

**Offline support:** Workout logging works fully offline. Social features require internet. Data syncs when connection is restored (Pulse+ only).

---

## Post-V1 Improvements (Implemented)

These were built after the initial 15-phase spec was complete.

### UX Improvements

**Active Workout**
- Bottom search bar + floating `+` FAB (`WorkoutBottomBar`) so one hand can reach both without stretching
- Notes moved into the `⋯` menu ("Add Note" / "Edit Note"); last session's note shown read-only in the same menu
- Swipe left on an exercise card to delete it (title row is a swipeable List row)
- Exercise cards for barbell and EZ bar exercises show an inline plate calculator that updates live as weight is typed (`InlinePlateView`)

**Programs Tab**
- Templates displayed directly as cards — no separate nested Templates page
- New templates start from a preset picker sheet (blank, PPL, Upper/Lower, Full Body) opened by the `+` button
- Swipe left on a program card to delete; `⋯` menu on each card with Edit and Delete
- No `>` disclosure chevron on cards (uses `navigationDestination(item:)` instead of `NavigationLink`)
- Target reps are optional when creating or editing a program — sets always required, reps can be omitted and added later

**Home Screen**
- Start Workout button docked at bottom via `safeAreaInset` for one-handed thumb reach

**Body Map Tab**
- Front and back views separated into swipeable pages (`TabView(.page)` with dot indicators)
- Legend and nudges scroll below the pager

**Social Feed**
- Caption field on the post-workout completion screen; caption shown in feed posts
- `FeedBodyMapView` — compact front/back silhouette in feed posts and detail sheet, worked muscles highlighted with `pumpPrimary.opacity(0.55)`
- Feed cached for 5 minutes; cached items shown immediately on revisit; pull-to-refresh forces a network fetch

### Visual Polish

- `medal.fill` (yellow) used for all PR badges throughout the app (completion screen, feed, share cards, feed detail)
- `flame.fill` (orange) used for streak indicator
- Program card list rows have `listRowBackground(.clear)` — no gray border when swiping to delete

### Data & Logic

**Streak calculation** (`StreakCalculator` utility, single source of truth for all 4 call sites):
- Gap between workouts counts toward streak (workout day 1, next day 3 → streak = 3)
- Streak expires if last workout was more than 3 days ago

**SF Symbols on enums:**
- `MovementPattern.sfSymbol` — mapped for push, pull, hinge, squat, carry, rotation, isolation
- `EquipmentType.sfSymbol` — mapped for barbell, dumbbell, cable, machine, bodyweight, etc.
- `SetType.shortName` — compact labels (STD, WU, SS, DROP, RP, AMRAP, FAIL)

**MuscleSubRegion enum** — 35 anatomical sub-regions across all major muscle groups

**TemplateExercise.targetReps** — changed to `Int?`; nil means no target reps set

### Live Activity & Dynamic Island

- `WorkoutActivityAttributes.ContentState` extended with `restSecondsRemaining: Int`
- When rest timer is active: Dynamic Island compact trailing and expanded leading show rest countdown in red; lock screen banner shows "Rest" label in red
- When rest ends: automatically reverts to elapsed workout time
- `NSSupportsLiveActivities` and `NSSupportsLiveActivitiesFrequentUpdates` enabled in Info.plist

---

## Known Gaps & Backlog

These items have been audited against the codebase and are confirmed incomplete. Tackle them in priority order.

### High Priority (already in progress or blocked on design decisions)

**Programs & Templates (Phase 5)**
- Template share-via-link: use custom URL scheme `pulsepump://template?data=<base64encodedJSON>`. Serialize template name + exercises to JSON, base64-encode, embed in URL. Share sheet includes plain-text App Store fallback for recipients without the app. Handle the URL in the scene delegate to import and create a local SwiftData copy.

**Social (Phase 9)**
- Push notifications: remote social notifications (likes, comments, friend requests) require Firebase Cloud Functions + FCM — not yet set up. Local workout reminder notifications can be wired up independently. Mark as deferred until FCM is configured.
- Challenges not gated behind Pulse+ — add subscription check to challenge creation.
- No friend profile tap destination — friend list items go nowhere. Profile should show: username, avatar, stats (total workouts, streak), latest body heatmap, current split, and past workouts. Users control visibility via a privacy toggle: private mode shows only username, avatar, and streak to others.

**Share Cards (Phase 11)**
- Post-workout card missing body map silhouette — embed `FeedBodyMapView`.
- Weekly recap card: triggered every Monday via a local notification, and manually accessible from History/More. Shows: workouts last week, volume vs previous week (up/down), PRs hit, muscles worked.
- Monthly recap card: triggered automatically the first time the app is opened after a calendar month rolls over (modal). Also manually accessible from History/More. Shows: total workouts, total sets, PRs hit, most-trained muscles (mini heatmap), consistency % (workout days / days in month), longest streak that month.
- Milestone cards: shown on the workout completion screen when one or more PRs were hit that session.

### Medium Priority

**Body Map (Phase 6)**
- `FinalBaseMesh.obj` is a silent runtime dependency — add a graceful fallback if the file is missing.
- No free-tier skin tone / body type customization (spec says free users get basic customization options).
- Muscle detail sheet has no trend graphs — spec says trend graphs appear at the top of the detail sheet.

**Onboarding (Phase 2)**
- No differentiated beginner/experienced tutorial flow — the yes/no prompt exists but both paths go to the same place.
- Contextual hints exist in `HintSystem.swift` but are not wired to any screens.

**Exercise Library (Phase 3)**
- Community exercise submissions only set a local `isCustom` flag — there is no backend write to a pending-review queue. Requires a Firestore collection for submitted exercises.

**Home Screen (Phase 7)**
- The predicted workout pinned widget card is missing from the configurable widget stack on the Home tab.
- Workout results in global search are not tappable (no navigation to workout detail).

### Lower Priority

**Settings (Phase 12)**
- No email/password change flow in account management.
- Terms of Service and Privacy Policy are placeholder links with no destinations.

**Utilities (Phase 10)**
- Equipment profiles are stored but not used to filter exercise substitution suggestions during a workout.

**iOS Platform (Phase 15)**
- Widget extension only shows streak — missing "next predicted workout" and "weekly volume" widgets (free and Pulse+ tiers).
- No network reachability handling — social writes (likes, comments, feed posts) fail silently when offline. Need an offline queue or reachability guard.

**Pulse+ (Phase 14)**
- Free trial uses `UserDefaults` install date instead of StoreKit's native introductory offer — resets on reinstall and is not tied to the App Store account.
- Multi-app pricing tiers (1 app / 2 apps / all 3 apps) are not represented in the StoreKit products or paywall UI.

**Calorie / Ecosystem (Phase 13)**
- No Pulse Fuel integration stub — spec asks for at minimum a protocol/interface placeholder so the hook point is defined even before Fuel is built.

---

## Things NOT to Build in V1

Do not build any of these. They are noted for future versions:

- Apple Watch companion app
- Apple Health integration (read/write) — flag this as important to revisit
- Multi-week progression / periodization in templates
- Percentage-based programming (% of 1RM)
- Data export (CSV, JSON, PDF)
- iPad support
- Accessibility features (VoiceOver, font scaling, contrast) — flag as important
- Landscape mode
- Auto-progression (auto-increase weights week to week)

---

## Open Questions

When you encounter these during development, make your best judgment call, leave a `// TODO:` comment, and note the decision in `CLAUDE.md`:

1. Exact body model customization options (free vs paid tiers)
2. Color scheme presets for the body map heatmap
3. Specific calorie burn formula details (free vs Pulse+)
4. Body map tab sub-navigation pattern (swipe vs toggle vs segmented control — build one, note alternatives)
5. Community exercise submission review tooling
6. Exact share card visual designs per time period
7. Specific widget designs and options (free vs paid)
8. Default rest timer exact durations (compound vs isolation)
