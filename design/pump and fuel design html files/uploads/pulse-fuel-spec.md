# Pulse Fuel — Build Specification

You are building **Pulse Fuel**, an iOS nutrition and calorie tracker. Read this entire document before writing any code. This is your single source of truth for what to build and how to build it.

---

## Project Setup

Create an Xcode project called `PulseFuel` targeting iOS 17.0+, built natively in **Swift** with **SwiftUI**. Use Swift Package Manager for dependency management. Do not use Storyboards or Interface Builder.

Create a `CLAUDE.md` file at the project root and keep it updated as the architecture evolves. It should document the file structure, conventions, and any decisions made during development.

### Backend

**Supabase** is the backend for all Pulse apps. It is chosen over Firebase for three reasons: (1) relational data (PostgreSQL) fits nutrition data far better than NoSQL — users have logs, logs have meals, meals reference foods, and analytics need SQL-shaped queries; (2) flat-rate pricing is predictable as the user base grows instead of scaling linearly with every read; (3) Android support is built in from Day 1, since Pulse will expand to Android after the iOS ecosystem ships.

Set up a single Supabase project shared across all Pulse apps (Pump, Stride, Fuel). Shared auth means a user signs in once and is recognised by every app in the ecosystem. Shared backend means ecosystem features (Pump writes workout calories, Fuel reads them) work through a single database instead of a custom API layer.

### Git Workflow

Manage version control autonomously throughout development. Do not ask for permission to commit or branch.

- Create feature branches for each module (e.g., `feature/food-logging`, `feature/adaptive-tdee`, `feature/plan-ahead`)
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
- Use a unified Pulse brand color palette. Fuel has its own unique primary accent color within that palette.
- No haptic feedback anywhere in the app.
- No shaming copy. Never "you went over!", "you failed to hit your goal", or any language that frames the user as falling short. Over-target is reported neutrally.
- No red alarm colors for over-target. Amber for notable weekly over-target only (defined in Phase 7). Daily over is shown without visual alarm.
- No gamification. No badges, no confetti, no XP, no levels. A simple streak is allowed (see Phase 5) but must not be the emotional centerpiece of the app.
- No ads anywhere, ever.
- No emojis in the UI.
- **Weekly-first framing.** Daily numbers matter less than 7-day averages, and the UI must reflect this. Anywhere a daily calorie or macro number appears, the corresponding weekly rolling average must be visible in the same view. This is a core anti-disordered-eating design principle, not a preference.

---

## App Architecture

### Tab Bar (3 tabs, left to right)

| Position | Tab | What it contains |
|----------|-----|-----------------|
| 1 | **Trends** | Weight graph, adaptive target history, adherence, weekly/monthly reports, macro balance, micronutrients (Pulse+) |
| 2 (center) | **Log** | Today's diary with compact dashboard header, date scrubber, meal list, docked search bar with barcode icon |
| 3 | **More** | Profile, friends (for recipe sharing), settings, data import, Pulse+ subscription, tutorial/help |

Log is the center tab and the app's default landing screen. It is where users spend 90% of their time. Everything else — database browsing, recipe creation, weigh-ins, planning, analytics — is accessed contextually from within Log or from the supporting tabs. There is no separate dashboard screen because Log's sticky header *is* the dashboard.

### Why 3 tabs, not 5

Fuel has exactly one dominant action — logging food — performed 15+ times per week. Any UI pattern that puts distance between the user and that action is pure friction multiplied by frequency. Pump's 5-tab pattern works because "Start Workout" happens 4-6× per week and earns a dashboard between sessions. Fuel's tab bar stays minimal because everything the user needs to log is reachable in one tap from the Log tab.

### Food Picker — Universal Interface

The food picker is the single surface for adding anything to the log. It is opened from: the docked search bar at the bottom of the Log tab, the barcode icon on the right of that search bar (opens directly to the Scan internal tab), or from the Trends tab when inspecting a food's nutrition.

Internal tabs inside the picker (swipeable or segmented):

| Tab | Contents |
|-----|----------|
| **Suggestions** | Default. Level 3 ML time-of-day-aware recommendations (see Phase 5). Keyboard opens active so typing immediately filters. |
| **Recent** | Last 30 foods logged, reverse chronological. |
| **Favorites** | User-starred foods. |
| **My foods** | Custom foods the user created (single-ingredient items). |
| **Recipes** | Saved user recipes + "Create new recipe" button. |
| **Meal templates** | Saved groupings of foods (e.g., "My usual breakfast"). |
| **Scan** | Barcode camera. |
| **AI** | Text + photo AI logging (Pulse+). |

The picker is where recipe creation lives primarily. A user logging breakfast realises they eat the same four ingredients every morning, switches to the Recipes internal tab, taps "Create from recent logs" or "New recipe," and saves. No tab-hop to a separate Foods screen.

---

## Build Order

Build the app in this order. Complete each phase before moving to the next. Commit and branch appropriately at each phase.

### Phase 1: Core Data Models & Local Storage

Build all data models first. Fuel is local-first with cloud sync as an optional paid feature. SwiftData backs local persistence. Supabase tables mirror the SwiftData schema for users who have cloud sync enabled.

**Models to create:**

