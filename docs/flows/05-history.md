# 05 History, exercise detail and Weekly Recap

## What it's for
History is your training log: every finished workout, a calendar view, and the ability to fix mistakes. Exercise detail shows how one lift is progressing, and Weekly Recap sums up each week.

## The flow
1. Tap More → History (the row shows how many workouts you've done) → a stats strip (WORKOUTS, THIS MONTH, STREAK) and every workout, newest first.
2. Tap a workout → detail: date, name, duration, exercises, sets, calories, each set as weight × reps, and notes.
3. Tap ⋯ → Edit → change the date, weights, reps, add or delete sets, edit notes → DONE.
4. Back on the list, swipe a workout left → Delete → confirm → it's gone everywhere (and from your other devices).
5. Tap the calendar icon → a month grid with workout days marked → tap a day → tap the workout card to open it.

**Alternate paths**
- **Duplicate:** in workout detail tap ⋯ → Duplicate (creates a draft copy; see bugs).
- **Exercise detail:** Home › search › tap an exercise → weight PR, rep PR, estimated 1RM, best session volume, a weight-over-time chart, the last 5 sessions, which programs use it, and your notes.
- **Weekly Recap:** More → Weekly Recap → sessions vs target, daily bars, volume, sets, time, sets by muscle, and this week's PRs. Use ‹ › to browse weeks.
- **Profile:** More → tap your name → avatar (tap to change photo), workouts, streak, friends, fans and your details.

## Not working / not built yet
- Duplicate gives no feedback, creates a hidden draft, and shows every copied set as already done. (broken)
- Edit lets you pick a future date. (broken)
- Edit can't change set type, RIR, duration or the program, and can't add, remove or reorder exercises. (not built)
- Edits save as you type; there's no Cancel.
- Clearing a weight or reps field keeps the old value instead of 0.
- Warm-ups look the same as working sets in the detail. (broken)
- No PRs or body map in workout detail. (not built)
- Exercise detail has only a weight chart; no 1RM, volume or rep charts and no PR history. (not built)
- Exercise detail and the logger calculate estimated 1RM slightly differently for single reps. (broken)
- Exercise detail's recent sessions include warm-ups.
- Widgets don't update after you edit or delete a workout. (broken)
- Recap in the first week of the year says "VS WK 0". (broken)
- Recap footer promises "NEXT RECAP · MON"; no Monday notification or monthly recap exists. (not built)
- Deleting a posted workout leaves its feed post behind.

## Decide
- **Deleting a posted workout:** also delete its feed post, and say so in the delete dialog. *Recommended: yes.*
- **Editing past workouts:** allow adding and removing exercises, changing set type, a Cancel button, and limit the date to today or earlier. *Recommended: yes.*
- **Weekly Recap:** send a Monday recap notification (when notifications are on); no monthly recap in v1. *Recommended: yes.*

## Rules I'll apply
- One PR rule everywhere (same as Home): weight PR, or rep PR at same-or-lighter weight; first time is a baseline.
- Estimated 1RM uses one formula everywhere; a single rep equals the weight lifted.
- Warm-ups get a WU marker in detail and are left out of exercise-detail history.
- Widgets refresh after any edit or delete.
- "VS WK" shows the real previous week number (52 or 53 in January).
