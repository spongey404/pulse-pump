# PULSE DESIGN SYSTEM
*Master reference for Pump, Fuel, and Stride. Paste this entire document as context before prompting Claude Design to build any screen.*

---

## HOW TO USE THIS DOCUMENT

This is the single source of truth for the Pulse visual system. When prompting Claude Design:

1. Always paste this whole document first as system context.
2. Then specify which **app** and which **batch** you're working on.
3. Reference signature components by name (e.g. "use the Stock Ticker Strip", "use the Set Row pattern").
4. Don't re-describe colors, type, or spacing — the tokens here are authoritative.

The point is to stop bleeding tokens on small tweaks. If a value isn't here, decide it once and add it back to this doc.

---

## 1. CORE PHILOSOPHY

### The aesthetic: "Bloomberg Terminal meets workshop manual"

Analog, dense, data-confident, warm. We sit between Apple Health (clinical, sterile) and Hevy/Strong (bro-coded, busy). Reference points:

- **Take from financial UIs:** monospace numerics, triangular trend arrows (▲▼), tabular alignment, ticker strips, percentage deltas everywhere.
- **Take from print/editorial:** thin horizontal rules instead of cards, small caps labels, generous letter-spacing on metadata.
- **Take from utility/workshop manuals:** earthy palette, dashed-border placeholders, no decorative chrome.
- **Reject:** cards-on-cards layouts, drop shadows, gradients, emoji, pastel gradients, "fitness app" bro signaling, gamification, any aesthetic that looks like a SaaS dashboard.

### The family rule: identical system, accent color differs

Pump, Fuel, and Stride are the *same app dressed differently*. They share:

- Identical color tokens (except primary accent)
- Identical typography
- Identical spacing
- Identical components (ticker, trend chip, set row, day scrubber, pill CTA, etc.)
- Identical motion and interaction patterns
- Identical iconography style

What differs between apps:
- **Primary accent color** (Pump = blue `#0A6FC0`, confirmed; Fuel = sage `#7A9B6E`, current but rejected as final; Stride = TBD)
- **Tab structure** (Pump has 5, Fuel has 3 — driven by content needs, not aesthetic)
- **App-specific surfaces** (Pump has body map / plate calc; Fuel has calorie ring / food picker)

Mental model: Apple Notes / Reminders / Calendar / Mail. Same system, different content. Users move between Pulse apps without relearning.

### Density without clutter — the core principle

Every pixel earns its place. We use horizontal rules, small caps labels, and tabular alignment to pack information tightly without resorting to cards. Cards exist only at the top level of grouping. Within a card, use rules and label/value pairs.

---

## 2. BRAND FOUNDATION

> **Pump's foundation, signals, and accent are CONFIRMED** — sourced from
> `design_handoff_pulse_color_system/tokens.json` and `README.md` (Claude Design
> project "App color system redesign"), which also has the full contrast rationale
> and the four rules any new accent must satisfy. **Fuel and Stride accents remain
> open** — do not invent values for them; see *Open decisions* at the end of this doc.
> The values below replace the earlier screenshot-eyeballed placeholders.

### 2.1 Color tokens — light mode

```
bg/canvas              #F9F8F4   warm cream — primary background
bg/elevated            #F1EFE9   slightly lighter — cards, sheets
bg/sunken              #E7E4DC   slightly darker — input wells, last-session note bg
bg/active-row          rgba(10,111,192,0.08)   accentSoft — active set, focused row only
                        (only the active row is tinted; completed/pending rows stay bg/canvas)
bg/ticker              #1A1816   always-dark, both color schemes, per spec
                        (Pump's implemented ticker deviates and switches to a light cream
                        bg in light mode — see the per-app note in 2.3)

text/primary           #1C1B18   charcoal — main copy, numbers
text/secondary         rgba(28,27,24,0.50)   warm grey — labels, metadata
text/ghost             rgba(28,27,24,0.13)   ghost text — previous values shown beside empty inputs
text/inverse           #ECE5D6   cream — text on the dark ticker bar

rule/default           rgba(28,27,24,0.08)   thin horizontal divider

signal/up              #00AA55   green ▲ — positive trend, in-UI
signal/down            #FF3B30   red ▼ — negative trend
signal/ticker-up       #00E07A   brighter green for the always-dark ticker only —
                        signal/up is too dark against ticker/bg
signal/warn            #C9892E   amber — Fuel weekly total >15% over target. Nothing else,
                        in any app, uses amber — including PR (see signal/pr below).
signal/pr              not a color — inkPrimary text + 1.5px inkPrimary underline.
                        Removed as a gold token; gold read as "amber" and collided with
                        signal/warn's meaning.
```