- `User` — name, email, auth provider, height, current weight, age, gender, unit preference (kg/lbs, also cm/ft-in), energy unit preference (kcal/kJ), tracking mode (detailed/simple/guided), experience level, avatar, username, age_acknowledged flag (for users under 16 — see Phase 3)
- `Goal` — type (lose/maintain/gain), target weight (optional), rate of change (conservative/moderate/aggressive/ultra-aggressive), start date, active flag. Multiple goals exist per user but only one is active at a time (see Phase 7 for multi-profile on Pulse+).
- `Food` — name, brand, source (user/OFF/USDA/community), verified flag, calories per 100g, macros per 100g (protein, carbs, fat, fiber, sugar, saturated fat), micronutrients per 100g (see list below), serving sizes (array of named portions with gram weights), barcode (optional), isCustom flag, submittedBy (optional), approvalStatus (approved/pending/rejected), createdAt
- `MicronutrientProfile` — per-food breakdown of all 30+ tracked micronutrients. Design this as a separate struct so it can be lazily loaded and doesn't bloat every `Food` query.
- `Recipe` — name, servings, ingredients (array of RecipeIngredient), notes, createdAt, source (user/imported). Macros are computed from ingredients, not stored directly, so edits to underlying foods propagate.
- `RecipeIngredient` — food reference, amount in grams, displayUnit (optional, e.g., "1 cup" resolves to grams)
- `MealTemplate` — name, items (array of food references with amounts)
- `MealEntry` — user, date, timestamp, mealName (free-form string, e.g., "Breakfast", "Post-workout", "Meal 1"), items (array of FoodLogItem), isPlanned flag, isConfirmed flag (planned items toggle to confirmed when eaten), notes
- `FoodLogItem` — food reference OR recipe reference OR meal template reference, amount in grams, displayUnit (optional)
- `WeightEntry` — date, weight, source (manual/HealthKit), timestamp, note
- `TDEEHistory` — date, calculated TDEE, source (formula/adaptive), window size (days used in calculation), weight trend at time of calc
- `WorkoutEntry` — external log of workouts (from Pump, HealthKit, or Stride). Contains date, duration, estimated calories, source app. Displayed in the Log tab for user context but NOT added to the daily eatable budget (the adaptive system absorbs them via weight trend — see Phase 6).
- `WaterEntry` — date, timestamp, amount (ml), source
- `SupplementEntry` — date, timestamp, supplement reference, amount (Pulse+ only)
- `Supplement` — name, category, micronutrient contribution per dose
- `UserFriend` — shared friend graph with Pump, accessed via Supabase
- `SharedRecipe` — transient object for recipe sharing via link (serialisation format, no persistent shared recipe table)

**Micronutrients to track** (Pulse+ feature, Phase 10):

Vitamins: A, B1 (thiamin), B2 (riboflavin), B3 (niacin), B5 (pantothenic acid), B6, B7 (biotin), B9 (folate), B12, C, D, E, K.

Minerals: calcium, iron, magnesium, phosphorus, potassium, sodium, zinc, copper, manganese, selenium, iodine, chromium, molybdenum.

Other: cholesterol, omega-3, omega-6, trans fat, caffeine, alcohol.

USDA FoodData Central provides these reliably. Open Food Facts coverage is partial — most packaged foods have calorie and macro data but not full micro profiles. Design the model so a missing micronutrient is distinct from a zero value.

**Local-first architecture:** all writes go to SwiftData first, then queue for Supabase sync if the user has Pulse+ cloud sync enabled. The app must be fully functional with no network connection. Reads prefer local data with background refresh from Supabase for Pulse+ users.

### Phase 2: Backend Setup & Authentication

Set up Supabase as the shared backend for all Pulse apps.

**Auth methods:** Apple Sign In, Google Sign In, and email + password. Apple Sign In is required by App Store guidelines when offering third-party auth. Use Supabase Auth for all three methods.

**Shared identity:** a user who signs in to Pump is automatically recognised by Fuel and Stride when they install those apps. The Pulse user identity is one Supabase user account with per-app profile data. The friend graph is shared across the ecosystem — a friend added in Pump is a friend in Fuel for recipe sharing.

**Supabase tables to create (sketch):**

- `users` — core identity, shared across apps
- `user_app_profiles` — per-app profile data (pump_profile, fuel_profile, stride_profile)
- `foods` — community food database, community submissions, approval queue
- `meal_entries` — user's food logs
- `weight_entries` — user's weight history
- `recipes` — user's recipes (plus optional sharing metadata)
- `user_friends` — friend graph
- `workout_entries` — workouts from Pump and Stride (read by Fuel)

**Row-level security:** enforce via Supabase RLS policies that users can only read and write their own data, with exceptions for the public food database (read-only for all authenticated users) and the friend graph.

**Sync strategy:**
- Pulse+ users: near-real-time sync. Writes to SwiftData trigger a queued Supabase write. Pull from Supabase on app foreground and every 5 minutes during active use.
- Free users: cloud sync is gated behind Pulse+ (see Phase 15). Free users' data lives in SwiftData only. Offer a one-time "export all data" option in Settings as a safety valve against phone loss.

**Conflict resolution:** last-write-wins with timestamps. Edge cases (simultaneous edit on two devices) are rare enough in nutrition tracking that more sophisticated CRDT handling is out of scope for V1.

### Phase 3: Onboarding Flow

Build the onboarding screens. Three authentication methods as above.

