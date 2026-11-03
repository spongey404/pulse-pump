# PULSE ORE — Design Reference for Claude Code
*Complete design system, component spec, and screen-by-screen guide for implementing backend functionality.*

---

## 1. WHAT THIS APP IS

Ore is an iOS workout logging app. It is one of three apps in the Pulse ecosystem (Ore, Fuel, Stride). The design aesthetic is **"Bloomberg Terminal meets workshop manual"** — analog, dense, data-confident, warm. It sits between Apple Health (clinical) and Hevy/Strong (bro-coded).

**The core promise:** log your workouts, let the app learn your patterns, predict what you should do next, and track progress with financial-dashboard clarity.

**Backend:** Supabase (PostgreSQL). Local-first architecture — all writes go to SwiftData first, then sync to Supabase for Supernova users.

---

## 2. TYPOGRAPHY — CRITICAL

This is one of the most distinctive things about this app. Getting fonts wrong breaks the entire aesthetic.

### Font stack
```
Display / UI:     Archivo (Google Fonts) — see weight hierarchy below
Data / Labels:    Space Mono (Google Fonts) — weight 700 for numbers, 400 for labels
Body copy:        Archivo weight 400
```

### 4-Level Type Hierarchy — FOLLOW THIS EXACTLY

```
Level 1 — SCREEN TITLES        Archivo 900 · 24-28px · letter-spacing 0.5px
  Examples: PROGRAMS, HOME, SOCIAL, MORE, PUSH DAY (logger header)
  Use for: tab names, screen headers, primary CTAs

Level 2 — CONTENT TITLES       Archivo 700 · 18-22px · letter-spacing 0.2px
  Examples: Push Pull Legs, Overhead Press, Pull Day (program names)
  Use for: program names, exercise names in library, workout names in history

Level 3 — SECONDARY CONTENT    Archivo 600 · 14-16px · letter-spacing 0.2px
  Examples: Push Day (quick start), exercise names in template rows
  Use for: session names in lists, exercise rows, recent workout names

Level 4 — METADATA / LABELS    Space Mono 400 · 8-10px · all-caps · letter-spacing 1.5px
  Examples: 4 DAYS/WK · 12 EXERCISES · 2 DAYS AGO
  Use for: all metadata, all data labels, timestamps, section headers
```

### Rules — NEVER BREAK THESE

1. **All numbers use Space Mono** — weight, reps, calories, sets, durations, percentages. Always. Without exception. This is what creates the Bloomberg tabular feel.

2. **All labels are Space Mono, all-caps, tracked** — `SETS`, `VS LAST`, `CHEST`, `PR WATCH`. Never sentence case. Always `letterSpacing: 1-2px`.

3. **Large display text uses Archivo weight 900** — workout names (`PUSH DAY`), CTA buttons (`START WORKOUT`), stat heroes (`94 SETS`). Archivo 900 is what gives the app its strong, muscular character.

4. **Onboarding/conversational headings use Archivo weight 300** — `"What should we call you?"` — light weight creates warmth and contrast against the heavy UI.

5. **Body copy is Archivo weight 400 at 13-14px** — used for descriptions, notes, captions. Never for numbers or labels.

6. **Font sizes:**
   - Hero numbers: 64-72px Space Mono 700
   - Workout names: 20-28px Archivo 900
   - CTA buttons: 15-20px Archivo 900, letter-spacing: 2px
   - Section labels: 8-9px Space Mono 400, all-caps, letter-spacing: 1.5px
   - Body copy: 13-14px Archivo 400
   - Set row data: 18-20px Space Mono 700

---

## 3. COLOR TOKENS

Ore's accent moved from terracotta to blue (`#0A6FC0`) so it no longer shares a hue
family with the negative-delta signal. Two accent tiers, not four tokens: `accent` for
filled surfaces (CTA, tab-bar fill, chip fill — carries white `onAccent` text), `accentInk`
for accent text/glyphs/borders, which lifts to a brighter blue on the dark canvas so it
doesn't read as a dim, desaturated ink. PR is no longer a color — see *Anti-patterns*.
Full rationale, contrast numbers and the two open accents (Fuel, Stride) are in
`design_handoff_pulse_color_system/README.md`.