### 2.2 Color tokens — dark mode (warm dark)

We are not using true black. Warm dark preserves the analog feel.

```
bg/canvas              #1A1917   warm dark charcoal
bg/elevated            #24221F   slightly lighter
bg/sunken              #2D2A26
bg/active-row          rgba(77,184,255,0.14)   accentSoft, dark variant
bg/ticker              #1A1816   unchanged — ticker is identical in both modes per spec

text/primary           #EAE7DF   cream
text/secondary         rgba(234,231,223,0.50)
text/ghost             rgba(234,231,223,0.13)
text/inverse           #ECE5D6

rule/default           rgba(234,231,223,0.08)

signal colors          same as light mode (already chosen for warm-palette harmony) —
                        except signal/ticker-up, which is dark-mode-only; Pump's
                        implemented ticker falls back to a pre-redesign darker green
                        (#2A7A4A) in light mode instead of signal/ticker-up. See 2.3.
```

### 2.3 Per-app accent colors

```
accent/pump            #0A6FC0   blue — Pump primary, CONFIRMED. Flat in both color
                                  schemes on filled surfaces (CTA, tab-bar fill, chip
                                  fill) so white on-accent text keeps its contrast.
accent/pump-ink        #0A6FC0 light / #4DB8FF dark — accent TEXT, glyphs, borders,
                                  and the active-row left border. Lifts on the dark
                                  canvas so it doesn't read as a dim, desaturated ink.
accent/pump-soft       rgba(10,111,192,0.08) light / rgba(77,184,255,0.14) dark

accent/fuel            #7A9B6E   sage green — CURRENT codebase value, but REJECTED as
                                  the confirmed Fuel accent (same hue as signal/up,
                                  also read as too muted) — see Open decisions. Do not
                                  treat this as final.

accent/stride          TBD. A candidate exists (magenta #D4197A / bright #FF5EAE,
                                  4.98:1 vs white, 3.46:1 vs ink) but is not confirmed.
                                  Do not use dusty mustard or soft clay — both collide
                                  with signal/warn's amber, now reserved exclusively
                                  for Fuel's over-target signal.
```

**Per-app ticker exception (Pump only):** Pump's implemented `TickerStripView` switches
`bg/ticker` to a light cream (`#F0EBE0`) in light mode rather than staying always-dark,
and its up-arrow correspondingly falls back from `signal/ticker-up` (`#00E07A`, tuned
for the dark bg) to the pre-redesign darker green `#2A7A4A` in light mode, where the
brighter green would wash out. Dark mode is unaffected. This is a deliberate,
implemented deviation from the spec default above — not something to "fix" back.

The accent is used for: primary CTAs, active tab indicator, selected day pill on the date scrubber, body silhouette overlay (Pump), calorie ring (Fuel), the one-week-highlighted bar in volume charts.

Never use the accent for body text or for decorative purposes.

### 2.4 Typography

> **Resolved for Pump — implemented, not a placeholder.** The SF Pro / SF Mono
> system-font placeholder below is superseded. Pump ships Archivo (5 weights) +
> Space Mono (2 weights) as bundled, registered fonts (`Info.plist` `UIAppFonts`,
> `Extensions/Font+Design.swift`) — both free Google Fonts, no licensing concerns. Per
> the identical-typography family rule, treat this as decided for Fuel and Stride too
> unless there's a reason to diverge.

Two voices, both free (Google Fonts) so no font licensing drama.

```
Display & body:   Archivo (light, regular, semibold, bold, black)
Numerics & data:  Space Mono (regular, bold) — used for ALL numbers, percentages, weights, reps, calories, set counts
Labels:           Space Mono regular, all caps, tracked +0.08em
```

Rules:
- Numbers are always Space Mono. Always. Tabular alignment depends on it.
- Labels are always small caps with letter-spacing. Examples: `SETS`, `VS LAST`, `BAR 20KG`, `PR WATCH`.
- Body text is Archivo regular at 16pt for readable copy.
- Never mix italic and bold for emphasis. Use weight only.
- The italic exception is the "last session note" quote treatment in the workout logger.

### 2.5 Type scale