**Data to collect during setup (in this order):**
1. Name
2. Current weight
3. Height
4. Age — if under 16, show a gentle informational screen explaining that the app is designed for adults and ask the user to continue only if they feel they can track food in a healthy way. Set `age_acknowledged` flag. Do not hard-block.
5. Gender
6. Activity level — sedentary / lightly active / moderately active / very active. Used only for the Day 1 Mifflin-St Jeor formula estimate. The adaptive system replaces this within 2 weeks.
7. Goal — lose weight / maintain / gain weight. If lose or gain, ask for target weight (optional — user can set a direction without a specific target).
8. Rate of change — conservative (0.25% bodyweight/week) / moderate (0.5%) / aggressive (1%) / ultra-aggressive (>1%). Ultra-aggressive triggers a warning modal with plain language:

> This rate loses muscle and disrupts hormones. Research shows rates above 1%/week are unsustainable beyond 2-4 weeks. We'll check in with you after 2 weeks.

User taps Confirm to proceed. After 14 days on ultra-aggressive, a check-in appears on app open: "You've been on ultra-aggressive for 2 weeks. How are you feeling?" with three options (Good / Tired / Bad). Tired or Bad softly prompts rate reduction. No hard block. This check-in is persistent until acknowledged.

9. Unit preferences — weight (kg/lbs), height (cm/ft-in), energy (kcal/kJ). Can all be changed later in Settings.
10. Tracking mode — Detailed (full numbers and macros), Simple (just meals, no numbers shown anywhere), Guided (targets exist but daily numbers are de-emphasised, weekly averages dominate). Explain each in one sentence. Switchable anytime in Settings. Do not ask about eating disorders or mental health — mode choice is framed as preference, not diagnosis.
11. HealthKit permissions — request read access to body weight (for smart scale integration) and optionally workouts (as a fallback for users not on Pump). Request write access for nutrition data (calories, macros, micros, water). Explain each permission before asking.

**Adaptive system explanation (a dedicated screen):**

> For the first 2 weeks, we'll use a formula based on your height, weight, age, and gender to estimate your calorie needs. After that, we learn your actual metabolism from your weight trend and calorie intake. Your target may go up as we learn that you burn more than the formula predicts — this is normal and correct.

This screen sets expectations so users don't interpret the 2-week warmup as the app being wrong.

**After setup:**
- Ask "Would you like a quick tutorial?" (yes/no)
- Beginner → guided walkthrough explaining core features (how to log a meal, how weigh-ins work, where trends live, what the weekly ring means)
- Experienced → dropped into the Log tab immediately
- Hints are available throughout the app at all times (tap-to-reveal). Tutorial is always re-accessible from Settings.

### Phase 4: Food Database Integration

Fuel's database is a hybrid of three sources.

**Open Food Facts (OFF)** — primary source for packaged/branded foods and barcodes. Roughly 3 million products, free, API-accessible. Coverage is strongest in Europe, decent in the US, weakest in Australia/NZ for regional brands. Sync a snapshot of popular products to Supabase during app setup to reduce API calls at runtime. Keep individual lookups (by barcode or search) going through the OFF API for completeness.

**USDA FoodData Central** — primary source for whole foods (chicken breast, banana, rolled oats) and micronutrient data. Free, well-structured, US-government-maintained. Import the Foundation Foods and SR Legacy datasets into Supabase at build time. These provide the micro data OFF lacks.

**Community-submitted foods** — users create custom foods and optionally submit them to the community database. Submissions enter a pending queue. Manual approval is required before appearing in public search. Submitter sees their pending submissions in the Foods area of the picker.

**Search behaviour:**
- Default search queries Supabase's merged food index across all three sources with a ranking that prioritises USDA (verified), then approved community submissions, then OFF.
- Level 3 ML time-of-day-aware suggestions appear in the Suggestions tab of the food picker before the user types (see Phase 5).
- Filters: source (verified only / include community), macronutrient target (e.g., "high protein"), allergens (optional filter, not a hard gate).
- Barcode scans hit OFF directly, fall back to USDA, fall back to community, fall back to "add as custom food" flow if nothing is found.

**Custom food creation:** name, brand (optional), serving sizes (amount + unit name — e.g., 1 bar = 60g), calories + macros per 100g, optional micros. Users creating a custom food can tick "submit to community database" — submission is tied to their account and visible in their pending queue.

**Restaurant foods:** no licensed database in V1. This is a known weakness. Two mitigations: (a) seed a small curated database of popular chain items from published nutrition info (legal — restaurants publish these on their websites and in FDA filings), (b) the AI logging feature (Phase 11) handles the restaurant case when the user is eating out and can't find an exact match.

### Phase 5: Core Logging — The Log Tab

This is the most important feature. Build it to be fast and frictionless. Every extra tap is multiplied by 15+ daily uses.

**Log tab layout, top to bottom:**

- **Sticky compact header.** Always visible. Contains: weekly calorie ring (today's calories + remaining vs weekly target, not just today's target — see weekly framing principle), today's calories remaining below the ring, and a contextual weigh-in chip (see Phase 8 for the smart weigh-in prompt). Tappable elements: the ring expands inline to show a 7-day breakdown; the weigh-in chip jumps to weigh-in entry. Shrinks on scroll (iOS large-title pattern) — by the time the user scrolls halfway down, the header is a slim summary bar with just today's remaining.

- **Date scrubber.** Horizontal strip of dates near the top, current day highlighted. Swipe the meal list left/right to jump days (±1 day per swipe). Tap the date text to open a full calendar picker for jumping to any day, with copy-forward and plan-ahead actions accessible from there.

