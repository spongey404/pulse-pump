# Handoff: Pump — Social tab (Friends feed + Challenges)

## Overview

This is the full design for the **SOCIAL** tab of Pump, the iOS workout-logging app in the Pulse ecosystem. It covers two sub-tabs (FRIENDS, CHALLENGES) plus every screen reachable from them: the post composer that runs at the end of a workout, friend and global leaderboards, challenge creation and invitation, friend discovery, profiles, comments, activity, privacy, empty states, and the admin screen for the monthly global challenge.

The shipping app today (`PulsePump/Views/Social/`) has an `ActivityFeedView` with a two-slide carousel and a `FriendsListView` that is an unstyled SwiftUI `List`. Everything in this handoff replaces that.

**Repo:** `spongey404/pulse-pump`, branch `develop`. See `github.md` at the project root for the screen-to-source map.

## About the Design Files

`Friends Feed.dc.html` is a **design reference created in HTML** — a prototype showing intended look and behaviour. It is not production code to copy. The task is to **recreate these designs in SwiftUI** inside the existing `PulsePump` app, using its established patterns, its `Color+Theme` / `Font+Design` extensions, and the Pump design system tokens.

The HTML file renders every screen as a 390×844 phone frame laid out on a canvas, grouped into numbered turns. **Turns 3 through 7 are the current design. Turns 1 and 2 are superseded exploration and should be ignored** — they are retained only as a record of why the final structure was chosen.

## Fidelity

**High-fidelity.** Final colours, typography, spacing, and interaction behaviour. Recreate pixel-accurately. All colour values are design-system tokens (see Design Tokens below) — use the token, not the literal hex, wherever one exists.

---

## Design system

Everything is built on the **Pump Design System** (`_ds/pump-design-system-e68c2807-90c1-46ad-a491-39f664e001c1/`). Rules that govern every screen below:

- **Two typefaces only.** Archivo carries anything a human wrote. Space Mono carries every number, unit, label, timestamp and column header — always uppercase, always tracked 1.2–2px. A number set in Archivo is a bug.
- **No drop shadows anywhere.** Elevation is background tint.
- **Rules over containers.** Hairline dividers (`--rule-hair`, 8% ink) instead of nested cards. A surface takes either a hairline border or an elevated background, never both.
- **Dashed borders are reserved exclusively for "add" affordances.**
- **Row heights never below 44px.** Touch targets never below 44px.
- **One accent** (`--accent`, blue) for the primary CTA, the active-state indicator, and one hero data accent. Never body text, never decoration.
- **Green is a positive delta only** — never a filled surface. Red is a negative delta and destructive actions.
- Radii: 4px chips, 8px controls and sheets, 12px primary CTAs, 14px cards. 999px only for filter chips and date pills.

### Deliberate deviations from the system

Three, all intentional, all agreed with the designer:

1. **Gold `#C9892E` marks PRs.** The system reserves amber for the sibling app Fuel and specifies PRs as ink + underline. The designer overrode this. Gold PR marks carry a soft glow: `text-shadow: 0 0 10px rgba(201,137,46,0.5)` at small sizes, `0 0 12px rgba(201,137,46,0.45)` at 22px+.
2. **Leaderboard medals.** Ranks 1/2/3 are gold `#A06E1E`, steel `#6E7C87`, bronze `#96602A`, on both the rank number and the athlete name, each with a matching glow. These are darkened from the obvious medal colours to clear 4.5:1 contrast on cream. Ranks 4+ are `--text-muted`.
3. **`Masthead` is not used.** The design-system `Masthead` renders a PULSE/PUMP wordmark lockup when given no overline. Screen titles here are a plain `Archivo 900 28px, letter-spacing 0.5px, --text-primary` in a `padding: 2px 16px 10px` container.

### Design-system components used

Mount these rather than rebuilding: `TickerStrip`, `KPIBlock` (compact variant), `SectionLabel`, `DashedAdd`, `FilterChip`, `TabBar`, `DockedCTA`.

