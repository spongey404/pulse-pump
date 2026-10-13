# 03 Workout logging

## What it's for
The logger is where you record a session set by set. It remembers what you lifted last time, runs a rest timer, helps load the bar, and ends with a summary you can post to friends.

## The flow
1. Tap START WORKOUT on Home → the logger covers the screen: workout name, a running clock, a REST pill, one card per exercise.
2. Look at a set row → faint numbers show what you did last time.
3. Type weight and reps (or leave them to reuse last time) → tap the circle → the set is ticked and the rest timer starts.
4. On barbell lifts, tap PLATES · SHOW under the row → see which plates go on each side.
5. Tap the REST pill → adjust with −15s / +15s / +30s / +1m, or SKIP REST. When rest ends you hear the alert (or get a "Rest done" notification if the phone is locked).
6. Tap + ADD SET for more rows; swipe a row left to delete it.
7. Tap + ADD EXERCISE → search or pick a movement → it's added at the bottom.
8. Tap FINISH WORKOUT → if sets are unticked, confirm REMOVE + FINISH → the summary opens: stats (sets, volume, streak, PRs), a mini body map, how many lifts improved, and your best sets.
9. Add a caption, tag friends (+ ADD) → tap POST → it goes to your friends' feed and you return to Home.

**Alternate paths**
- **Leave mid-workout:** tap ‹ → SAVE AS DRAFT (resume later from Home's CONTINUE) or DISCARD WORKOUT.
- **App crashes or is closed:** reopen → Home shows CONTINUE with your ticked sets kept.
- **Card menu (···):** Replace Exercise, Rest Timer Override (custom rest for this lift), Remove Exercise.
- **Set type:** tap the chip at the left of a row → Warmup, Superset, Drop, Rest-Pause, AMRAP, Failure or L/R. Warm-ups are kept but don't count toward stats.
- **Don't post:** on the summary tap ··· → Don't post, Post without body map, or Never post automatically.
- **Starting from Programs or a widget** works the same way (see 07 and 11).

## Not working / not built yet
- Starting from Programs or a widget while a draft exists creates a second hidden draft. (broken)
- Supersets and L/R are labels only; rest still starts after a "no rest" superset set. (not built)
- Drop, Rest-Pause, AMRAP and Failure change only the label.
- Time-based exercises show KG and REPS headers. (broken)
- An empty first-time set can be ticked as 0 × 0, and negative weights are accepted. (broken)
- No note for the whole workout. (not built)
- Calories appear only in the summary ticker, never during the workout.
- Plates: "BAR ONLY" hides a small leftover (broken); the bar is always 20 kg, even for EZ or trap bar.
- START TIMER always gives 90 seconds; "Auto-Start with Dismiss" equals Auto-Start.
- Dragging tall or collapsed cards lands in the wrong place. (broken)
- A summary photo is dropped when you post, and a failed post is lost. (broken)
- With privacy "Only me", POST silently posts nothing.
- No way to share the summary card as an image. (not built)

## Decide
- **Logger extras:** build real supersets (link two exercises, rest only after the last one), add a whole-workout note, and remove the L/R set type for v1. *Recommended: yes.*
- **Completion screen:** show calories in the stats row (none live during the workout), add Share / Save image for the card, and hide the camera until photo upload is built. *Recommended: yes.*

## Rules I'll apply
- Ticking an empty row reuses last time's numbers; a row with nothing at all can't be ticked (it shakes). Last-time numbers match warm-ups to warm-ups.
- Weights must be 0 to 1000 kg and reps 0 to 999; rest timers cap at 30 minutes; START TIMER uses the exercise's own rest time.
- Finishing needs at least one ticked set; a session past midnight keeps the date it started.
- The plate calculator preselects the bar from the exercise's equipment and shows any leftover weight per side.
- Failed posts are saved and retried automatically; "Only me" shows "Saved. Not posted (privacy is Only me)".