- **Meal list.** Today's meals grouped by timestamp. Each meal has: meal name (free-form, e.g., "Breakfast", "Post-workout", "Meal 1"), timestamp, food items with their amounts and calories, and a meal total at the bottom. Swipe actions on each item: edit, delete, duplicate. Swipe actions on each meal: add food, convert to recipe, delete, duplicate meal. Long-press a meal to drag-reorder within the day.

- **Planned vs confirmed items.** Planned items (from plan-ahead mode or copy-forward with offset dates) render with dashed borders and slightly reduced opacity. Tap the meal's "mark as eaten" toggle or tap each item's checkmark to confirm. Confirmed items render normally.

- **Docked search bar at the bottom.** Always visible above the tab bar. Tapping it opens the food picker with keyboard active and Suggestions tab showing. A barcode icon sits on the right of the search bar — tapping it opens the food picker jumped directly to the Scan tab. This is the primary add-food flow.

**Logging flow (the 90% case):**

1. User taps search bar at the bottom of Log.
2. Food picker opens with Suggestions tab visible and keyboard open.
3. Either: user taps a suggestion (1 tap) OR starts typing and picks from filtered results.
4. Food detail sheet opens with default serving size. Grams is the default unit. User can adjust amount in grams or switch to a named serving (e.g., "1 cup", "1 bar").
5. User selects which meal to add to (defaults to the nearest meal in time — if logging at 12:30pm and the user has a meal from 12:15pm, add to that meal; otherwise create a new meal with the current timestamp).
6. Back to Log tab. Meal list updates.

**Meal grouping (MacroFactor-style, not MFP-style).** Meals are free-form, not fixed Breakfast/Lunch/Dinner/Snacks. When adding food, the default meal is either the nearest recent meal (within 30 minutes) or a new meal named "Meal N" with the current timestamp. User can rename any meal inline by tapping its title. Users who want fixed meals can rename their defaults consistently ("Breakfast", "Lunch", etc.) and Fuel remembers.

**Convert meal to recipe.** Swipe action on a meal opens "Convert to recipe." User confirms name and servings, recipe is saved. Original meal entry is unchanged. This is MacroFactor's missing feature.

**Time-of-day-aware suggestions (Level 3 ML).**

This is the default content of the Suggestions tab in the food picker. Approach:

- Group historical logs into time buckets (early morning 5–9am, mid-morning 9am–12pm, lunch 12–2pm, afternoon 2–5pm, dinner 5–8pm, evening 8pm+).
- Consider day-of-week patterns (Monday breakfasts may differ from Saturday breakfasts).
- Consider meal context (post-workout meals detected by proximity to a WorkoutEntry get weighted toward recovery foods).
- Score foods by recency-weighted frequency within the matching context.
- Show top 8-12 foods, re-ranked as the user types.

For the first 2-3 weeks before enough data exists, fall back to simple recency-weighted frequency without time awareness. As the model learns, the suggestions become sharper.

**Quick-add calories.** Inside the food picker, a "Quick add" option creates a log entry with just a calorie number (and optional macro split), no food. For users eating something untracked who don't want to spend effort logging it exactly. Discouraged by placement (it's a menu option, not a top-level action) but available.

**Streak.** Count consecutive days with at least one logged meal. Display discreetly in the More tab profile view. Do not show on the Log tab or Home. Do not animate, flash, or gamify. A streak is a private motivation tool, not a scoreboard. Streak breaks silently — no "you lost your streak!" notification.

### Phase 6: Adaptive TDEE System

This is Fuel's core technical feature. It replaces static calorie formulas with a learning system that converges on the user's true metabolism within 2-4 weeks.

**Day 1 behaviour.** On first use, calculate TDEE from Mifflin-St Jeor using the user's height, weight, age, gender, and onboarding activity level. Apply goal-based deficit or surplus based on their rate of change. This is the user's target for the first 14 days.

**Window-based recalculation.** Starting on day 15, the adaptive system takes over. Every day (or whenever the user opens Trends), recalculate TDEE using:

```
measured_TDEE = avg_daily_calories_over_window + (weight_change_kcal / days_in_window)
```

Where:
- `avg_daily_calories_over_window` = mean of logged calories over the last 14 days
- `weight_change_kcal` = (weight_change_kg × 7700 kcal/kg), using smoothed weight trend (see Phase 8 weight smoothing)
- `days_in_window` = number of days in the window with valid data (default 14)

The result is the user's actual maintenance TDEE. New target = `measured_TDEE + goal_adjustment` where `goal_adjustment` is negative for weight loss, positive for gain, zero for maintenance.

**Goal adjustment calculation.** For a conservative 0.25% bodyweight/week loss:
```
weekly_deficit_kcal = (bodyweight_kg × 0.0025) × 7700
daily_deficit_kcal = weekly_deficit_kcal / 7
target = measured_TDEE - daily_deficit_kcal
```

Scale proportionally for moderate (0.5%), aggressive (1%), ultra-aggressive (user-defined up to a soft cap of 1.5% with warnings).

**Data requirements for recalc.** Require at least:
- 10 days of logged calories in the 14-day window (allow up to 4 gaps)
- At least 3 weigh-ins in the window

If either condition fails, do not recalculate. Keep the previous target and show a gentle note in Trends: "Not enough data to update your target this week. Log more consistently to get the benefit of adaptive targets."