`KPIBlock` compact renders label + value + delta only — it ignores a `denominator` prop. Where a stat needs a coloured value (IMPROVED in green, PRS in gold), the design uses a hand-built twin typed to match exactly: label is `Space Mono 400 7px, letter-spacing 1.2px, uppercase, --text-muted, margin-bottom 3px`; value is `Archivo 900 22px, line-height 0.9`.

### BodyHeat (custom component — `BodyHeat.dc.html`)

The muscle heat-map silhouette. **The design system does not include this** — it is flagged as "not built" there because no SVG asset existed. This one was reconstructed from the repo's own `pump and fuel design html files/_mm_src.html` BodyMap path set.

- **Geometry:** `viewBox="0 0 200 320"`, aspect ratio 0.625. Always give it an explicit width matching that ratio (e.g. 69×110, 75×120, 150×240) — `width: auto` has no intrinsic size and will absorb flex space.
- **Regions:** `traps`, `chest`, `shoulders`, `biceps`, `forearms`, `core`, `glutes`, `quads`, `calves`. Each takes a 0–1 intensity; empty or absent renders the base fill.
- **Thermal ramp** (5 stops, linear interpolation between them):
  `0 → rgb(236,229,214)` · `0.2 → rgb(184,217,242)` · `0.45 → rgb(107,176,232)` · `0.7 → rgb(26,131,214)` · `1 → rgb(10,111,192)`
- **Themeable base/stroke:** `base` (default `rgba(31,28,25,0.035)`) and `stroke` (default `rgba(31,28,25,0.07)`) props. On a dark surface pass `base="rgba(236,229,214,0.10)"` and `stroke="rgba(236,229,214,0.12)"`.
- The reference session used throughout is Push Day: `chest 0.95, shoulders 0.78, biceps 0.8, traps 0.3, core 0.18`.

---

## The story

A user finishes a workout. Pump has already logged every set, so it knows the session is worth sharing without asking. It shows the composer (**7a**) with the post already built — the share card is the post. One tap posts it; the overflow declines. The session is saved either way.

Friends see it in the feed (**4a**) as a photo plus a body map. Tapping the map opens the whole session — every exercise, every set. They react or comment (**6c**).

Separately, friends compete. Anyone creates a challenge (**5a**, **5b**) scored on something Pump already logs, so nobody self-reports. Progress shows on a leaderboard (**3c**). Once a month the Pulse admin sets a global challenge everyone can enter (**3b** top, **3d**, admin at **6f**). When a challenge ends, there is a result (**7b**).

---

## Screens

Screen IDs below match the badge on each option in the HTML file.

### 7a — Post composer (`SESSION DONE` → post)

**Purpose.** The end of a workout. The user decides whether the session becomes a post. This is the input to the entire tab.

**Layout, top to bottom:**

| Element | Spec |
|---|---|
| Header | `padding: 4px 16px 10px`, `border-bottom: 0.5px solid --rule-hair`, flex row, gap 12. Back chevron `‹` Space Mono 400 20px. Centre block: overline `WORKOUT COMPLETE` Space Mono 400 8px / 1.5px tracking / `--text-muted`, then `PUSH DAY` Archivo 900 22px / 0.5px / line-height 1. Right: `SAT 2 MAY` Space Mono 400 9px / 1.5px / `--text-muted`. |
| Post preview card | `margin: 12px 16px 0`, `background --surface-elevated`, `border 1px solid --rule-hair`, `radius 14px`, overflow hidden. Contains the share card (below). |
| Photo (optional) | Only when attached. `margin: 10px 16px 0`, height 170, radius 12, `background --surface-inverse`. REMOVE pill top-right: Space Mono 700 8px / 1.2px, `#F9F8F4` on `rgba(31,28,25,0.6)`, radius 999, `padding 6px 10px`. |
| Caption row | `margin: 12px 16px 0`, flex, gap 12. 36px round avatar (1px `--rule-strong` border). Field: flex 1, `border-bottom 1px --rule-hair`, min-height 44, placeholder "Add a caption" Archivo 400 15px `--text-muted`. Photo button: 44×44, 22px camera glyph stroked `--accent-text` — **hidden once a photo is attached**. |
| TAG FRIENDS | `SectionLabel` with meta `FRIENDS ONLY ›`, `padding: 20px 16px 8px`. Then chips row, `padding: 0 16px`, gap 8, wrapping. |
| Tag chip | flex, gap 7, `padding: 6px 12px 6px 6px`, `border 1px solid --rule-strong`, radius 999. 22px round avatar on `--surface-sunken`, name Archivo 600 13px. |
| ADD chip | Same shape, `border 1px dashed --rule-strong`. `+` Space Mono 400 12px + `ADD` Space Mono 700 9px / 1.2px, both `--accent-text`. |
| Docked bar | Absolute bottom. `padding: 10px 16px 26px`, `background --surface-canvas`, `border-top 1px solid --rule-hair`, flex, gap 10. **POST**: flex 1, height 52, radius 12, `background --accent`, centred label Archivo 900 15px / 0.5px / `#FFFFFF`. **Overflow**: 52×52, radius 12, `border 1px solid --rule-strong`, 20px `···` glyph filled `--text-muted`. |