### Light mode
```
bg/canvas:        #f9f8f4   warm cream — primary background
bg/elevated:      #f1efe9   slightly lighter — cards
bg/sunken:        #e7e4dc   inputs, last-session note bg
bg/active-row:    rgba(10,111,192,0.08)   active set tint (= accent/soft)

text/primary:     #1c1b18   charcoal
text/secondary:   rgba(28,27,24,0.5)    warm grey labels
text/faint:       rgba(28,27,24,0.13)   ghost/placeholder
rule/default:     rgba(28,27,24,0.08)   dividers

accent:           #0a6fc0   blue — Ore primary, FILLED surfaces only
accent/ink:       #0a6fc0   accent TEXT, glyphs, borders (= accent in light mode)
accent/soft:      rgba(10,111,192,0.08)
on-accent:        #ffffff
signal/up:        #00aa55   green — positive
signal/down:      #ff3b30  red — negative
signal/pr:        not a color — inkPrimary text + 1.5px inkPrimary underline
ticker/bg:        #1a1816   always-dark bar
ticker/fg:        #ece5d6   cream text on ticker
```

### Dark mode
```
bg/canvas:        #1a1917   warm dark charcoal
bg/elevated:      #24221f
bg/sunken:        #2d2a26
bg/active-row:    rgba(77,184,255,0.14)   (= accent/soft)

text/primary:     #eae7df   cream
text/secondary:   rgba(234,231,223,0.5)
text/faint:       rgba(234,231,223,0.13)
rule/default:     rgba(234,231,223,0.08)

accent:           #0a6fc0   unchanged in dark mode — filled surfaces keep this so
                             white on-accent text keeps its contrast
accent/ink:       #4db8ff   lifted blue — accent TEXT, glyphs, borders only
signal/up:        #00aa55   unchanged
signal/down:      #ff3b30   unchanged
ticker/bg:        #1a1816   unchanged — ticker is identical in both modes
```

Amber (`#c9892e`) is reserved app-wide for Fuel's "over target" signal. Nothing in Ore
uses it — PR badges now use the `signal/pr` treatment above instead.

### Anti-patterns
- **No drop shadows anywhere** — elevation via background tint only
- **No gradients** — flat colors only (exception: the barbell plate colors)
- **No emojis** — anywhere, ever
- **No red for daily over-target** — amber only for weekly notable over
- **No gamification** — no XP, levels, badges-as-trophies

---

## 4. SPACING & RADIUS

```
Screen edge padding:    16px
Card internal padding:  12-14px
Row height (set rows):  44-48px min (touch target compliance)
Gap between sections:   16-24px

Border radius:
  Cards/sheets:     12-14px
  Buttons (CTA):    10-12px
  Chips/tags:       4-6px
  Pill buttons:     999px (only for filter chips and date pills)
  
Dividers: 0.5-1px, always rgba not solid color
Active row: 2px left border in accentInk + accentSoft background (only the active row —
completed and pending rows are untinted, back to bgCanvas)
```

---

## 5. SIGNATURE COMPONENTS

### 5.1 Stock Ticker Strip
- Spec default is an always-dark bar (`#1a1816`) in both color schemes, height 26px.
  **Implemented behavior deviates from this**: `TickerStripView` switches to a light
  cream bg (`#f0ebe0`) in light mode. Not something to "fix" back — see the color note
  below.
- Space Mono, 10px, white text
- Stats: `LABEL` (muted opacity) + VALUE (▲/▼ in signal colors) + `·` separator
- Scrolls as marquee if content overflows
- Used on: Home, Workout Logger, Post-Workout Summary, Muscle Map
- **Up-arrow color has a light/dark split**: `tickerUp` (`#00e07a`) is tuned for the
  always-dark ticker bg and washes out on the light-mode cream bg, so light mode uses
  the older, darker green `#2a7a4a` instead. Dark mode keeps `#00e07a`. `tickerDown`
  (`#ff3b30`) is unaffected and stays the same in both modes.

### 5.2 Set Row
One tinted row per screen. Completion is carried by the check control, not by a
background color. Full state spec in `design_handoff_pulse_color_system/Set Row
States.dc.html`.
```
Grid: [TYPE] [#] [KG] [REPS] [RIR?] [✓]
- TYPE chip: 4-6px radius, colored by set type
  WU = amber tint, STD = transparent, DROP = red tint, SS = purple tint, AMRAP = blue tint
- Numbers: Space Mono 700, 18-20px
- Ghost values: previous session shown in faint color (rgba 0.13)

State           Background                        Numbers      Check control
Completed       bgCanvas (no tint)                inkPrimary   filled accent circle, white ✓
Active           accentSoft + 2px accentInk        inkPrimary   2px accentInk ring, empty
                 left border (only tinted row)
Pending         bgCanvas                          inkPrimary   1.5px inkPrimary 20% ring
Ghost           bgCanvas                          inkFaint     1.5px inkPrimary 10% ring
                (previous-session value, not yet logged this session)

- The filled check is `accent` (flat blue) in BOTH color modes, not `accentBright` —
  it's a filled surface carrying white, so it follows the CTA rule.
- Green never fills a set-row surface — deltaUp is reserved for positive-delta text/
  arrows elsewhere. A completed row does not turn green.
- No per-set PR marker/dot in the live row — PRs stay a surprise until the
  post-workout summary rather than being spoiled mid-set.
```