```
display/xl     64pt   Space Mono bold      hero numbers (Home: "94" total sets)
display/lg     40pt   Space Mono bold      large stats (calorie ring center)
display/md     28pt   Space Mono bold      secondary stats
heading/lg     20pt   Archivo black        screen titles, exercise names
heading/md     16pt   Archivo bold         section titles, meal names
body           16pt   Archivo regular      paragraph copy
body/sm        14pt   Archivo regular      secondary copy
data/lg        20pt   Space Mono bold      table cell numbers (set rows)
data/md        14pt   Space Mono regular   ticker strip numbers
data/sm        12pt   Space Mono regular   micro stats (sub-percentages, dates)
label/md       12pt   Space Mono regular   small caps labels, +0.08em tracking
label/sm       10pt   Space Mono regular   tiny small caps, +0.1em tracking
```

### 2.6 Iconography

> **⚑ TODO — REVISIT LATE IN BUILD:** Custom icon set is planned. For now, use whatever Claude Design provides by default (likely SF Symbols or Lucide). Don't waste cycles on icon decisions yet. When the rest of the system is locked and screens are stable, design a custom Pulse icon family that matches the analog/utilitarian aesthetic — likely thin-stroke, slightly rougher than SF Symbols, with the same visual language across Pump/Fuel/Stride. Reserve a "custom icon" tag in the design system that maps to SF Symbol names today and will swap to custom assets later without changing layouts.

- **SF Symbols throughout.** Weight: Regular by default. Filled only for "selected/active" state (e.g., active tab icon).
- Icon sizes: 16pt (inline with body text), 20pt (controls), 24pt (tab bar), 28pt+ (hero).
- Custom symbols allowed only for: triangular trend arrows (▲▼), the dashed-border add icon, the plate-calculator visual.
- **No filled icons in non-state contexts.** Don't use `heart.fill` for a static "favorites" label — use `heart`.
- PR badge: no icon color — `signal/pr` is inkPrimary text + underline, not a fill color. Streak: `flame.fill` in orange (if used).

---

## 3. LAYOUT & DENSITY

### 3.1 Spacing scale (4pt grid)

```
space/0     0
space/1     4pt    tight inline spacing
space/2     8pt    default gap between related items
space/3     12pt   row internal padding
space/4     16pt   default screen edge padding, between related groups
space/5     20pt
space/6     24pt   between unrelated sections
space/8     32pt   major section breaks
space/10    40pt   above primary CTAs
```

### 3.2 Border radius

```
radius/none   0pt    rule strips, ticker bars
radius/sm     4pt    small chips, type pills (WU, DROP, SS)
radius/md     8pt    cards, sheets, modals
radius/lg     12pt   primary CTAs, large cards
radius/pill   999pt  day picker pills, primary action pills like "FINISH WORKOUT"
```

### 3.3 Borders, rules, shadows

- **No drop shadows.** Anywhere. Elevation is communicated by background tint, not shadow.
- **Rules are 0.5pt** in `rule/default`. They divide content within a card or section.
- Cards have a 1pt border in `rule/default` OR a `bg/elevated` background — pick one per surface, don't combine.
- Active/focused rows get a 2pt left border in the app's accent color, plus `bg/active-row` fill.
- Dashed borders are 1pt with a 4pt dash, 4pt gap. Used for "add" affordances only.

### 3.4 Layout principles

1. **Prefer horizontal rules over card containers.** Cards group at the top level; rules divide within.
2. **Tabular alignment over flow.** Numbers align in columns. Labels align left, values align right or in fixed columns.
3. **Edge-to-edge dividers.** Rules go full width within their container.
4. **Bottom-anchored primary actions.** Use `safeAreaInset` to dock the primary CTA. One-handed thumb reach is non-negotiable.
5. **Sticky compact headers.** Headers shrink on scroll (iOS large-title pattern). The dashboard summary stays visible as a slim bar after scroll.

---

## 4. SIGNATURE COMPONENTS — THE DNA

These appear in every Pulse app. They are what makes Pulse feel like Pulse. Same treatment, different data per app.

### 4.1 Stock Ticker Strip

A horizontal black bar with white tabular monospace text. Stats separated by a center middle-dot ` · `. Each stat shows a label + value + optional trend arrow.