**Share card contents** (inside the preview card, `padding: 14px`):
1. `TickerStrip` full-bleed at top — items: `BENCH ▲ PR +5KG`, `OHP ▲ PR +2KG`, `VOL ▲ 8.4%`.
2. Title block: `SAT 2 MAY 2026` Space Mono 400 9px / 1.6px / `--text-muted`; `PUSH DAY` Archivo 900 32px / 0.5px / line-height 0.88. Right-aligned: `DURATION` label + `58:42` Space Mono 700 20px.
3. Four-up stats, `padding 10px 0`, hairline top and bottom, centre-aligned: SETS `30`, VOLUME `13.4K`, STREAK `13D`, PRS `2` (gold + glow).
4. Body map row: BodyHeat 69×110 beside the improved block — `6` Space Mono 700 42px `--signal-up`, then `OF 9` / `IMPROVED` stacked in Space Mono 400 9px/8px. Below a hairline: `2 NEW PRS` Archivo 900 15px gold + glow, then `BENCH PRESS +5KG` with the delta in `--signal-up` 700.
5. Exercise table, grid `1fr 30px 62px 24px`, gap 6. Header row Space Mono 400 7px / 1.5px / `--text-muted`: EXERCISE · SETS · BEST SET · ▲. Data rows `padding 6px 0`, hairline bottom.
6. Watermark: 7×7 `--accent` square (radius 2) + `PULSE / PUMP` Space Mono 400 8px / 1.5px / `--text-muted`.

**Overflow sheet** (from the `···`): scrim `rgba(31,28,25,0.45)` + 6px blur, sheet from bottom, radius `8px 8px 0 0`, 36×4 grab handle. `SectionLabel`: `SESSION SAVED EITHER WAY`. Three rows, each min-height 56, hairline-separated, Archivo 600 16px title + Space Mono 400 8px / 1.2px `--text-muted` note, trailing `›`:
- **Don't post** — `STAYS IN YOUR HISTORY, NOBODY SEES IT`
- **Post without body map** — `STATS AND PHOTO ONLY`
- **Never post automatically** — `TURNS THIS SCREEN OFF FOR GOOD`

> **Open product question:** the third item implies posting is the default after every session. If posting should be opt-in, the composer becomes a prompt and that row is removed.

---

### 4a — Feed post (recommended feed treatment)

**Purpose.** How a friend's session reads in the feed.