### 5.3 Docked CTA (FINISH WORKOUT / START WORKOUT)
- Position: absolute, bottom:96px (above 96px tab bar)
- Height: 54px, border-radius: 12px
- Background: accent color
- Text: Archivo 900, 20-22px, letter-spacing 2px, white
- Contains: workout name left, duration/sets right — NO divider line
- Draft state: progress fill + "CONTINUE [NAME]" + small "start new workout" link above

### 5.4 Pill CTA with Split
- Only used for social "START" buttons and filter chips
- border-radius: 999px
- Height: 28-32px

### 5.5 Exercise Card (Logger)
- Background: bg/elevated
- Drag handle: 3 horizontal lines, 12px wide, opacity 0.35
- Header: exercise name (Archivo 900 20px) + equipment + PR badge
- Collapsible: tap header to expand/collapse set rows
- Set type picker: inline chips on tap

### 5.6 Body Heatmap Silhouette
- SVG-based body outline
- Thermal color scale: cream → peach → terracotta → red
- Front and back views
- 3D rotation: CSS transform rotateY, auto-animates in feed, interactive on post detail
- Used on: Muscle Map tab, Social Feed, Post-Workout Summary, Friend Profile

### 5.7 Plate Calculator
- Only shown for barbell exercises
- Only accessible on the **active set** (not all sets)
- Color-coded plates: 25=red, 20=blue, 15=amber, 10=green, 5=black, 2.5=grey, 1.25=cream
- Bar type selector: BARBELL 20kg / OLY 15 / EZ 7.5 / TRAP 25 / SAFETY 32

---

## 6. SCREEN-BY-SCREEN GUIDE

### 6.1 Onboarding Flow
**Screens (in order):**
1. **Auth** — Apple Sign In, Google Sign In, Email. Apple must be first per App Store guidelines.
2. **Name** — free text input, Archivo 900 large
3. **Weight** — numeric input, KG/LBS toggle, large Space Mono number display
4. **Height** — numeric input, CM/FT-IN toggle
5. **Age** — numeric input
6. **Gender** — radio card selection (Male / Female / Non-binary / Prefer not to say)
7. **Experience** — Beginner (<1yr) / Intermediate (1-3yr) / Experienced (3yr+). Each has expanding detail text explaining what the app does differently.
8. **Split** — PPL / Upper-Lower / Full Body / Bro Split / Custom / No Split
9. **Tutorial prompt** — Beginners: YES/SKIP. Experienced: single START TRAINING CTA.

**Progress bar:** linear, top of screen, step N of 8, accent color fill.

**Data collected → stored in User model:**
- name, weight, weightUnit, height, heightUnit, age, gender, experienceLevel, trainingSplit, tutorialCompleted

**After onboarding:** create default program template based on selected split.

---

### 6.2 Home Screen (Dense variant — user preference)
**Layout top to bottom:**
1. Status bar
2. Ticker strip (weekly muscle group deltas)
3. Masthead: ORE wordmark + search icon + avatar
4. **Prediction block** (bg/elevated): predicted workout name (Archivo 900 36px), program tag, last done, est. duration, confidence dots (5 squares = NN% confidence), exercise chip list, "Not today?" link
5. 4-up KPI row: STREAK / IMPROVED / PRs / SETS — Space Mono numbers
6. Weekly volume sparkbar: 7 bars Mon-Sun, today in accent, done in green, rest in faint
7. Friends chip: avatars + "[Name] trained today"
8. Recent workouts compact table: RECENT header, rows with date pill + name + improved score + volume delta
9. **Docked CTA:** START WORKOUT with TODAY · [PROGRAM] label and est. duration

**Draft state:** CONTINUE [WORKOUT NAME] button replaces START, "start new workout" text link above it.

