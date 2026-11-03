# 02 Home

## What it's for
Home is the middle tab and the launch pad. It shows today's predicted workout, your streak and this week's numbers, and has one big button to start training.

## The flow
1. Open the app → Home shows, top to bottom: a scrolling ticker of muscle changes, the ORE masthead with search and your avatar, the PREDICTED TODAY block, four tiles (STREAK, IMPROVED, PRs, SETS), a Monday-to-Sunday sets bar chart, a "friends trained today" banner, and your three most RECENT workouts.
2. Read the predicted block → workout name, when you last did it, about how long it takes, a 5-square confidence meter and its exercises.
3. Tap START WORKOUT at the bottom → the workout logger opens with that program's exercises (see 03).
4. Finish the workout → Home's tiles and bars update at once.

**Alternate paths**
- **Pick a different workout:** tap NOT TODAY? → choose any program → the block and the START button switch to it.
- **Resume a draft:** if a workout is unfinished, the button becomes CONTINUE · name · N SETS DONE → tap it → the logger reopens where you left off. Tap START NEW WORKOUT above it → confirm DISCARD + START NEW to throw the draft away.
- **Search:** tap the magnifier → type → see matching exercises, past workouts and people (by exact @username). Tap an exercise to open its detail.
- **Avatar menu:** tap your initial → a card with your name and SIGN OUT.

## Not working / not built yet
- "IMPROVED" means three different things on Home, the RECENT table and the workout summary, so the numbers disagree. (broken)
- A first-ever lift counts as a PR on Home but not on the workout summary. (broken)
- "WK n" means a different week number on Home, More, Body and Recap. (broken)
- If the prediction doesn't match a saved program, START begins an empty workout and NOT TODAY? disappears. (broken)
- After you pick a workout with NOT TODAY?, that choice sticks until the app restarts. (broken)
- "Last done" can say TODAY for a workout done last night. (broken)
- DISCARD + START NEW starts an empty workout, not the predicted one. (broken)
- The discard message promises drafts are kept 7 days; nothing deletes them. (broken)
- Extra drafts (for example from Duplicate) are hidden and never cleaned up. (broken)
- Tapping a RECENT row, the friends banner, a workout search result or a person search result does nothing. (not built)
- Tiny volume changes show as "▲ 0%" in green. (broken)
- SIGN OUT from the avatar menu has no confirmation. (broken)
- Search hint promises "search by muscle"; it only searches names.
- A workout re-dated into the future counts in this week's numbers. (broken)
- No "What do you want to do?" screen when the app isn't confident. (not built)

## Decide
- **Predicted workout:** show NEXT UP once you've already trained today, always show NOT TODAY?, and when confidence is low show "What do you want to do?" with quick picks. *Recommended: yes.*
- **One workout at a time:** starting a new workout from anywhere (Home, Programs, widgets) asks to discard the current draft first; drafts are kept until finished or discarded, and the "7 days" wording goes. *Recommended: yes.*
- **Streak meaning:** keep the current forgiving streak (rest gaps of up to 3 days keep it alive and count as days). *Recommended: yes, keep it.*

## Rules I'll apply
- One PR rule everywhere: a weight PR beats your previous best weight; a rep PR beats your best reps at the same or lighter weight; the first time you do a lift sets a baseline, not a PR.
- "Improved" everywhere means a better estimated one-rep max than last time you did that lift.
- "WK n" is the calendar week of the year everywhere.
- RECENT and search rows open the workout detail; the banner and person rows open the Social tab or profile.
- Percent changes round normally, and anything under 0.5% shows as a neutral "0%".