- **Masthead** `SOCIAL`, then sub-tabs FRIENDS / CHALLENGES: Space Mono 700 10px / 1px, `padding 10px 14px`, active gets `--text-primary` + `border-bottom 2px solid --accent`, inactive `--text-muted` + transparent border.
- **Post header:** 38px round avatar, name Archivo 600 14px + handle Space Mono 400 9px `--text-muted` inline, meta line `PUSH DAY · 58:42 · YESTERDAY` Space Mono 400 9px. Trailing `···` 18px.
- **Media carousel — exactly two slides**, height 330:
  - **Slide 1:** the photo, `background --surface-inverse`. Tap advances.
  - **Slide 2:** the body map on `--surface-sunken`, BodyHeat at height 290, centred. Per-muscle set counts stacked top-left (`CHEST 12`, `SHLDR 7`, `TRI 7` — label Space Mono 400 7px / 1.5px, value Space Mono 700 14px). Bottom-right: `FULL SESSION ›` in `--accent-text`. **Tapping this slide opens the session sheet, it does not advance.**
  - Counter pill top-right: `1/2` Space Mono 400 8px on `rgba(31,28,25,0.55)`, radius 999, `padding 3px 8px`.
  - Dots below the media, `padding 8px 0 2px`: 5px tall, active 16px wide `--text-primary`, inactive 5px `--text-ghost`.
- **Four-up stats:** `padding 10px 16px`, grid of 4, gap 6 — SETS, VOLUME, IMPROVED (green value, muted denominator), PRS (gold + glow).
- **Caption:** Archivo 400 13px / 1.45, name in 700 inline.
- **Reactions:** flex, gap 22, `padding 4px 16px 14px`. Each is icon + count in a 44px-min-height target: 24px stroked glyph (`--text-muted`, stroke-width 1.6) + count Space Mono 700 14px `--text-primary`. **No borders, no pills.** The heart is a like; the speech bubble opens comments.
- Posts are separated by `height 1px; background --rule-strong`.

**Session sheet** (opens from slide 2). Scrim + blur, sheet `top: 64px` to bottom, radius `8px 8px 0 0`, **flat — no card shell inside it**:
- Header: `JAY · SAT 2 MAY` overline, `PUSH DAY` Archivo 900 24px, `CLOSE ✕` right.
- `TickerStrip` full-bleed.
- BodyHeat 69×110 beside a 2×2 of KPIBlocks (SETS, VOLUME, DURATION, PRS-gold).
- **Every exercise in the session**, nothing truncated. Each: name Archivo 700 15px uppercase 0.3px tracking (gold if PR), `PR` mark, delta right (`▲ +5KG` in `--signal-up`, or `—` muted), volume line beneath, then per-set chips — `padding 5px 9px`, `border 1px solid --rule-hair`, radius 6, set number Space Mono 400 8px muted + value Space Mono 12px (700 and coloured when it is the best set).
- **Like and comment at the end of the list**, above the watermark, behind a hairline. Deliberately not docked: the sheet is a reading surface, and a docked bar would cost 56px on every scroll to serve an occasional action.

### 3a — Feed post, collapsed variant (alternative)

Same post, but the summary is four stats plus a single tappable row — `9 EXERCISES · CHEST · SHOULDERS · TRI ›`, min-height 44, hairline top and bottom — which expands the full table in place with a `COLLAPSE ›` row at the end. Two posts fit on screen instead of one. Build **either 4a or 3a**, not both.

---

### 3b — Challenges tab

- **Global challenge card** at top. `SectionLabel` `THIS MONTH · GLOBAL` / meta `ENDS 31 AUG`. Card: `--surface-elevated`, 1px `--rule-hair`, radius 14. Inside: `SET BY PULSE · 1–31 AUG` overline, `TOTAL VOLUME` Archivo 900 26px, rule description. Then a three-up of KPIBlocks (YOUR TOTAL `48.2K`, RANK `47` with delta `OF 2,412`, TO NEXT `1.4K`) divided by vertical hairlines. Action row: `padding 8px 14px`, min-height 40, `VIEW LEADERBOARD` Archivo 900 14px `--accent-text` + `›` 14px.
- **FRIEND CHALLENGES** `SectionLabel`, meta `3 ACTIVE`. Each row: hairline top, name Archivo 700 17px + time-left meta right, metric + participant line, then YOU and POSITION KPIBlocks with a trailing `›` 14px marking it tappable through to the leaderboard.
- **`DashedAdd`** `CREATE CHALLENGE` at the end.