**Smart prediction algorithm:**
- Analyze last 30 workouts for day-of-week patterns
- Score each program day against: day of week, days since last trained that muscle group, current streak pattern
- Confidence = pattern match strength (0.0–1.0)
- If confidence < 0.5, show "What do you want to do?" instead of prediction

---

### 6.3 Workout Logger
**Header:**
- Back arrow + SESSION label + workout name + elapsed timer (HH:MM:SS)
- Rest timer pill: shows countdown or —:— when idle. Tapping opens rest modal.

**Rest Timer Modal:**
- Centered floating card (NOT bottom sheet)
- Large ring (radius 96px) with accent progress stroke
- Time in Space Mono 68px
- ±15s, +30s, +1m adjustment buttons
- SKIP REST full-width CTA

**Exercise Cards (Card Stack layout):**
- Each exercise in a bg/elevated card
- Collapsible (tap header)
- Set rows with TYPE / # / KG / REPS / RIR / ✓ columns
- Tapping a set row opens set type picker inline (STD/WU/DROP/AMRAP/SS/RP)
- Plate calc: only visible on active set row, tap PLATES > SHOW to expand

**Set Types:**
- STD: standard working set — counted in volume
- WU: warmup — NOT counted in volume calculations
- DROP: drop set — weight decreases without rest
- SS: superset — paired with next exercise
- AMRAP: as many reps as possible — reps field becomes result
- RP: rest-pause

**Ghost text:** previous session values shown in faint color beside empty inputs. Never auto-filled.

**Finish Workout pill:** docked at bottom, progress fill shows sets done / total. When all sets done, full accent fill.

---

### 6.4 Post-Workout Summary
**Layout:**
- Screen header: WORKOUT COMPLETE + workout name + date
- **Dark share card** (inside scroll):
  - Ticker strip as header (always dark regardless of screen mode)
  - Session name + duration
  - 4-up stats grid: SETS / KCAL / VOL / STREAK
  - Body silhouettes (front + back thermal heatmap, 72px each)
  - Improvement hero: big green number N/total
  - PR badges: inkPrimary text + 1.5px inkPrimary underline (★), not a color — amber is
    reserved for Fuel's over-target signal
  - Exercise breakdown table: sorted PRs first → improved → unimproved
  - "+X MORE EXERCISES" if > 6 exercises
  - ORE watermark
- **Caption composer:**
  - Avatar + text input
  - TAG FRIENDS pills + + ADD
  - SHARE TO chips: PULSE FEED (default active) / INSTAGRAM / MESSAGES
  - **POST TO FEED** big full-width button (Archivo 900, 54px)
  - **···** three-dot button opens action sheet:
    - Save workout (save locally, no post)
    - Share via… (iOS share sheet)
    - Discard workout (red destructive)

**Exercise sort order:** PRs first, then improved (by delta magnitude), then unimproved.

**Auto-post to social:** on by default. User can disable in Settings.

---

### 6.5 Muscle Map (Body Tab)
**Layout:**
- Masthead with ORE + BODY · LIVE label
- Ticker strip (muscle group weekly deltas)
- Big stat block: total sets / target, vs last % change
- Day scrubber: WEEK pill + 7 day buttons. Accent dot under days with logged workouts.
- Body silhouette with thermal heatmap (front view only in this tab)
- Left column: ▲ TOP 3 muscles (sets/target ratio)
- Right column: ▼ GAPS 3 muscles (lowest ratio)
- Volume sparkline: 12-week bar chart at bottom

**Heat calculation:**
- Week view: muscle sets / target weekly volume
- Day view: muscle sets / day peak (normalized)

**Thermal scale:** 0%=cream, 20%=peach, 45%=soft terracotta, 70%=terracotta, 100%=red

---

### 6.6 Social Feed
**Feed post card:**
- Header: avatar + username + handle + workout + duration + time + ··· menu
- **Swipeable carousel** (3 slides if photo, 2 if no photo):
  - Slide 1 (if photo): full photo
  - Slide 2: 3D rotating body silhouette with thermal heatmap + stat badges
  - Slide 3: workout summary (exercise list with improvement deltas)
- Dot indicators + slide counter badge
- Stats strip: SETS / KCAL / DURATION
- Music chip: spinning vinyl + song name + artist + mute/unmute
- Caption
- Reactions: ❤️ like (hold for picker: ❤️💪🔥👊🏆😤) + 💬 comment