**Weight trend smoothing.** Raw daily weigh-ins include water weight noise that can dwarf real fat change over a week. Use a 7-day exponential moving average for the trend input to TDEE calculation. On the Trends tab, show both raw weigh-ins (dots) and the smoothed trend (line) so the user understands why their daily spike didn't affect their target.

**User override: ignore a week.** In Trends, the user can tap a week and tag it as "ignore" — travel, illness, period, post-surgery. The adaptive system excludes tagged weeks from window calculations.

**Workout calorie handling.** Workouts flow in from Pump, Stride, and HealthKit (see Phase 12). They are displayed on the Log tab for context — "You burned ~420 kcal in your workout today" — but are **not** added to the daily eatable budget. The adaptive system absorbs them silently via the weight trend. Explain this in an onboarding tooltip and in the Trends tab first-time help:

> You burned 420 kcal today, and that's already accounted for. Our system learns your true maintenance from your weight changes, so every calorie you burn makes your target go up over time — without the guesswork of estimating individual workouts.

**No static fallback mode.** There is no permanent MFP-style "subtract workout calories from TDEE" option. The 2-week warmup uses formula TDEE; from day 15 onward, everyone is on adaptive. This is a deliberate product decision, not an oversight.

**One-off workouts.** A single unusual day (e.g., a 20km incline hike) does not meaningfully distort targets. The 14-day window smears the extra burn across 14 days, resulting in a small temporary target bump that fades as the day ages out. No special-case logic needed.

### Phase 7: Recipes, Custom Foods & Meal Templates

All three live inside the food picker's internal tabs, not as a separate Foods screen.

**Recipes.** Multi-ingredient composites that log as a single entry with combined macros. Build-a-recipe screen: name, servings count, ingredients list (add from food picker, specify amount in grams per ingredient), optional notes. Macros are computed from ingredients, not stored — so if an underlying food's nutrition data updates, the recipe updates too. Edit, duplicate, delete. Share via link (see Phase 13).

**Custom foods.** Single-ingredient items the user enters manually from a product label. Fields: name, brand (optional), barcode (optional, if scanning an unrecognised code), serving sizes (amount + unit name), calories and macros per 100g, optional micronutrients. Option to "submit to community database" during creation — submission enters the pending approval queue.

**Meal templates.** Saved groupings of foods that log as separate entries. Different from a recipe: a recipe collapses to one log entry with one set of macros; a meal template expands into N separate log entries, each with its own food and amount. Useful when the user wants to see individual items (e.g., for per-food protein tracking) rather than a merged recipe. Create from scratch or "Save this meal as template" swipe action on an existing meal.

**Multi-profile (Pulse+ only).** Users can create multiple goal profiles (e.g., "Cut", "Maintain", "Bulk", "Wedding prep") each with its own target, rate of change, and macro split. Only one is active at a time. Switching profiles preserves all history — logs are tagged with the profile active at the time they were created, so trend graphs can filter or color-code by phase. Free users have a single active goal.

### Phase 8: Weigh-ins & HealthKit Integration

The adaptive system lives or dies on weigh-in consistency. Make logging weight as frictionless as possible.