**Visual:**
- Height: 36pt
- Background: `bg/ticker`
- Text: `text/inverse`, `data/md`
- Padding: `space/4` left/right, vertical centered
- Stats marked up as: `LABEL` (label/sm, tracked, muted opacity 0.7) + space + `VALUE` (data/md) + optional `▲`/`▼` (signal color)

**Examples:**
- Pump (Home): `TRAP ▼ -25.0% · CHEST ▲ +12.5%`
- Pump (workout logger): `LAST SET 225×5 · TGT 3/4 SETS · PR WATCH ▲▲`
- Fuel (Log): `PROTEIN ▲ +12% · CARBS ▼ -8% · CALS ▲ +4%`
- Fuel (Trends): `TDEE 2,420 · WEIGHT ▼ -0.4KG · 7D AVG 2,180`

If content overflows, it scrolls horizontally as a marquee. Never wrap to a second line.

### 4.2 Trend Chip / KPI Block

A label + big tabular number + optional comparison percentage. The dominant data display element.

**Variants:**
- **Inline (used in stat clusters around the body silhouette):** label on top in `label/md`, big `data/lg` number, ▲/▼ + percentage in `data/sm` below, thin `rule/default` underline.
- **Hero (used as page-level dominant stat):** big `display/xl` number with `data/sm` denominator ghost (e.g., `94 / 132`).
- **Compact (used in ticker-adjacent KPI rows):** label + value + delta inline.

**Rule:** the label is *always* small caps, never sentence case. The number is *always* Space Mono.

### 4.3 Set / Log Row

Tabular row with a type pill, sequential number, value columns, and a check.

**Pump version (workout set):**
```
[TYPE]  [#]   [KG]    [REPS]  [RIR]   [✓]
 WU     01    60      8       5       ✓
 STD    02    95      6       3       ✓
 DROP   05    80      8       —       ○
```

**Fuel version (food log item):**
```
[TYPE]  [AMOUNT]  [CALS]  [P/C/F]    [✓]
 FOOD   240G      380     32/45/8    ✓
```

**Visual rules:**
- Row height: 48pt
- Type pill: `radius/sm`, `space/2` horizontal padding, `label/sm`, distinct color per type (WU=cream, STD=neutral, DROP=tinted red, SS=tinted yellow, AMRAP=tinted accent)
- Active row: `bg/active-row`, 2pt left accent border, set number in red
- Ghost rows (planned/predicted): all values in `text/ghost`, dashed underline below
- Swipe left to delete

### 4.4 Pill CTA with Internal Divider

Primary action pill with right-aligned secondary metadata, separated by a vertical rule.

**Visual:**
- Height: 56pt
- Shape: `radius/pill`
- Left: primary action label, white text, accent background (e.g., blue for Pump, sage for Fuel — pending confirmation)
- Vertical rule: 0.5pt `text/inverse` at 0.3 opacity
- Right: secondary metadata in cream/inverse text, smaller (`label/md`)
- Position: docked to bottom via safeAreaInset

**Examples:**
- Pump: `FINISH WORKOUT | 11 SETS LEFT`
- Fuel: `FINISH MEAL | 320 KCAL`
- Pump: `START PUSH DAY | EST. 45 MIN`
- Fuel: `SAVE WEIGHT | 78.4 KG`

### 4.5 Day / Date Scrubber

Horizontal strip of 7 day pills. The current/selected day is a filled black pill with white text. Other days show the day letter + date in `text/secondary`. Days with logged data have a thin underline accent below in `text/primary`. Days without data have no underline.

**Visual:**
- Pill size: 44pt × 56pt (touch target compliant)
- Selected: `bg/ticker` background, `text/inverse` text, `radius/md`
- Unselected: transparent, just the underline indicator
- Above the scrubber: a small `WEEK 14 · APR 13–19` label in `label/md`

Tapping a day jumps the view. Tapping the week label opens a full calendar picker.

### 4.6 Ghost Text Pattern

Previous-session values shown as light placeholder text inside or beside empty inputs. Passive — the user types over it, no auto-fill.

**Visual:**
- Color: `text/ghost`
- Weight: regular (matches active text weight to avoid layout shift)
- In Pump: shown inside empty kg/reps fields when starting a set the user has done before
- In Fuel: shown beside the amount field when logging a food the user has logged before ("usually 240g")

### 4.7 Dashed-Border Add Affordance

Used for "add a thing" buttons inside an existing context (add a set, add a food, add an exercise).