**··· menu actions:**
- Steal program → saves to Programs tab, shows "SAVED TO PROGRAMS" toast
- Save workout → saves to history, no post
- Share via… → iOS share sheet
- Report post
- Unfollow (destructive)

**Comments:** slide-up modal (72% height), scrollable, input at bottom.

**Post Detail:** tap any post → full screen with large interactive 3D silhouette (drag to orbit), exercise list, comments. Tap any exercise → bottom sheet with BODY MAP tab (focused heatmap) + SETS tab (set-by-set breakdown).

---

### 6.7 Programs + Exercise Library
**Program list:**
- Drag-to-reveal delete (swipe left)
- Program name left, split day squares right (4px radius tiles)
- Quick Start section: recent sessions with START button

**Preset picker:** Blank / PPL / Upper-Lower / Full Body / Bro Split / PHUL

**Template detail:**
- Day selector pills at top (Push 1 / Pull 2 / Legs 3 etc)
- Exercise rows — tap to expand into set rows
- Each set row has: TYPE chip / # / REPS (optional) / RIR (optional) / edit toggle
- Tap set row → set type picker inline
- Sets, reps, RIR all optional — can be left blank

**Exercise picker (bottom sheet variant):**
- Searchable exercise list
- Tap exercise → bottom sheet slides up with variant options
- Sheet has its own search input to filter variants
- Equipment selection → grip/style sub-options appear indented
- ADD button activates only when variant selected

**Variant taxonomy:**
- RDL: Equipment (Barbell / Dumbbell / Cable / Trap Bar)
- Pull-up: Grip (Overhand / Neutral / Underhand / Wide / Close)
- Bench Press: Equipment → Grip (Barbell → Flat/Incline/Decline)
- Smart search: typing "dumbbell rdl" pre-selects Dumbbell variant, shows it as pill next to exercise name

**New Program screen:**
- Name input (Archivo 900, large)
- Days/week selector: 1-7 rounded rectangle tiles
- Split type chips (optional)
- Exercise empty state: icon + description + ADD EXERCISE CTA
- Notes field (optional)
- SAVE button in header — activates when name + days filled

---

### 6.8 More Tab
**Hub:**
- Profile card (tap → Profile screen)
- Supernova upgrade banner (only for free users)
- Nav sections: TRAINING / ACCOUNT / HELP
- Rows use: 32px icon container + label + optional sub-label + chevron

**History:**
- Calendar/list toggle in header
- List: stats header + workout rows with date pill, name, improvement score, volume delta, PR badge
- Calendar: month grid, workout days marked with accent dot, tap day → preview card

**Profile:**
- Avatar (placeholder initial) + name + handle + split
- Stats: WORKOUTS / THIS YEAR / STREAK
- Current program with SWITCH button
- All-time PRs table
- Body stats: weight, height, age, units

**Settings:**
- Account: Name & Email, Change Password, Linked Accounts
- Units: Weight (KG/LBS), Height (CM/FT-IN), Distance (KM/MI) — toggle chips
- Appearance: Dark Mode toggle, App Icon
- Rest Timer: Auto-start toggle, compound default, isolation default, alert type
- Notifications: Workout reminders, Social activity, Weekly recap — toggles
- Workout: Auto-post to social toggle, Post-workout summary customization
- Data: Import (Strong/Hevy/CSV), Export

**Equipment Profiles:**
- Profile switcher: Home Gym / Commercial Gym
- Equipment list with edit icon
- Plate visualizer: barbell SVG with color-coded plates
- Plate chips: color-coded by weight
- ADD EQUIPMENT dashed button

**Supernova Paywall:**
- Lightning bolt icon + "UNLOCK SUPERNOVA" hero
- 14-day free trial badge
- Monthly/Yearly billing toggle (yearly saves ~25%)
- 3-tier selector: Ore Only ($5/mo) / 2 Apps ($8/mo) / All 3 ($9/mo)
- 11 features checklist with green checkmarks
- START FREE TRIAL full-width CTA
- No aggressive colors, no countdown timers, no interstitials

---

## 7. DATA MODELS (SwiftData / Supabase)

