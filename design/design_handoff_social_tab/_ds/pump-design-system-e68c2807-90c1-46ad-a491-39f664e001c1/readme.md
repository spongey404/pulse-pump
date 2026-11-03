# Pump Design System

Pump is an iOS workout-logging app and one of three apps in the **Pulse** ecosystem, alongside **Fuel** (nutrition) and **Stride** (running). The three are the same app dressed differently: identical tokens, typography, spacing, components, motion and iconography, differing only in accent colour, tab structure and app-specific surfaces. A user moving between them relearns nothing.

The stated aesthetic is **"Bloomberg Terminal meets workshop manual"** — dense, monospace-numeric, data-confident, warm. Pump sits deliberately between Apple Health (clinical, sterile) and Strong/Hevy (bro-coded, busy). It takes monospace numerics, triangular trend arrows, tabular alignment and ticker strips from financial UIs; thin horizontal rules, small-caps labels and generous label tracking from print and editorial; and an earthy palette with dashed-border placeholders from utility and workshop manuals.

The core promise: log your workouts, let the app learn your patterns, predict what you should do next, and track progress with financial-dashboard clarity.

## Sources

Everything here was built by reading these. The reader is not assumed to have access; the references are recorded so they can be followed if they do.

- **GitHub — `https://github.com/spongey404/pulse-pump`** (branch `main`). The Swift/SwiftUI app, the HTML design prototypes and the design documents. Worth exploring further before designing anything for this product — in particular:
  - `PULSE_PUMP_DESIGN_REFERENCE.md` — screen-by-screen spec, signature components, interaction patterns
  - `pump and fuel design html files/uploads/pulse-design-system.md` — the ecosystem-wide Pulse system (Pump + Fuel + Stride)
  - `pump and fuel design html files/*.html` — pixel-level Claude Design prototypes for Home, Logger, Post-Workout, Muscle Map, Social Feed, Programs
  - `PulsePump/Views/**` — the shipping SwiftUI implementation
  - `PumpApp/constants/theme.ts` — the React Native token mirror (radii, spacing, plate and set-type colours)
- **Project uploads** — `uploads/PULSE_PUMP_DESIGN_REFERENCE.md` and `uploads/pulse-pump-spec.md`, the same two documents attached directly.
- **Brand direction supplied in conversation** — the blue accent, the cream/charcoal canvases, the PR-as-underline rule, the amber prohibition and the light-mode ticker behaviour. **Where this conflicts with the repository, this direction wins**; see "Colour history" below.

### Colour history — read before trusting an old file

The accent has moved three times. In order: terracotta `#C8553D` (design reference and HTML prototypes), hot pink `#FD4A9F` (`CLAUDE.md` in the repo, and the shipping Swift), and now **blue `#0A6FC0`**. Anything in the repo showing terracotta or pink is superseded. The structural values in those files — dimensions, radii, type sizes, grid columns — are still authoritative and were copied here exactly.

## Index

| Path | What it is |
|---|---|
| `styles.css` | Global entry point. Import this one file. `@import` lines only. |
| `tokens/colors.css` | Base palette + semantic aliases, light and `[data-theme="dark"]` |
| `tokens/typography.css` | Font stacks, the four-level hierarchy, the data scale |
| `tokens/spacing.css` | 4pt grid, radii, border and row-height tokens |
| `tokens/motion.css` | Durations and easings |
| `tokens/fonts.css` | `@font-face` for Archivo and Space Mono |
| `assets/fonts/` | Archivo (300/400/600/700/900) and Space Mono (400/700) TrueType, copied from the repo |
| `guidelines/*.card.html` | Foundation specimen cards — colour, type, spacing, brand |
| `components/` | Reusable primitives (below) |
| `ui_kits/pump/` | Click-through recreation of the app's core screens |
| `templates/pump-screen/` | "Pump app screen" — a phone-screen scaffold (ticker, masthead, stat row, docked CTA, tab bar) to start a new screen from |
| `SKILL.md` | Agent Skills wrapper for use in Claude Code |

## Components

Grouped by concern. Each directory has a `@dsCard` specimen HTML; each component has a `.d.ts` props contract and a `.prompt.md` usage note.

**`components/data/`** — `TickerStrip`, `KPIBlock`, `TrendValue`, `WeekBars`, `ConfidenceDots`
**`components/logging/`** — `ExerciseCard`, `SetRow`, `SetTypeChip`, `PlateBar`
**`components/controls/`** — `DockedCTA`, `DayScrubber`, `FilterChip`, `DashedAdd`, `SectionLabel`
**`components/navigation/`** — `TabBar`, `Masthead`, `RestTimerPill`
**`components/feedback/`** — `PRMark`, `EmptyState`

This inventory is the source's own list of signature components (`pulse-design-system.md` §4 and `PULSE_PUMP_DESIGN_REFERENCE.md` §5), not a generic primitive set. There is no Button, Input, Select, Switch or Toast here because the sources define none — Pump's actions are the docked CTA, the filter chip and the dashed add.

### Intentional additions