**Visual:**
- 1pt dashed border, 4pt dash / 4pt gap
- `radius/md`
- Background: transparent
- Label: `+ ADD [THING]` in `text/secondary`, `label/md`
- Min height: 48pt
- Tapping triggers an inline insert or opens the picker, depending on context

### 4.8 Sticky Compact Header

The dashboard at the top of Log (Fuel) and Home (Pump). Always visible, shrinks on scroll.

**Expanded state (top of scroll):**
- Hero metric (calorie ring in Fuel; sets total in Pump) at full size
- Secondary stats below the hero
- Quick-action chip (weigh-in chip in Fuel; start workout in Pump)

**Compact state (after scroll):**
- Single line: hero metric + remaining number
- All secondary content hidden
- Background: `bg/elevated` with a `rule/default` bottom border

Transition: smooth 250ms ease-in-out. Header content fades and translates, doesn't snap.

### 4.9 Type Pill (set-type / food-type / category labels)

Small rectangular pills used inline to tag content. `label/sm`, `radius/sm`, `space/2` padding.

Color treatments by category:
- Neutral / standard: `bg/sunken` background, `text/secondary` text
- Warning / drop / fail: tinted red background (signal/down at 0.15 alpha), red text
- Highlight / superset / amrap: tinted accent background, accent text
- Warmup: cream/yellow tint

---

## 5. APP-SPECIFIC SURFACES

### 5.1 Pump-only components

- **Body silhouette:** stylized blocky figure with overlay regions colored by accent. Front and back views in a swipeable pager.
- **Plate calculator:** horizontal barbell visualization with color-coded plates per side. Updates live as weight is typed in a set row.
- **Rest timer ring:** circular progress ring in the top-right of the workout logger header. Background black, ring accent color, countdown time in white Space Mono inside.
- **Exercise card:** drag handle on the left, exercise name + type label, PR/1RM badges, set-count progress (`3/5`), overflow menu. Contains the set rows.

### 5.2 Fuel-only components

- **Weekly calorie ring:** large circular progress ring in the sticky header. Outer = weekly target, fill = consumed. Center: `display/lg` calories remaining. Tap to expand into a 7-day breakdown inline.
- **Food picker:** full-screen sheet with internal segmented tabs at the top (Suggestions / Recent / Favorites / My Foods / Recipes / Templates / Scan / AI). Search bar persistent at the top, keyboard active on open.
- **Weight trend graph:** raw weigh-ins as muted dots, smoothed EMA as a continuous line in accent. Time range pills at the top.
- **Barcode scanner:** native camera view with a centered targeting rectangle, dimmed surrounding overlay, "POSITION BARCODE" label, manual-entry fallback link.
- **Meal block:** free-form meal name (inline editable) + timestamp + items (set-row pattern) + meal-total footer with calorie sum.

---

## 6. STATES & EDGES

These have to be designed explicitly. Don't let Claude Design improvise them.

### 6.1 Empty states

Quiet, minimal, no illustrations of cartoon characters. Use a single SF Symbol icon at low opacity, a one-line title, a one-line description, and a primary CTA.

- Pump first-open Home: "No workouts yet." → `START FIRST WORKOUT`
- Pump empty Programs: "No templates saved." → `CREATE TEMPLATE`
- Fuel first-open Log: "Today's log is empty." → search bar focused, suggestions visible
- Fuel no weight history: "Add your first weigh-in to start tracking."

### 6.2 Loading states

Skeleton rows that match the actual content shape. Never spinners except for full-screen blocking operations (account creation, etc.).

- Set rows skeleton: grey blocks in the same column structure as a real set row
- Ticker skeleton: pulsing grey blocks in place of stats
- Body model: silhouette in `text/ghost` until data loads

### 6.3 Error states

Quiet text in `signal/down` color, no alarm. Always include a retry action.

- "Couldn't reach the server. [Retry]"
- "Barcode not found. [Add as custom food]"
- "Network unavailable. Changes saved locally and will sync."

### 6.4 Offline state

Slim banner at the top of the screen in `signal/warn` background, `text/inverse` text: `OFFLINE — Changes saving locally`. Disappears when reconnected.

### 6.5 Pulse+ paywall states

The exact opposite of aggressive. We do NOT use:
- Interstitials
- Modal popups during core flows
- Red urgency colors
- Countdown timers
- "Limited time" framing