```swift
User: id, name, username, email, weight, weightUnit, height, heightUnit, 
      age, gender, experienceLevel, trainingSpli, unitPref, avatarURL,
      pulseProTier, streakCount, lastWorkoutDate

Exercise: id, name, primaryMuscle[], secondaryMuscle[], equipment, 
          movementPattern, exerciseType, isCustom, isApproved

WorkoutTemplate: id, userId, name, split, days[], exercises[]

TemplateExercise: id, templateId, exerciseId, variantEquipment, variantGrip,
                  sets[], targetReps, targetRIR, orderIndex

Workout: id, userId, templateId, startTime, endTime, duration, 
         estimatedCalories, notes, isDraft, shareCardPosted

ExerciseLog: id, workoutId, exerciseId, variantEquipment, variantGrip, 
             sets[], notes, orderIndex

SetLog: id, exerciseLogId, setType, weight, weightUnit, reps, rir, 
        side, timestamp, isPR

EquipmentProfile: id, userId, name, isActive, equipment[], 
                  availablePlates[], barTypes[]

Post: id, userId, workoutId, caption, songTitle, songArtist,
      photoURL, visibility, createdAt

Reaction: id, postId, userId, type (heart/fire/strong/trophy/fist/sweat)
Comment: id, postId, userId, text, createdAt
Friend: id, userId, friendId, status (pending/accepted)
```

---

## 8. PREDICTION ALGORITHM

The smart workout prediction on the Home screen works as follows:

```
1. Fetch last 60 workouts for the user
2. Group by day-of-week (Mon=0...Sun=6)
3. For today's day-of-week, find the most common workout type
4. Score by:
   - frequency (how often this workout on this day): weight 0.4
   - recency (days since last did this workout): weight 0.3  
   - muscle freshness (days since those muscles were last trained): weight 0.3
5. confidence = weighted score normalized to 0.0-1.0
6. If confidence > 0.7: show predicted workout prominently
7. If confidence 0.4-0.7: show with "suggested" label
8. If confidence < 0.4: show "What do you want to do?" with program list
```

---

## 9. KEY INTERACTION PATTERNS

### Swipe to reveal delete
- Drag card left → reveals red delete button behind
- Threshold: -40px drag reveals partially, -80px (full delete width) locks open
- Tap anywhere else to dismiss

### Hold to react
- 400ms hold on heart icon → emoji picker animates up
- Options: ❤️ 💪 🔥 👊 🏆 😤
- Quick tap = toggle heart like

### Active set detection
- A set is "active" when the previous set is marked done and this one has no data
- Only one set can be active at a time
- Active set: 2px left accentInk border + accentSoft background
- Plate calculator only available on active set

### Ghost text
- Previous session values shown as faint placeholder text
- Color: faint (rgba 0.13)
- Never auto-filled — user types over it
- Disappears once user starts typing in that field

### Rest timer
- Auto-starts when set is marked done (if auto-start setting enabled)
- Compound exercises default: 3:00
- Isolation exercises default: 1:30
- Override per exercise possible
- Shows in masthead as pill, tap to expand modal

---

## 10. MOTION & ANIMATION

- Default duration: 250ms ease-in-out
- Sheet present/dismiss: 280-350ms ease-out (slideUp)
- Micro interactions: 150ms ease-out
- Ticker marquee: 45s linear continuous
- Body silhouette auto-rotation: sine wave, 6s period, ±25° rotateY
- No spring physics, no overshoot, no bounces

---

## 11. ANTI-PATTERNS — DO NOT DO THESE

- No drop shadows anywhere
- No gradients (except barbell plate color-coding)
- No emojis in UI (emojis are allowed in user-typed captions/notes only)
- No filled icons in non-active state
- No interstitial paywall popups during core flows  
- No confetti or celebration animations for PRs — inkPrimary text + underline only, never a color highlight
- No "streak lost!" notifications
- No round circles for day selectors — use rounded rectangles (radius 8px)
- No pill-shaped primary action buttons — radius 12px for main CTAs
- No vertical divider lines inside buttons
- No separate RESUME button alongside CONTINUE — the whole bar is tappable

---

## 12. SUPERNOVA GATING

Free tier includes: core logging, rest timer, exercise library, all templates, body map (basic), social feed, plate calculator, warmup generator, equipment profiles, basic analytics.

Supernova gates: cloud sync, smart weight suggestions, advanced exercise substitutions, challenges, personalized calorie burn, muscle balance analysis, deload tracking, detailed analytics, advanced body map sub-regions, additional widgets.

Show Supernova upsell as: inline blurred section with small pill "UNLOCK WITH SUPERNOVA" overlay. Never as popup during core flows.

---

*This document represents the complete design specification for Ore. All component dimensions, colors, typography, and interaction patterns described here are final and should be implemented exactly as specified.*
