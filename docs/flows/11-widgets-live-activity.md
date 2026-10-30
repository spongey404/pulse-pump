# 11 Widgets and Live Activity

## What it's for
Widgets put your streak, next workout and weekly numbers on the home and lock screen. During a workout, a Live Activity on the lock screen and Dynamic Island shows your current set and rest timer, and lets you log a set without opening the app.

## The flow
**Home and lock screen widgets**
1. Long-press the home screen → + → search "Ore" → choose a widget: Next workout, Streak, Weekly volume, Last session, Program, Weekly goal, Bodyweight, Friends, Quick start, Pulse, or the Supernova ones (Body map, Muscle balance, PR watch, Deload and recovery).
2. Add Next workout (medium) → it shows tomorrow's or today's predicted workout and its exercises.
3. Tap START WORKOUT on it → Ore opens with that workout running.
4. Finish a workout in the app → widgets update with the new streak and numbers.

**Live Activity**
5. Start a workout → lock the phone → the lock screen shows the workout, sets done, elapsed time and the next set (weight × reps) with ✓ LOG SET.
6. Tap ✓ LOG SET → the set is logged and the rest countdown appears with −15S, +15S and SKIP.
7. When rest ends → "Rest done" alert, and the Dynamic Island expands.
8. Finish the workout in the app → the Live Activity ends.

**Alternate paths**
- **Custom widget (Supernova):** More › Widgets → NEW → pick a size → tap or drag pieces (stats, PRs, week bars, charts, body map, start button) onto the canvas → SAVE. Then on the home screen add "Ore Custom" → Edit Widget → pick yours.
- **Widget gallery:** More › Widgets › Widget gallery → every widget in light, dark and tinted, with sample numbers.
- **Free user adds a Supernova widget:** it shows a locked preview with UNLOCK SUPERNOVA.
- **Dynamic Island:** long-press it during a workout for the current set and rest controls.

## Not working / not built yet
- Tapping START on a small widget (Next workout, Quick start, locked preview) probably just opens the app. (broken, check on device)
- Quick start tiles start an empty workout when the program name has lowercase letters. (broken)
- Starting from a widget while a workout is already running replaces it. (broken)
- After a crash and resume, two Live Activities can appear. (broken)
- Widgets don't update after editing or deleting history, importing, or at midnight until you open the app.
- Widgets show zeros or blanks for new users instead of a helpful message.
- Weekly volume shows "+0.0%" in your first week and "WK 1 VS 0" in January. (broken)
- The small Last session widget labels every PR "ROW". (broken)
- Streak medium says "1 DAYS AGO". (broken)
- Custom widgets show fake sample numbers when you have no workouts, and the bodyweight chart is always fake. (broken)
- Custom widgets: no rename, no "unsaved changes" warning, delete has no confirmation, and re-edited widgets can mix up pieces. (broken)
- The lock-screen PR watch widget isn't locked for free users.
- Custom widgets keep working after Supernova ends.
- The gallery says "what you see is what WidgetKit draws" but always uses sample data.

## Decide
- Covered by README decision 2 (custom widgets lock when Supernova or the trial ends, like other Plus widgets). No other owner questions.

## Rules I'll apply
- Every widget gets a real empty state ("Log your first workout", "Add your weight", "No friends yet"); no comparison shows "NEW" instead of +0.0%.
- Widgets refresh after any history change, import or split change, and roll over to the new day.
- Starting from a widget while a workout or draft exists asks first (same as Home).
- Stale Live Activities are cleaned up on launch, and one is ended tidily at iOS's 8-hour limit.
- The lock-screen PR watch widget is Supernova, like its home-screen sizes.