We DO use:
- Inline blurred sections with a small overlay: `UNLOCK WITH PULSE+` in a thin pill
- A dedicated benefits page in More tab
- A subtle banner on relevant screens: "Upgrade for [specific feature]" — text only, no graphics

---

## 7. MOTION

### 7.1 Principles

- No bouncy springs. Tight ease-in-out only.
- No haptic feedback anywhere.
- Motion is precise and analog, not playful.
- Default duration: 250ms. Range: 150ms (micro) to 350ms (sheets).

### 7.2 Specific timings

```
micro              150ms  ease-out      tap states, color transitions
default            250ms  ease-in-out   most transitions, header collapse
sheet              350ms  ease-in-out   modal/sheet present and dismiss
list reorder       200ms  ease-in-out   drag-and-drop settle
ticker scroll      40px/sec  linear     marquee scroll if overflow
ring fill          800ms  ease-out      calorie ring loading in
```

### 7.3 Transitions to never use

- Spring physics with overshoot
- Page curl / 3D card flips
- Confetti, particle effects, celebrations
- Pulsing/glowing PR badges (inkPrimary text + underline only — see anti-patterns)

---

## 8. ANTI-PATTERNS — THESE BREAK THE BRAND

A combined list from both specs. If you find yourself doing any of these, stop.

- **No emojis in the UI. Anywhere. Ever.**
- No haptic feedback.
- No exercise demo videos or GIFs in Pump.
- No drop shadows.
- No gradients (except subtle ring fills).
- No confetti, particles, or celebration animations.
- No PR badges that pulse, animate, or get oversized — inkPrimary text + underline only, no color, no gold.
- No gamification: no XP, levels, badges-as-trophies, leaderboards-as-status.
- No ads, ever, of any kind.
- No red alarm colors for daily over-target in Fuel. Amber for weekly notable over-target only.
- No shaming copy in Fuel. Never "you went over!" or "you failed your goal."
- No "streak lost!" notifications or animations. Streaks break silently.
- No carded layouts where a horizontal rule would do.
- No SF Symbol fills on non-active-state icons.
- No bouncy spring animations.
- No interstitial paywall popups during core flows.

---

## 9. PUMP — SCREEN BATCHES

Build in these batches. Each batch is one mega-prompt to Claude Design with this whole document as preamble.

### Batch 1: Home + Body Map ✅ REFERENCE
The screens already designed. Use these as the visual ground truth for every other screen.

- **Home (Body view):** logo treatment, top stock ticker, hero `94/132` stat, day scrubber, body silhouette with stat clusters, weekly volume chart, tab bar.
- **Body Map (front/back swipeable):** full body silhouette in a TabView pager, dot indicators, legend below, neglected-muscle nudges, muscle-group tap → trend graphs + exercise list bottom sheet.

### Batch 2: Live Workout Logger + Post-Workout

- **Active workout (logger):** session breadcrumb header with rest-timer ring, black status ticker, exercise card with set rows, plate preview, add-set affordance, finish-workout pill CTA. ✅ already designed — use as reference.
- **Rest timer expanded view:** full rest timer modal/sheet with dismiss button.
- **Live Activity / Dynamic Island:** rest countdown in red, elapsed workout time when not resting.
- **Post-workout completion:** duration, calories, body map muscles worked, PRs hit (inkPrimary text + underline, not a color), improvement count ("Improved on 4/6 exercises"), caption field, share buttons, save & exit.
- **Cancel workout confirmation:** dialog with warning copy, cancel/keep buttons.

### Batch 3: Programs + Templates

- **Programs tab list:** template cards with swipe-to-delete and overflow menus, no chevron disclosure, `+` button opens preset picker sheet.
- **Preset picker sheet:** Blank / PPL / Upper-Lower / Full Body cards.
- **Template detail:** exercise list with sets/reps/RIR, drag to reorder, edit/delete actions.
- **Template editor:** add exercise, configure sets, optional target reps (nullable), save.

### Batch 4: Social

- **Social feed:** chronological list of posts. Each post = 3D body silhouette (compact), stats summary (PRs, improvement count), caption, like/comment row.
- **Post detail:** full body silhouette, full workout breakdown (no notes), comments thread.
- **Friend list:** username, avatar, streak, mutual workouts. Tap → friend profile.
- **Friend profile:** username, avatar, stats, latest body heatmap, current split, past workouts. Privacy toggle respected.
- **Challenges (Pulse+):** active challenges list, leaderboard, create challenge flow.