- **`SectionLabel`** — the sources describe the small-caps tracked label as a rule rather than a component. It is used on every screen, so it is packaged as one to stop consumers hand-rolling the tracking.
- **`PRMark`** — the sources describe the PR treatment in prose (and the older files show a gold badge). Packaging it as a component is how the current no-colour rule gets enforced.

### Not built

- **Body heatmap silhouette** — front/back anatomical SVG with a thermal scale, used on the Muscle Map tab, the share card and the social feed. No SVG asset exists in the sources, and drawing an anatomical figure from memory would be an invention rather than a recreation. Flagged for the user to supply.
- **Muscle Map and Social Feed screens** depend on it and are therefore omitted from the UI kit.

---

# CONTENT FUNDAMENTALS

**Voice.** Flat, factual, mechanical. Pump reports; it does not encourage. The app never congratulates, never scolds, never says "let's". Closest register: an instrument readout with good manners.

**Person.** Mostly none — labels are nouns, not sentences. Where a sentence is needed the app addresses the user as *you* ("Your progress on Push Day will be lost."). Onboarding is the one warm place and uses first-person plural: *"What should we call you?"*

**Casing — the load-bearing rule.**
- Metadata, labels, units, timestamps, column headers, section headings: **ALL CAPS, Space Mono, tracked**. `SETS` · `VS LAST` · `PR WATCH` · `4 DAYS/WK` · `2 DAYS AGO` · `WK 14 · APR 13–19`
- Screen titles and primary CTAs: **ALL CAPS, Archivo 900**. `PROGRAMS` · `START WORKOUT` · `FINISH WORKOUT ›`
- Workout and exercise names in running content: **Title Case**. `Push Pull Legs` · `Overhead Press`
- Body copy and descriptions: **sentence case**, full stops. `Pause at bottom. Felt strong.`

**Numbers.** Always Space Mono, always tabular, always with the unit as a separate tracked label (`100` + `KG`, not "100kg"). Deltas carry a triangle and a sign: `▲ +12.5%`, `▼ -25.0%`. Counts of things done out of things planned use a slash: `4/6`, `94 / 132`, `9/28 SETS DONE`.

**Separators.** The middle dot ` · ` does almost all the work: `PUSH · 24:18`, `TODAY · PPL`, `BARBELL · PR 105×4 · 1RM ~118`. Never commas in metadata lines, never pipes.

**Empty states.** One line of fact, one line of consequence, one action. *"No workouts yet."* → `START FIRST WORKOUT`. *"No templates saved."* → `CREATE TEMPLATE`. Never a mascot, never a pep talk.

**Errors.** Quiet, in `--signal-down`, always with a retry. *"Couldn't reach the server. [Retry]"* · *"Network unavailable. Changes saved locally and will sync."*

**What Pump never writes.** No emoji anywhere in the UI — emoji are permitted only inside user-typed captions and notes. No exclamation marks. No streak-loss messaging; streaks break silently. No shaming, no urgency, no "limited time", no countdown copy on the paywall.

---

# VISUAL FOUNDATIONS

**Palette.** One accent on a warm neutral ground, and nothing else. The canvas is warm cream `#F9F8F4` in light mode and warm dark charcoal `#1A1917` in dark — never true white, never true black; warm dark is what preserves the analog feel. Elevation is a warmer tint (`#F4F0E6` / `#252220`), sunken is a cooler one (`#ECE7D8` / `#2E2A26`).

The accent is blue. It is **flat `#0A6FC0` on filled surfaces** — CTAs, the raised tab-bar Home key, selected chips — in both modes, and **lifts to `#4DB8FF`** for text, glyphs and borders on the dark canvas. The accent is only ever used for the primary CTA, the active-state indicator and the one hero data accent. Never for body text, never decoratively.

Signals: green `#00AA55` is a positive delta and nothing else — it never fills a surface. Red `#C0341A` is a negative delta and destructive actions. **Amber `#C9892E` is reserved for the sibling app Fuel's "over target" signal and never appears in Pump**, including for PRs.

Only one row or element on a screen is ever tinted — the active set row. Completion is carried by the check control, not a background colour.

**Ticker exception.** The spec calls the stock ticker strip always-dark. Pump deliberately breaks that in light mode and uses a cream bar `#F0EBE0`, which means its up-arrow green darkens to `#2A7A4A`; the bright `#00E07A` washes out on a light ground. Dark mode keeps `#0E0C0A` and `#00E07A`.

**Typography.** Two voices. **Archivo** carries everything a human wrote; **Space Mono** carries every number, label, unit, timestamp and column header, always uppercase, always tracked 1.2–2px. Tabular alignment depends on it; a number set in Archivo is a bug. The hierarchy is four levels — Archivo 900 at 24–28px for screen titles and CTAs, 700 at 18–22px for content titles, 600 at 14–16px for list rows, then Space Mono 400 at 8–10px all-caps for everything else. Archivo 300 appears in exactly one place: conversational onboarding headings, where the light weight creates warmth against the heavy UI. Emphasis is by weight only, never italic — the single italic exception is the "last session note" quote in the workout logger.