**Manual weigh-in.** Accessible from: the weigh-in chip in the Log tab's sticky header (shown in morning if no weigh-in today and user has a morning weigh-in pattern), a dedicated "Log weight" option in the food picker's action area, and a direct entry in the Trends tab. Simple screen: weight input (defaults to user's last weight ±2kg range), optional note, save.

**HealthKit integration.** Fuel reads body weight samples from HealthKit and writes nutrition data back. Read permissions requested during onboarding (Phase 3). Implementation:

- On app foreground, query HealthKit for new weight samples since the last sync. Any new samples are imported as WeightEntries with `source = HealthKit`.
- When the user saves a manual weight, write it to HealthKit as well so other health apps see it.
- Write calories, macros (protein, carbs, fat), micros (for Pulse+ users), and water to HealthKit as the user logs meals. One-way write — Fuel does not read nutrition from HealthKit because other apps' nutrition data is often unreliable.
- Last-write-wins conflict resolution by timestamp. If HealthKit has a reading newer than Fuel's local data, pull it in. If the user typed a weight manually and it's the most recent, it wins.

**Smart scale users without HealthKit support.** Some scales (e.g., Taylor, older Eufy models) don't write to HealthKit. For these users: manual entry only, with a one-liner in Settings under "Data Sources":

> Have a smart scale? If it supports Apple Health, Fuel can read your weight automatically each morning — no manual entry needed. Check your scale's settings or manual for Apple Health support.

**Weight smoothing.** Store raw weigh-ins. Compute 7-day EMA for trend display and TDEE calculations. Display both on the Trends tab weight graph (raw dots, smoothed line).

**Daily weigh-in encouragement.** The app encourages (but does not require) daily weigh-ins. Benefits of daily weighing are explained in the Trends tab's first-time help:

> Weighing daily sounds like overkill, but it gives us the best picture of your real trend. Daily weight swings are mostly water — our smoothed line is what matters. Missing a day or two is fine; the system handles gaps.

**Smart weigh-in widget (see Phase 16).** If the user has logged a weigh-in within 30 minutes of first app open on ≥50% of mornings over the last 14 days, Fuel recognises them as a morning-weigh-in user. The daily-calories widget morphs into a "Log your weight" widget from 5am–10am local time on days when no weigh-in has been recorded yet, then reverts to the calorie display for the rest of the day.

### Phase 9: Plan-Ahead & Copy-Forward

Both features are in V1. They share UI surface (the calendar picker accessed from the Log tab's date header) but are distinct flows.

**Copy-forward (retroactive convenience).** Primary action. User eats their meals, logs them. Tomorrow they'll eat similar — they open the calendar, tap "Copy day," select yesterday as source, select one or more destination days via multi-select, optionally offset timestamps, confirm. Destination days are pre-populated with planned items (dashed borders). User marks items as eaten when they actually eat them.

**Plan-ahead (proactive flow).** User taps a future date from the Log tab's calendar. A blank planning screen opens for that day. User builds meals they intend to eat, sees projected daily totals (calories, macros, micros for Pulse+), saves. When that day arrives, the Log tab shows the planned items with tap-to-confirm checkmarks. Discrepancy between plan and reality is fine — add, delete, or edit on the day of.

**Quick actions.** At the top of the calendar picker: "Copy yesterday to today" and "Copy last week to this week" as one-tap shortcuts for the dominant patterns.

**Weekly meal prep (Pulse+ only).** A specific workflow built on plan-ahead. "Plan this week" opens a five-day (Monday-Friday) or seven-day view with planning surfaces for each. A weekly projected total is displayed at the top. A "balance this week" helper flags days significantly below or above the weekly average and suggests redistributions. For users who Sunday-prep.

**Planned data visibility.**
- Planned items contribute to forward-looking projected totals shown in the date scrubber and the weekly view.
- Planned items do NOT contribute to the adaptive TDEE calculation until confirmed. The system waits for actual eaten data.
- Planned items on past dates that were never confirmed are treated as "unlogged" for that date and excluded from calculations.

### Phase 10: Trends Tab & Analytics

Everything analytics lives here. The design principle is weekly-first — weekly views are default, daily is a drill-down.

**Top-level views (tabs or segmented control inside the Trends tab):**

- **Weight** — line chart of raw weigh-ins (dots) + smoothed EMA (line). Time range selector (week/month/3 months/6 months/year/all). Rate-of-change readout — actual weekly change vs targeted weekly change. For users on multi-profile (Pulse+), color-code segments by active goal phase.

- **Calories** — bar chart of daily calories with weekly average line overlay and target line. Days over target in amber (only when weekly total is 15%+ over target — individual days are shown neutrally). Include the TDEE history line so users can see how the adaptive system has adjusted their target over time.

- **Macros** — stacked bars showing daily protein/carb/fat grams, with target ranges. Weekly averages displayed prominently.

- **Micronutrients** (Pulse+ only) — weekly average intake vs RDI for each tracked micro, colour-coded by adequacy. Callouts for micros consistently below RDI ("Your iron intake has been below target for 3 weeks"). No alarmist framing — this is nutrition education, not pathology.

- **Adherence** (Pulse+ only) — log-day consistency, days-on-target percentage, predicted goal-hit date based on current trend, plateau detection (flag when weight trend has been flat for 3+ weeks despite a calculated deficit, prompting "your adaptive target may need recalibration").

- **Macro timing** (Pulse+ only) — when in the day the user gets their protein/carbs/fat. Useful for users timing carbs around workouts or front-loading protein.

- **Workout calories** — passive display of workouts from Pump, Stride, and HealthKit. Shows count, total calories burned, and a reminder that this data already informs TDEE via the adaptive system.

**Time ranges:** all views support week, month, 3 months, 6 months, year, all-time, and custom date ranges.

**Interaction:** tap any data point or week to drill down into that specific day or week's log.

**"Ignore a week" from the Weight view** — long-press a week's data to tag it as ignored for TDEE calculation (see Phase 6).

### Phase 11: AI Logging

Pulse+ feature. Two modes: text-based and photo-based. Both live in the AI internal tab of the food picker.

**Text-based AI.** User types a description — "chicken parm, medium portion, with a side of spaghetti" — and the AI returns a best-guess breakdown: chicken parmesan (estimated 250g, 580 kcal), spaghetti with tomato sauce (estimated 150g cooked, 290 kcal). User reviews, adjusts portions, and confirms. All confirmed items log as standard FoodLogItems with source tagged as AI-estimated (shown as a small icon — these are less accurate than weighed entries and the user should know).

**Photo-based AI.** User takes or picks a photo of a plate. The model identifies likely foods and estimates portions from visual cues. User reviews each identified food, adjusts or deletes, and confirms.

**Implementation.** Use Claude (Anthropic API) via a Supabase Edge Function. Send the user's description (or photo) to a vision/text model, receive structured JSON with food names, estimated amounts in grams, and confidence scores. Low-confidence items are flagged for user review.

**Cost management.** Each AI call is a direct cost. Build in:
- Hard rate limit per Pulse+ user: e.g., 30 AI logs per month, with clear messaging ("You have 18 AI logs remaining this month").
- Cache common descriptions for 30 days.
- Prefer matching AI outputs to existing foods in the database before creating AI-estimated entries — an "AI says chicken parm, 250g" output should map to the USDA chicken parmesan entry at 250g rather than create a one-off AI estimate.

**Positioning.** The AI feature is framed for occasional use, especially when eating out. The in-app copy should reinforce this: "For when weighing isn't practical." This prevents Pulse+ users from leaning on AI for every meal (which is both bad for their tracking accuracy and expensive for you) and keeps them on the more accurate barcode + weighing workflow.

### Phase 12: Ecosystem Integration

The core Pulse brand promise: your apps talk to each other. This is what positions Fuel against MyFitnessPal, MacroFactor, and Cronometer.

**Data Fuel reads:**

- **From Pump** — workout entries (date, duration, type, estimated calories burned, exercise list). Written by Pump to the shared Supabase `workout_entries` table. Pulled into Fuel's Log tab as a read-only summary card beneath or above the meal list for days with workouts. Clicking expands to show exercise breakdown.
- **From Stride** — step activity, distance, and estimated calories burned. Read periodically throughout the day. Displayed as a daily activity summary in the Log tab's header area.
- **From HealthKit** — body weight (as described in Phase 8), and optionally workouts from non-Pulse apps (Strava, Strong, Hevy, Apple Fitness) as a fallback for users not yet on Pump/Stride.

**Data Fuel writes:**

- **To HealthKit** — nutrition (calories, protein, carbs, fat, fiber, micros for Pulse+, water).
- **To Supabase `nutrition_summary`** — daily total calories and macros, readable by future Pulse apps that might need the data.

**No double-counting.** Workouts from Pump and HealthKit are de-duplicated by timestamp and source. If Pump wrote the workout, don't re-import it from HealthKit.

**Build the integration as pluggable adapters** so new data sources (future Pulse apps, third-party integrations) can be added without rewriting the ingestion layer. Protocol-based design with a `WorkoutDataSource` and `ActivityDataSource` abstraction.

### Phase 13: Social & Recipe Sharing

Fuel's social footprint is intentionally tiny. No feed, no likes, no public discovery.

**Friend graph.** Shared with Pump via the Supabase `user_friends` table. A friend added in Pump is a friend in Fuel. Manage friends in the More tab.

**Recipe sharing.** Peer-to-peer only. User taps "Share" on a recipe, picks one or more friends, sends. Implementation:

- Generate a custom URL scheme link: `pulsefuel://recipe?data=<base64-encoded-JSON>`
- JSON contains: recipe name, servings, ingredients (food references or embedded custom foods), notes.
- Native iOS share sheet sends the link via iMessage, email, etc.
- Share sheet also includes a plain-text App Store fallback for recipients without Fuel installed.
- Recipient taps the link, Fuel opens, prompts "Add '[Recipe name]' from [Friend]?", user confirms, recipe is saved to their library as a new SwiftData copy. No ongoing linkage to the original — the shared recipe is a clone, not a subscription.

**Notifications for recipe shares** are optional (configurable in Settings, off by default for inbound shares to respect quiet notifications).

**No public recipe discovery, no recipe feed, no reactions.** If recipe-sharing organically becomes heavily used, a V2 feed can be added. The V1 position is that Fuel is a nutrition tool first, a social product never.

### Phase 14: Settings & More Tab

All settings inside the More tab:

- **Account management** — name, email, password change, linked auth providers, sign out, delete account (with a 30-day grace period for data recovery).
- **Unit preferences** — weight (kg/lbs), height (cm/ft-in), energy (kcal/kJ), volume (ml/fl oz).
- **Tracking mode** — switch between Detailed / Simple / Guided.
- **Theme** — light/dark toggle (or follow system).
- **Goal management** — edit target weight, rate of change, macro ratios. For Pulse+ users, manage multiple profiles.
- **Rate of change cap** — ultra-aggressive check-in history and acknowledgments.
- **Notification preferences** — granular control. Options: morning weigh-in reminder, meal logging reminders (configurable times), weekly recap, friend activity (recipe shares, friend requests), goal milestones. All off by default except the weekly recap.
- **Data sources** — HealthKit permissions management, Pump/Stride integration status, Apple Health smart scale tip (see Phase 8).
- **Data import** — import from MyFitnessPal (via JSON export), MacroFactor (CSV), Cronometer (CSV, Gold tier only — note this). See Phase 16.
- **Data export** — export all data as JSON or CSV. Free users get this as a manual one-time export (so data is never hostage). Pulse+ users get automated cloud sync.
- **Subscription** — Pulse+ status, upgrade/manage, restore purchases.
- **Tutorial / Help** — re-watch onboarding, browse hint index.
- **Privacy & legal** — terms of service, privacy policy, data deletion request.

### Phase 15: Pulse+ Subscription System

Build the paywall and subscription management.

**Pricing (for reference — integrate with StoreKit):**

| Plan | 1 App | 2 Apps | All 3 Apps |
|------|-------|--------|------------|
| Monthly | $5 | $8 | $9 |
| Yearly | $45 | ~$76 | ~$86 |

Pulse+ is a unified subscription across the ecosystem. Users choose how many apps to unlock.

**Free trial:** 14 days of all Pulse+ features for new users. Integrate via StoreKit's native introductory offer (not a UserDefaults install date — that approach is not tied to the App Store account and resets on reinstall).

**Upselling:** Subtle inline banners (e.g., blurred micronutrient breakdown with "Unlock with Pulse+" overlay on the Trends tab) AND a dedicated Pulse+ benefits page in the More tab. No interstitials, no nag screens, no feature-blocking popups during core logging.

**Free tier — everything in the list below is free, forever:**

- Full adaptive TDEE with weekly recalculation
- Unlimited food logging
- Full food database (Open Food Facts + USDA FoodData Central)
- Barcode scanning
- Recipes (create, save, share via link)
- Custom foods and community submissions
- Meal templates
- All three tracking modes (Detailed / Simple / Guided)
- Copy-forward day planning
- Water tracking
- HealthKit read/write integration
- Ecosystem sync with Pump and Stride (the data exchange itself — not cloud sync across devices)
- Basic analytics: weight, calories, macros, adherence streak
- Import from MFP, MacroFactor, Cronometer
- Manual + HealthKit weigh-ins
- Smart weigh-in widget
- 3 core widgets (daily calories, weekly ring, weigh-in)
- Recipe sharing with friends
- Manual data export

**Pulse+ tier (gated features):**

1. Cloud sync across multiple devices
2. AI logging (text + photo)
3. Micronutrient tracking and analytics
4. Supplement tracking
5. Plan-ahead mode (full calendar + planned-vs-actual)
6. Weekly meal prep workflow
7. Advanced analytics (adherence scoring, predicted goal-hit date, plateau detection, macro timing, deficit quality)
8. Multi-profile goals (save and switch between cut / maintain / bulk)
9. Advanced widgets (full set beyond the 3 free ones)
10. Priority community food submission review

**Everything else is free.** Do not paywall: adaptive TDEE, logging, database access, barcode, recipes, water, ecosystem sync with Pump/Stride (data exchange, not device sync), basic analytics, streaks, imports, all three tracking modes.

### Phase 16: iOS Platform Features

**Widgets (free tier — 3 widgets):**

- **Daily calories** — today's remaining calories, weekly ring mini-view. Morphs into the weigh-in widget in the morning for users with a morning weigh-in pattern (see Phase 8).
- **Weekly ring** — 7-day rolling calorie average vs target.
- **Weigh-in quick action** — tap to open direct-to-weigh-in entry.

**Widgets (Pulse+ tier — additional options):**

- Macronutrient breakdown (daily and weekly)
- Micronutrient spotlight (rotating — today's highlighted nutrient and intake)
- Weight trend mini-chart
- Predicted goal-hit date
- Today's meals summary
- Streak + adherence

**Live Activity & Dynamic Island.** Fuel's use case for Live Activity is less obvious than Pump's rest timer, but there is one genuinely useful pattern: during active meal logging (picker open), show the running meal total in the Dynamic Island so the user can see macros update as they add items without dismissing the keyboard. For V1 this is optional — flag as a nice-to-have. Build the LiveActivityAttributes structure but ship without Live Activity if tight on time.

**Data import.**

- **MyFitnessPal** — users export their data via MFP account settings (JSON format). Fuel parses and imports food logs, custom foods, and weight history. Match foods to Fuel's database by name and brand where possible, import as custom foods otherwise.
- **MacroFactor** — users can request a CSV export. Parse columns for date, meal, food name, amount, calories, macros.
- **Cronometer** — CSV export (Cronometer Gold tier only — note this limitation in the Settings > Data Import screen so users without Gold aren't confused when it doesn't work).

Build the import as a pluggable adapter so additional sources (Lose It!, Yazio, FatSecret) can be added later.

**Offline support.** Logging, barcode scanning (for cached products), weigh-ins, recipe creation — all work fully offline. Data syncs when connection is restored. Non-cached barcode lookups and AI logging require internet.

---

## Things NOT to Build in V1

Do not build any of these. They are noted for future versions:

- Android version (planned for after iOS ecosystem ships — Supabase was chosen specifically to support this, but the Android build itself is a separate project)
- Apple Watch companion app
- Public recipe feed or discovery
- Meal delivery service integration
- Grocery list generation
- Barcode scanning for supermarket receipts
- Recipe video or photo gallery features
- Multi-language support beyond English (flag as important for global launch)
- iPad native UI (universal binary is fine, iPad-optimised layout is V2)
- Accessibility features (VoiceOver, font scaling, contrast) — flag as important
- Landscape mode
- Barcode scanning via user-trained ML (custom Vision model for unrecognised codes)
- Meal sharing via image (Instagram-style food photo feed)
- Coach or human consultation features
- Integration with fasting apps
- Period tracking integration

---

## Open Questions

When you encounter these during development, make your best judgment call, leave a `// TODO:` comment, and note the decision in `CLAUDE.md`:

1. Exact Mifflin-St Jeor activity multipliers (sedentary / lightly active / moderately active / very active) — use standard 1.2 / 1.375 / 1.55 / 1.725 unless research suggests otherwise.
2. Exact default macro split when the user doesn't specify (proposed: 30P / 40C / 30F for lose, 25P / 50C / 25F for maintain, 20P / 55C / 25F for gain).
3. Hard cap on ultra-aggressive rate — proposed 1.5% bodyweight/week, but this may warrant research.
4. AI logging rate limit — 30 logs/month per Pulse+ user is a placeholder, adjust based on actual API costs after launch.
5. Minimum weigh-in frequency for adaptive recalc (proposed: 3 in 14 days — may need tuning).
6. Weekly recap delivery time (proposed: Sunday evening local time, just before the new week starts).
7. Exact community food submission review tooling (separate admin dashboard to be built).
8. Specific widget visual designs (build functional placeholders matching Apple Health style).
9. Handling of foods with incomplete data in OFF (calories known, macros missing) — prompt user to fill in gaps during log, or allow partial data with warnings?
10. Whether to show estimated body fat percentage on the Trends tab — the math is unreliable without a skinfold or DEXA scan, but users often want to see it.