### Batch 5: More tab + Settings + Onboarding + Pulse+

- **More tab:** History, Profile, Equipment Profiles, Settings, Tutorial, Pulse+ — list of nav rows.
- **History:** calendar/list toggle, workout cards.
- **Settings:** sectioned list (Account / Units / Theme / Rest Timer / Notifications / Equipment / Subscription).
- **Onboarding:** auth screen → name → weight → height → age → gender → unit pref → experience level → split selection → tutorial prompt.
- **Pulse+ paywall:** benefits list (10 features), pricing tiers (1/2/all-3 apps × monthly/yearly), free trial CTA.

---

## 10. FUEL — SCREEN BATCHES

### Batch 1: Log tab + Food Picker

The flagship. Get this right first.

- **Log tab:** sticky compact header (weekly calorie ring + remaining + weigh-in chip) → date scrubber → meal blocks (with planned/confirmed states) → docked search bar with barcode icon at the bottom.
- **Date scrubber expanded → calendar picker:** month view, copy-day and plan-ahead actions.
- **Food picker (full-screen sheet):** segmented tab strip (Suggestions / Recent / Favorites / My Foods / Recipes / Templates / Scan / AI), search bar always visible, keyboard active on open. Each tab has its own list/grid layout.
- **Food detail sheet (after picking a food):** food name, nutrition table, serving-size selector (grams default + named portions), amount input, meal selector dropdown, "Add" CTA pill.
- **Barcode scanner:** camera view with targeting rectangle, manual-entry fallback.

### Batch 2: Trends Tab

- **Tab top:** segmented control with sub-views (Weight / Calories / Macros / Micros / Adherence / Macro Timing / Workouts).
- **Weight view:** raw dots + smoothed line, time range pills, rate-of-change readout, "ignore week" long-press.
- **Calories view:** daily bar chart + weekly average overlay + target line + adaptive TDEE history line. Days over weekly target colored amber only when 15%+ over.
- **Macros view:** stacked bars by day, weekly averages prominent.
- **Micros view (Pulse+):** weekly avg vs RDI, callouts for consistently low.
- **Adherence view (Pulse+):** log-day consistency, predicted goal-hit date, plateau detection.
- **Macro timing (Pulse+):** when in the day P/C/F is consumed.
- **Workouts view:** passive read-only display of Pump/Stride/HealthKit workouts.

### Batch 3: Recipes + Custom Foods + Weigh-in + Plan-ahead

- **Recipe builder:** name, servings, ingredient list (add from picker, gram amounts), notes. Macros computed live from ingredients.
- **Recipe detail:** ingredients, computed macros per serving, edit/duplicate/delete/share.
- **Custom food creator:** name, brand, serving sizes, calories + macros per 100g, optional micros, "submit to community" toggle.
- **Meal template creator:** items grouped, save as template.
- **Weigh-in entry:** simple weight input, optional note, save to HealthKit toggle.
- **Plan-ahead view:** future-day calendar, blank meal slots, projected daily totals.
- **Weekly meal prep (Pulse+):** 5/7-day grid, weekly projected total, balance helper.

### Batch 4: Onboarding

The most identity-shaping flow. Tone matters as much as visuals.

- **Auth screen:** Apple / Google / Email — three buttons stacked.
- **Setup steps:** name → weight → height → age (with under-16 acknowledgment screen if applicable) → gender → activity level → goal → rate of change → ultra-aggressive warning modal (if selected).
- **Adaptive system explanation:** the 2-week warmup screen with the explanatory copy.
- **Unit prefs.** **Tracking mode selector:** Detailed / Simple / Guided — three cards, each with a one-line explanation.
- **HealthKit permissions:** body weight read, optional workouts read, nutrition write — explained one at a time.
- **Tutorial prompt:** beginner walkthrough vs experienced fast-track.

### Batch 5: More tab + Settings + Paywall

- **More tab:** Profile, Friends, Settings, Data Import, Tutorial, Pulse+.
- **Profile:** username, avatar, stats, streak (discreet), goal display.
- **Settings:** sectioned list (Account / Units / Tracking Mode / Theme / Goal / Notifications / Data Sources / Data Import / Data Export / Subscription / Privacy).
- **Data import:** MFP, MacroFactor, Cronometer cards with file pickers.
- **Pulse+ paywall:** 9 benefit list, pricing matrix, free trial CTA.

---