**Layout.** Prefer horizontal rules over card containers. Cards group at the top level only; inside a card, hairline rules divide and label/value pairs align in columns. Edge-to-edge dividers within their container. Numbers align in columns, labels left, values right. Screen edge padding 16px, card padding 12–14px, 24px between unrelated sections. Row heights never below 44px. The primary action is bottom-anchored for one-handed thumb reach; headers shrink on scroll rather than snapping.

**Backgrounds and imagery.** Flat colour only. No gradients, no photography, no illustration, no texture, no repeating pattern, no full-bleed imagery. The only image content in the product is user-supplied — an optional workout photo in a social post. There is no brand imagery to have a colour vibe.

**Borders, rules and shadows.** **No drop shadows anywhere** — elevation is background tint, full stop. Rules are 0.5–1px at 8% ink (`--rule-hair`), or 14% for a stronger break. A surface takes either a hairline border or an elevated background, never both. The active row takes a 2px accent left border plus `--accent-row`. Dashed borders — 1px, 4px dash, 4px gap — are reserved exclusively for "add" affordances and appear nowhere else.

**Corner radii.** 4px chips and type pills, 8px controls and sheets, 12px primary CTAs, 14px cards. 999px is allowed for exactly two things: filter chips and date pills. A pill-shaped primary CTA is wrong; so is a circular day selector — day tiles are 8px rounded rectangles.

**Cards.** `--surface-elevated` background, 14px radius, one hairline border, no shadow. Header row, then a sunken column-header strip, then rows divided by hairlines. Never a card inside a card.

**Transparency and blur.** Almost never. Blur appears only behind a modal scrim (`rgba(31,28,25,0.45)` + 6px blur) and behind the tab bar. Everything else is opaque. Alpha is used for ink levels and 8–13% colour tints, not for glass effects.

**Motion.** Precise and analog. Default 250ms ease-in-out; 150ms ease-out for micro-interactions and tap states; 350ms for sheets; 200ms for drag-settle. The ticker marquees at 40px/sec, linear, continuous. **No spring physics, no overshoot, no bounce, no confetti, no particles, no celebration animation.** The body silhouette's idle rotation is a sine wave, 6s period, ±25°. Loading is skeleton rows shaped like the real content, never spinners (except a full-screen blocking operation).

**Hover and press.** This is a touch product; hover is a desktop-preview courtesy only, expressed as a slight background tint, never a colour change. Press states darken the filled surface (`#0A6FC0` → `#08589A`) or drop opacity to 0.7 for text controls. Scale-down on press exists in the shipping Swift at 0.95–0.97 — use it sparingly and never with a spring.

**Fixed elements.** The status bar and masthead pin to the top; the ticker sits directly under the masthead; the primary CTA docks above the tab bar; the tab bar pins to the bottom with a 0.5px top hairline. Everything between them scrolls.

**Protection.** No scrims over imagery, because there is no imagery. Docked elements sit on an opaque canvas-coloured bar with a top hairline rather than a fade.

---

# ICONOGRAPHY

**The system is SF Symbols, and the sources say so explicitly.** The shipping SwiftUI code uses SF Symbol names throughout (`list.bullet.clipboard`, `person.2`, `house`, `figure.stand`, `ellipsis`, `medal.fill`, `flame.fill`). The HTML prototypes, which cannot use SF Symbols, hand-draw the equivalent glyphs as inline `<svg>` at 1.6px stroke on a 24×24 box — that is the substitution the source itself made, and this system follows it.

There is **no icon font, no sprite sheet and no icon SVG files in the repository** — nothing to copy in. For web work, use **Lucide** (`https://unpkg.com/lucide-static`) as the CDN substitute: same geometric construction, same 24×24 box, and it can be set to a 1.6px stroke to match. **This is a substitution, flagged as such** — the sources plan a custom thin-stroke Pulse icon family late in the build, and this system should be updated when those assets exist.

Rules that hold regardless of which set is used:
- Stroke weight 1.6px on 24×24. Regular weight in SF Symbols terms.
- **Never a filled icon outside the selected/active state.** A static "favourites" label uses `heart`, not `heart.fill`.
- Sizes: 16px inline with body text, 20px for controls, 24px in the tab bar, 28px+ for hero and empty-state glyphs (rendered at 0.18 opacity).
- Icons are ink-coloured, not accent-coloured. The one accent glyph on screen is the white barbell inside the raised tab-bar Home key.

**Non-icon glyphs that are part of the system.** The triangles `▲` `▼` for trends, the middle dot `·` as a separator, the check `✓` for a completed set, the chevron `›` for forward motion, and the three-dot `···` overflow. These are typed characters in Space Mono, not icons, and they are load-bearing — do not replace them with SVG.

**Emoji are never used in the UI.** The only place emoji appear in the product is inside a user's own caption or note, and in the social reaction picker, which is user-content territory rather than chrome.

**Logo.** There is no logo asset in the sources and none has been created here. The brand mark is a **16px solid accent square** beside **PULSE/PUMP** set in Space Mono 700 at 10px with 2px tracking — that is the masthead treatment in both the Swift app and the prototypes, and the same lockup is the share-card watermark. The display name on device is simply *Pump*. Do not draw or reconstruct a Pulse logo; if a real mark exists, drop the file into `assets/` and replace the square.