### 3c — Friend challenge leaderboard

- Header with back chevron and challenge name Archivo 900 22px.
- Meta line + `+ INVITE` as a quiet `--accent-text` link on the right (not a docked button).
- Three-up: YOUR COUNT, POSITION, ENDS.
- Board, grid `22px 32px 1fr 54px 44px`, gap 10, rows min-height 56: rank (medal-coloured) · 32px avatar · name (medal-coloured) · count · MOVE.
- **Your row** gets `background --accent-row` and `border-left 2px solid --accent`.
- **MOVE column:** `▲ n` in `--signal-up` for places gained, `▼ n` in `--signal-down` for places lost, `—` muted for unchanged.
- ACTIVITY list below: who logged what, hairline rows.

### 3d — Global monthly leaderboard

- GLOBAL / FRIENDS `FilterChip` pair filters the same board.
- Grid `22px 32px 1fr 76px 40px`. Top 5, then `· · ·`, then ranks 45, 46, 48, 49 — the neighbourhood around the user.
- **Your row is pinned** above the tab bar: min-height 60, `--accent-row`, accent left border, with `1.4K TO 46TH` under your name.

### 5a — Create challenge, step 1

- Header `NEW CHALLENGE`, back chevron only — no cancel.
- NAME field: `border-bottom 1px --rule-strong`, value Archivo 700 20px with an accent caret.
- **MEASURED BY** — five selectable rows, min-height 56, hairline-separated. Selected gets `--accent-row` + accent left border + Archivo 700 + `✓` in `--accent-text`. Each shows unit and rule in Space Mono 400 8px:
  | Metric | Unit | Rule |
  |---|---|---|
  | Total volume | KG LIFTED | Every working set, summed |
  | Heaviest lift | BEST 1RM | Top estimated single, one exercise |
  | Most reps | REPS | Every rep logged, summed |
  | Sessions logged | WORKOUTS | Any session over 10 minutes |
  | Custom | YOU DEFINE | Pick an exercise and what to count |
- **Selecting Custom reveals three inline rows**: EXERCISE, COUNT BY, TIE BREAK — label left in Space Mono, value right in Archivo 600 15px with a `›`.
- **RUNS FOR** chips, wrapping: `1 WEEK` · `4 WEEKS` · `REST OF AUG` · `1 YEAR` · `CUSTOM`. Selected is filled `--accent` with white text.
- Footnote: `SCORED FROM LOGGED SESSIONS · NOTHING TO ENTER BY HAND`.
- Docked: quiet row, `STEP 2 · INVITE FRIENDS` left in Space Mono, `NEXT ›` right in Archivo 900 14px `--accent-text`. Not a filled slab.

### 5b — Invite friends, step 2

- Header `INVITE FRIENDS`, `SKIP` right.
- Context line: `AUGUST VOLUME · TOTAL VOLUME · 4 WEEKS`.
- Search field, then friend rows min-height 60 with an INVITE/INVITED pill toggle (filled accent → outlined muted). Each row shows when they last trained, so the user knows who is actually active.
- `NOT ON PUMP` → `DashedAdd` `SHARE INVITE LINK`.
- Copy: `THE LINK STAYS OPEN FOR THE WHOLE CHALLENGE · LATE JOINERS ARE SCORED FROM THE DAY THEY JOIN`.
- Docked: `n INVITED` left, `DONE ›` right. **No create button** — the challenge already exists by this step.

> **Open product question:** late joiners scored from their join date keeps totals honest but puts them structurally last on a cumulative metric. A per-day average would let them compete but is a different number from what everyone else started measuring. Not yet decided.

### 6a — Add friends

Search · REQUESTS (ACCEPT filled / IGNORE outlined, rows min-height 64) · SUGGESTED with mutual counts and a FOLLOW pill · `DashedAdd` SHARE INVITE LINK.

### 6b — Friend profile