## 11. PROMPT TEMPLATE FOR EACH BATCH

When prompting Claude Design for a batch, structure your prompt like this:

```
[Paste this entire pulse-design-system.md as system context]

I'm building [Pump | Fuel] — Batch [N]: [batch name].

App-specific context:
- Accent color: [accent/pump | accent/fuel]
- Tab structure: [5 tabs (Programs/Social/Home/Body/More) | 3 tabs (Trends/Log/More)]
- Mode: [Light + Dark, both required]

Screens to build in this batch:
1. [Screen name]
   - Purpose: [one sentence]
   - Key components used (from design system): [list signature components]
   - Specific states needed: [empty / loading / error / etc.]
   - Data shown: [be specific — what numbers, what labels]
   - Interactions: [what taps do what]

2. [Next screen...]

Reference screens that are already designed:
[Attach the existing Pump Home + Logger screenshots if working on Pump]

Build all screens in this batch as a connected prototype. Use the design tokens, components, and motion principles from the design system above. Do not invent new patterns — if something isn't covered in the system, ask before assuming.
```

---

## 12. QUICK CHECKLIST — BEFORE FINALIZING ANY SCREEN

- [ ] All numbers use Space Mono (tabular)
- [ ] All labels are small caps with letter-spacing
- [ ] No drop shadows anywhere
- [ ] No emojis anywhere
- [ ] Primary action is bottom-anchored if it's the screen's main CTA
- [ ] Empty / loading / error states designed
- [ ] Light + dark mode both look right (warm dark, not true dark)
- [ ] Touch targets ≥ 44pt
- [ ] Accent color used only for: primary CTA, active-state indicator, hero data accent
- [ ] Horizontal rules used instead of nested cards where possible
- [ ] Type pills, ticker strips, set rows match the signature component spec exactly
- [ ] No motion uses springs or bounces

---

## 13. OPEN DECISIONS — RESOLVE LATER

A consolidated list of every "decide later" flagged in this doc. Don't lose track of these.

**Resolved (was a placeholder, now confirmed):**
- **Font pairing** — Archivo + Space Mono, both bundled and registered in Pump. No longer SF Pro / SF Mono; no plan to swap to a licensed pairing later. Treat this as decided for Fuel and Stride too.
- **Pump's foundation, signal, and accent hex values** — confirmed via `design_handoff_pulse_color_system/tokens.json` and `README.md`, not screenshot-eyeballed estimates. Section 2 above reflects the confirmed values.

**Locked-in placeholders (intentionally deferred):**
- **Custom icon set.** Currently using whatever Claude Design defaults to (likely SF Symbols or Lucide). Plan: design a thin-stroke custom icon family late in the build, swap into the existing icon slots without layout changes.

**Genuine open questions:**
- **Fuel and Stride accent colors — still unresolved.** Constraint: Fuel must be green, and `signal/up`/`signal/down` must stay green/red, so Fuel's green has to sit hue-separated from `signal/up` (roughly 75–105°, deeper and less saturated than `signal/up`'s ~150°). Sage `#7A9B6E` (current codebase value) was explicitly rejected — same hue as `signal/up`, also read as too muted. Also rejected on taste: teal `#2EBAB5` (too close to Pump's blue), violet `#6B4FD0`, forest `#4A7F38`, olive `#5F7A21`. For Stride, magenta `#D4197A` is viable (4.98:1 vs white, 3.46:1 vs ink) but not confirmed. Do not propose dusty mustard or soft clay for Stride — both collide with `signal/warn`'s amber, now reserved exclusively for Fuel's over-target signal. Any new candidate must clear all four rules in `design_handoff_pulse_color_system/README.md` before being treated as confirmed.
- Exact body-model customization tiers in Pump (free vs Pulse+) — placeholder for now
- Body-map sub-navigation (swipe vs toggle vs segmented) — currently using TabView page swipe
- Specific widget visual designs (functional placeholders matching this system are fine)
- Live Activity for Fuel (running meal total in Dynamic Island) — decided as nice-to-have, not V1 blocker
- Keyboard / input field styling treatment
- Toast / snackbar pattern for non-modal feedback
- Search result row pattern (used by Pump global search and Fuel food picker)
- Chart specifics beyond "raw dots + smoothed line" — bar widths, axis treatment, gridlines

---

*End of Pulse Design System. Update this document whenever a new pattern is introduced. It is the single source of truth.*