Avatar 60px, handle overline, FOLLOWING pill. Four-up: STREAK, THIS WK, VOLUME, PRS (gold). BodyHeat 75×120 for the last 30 days beside a per-muscle set list. **THIS WEEK · 5 OF 7 DAYS** — seven rows, one per day, rest days rendered muted with no chevron and `—` for sets; training days tap through to the session sheet.

### 6c — Comments

**A sheet sliding up over the post, not a separate screen.** The post header and photo stay visible above a `rgba(31,28,25,0.45)` + 6px blur scrim; the sheet starts at `top: 230px` with a grab handle. Comment rows: 32px avatar, name Archivo 700 14px + timestamp, body Archivo 400 14px / 1.45. Actions: a 16px heart with a like count, and REPLY. Composer docked inside the sheet.

> The shipping app labels the like action `HOLD` (Pump's own term). That reads as a brand flourish next to a heart and a count on a post; on a bare comment row it is unexplained, so comments use a heart + count instead.

### 6d / 6e — Empty states

Both follow the system pattern: one line of fact, one of consequence, one action.
- **6d, no friends:** 40px glyph at 0.18 opacity, "No friends yet." Archivo 700 20px, "Sessions from people you follow appear here." then a filled `FIND FRIENDS` button.
- **6e, no challenges:** the global card still shows with a `JOIN` action; below it "No friend challenges." and `DashedAdd CREATE CHALLENGE`.

### 6f — Admin (monthly global challenge)

Gated. `ADMIN` badge in the header (Space Mono 700 8px, white on `--text-primary`, radius 4). RUNNING section shows the live challenge with entry count and days left. NEXT UP: name field, the same MEASURED BY list, and two toggles — **Announce on 1 Sep** (`PUSH TO EVERYONE ON PUMP`) and **Show full leaderboard** (`OFF SHOWS TOP 50 AND YOUR RANK ONLY`). Docked: `STARTS 1 SEP · 00:00 LOCAL` + `SCHEDULE ›`.

### 6g — Activity and privacy

`NEEDS YOU` — challenge invites and friend requests with two actions each. `EARLIER` — quieter events. `PRIVACY` — four rows: Workout posts, Body map, Global leaderboards, Profile; each with its current value and a note explaining exactly what is exposed.

> Two placement calls worth revisiting: challenge invites live here rather than as a push interrupt, and privacy sits at the bottom of Activity rather than in Settings — on the theory that this is where people look after seeing something they did not expect to be public.

### 7b — Challenge ended

Header + `ENDED 2 AUG` pill (filled `--surface-sunken`, no border). **Winner row** — a single horizontal band bounded by hairlines: 44px avatar · `WINNER` / `PRIYA` in medal gold with glow · `BEST` / `112KG` right. Three-up: YOU FINISHED `2ND`, YOUR BEST `105KG`, GAINED `+5KG` in green. Final board with medals and a per-person GAINED column. Docked: `SAME METRIC, NEW 4 WEEKS` + `RUN IT AGAIN ›`.

### 7c — Your profile

Like 6b but yours: `EDIT` in the header, `SHARE` pill for your handle, your four stats, then **FOLLOWING** — every person you follow with an `UNFOLLOW` pill. This is the only place a friend can be removed. `DashedAdd FIND FRIENDS` at the end.

---

## Interactions & behaviour

| Trigger | Result |
|---|---|
| Tap feed photo (4a slide 1) | Advance to body map |
| Tap body map (4a slide 2) | Open session sheet — does **not** advance |
| Tap collapsed exercise row (3a) | Expand full table in place |
| Tap heart | Toggle like, increment count |
| Tap speech bubble | Open comments sheet over the post |
| Tap challenge row (3b) | Push its leaderboard |
| Tap metric row (5a) | Select it; Custom also reveals three inline fields |
| Tap INVITE pill (5b) | Toggle invited, update the docked count |
| Tap `···` (7a) | Open the don't-post sheet |
| Tap scrim or a sheet row | Dismiss the sheet |

**Motion.** Default 250ms ease-in-out. 150ms ease-out for taps. **350ms for sheets.** Ticker marquees at 40px/sec linear. **No spring physics, no bounce, no confetti** — not even on a PR or a challenge win.

**Loading.** Skeleton rows shaped like the real content. Never spinners.

**Press states.** Filled surfaces darken (`#0A6FC0` → `#08589A`); text controls drop to 0.7 opacity.

## State

| State | Where | Notes |
|---|---|---|
| `carouselIndex` | Per post | 0–1, two slides only |
| `sessionSheetOpen` | Per post | Body map tap opens |
| `commentsOpen` | Per post | Sheet over the post |
| `expanded` | 3a post | Collapsed table toggle |
| `metric`, `window`, `customOpen` | 5a | `customOpen` derives from `metric === 'Custom'` |
| `invited[]` | 5b | Drives the docked count |
| `composerPhoto` | 7a | Attached photo; hides the camera button |
| `composerMenu` | 7a | Overflow sheet |
| `theme` | App-wide | Every screen is token-driven and follows light/dark |

**Session totals must be derived, never hardcoded.** In the prototype one `session` array produces sets, improved count, PR count and the summary line, so the post header, the sheet header and the collapsed row cannot drift apart. Do the same in Swift.

## Design tokens

All from `_ds/.../tokens/`. Use the token names.

| Token | Light | Dark |
|---|---|---|
| `--surface-canvas` | `#F9F8F4` | `#1A1917` |
| `--surface-elevated` | `#F4F0E6` | `#252220` |
| `--surface-sunken` | `#ECE7D8` | `#2E2A26` |
| `--accent` (filled) | `#0A6FC0` | `#0A6FC0` |
| `--accent-text` | `#0A6FC0` | `#4DB8FF` |
| `--signal-up` | `#00AA55` | `#00E07A` |
| `--signal-down` | `#C0341A` | — |
| `--rule-hair` | 8% ink | 8% ink |
| `--rule-strong` | 14% ink | 14% ink |

Literals not covered by a token: PR gold `#C9892E`; medals `#A06E1E` / `#6E7C87` / `#96602A`; scrim `rgba(31,28,25,0.45)` with 6px blur.

**Type scale.** Archivo 900 28px screen titles · 900 22–24px sheet and section titles · 900 14–15px CTAs · 700 15–20px content titles · 600 14–16px list rows · 400 13–15px body. Space Mono 700 14–20px data values · 700 9–11px deltas · 400 7–9px labels, tracked 1.2–1.6px, always uppercase.

**Spacing.** 4pt grid. Screen edge 16px. Card padding 12–14px. 24px between unrelated sections. Rows 44px minimum, 56–60px for rows with avatars.

## Assets

- **Fonts:** Archivo (300/400/600/700/900) and Space Mono (400/700), in `_ds/.../assets/fonts/`.
- **Icons:** SF Symbols in the app. The prototype hand-draws equivalents as inline SVG at 1.6px stroke on 24×24, which is the substitution the source prototypes themselves made. Never use a filled icon outside an active state.
- **Glyphs that are typed characters, not icons:** `▲` `▼` `·` `✓` `›` `···`. These are load-bearing — keep them as Space Mono text.
- **Photos:** user-supplied only. The prototype uses `image-slot.js` drop targets as placeholders.
- **No logo asset exists.** The brand mark is a 16px solid accent square beside `PULSE/PUMP` in Space Mono 700 10px / 2px tracking.

## Files

| File | What |
|---|---|
| `Friends Feed.dc.html` | All screens. Turns 3–7 current; turns 1–2 superseded. |
| `BodyHeat.dc.html` | The muscle heat-map silhouette component. |
| `image-slot.js` | Photo placeholder helper (prototype only — not for production). |
| `support.js` | Prototype runtime (not for production). |
| `_ds/pump-design-system-.../` | Tokens, stylesheets, component bundle. |
| `github.md` | Repo association and screen-to-source map. |

## Still to design

- Post overflow sheet (mute, report, unfollow) — the `···` on a feed post has no sheet behind it.
- Skeleton loading rows, specified by the system but never drawn.
- What a challenge invite looks like as a push notification.
